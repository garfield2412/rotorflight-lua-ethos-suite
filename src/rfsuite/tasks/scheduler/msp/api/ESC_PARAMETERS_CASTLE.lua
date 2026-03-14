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

-- Cross-check against:
--   C:\Users\kayko\OneDrive\Dokumente\PlatformIO\Projects\CastleLink\
-- Current takeaway from that project:
-- - Session 7 / Session 8 do not support a "5 blocks of 13 payload bytes"
--   model. They support 13-byte transport frames with an 8-byte body.
-- - The observed config-read burst is five selectors:
--     00 00, 00 80, 00 40, 00 C0, 00 20
-- - The strongest current interpretation there is:
--     00 00 -> simple scalar settings region
--     00 80 -> Advanced Throttle composite region
--     00 40 -> Advanced Throttle composite region
--     00 C0 -> Advanced Throttle companion/composite region
--     00 20 -> tail region with scalar/packed values
-- - Highest-confidence byte anchors from that material are:
--     00 00 byte 1 = motor timing candidate (90)
--     00 00 byte 2 = cutoff voltage / Auto Li-Po candidate (255)
--     00 00 byte 4 = brake strength candidate (0)
--     00 00 byte 7 = direction candidate (0)
--     00 80 byte 5 = throttle/vehicle mode selector candidate (72 -> 32)
--     00 C0 byte 5 = dependent companion byte candidate (0 -> 152)
--     00 20 byte 5 = governor gain candidate (15)
-- - Therefore the parser layout below should currently be read as a
--   Rotorflight-side working format, not as a proven raw CastleLink wire map
--   for model/version/firmware fields.

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature",       type = "U8",   apiVersion = {12, 0, 9}, simResponse = {170}},
    {field = "esc_command",         type = "U8",   apiVersion = {12, 0, 9}, simResponse = {0}},
    {field = "esc_model",           type = "U128", apiVersion = {12, 0, 9}, simResponse = {69, 68, 71, 69, 32, 72, 86, 0, 0, 0, 0, 0, 0, 0, 0, 0}},
    {field = "esc_version",         type = "U128", apiVersion = {12, 0, 9}, simResponse = {49, 54, 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}},
    {field = "esc_firmware",        type = "U128", apiVersion = {12, 0, 9}, simResponse = {52, 46, 50, 53, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}},
    {field = "motor_timing",        type = "U8",   apiVersion = {12, 0, 9}, simResponse = {5}},
    {field = "cutoff_voltage",      type = "U8",   apiVersion = {12, 0, 9}, simResponse = {3}},
    {field = "current_limiting",    type = "U8",   apiVersion = {12, 0, 9}, simResponse = {120}},
    {field = "brake_strength",      type = "U8",   apiVersion = {12, 0, 9}, simResponse = {1}},
    {field = "voltage_cutoff_type", type = "U8",   apiVersion = {12, 0, 9}, simResponse = {1}},
    {field = "pwm_rate",            type = "U8",   apiVersion = {12, 0, 9}, simResponse = {1}},
    {field = "direction",           type = "U8",   apiVersion = {12, 0, 9}, simResponse = {1}},
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
    -- Current Castle read approach:
    -- Queue a regular MSP read with command 217 (MSP_API_CMD_READ) and a fixed
    -- 10-byte payload selecting block 0x0000.
    -- CastleLink Session 7/8 currently suggest that a transport-faithful probe
    -- should validate these selector pairs first:
    --   0x00 0x00
    --   0x00 0x80
    --   0x00 0x40
    --   0x00 0xC0
    --   0x00 0x20
    -- The current implementation still only issues the first selector
    -- (0x00, 0x00) here.
    -- Payload sent today:
    --   0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
    -- Interpreted as:
    --   [1] block selector high = 0x00
    --   [2] block selector low  = 0x00
    --   [3..10] read filler     = 0xFF
    -- The reply is then parsed as Castle data with the first 2 bytes reserved
    -- for the Castle header/signature area (see mspHeaderBytes/MSP_HEADER_BYTES).
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
