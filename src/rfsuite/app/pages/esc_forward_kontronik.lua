-- KBiDir configuration with page-local edits. MSP217 reads only; Save/MSP218 disabled.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local header = requireModule("app/header.lua")
local closeKey = requireModule("app/close_key.lua")
local bus = requireModule("lib/bus.lua")
local tileGrid = requireModule("app/tile_grid.lua")
local fieldLayout = requireModule("app/field_layout.lua")
-- Stateless codec; snapshots belong to this page.
local codec = requireModule("lib/msp_esc_parameters_kontronik.lua")

local T = {
  default_parameter_set = "@i18n(app.modules.esc_tools.mfg.kontr.default_parameter_set)@",
  f5a_note = "@i18n(app.modules.esc_tools.mfg.kontr.f5a_note)@",
  load_preset = "@i18n(app.modules.esc_tools.mfg.kontr.load_preset)@",
  preset_glider = "@i18n(app.modules.esc_tools.mfg.kontr.preset_glider)@",
  preset_aircraft = "@i18n(app.modules.esc_tools.mfg.kontr.preset_aircraft)@",
  preset_helicopter = "@i18n(app.modules.esc_tools.mfg.kontr.preset_helicopter)@",
  preset_car = "@i18n(app.modules.esc_tools.mfg.kontr.preset_car)@",

  cutoff_default = "@i18n(app.modules.esc_tools.mfg.kontr.cutoff_default)@",
  expert_settings = "@i18n(app.modules.esc_tools.mfg.kontr.expert_settings)@",
  rc_check = "@i18n(app.modules.esc_tools.mfg.kontr.rc_check)@",
  rc_valid = "@i18n(app.modules.esc_tools.mfg.kontr.rc_valid)@",
  rc_invalid = "@i18n(app.modules.esc_tools.mfg.kontr.rc_invalid)@",
  alarm_edit = "@i18n(app.modules.esc_tools.mfg.kontr.alarm_edit)@",
  alarm_warning = "@i18n(app.modules.esc_tools.mfg.kontr.alarm_warning)@",
  ok = "@i18n(app.btn_ok)@",
  bluetooth = "@i18n(app.modules.esc_tools.mfg.kontr.bluetooth)@",
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
  ["prop_brake"] = "@i18n(app.modules.esc_tools.mfg.kontr.prop_brake)@",
  ["rc"] = "@i18n(app.modules.esc_tools.mfg.kontr.rc)@",
  ["rotation"] = "@i18n(app.modules.esc_tools.mfg.kontr.rotation)@",
  ["rpm_ctl"] = "@i18n(app.modules.esc_tools.mfg.kontr.rpm_ctl)@",
  ["slewrate_down"] = "@i18n(app.modules.esc_tools.mfg.kontr.slewrate_down)@",
  ["slewrate_up"] = "@i18n(app.modules.esc_tools.mfg.kontr.slewrate_up)@",
  ["startup_curr_limit"] = "@i18n(app.modules.esc_tools.mfg.kontr.startup_curr_limit)@",
  ["startuptime"] = "@i18n(app.modules.esc_tools.mfg.kontr.startuptime)@",
  ["undervoltage_behavior"] = "@i18n(app.modules.esc_tools.mfg.kontr.undervoltage_behavior)@",
  ["undervoltage_behavior_choice_0"] = "@i18n(app.modules.esc_tools.mfg.kontr.undervoltage_behavior_choice_0)@",
  ["undervoltage_behavior_choice_1"] = "@i18n(app.modules.esc_tools.mfg.kontr.undervoltage_behavior_choice_1)@",
  ["undervoltage_cell"] = "@i18n(app.modules.esc_tools.mfg.kontr.undervoltage_cell)@",
  eeprom_summary = "@i18n(app.modules.esc_tools.mfg.kontr.eeprom_summary)@",
  loading = "@i18n(app.modules.esc_tools.mfg.kontr.loading)@",
  unavailable = "@i18n(app.modules.esc_tools.mfg.kontr.unavailable)@",
  ready = "@i18n(app.modules.esc_tools.mfg.kontr.ready)@",
  msp_error = "@i18n(app.modules.esc_tools.mfg.kontr.msp_error)@",
  timeout = "@i18n(app.modules.esc_tools.mfg.kontr.timeout)@",
  incompatible = "@i18n(app.modules.esc_tools.mfg.kontr.incompatible)@",
  transport_error = "@i18n(app.modules.esc_tools.mfg.kontr.transport_error)@",
  disconnected = "@i18n(app.modules.esc_tools.mfg.kontr.disconnected)@",
  parameter_age = "@i18n(app.modules.esc_tools.mfg.kontr.parameter_age)@",
  model_age = "@i18n(app.modules.esc_tools.mfg.kontr.model_age)@",
  read_duration = "@i18n(app.modules.esc_tools.mfg.kontr.read_duration)@",
}

local FIELDS = {
  {group = T.basic},
  {key = "battery_type", label = T["battery_type"], choices = {[0] = "NiCd / NiMH", [1] = "LiPo", [2] = "LiFePo"}},
  {key = "undervoltage_behavior", label = T["undervoltage_behavior"], choices = {[0] = T.undervoltage_behavior_choice_0, [1] = T.undervoltage_behavior_choice_1}},
  {key = "undervoltage_cell", label = T["undervoltage_cell"], suffix = "mV"},
  {key = "discharge_limit", label = T["discharge_limit"], suffix = "Ah"},
  {group = T.motor},
  {key = "rotation", label = T["rotation"], choices = {[0] = "@i18n(app.modules.governor.tbl_off)@", [1] = "@i18n(app.modules.governor.tbl_on)@"}},
  {key = "fwd_bckwd", label = T["fwd_bckwd"], choices = {[0] = "@i18n(app.modules.governor.tbl_off)@", [1] = "@i18n(app.modules.governor.tbl_on)@"}},
  {key = "pole_number", label = T["pole_number"]},
  {key = "gear_ratio", label = T["gear_ratio"]},
  {key = "brake", label = T["brake"], choices = {[0] = "@i18n(app.modules.governor.tbl_off)@", [1] = "@i18n(app.modules.governor.tbl_on)@"}},
  {key = "prop_brake", label = T["prop_brake"], choices = {[0] = "@i18n(app.modules.governor.tbl_off)@", [1] = "@i18n(app.modules.governor.tbl_on)@"}},
  {key = "rpm_ctl", label = T["rpm_ctl"], choices = {[0] = "@i18n(app.modules.governor.tbl_off)@", [1] = "@i18n(app.modules.governor.tbl_on)@"}},
  {key = "how_adj_max_rpm", label = T["how_adj_max_rpm"], choices = {[0] = T.how_adj_max_rpm_choice_0, [1] = T.how_adj_max_rpm_choice_1}},
  {key = "max_rpm", label = T["max_rpm"]},
  {key = "startuptime", label = T["startuptime"], suffix = "s"},
  {key = "p-gain", label = T["p-gain"]},
  {key = "motor_resist", label = T["motor_resist"], suffix = "mOhm"},
  {key = "PWM_min", label = T["PWM_min"], suffix = "%"},
  {key = "slewrate_up", label = T["slewrate_up"], suffix = "ms"},
  {key = "slewrate_down", label = T["slewrate_down"], suffix = "ms"},
  {key = "extra_smooth_IU", label = T["extra_smooth_IU"], choices = {[0] = "@i18n(app.modules.governor.tbl_off)@", [1] = "@i18n(app.modules.governor.tbl_on)@"}},
  {key = "alternate_startup", label = T["alternate_startup"], choices = {[0] = "@i18n(app.modules.governor.tbl_off)@", [1] = "@i18n(app.modules.governor.tbl_on)@"}},
  {key = "startup_curr_limit", label = T["startup_curr_limit"], suffix = "A"},
  {group = T.rc},
  {key = "act_impulse_length", label = T["act_impulse_length"], suffix = "us"},
  {key = "off_position", label = T["off_position"], suffix = "us"},
  {key = "max_position", label = T["max_position"], suffix = "us"},
  {key = "brake_position", label = T["brake_position"], suffix = "us"},
  {key = "bec_voltage", label = T["bec_voltage"], suffix = "mV"},
  {group = T.bluetooth},
  {key = "bt_disable_motor_renable_button", label = T["bt_disable_motor_renable_button"], choices = {[0] = "@i18n(app.modules.governor.tbl_off)@", [1] = "@i18n(app.modules.governor.tbl_on)@"}},
  {key = "bt_disable_motor_renable_motor_stop", label = T["bt_disable_motor_renable_motor_stop"], choices = {[0] = "@i18n(app.modules.governor.tbl_off)@", [1] = "@i18n(app.modules.governor.tbl_on)@"}},
  {group = T.esc_status},
  {group = T.alarm},
  {key = "max_discharge", label = T["max_discharge"], suffix = "Ah"},
  {key = "min_input_voltage", label = T["min_input_voltage"], suffix = "mV"},
  {key = "max_motor_current", label = T["max_motor_current"], suffix = "A"},
  {key = "max_esc_temp", label = T["max_esc_temp"], suffix = "Â°C"},
  {key = "max_bec_temp", label = T["max_bec_temp"], suffix = "Â°C"},
  {key = "max_bec_current", label = T["max_bec_current"], suffix = "mA"},
}

-- Draft UI ranges only: no write authorization/capability is inferred from these.
-- Native number widgets use integer ticks with decimals; retain received values
-- outside a provisional range by extending the widget bounds, never by clamping.
-- APK A6/A11: descendants of idcBatteryExperts and idcMotorExperts.
local EXPERT_KEYS = {undervoltage_behavior=true,undervoltage_cell=true,discharge_limit=true,
  PWM_min=true,slewrate_up=true,slewrate_down=true,extra_smooth_IU=true,
  alternate_startup=true,startup_curr_limit=true}
local ALARM_KEYS = {max_discharge=true,min_input_voltage=true,max_motor_current=true,
  max_esc_temp=true,max_bec_temp=true,max_bec_current=true}
local EDIT_META = {
  discharge_limit = {min=0,max=1000,decimals=1},
  pole_number = {min=2,max=100,step=2}, gear_ratio = {min=100,max=65535,decimals=2},
  max_rpm = {min=0,max=1000000,step=100}, startuptime = {min=4000,max=60000,decimals=3,step=1000},
  ["p-gain"] = {min=0,max=10}, motor_resist = {min=1,max=1000}, PWM_min = {min=2,max=100},
  slewrate_up = {min=200,max=60000,step=100}, slewrate_down = {min=200,max=60000,step=100},
  startup_curr_limit = {min=10,max=100}, off_position = {min=500,max=2500},
  max_position = {min=500,max=2500}, brake_position = {min=500,max=2500},
  bec_voltage = {min=5000,max=8000,step=100}, max_discharge = {min=0,max=1000,decimals=1},
  min_input_voltage = {min=12000,max=60000,step=100}, max_motor_current = {min=0,max=1000},
  max_esc_temp = {min=20,max=100}, max_bec_temp = {min=20,max=100},
  max_bec_current = {min=0,max=50000,step=100},
}
local CUTOFF_META = {[0]={min=700,max=1200,step=100,default=800},[1]={min=2700,max=3500,step=100,default=3000},[2]={min=1800,max=2600,step=100,default=2300}}
-- Exact captured layouts only; names alone never grant a capability.
local ALARM_LAYOUTS = {["KOLIBRI140+LV"]={count=41,version=0x0402},["KOSMIK200+HV"]={count=39,version=0x0401}}
local DEPENDS = {prop_brake="brake", how_adj_max_rpm="rpm_ctl", max_rpm="rpm_ctl",
  startuptime="rpm_ctl", ["p-gain"]="rpm_ctl", motor_resist="rpm_ctl"}
-- Additional local UI restrictions; never device permissions or preset defaults.
local PREVIEW_CHOICES = {{"--",0},{T.preset_glider,2},{T.preset_aircraft,3},
  {T.preset_helicopter,4},{"F5A",5},{T.preset_car,6}}
local PREVIEW_GROUPS = {brake="brake",prop_brake="brake",rpm_ctl="governor",
  how_adj_max_rpm="governor",max_rpm="governor",startuptime="governor",
  ["p-gain"]="governor",motor_resist="governor",slewrate_up="ramp",
  slewrate_down="ramp",fwd_bckwd="reverse",brake_position="endpoint"}
local PREVIEW_MASKS = {
  [2]={governor=true,reverse=true}, [3]={reverse=true},
  [4]={brake=true,ramp=true,reverse=true,endpoint=true}, [6]={governor=true},
}
local function disabledPreset() end

local function nativeNumber(value)
  return type(value)=="number" and value>=-0x80000000 and value<=0x7FFFFFFF
end
local CUTOFF_POINTERS = {[0]=0x2008,[1]=0x200A,[2]=0x200C}
for i=1,#FIELDS do
  local spec=FIELDS[i]
  if spec.choices then
    spec.choiceList={}
    local value=0
    while spec.choices[value] do
      spec.choiceList[#spec.choiceList+1]={spec.choices[value],value}
      value=value+1
    end
  end
end

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
  local disposed, busy, needsBuild = false, false, false
  local connected, armed, transport, apiReady
  local epoch = 0
  local snapshot, reader
  local alarmEnabled, alarmDialog, alarmSwitch, alarmSwitchEnabled = false, nil, nil, nil
  local expertEnabled,expertSwitch,expertSwitchEnabled,deviceSupported=false,nil,nil,false
  local preview=0
  local previewSwitch,previewSwitchEnabled
  local cutoffMin,cutoffMax
  local gearConfirmed=false
  local gearDialog,gearProposal
  local gearEpoch=0
  local building=false
  local cutoffDefaultField,cutoffDefaultText
  local rcField,rcText
  local baseline,alarmCapabilities={},{}
  local state = "loading"
  local draft, previous, cutoffs, controls, enabled = {}, {}, {}, {}, {}
  local runtime = {logTag="esc_kontronik_local", sources={{mspModule=codec}}, data=draft}
  runtime.dataRef = {data=draft}
  runtime.controlRef = {runtime=runtime}
  local buildForm, reload, goBack
  local summaryWidth = lcd and lcd.getWindowSize and lcd.getWindowSize()-12 or 460
  local modelWidth = math.floor((summaryWidth+12)/2)-20

  local function clear(t) for key in pairs(t) do t[key]=nil end end
  local function editable(key)
    if disposed or busy or armed or draft[key]==nil then return false end
    -- Car grants local draft editing only; no active ESC preset is inferred
    -- and Expert must not bypass an absent or different preview target.
    if key=="fwd_bckwd" and preview~=6 then return false end
    local mask=PREVIEW_MASKS[preview]
    if mask and mask[PREVIEW_GROUPS[key]] then return false end
    if EXPERT_KEYS[key] and not expertEnabled then return false end
    if ALARM_KEYS[key] and (not alarmEnabled or not alarmCapabilities[key]) then return false end
    local dependency=DEPENDS[key]
    if dependency and draft[dependency]~=1 then return false end
    if key=="max_rpm" and draft.how_adj_max_rpm~=1 then return false end
    return true
  end
  local function metaFor(key)
    if key=="undervoltage_cell" then return CUTOFF_META[draft.battery_type] end
    return EDIT_META[key]
  end
  local function rangeValid(key,value)
    local meta=metaFor(key)
    return meta and value>=meta.min and value<=meta.max and (not meta.step or (value-meta.min)%meta.step==0)
  end
  local function updateDiagnostics()
    if cutoffDefaultField then
      local meta=CUTOFF_META[draft.battery_type]
      local value=meta and (meta.default.." mV") or "--"
      if cutoffDefaultText~=value then cutoffDefaultText=value;cutoffDefaultField:value(value) end
    end
    if rcField then
      local off,max,brake=draft.off_position,draft.max_position,draft.brake_position
      local value="--"
      if off and max and brake and draft.brake~=nil then
        local valid=off>=500 and off<=2500 and max>=500 and max<=2500
          and math.abs(max-off)>=100
          and ((max>off and off>=brake and (draft.brake==0 or max>=brake+200))
            or (max<off and off<=brake and (draft.brake==0 or max<=brake-200)))
          and (draft.brake==0 or (brake>=500 and brake<=2500))
        value=valid and T.rc_valid or T.rc_invalid
      end
      if value~=rcText then rcText=value;rcField:value(value) end
    end

  end
  local function canEditAlarms()
    return not disposed and not busy and not armed and connected~=false and snapshot~=nil and snapshot.parametersAvailable and next(alarmCapabilities)~=nil
  end
  local function canEditExperts()
    return not disposed and not busy and not armed and connected~=false and deviceSupported
  end
  local function updateStates()
    updateDiagnostics()
    if previewSwitch then
      local value=not disposed and not busy and not armed and connected~=false and state=="ready"
      if previewSwitchEnabled~=value then previewSwitchEnabled=value;previewSwitch:enable(value) end
    end
    if expertSwitch then
      local value=canEditExperts()
      if expertSwitchEnabled~=value then expertSwitchEnabled=value;expertSwitch:enable(value) end
    end
    if alarmSwitch then
      local value=canEditAlarms()
      if alarmSwitchEnabled~=value then alarmSwitchEnabled=value;alarmSwitch:enable(value) end
    end
    for key,field in pairs(controls) do
      local value=editable(key)
      if enabled[key]~=value then enabled[key]=value;field:enable(value) end
    end
  end
  local function getPreview() return preview end
  local function setPreview(value)
    if disposed or busy or armed or connected==false or state~="ready" then return end
    if value~=0 and value~=2 and value~=3 and value~=4 and value~=5 and value~=6 then return end
    if preview==value then return end
    if (preview==5)~=(value==5) then needsBuild=true end
    preview=value
    updateStates()
  end
  local function getExpertEnabled() return expertEnabled end
  local function setExpertEnabled(value)
    if not canEditExperts() then return end
    value=value==true
    if expertEnabled==value then return end
    expertEnabled=value
    if not value then
      for chemistry,pointer in pairs(CUTOFF_POINTERS) do cutoffs[chemistry]=snapshot.byPointer[pointer] end
      baseline.undervoltage_cell=cutoffs[draft.battery_type]
      building=true
      for key in pairs(EXPERT_KEYS) do
        draft[key]=baseline[key];previous[key]=baseline[key]
        local field=controls[key]
        if field and (EDIT_META[key] or key=="undervoltage_cell") and baseline[key]~=nil then field:default(key=="undervoltage_cell" and CUTOFF_META[draft.battery_type].default or baseline[key]) end
      end
      building=false
    end
    updateStates()
  end
  local function getAlarmEnabled() return alarmEnabled end
  local function dismissAlarmNotice()
    alarmDialog=nil
    return true
  end
  local alarmNotice = {title=T.alarm,message=T.alarm_warning,
    buttons={{label=T.ok,action=dismissAlarmNotice}},wakeup=function() end,paint=function() end}
  local function setAlarmEnabled(value)
    if not canEditAlarms() then return end
    value=value==true
    if alarmEnabled==value then return end
    alarmEnabled=value
    updateStates()
    if value then alarmDialog=form.openDialog(alarmNotice) end
  end
  local function closeAlarmNotice()
    if alarmDialog then alarmDialog:close();alarmDialog=nil end
  end
  local function clearGearConfirmation()
    gearEpoch=gearEpoch+1
    gearProposal=nil
    if gearDialog then gearDialog:close();gearDialog=nil end
  end
  local function confirmGear(value)
    if gearProposal~=nil then return end
    gearEpoch=gearEpoch+1
    local token=gearEpoch
    local old=previous.gear_ratio
    gearProposal=value
    gearDialog=form.openDialog({
      title=T.gear_ratio,
      -- Temporary copy until the final i18n pass requested by the developer.
      message="Change the ESC Main Gear Ratio? Rotorflight uses the main gear ratio configured in the flight controller for rotor-speed calculation.",
      buttons={
        {label="Confirm",action=function()
          if token~=gearEpoch then return true end
          if editable("gear_ratio") and draft.gear_ratio==old then
            draft.gear_ratio=value;previous.gear_ratio=value
            gearConfirmed=true
          end
          gearProposal,gearDialog=nil,nil
          gearEpoch=gearEpoch+1
          updateStates()
          return true
        end},
        {label="Cancel",action=function()
          if token==gearEpoch then
            gearProposal,gearDialog=nil,nil;gearEpoch=gearEpoch+1
          end
          return true
        end},
      },wakeup=function() end,paint=function() end,
    })
  end
  function runtime:registerField(key,field) controls[key]=field end
  function runtime:refreshDirty()
    if building then
      for key in pairs(draft) do draft[key]=previous[key] end
      return
    end
    -- Pool setters are detached on close. Validate local callbacks too, so stale
    -- events and changes to disabled controls cannot mutate an unrelated draft.
    for i=1,#FIELDS do
      local spec=FIELDS[i]
      local key=spec.key
      if key and controls[key] and draft[key]~=previous[key] then
        local value=draft[key]
        local valid=editable(key) and type(value)=="number" and value%1==0
        if spec.choices then valid=valid and spec.choices[value]~=nil
        else
          valid=valid and (rangeValid(key,value) or value==baseline[key])
          if valid and key=="pole_number" then valid=value%2==0 end
        end
        if not valid then draft[key]=previous[key]
        elseif key=="gear_ratio" and not gearConfirmed then
          -- The field-layout setter has proposed the value; restore before
          -- opening the dialog so only explicit confirmation updates the draft.
          draft[key]=previous[key]
          confirmGear(value)
        end
      end
    end
    local chemistryChanged=false
    local oldChemistry=previous.battery_type
    if draft.battery_type~=oldChemistry then
      if oldChemistry~=nil then cutoffs[oldChemistry]=previous.undervoltage_cell end
      draft.undervoltage_cell=cutoffs[draft.battery_type]
      baseline.undervoltage_cell=snapshot.byPointer[CUTOFF_POINTERS[draft.battery_type]]
      chemistryChanged=true
      -- Static rows have no getter: rebuild even when both chemistries use
      -- static text (oversized or absent), otherwise the old text survives.
      if not controls.undervoltage_cell or not nativeNumber(draft.undervoltage_cell) then needsBuild=true end
    elseif draft.undervoltage_cell~=previous.undervoltage_cell and draft.battery_type~=nil then
      cutoffs[draft.battery_type]=draft.undervoltage_cell
    end
    clear(previous)
    for key,value in pairs(draft) do previous[key]=value end
    if chemistryChanged and controls.undervoltage_cell and nativeNumber(draft.undervoltage_cell) then
      local field=controls.undervoltage_cell
      local meta=metaFor("undervoltage_cell")
      local value=draft.undervoltage_cell
      local minimum=math.min(meta.min,value,baseline.undervoltage_cell or value)
      local maximum=math.max(meta.max,value,baseline.undervoltage_cell or value)
      -- Native bound setters can clamp and call back. Restore the new chemistry's
      -- previous value while widening first, then apply its own bounds/default.
      building=true
      field:minimum(math.min(cutoffMin,minimum));field:maximum(math.max(cutoffMax,maximum))
      field:minimum(minimum);field:maximum(maximum);field:step(meta.step);field:default(meta.default)
      building=false
      cutoffMin,cutoffMax=minimum,maximum
    end
    updateStates()
  end

  local function summary()
    if state~="ready" then return T[state] or T.transport_error end
    if not snapshot.parametersAvailable and not snapshot.modelAvailable then return T.unavailable end
    local name=snapshot.modelAvailable and snapshot.model or T.name
    local suffix=""
    if snapshot.eepromAvailable then
      local hex=string.format("%04X",snapshot.eepromVersion)
      local major,minor=tonumber(hex:sub(1,2)),tonumber(hex:sub(3,4))
      local version=major and minor and (tostring(major).."."..hex:sub(3,4)) or hex
      suffix=" / "..string.format(T.eeprom_summary,version)
    end
    local suffixWidth=0
    if lcd and lcd.getTextSize then
      if lcd.font then lcd.font(FONT_STD) end
      suffixWidth=lcd.getTextSize(suffix)
    end
    return tileGrid.fitText(name,summaryWidth-suffixWidth,FONT_STD)..suffix
  end
  local function textLine(text)
    local line=form.addLine("")
    local slot=form.getFieldSlots(line,{0})[1]
    form.addStaticText(line,{x=0,y=slot.y,w=summaryWidth,h=slot.h},text,LEFT)
  end
  local function releaseFields()
    fieldLayout.releaseRuntime(runtime)
    clear(controls);clear(enabled)
    alarmSwitch,alarmSwitchEnabled=nil,nil
    expertSwitch,expertSwitchEnabled=nil,nil
    rcField,rcText=nil,nil
    cutoffDefaultField,cutoffDefaultText=nil,nil
    cutoffMin,cutoffMax=nil,nil
    previewSwitch,previewSwitchEnabled=nil,nil
  end
  local function invalidate(nextState)
    clearGearConfirmation();gearConfirmed=false
    closeAlarmNotice();alarmEnabled=false;expertEnabled=false;deviceSupported=false;preview=0
    epoch=epoch+1
    if reader then reader:cancel();reader=nil end
    snapshot=nil;state=nextState;busy=false;needsBuild=true
    releaseFields()
    clear(draft);clear(previous);clear(cutoffs);clear(baseline);clear(alarmCapabilities)
  end
  reload=function()
    if disposed or busy or connected==false or armed then return end
    invalidate("loading");busy=true
    local token=epoch
    reader=codec.newReader(function(message) bus.publish("msp.request",message) end,function(data)
      if disposed or token~=epoch then return end
      snapshot,reader=data,nil
      for key,value in pairs(data.fields) do
        local meta=EDIT_META[key]
        draft[key]=meta and meta.decimals and math.floor(value*10^meta.decimals+0.5) or value
      end
      for chemistry,pointer in pairs(CUTOFF_POINTERS) do cutoffs[chemistry]=data.byPointer[pointer] end
      for key,value in pairs(draft) do previous[key]=value;baseline[key]=value end
      local layout=data.modelAvailable and ALARM_LAYOUTS[data.model]
      local versionPointer=data.byPointer[0x2002]
      if layout and data.eepromAvailable and data.eepromVersion==layout.version and versionPointer==layout.version
        and data.count==layout.count and data.byPointer[0x2000]~=nil and data.byPointer[0x4004]~=nil
        and data.byPointer[0x4058]~=nil
        and ((layout.count==41 and data.byPointer[0x2036]~=nil and data.byPointer[0x2038]~=nil)
          or (layout.count==39 and data.byPointer[0x2036]==nil and data.byPointer[0x2038]==nil)) then
        deviceSupported=true
        for key in pairs(ALARM_KEYS) do
          -- Rated motor/BEC currents are not part of this contract: do not invent their limits.
          if key~="max_motor_current" and key~="max_bec_current" and draft[key]~=nil then alarmCapabilities[key]=true end
        end
      end
      busy,state,needsBuild=false,"ready",true
    end,function(kind)
      if disposed or token~=epoch then return end
      snapshot,reader=nil,nil;busy,state,needsBuild=false,kind,true
    end)
  end
  local function onSession(update)
    if disposed then return end
    local ready=update.handshake and update.handshake.apiVersion
    if (update.connected==false and connected~=false) or (update.isArmed==true and not armed)
      or (transport~=nil and update.mspTransport~=transport) or (apiReady==true and ready==false) then
      invalidate("disconnected")
    end
    if connected~=update.connected or armed~=(update.isArmed==true) then needsBuild=true end
    connected,armed,transport,apiReady=update.connected,update.isArmed==true,update.mspTransport,ready
  end
  local function dispose()
    if disposed then return end
    invalidate("disconnected");disposed=true
    bus.unsubscribe("session.update",onSession)
    runtime.controlRef.runtime=nil;runtime.dataRef.data=nil
    if opts.setEventHandler then opts.setEventHandler(nil) end
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setPaintHandler then opts.setPaintHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    opts=nil
  end
  goBack=function()
    if disposed then return end
    local onBack=opts.onBack;dispose();if onBack then onBack() end
  end
  buildForm=function()
    releaseFields()
    building=true
    form.clear()
    -- UI edits are local only: deliberately no Save or preset callback.
    header.build(T.name,{onBack=goBack,onReload=not busy and connected~=false and not armed and reload or nil})
    textLine(summary())
    if state=="ready" then
      previewSwitch=form.addChoiceField(form.addLine(T.default_parameter_set),nil,PREVIEW_CHOICES,getPreview,setPreview)
      if preview==5 then textLine(T.f5a_note) end
      local button=form.addButton(form.addLine(""),nil,{text=T.load_preset,press=disabledPreset})
      button:enable(false)
      expertSwitch=form.addBooleanField(form.addLine(T.expert_settings),nil,getExpertEnabled,setExpertEnabled)
    end
    local panel
    for i=1,#FIELDS do
      local spec=FIELDS[i]
      if spec.group then
        panel=form.addExpansionPanel(spec.group);panel:open(false)
        if spec.group==T.rc then rcField=form.addStaticText(panel:addLine(T.rc_check),nil,"--") end
        if spec.group==T.alarm then
          alarmSwitch=form.addBooleanField(panel:addLine(T.alarm_edit),nil,getAlarmEnabled,setAlarmEnabled)
        end
        if spec.group==T.esc_status then
          for j=1,#STATUS_ROWS do
            local row=STATUS_ROWS[j]
            if type(row)=="table" then panel:addLine(row.group)
            else
              local value="--"
              if snapshot and row==T.status_model and snapshot.modelAvailable then
                value=tileGrid.fitText(snapshot.model,modelWidth,FONT_STD)
              elseif snapshot and row==T.status_eeprom and snapshot.eepromAvailable then
                value=string.format("%04X",snapshot.eepromVersion)
              end
              form.addStaticText(panel:addLine(row),nil,value)
              if row==T.status_eeprom then
                form.addStaticText(panel:addLine(T.parameter_age),nil,snapshot and snapshot.parametersAvailable and (snapshot.parameterAge.." ms") or "--")
                form.addStaticText(panel:addLine(T.model_age),nil,snapshot and snapshot.modelAvailable and (snapshot.modelAge.." ms") or "--")
                form.addStaticText(panel:addLine(T.read_duration),nil,snapshot and string.format("%.1f s",snapshot.retrievalSeconds) or "--")
              end
            end
          end
        end
      else
        local value=draft[spec.key]
        local meta=metaFor(spec.key)
        -- Ethos number widgets use signed integer ticks. Preserve larger raw U32
        -- values as static text instead of overflowing their native bounds.
        if value~=nil and ((spec.choices and spec.choices[value])
          or (meta and nativeNumber(value))) then
          local fieldSpec={key=spec.key,choices=spec.choiceList,suffix=spec.suffix}
          if meta then
            fieldSpec.min=math.min(meta.min,value);fieldSpec.max=math.max(meta.max,value)
            fieldSpec.decimals=meta.decimals;fieldSpec.step=meta.step;fieldSpec.default=value
            if spec.key=="undervoltage_cell" then
              cutoffMin,cutoffMax=fieldSpec.min,fieldSpec.max;fieldSpec.default=meta.default
            end
          end
          fieldLayout.buildSingle(runtime,spec.label,fieldSpec,panel)
        else
          local display="--"
          if value~=nil then
            display=meta and meta.decimals and string.format("%."..meta.decimals.."f",value/10^meta.decimals) or tostring(value)
            if spec.suffix then display=display.." "..spec.suffix end
          end
          form.addStaticText(panel:addLine(spec.label),nil,display)
        end
        if spec.key=="undervoltage_cell" then
          cutoffDefaultField=form.addStaticText(panel:addLine(T.cutoff_default),nil,"--")
        end
      end
    end
    building=false
    updateStates();needsBuild=false
  end
  local function wakeup()
    if disposed then return end
    if reader then reader:wakeup() end
    if needsBuild then buildForm() end
  end
  if opts.setWakeupHandler then opts.setWakeupHandler(wakeup) end
  if opts.setEventHandler then opts.setEventHandler(function(category,value)
    if not closeKey.shouldHandleClose(category,value) then return false end
    goBack();return true
  end) end
  if opts.setCleanupHandler then opts.setCleanupHandler(dispose) end
  bus.subscribe("session.update",onSession)
  reload();wakeup()
end

return {open=open}
