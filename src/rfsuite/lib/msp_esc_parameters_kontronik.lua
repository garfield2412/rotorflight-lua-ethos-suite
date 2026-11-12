-- KBiDir MSP217 kbidir-msp217-v4-r3.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bytes = requireModule("lib/mspcodec.lua")
local M = {READ_COMMAND = 217, EXPECTED_SIGNATURE = 0x4C, REVISION = "kbidir-msp217-v4-r3"}
local ABSENT = 0xFFFFFFFF
local BLOCK_PAIRS = 14
local isSimulator = system and system.getVersion and system.getVersion().simulation == true

-- Encoded pointers, not ordinal slots. Values remain raw until field projection.
local POINTERS = {
  brake_pwm_min = 0x3040, brake_pwm_max = 0x3042,
  brake_slew_up = 0x200E, brake_slew_down = 0x203E,
  bec_voltage = 0x2010, brake_position = 0x2016, off_position = 0x2018,
  max_position = 0x201A, slewrate_up = 0x2022, slewrate_down = 0x2024,
  startuptime = 0x2026, ["p-gain"] = 0x2028, motor_resist = 0x202A,
  discharge_limit = 0x202C, startup_curr_limit = 0x203C, pole_number = 0x2048,
  gear_ratio = 0x204A, min_input_voltage = 0x204C, max_motor_current = 0x204E,
  max_esc_temp = 0x2050, max_bec_temp = 0x2052, max_bec_current = 0x2054,
  max_discharge = 0x2056, PWM_min = 0x303A, max_rpm = 0x4030,
}
local CUTOFF_POINTERS = {[0] = 0x2008, [1] = 0x200A, [2] = 0x200C}
local BITS = {
  brake = 0, prop_brake = 1, rpm_ctl = 5, how_adj_max_rpm = 6,
  undervoltage_behavior = 8, rotation = 10, fwd_bckwd = 13,
  extra_smooth_IU = 14, alternate_startup = 17,
  bt_disable_motor_renable_button = 18, bt_disable_motor_renable_motor_stop = 19,
}

-- One bounded response; this does not publish a configuration snapshot.
local function project(result)
  local index, ambiguous = result.byPointer, result.ambiguous
  for i = 1, #result.pairs do
    local pair = result.pairs[i]
    if index[pair.pointer] ~= nil then ambiguous[pair.pointer] = true end
    index[pair.pointer] = pair.value
  end
  for pointer in pairs(ambiguous) do index[pointer] = nil end
  local fields = result.fields
  for key, pointer in pairs(POINTERS) do fields[key] = index[pointer] end
  local status = index[0x4004]
  if status ~= nil then
    fields.battery_type = (status >> 2) & 3
    for key, bit in pairs(BITS) do fields[key] = (status >> bit) & 1 end
    local cutoff = CUTOFF_POINTERS[fields.battery_type]
    fields.undervoltage_cell = cutoff and index[cutoff] or nil
  end
  -- APK/K-PROG receive representations, independent of the old editable preview.
  if fields.gear_ratio then fields.gear_ratio = fields.gear_ratio / 100 end
  if fields.max_discharge then fields.max_discharge = fields.max_discharge / 10 end
  if fields.discharge_limit then fields.discharge_limit = fields.discharge_limit / 10 end
  if fields.startuptime then fields.startuptime = fields.startuptime / 1000 end
  if fields.brake_pwm_min then fields.brake_pwm_min = math.floor((fields.brake_pwm_min + 20) * 100 / 4096) end
  if fields.brake_pwm_max then fields.brake_pwm_max = math.floor((fields.brake_pwm_max + 20) * 100 / 4096) end
  if fields.PWM_min then fields.PWM_min = math.floor((fields.PWM_min + 20) * 100 / 4096) end
end

-- Validate the complete response before changing collection state.
local function envelope(buf, operation)
  if type(buf) ~= "table" or #buf ~= 96 then return nil, "incompatible" end
  for i = 1, #buf do
    local v = buf[i]
    if type(v) ~= "number" or v % 1 ~= 0 or v < 0 or v > 255 then return nil, "incompatible" end
  end
  if buf[1] ~= 0x4C then return nil, "incompatible" end
  if buf[2] ~= operation then
    return nil, (buf[2] == 0 or buf[2] == 1) and "correlation" or "incompatible"
  end
  return true
end

local function zeroPadding(buf, meaningful)
  for i = meaningful + 1, 96 do if buf[i] ~= 0 then return false end end
  return true
end

function M.decodeStart(buf)
  local ok, err = envelope(buf, 0)
  if not ok then return nil, err end
  if buf[3] ~= 0 then return nil, "incompatible" end
  buf.offset = 4
  local id = bytes.readU32(buf)
  local session = bytes.readU32(buf)
  local generation = bytes.readU32(buf)
  local count = bytes.readU16(buf)
  local version = bytes.readU16(buf)
  local parameterAge = bytes.readU32(buf)
  local modelAge = bytes.readU32(buf)
  local flags, length = bytes.readU8(buf), bytes.readU8(buf)
  local lifetime = bytes.readU16(buf)
  if id == 0 or count > 64 or flags > 7 or length > 31
    or lifetime ~= 30000 or (flags & 4 ~= 0 and flags & 1 == 0) then return nil, "incompatible" end
  if not zeroPadding(buf, 31 + length) then return nil, "incompatible" end
  local parameters, model, eeprom = flags & 1 ~= 0, flags & 2 ~= 0, flags & 4 ~= 0
  if parameters then
    if count == 0 or parameterAge >= 2000 then return nil, "incompatible" end
  elseif count ~= 0 or version ~= 0 or generation ~= 0 or parameterAge ~= ABSENT then return nil, "incompatible" end
  if not eeprom and version ~= 0 then return nil, "incompatible" end
  if model then
    if length == 0 or modelAge >= 2000 then return nil, "incompatible" end
  elseif length ~= 0 or modelAge ~= ABSENT then return nil, "incompatible" end
  local chars = {}
  for i = 32, 31 + length do
    if buf[i] < 32 or buf[i] > 126 then return nil, "incompatible" end
    chars[#chars + 1] = string.char(buf[i])
  end
  return {
    esc_signature = 0x4C, revision = M.REVISION, retrievalId = id, lifetimeMs = lifetime,
    flags = flags, count = count, model = table.concat(chars), eepromVersion = version,
    sessionId = session, generation = generation, parameterAge = parameterAge, modelAge = modelAge,
    parametersAvailable = parameters, modelAvailable = model, eepromAvailable = eeprom,
    pairs = {}, byPointer = {}, ambiguous = {}, fields = {},
  }
end

function M.decodeBlock(buf, id, offset, total)
  local ok, err = envelope(buf, 1)
  if not ok then return nil, err end
  buf.offset = 4
  local replyId, replyOffset = bytes.readU32(buf), bytes.readU16(buf)
  local count, reserved = bytes.readU8(buf), bytes.readU8(buf)
  if replyId == 0 or buf[3] ~= 0 or reserved ~= 0 or count == 0 or count > BLOCK_PAIRS
    or replyOffset % BLOCK_PAIRS ~= 0 or replyOffset >= 64
    or replyOffset + count > 64 then return nil, "incompatible" end
  if not zeroPadding(buf, 11 + count * 6) then return nil, "incompatible" end
  if id and replyId ~= id then return nil, "correlation" end
  if offset and replyOffset ~= offset then return nil, "correlation" end
  if total and (replyOffset >= total or count ~= math.min(BLOCK_PAIRS, total - replyOffset)) then
    return nil, "incompatible"
  end
  local result = {}
  for i = 1, count do result[i] = {pointer = bytes.readU16(buf), value = bytes.readU32(buf)} end
  return result, nil, replyId, replyOffset
end

-- K-PROG adjustData intentions, NOT MSP messages or an EEPROM encoder.
-- Compare captured raw values; the type-3 Stick_PWM_min command takes percent.
-- Recompute against the immutable capture so switching back cancels obsolete
-- intentions rather than applying guessed percent-to-EEPROM conversions.
local GOVERNOR_HELPERS = {
  {pointer=0x3020,onMin=1280,onMax=1536,onValue=33,offMin=40,offMax=400,offValue=1,unit="percent"},
  {pointer=0x201C,onMin=1280,onMax=1536,onValue=1365,offMin=1,offMax=500,offValue=327,unit="raw"},
  {pointer=0x201E,onMin=0,onMax=0,onValue=0,offMin=1,offMax=320,offValue=204,unit="raw"},
}
function M.planGovernorAdjustments(snapshot,mode)
  if (mode~=0 and mode~=1) or not snapshot or not snapshot.byPointer
    or not snapshot.fields or snapshot.fields.rpm_ctl==nil then return nil,"unavailable" end
  -- Check all inputs before preparing anything. Missing/ambiguous pointers
  -- must not yield an apparently complete partial transaction.
  for _,spec in ipairs(GOVERNOR_HELPERS) do
    if snapshot.byPointer[spec.pointer]==nil then return nil,"unavailable" end
  end
  local plan={}
  for _,spec in ipairs(GOVERNOR_HELPERS) do
    local raw=snapshot.byPointer[spec.pointer]
    local minimum=mode==1 and spec.onMin or spec.offMin
    local maximum=mode==1 and spec.onMax or spec.offMax
    if raw<minimum or raw>maximum then
      plan[#plan+1]={pointer=spec.pointer,value=mode==1 and spec.onValue or spec.offValue,
        unit=spec.unit,observedRaw=raw}
    end
  end
  return plan
end

function M.errorKind(reason)
  if reason == true then return "msp_error" end
  if reason == "max_retries" or reason == "timeout" then return "timeout" end
  return "transport_error"
end

-- Synthetic KOLIBRI140+LV demo based on the capture, adjusted to known limits.
-- Shared firmware/capture vectors remain unchanged; transport still uses V4-r3.
local SIM_PAIRS = isSimulator and {
  0x00, 0x20, 0xB0, 0x04, 0x00, 0x00, 0x02, 0x20, 0x02, 0x04, 0x00, 0x00,
  0x04, 0x40, 0x74, 0x0A, 0x11, 0x00, 0x08, 0x20, 0x20, 0x03, 0x00, 0x00,
  0x0A, 0x20, 0xB8, 0x0B, 0x00, 0x00, 0x0C, 0x20, 0xFC, 0x08, 0x00, 0x00,
  0x0E, 0x20, 0xF4, 0x01, 0x00, 0x00, 0x10, 0x20, 0x7C, 0x15, 0x00, 0x00,
  0x12, 0x20, 0xD0, 0x07, 0x00, 0x00, 0x14, 0x20, 0x05, 0x00, 0x00, 0x00,
  0x16, 0x20, 0x4D, 0x04, 0x00, 0x00, 0x18, 0x20, 0x4D, 0x04, 0x00, 0x00,
  0x1A, 0x20, 0xDD, 0x05, 0x00, 0x00, 0x1C, 0x20, 0x55, 0x05, 0x00, 0x00,
  0x1E, 0x20, 0x00, 0x00, 0x00, 0x00, 0x20, 0x30, 0x55, 0x05, 0x00, 0x00,
  0x22, 0x20, 0xE8, 0x03, 0x00, 0x00, 0x24, 0x20, 0xC8, 0x00, 0x00, 0x00,
  0x26, 0x20, 0x10, 0x27, 0x00, 0x00, 0x28, 0x20, 0x06, 0x00, 0x00, 0x00,
  0x2A, 0x20, 0x04, 0x00, 0x00, 0x00, 0x2C, 0x20, 0x00, 0x00, 0x00, 0x00,
  0x30, 0x40, 0x30, 0x75, 0x00, 0x00, 0x34, 0x20, 0x06, 0x00, 0x00, 0x00,
  0x36, 0x20, 0x00, 0x01, 0x00, 0x00, 0x38, 0x20, 0x00, 0x00, 0x00, 0x00,
  0x3A, 0x30, 0x51, 0x00, 0x00, 0x00, 0x3C, 0x20, 0x0F, 0x00, 0x00, 0x00,
  0x3E, 0x20, 0x64, 0x00, 0x00, 0x00, 0x40, 0x30, 0x51, 0x00, 0x00, 0x00,
  0x42, 0x30, 0xD7, 0x0F, 0x00, 0x00, 0x44, 0x40, 0xC0, 0x5D, 0x00, 0x00,
  0x48, 0x20, 0x0A, 0x00, 0x00, 0x00, 0x4A, 0x20, 0x64, 0x00, 0x00, 0x00,
  0x4C, 0x20, 0xDC, 0x37, 0x00, 0x00, 0x4E, 0x20, 0xDC, 0x00, 0x00, 0x00,
  0x50, 0x20, 0x5F, 0x00, 0x00, 0x00, 0x52, 0x20, 0x5F, 0x00, 0x00, 0x00,
  0x54, 0x20, 0xE0, 0x2E, 0x00, 0x00, 0x56, 0x20, 0x00, 0x00, 0x00, 0x00,
  0x58, 0x40, 0x8F, 0x1C, 0xFD, 0xFF,
}

local function padded(buf)
  for i = #buf + 1, 96 do buf[i] = 0 end
  return buf
end

local simId = 0
local function simulatorStart()
  simId = (simId + 1) & 0xFFFFFFFF
  if simId == 0 then simId = 1 end
  local buf = {0x4C, 0, 0}
  bytes.writeU32(buf, simId); bytes.writeU32(buf, 1); bytes.writeU32(buf, 2)
  bytes.writeU16(buf, 41); bytes.writeU16(buf, 0x0402)
  bytes.writeU32(buf, 0); bytes.writeU32(buf, 0)
  bytes.writeU8(buf, 7); bytes.writeU8(buf, 13); bytes.writeU16(buf, 30000)
  local model = "KOLIBRI140+LV"
  for i = 1, #model do buf[#buf + 1] = model:byte(i) end
  return padded(buf)
end
local simOffset, simMetadata, simCaptured = 0, nil, 0
local function simulatorReply()
  if not simMetadata or os.clock() - simCaptured >= 30 then
    simMetadata, simOffset, simCaptured = simulatorStart(), 0, os.clock()
    return simMetadata
  end
  if simOffset >= 41 then simOffset = 0; return simMetadata end
  local response = {0x4C, 1, 0}
  bytes.writeU32(response, simId); bytes.writeU16(response, simOffset)
  local count = math.min(BLOCK_PAIRS, 41 - simOffset)
  bytes.writeU8(response, count); bytes.writeU8(response, 0)
  for i = simOffset * 6 + 1, (simOffset + count) * 6 do response[#response + 1] = SIM_PAIRS[i] end
  simOffset = simOffset + count
  return padded(response)
end
function M.buildReadMessage(onReply, onError)
  return {command = 217, payload = {}, processReply = function(_, buf) onReply(buf) end,
    errorHandler = onError, simulatorResponse = isSimulator and simulatorReply() or nil}
end

-- A shared cyclic cursor cannot echo requests. Collect complete blocks by their
-- served ID/offset, retaining ordered pairs only after full validation.
function M.newReader(send, onData, onError)
  local reader = {}
  local waiting, stopped, serial = false, false, 0
  local partial, metadata, received = nil, nil, 0
  local blocks = {}
  local startedAt
  local function fail(reason)
    if stopped then return end
    stopped, waiting, partial, metadata = true, false, nil, nil
    for k in pairs(blocks) do blocks[k] = nil end
    serial = serial + 1
    onError(reason)
  end
  function reader:cancel()
    stopped, waiting, partial, metadata = true, false, nil, nil
    for k in pairs(blocks) do blocks[k] = nil end
    serial = serial + 1
  end
  local function expired() return startedAt and os.clock() - startedAt >= 30 end
  function reader:wakeup()
    if stopped then return end
    if expired() then return fail("timeout") end
    if waiting then return end
    if not startedAt then startedAt = os.clock() end
    waiting = true
    serial = serial + 1
    local token = serial
    local function reply(buf)
      if stopped or token ~= serial or not waiting then return end
      waiting = false
      if expired() then return fail("timeout") end
      if type(buf) ~= "table" then return fail("incompatible") end
      if buf[2] == 0 then
        local result = M.decodeStart(buf)
        if not result then return fail("incompatible") end
        if partial and result.retrievalId == partial.retrievalId then
          if #buf ~= #metadata then return fail("incompatible") end
          for i = 1, #buf do if buf[i] ~= metadata[i] then return fail("incompatible") end end
        else
          partial, metadata, received = result, {}, 0
          for i = 1, #buf do metadata[i] = buf[i] end
          for k in pairs(blocks) do blocks[k] = nil end
        end
      else
        local result, _, id, offset = M.decodeBlock(buf)
        if not result then return fail("incompatible") end
        if not partial or id ~= partial.retrievalId then return end
        if offset >= partial.count or #result ~= math.min(BLOCK_PAIRS, partial.count - offset) then
          return fail("incompatible")
        end
        if blocks[offset] then
          for i = 1, #result do
            local old = partial.pairs[offset + i]
            if old.pointer ~= result[i].pointer or old.value ~= result[i].value then return fail("incompatible") end
          end
        else
          for i = 1, #result do partial.pairs[offset + i] = result[i] end
          blocks[offset], received = true, received + #result
        end
      end
      if partial and received == partial.count then
        project(partial)
        partial.retrievalSeconds = math.max(0, os.clock() - startedAt)
        local complete = partial
        self:cancel()
        onData(complete)
      end
    end
    local function errorHandler(reason)
      if stopped or token ~= serial or not waiting then return end
      waiting = false
      if expired() then return fail("timeout") end
      local kind = M.errorKind(reason)
      if kind ~= "timeout" then fail(kind) end
      -- The next empty read may return another item; missing blocks arrive in a later cycle.
    end
    send(M.buildReadMessage(reply, errorHandler))
  end
  return reader
end

-- No WRITE_COMMAND, encoder or MSP218.
return M
