-- Experimental ESCape32 session contract v1. 0x5FE0 is fork-local, not allocated upstream.
if package.loaded["rfsuite.lib.msp_esc_parameters_escape32"] then
  return package.loaded["rfsuite.lib.msp_esc_parameters_escape32"]
end

local M = {COMMAND = 0x5FE0, VERSION = 1, REPLY_SIZE = 32}
local SIMULATOR_CAPS = {1,0,0,0,0,0,0,0,0,0,255,17,255,0,0,0,
  0,0,0,0,0,14,32,0,16,39,1,0,0,0,0,0}
M.OP = {CAPS = 0, OPEN = 1, STATUS = 2, GET = 3, SET = 4, SAVE = 5, CLOSE = 6}
M.RESULT = {OK = 0, UNSUPPORTED = 1, BUSY = 2, INVALID_SESSION = 3,
  INVALID_REQUEST = 4, POWER_CYCLE_NEEDED = 5, TIMEOUT = 6, PROTOCOL_ERROR = 7,
  NORMALIZED = 8, OUTCOME_UNKNOWN = 9, VERIFY_FAILED = 10, RANGE = 11, STALE_REQUEST = 12}
M.STATE = {IDLE = 0, WAIT_POWER = 1, IDENTIFY = 2, READY = 3, READ = 4,
  SET = 5, SAVE = 6, VERIFY = 7, ERROR = 8, RESTART_REQUIRED = 9}
M.PARAMETERS = {
  {key = "revdir", min = 0, max = 1, scale = 1},
  {key = "timing", min = 1, max = 31, scale = 15 / 16},
  {key = "freq_min", min = 16, max = 48, scale = 1},
  {key = "freq_max", min = 16, max = 96, scale = 1},
  {key = "duty_spup", min = 1, max = 100, scale = 1},
  {key = "duty_ramp", min = 0, max = 100, scale = 1},
  {key = "duty_rate", min = 1, max = 100, scale = 0.1},
  {key = "prot_temp", min = 0, max = 140, scale = 1},
  {key = "prot_curr", min = 0, max = 999, scale = 1},
}

local function integer(v, max)
  return type(v) == "number" and v == math.floor(v) and v >= 0 and v <= max
end
local function write(bytes, n, count)
  for _ = 1, count do bytes[#bytes + 1] = n % 256; n = math.floor(n / 256) end
end
local function read(bytes, offset, count)
  local n = 0
  for i = offset + count - 1, offset, -1 do n = n * 256 + bytes[i] end
  return n
end

function M.encode(op, args)
  args = args or {}
  if not integer(op, M.OP.CLOSE) then return nil, "invalid_operation" end
  local bytes = {M.VERSION, op}
  if op == M.OP.CAPS then return bytes end
  local token, id = args.token or 0, args.requestId or 0
  if not integer(token, 0xFFFFFFFF) or not integer(id, 65535) then return nil, "invalid_session" end
  if op ~= M.OP.STATUS and id == 0 then return nil, "invalid_request_id" end
  if op == M.OP.OPEN then
    if token ~= 0 or not integer(args.target, 15) or not integer(args.nonce, 0xFFFFFFFF)
      or args.nonce == 0 then return nil, "invalid_open" end
  elseif token == 0 then return nil, "invalid_session" end
  write(bytes, token, 4); write(bytes, id, 2)
  if op == M.OP.OPEN then
    write(bytes, args.target, 1); write(bytes, 1, 1); write(bytes, args.nonce, 4)
  elseif op == M.OP.GET or op == M.OP.SET then
    if not integer(args.key, #M.PARAMETERS - 1) then return nil, "invalid_key" end
    write(bytes, args.key, 1)
    if op == M.OP.SET then
      local p, v = M.PARAMETERS[args.key + 1], args.value
      if type(v) ~= "number" or v ~= math.floor(v) or v < p.min or v > p.max then
        return nil, "out_of_range"
      end
      write(bytes, v % 0x100000000, 4)
    end
  end
  return bytes
end

function M.decode(bytes, expectedOp)
  if type(bytes) ~= "table" or #bytes ~= M.REPLY_SIZE then return nil, "invalid_length" end
  for i = 1, #bytes do if not integer(bytes[i], 255) then return nil, "invalid_byte" end end
  if bytes[1] ~= M.VERSION then return nil, "unsupported_version" end
  if bytes[2] ~= expectedOp then return nil, "operation_mismatch" end
  if bytes[3] > M.RESULT.STALE_REQUEST or bytes[4] > M.STATE.RESTART_REQUIRED
    or bytes[24] ~= 0 or bytes[31] ~= 0 or bytes[32] ~= 0
    or bytes[12] & 0xE0 ~= 0 then return nil, "invalid_reply" end
  local value = read(bytes, 17, 4)
  if value >= 0x80000000 then value = value - 0x100000000 end
  local flags = bytes[12]
  return {op = bytes[2], result = bytes[3], state = bytes[4], token = read(bytes, 5, 4),
    requestId = read(bytes, 9, 2), target = bytes[11], flags = flags,
    key = bytes[13], revision = bytes[14], patch = bytes[15], schema = bytes[16],
    value = value, backend = bytes[21], maxRequest = bytes[22], maxReply = bytes[23],
    timeoutMs = read(bytes, 25, 2), capabilities = read(bytes, 27, 2),
    targets = read(bytes, 29, 2), readonly = flags & 1 ~= 0,
    dirty = flags & 2 ~= 0, restartRequired = flags & 4 ~= 0,
    valueValid = flags & 8 ~= 0, terminal = flags & 16 ~= 0}
end

function M.canRead(caps)
  return caps and caps.result == M.RESULT.OK and caps.capabilities & 7 == 7
    and caps.targets ~= 0 and caps.backend == 1 and caps.maxRequest >= 14
    and caps.maxReply == M.REPLY_SIZE and caps.timeoutMs >= 3000
end
function M.hasKnownSchema(reply)
  -- rev17.2 and rev17.3 have identical CFG_MAP/checkcfg; future patches need review.
  return reply and reply.schema == 1 and reply.revision == 17
    and (reply.patch == 2 or reply.patch == 3)
end
function M.canWrite(reply)
  return M.hasKnownSchema(reply) and reply.capabilities & 8 ~= 0 and not reply.readonly
end

function M.buildMessage(op, args, onData, onError)
  local payload, err = M.encode(op, args)
  if not payload then return nil, err end
  return {command = M.COMMAND, payload = payload, isWrite = true,
    -- No blind retry of a flash operation. STATUS recovers an unknown outcome.
    maxRetries = 0, retryDelay = 1.2,
    simulatorResponse = op == M.OP.CAPS and SIMULATOR_CAPS or nil,
    processReply = function(_, bytes)
      local data, reason = M.decode(bytes, op)
      if data then onData(data) elseif onError then onError(reason) end
    end,
    errorHandler = onError}
end

package.loaded["rfsuite.lib.msp_esc_parameters_escape32"] = M
return M
