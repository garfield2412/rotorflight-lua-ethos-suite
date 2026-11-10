-- Setup -> ESC & Motors -> ESC Tools -> Kontronik.
-- UI-only draft: values and limits come from the old ESC_kontronik design.
-- They are provisional until firmware integration validates the parameter model.
-- No bus, codec, read, write, EEPROM or reboot operations belong to this preview.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local header = requireModule("app/header.lua")
local closeKey = requireModule("app/close_key.lua")

local T = {
  rc_check = "@i18n(app.modules.esc_tools.mfg.kontr.rc_check)@",
  rc_valid = "@i18n(app.modules.esc_tools.mfg.kontr.rc_valid)@",
  rc_invalid = "@i18n(app.modules.esc_tools.mfg.kontr.rc_invalid)@",
  alarm_edit = "@i18n(app.modules.esc_tools.mfg.kontr.alarm_edit)@",
  alarm_note = "@i18n(app.modules.esc_tools.mfg.kontr.alarm_note)@",
  alarm_independent = "@i18n(app.modules.esc_tools.mfg.kontr.alarm_independent)@",
  bluetooth = "@i18n(app.modules.esc_tools.mfg.kontr.bluetooth)@",
  bt_button_note = "@i18n(app.modules.esc_tools.mfg.kontr.bt_button_note)@",
  bt_stop_note = "@i18n(app.modules.esc_tools.mfg.kontr.bt_stop_note)@",
  ["preset_target"] = "@i18n(app.modules.esc_tools.mfg.kontr.preset_target)@",
  ["preset_load"] = "@i18n(app.modules.esc_tools.mfg.kontr.preset_load)@",
  ["preset_confirm_title"] = "@i18n(app.modules.esc_tools.mfg.kontr.preset_confirm_title)@",
  ["preset_confirm"] = "@i18n(app.modules.esc_tools.mfg.kontr.preset_confirm)@",
  ["preset_none"] = "@i18n(app.modules.esc_tools.mfg.kontr.preset_none)@",
  ["preset_requested"] = "@i18n(app.modules.esc_tools.mfg.kontr.preset_requested)@",
  ["preset_f5a"] = "@i18n(app.modules.esc_tools.mfg.kontr.preset_f5a)@",
  ["preset_car"] = "@i18n(app.modules.esc_tools.mfg.kontr.preset_car)@",
  ["status_identity"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_identity)@",
  ["status_model"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_model)@",
  ["status_eeprom"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_eeprom)@",
  ["status_programming"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_programming)@",
  ["status_state"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_state)@",
  ["status_live"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_live)@",
  ["status_runtime"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_runtime)@",
  ["status_battery_v"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_battery_v)@",
  ["status_battery_a"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_battery_a)@",
  ["status_capacity"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_capacity)@",
  ["status_rpm"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_rpm)@",
  ["status_motor_a"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_motor_a)@",
  ["status_timing"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_timing)@",
  ["status_bec_v"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_bec_v)@",
  ["status_bec_a"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_bec_a)@",
  ["status_bec_temp"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_bec_temp)@",
  ["status_throttle"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_throttle)@",
  ["status_target_rpm"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_target_rpm)@",
  ["status_pwm"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_pwm)@",
  ["status_esc_temp"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_esc_temp)@",
  ["status_pulse"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_pulse)@",
  ["status_pulse_avg"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_pulse_avg)@",
  ["status_statistics"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_statistics)@",
  ["status_min_battery"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_min_battery)@",
  ["status_max_motor"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_max_motor)@",
  ["status_peak_motor"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_peak_motor)@",
  ["status_min_bec"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_min_bec)@",
  ["status_max_bec_a"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_max_bec_a)@",
  ["status_max_bec_temp"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_max_bec_temp)@",
  ["status_max_esc_temp"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_max_esc_temp)@",
  ["status_events"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_events)@",
  ["status_event_time"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_event_time)@",
  ["status_event_type"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_event_type)@",
  ["status_event_code"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_event_code)@",
  ["status_event_text"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_event_text)@",
  ["PWM_min"] = "@i18n(app.modules.esc_tools.mfg.kontr.PWM_min)@",
  ["act_impulse_length"] = "@i18n(app.modules.esc_tools.mfg.kontr.act_impulse_length)@",
  ["alarm"] = "@i18n(app.modules.esc_tools.mfg.kontr.alarm)@",
  ["alternate_startup"] = "@i18n(app.modules.esc_tools.mfg.kontr.alternate_startup)@",
  ["basic"] = "@i18n(app.modules.esc_tools.mfg.kontr.basic)@",
  ["battery_type"] = "@i18n(app.modules.esc_tools.mfg.kontr.battery_type)@",
  ["bec_voltage"] = "@i18n(app.modules.esc_tools.mfg.kontr.bec_voltage)@",
  ["brake"] = "@i18n(app.modules.esc_tools.mfg.kontr.brake)@",
  ["brake_position"] = "@i18n(app.modules.esc_tools.mfg.kontr.brake_position)@",
  ["bt_disable_motor_renable_button"] = "@i18n(app.modules.esc_tools.mfg.kontr.bt_disable_motor_renable_button)@",
  ["bt_disable_motor_renable_motor_stop"] = "@i18n(app.modules.esc_tools.mfg.kontr.bt_disable_motor_renable_motor_stop)@",
  ["discharge_limit"] = "@i18n(app.modules.esc_tools.mfg.kontr.discharge_limit)@",
  ["esc_status"] = "@i18n(app.modules.esc_tools.mfg.kontr.esc_status)@",
  ["extra_smooth_IU"] = "@i18n(app.modules.esc_tools.mfg.kontr.extra_smooth_IU)@",
  ["flight_Mode_choice_0"] = "@i18n(app.modules.esc_tools.mfg.kontr.flight_Mode_choice_0)@",
  ["flight_Mode_choice_1"] = "@i18n(app.modules.esc_tools.mfg.kontr.flight_Mode_choice_1)@",
  ["flight_Mode_choice_2"] = "@i18n(app.modules.esc_tools.mfg.kontr.flight_Mode_choice_2)@",
  ["fwd_bckwd"] = "@i18n(app.modules.esc_tools.mfg.kontr.fwd_bckwd)@",
  ["gear_ratio"] = "@i18n(app.modules.esc_tools.mfg.kontr.gear_ratio)@",
  ["how_adj_max_rpm"] = "@i18n(app.modules.esc_tools.mfg.kontr.how_adj_max_rpm)@",
  ["how_adj_max_rpm_choice_0"] = "@i18n(app.modules.esc_tools.mfg.kontr.how_adj_max_rpm_choice_0)@",
  ["how_adj_max_rpm_choice_1"] = "@i18n(app.modules.esc_tools.mfg.kontr.how_adj_max_rpm_choice_1)@",
  ["max_bec_current"] = "@i18n(app.modules.esc_tools.mfg.kontr.max_bec_current)@",
  ["max_bec_temp"] = "@i18n(app.modules.esc_tools.mfg.kontr.max_bec_temp)@",
  ["max_discharge"] = "@i18n(app.modules.esc_tools.mfg.kontr.max_discharge)@",
  ["max_esc_temp"] = "@i18n(app.modules.esc_tools.mfg.kontr.max_esc_temp)@",
  ["max_motor_current"] = "@i18n(app.modules.esc_tools.mfg.kontr.max_motor_current)@",
  ["max_position"] = "@i18n(app.modules.esc_tools.mfg.kontr.max_position)@",
  ["max_rpm"] = "@i18n(app.modules.esc_tools.mfg.kontr.max_rpm)@",
  ["min_input_voltage"] = "@i18n(app.modules.esc_tools.mfg.kontr.min_input_voltage)@",
  ["motor"] = "@i18n(app.modules.esc_tools.mfg.kontr.motor)@",
  ["motor_resist"] = "@i18n(app.modules.esc_tools.mfg.kontr.motor_resist)@",
  ["name"] = "@i18n(app.modules.esc_tools.mfg.kontr.name)@",
  ["off_position"] = "@i18n(app.modules.esc_tools.mfg.kontr.off_position)@",
  ["p-gain"] = "@i18n(app.modules.esc_tools.mfg.kontr.p-gain)@",
  ["pole_number"] = "@i18n(app.modules.esc_tools.mfg.kontr.pole_number)@",
  ["preview"] = "@i18n(app.modules.esc_tools.mfg.kontr.preview)@",
  ["prop_brake"] = "@i18n(app.modules.esc_tools.mfg.kontr.prop_brake)@",
  ["rc"] = "@i18n(app.modules.esc_tools.mfg.kontr.rc)@",
  ["rotation"] = "@i18n(app.modules.esc_tools.mfg.kontr.rotation)@",
  ["rpm_ctl"] = "@i18n(app.modules.esc_tools.mfg.kontr.rpm_ctl)@",
  ["slewrate_down"] = "@i18n(app.modules.esc_tools.mfg.kontr.slewrate_down)@",
  ["slewrate_up"] = "@i18n(app.modules.esc_tools.mfg.kontr.slewrate_up)@",
  ["startup_curr_limit"] = "@i18n(app.modules.esc_tools.mfg.kontr.startup_curr_limit)@",
  ["startuptime"] = "@i18n(app.modules.esc_tools.mfg.kontr.startuptime)@",
  ["status_note"] = "@i18n(app.modules.esc_tools.mfg.kontr.status_note)@",
  ["undervoltage_behavior"] = "@i18n(app.modules.esc_tools.mfg.kontr.undervoltage_behavior)@",
  ["undervoltage_behavior_choice_0"] = "@i18n(app.modules.esc_tools.mfg.kontr.undervoltage_behavior_choice_0)@",
  ["undervoltage_behavior_choice_1"] = "@i18n(app.modules.esc_tools.mfg.kontr.undervoltage_behavior_choice_1)@",
  ["undervoltage_cell"] = "@i18n(app.modules.esc_tools.mfg.kontr.undervoltage_cell)@",
}
local OFF_ON = {{"@i18n(app.modules.governor.tbl_off)@", 0}, {"@i18n(app.modules.governor.tbl_on)@", 1}}
-- PDF 2026-04-01, pp. 10-11: preview limits/examples, not inferred ESC data.
-- Keep a separate value per chemistry; switching must never copy one into another.
local CELL_LIMITS = {
  [0] = {min = 700, max = 1200, default = 800},
  [1] = {min = 2700, max = 3500, default = 3000},
  [2] = {min = 1800, max = 2600, default = 2300},
}


local FIELDS = {
  {group = T.basic},
  {key = "battery_type", label = T["battery_type"], choices = {{"NiCd / NiMH", 0}, {"LiPo", 1}, {"LiFePo", 2}}, value = 0},
  {key = "undervoltage_behavior", label = T["undervoltage_behavior"], choices = {{T["undervoltage_behavior_choice_0"], 0}, {T["undervoltage_behavior_choice_1"], 1}}, value = 0},
  {key = "undervoltage_cell", label = T["undervoltage_cell"], min = CELL_LIMITS[0].min, max = CELL_LIMITS[0].max, value = CELL_LIMITS[0].default, suffix = "mV", step = 100},
  {key = "discharge_limit", label = T["discharge_limit"], min = 0, max = 1000, value = 0, suffix = "Ah", decimals = 1, step = 1},
  {group = T.motor},
  {key = "rotation", label = T["rotation"], choices = OFF_ON, value = 0},
  {key = "fwd_bckwd", label = T["fwd_bckwd"], choices = OFF_ON, value = 0},
  {key = "pole_number", label = T["pole_number"], choices = {{"2", 0}, {"4", 1}, {"6", 2}, {"8", 3}, {"10", 4}, {"12", 5}, {"14", 6}, {"16", 7}, {"18", 8}, {"20", 9}}, value = 0},
  {key = "gear_ratio", label = T["gear_ratio"], min = 100, max = 2000, value = 100, step = 1},
  {key = "brake", label = T["brake"], choices = OFF_ON, value = 0},
  {key = "prop_brake", dependsOn = "brake", label = T["prop_brake"], choices = OFF_ON, value = 0},
  {key = "rpm_ctl", label = T["rpm_ctl"], choices = OFF_ON, value = 0},
  {key = "how_adj_max_rpm", dependsOn = "rpm_ctl", label = T["how_adj_max_rpm"], choices = {{T["how_adj_max_rpm_choice_0"], 0}, {T["how_adj_max_rpm_choice_1"], 1}}, value = 0},
  {key = "max_rpm", dependsOn = "rpm_ctl", label = T["max_rpm"], min = 0, max = 100000, value = 30000, step = 100},
  {key = "startuptime", dependsOn = "rpm_ctl", label = T["startuptime"], min = 0, max = 60, value = 5, suffix = "s", step = 1},
  {key = "p-gain", dependsOn = "rpm_ctl", label = T["p-gain"], min = 0, max = 15, value = 4, step = 1},
  {key = "motor_resist", dependsOn = "rpm_ctl", label = T["motor_resist"], min = 0, max = 15, value = 10, suffix = "mOhm", step = 1},
  {key = "PWM_min", label = T["PWM_min"], min = 0, max = 100, value = 0, suffix = "%", step = 1},
  {key = "slewrate_up", label = T["slewrate_up"], min = 0, max = 65535, value = 8000, suffix = "ms", step = 1},
  {key = "slewrate_down", label = T["slewrate_down"], min = 0, max = 65535, value = 4000, suffix = "ms", step = 1},
  {key = "extra_smooth_IU", label = T["extra_smooth_IU"], choices = OFF_ON, value = 0},
  {key = "alternate_startup", label = T["alternate_startup"], choices = OFF_ON, value = 0},
  {key = "startup_curr_limit", label = T["startup_curr_limit"], min = 0, max = 255, value = 150, suffix = "A", step = 1},
  {group = T.rc},
  {key = "act_impulse_length", label = T["act_impulse_length"], min = 500, max = 2100, value = 1100, suffix = "us", step = 10, readOnly = true},
  {key = "off_position", label = T["off_position"], min = 500, max = 2100, value = 1100, suffix = "us", step = 10},
  {key = "max_position", label = T["max_position"], min = 500, max = 2100, value = 1940, suffix = "us", step = 10},
  {key = "brake_position", label = T["brake_position"], min = 500, max = 2100, value = 1100, suffix = "us", step = 10},
  {key = "bec_voltage", label = T["bec_voltage"], min = 4800, max = 8000, value = 4800, suffix = "mV", step = 100},
  {group = T.bluetooth},
  {key = "bt_disable_motor_renable_button", label = T["bt_disable_motor_renable_button"], note = T.bt_button_note, choices = OFF_ON, value = 0, readOnly = true},
  {key = "bt_disable_motor_renable_motor_stop", label = T["bt_disable_motor_renable_motor_stop"], note = T.bt_stop_note, choices = OFF_ON, value = 0, readOnly = true},
  {group = T.esc_status},
  {group = T.alarm},
  {key = "max_discharge", alarm = true, label = T["max_discharge"], min = 0, max = 50, value = 15, suffix = "Ah", step = 1},
  {key = "min_input_voltage", alarm = true, label = T["min_input_voltage"], min = 1000, max = 100000, value = 3000, suffix = "mV", step = 100},
  {key = "max_motor_current", alarm = true, label = T["max_motor_current"], min = 0, max = 500, value = 150, suffix = "A", step = 1},
  {key = "max_esc_temp", alarm = true, label = T["max_esc_temp"], min = 0, max = 200, value = 90, suffix = "°C", step = 1},
  {key = "max_bec_temp", alarm = true, label = T["max_bec_temp"], min = 0, max = 255, value = 95, suffix = "°C", step = 1},
  {key = "max_bec_current", alarm = true, label = T["max_bec_current"], min = 0, max = 50000, value = 12, suffix = "mA", step = 100},
}

-- PDF pages 12-13: these are destructive default-set command values,
-- not a readable model-type enum. Selection alone never executes a command.
local PRESETS = {
  {T.flight_Mode_choice_0, 2}, {T.flight_Mode_choice_1, 3},
  {T.flight_Mode_choice_2, 4}, {T.preset_f5a, 5}, {T.preset_car, 6},
}
-- PDF pages 2-8. Until transport exists every status value is unavailable;
-- zeroes or plausible example telemetry would imply a successful ESC read.
local STATUS_ROWS = {
  {group = T.status_identity},
  T.status_model, T.status_eeprom, T.status_programming, T.status_state,
  {group = T.status_events},
  T.status_event_time, T.status_event_type, T.status_event_code, T.status_event_text,
  {group = T.status_live},
  T.status_runtime, T.status_battery_v, T.status_battery_a, T.status_capacity,
  T.status_rpm, T.status_motor_a, T.status_timing, T.status_bec_v,
  T.status_bec_a, T.status_bec_temp, T.status_throttle, T.status_target_rpm,
  T.status_pwm, T.status_esc_temp, T.status_pulse, T.status_pulse_avg,
  {group = T.status_statistics},
  T.status_min_battery, T.status_max_motor, T.status_peak_motor,
  T.status_min_bec, T.status_max_bec_a, T.status_max_bec_temp, T.status_max_esc_temp,
}


local function open(opts)
  opts = opts or {}
  local values = {}
  local controls = {}
  local enabledStates = {}
  local cutoffs = {[0] = CELL_LIMITS[0].default, [1] = CELL_LIMITS[1].default, [2] = CELL_LIMITS[2].default}
  local cellChemistry = 0
  local changingCellBounds = false
  local positionStatus
  local lastPositionsValid
  local alarmEditing = false
  local disposed = false
  local preset = 4
  local presetResult
  local dialog

  local function fieldEnabled(spec)
    if disposed or spec.readOnly then return false end
    if spec.alarm and not alarmEditing then return false end
    if spec.dependsOn and values[spec.dependsOn] ~= 1 then return false end
    if spec.key == "max_rpm" and values.how_adj_max_rpm ~= 1 then return false end
    return true
  end

  local function updateFieldStates()
    for i = 1, #FIELDS do
      local spec = FIELDS[i]
      local key = spec.key
      local field = key and controls[key]
      if field then
        local enabled = fieldEnabled(spec)
        if enabledStates[key] ~= enabled then
          enabledStates[key] = enabled
          field:enable(enabled)
        end
      end
    end
    if positionStatus then
      local off, max, brake = values.off_position, values.max_position, values.brake_position
      local braking = values.brake == 1
      -- K-PROG checks the endpoint order even with the brake disabled.
      -- Diagnose the combination without blocking edits needed to repair it.
      local valid = off and max and brake and (
        (max > off and off >= brake and max - off >= 100 and (not braking or max - brake >= 200))
        or (max < off and off <= brake and off - max >= 100 and (not braking or brake - max >= 200))) or false
      if lastPositionsValid ~= valid then
        lastPositionsValid = valid
        positionStatus:value(valid and T.rc_valid or T.rc_invalid)
      end
    end
  end

  local function updateCellBounds()
    local chemistry = values.battery_type
    local field = controls.undervoltage_cell
    if not field or chemistry == cellChemistry then return end
    local limits = CELL_LIMITS[chemistry]
    local previous = CELL_LIMITS[cellChemistry]
    changingCellBounds = true
    -- Widen first to avoid an inverted intermediate range. Ignore any widget
    -- clamp callbacks while moving between independent chemistry values.
    field:minimum(math.min(previous.min, limits.min))
    field:maximum(limits.max)
    field:minimum(limits.min)
    field:default(limits.default)
    -- Number fields read the selected value through their getter; unlike
    -- static text widgets they do not provide a value() method on Ethos.
    cellChemistry = chemistry
    changingCellBounds = false
  end

  local function closeDialog()
    if not dialog then return end
    local handle = dialog
    dialog = nil
    pcall(function() handle:close() end)
  end

  local function confirmPreset()
    if disposed then return end
    closeDialog()
    local selected = PRESETS[preset - 1]
    if not selected then return end
    -- Capture the confirmed target, rather than reading a later selection.
    local name = selected[1]
    dialog = form.openDialog({
      title = T.preset_confirm_title,
      message = string.format(T.preset_confirm, name),
      buttons = {
        {label = "@i18n(app.btn_cancel)@", action = function()
          dialog = nil
          return true
        end},
        {label = "@i18n(app.btn_ok)@", action = function()
          dialog = nil
          if not disposed and presetResult then
            -- Only record the preview request. The PDF does not specify all
            -- model-specific default values, so do not invent a local reset.
            presetResult:value(string.format(T.preset_requested, name))
          end
          return true
        end},
      },
    })
  end

  local function dispose()
    if disposed then return end
    disposed = true
    closeDialog()
    presetResult = nil
    positionStatus = nil
    for key in pairs(values) do values[key] = nil end
    for key in pairs(controls) do controls[key] = nil end
    for key in pairs(enabledStates) do enabledStates[key] = nil end
    for key in pairs(cutoffs) do cutoffs[key] = nil end
    if opts.setEventHandler then opts.setEventHandler(nil) end
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setPaintHandler then opts.setPaintHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    opts = nil
  end

  local function goBack()
    if disposed then return end
    local onBack = opts.onBack
    dispose()
    if onBack then onBack() end
  end

  form.clear()
  header.build(T.name, {onBack = goBack})
  form.addLine(T.preview)
  local panel
  for i = 1, #FIELDS do
    local spec = FIELDS[i]
    if spec.group then
      panel = form.addExpansionPanel(spec.group)
      panel:open(false)
      if spec.group == T.basic then
        local line = panel:addLine(T.preset_target)
        form.addChoiceField(line, nil, PRESETS,
          function() return preset end,
          function(value)
            if not disposed and PRESETS[value - 1] then preset = value end
          end)
        line = panel:addLine("")
        form.addButton(line, nil, {text = T.preset_load, press = confirmPreset})
        presetResult = form.addStaticText(panel:addLine(""), nil, T.preset_none)
      elseif spec.group == T.rc then
        positionStatus = form.addStaticText(panel:addLine(T.rc_check), nil, "--")
      elseif spec.group == T.esc_status then
        panel:addLine(T.status_note)
        for j = 1, #STATUS_ROWS do
          local row = STATUS_ROWS[j]
          if type(row) == "table" then
            panel:addLine(row.group)
          else
            form.addStaticText(panel:addLine(row), nil, "--")
          end
        end
      elseif spec.group == T.alarm then
        panel:addLine(T.alarm_note)
        panel:addLine(T.alarm_independent)
        form.addBooleanField(panel:addLine(T.alarm_edit), nil,
          function() return alarmEditing end,
          function(enabled)
            if disposed then return end
            enabled = enabled == true
            if alarmEditing == enabled then return end
            alarmEditing = enabled
            updateFieldStates()
          end)
      end
    else
      local key = spec.key
      values[key] = spec.value
      local function get()
        if key == "undervoltage_cell" then return cutoffs[values.battery_type] end
        return values[key]
      end
      local function set(value)
        if not fieldEnabled(spec) or changingCellBounds then return end
        if type(value) ~= "number" then return end
        if spec.choices then
          local valid = false
          for j = 1, #spec.choices do
            if value == spec.choices[j][2] then valid = true; break end
          end
          if not valid then return end
        else
          local limits = key == "undervoltage_cell" and CELL_LIMITS[values.battery_type] or spec
          if value % 1 ~= 0 or value < limits.min or value > limits.max then return end
        end
        if key == "undervoltage_cell" then
          cutoffs[values.battery_type] = value
        elseif values[key] ~= value then
          values[key] = value
          if key == "battery_type" then updateCellBounds() end
          updateFieldStates()
        end
      end
      local line = panel:addLine(spec.label)
      local field
      if spec.choices then
        field = form.addChoiceField(line, nil, spec.choices, get, set)
      else
        field = form.addNumberField(line, nil, spec.min, spec.max, get, set)
        field:default(spec.value)
        if spec.suffix then field:suffix(spec.suffix) end
        if spec.decimals then field:decimals(spec.decimals) end
        if field.step then field:step(spec.step) end
      end
      controls[key] = field
      enabledStates[key] = true
      if spec.note then panel:addLine(spec.note) end
    end
  end

  updateFieldStates()

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if not closeKey.shouldHandleClose(category, value) then return false end
      goBack()
      return true
    end)
  end
  if opts.setCleanupHandler then opts.setCleanupHandler(dispose) end
end

return {open = open}
