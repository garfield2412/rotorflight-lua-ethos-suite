--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then msp.apicore = core end
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "ESC_PARAMETERS_CASTLE"
local MSP_API_CMD_READ = 217
local MSP_API_CMD_WRITE = 218
local MSP_SIGNATURE = 0xAA
local MSP_HEADER_BYTES = 2

local BLOCK_SELECTOR_HIGH = 0x00
local BLOCK_SELECTOR_LOW = 0x00
local READ_FILLER = 0xFF

-- This first Castle implementation intentionally only covers the first
-- 8-byte 0x60 block from the current reverse-engineering work.
-- The field names below follow the strongest current mapping hypothesis.
-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_command",         type = "U8", apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "esc_model",           type = "U8", apiVersion = {12, 0, 9}, simResponse = {23}},
    {field = "esc_version",         type = "U8", apiVersion = {12, 0, 9}, simResponse = {3}},
    {field = "motor_timing",        type = "U8", apiVersion = {12, 0, 9}, simResponse = {5}},
    {field = "cutoff_voltage",      type = "U8", apiVersion = {12, 0, 9}, simResponse = {3}},
    {field = "current_limiting",    type = "U8", apiVersion = {12, 0, 9}, simResponse = {120}},
    {field = "brake_strength",      type = "U8", apiVersion = {12, 0, 9}, simResponse = {1}},
    {field = "voltage_cutoff_type", type = "U8", apiVersion = {12, 0, 9}, simResponse = {1}},
    {field = "pwm_rate",            type = "U8", apiVersion = {12, 0, 9}, simResponse = {1}},
    {field = "direction",           type = "U8", apiVersion = {12, 0, 9}, simResponse = {1}},
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)
local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

local function parseRead(buf)
    local result = nil

    core.parseMSPData(API_NAME, buf, MSP_API_STRUCTURE_READ, nil, nil, function(parsed)
        result = parsed
    end)

    if result == nil then
        return nil, "parse_failed"
    end

    return result
end

local function buildReadPayload()
    return {
        BLOCK_SELECTOR_HIGH,
        BLOCK_SELECTOR_LOW,
        READ_FILLER,
        READ_FILLER,
        READ_FILLER,
        READ_FILLER,
        READ_FILLER,
        READ_FILLER,
        READ_FILLER,
        READ_FILLER
    }
end

local function buildWritePayload(payloadData, mspData)
    local parsed = mspData and mspData.parsed or {}
    local values = {
        block_selector_high = BLOCK_SELECTOR_HIGH,
        block_selector_low = BLOCK_SELECTOR_LOW,
        esc_signature = (payloadData.esc_signature ~= nil) and payloadData.esc_signature or parsed.esc_signature,
        motor_timing = (payloadData.motor_timing ~= nil) and payloadData.motor_timing or parsed.motor_timing,
        cutoff_voltage = (payloadData.cutoff_voltage ~= nil) and payloadData.cutoff_voltage or parsed.cutoff_voltage,
        current_limiting = (payloadData.current_limiting ~= nil) and payloadData.current_limiting or parsed.current_limiting,
        brake_strength = (payloadData.brake_strength ~= nil) and payloadData.brake_strength or parsed.brake_strength,
        voltage_cutoff_type = (payloadData.voltage_cutoff_type ~= nil) and payloadData.voltage_cutoff_type or parsed.voltage_cutoff_type,
        pwm_rate = (payloadData.pwm_rate ~= nil) and payloadData.pwm_rate or parsed.pwm_rate,
        direction = (payloadData.direction ~= nil) and payloadData.direction or parsed.direction,
    }

    return core.buildFullPayload(API_NAME, values, MSP_API_STRUCTURE_WRITE)
end

return factory.create({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    minBytes = MSP_MIN_BYTES or 0,
    readStructure = MSP_API_STRUCTURE_READ,
    writeStructure = MSP_API_STRUCTURE_WRITE,
    simulatorResponseRead = MSP_API_SIMULATOR_RESPONSE or {},
    parseRead = parseRead,
    buildReadPayload = buildReadPayload,
    buildWritePayload = buildWritePayload,
    initialRebuildOnWrite = true,
    writeUuidFallback = true,
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end,
    exports = {
        mspSignature = MSP_SIGNATURE,
        mspHeaderBytes = MSP_HEADER_BYTES,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
    }
})
