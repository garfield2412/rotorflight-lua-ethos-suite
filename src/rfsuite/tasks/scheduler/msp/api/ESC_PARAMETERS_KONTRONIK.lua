local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "ESC_PARAMETERS_KONTRONIK"
local MSP_API_CMD_READ = 217
local MSP_API_CMD_WRITE = 218
local MSP_REBUILD_ON_WRITE = false
local MSP_SIGNATURE = 0x4B
local MSP_HEADER_BYTES = 2

local flight_Mode = {"@i18n(api.ESC_PARAMETERS_KONTRONIK.tbl_sailplane)@", "@i18n(api.ESC_PARAMETERS_KONTRONIK.tbl_motorplane)@", "@i18n(api.ESC_PARAMETERS_KONTRONIK.tbl_helicopter)@", "@i18n(api.ESC_PARAMETERS_KONTRONIK.tbl_auto)@"}
local rotation = {"@i18n(api.ESC_PARAMETERS_KONTRONIK.tbl_cw)@", "@i18n(api.ESC_PARAMETERS_KONTRONIK.tbl_ccw)@"}
--local bec_voltage = {"4800mv", "4900mv", "5000mv", "5100mv", "5200mv", "5300mv", "5400mv", "5500mv", "5600mv", "5700mv", "5800mv", "5900mv", "6000mV", "6100mV", "6200mV", "6300mV", "6400mV", "6500mV", "6600mV", "6700mV", "6800mV", "6900mV", "7000mV", "7100mV", "7200mV", "7300mV", "7400mV", "7500mV", "7600mV", "7700mV", "7800mV", "7900mV", "8000mV"}
local pole_number = {"2", "4", "6", "8", "10", "12", "14", "16", "18", "20"}
local battery_type = {"NiCd / NiMH", "LiPo", "LiFePo"}
local undervoltage_behavior = {"@i18n(api.ESC_PARAMETERS_KONTRONIK.tbl_undervoltage_behavior_slow)@", "@i18n(api.ESC_PARAMETERS_KONTRONIK.tbl_undervoltage_behavior_shut)@"}
local how_adj_max_rpm = {"@i18n(api.ESC_PARAMETERS_KONTRONIK.tbl_how_adj_max_rpm_idleup)@", "@i18n(api.ESC_PARAMETERS_KONTRONIK.tbl_how_adj_max_rpm_govstore)@"}

local MSP_API_STRUCTURE_READ_DATA = {
  {field = "esc_signature", type="U8", apiVersion=12.07, simResponse={ 75 }, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.esc_signature)@" },
  {field = "esc_command", type = "U8", apiVersion = 12.07, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.esc_command)@"},
  {field = "esc_model", type = "U128", apiVersion = 12.07, simResponse = {75, 79, 76, 73, 66, 82, 73, 49, 52, 48, 43, 76, 86, 32, 32, 32}, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.esc_model)@"},
  {field = "bec_voltage", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, unit = "mV",help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.bec_voltage)@"},
  {field = "rotation", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.rotation)@" },
  {field = "fwd_bckwd", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.fwd_bckwd)@" },
  {field = "flight_Mode", type = "U8", apiVersion = 12.07, simResponse = { 2 }, default = 2, min = 0, max = #flight_Mode, tableIdxInc = -1, table = flight_Mode, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.flight_Mode)@" },
  {field = "battery_type", type = "U8", apiVersion = 12.07, simResponse = { 1 }, default = 1, min = 0, max = #battery_type, tableIdxInc = -1, table = battery_type, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.battery_type)@" },
  {field = "undervoltage_behavior", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0, min = 0, max = #undervoltage_behavior, tableIdxInc = -1, table = undervoltage_behavior, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.undervoltage_behavior)@" },
  {field = "undervoltage_cell", type = "U16", apiVersion = 12.07, simResponse = {184, 11},min = 2800, max = 3700, step = 100, unit = "mV", help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.undervoltage_cell)@" },
  --{field = "discharge_limiter_act", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0},
  {field = "discharge_limit", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 20, step = 1, unit = "mAh", help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.discharge_limit)@" },
  {field = "pole_number", type = "U8", apiVersion = 12.07, simResponse = {4}, tableIdxInc = -1, table = pole_number, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.pole_number)@" },
  {field = "gear_ratio", type = "U16", apiVersion = 12.07, simResponse = {100, 0}, min = 100, max = 2000,step = 1, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.gear_ratio)@" },
  {field = "brake", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0},
  {field = "prop_brake", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0},
  {field = "rpm_ctl", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0},
  {field = "how_adj_max_rpm", type = "U8", apiVersion = 12.07, simResponse = { 4, 64, 117, 10, 17 }, default = 0, min = 0, max = #how_adj_max_rpm, tableIdxInc = -1, table = how_adj_max_rpm},
  {field = "max_rpm", type = "U16", apiVersion = 12.07, simResponse = { 48, 117 }, default = 30000, min = 0, max = 100000, step = 100},
  {field = "startuptime", type = "U8", apiVersion = 12.07, simResponse = {5}, default = 5, min = 0, max = 60, unit = "s"},
  {field = "p-gain", type = "U8", apiVersion = 12.07, simResponse = {4}, default = 4, min = 0, max = 15},
  {field = "motor_resist", type = "U8", apiVersion = 12.07, simResponse = {10}, default = 10, min = 0, max = 15, unit = "mOhm"},
  {field = "PWM_min", type = "U8", apiVersion = 12.07, simResponse = {1}, min = 0, max = 100, step = 1, unit = "%", help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.PWM_min)@" },
  {field = "slewrate_up", type = "U16", apiVersion = 12.07, simResponse = {64, 31}, default = 8000, min = 0, max = 65535, unit = "ms"},
  {field = "slewrate_down", type = "U16", apiVersion = 12.07, simResponse = {160, 15}, default = 4000, min = 0, max = 65535, unit = "ms"},
  {field = "extra_smooth_IU", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0},
  {field = "alternate_startup", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0},
  {field = "startup_curr_limit", type = "U8", apiVersion = 12.07, simResponse = {100}, default = 150, min = 0, max = 255, step = 1, unit = "A"},
  {field = "max_discharge", type = "U16", apiVersion = 12.07, simResponse = {86, 32, 10, 0, 0}, default = 15, min = 0, max = 50, step = 1,  unit = "Ah", help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.max_discharge)@" },
  {field = "min_input_voltage", type = "U16", apiVersion = 12.07, simResponse = {76, 32, 172, 13, 0}, default = 3000, min = 1000, max = 100000, step = 100, unit = "mV", help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.min_input_voltage)@" },
  {field = "max_motor_current", type = "U16", apiVersion = 12.07, simResponse = {78, 32, 150, 0, 0}, default = 150, min = 0, max = 500, step = 1, unit = "A", help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.max_motor_current)@" },
  {field = "max_esc_temp", type = "U8", apiVersion = 12.07, simResponse = {90}, default = 90, min = 0, max = 200, step = 1,  unit = "°C", help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.max_esc_temp)@" },
  {field = "max_bec_temp", type = "U8", apiVersion = 12.07, simResponse = {95}, default = 95, min = 0, max = 255, step = 1, unit = "°C", help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.max_bec_temp)@" },
  {field = "max_bec_current", type = "U8", apiVersion = 12.07, simResponse = {12}, default = 12, min = 0, max = 50, step = 1, unit = "A", help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.max_bec_current)@" },
  {field = "act_impulse_length", type = "U16", apiVersion = 12.07, simResponse = {76, 4}, default = 1100, min = 500, max = 2100, step = 10, unit = "us"},
  {field = "off_position", type = "U16", apiVersion = 12.07, simResponse = {76, 4}, default = 1100, min = 500, max = 2100, step = 10, unit = "us", help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.off_position)@" },
  {field = "max_position", type = "U16", apiVersion = 12.07, simResponse = {148, 7}, default = 1940, min = 500, max = 2100, step = 10, unit = "us", help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.max_position)@" },
  {field = "brake_position", type = "U16", apiVersion = 12.07, simResponse = {76, 4}, default = 1100, min = 500, max = 2100, step = 10, unit = "us", help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.brake_position)@" },
  {field = "bt_disable_motor_renable_button", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.bt_disable_motor_renable_button)@" },
  {field = "bt_disable_motor_renable_motor_stop", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.bt_disable_motor_renable_motor_stop)@" },
  {field = "status_bec_v", type = "U8", apiVersion = 12.07, simResponse = { 60 }, unit = "V"},
  {field = "status_bec_a", type = "U8", apiVersion = 12.07, simResponse = { 5 }, unit = "A"},
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local defaultData = {}

local handlers = core.createHandlers()

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

local lastWriteUUID = nil

local writeDoneRegistry = setmetatable({}, {__mode = "kv"})

local function getFieldDefByName(fieldName)
    for _, def in ipairs(MSP_API_STRUCTURE_READ) do
        if def.field == fieldName then return def end
    end
    return nil
end

-- Build simulator payload for Kontronik register format from field simResponse values.
-- Pair format in field simResponse:
--   {reg_lo, reg_hi, val_b0, val_b1, val_b2[, val_b3]}
local function buildKontronikSimulatorResponse()
    local out = {}

    local sigDef = getFieldDefByName("esc_signature")
    local cmdDef = getFieldDefByName("esc_command")
    local modelDef = getFieldDefByName("esc_model")

    out[#out + 1] = (sigDef and sigDef.simResponse and sigDef.simResponse[1]) or MSP_SIGNATURE
    out[#out + 1] = (cmdDef and cmdDef.simResponse and cmdDef.simResponse[1]) or 0

    if modelDef and modelDef.simResponse then
        for i = 1, #modelDef.simResponse do out[#out + 1] = modelDef.simResponse[i] end
    else
        for i = 1, 16 do out[#out + 1] = 32 end
    end

    local pairs = {}
    for _, def in ipairs(MSP_API_STRUCTURE_READ) do
        local sr = def.simResponse
        if type(sr) == "table" and #sr >= 5 and #sr <= 6 then
            local regLo, regHi = sr[1], sr[2]
            if type(regLo) == "number" and type(regHi) == "number" then
                local entry = {}
                for i = 1, #sr do entry[#entry + 1] = sr[i] end
                pairs[#pairs + 1] = entry
            end
        end
    end

    out[#out + 1] = #pairs

    for i = 1, #pairs do
        local p = pairs[i]
        for j = 1, #p do out[#out + 1] = p[j] end
    end

    return out
end

local KONTRONIK_SIMULATOR_RESPONSE = buildKontronikSimulatorResponse()

-- Kontronik fixed read format:
-- [1]   U8  esc_signature
-- [2]   U8  esc_command
-- [3..18] U128 esc_model (16 bytes, 0-terminated)
-- [19]  U8  pair_count
-- then pair_count * (U16 register_id + U24 value), all little-endian.
local REG_TO_FIELD = {
    --[8192] = "unknown_reg_8192",
    --[8194] = "unknown_reg_8194",
    --[8200] = "unknown_reg_8200",
    [8202] = "undervoltage_cell",
    --[8204] = "unknown_reg_8204",
    [8206] = "EMK_brake_positive",
    [8208] = "bec_voltage",
    --[8210] = "unknown_reg_8210",
    --[8212] = "unknown_reg_8212",
    [8214] = "brake_position",
    [8216] = "off_position",
    [8218] = "max_position",
    [8220] = "rpm_ctl",
    --[8222] = "unknown_reg_8222",
    [8226] = "slewrate_up",
    [8228] = "slewrate_down",
    [8230] = "startuptime",
    [8232] = "p-gain",
    [8234] = "motor_resist",
    [8236] = "discharge_limit", -- (0 = off, 1-20 = mAh)
    [8238] = "discharge_limiter_act",
    --[8244] = "unknown_reg_8244",
    [8246] = "telemetry",
    [8252] = "startup_curr_limit",
    [8254] = "EMK_brake_negative",
    [8264] = "pole_number",
    [8266] = "gear_ratio",
    [8268] = "min_input_voltage",
    [8270] = "max_motor_current",
    [8272] = "max_esc_temp",
    [8274] = "max_bec_temp",
    [8276] = "max_bec_current",
    [8278] = "max_discharge",
    [12352] = "min_brake_pos",
    [12354] = "max_brake_pos",
    [12346] = "PWM_min",
    [16388] = "summary_16388",
    [16432] = "max_rpm",
    --[16452] = "unknown_reg_16452",
    --[16472] = "unknown_reg_16472",
    [20480] = "flight_Mode",
}

local function applySummary16388(parsed, summary)
    if summary == nil then return end

    -- 2-bit enum: 0=NiCd/NiMH, 1=LiPo, 2=LiFePo
    parsed.battery_type = (summary >> 2) & 0x03

    -- Single-bit toggles decoded from summary register 16388.
    parsed.brake = ((summary & 0x0001) ~= 0) and 1 or 0
    parsed.prop_brake = ((summary & 0x0002) ~= 0) and 1 or 0
    parsed.how_adj_max_rpm = ((summary & 0x0040) ~= 0) and 0 or 1
    parsed.undervoltage_behavior = ((summary & 0x0100) ~= 0) and 1 or 0
    parsed.rotation = ((summary & 0x0400) ~= 0) and 1 or 0
    parsed.fwd_bckwd = ((summary & 0x2000) ~= 0) and 1 or 0
    parsed.extra_smooth_IU = ((summary & 0x4000) ~= 0) and 1 or 0
    parsed.alternate_startup = ((summary & 0x20000) ~= 0) and 1 or 0
    parsed.bt_disable_motor_renable_button = ((summary & 0x40000) ~= 0) and 1 or 0
    parsed.bt_disable_motor_renable_motor_stop = ((summary & 0x80000) ~= 0) and 1 or 0
end

local function readU16LE(buf, pos)
    local b0 = buf[pos]
    local b1 = buf[pos + 1]
    if b0 == nil or b1 == nil then return nil end
    return b0 | (b1 << 8), pos + 2
end

local function readU24LE(buf, pos)
    local b0 = buf[pos]
    local b1 = buf[pos + 1]
    local b2 = buf[pos + 2]
    if b0 == nil or b1 == nil or b2 == nil then return nil end
    return b0 | (b1 << 8) | (b2 << 16), pos + 3
end

local function parseKontronikReadBuffer(buf)
    if type(buf) ~= "table" then return nil, "buffer is not a table" end

    local signature = buf[1]
    if signature ~= MSP_SIGNATURE then
        return nil, "invalid signature (" .. tostring(signature) .. ")"
    end

    local command = buf[2]
    if command == nil then return nil, "missing command byte" end

    local modelChars = {}
    for i = 3, 18 do
        local b = buf[i]
        if b == nil then return nil, "buffer too short for model field" end
        if b == 0 then break end
        modelChars[#modelChars + 1] = string.char(b)
    end
    local model = table.concat(modelChars)

    local pairCount = buf[19]
    if pairCount == nil then return nil, "missing register pair count" end
    local pos = 20

    local parsed = {
        esc_signature = signature,
        esc_command = command,
        esc_model = model
    }

    local registers = {}
    for i = 1, pairCount do
        local reg
        reg, pos = readU16LE(buf, pos)
        if reg == nil then return nil, "truncated register id at pair " .. tostring(i) end

        local value
        value, pos = readU24LE(buf, pos)
        if value == nil then return nil, "truncated register value at pair " .. tostring(i) end

        registers[reg] = value

        local fieldName = REG_TO_FIELD[reg]
        if fieldName ~= nil then parsed[fieldName] = value end
    end

    applySummary16388(parsed, registers[16388])

    return {
        parsed = parsed,
        buffer = buf,
        structure = MSP_API_STRUCTURE_READ,
        positionmap = {},
        processed = {},
        other = {registers = registers},
        receivedBytesCount = #buf
    }
end

local function processReplyStaticRead(self, buf)
    local result, err = parseKontronikReadBuffer(buf)
    if not result then
        log("[" .. API_NAME .. "] read parse failed: " .. tostring(err), "info")
        local getError = self.getErrorHandler
        if getError then
            local handler = getError()
            if handler then handler(self, buf) end
        end
        return
    end

    mspData = result
    local getComplete = self.getCompleteHandler
    if getComplete then
        local complete = getComplete()
        if complete then complete(self, buf) end
    end
end

local function processReplyStaticWrite(self, buf)
    mspWriteComplete = true

    if self.uuid then writeDoneRegistry[self.uuid] = true end

    local getComplete = self.getCompleteHandler
    if getComplete then
        local complete = getComplete()
        if complete then complete(self, buf) end
    end
end

local function errorHandlerStatic(self, buf)
    local getError = self.getErrorHandler
    if getError then
        local err = getError()
        if err then err(self, buf) end
    end
end

local function read()
    if MSP_API_CMD_READ == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_READ", "debug")
        return
    end

    local message = {command = MSP_API_CMD_READ, apiname=API_NAME, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = KONTRONIK_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_WRITE", "debug")
        return
    end

    local payload = suppliedPayload or core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE)

    local uuid = MSP_API_UUID or rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid() or tostring(os.clock())
    lastWriteUUID = uuid

    local message = {command = MSP_API_CMD_WRITE, apiname = API_NAME, payload = payload, processReply = processReplyStaticWrite, errorHandler = errorHandlerStatic, simulatorResponse = {}, uuid = uuid, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler}

    rfsuite.tasks.msp.mspQueue:add(message)
end

local function readValue(fieldName)
    if mspData and mspData['parsed'][fieldName] ~= nil then return mspData['parsed'][fieldName] end
    return nil
end

local function setValue(fieldName, value) payloadData[fieldName] = value end

local function readComplete() return mspData ~= nil and mspData['buffer'] ~= nil end

local function writeComplete() return mspWriteComplete end

local function resetWriteStatus() mspWriteComplete = false end

local function data() return mspData end

local function setUUID(uuid) MSP_API_UUID = uuid end

local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end

local function setRebuildOnWrite(rebuild) MSP_REBUILD_ON_WRITE = rebuild end

return {read = read, write = write, setRebuildOnWrite = setRebuildOnWrite, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout, mspSignature = MSP_SIGNATURE, mspHeaderBytes = MSP_HEADER_BYTES, simulatorResponse = KONTRONIK_SIMULATOR_RESPONSE}
