-- Run from repository root: lua5.4 bin/escape32/verify_escape32.lua
local root = (debug.getinfo(1, "S").source:sub(2):match("^(.*)/bin/escape32/") or ".")
local prefix = root .. "/src/rfsuite/"
package.loaded["rfsuite.lib.require"] = function(path) return assert(loadfile(prefix .. path))() end
local codec = assert(loadfile(prefix .. "lib/msp_esc_parameters_escape32.lua"))()
local session = assert(loadfile(prefix .. "lib/escape32_session.lua"))()
local json = assert(loadfile(root .. "/bin/i18n/lib/dkjson.lua"))()
local f = assert(io.open(root .. "/bin/escape32/contract-v1.json")); local fixture = assert(json.decode(f:read("*a"))); f:close()
local checks = 0
local function check(ok, text) checks = checks + 1; assert(ok, text) end
local function equal(a, b) if #a ~= #b then return false end for i=1,#a do if a[i]~=b[i] then return false end end return true end
local function put(b, offset, n, count) for i=offset,offset+count-1 do b[i]=n%256; n=math.floor(n/256) end end
local function reply(op, changes)
  local b = {1,op,0,3,1,0,0,0,1,0,0,16,255,17,3,1,0,0,0,0,1,14,32,0,16,39,15,0,1,0,0,0}
  if changes then for i,v in pairs(changes) do b[i]=v end end
  return b
end
check(codec.COMMAND == fixture.command, "shared command")
for _,v in ipairs(fixture.vectors) do check(codec.decode(v.reply,v.reply[2]) ~= nil, v.name) end
check(equal(assert(codec.encode(0)),fixture.vectors[1].request),"CAPS vector")
check(equal(assert(codec.encode(1,{target=0,nonce=0x12345678,requestId=1})),fixture.vectors[4].request),"OPEN vector")
for i,p in ipairs(fixture.keys) do
  local actual=codec.PARAMETERS[i]
  check(actual.key==p.name and actual.min==p.min and actual.max==p.max and actual.scale==p.scale,"schema "..p.name)
end
check(not codec.canRead(assert(codec.decode(fixture.vectors[1].reply,0))),"core-only never opens")
check(not codec.decode({1,0},0),"truncation")
local bad=reply(0);bad[1]=2;check(not codec.decode(bad,0),"unknown version")
bad=reply(0);bad[24]=1;check(not codec.decode(bad,0),"reserved field")
bad=reply(0);bad[4]=255;check(not codec.decode(bad,0),"unknown state")
bad=reply(0);bad[17]=256;check(not codec.decode(bad,0),"invalid byte")
check(not codec.encode(4,{token=1,requestId=2,key=1,value=32}),"range")
check(not codec.encode(4,{token=1,requestId=2,key=1,value=1.5}),"fraction")
check(not codec.encode(3,{token=1,requestId=0,key=0}),"zero request id")
check(not codec.encode(1,{target=0,nonce=0,requestId=1}),"zero nonce")
local signed=reply(3);put(signed,17,0xFFFFFFFF,4);check(codec.decode(signed,3).value==-1,"signed value")
check(codec.canWrite(codec.decode(reply(1),1)),"known ESCape32 17.3 schema writable")
check(codec.canWrite(codec.decode(reply(1,{[15]=2}),1)),"known ESCape32 17.2 stays compatible")
check(not codec.canWrite(codec.decode(reply(1,{[15]=4}),1)),"unknown 17.4 schema denied")
check(not codec.canWrite(codec.decode(reply(1,{[14]=16}),1)),"unknown 16.3 schema denied")
check(not codec.canWrite(codec.decode(reply(1,{[12]=17}),1)),"known revision readonly flag respected")
check(not codec.canWrite(codec.decode(reply(1,{[27]=7}),1)),"known revision write capability required")

local queue, now, c
local function fresh()
  queue={};now=0;c=session.new({send=function(m)queue[#queue+1]=m end,clock=function()return now end})
  c.setLink(true,false);return c
end
local function take(op)
  local m=table.remove(queue,1);check(m and m.payload[2]==op,"expected operation "..op);return m
end
local function respond(op, changes)
  local m=take(op);local b=reply(op,changes);m.processReply(m,b);return b
end
local function supported()
  fresh();c.probe();respond(0,{[5]=0,[9]=0,[11]=255,[4]=0})
  check(c.state=="select_target","CAPS enables selector")
end
local function opened()
  supported();check(c.open(0),"open supported target");respond(1)
  check(c.state=="ready" and c.canWrite(),"supported session ready")
end
fresh();check(not c.open(0) and #queue==0,"unprobed never opens")
c.probe();local m=take(0);m.processReply(m,fixture.vectors[1].reply)
check(not c.open(0) and #queue==0,"unsupported never sends OPEN")
supported();check(not c.open(1) and #queue==0,"target mask")
opened();c.get(1);respond(3,{[9]=2,[12]=24,[13]=1,[17]=16})
check(c.values[1]==16 and c.state=="ready","read raw value")
c.set(1,18);respond(4,{[3]=8,[9]=3,[12]=26,[13]=1,[17]=17})
check(c.values[1]==17 and c.normalized and c.dirty,"normalization is authoritative")
check(c.save(),"save dirty session");m=take(5);check(m.maxRetries==0,"no automatic flash retry")
m.errorHandler("timeout");check(c.state=="outcome_unknown","unknown save outcome")
now=1;c.wakeup();respond(2,{[9]=4,[12]=16})
check(c.state=="save_confirmed" and not c.dirty and c.lastOperation==5,"recover save without reissuing")
check(not c.save() and #queue==0,"clean save refused")
now=4;c.wakeup();respond(2,{[9]=4,[12]=16})
check(c.state=="save_confirmed" and c.lastOperation==5,"idle heartbeat preserves save status")
now=6;c.wakeup();respond(2,{[9]=4,[12]=16})
now=8;c.wakeup();respond(2,{[9]=4,[12]=16})
now=10;c.wakeup();respond(2,{[9]=4,[12]=16})
check(c.state=="save_confirmed","idle session heartbeats through owner timeout")
opened();c.get(0);respond(3,{[3]=2,[4]=4,[9]=2,[12]=0})
check(c.state=="busy" and not c.get(1),"single outstanding transaction")
now=1;c.wakeup();respond(2,{[9]=2,[12]=24,[13]=0,[17]=1})
check(c.values[0]==1,"poll completes GET")
opened();c.get(0);respond(3,{[9]=2,[12]=24,[13]=1,[17]=1})
check(c.state=="error" and c.values[0]==nil,"wrong key rejected")
opened();c.get(0);respond(3,{[9]=2,[5]=2,[12]=24,[13]=0,[17]=1})
check(c.state=="error","wrong token rejected")
opened();c.reply.schema=0;check(not c.canWrite() and not c.set(0,1),"unknown schema readonly")
check(not c.get(0) and #queue==0,"unknown schema emits no GET")
c.reply.schema=1;c.reply.capabilities=7;check(not c.canWrite() and not c.save(),"capability write gate")
opened();c.reply.patch=2;check(c.canWrite() and c.get(0),"17.2 session remains compatible")
respond(3,{[9]=2,[12]=24,[13]=0,[17]=1,[15]=2})
check(c.values[0]==1,"17.2 parameter readback")
opened();c.reply.patch=4
check(not c.canWrite() and not c.get(0) and not c.set(0,1) and not c.save() and #queue==0,"17.4 sends no parameter operations even with schema1")
opened();c.reply.revision=16
check(not c.canWrite() and not c.get(0) and not c.set(0,1) and not c.save() and #queue==0,"16.3 sends no parameter operations")
opened();c.get(0);m=take(3);c.close();respond(6,{[3]=5,[4]=9,[9]=3,[12]=21})
m.processReply(m,reply(3,{[9]=2,[12]=24,[13]=0,[17]=1}))
check(c.state=="restart_required" and c.values[0]==nil,"late reply cannot revive closed session")
opened();c.close();respond(6,{[3]=3,[9]=2})
check(c.state=="close_unknown" and c.token==1,"failed close not released")
opened();c.close();m=take(6);m.errorHandler("timeout")
check(c.state=="close_unknown","lost close acknowledgment")
c.recover();respond(2,{[9]=2,[4]=0})
check(c.state=="closed" and c.token==0,"recover CLOSED via status")
opened();c.close();m=take(6);m.errorHandler("timeout")
c.recover();respond(2,{[3]=5,[9]=2,[4]=9,[12]=21})
check(c.state=="restart_required" and c.token==0,"recover CLOSE restart requirement")
supported();c.open(0);m=take(1);c.dispose();m.processReply(m,reply(1))
check(#queue==1 and queue[1].payload[2]==6,"late OPEN releases acquired token")
supported();c.open(0);m=take(1);local original=m.payload;m.errorHandler("timeout")
check(c.state=="open_unknown" and not c.open(0) and not c.probe(),"lost OPEN cannot start a different session")
check(c.recover(),"explicit OPEN recovery");m=take(1)
check(equal(original,m.payload),"OPEN recovery preserves nonce and request ID")
m.processReply(m,reply(1));check(c.state=="ready","OPEN recovered")
opened();c.setLink(false,false);check(c.state=="disconnected","link loss visible")
local n=#queue;c.setLink(false,false);check(#queue==n,"no close storm on repeated link snapshot")
print("ESCape32 codec/session: "..checks.." checks passed (Lua ".._VERSION..")")
