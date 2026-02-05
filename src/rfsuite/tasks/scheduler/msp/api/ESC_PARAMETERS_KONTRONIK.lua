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
local bec_voltage = {"6000mV", "6200mV", "6400mV", "6600mV", "6800mV", "7000mV", "7200mV", "7400mV", "7600mV", "7800mV", "8000mV"}
local pole_number = {"2", "4", "6", "8", "10", "12", "14", "16", "18", "20"}
local battery_type = {"NiCd / NiMH", "LiPo", "LiFePo"}
local undervoltage_behavior = {"@i18n(api.ESC_PARAMETERS_KONTRONIK.tbl_undervoltage_behavior_slow)@", "@i18n(api.ESC_PARAMETERS_KONTRONIK.tbl_undervoltage_behavior_shut)@"}
local how_adj_max_rpm = {"@i18n(api.ESC_PARAMETERS_KONTRONIK.tbl_how_adj_max_rpm_idleup)@", "@i18n(api.ESC_PARAMETERS_KONTRONIK.tbl_how_adj_max_rpm_govstore)@"}

local MSP_API_STRUCTURE_READ_DATA = {
  {field = "esc_signature", type="U8", apiVersion=12.07, simResponse={ 75 }, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.esc_signature)@" },
  {field = "esc_command", type = "U8", apiVersion = 12.07, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.esc_command)@"},
  {field = "esc_model", type = "U128", apiVersion = 12.07, simResponse = {75, 79, 83, 77, 73, 75, 32, 72, 86, 32, 32, 32, 32, 32, 32, 32}, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.esc_model)@"},
  {field = "esc_version", type = "U128", apiVersion = 12.07, simResponse = {50, 48, 48, 65, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32}, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.esc_version)@"},
  {field = "firmware_version", type = "U128", apiVersion = 12.07, simResponse = { 86,52,46,49,55, 32,32,32,32,32,32,32,32,32,32,32 }, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.firmware_version)@" },
  {field = "bec_voltage", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = bec_voltage, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.bec_voltage)@"},
  {field = "rotation", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.rotation)@" },
  {field = "fwd_bckwd", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.fwd_bckwd)@" },
  {field = "flight_Mode", type = "U8", apiVersion = 12.07, simResponse = { 2 }, default = 2, min = 0, max = #flight_Mode, tableIdxInc = -1, table = flight_Mode, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.flight_Mode)@" },
  {field = "battery_type", type = "U8", apiVersion = 12.07, simResponse = { 1 }, default = 1, min = 0, max = #battery_type, tableIdxInc = -1, table = battery_type, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.battery_type)@" },
  {field = "undervoltage_behavior", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0, min = 0, max = #undervoltage_behavior, tableIdxInc = -1, table = undervoltage_behavior, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.undervoltage_behavior)@" },
  {field = "undervoltage_cell", type = "U16", apiVersion = 12.07, simResponse = {184, 11},min = 2800, max = 3700, step = 100, unit = "mV", help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.undervoltage_cell)@" },
  {field = "discharge_limiter_act", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0},
  {field = "discharge_limit", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 20, step = 1, unit = "mAh", help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.discharge_limit)@" },
  {field = "pole_number", type = "U8", apiVersion = 12.07, simResponse = {4}, tableIdxInc = -1, table = pole_number, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.pole_number)@" },
  {field = "gear_ratio", type = "U16", apiVersion = 12.07, simResponse = {100, 0}, min = 100, max = 2000,step = 1, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.gear_ratio)@" },
  {field = "brake", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0},
  {field = "rpm_ctl", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0},
  {field = "how_adj_max_rpm", type = "U8", apiVersion = 12.07, simResponse = { 0 }, default = 0, min = 0, max = #how_adj_max_rpm, tableIdxInc = -1, table = how_adj_max_rpm},
  {field = "max_discharge", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.max_discharge)@" },
  {field = "min_input_voltage", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.min_input_voltage)@" },
  {field = "max_motor_current", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.max_motor_current)@" },
  {field = "max_esc_temp", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.max_esc_temp)@" },
  {field = "max_bec_temp", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.max_bec_temp)@" },
  {field = "max_bec_current", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, help = "@i18n(api.ESC_PARAMETERS_KONTRONIK.max_bec_current)@" },
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

local function processReplyStaticRead(self, buf)
    core.parseMSPData(API_NAME, buf, self.structure, nil, nil, function(result)
        mspData = result
        if #buf >= (self.minBytes or 0) then
            local getComplete = self.getCompleteHandler
            if getComplete then
                local complete = getComplete()
                if complete then complete(self, buf) end
            end
        end
    end)
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

    local message = {command = MSP_API_CMD_READ, apiname=API_NAME, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = MSP_API_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
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

local function readComplete() return mspData ~= nil and #mspData['buffer'] >= MSP_MIN_BYTES end

local function writeComplete() return mspWriteComplete end

local function resetWriteStatus() mspWriteComplete = false end

local function data() return mspData end

local function setUUID(uuid) MSP_API_UUID = uuid end

local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end

local function setRebuildOnWrite(rebuild) MSP_REBUILD_ON_WRITE = rebuild end

return {read = read, write = write, setRebuildOnWrite = setRebuildOnWrite, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout, mspSignature = MSP_SIGNATURE, mspHeaderBytes = MSP_HEADER_BYTES, simulatorResponse = MSP_API_SIMULATOR_RESPONSE}
