-- UI-only boundary: opening, editing and leaving must never request firmware I/O.
-- Run from the repository root with lua5.4 bin/esc_kontronik_preview/verify_preview.lua.
local fields, panels, handlers = {}, {}, {}
local byLabel = {}
local headerOptions
local staticTexts, actionButton, dialogArgs, dialogClosed
TEXT_LEFT = 0
local dependencies = {
  ["app/header.lua"] = {build = function(_, opts) headerOptions = opts end},
  ["app/close_key.lua"] = {shouldHandleClose = function() return true end},
}
package.loaded["rfsuite.lib.require"] = function(path)
  return assert(dependencies[path], "Preview must not load transport dependencies: " .. path)
end
local function field(get, set, label)
  local f = {get = get, set = set, enabled = true}
  function f:enable(value) self.enabled = value; self.enableCalls = (self.enableCalls or 0) + 1 end
  function f:default(value) self.defaultValue = value end
  function f:decimals(value) self.decimalPlaces = value end
  function f:minimum(value)
    self.min = value
    assert(not self.max or value <= self.max, "Transient inverted bounds")
    if self.get() < value then self.set(value) end
  end
  function f:maximum(value)
    self.max = value
    assert(not self.min or value >= self.min, "Transient inverted bounds")
    if self.get() > value then self.set(value) end
  end
  function f:suffix() end
  function f:step() end
  if label then byLabel[label] = f end
  fields[#fields + 1] = f
  return f
end
form = {
  clear = function() fields, panels, staticTexts, byLabel = {}, {}, {}, {} end,
  addStaticText = function(line, _, text)
    local widget = {label = line, text = text}
    function widget:value(value) self.text = value end
    staticTexts[#staticTexts + 1] = widget
    return widget
  end,
  addButton = function(_, _, args) actionButton = args; return {} end,
  openDialog = function(args)
    dialogArgs = args
    dialogClosed = false
    return {close = function() dialogClosed = true end}
  end,
  addLine = function(label) return label end,
  addExpansionPanel = function(label)
    panels[#panels + 1] = label
    return {open = function() end, addLine = function(_, text) return text end}
  end,
  addBooleanField = function(label, _, get, set) return field(get, set, label) end,
  addNumberField = function(label, _, min, max, get, set)
    assert(get() >= min and get() <= max, "Example outside preview range")
    local f = field(get, set, label)
    f.min, f.max = min, max
    return f
  end,
  addChoiceField = function(label, _, choices, get, set)
    local valid = false
    for _, choice in ipairs(choices) do if choice[2] == get() then valid = true end end
    assert(valid, "Example outside preview choices")
    return field(get, set, label)
  end,
}
local backCount = 0
local opts = {
  onBack = function() backCount = backCount + 1 end,
  setEventHandler = function(h) handlers.event = h end,
  setWakeupHandler = function(h) handlers.wakeup = h end,
  setPaintHandler = function(h) handlers.paint = h end,
  setCleanupHandler = function(h) handlers.cleanup = h end,
}
local page = assert(loadfile("src/rfsuite/app/pages/esc_forward_kontronik.lua"))()
page.open(opts)
assert(#fields == 37 and #panels == 6, "Draft fields/groups must remain complete")
assert(not headerOptions.onSave and not headerOptions.onReload, "Preview cannot save/reload")
assert(not handlers.wakeup and not handlers.paint, "Preview needs no polling/render callbacks")
local staleField = fields[2]
local initial = staleField.get()
staleField.set(1)
assert(staleField.get() == 1, "Local editing must work")
assert(#staticTexts == 33, "31 status rows, RC check and preset result are required")
for i = 3, #staticTexts do
  assert(staticTexts[i].text == "--", "Unavailable status must not look like live telemetry")
end
for _, index in ipairs({24, 29, 30}) do
  local f = fields[index]
  local before = f.get()
  f.set(1)
  assert(not f.enabled and f.get() == before, "Draft read-only controls must remain locked")
end
assert(panels[5]:find("esc_status", 1, true) and panels[6]:find(".alarm)", 1, true),
  "Alarm must be the final panel after ESC Live Status")
local lock = fields[31]
assert(lock.get() == false, "Alarm editing must require explicit opt-in")
for i = 32, 37 do
  local f = fields[i]
  local before = f.get()
  f.set(before + 1)
  assert(not f.enabled and f.get() == before, "Locked alarm setters must reject edits")
end
lock.set(true)
for i = 32, 37 do assert(fields[i].enabled, "Unlock must enable all six alarms") end
local alarm = fields[32]
local alarmInitial = alarm.get()
alarm.set(alarmInitial + 1)
assert(alarm.get() == alarmInitial + 1, "Opt-in must permit local alarm edits")
local calls = alarm.enableCalls
lock.set(true)
assert(alarm.enableCalls == calls, "Unchanged switch must not update widget state")
lock.set(false)
alarm.set(alarmInitial + 2)
assert(not alarm.enabled and alarm.get() == alarmInitial + 1, "Re-lock must reject further edits")
local function named(key)
  return assert(byLabel["@i18n(app.modules.esc_tools.mfg.kontr." .. key .. ")@"], key)
end
local battery, cutoff = named("battery_type"), named("undervoltage_cell")
assert(battery.get() == 1 and cutoff.get() == 3000 and cutoff.min == 2700 and cutoff.max == 3500)
cutoff.set(3200)
battery.set(2)
assert(cutoff.get() == 2300 and cutoff.min == 1800 and cutoff.max == 2600)
cutoff.set(2500)
battery.set(0)
assert(cutoff.get() == 800 and cutoff.min == 700 and cutoff.max == 1200)
cutoff.set(900)
battery.set(1)
assert(cutoff.get() == 3200, "Each chemistry must retain its own local cutoff")
cutoff.set(4000)
assert(cutoff.get() == 3200, "Out-of-range chemistry edits must be rejected")
battery.set(9)
assert(battery.get() == 1, "Unknown chemistry must not change the data model")
battery.set(2)
assert(cutoff.get() == 2500, "Widget clamp callbacks must not overwrite other chemistry values")
battery.set(1)
assert(named("discharge_limit").decimalPlaces == 1, "Capacity uses tenths of Ah")
local brake, proportional = named("brake"), named("prop_brake")
assert(not proportional.enabled)
proportional.set(1)
assert(proportional.get() == 0, "A disabled brake-dependent setter must reject edits")
brake.set(1)
assert(proportional.enabled)
proportional.set(1)
brake.set(0)
assert(not proportional.enabled and proportional.get() == 1, "Disabling a parent must preserve child values")
local governor, store, rpm = named("rpm_ctl"), named("how_adj_max_rpm"), named("max_rpm")
local children = {store, rpm, named("startuptime"), named("p-gain"), named("motor_resist")}
for _, f in ipairs(children) do assert(not f.enabled) end
rpm.set(32000)
assert(rpm.get() == 30000)
governor.set(1)
assert(store.enabled and not rpm.enabled and named("p-gain").enabled)
store.set(1)
assert(rpm.enabled)
rpm.set(32000)
store.set(0)
assert(not rpm.enabled and rpm.get() == 32000)
governor.set(0)
for _, f in ipairs(children) do assert(not f.enabled) end
governor.set(1)
assert(not rpm.enabled)
store.set(1)
assert(rpm.enabled and rpm.get() == 32000)
local calls = rpm.enableCalls
governor.set(1)
assert(rpm.enableCalls == calls, "Unchanged dependencies must not update widget state")
local positions = staticTexts[2]
assert(positions.text:find("rc_valid", 1, true))
named("off_position").set(1940)
assert(positions.text:find("rc_invalid", 1, true), "Equal endpoints must be diagnosed")
named("off_position").set(1100)
assert(positions.text:find("rc_valid", 1, true))
named("max_position").set(600)
assert(positions.text:find("rc_valid", 1, true), "Reversed valid endpoints must be accepted")
named("max_position").set(1150)
assert(positions.text:find("rc_invalid", 1, true), "Too-close endpoints must be diagnosed")
named("max_position").set(1250)
assert(positions.text:find("rc_valid", 1, true))
brake.set(1)
assert(positions.text:find("rc_invalid", 1, true), "Brake needs 200 us to full throttle")
named("max_position").set(1300)
assert(positions.text:find("rc_valid", 1, true), "The 200 us brake boundary is valid")
brake.set(0)
named("max_position").set(1940)
local result = staticTexts[1]
local untouched = result.text
fields[1].set(6)
assert(fields[1].get() == 6 and result.text == untouched, "Selection must not load a preset")
actionButton.press()
assert(#dialogArgs.buttons == 2 and not headerOptions.onSave)
dialogArgs.buttons[1].action()
assert(result.text == untouched, "Cancel must leave the preview request unchanged")
actionButton.press()
dialogArgs.buttons[2].action()
assert(result.text:find("preset_requested", 1, true), "Confirm must show a preview request")
assert(fields[2].get() == 1, "Preset preview must not invent model-specific defaults")
for _, value in ipairs({2, 3, 4, 5, 6}) do
  fields[1].set(value)
  assert(fields[1].get() == value, "Documented preset command must be selectable")
end
fields[1].set(1)
assert(fields[1].get() == 6, "Undocumented preset values must be rejected")
actionButton.press()
local staleConfirm = dialogArgs.buttons[2].action
handlers.event(0, 0)
assert(backCount == 1 and not handlers.cleanup and not handlers.event)
assert(dialogClosed, "Leaving must close the preset confirmation dialog")
lock.set(true)
assert(lock.get() == false, "A stale unlock callback must not reopen editing")
local closedText = result.text
staleConfirm()
assert(result.text == closedText, "Late confirmation must not update a closed page")
assert(staleField.get() == nil, "Close must release local values")
staleField.set(2)
assert(staleField.get() == nil, "Stale callbacks must not restore closed state")
page.open(opts)
assert(named("undervoltage_cell").get() == 800, "Reopen must reset per-chemistry preview values")
assert(not named("prop_brake").enabled and not named("max_rpm").enabled, "Reopen must reset dependencies")
assert(fields[2].get() == initial, "Reopening must discard all preview edits")
assert(fields[31].get() == false and not fields[32].enabled, "Reopening must reset the alarm edit lock")
assert(fields[1].get() == 4, "Reopening must reset the preset target")
assert(staticTexts[1].text == untouched, "Reopening must discard the preset request")
handlers.cleanup()
print("PASS: chemistry/brake/governor dependencies, RC diagnostics, alarm lock, no transport and cleanup")
