-- Experimental CLI sessions; never enters the four-way bootloader selector.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local codec = requireModule("lib/msp_esc_parameters_escape32.lua")
local sessions = requireModule("lib/escape32_session.lua")
local header = requireModule("app/header.lua")
local closeKey = requireModule("app/close_key.lua")

local T = {
  name = "ESCape32",
  status = "@i18n(app.modules.esc_tools.escape32.status)@",
  experimental = "@i18n(app.modules.esc_tools.escape32.experimental)@",
  probe = "@i18n(app.modules.esc_tools.escape32.probe)@",
  target = "@i18n(app.modules.esc_tools.escape32.target)@",
  open = "@i18n(app.modules.esc_tools.escape32.open)@",
  parameter = "@i18n(app.modules.esc_tools.escape32.parameter)@",
  raw = "@i18n(app.modules.esc_tools.escape32.raw)@",
  shown = "@i18n(app.modules.esc_tools.escape32.shown)@",
  read = "@i18n(app.modules.esc_tools.escape32.read)@",
  apply = "@i18n(app.modules.esc_tools.escape32.apply)@",
  save = "@i18n(app.modules.esc_tools.escape32.save)@",
  recover = "@i18n(app.modules.esc_tools.escape32.recover)@",
  close = "@i18n(app.modules.esc_tools.escape32.close)@",
  identity = "@i18n(app.modules.esc_tools.escape32.identity)@",
  help = "@i18n(app.modules.esc_tools.escape32.help)@",
  helpBody = "@i18n(app.modules.esc_tools.escape32.help_body)@",
  idle = "@i18n(app.modules.esc_tools.escape32.idle)@",
  probing = "@i18n(app.modules.esc_tools.escape32.probing)@",
  select_target = "@i18n(app.modules.esc_tools.escape32.select_target)@",
  unsupported = "@i18n(app.modules.esc_tools.escape32.unsupported)@",
  opening = "@i18n(app.modules.esc_tools.escape32.opening)@",
  wait_power = "@i18n(app.modules.esc_tools.escape32.wait_power)@",
  busy = "@i18n(app.modules.esc_tools.escape32.busy)@",
  ready = "@i18n(app.modules.esc_tools.escape32.ready)@",
  save_confirmed = "@i18n(app.modules.esc_tools.escape32.save_confirmed)@",
  outcome_unknown = "@i18n(app.modules.esc_tools.escape32.outcome_unknown)@",
  open_unknown = "@i18n(app.modules.esc_tools.escape32.open_unknown)@",
  close_unknown = "@i18n(app.modules.esc_tools.escape32.close_unknown)@",
  restart_required = "@i18n(app.modules.esc_tools.escape32.restart_required)@",
  disconnected = "@i18n(app.modules.esc_tools.escape32.disconnected)@",
  closing = "@i18n(app.modules.esc_tools.escape32.closing)@",
  closed = "@i18n(app.modules.esc_tools.escape32.closed)@",
  error = "@i18n(app.modules.esc_tools.escape32.error)@",
  normalized = "@i18n(app.modules.esc_tools.escape32.normalized)@",
}
local CHOICES = {}
local UNITS = {"0/1", "deg", "kHz", "kHz", "%", "kERPM", "%/ms", "C", "A"}
for i = 1, #codec.PARAMETERS do CHOICES[i] = {codec.PARAMETERS[i].key, i - 1} end

local function open(opts)
  opts = opts or {}
  local disposed, pendingHelp, dialog = false, false, nil
  local c = sessions.new({send = function(message) bus.publish("msp.request", message) end})
  local selected, target, raw, edited = 0, nil, 0, false
  local fields, cache, enabled = {}, {}, {}
  local lastRevision, lastKey, lastValue, lastCaps, lastAcceptedId = -1, nil, nil, nil, nil
  local sessionHandler
  local build
  local function setEnabled(key, value)
    if enabled[key] == value then return end
    enabled[key] = value
    if fields[key] and fields[key].enable then fields[key]:enable(value) end
  end
  local function setText(key, text)
    if cache[key] == text then return end
    cache[key] = text
    if fields[key] and fields[key].value then fields[key]:value(text) end
  end
  local function closeDialog()
    if not dialog then return end
    local d = dialog; dialog = nil
    pcall(function() d:close() end)
  end
  local function dispose()
    if disposed then return end
    disposed = true
    closeDialog(); c.dispose()
    if sessionHandler then bus.unsubscribe("session.update", sessionHandler); sessionHandler = nil end
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setEventHandler then opts.setEventHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    for key in pairs(fields) do fields[key] = nil end
  end
  local function back() dispose(); if opts.onBack then opts.onBack() end end
  local function static(key, label)
    fields[key] = form.addStaticText(form.addLine(label), nil, "-")
  end
  local function button(key, label, action)
    local line = form.addLine("")
    local slots = form.getFieldSlots(line, {0, " " .. label .. " "})
    fields[key] = form.addButton(line, slots[2], {text = label, options = FONT_S + CENTERED, press = action})
  end
  local function refresh()
    if disposed then return end
    if c.caps ~= lastCaps then lastCaps = c.caps; build() end
    if lastRevision == c.revision and lastKey == selected then return end
    lastRevision = c.revision; lastKey = selected
    local v = c.values[selected]
    if v ~= lastValue or (c.reply and c.reply.valueValid and c.reply.key == selected
      and c.reply.requestId ~= lastAcceptedId) then
      lastValue = v; edited = false; raw = v or codec.PARAMETERS[selected + 1].min
      lastAcceptedId = c.reply and c.reply.requestId
      if fields.raw and fields.raw.value then fields.raw:value(raw) end
    end
    local status = T[c.state] or T.error
    if type(c.error) == "number" then status = status .. " (" .. c.error .. ")" end
    if c.normalized and c.state == "ready" then status = T.normalized end
    setText("status", status)
    local r = c.reply
    setText("identity", r and ("rev" .. r.revision .. "." .. r.patch .. " / schema " .. r.schema) or "-")
    if v ~= nil and r and r.schema == 1 then
      setText("shown", tostring(raw * codec.PARAMETERS[selected + 1].scale) .. " " .. UNITS[selected + 1])
    else setText("shown", v ~= nil and tostring(raw) or "-") end
    local act, write = c.canAct(), c.canWrite()
    setEnabled("probe", c.connected and c.disarmed and not c.pending and c.token == 0 and c.state ~= "open_unknown")
    setEnabled("target", codec.canRead(c.caps) == true and c.token == 0 and not c.pending)
    setEnabled("open", codec.canRead(c.caps) == true and target ~= nil and c.token == 0 and not c.pending and c.state ~= "open_unknown")
    setEnabled("parameter", not c.pending and (act or c.token == 0))
    setEnabled("raw", write and v ~= nil)
    setEnabled("read", act and r ~= nil and r.schema == 1)
    local p = codec.PARAMETERS[selected + 1]
    setEnabled("apply", write and edited and v ~= nil and raw >= p.min and raw <= p.max)
    setEnabled("save", write and c.dirty)
    setEnabled("recover", c.connected and c.disarmed and not c.pending
      and (c.state == "open_unknown" or c.token ~= 0))
    setEnabled("close", c.connected and c.token ~= 0 and c.state ~= "closing")
  end
  build = function()
    form.clear()
    for key in pairs(fields) do fields[key] = nil end
    for key in pairs(enabled) do enabled[key] = nil end
    for key in pairs(cache) do cache[key] = nil end
    header.build(T.name, {onBack = back})
    form.addLine(T.experimental)
    static("status", T.status)
    static("identity", T.identity)
    button("probe", T.probe, c.probe)
    local targets = {}
    if codec.canRead(c.caps) then
      for i = 0, 15 do
        if c.caps.targets & (1 << i) ~= 0 then targets[#targets + 1] = {"ESC " .. (i + 1), i} end
      end
    end
    target = targets[1] and targets[1][2] or nil
    if #targets > 0 then
      fields.target = form.addChoiceField(form.addLine(T.target), nil, targets,
        function() return target end, function(value) target = value; lastRevision = -1 end)
    else static("target", T.target) end
    button("open", T.open, function() if target ~= nil then c.open(target) end end)
    fields.parameter = form.addChoiceField(form.addLine(T.parameter), nil, CHOICES,
      function() return selected end, function(value)
        selected = value; lastValue = nil; lastKey = nil; edited = false; lastRevision = -1
      end)
    fields.raw = form.addNumberField(form.addLine(T.raw), nil, 0, 999,
      function() return raw end, function(value) raw = value; edited = true; lastRevision = -1 end)
    static("shown", T.shown)
    button("read", T.read, function() c.get(selected) end)
    button("apply", T.apply, function() c.set(selected, raw) end)
    button("save", T.save, c.save)
    button("recover", T.recover, c.recover)
    button("close", T.close, c.close)
    button("help", T.help, function() pendingHelp = true end)
    lastRevision = -1
  end
  build()
  sessionHandler = bus.subscribe("session.update", function(snapshot)
    if disposed then return end
    c.setLink(snapshot and snapshot.connected, snapshot and snapshot.isArmed)
  end)
  if opts.setEventHandler then opts.setEventHandler(function(category, value)
    if not closeKey.shouldHandleClose(category, value) then return false end
    back(); return true
  end) end
  if opts.setCleanupHandler then opts.setCleanupHandler(dispose) end
  if opts.setWakeupHandler then opts.setWakeupHandler(function()
    if disposed then return end
    c.wakeup(); refresh()
    if pendingHelp then
      pendingHelp = false
      if form.openDialog then
        closeDialog()
        dialog = form.openDialog({title = T.name, message = T.helpBody,
          buttons = {{label = "@i18n(app.btn_ok)@", action = function() dialog = nil; return true end}},
          options = TEXT_LEFT})
      end
    end
  end) end
  refresh()
end

return {open = open}
