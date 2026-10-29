#!/usr/bin/env python3
"""Cross-repository ESCape32 v1 test; no hardware or network access.

Run: python3 bin/escape32/verify_bridge.py --firmware ../escape32-firmware
Requires a host C compiler and Lua 5.4. Uses the real portable firmware core,
an injected fake serial device, and the real Suite codec/session controller.
"""
import argparse
import ctypes as C
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--firmware", type=Path, required=True)
    parser.add_argument("--lua", default="lua5.4")
    args = parser.parse_args()
    suite = Path(__file__).resolve().parents[2]
    firmware = args.firmware.resolve()
    fixture = json.loads((suite / "bin/escape32/contract-v1.json").read_text())
    companion = json.loads((firmware / "src/test/fixtures/escape32-contract-v1.json").read_text())
    assert fixture == companion, "Companion contract fixtures differ"
    assert shutil.which(args.lua), "Lua 5.4 executable required"
    records = []
    with tempfile.TemporaryDirectory(prefix="escape32-bridge-") as scratch:
        scratch = Path(scratch)
        shared = scratch / "libescape32.so"
        subprocess.run(["gcc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-fPIC", "-shared",
                        str(firmware / "src/main/io/escape32.c"), "-o", str(shared)], check=True)
        core = C.CDLL(str(shared))
        Bool = C.CFUNCTYPE(C.c_bool, C.c_void_p)
        Acquire = C.CFUNCTYPE(C.c_bool, C.c_void_p, C.c_uint8)
        Write = C.CFUNCTYPE(C.c_bool, C.c_void_p, C.c_void_p, C.c_size_t)
        Read = C.CFUNCTYPE(C.c_int, C.c_void_p)
        Inhibit = C.CFUNCTYPE(None, C.c_void_p, C.c_bool)

        class Adapter(C.Structure):
            _fields_ = [("validatedTargets", C.c_uint16), ("writable", C.c_bool),
                        ("safe", Bool), ("acquire", Acquire), ("ready", Bool),
                        ("write", Write), ("read", Read), ("release", Bool), ("inhibit", Inhibit)]

        core.escape32Init.argtypes = [C.POINTER(Adapter), C.c_void_p]
        core.escape32Process.argtypes = [C.c_uint32]
        core.escape32Handle.argtypes = [C.c_uint32, C.POINTER(C.c_uint8), C.c_size_t,
                                       C.POINTER(C.c_uint8), C.c_size_t, C.c_uint32]
        core.escape32Handle.restype = C.c_bool
        now = 0
        rx, writes, inhibits, device_errors = [], [], [], []
        values = dict(zip((p["name"] for p in fixture["keys"]), [0, 16, 24, 48, 15, 0, 30, 0, 0]))
        safe = True
        corrupt = False

        def write_callback(_, pointer, length):
            text = C.string_at(pointer, length).decode("ascii")
            writes.append(text)
            if text == "info\n":
                response = "ESCape32 rev17.2 [TEST]\nTemp: 24C\nVolt: 12.00V\nCurr: 0.00A\nCsum: 0mAh\nERPM: 0\nOK\n"
            elif text.startswith("get "):
                key = text.split()[1]
                response = (f"{key}: 999999999999999999999\nOK\n" if corrupt
                            else f"{key}: {values[key]}\nOK\n")
            elif text.startswith("set "):
                _, key, raw = text.split()
                values[key] = 18 if key == "timing" and int(raw) == 19 else int(raw)
                response = f"{key}: {values[key]}\nOK\n"
            elif text == "save\n":
                response = "OK\n"
            else:
                # ctypes callbacks must return safely even on unexpected input.
                device_errors.append(f"Unexpected CLI command: {text!r}")
                return False
            rx.extend(response.encode("ascii"))
            return True

        # Keep callback references alive until the shared library is no longer used.
        callbacks = [Bool(lambda _: safe), Acquire(lambda _, target: target == 0),
                     Bool(lambda _: True), Write(write_callback),
                     Read(lambda _: rx.pop(0) if rx else -1), Bool(lambda _: True),
                     Inhibit(lambda _, enabled: inhibits.append(bool(enabled)))]
        adapter = Adapter(1, True, *callbacks)

        def handle(request, owner=7, record=False):
            incoming = (C.c_uint8 * len(request))(*request)
            outgoing = (C.c_uint8 * 32)()
            assert core.escape32Handle(owner, incoming, len(request), outgoing, 32, now)
            reply = list(outgoing)
            if record:
                records.append({"request": request, "reply": reply})
            return reply

        def header(op, token, rid):
            return [1, op, *token.to_bytes(4, "little"), *rid.to_bytes(2, "little")]

        def drain():
            nonlocal now
            for _ in range(40):
                now += 5
                core.escape32Process(now)

        core.escape32Init(None, None)
        for vector in fixture["vectors"]:
            actual = handle(vector["request"], record=True)
            assert actual == vector["reply"], vector["name"]
        # Exhaustive request lengths and arbitrary op/version bytes cannot access
        # a pin or write outside the bounded reply. The C unit test also uses ASan.
        for length in range(40):
            for op in range(9):
                handle(([1, op] + [255] * 40)[:length])
        assert writes == [] and inhibits == []

        core.escape32Init(C.byref(adapter), None)
        caps = handle([1, 0], record=True)
        assert caps[26] == 15 and caps[28] == 1
        opened = [1, 1, 0, 0, 0, 0, 1, 0, 0, 1, 120, 86, 52, 18]
        reply = handle(opened, record=True)
        token = int.from_bytes(bytes(reply[4:8]), "little")
        assert token and reply[2] == 2 and not reply[11] & 16
        assert handle(opened)[4:8] == reply[4:8], "OPEN retry changed ownership"
        assert handle(opened, owner=8)[2] == 2, "Other owner stole session"
        drain()
        reply = handle(header(2, token, 1), record=True)
        assert reply[2:4] == [0, 3] and reply[13:16] == [17, 2, 1]
        reply = handle(header(3, token, 2) + [1], record=True)
        drain()
        reply = handle(header(2, token, 2), record=True)
        assert reply[12] == 1 and int.from_bytes(bytes(reply[16:20]), "little") == 16
        set_request = header(4, token, 3) + [1, 18, 0, 0, 0]
        handle(set_request, record=True)
        drain()
        reply = handle(header(2, token, 3), record=True)
        assert reply[2] == 0 and reply[16] == 18 and reply[11] & 2
        count = len(writes)
        handle(set_request, record=True)
        assert len(writes) == count, "SET duplicate caused device write"
        save = header(5, token, 4)
        handle(save, record=True)
        drain()
        handle(save, record=True)
        reply = handle(header(2, token, 4), record=True)
        assert writes.count("save\n") == 1 and reply[2] == 0 and not reply[11] & 2
        assert handle(header(4, token, 4) + [1, 19, 0, 0, 0])[2] == 4
        # Heartbeats through >owner timeout must keep the actual C session alive.
        for _ in range(6):
            now += 2000
            reply = handle(header(2, token, 4))
            core.escape32Process(now)
            assert reply[3] == 3
        corrupt = True
        handle(header(3, token, 5) + [1])
        drain()
        reply = handle(header(2, token, 5), record=True)
        assert reply[2] == 7 and reply[11] & 16, "Malformed numeric response accepted"
        reply = handle(header(6, token, 6), record=True)
        assert reply[2] == 0 and reply[11] & 16, "Released error session cannot CLOSE"
        assert inhibits == [True, False], "Ownership was not released exactly once"

        # Real C snapshots are decoded by Lua; generated requests must match the
        # actual C wire format, not a separately hand-written UI reply mock.
        data = scratch / "records.json"
        wire_open = next(r for r in records if r["request"][1] == 1 and r["reply"][4:8] != [0, 0, 0, 0])
        ready_snapshot = next(r for r in records if r["request"][1] == 2 and r["reply"][3] == 3)
        data.write_text(json.dumps({"records": records, "wireOpen": wire_open["request"],
                                    "ready": ready_snapshot["reply"]}))
        check = scratch / "check.lua"
        check.write_text('''local root, file = arg[1], arg[2]
local codec = assert(loadfile(root .. "/src/rfsuite/lib/msp_esc_parameters_escape32.lua"))()
local json = assert(loadfile(root .. "/bin/i18n/lib/dkjson.lua"))()
local f = assert(io.open(file)); local data = assert(json.decode(f:read("*a"))); f:close()
for _, record in ipairs(data.records) do
  local r = assert(codec.decode(record.reply, record.request[2]))
  assert(r.requestId == record.reply[9] + record.reply[10] * 256)
  assert(r.token == record.reply[5] + record.reply[6]*256 + record.reply[7]*65536 + record.reply[8]*16777216)
end
local function eq(a,b) assert(#a==#b); for i=1,#a do assert(a[i]==b[i],"wire mismatch "..i) end end
eq(assert(codec.encode(codec.OP.OPEN,{requestId=1,target=0,nonce=0x12345678})), data.wireOpen)
local ready = assert(codec.decode(data.ready,codec.OP.STATUS))
assert(ready.schema==1 and ready.revision==17 and ready.patch==2)
print("C -> Lua contract snapshots: "..#data.records.." passed")
''')
        subprocess.run([args.lua, str(check), str(suite), str(data)], check=True)

        # A Lua controller now sends real wire requests to this C instance over
        # stdin/stdout. Device progression remains deterministic and uses no sleeps.
        rx.clear()
        core.escape32Init(C.byref(adapter), None)
        corrupt = False
        controller = scratch / "controller.lua"
        controller.write_text('''local root = arg[1]
package.loaded["rfsuite.lib.require"] = function(path)
  return assert(loadfile(root .. "/src/rfsuite/" .. path))()
end
local session = assert(loadfile(root .. "/src/rfsuite/lib/escape32_session.lua"))()
local json = assert(loadfile(root .. "/bin/i18n/lib/dkjson.lua"))()
io.stdout:setvbuf("line")
local now = 0
local droppedSave, droppedClose = false, false
local c = session.new({clock=function() return now end, send=function(message)
  io.write("REQUEST " .. json.encode(message.payload) .. "\\n")
  local reply = assert(json.decode(assert(io.read("*l"))))
  if message.payload[2]==5 and not droppedSave then
    droppedSave=true; message.errorHandler("timeout"); return
  end
  if message.payload[2]==6 and not droppedClose then
    droppedClose=true; message.errorHandler("timeout"); return
  end
  message.processReply(message,reply)
end})
local function settle()
  for _=1,30 do
    if c.state~="busy" and c.state~="opening" and c.state~="wait_power"
      and c.state~="outcome_unknown" then return end
    now=now+1; c.wakeup()
  end
  error("Session failed to settle: "..c.state)
end
c.setLink(true,false); assert(c.probe()); assert(c.state=="select_target")
assert(c.open(0)); settle(); assert(c.state=="ready" and c.canWrite())
assert(c.get(1)); settle(); assert(c.values[1]==18)
assert(c.set(1,19)); settle()
assert(c.values[1]==18 and c.normalized and c.dirty,"C normalization was lost")
assert(c.save()); settle(); assert(c.state=="save_confirmed" and not c.dirty)
for _=1,6 do now=now+2; c.wakeup() end
assert(c.state=="save_confirmed","heartbeat lost save result")
assert(c.close()); assert(c.state=="close_unknown","lost CLOSE must stay unconfirmed")
assert(c.recover()); assert(c.state=="closed" and c.token==0,"lost CLOSE not recovered")
print("Lua session <-> C core: OPEN/GET/normalized SET/SAVE/heartbeat/CLOSE passed (lost SAVE/CLOSE replies)")
''')
        child = subprocess.Popen([args.lua, str(controller), str(suite)], stdin=subprocess.PIPE,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            for line in child.stdout:
                if line.startswith("REQUEST "):
                    now += 100
                    drain()
                    child.stdin.write(json.dumps(handle(json.loads(line[8:]))) + "\n")
                    child.stdin.flush()
                else:
                    print(line, end="")
            _, error = child.communicate(timeout=10)
            assert child.returncode == 0, error
            assert not device_errors, device_errors
            assert writes.count("save\n") == 2, "Lost SAVE reply caused another flash save"
        finally:
            if child.poll() is None:
                child.kill()
                child.communicate()
    print("ESCape32 real C core / Lua codec bridge: passed (fake serial; hardware unverified)")


if __name__ == "__main__":
    main()
