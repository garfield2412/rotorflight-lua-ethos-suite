-- One owner per page; only MSP messages cross the subsystem boundary.
if package.loaded["rfsuite.lib.escape32_session"] then return package.loaded["rfsuite.lib.escape32_session"] end
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local codec = requireModule("lib/msp_esc_parameters_escape32.lua")
local M = {}
local nonceCounter = 0

function M.new(opts)
  opts = opts or {}
  local send = assert(opts.send)
  local clock = opts.clock or os.clock
  local c = {state = "idle", values = {}, pending = false, token = 0, requestId = 0,
    connected = false, disarmed = false, dirty = false, revision = 0}
  local generation, nextPoll, pendingOp, pendingKey, disposed = 0, 0, nil, nil, false
  local openArgs, closeArgs
  local function changed() c.revision = c.revision + 1 end
  local function fail(reason)
    c.error = reason; c.state = "error"; c.pending = false; changed()
  end
  local function issue(op, args, done)
    local gen = generation
    c.pending = true
    local message, reason = codec.buildMessage(op, args, function(data)
      if disposed or gen ~= generation then
        -- OPEN may have completed after the page closed, before we knew its token.
        if op == codec.OP.OPEN and data.token ~= 0 then
          local close = codec.buildMessage(codec.OP.CLOSE,
            {token = data.token, requestId = args.requestId + 1}, function() end, function() end)
          if close then send(close) end
        end
        return
      end
      c.pending = false
      done(data)
    end, function(err)
      if disposed or gen ~= generation then return end
      c.pending = false
      if op == codec.OP.SET or op == codec.OP.SAVE or op == codec.OP.STATUS then
        c.state = "outcome_unknown"; c.error = err; nextPoll = clock() + 0.5; changed()
      elseif op == codec.OP.OPEN then
        c.state = "open_unknown"; c.error = err; changed()
      elseif op == codec.OP.CLOSE then
        c.state = "close_unknown"; c.error = err; changed()
      else fail(err) end
    end)
    if not message then c.pending = false; fail(reason); return false end
    send(message)
    return true
  end
  local function accept(data)
    if data.token ~= c.token or data.target ~= c.target or data.requestId ~= c.requestId then
      fail("session_mismatch"); return
    end
    c.reply = data; c.dirty = data.dirty; c.restartRequired = data.restartRequired
    if not data.terminal and data.result == codec.RESULT.BUSY then
      c.state = data.state == codec.STATE.WAIT_POWER and "wait_power" or "busy"
      nextPoll = clock() + 0.5
    elseif data.result == codec.RESULT.POWER_CYCLE_NEEDED or data.restartRequired then
      c.state = "restart_required"; c.error = data.result; pendingOp = nil
    elseif data.result == codec.RESULT.OUTCOME_UNKNOWN then
      c.state = "outcome_unknown"; c.error = data.result; pendingOp = nil
    elseif data.result ~= codec.RESULT.OK and data.result ~= codec.RESULT.NORMALIZED then
      fail(data.result); pendingOp = nil
    elseif not data.terminal then
      fail("missing_terminal"); pendingOp = nil
    else
      if data.state ~= codec.STATE.READY then fail("unexpected_state"); pendingOp = nil; return end
      if (pendingOp == codec.OP.GET or pendingOp == codec.OP.SET) then
        local p = codec.PARAMETERS[(pendingKey or -1) + 1]
        if not data.valueValid or data.key ~= pendingKey or not p
          or (data.schema == 1 and (data.value < p.min or data.value > p.max)) then
          fail("invalid_value"); pendingOp = nil; return
        end
        c.values[pendingKey] = data.value
      end
      if pendingOp then
        c.lastOperation = pendingOp
        c.normalized = data.result == codec.RESULT.NORMALIZED
        c.state = pendingOp == codec.OP.SAVE and "save_confirmed" or "ready"
      elseif c.state == "outcome_unknown" then
        c.state = c.lastOperation == codec.OP.SAVE and "save_confirmed" or "ready"
      end
      c.error = nil; pendingOp = nil
      nextPoll = clock() + 2
    end
    changed()
  end
  local function nextId(forClose)
    if c.requestId >= (forClose and 65535 or 65534) then fail("request_id_exhausted"); return nil end
    c.requestId = c.requestId + 1
    return c.requestId
  end
  function c.setLink(connected, isArmed)
    connected = connected == true
    local disarmed = isArmed == false
    if connected == c.connected and disarmed == c.disarmed then return end
    c.connected = connected; c.disarmed = disarmed
    if not c.connected or not c.disarmed then
      if c.token ~= 0 then c.close()
      else generation = generation + 1; c.pending = false; pendingOp = nil end
      c.caps = nil; c.state = "disconnected"; changed()
    end
  end
  function c.probe()
    if disposed or c.pending or c.token ~= 0 or c.state == "open_unknown"
      or not c.connected or not c.disarmed then return false end
    c.state = "probing"; c.error = nil; changed()
    return issue(codec.OP.CAPS, nil, function(data)
      c.caps = data; c.state = codec.canRead(data) and "select_target" or "unsupported"; changed()
    end)
  end
  local function opened(data)
    if data.token == 0 then fail(data.result); pendingOp = nil; openArgs = nil; return end
    c.token = data.token
    accept(data)
  end
  function c.open(target)
    if disposed or c.pending or c.token ~= 0 or not c.connected or not c.disarmed
      or c.state == "open_unknown"
      or not codec.canRead(c.caps) or type(target) ~= "number" or target ~= math.floor(target)
      or target < 0 or target > 15 or c.caps.targets & (1 << target) == 0 then return false end
    generation = generation + 1; nonceCounter = (nonceCounter % 0xFFFFFFFE) + 1
    -- Fresh per intent, retained verbatim for recovery. A nonce is not authentication.
    local seconds = 0
    if os.time then local ok, value = pcall(os.time); if ok then seconds = tonumber(value) or 0 end end
    local nonce = (seconds * 1664525 + math.floor(clock() * 1000000)
      + nonceCounter * 1013904223) % 0xFFFFFFFF + 1
    c.target = target; c.requestId = 1; c.state = "opening"; pendingOp = codec.OP.OPEN
    for k in pairs(c.values) do c.values[k] = nil end
    changed()
    openArgs = {target = target, nonce = nonce, requestId = 1}
    return issue(codec.OP.OPEN, openArgs, opened)
  end
  function c.canAct()
    return not disposed and c.connected and c.disarmed and c.token ~= 0 and not c.pending
      and (c.state == "ready" or c.state == "save_confirmed")
  end
  function c.canWrite()
    return c.canAct() and codec.canWrite(c.reply)
  end
  local function operation(op, key, value)
    if not c.canAct() or (op ~= codec.OP.GET and not c.canWrite()) then return false end
    if op == codec.OP.SAVE and not c.dirty then return false end
    local id = nextId(); if not id then return false end
    pendingOp = op; pendingKey = key; c.state = "busy"; c.normalized = false; changed()
    return issue(op, {token = c.token, requestId = id, key = key, value = value}, accept)
  end
  function c.get(key)
    if not c.reply or c.reply.schema ~= 1 then return false end
    return operation(codec.OP.GET, key)
  end
  function c.set(key, value) return operation(codec.OP.SET, key, value) end
  function c.save() return operation(codec.OP.SAVE) end
  local function closed(data)
    if not closeArgs or data.token ~= closeArgs.token or data.requestId ~= closeArgs.requestId then
      fail("session_mismatch"); return
    end
    if not data.terminal or (data.result ~= codec.RESULT.OK
      and data.result ~= codec.RESULT.POWER_CYCLE_NEEDED)
      or (data.state ~= codec.STATE.IDLE and data.state ~= codec.STATE.RESTART_REQUIRED) then
      c.state = "close_unknown"; c.error = data.result; changed(); return
    end
    c.reply = data; c.token = 0; c.restartRequired = data.restartRequired
    c.state = data.restartRequired and "restart_required" or "closed"
    c.error = nil; pendingOp = nil; closeArgs = nil; changed()
  end
  function c.recover()
    if disposed or c.pending or not c.connected or not c.disarmed then return false end
    if c.token == 0 then
      if c.state == "open_unknown" and openArgs then return issue(codec.OP.OPEN, openArgs, opened) end
      return false
    end
    return issue(codec.OP.STATUS, {token = c.token, requestId = c.requestId},
      pendingOp == codec.OP.CLOSE and closed or accept)
  end
  function c.wakeup()
    if disposed or c.pending or not c.connected or not c.disarmed then return end
    if pendingOp and clock() >= nextPoll and (c.state == "wait_power" or c.state == "busy"
      or c.state == "outcome_unknown") then c.recover() end
    if c.token ~= 0 and not pendingOp and clock() >= nextPoll
      and (c.state == "ready" or c.state == "save_confirmed") then c.recover() end
  end
  function c.close()
    if c.token == 0 then return false end
    generation = generation + 1; c.pending = false
    if not closeArgs then
      local id = nextId(true); if not id then return false end
      closeArgs = {token = c.token, requestId = id}
    end
    pendingOp = codec.OP.CLOSE
    c.state = "closing"; changed()
    return issue(codec.OP.CLOSE, closeArgs, closed)
  end
  function c.dispose()
    if disposed then return end
    c.close(); disposed = true; generation = generation + 1
  end
  return c
end

package.loaded["rfsuite.lib.escape32_session"] = M
return M
