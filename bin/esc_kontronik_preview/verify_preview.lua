-- KBiDir decoder + real page integration. Run from repository root with Lua 5.4.
local checks = 0
local function check(ok, label)
  checks = checks + 1
  assert(ok, label)
end
system = {getVersion=function() return {simulation=true} end}
local deps = {}
deps["app/tile_grid.lua"] = dofile("src/rfsuite/app/tile_grid.lua")
deps["app/field_layout.lua"] = dofile("src/rfsuite/app/field_layout.lua")
local lastFieldRuntime
local buildSingle=deps["app/field_layout.lua"].buildSingle
deps["app/field_layout.lua"].buildSingle=function(runtime,...)
 lastFieldRuntime=runtime
 return buildSingle(runtime,...)
end
package.loaded["rfsuite.lib.require"] = function(path)
  return deps[path] or error("Unexpected dependency: " .. path)
end
deps["lib/mspcodec.lua"] = dofile("src/rfsuite/lib/mspcodec.lua")
local codec = dofile("src/rfsuite/lib/msp_esc_parameters_kontronik.lua")
deps["lib/msp_esc_parameters_kontronik.lua"] = codec
local wire = deps["lib/mspcodec.lua"]
local file=assert(io.open(arg[1] or "bin/esc_kontronik_preview/kbidir_msp217_v4_vectors.json","rb"))
local vectorJson=file:read("*a");file:close()
check(vectorJson:find('"revision"%s*:%s*"kbidir%-msp217%-v4%-r3"')~=nil,"shared fixture revision r3")
-- Use the firmware-owned raw pairs instead of maintaining a second captured fixture.
local raw={}
for b in assert(vectorJson:match('"pairs_hex"%s*:%s*"([%x%s]+)"')):gmatch("%x%x") do raw[#raw+1]=tonumber(b,16) end
check(#raw==41*6,"captured KOLIBRI raw pair count")
local kolibri={};raw.offset=1
for i=1,41 do kolibri[i]={wire.readU16(raw),wire.readU32(raw)} end
local function copy(b) local out = {}; for i=1,#b do out[i]=b[i] end; return out end
local function fixture(options)
  local o = options or {}
  local model, ps = o.model or "KOLIBRI140+LV", o.pairs or kolibri
  local b = {0x4C,0,0}
  wire.writeU32(b,1);wire.writeU32(b,o.session or 1);wire.writeU32(b,o.generation or 9)
  wire.writeU16(b,#ps);wire.writeU16(b,o.version or 0x0402)
  wire.writeU32(b,o.parameterAge or 0);wire.writeU32(b,o.modelAge or 0)
  b[#b+1]=o.flags or 7;b[#b+1]=#model;wire.writeU16(b,30000)
  for i=1,#model do b[#b+1]=model:byte(i) end
  local tx={b}
  for offset=0,#ps-1,14 do
    local block={0x4C,1,0};wire.writeU32(block,1);wire.writeU16(block,offset)
    block[#block+1]=math.min(14,#ps-offset);block[#block+1]=0
    for i=offset+1,math.min(offset+14,#ps) do wire.writeU16(block,ps[i][1]);wire.writeU32(block,ps[i][2]) end
    tx[#tx+1]=block
  end
  for _,buf in ipairs(tx) do for i=#buf+1,96 do buf[i]=0 end end
  return tx
end
local empty = fixture({model="",pairs={},flags=0,version=0,generation=0,parameterAge=0xFFFFFFFF,modelAge=0xFFFFFFFF})
local shared, group = {},nil
for kind,hex in vectorJson:gmatch('"kind"%s*:%s*"([%w_]+)".-"response_hex"%s*:%s*"([%x%s]+)"') do
  local p={};for byte in hex:gmatch("%x%x") do p[#p+1]=tonumber(byte,16) end
  if kind=="metadata" then group={};shared[#shared+1]=group end
  if kind=="metadata" or kind=="block" then group[#group+1]=p end
end
check(#shared==3,"three shared V4-r3 acquisitions")
local function decodeTransaction(tx)
  local current,outcome,kind
  local reader=codec.newReader(function(m) current=m end,function(d) outcome=d end,function(k) kind=k end)
  for i,p in ipairs(tx) do
    reader:wakeup()
    local msg=current; msg.processReply(msg,copy(p))
    if i<#tx then check(outcome==nil,"partial snapshot withheld") end
  end
  return outcome,kind
end
for _ in vectorJson:gmatch('"request_hex"%s*:%s*""') do
  check(#codec.buildReadMessage(function() end,function() end).payload==0,"empty V4 request")
end
local responseCount=0
local sharedReplacement
for hex in vectorJson:gmatch('"response_hex"%s*:%s*"([%x%s]+)"') do
  local buf={};for b in hex:gmatch("%x%x") do buf[#buf+1]=tonumber(b,16) end
  check(#buf==96,"every exact firmware response is 96 bytes")
  local decoded=buf[2]==0 and codec.decodeStart(buf) or codec.decodeBlock(buf)
  check(decoded~=nil,"every exact firmware response decodes")
  if buf[2]==0 and decoded.retrievalId==2 then sharedReplacement=buf end
  responseCount=responseCount+1
end
check(responseCount==17 and sharedReplacement~=nil,"all firmware replies including snapshot replacement checked")
local good=shared[1]
for i,tx in ipairs(shared) do
  local d=assert(decodeTransaction(tx))
  check(#d.pairs==({41,0,64})[i] and d.revision=="kbidir-msp217-v4-r3","shared count and revision "..i)
  for _,p in ipairs(tx) do check(#p==96,"bounded response") end
end
check(#good[1]==96 and #good[#good]==96 and good[#good][10]==13,"KOLIBRI short final block")
check(#shared[3][1]==96 and #shared[3][#shared[3]]==96 and shared[3][#shared[3]][10]==8,"maximum short final block")
check(#good==4 and good[2][10]==14 and good[3][10]==14 and good[4][10]==13,"41 pairs split 14/14/13")
check(#shared[3]==6,"64 pairs use five blocks")
for i=2,6 do
  local b=shared[3][i]
  check(b[8]+256*b[9]==(i-2)*14 and b[10]==(i==6 and 8 or 14),"maximum block offset/count "..i)
end
check(good[2][96]==0,"full fourteen-pair block retains its final padding byte")
local wrongOffset,offsetError=codec.decodeBlock(copy(good[3]),1,0,41)
check(wrongOffset==nil and offsetError=="correlation","explicit expected block offset is checked")
check(codec.decodeBlock(copy(good[3]),1,14,41)~=nil,"matching expected block offset accepted")
local data=assert(decodeTransaction(good))
check(data.model=="KOLIBRI140+LV" and data.eepromVersion==0x0402,"captured metadata")
for i,p in ipairs(kolibri) do check(data.pairs[i].pointer==p[1] and data.pairs[i].value==p[2],"ordered pair "..i) end
check(data.byPointer[0x4004]==1116789 and data.byPointer[0x4058]==4294791047,"raw U32 retained")
check(data.fields.bec_voltage==5500 and data.fields.pole_number==2 and data.fields.gear_ratio==9.5,"projection")
local duplicates={{0x2010,5500},{0x9999,0xFFFFFFFF},{0x4004,1116789},{0x2010,5500},{0x4004,0}}
local ambiguous=assert(decodeTransaction(fixture({pairs=duplicates})))
check(#ambiguous.pairs==5 and ambiguous.byPointer[0x9999]==0xFFFFFFFF,"unknown/duplicate pairs retained")
check(ambiguous.fields.bec_voltage==nil and ambiguous.fields.battery_type==nil,"ambiguous projections hidden")
check(assert(decodeTransaction(fixture({model="  MODEL  "}))).model=="  MODEL  ","spaces retained")
check(decodeTransaction(empty)~=nil,"empty needs no block")
local cross={};for i,pair in ipairs(kolibri) do cross[i]={pair[1],pair[2]} end
cross[#cross+1]={0x9999,0xFFFFFFFF};cross[#cross+1]={0x2010,5500}
local across=assert(decodeTransaction(fixture({pairs=cross})))
check(across.fields.bec_voltage==nil and across.fields.pole_number==2
  and across.pairs[42].pointer==0x9999 and across.pairs[43].pointer==0x2010,
  "duplicate across block boundary suppresses only its field and preserves order")
local largest=assert(decodeTransaction(shared[3]))
check(largest.pairs[64].pointer==0x40FC and largest.pairs[64].value==0xFFFFFFC0,"maximum final U32 pair retained")
check(decodeTransaction(fixture({flags=3,version=0}))~=nil,"missing BCD permitted")
check(decodeTransaction(fixture({model="",flags=5,modelAge=0xFFFFFFFF}))~=nil,"missing model permitted")
local function reject(b,label)
  local value
  if b[2]==1 then value=codec.decodeBlock(b,1,0,41) else value=codec.decodeStart(b) end
  check(value==nil,"reject "..label)
end
for length=0,#good[1]-1 do local b={};for i=1,length do b[i]=good[1][i] end;reject(b,"truncated start "..length) end
for _,change in ipairs({{1,0x4B},{2,0x41},{3,2},{4,0},{16,65},{28,8},{28,4},{29,32},{30,0},{32,0},{32,127},{32,1.5},{32,"A"}}) do
  local b=copy(good[1]);b[change[1]]=change[2];reject(b,"bad start")
end
for length=0,#good[2]-1 do local b={};for i=1,length do b[i]=good[2][i] end;reject(b,"truncated block "..length) end
for _,change in ipairs({{3,3},{10,15},{11,1}}) do local b=copy(good[2]);b[change[1]]=change[2];reject(b,"bad block") end
for _,case in ipairs({{pairs={}},{model=""},{flags=3},{flags=2},{flags=5},
  {parameterAge=2000},{modelAge=2000},{parameterAge=0xFFFFFFFF},{modelAge=0xFFFFFFFF}}) do
  reject(fixture(case)[1],"capture availability/age invariant")
end
local oldSchema=copy(good[1]);oldSchema[2]=0x42;reject(oldSchema,"V2 schema")
for _,tx in ipairs(shared) do
  for _,buf in ipairs(tx) do
    local meaningful=buf[2]==0 and 31+buf[29] or 11+6*buf[10]
    for i=meaningful+1,96 do
      local bad=copy(buf);bad[i]=1
      reject(bad,"nonzero padding byte "..i)
    end
  end
end
local oldCyclic=copy(good[1]);oldCyclic[2]=0x43;reject(oldCyclic,"V3 schema")
local oldV4=copy(good[1]);table.insert(oldV4,2,0x44);oldV4[97]=nil
reject(oldV4,"obsolete V4 version byte")
-- Cyclic collection tolerates out-of-order, repeated and lost blocks.
local current,outcome,kind,reader,sends
local function begin()
  outcome,kind,sends=nil,nil,0
  reader=codec.newReader(function(m) current=m;sends=sends+1 end,function(d) outcome=d end,function(k) kind=k end)
  reader:wakeup()
  check(#current.payload==0,"empty direct read")
end
local function deliver(payload)
  local m=current;m.processReply(m,copy(payload));reader:wakeup()
end
begin();deliver(good[2]);check(not outcome,"block before metadata ignored")
deliver(good[1]);deliver(good[2]);deliver(good[4]);deliver(good[1]);deliver(good[2])
check(not outcome and not kind,"repeated metadata preserves partial; middle block still missing")
deliver(good[3]);check(outcome and #outcome.pairs==41,"later cycle recovers middle loss")
begin();deliver(good[1]);deliver(good[2]);deliver(good[2]);check(not kind,"identical duplicate ignored")
local bad=copy(good[2]);bad[13]=bad[13]~1;deliver(bad)
check(kind=="incompatible" and not outcome,"conflicting duplicate invalidates partial")
begin();deliver(good[1]);local bad=copy(good[1]);bad[13]=bad[13]+1;deliver(bad)
check(kind=="incompatible","conflicting same-ID metadata rejected")
begin();deliver(good[1]);deliver(good[2])
local replacement=fixture({pairs={{0x2010,6000}},session=2})
for _,b in ipairs(replacement) do b[4]=2 end
deliver(replacement[1]);deliver(good[3]);deliver(replacement[2])
check(outcome and #outcome.pairs==1 and outcome.fields.bec_voltage==6000 and outcome.sessionId==2,"snapshot switch never mixes IDs")
begin();deliver(good[1]);deliver(good[2]);deliver(sharedReplacement)
for i=3,#good do deliver(good[i]) end
check(not outcome and not kind,"exact firmware replacement metadata discards old-ID pairs")
for i=2,#good do local b=copy(good[i]);b[4]=2;deliver(b) end
check(outcome and outcome.retrievalId==2 and outcome.generation==4,"new snapshot publishes only its own pairs")
begin();deliver(good[1]);local short=copy(good[2]);short[10]=13
for i=11+13*6+1,96 do short[i]=0 end
deliver(short);check(kind=="incompatible" and not outcome,"aligned non-final block requires fourteen pairs")
for _,offset in ipairs({1,12,13,41,64,65535}) do
  begin();deliver(good[1]);local b=copy(good[2]);b[8]=offset&255;b[9]=offset>>8;deliver(b)
  check(kind=="incompatible" and not outcome,"reject unaligned/out-of-range block "..offset)
end
begin();deliver(good[1]);local b=copy(good[2]);b[4]=2;deliver(b)
check(not outcome and not kind,"unknown ID block contributes nothing")
for i=2,#good do deliver(good[i]) end
check(outcome and #outcome.pairs==41,"known ID completes after unknown ID")
for reason,expected in pairs({[true]="msp_error",cleared="transport_error"}) do
  begin();current.errorHandler(reason);check(kind==expected,"error "..tostring(reason))
end
begin();current.errorHandler("max_retries");reader:wakeup()
check(not kind and sends==2,"lost response retries another cyclic read")
local realClock=os.clock;local now=0;os.clock=function() return now end
begin();now=30;reader:wakeup();check(kind=="timeout","page-local deadline while pending")
current.processReply(current,copy(good[1]));check(not outcome,"late reply after deadline ignored")
now=0;begin();deliver(good[1]);deliver(good[2]);now=29
deliver(replacement[1]);now=30;deliver(replacement[2])
check(kind=="timeout" and not outcome,"snapshot switch never extends overall deadline")
now=0;begin();deliver(good[1]);deliver(good[2]);now=30
current.errorHandler("timeout");check(kind=="timeout" and not outcome,"partial collection expires on error callback")
os.clock=realClock
begin();reader:cancel();current.processReply(current,copy(good[1]));reader:wakeup()
check(sends==1 and not outcome and not kind,"cancel suppresses late response")
check(not codec.WRITE_COMMAND and not codec.buildWriteMessage and not codec.encode,"no write path")
-- Every block truncated prefix and trailing data must fail exact-length validation.
for i=2,#good do
  local offset=(i-2)*14
  for n=0,#good[i]-1 do
    local bad={};for k=1,n do bad[k]=good[i][k] end
    check(codec.decodeBlock(bad,1,offset,41)==nil,"truncated block offset "..offset.." length "..n)
  end
  local bad=copy(good[i]);bad[#bad+1]=0
  check(codec.decodeBlock(bad,1,offset,41)==nil,"overlong block")
end
local bad=copy(good[1]);bad[#bad+1]=0;reject(bad,"overlong start")
local terminal={0x4C,1,0,1,0,0,0,41,0,0,0}
for i=#terminal+1,96 do terminal[i]=0 end
check(codec.decodeBlock(terminal,1,41,41)==nil,"V4 has no terminal probe")

-- Exercise actual page lifecycle, callbacks and static text using the real bus.
local bus = dofile("src/rfsuite/lib/bus.lua")
deps["lib/bus.lua"] = bus
local clock = 0
os.clock = function() return clock end
local widgets, options, handlers, nav, sent = {}, nil, {}, {}, {}
local dialog,dialogClosed,dialogCount=nil,false,0
local updates,builds = 0,0
local focusedLabel
local function widget(line,text)
  local w={label=line,text=text}
  function w:value(v) self.text=v; updates=updates+1 end
  function w:focus() focusedLabel=self.label end
  widgets[#widgets+1]=w
  return w
end
form={clear=function() widgets={};builds=builds+1 end, addLine=function(t) return t end,
  getFieldSlots=function() return {{x=0,y=0,w=460,h=20}} end,
  addExpansionPanel=function() return {open=function() end,addLine=function(_,t) return t end} end,
  addStaticText=function(line,_,text) return widget(line,text) end,
  addButton=function(line,_,args)
    local w=widget(line,args.text);w.press=args.press
    function w:enable(value) self.enabled=value end
    return w
  end,
  addNumberField=function(line,_,minimum,maximum,get,set)
    assert(minimum>=-0x80000000 and maximum<=0x7FFFFFFF,"native signed widget overflow")
    local w=widget(line,nil);w.get=get;w.set=set;w.min=minimum;w.max=maximum
    function w:enable(v) self.enabled=v end
    function w:minimum(v) assert(v>=-0x80000000 and v<=0x7FFFFFFF,"native minimum overflow");self.min=v;if self.get()<v then self.set(v) end end
    function w:maximum(v) assert(v>=-0x80000000 and v<=0x7FFFFFFF,"native maximum overflow");self.max=v;if self.get()>v then self.set(v) end end
    function w:default(v) self.defaultValue=v end
    function w:decimals(v) self.decimalPlaces=v end
    function w:suffix(v) self.unit=v end
    function w:step(v) self.increment=v end
    return w
  end,
  addChoiceField=function(line,_,choices,get,set)
    local w=widget(line,nil);w.get=get;w.set=set;w.choices=choices
    function w:enable(v) self.enabled=v end
    return w
  end,
  addBooleanField=function(line,_,get,set)
    local w=widget(line,nil);w.get=get;w.set=set
    function w:enable(v) self.enabled=v end
    return w
  end,
  openDialog=function(args)
    dialog=args;dialogClosed=false;dialogCount=dialogCount+1
    return {close=function() dialogClosed=true end}
  end}
deps["app/header.lua"]={build=function(_,o)
  options=o
  local reload=o.onReload
  options.onReload=reload and function() reload(); if handlers.wakeup then handlers.wakeup() end end or nil
  nav={setReloadEnabled=function(v) nav.reload=v end}
  return nav
end}
deps["app/close_key.lua"]={shouldHandleClose=function() return true end}
bus.subscribe("msp.request",function(m) check(m.command==217 and not m.isWrite,"page only reads 217"); sent[#sent+1]=m end)
local function session(values)
  bus.publish("session.update",values or {connected=true,isArmed=false,mspTransport="sport",handshake={apiVersion=true}})
end
session()
local received
local originalReader=codec.newReader
codec.newReader=function(send,onData,onError)
  return originalReader(send,function(d) received=d;onData(d) end,onError)
end
local expertLabelKeys={"undervoltage_behavior","undervoltage_cell","discharge_limit","PWM_min","slewrate_up","slewrate_down","extra_smooth_IU","alternate_startup","startup_curr_limit","expert_settings"}
local english=assert(io.open("bin/i18n/json/en.json","rb"));local englishJson=english:read("*a");english:close()
local kontrJson=assert(englishJson:match('"kontr"%s*:%s*({.*)'))
local markedLabels={}
for _,key in ipairs(expertLabelKeys) do
 markedLabels[key]=assert(kontrJson:match('"'..key..'"%s*:%s*{%s*"english"%s*:%s*"([^"]+)"'),key)
 check(markedLabels[key]:sub(-2)==" *","English expert label ends with literal star: "..key)
end
local function labelFor(key)
 return markedLabels[key] or "@i18n(app.modules.esc_tools.mfg.kontr."..key..")@"
end
local function loadPage()
  local f=assert(io.open("src/rfsuite/app/pages/esc_forward_kontronik.lua","r"));local source=f:read("*a");f:close()
  source=source:gsub("@i18n%(app.modules.esc_tools.mfg.kontr.eeprom_summary%)@",function() return "EEPROM %s" end)
  source=source:gsub("@i18n%(app.modules.esc_tools.mfg.kontr.([%w_]+)%)@",function(key) return markedLabels[key] or "@i18n(app.modules.esc_tools.mfg.kontr."..key..")@" end)
  return assert(load(source,"@src/rfsuite/app/pages/esc_forward_kontronik.lua"))()
end
local page=loadPage()
local function open()
  page.open({setWakeupHandler=function(v) handlers.wakeup=v end,
    setEventHandler=function(v) handlers.event=v end,
    setCleanupHandler=function(v) handlers.cleanup=v end})
end
local function text(key)
  for _, w in ipairs(widgets) do
    if w.label == labelFor(key) then
      if w.get then
        if w.choices then
          for _,choice in ipairs(w.choices) do if choice[2]==w.get() then return choice[1] end end
        end
        local value=w.decimalPlaces and string.format("%."..w.decimalPlaces.."f",w.get()/10^w.decimalPlaces) or tostring(w.get())
        return value..(w.unit and (" "..w.unit) or "")
      end
      return w.text
    end
  end
  error("Missing widget "..key)
end
local function status() return widgets[1].text end
local function isStatus(key)
  if key=="ready" then return status():find("KOLIBRI140+LV",1,true)~=nil end
  return status()=="@i18n(app.modules.esc_tools.mfg.kontr."..key..")@"
end
local function control(key)
  for _,w in ipairs(widgets) do
    if w.label==labelFor(key) then return w end
  end
  error("Missing control "..key)
end
local function answer(payload)
  local tx=type(payload[1])=="table" and payload or {payload}
  for _,p in ipairs(tx) do handlers.wakeup();local m=sent[#sent];m.processReply(m,copy(p));handlers.wakeup() end
  handlers.wakeup()
end
open()
check(not options.onSave and not options.onReload and not options.onTool,"Save and Reload disabled during acquisition")
local count=#sent; handlers.wakeup(); check(#sent==count,"overlapping request suppressed")
answer(good)
check(isStatus("ready") and text("bec_voltage")=="5500 mV" and text("pole_number")=="2"
  and text("status_model")=="KOLIBRI140+LV" and text("status_eeprom")=="0402", "page renders shared snapshot")
local before,beforeBuilds=updates,builds
for i=1,100 do session(); handlers.wakeup() end
check(updates==before and builds==beforeBuilds,"unchanged wakeup/session does not update widgets or rebuild editor")
check(status()=="KOLIBRI140+LV / EEPROM 4.02","model and honest EEPROM version displayed at top")
check(not control("expert_settings").get() and not control("undervoltage_cell").enabled,"expert fields default locked")
control("expert_settings").set(true)
local bec=control("bec_voltage")
check(bec.enabled and bec.get()==5500,"received BEC is editable")
bec.set(6000)
check(bec.get()==6000 and received.fields.bec_voltage==5500,"edit changes draft without mutating captured data")
local toggle=control("alarm_edit")
local alarm=control("max_esc_temp");local oldAlarm=alarm.get()
check(toggle.get()==false and not alarm.enabled,"ESC alarm editing defaults off")
alarm.set(oldAlarm+1);check(alarm.get()==oldAlarm,"disabled alarm setter rejected")
local beforeAlarm=#sent
toggle.set(true)
check(toggle.get() and alarm.enabled and dialogCount==1,"enabling shows ESC alarm notice and unlocks fields")
check(dialog.message=="@i18n(app.modules.esc_tools.mfg.kontr.alarm_warning)@","ESC-specific warning used")
dialog.buttons[1].action();toggle.set(true);check(dialogCount==1,"no repeat notice without state change")
alarm.set(oldAlarm+1);check(alarm.get()==oldAlarm+1,"enabled alarm edits remain local")
toggle.set(false);check(not alarm.enabled and alarm.get()==oldAlarm+1,"off disables editing and retains local draft")
check(#sent==beforeAlarm and not options.onSave,"alarm toggle never sends MSP or enables Save")
local sentBeforeEdit=#sent
control("gear_ratio").set(1234);dialog.buttons[1].action()
check(text("gear_ratio")=="12.34" and control("gear_ratio").decimalPlaces==2,"ratio editing retains decimal precision")
control("startuptime").set(13000)
check(text("startuptime")=="13.000 s","startup editing retains millisecond display precision")
control("pole_number").set(3)
check(control("pole_number").get()==2,"invalid odd pole count rejected")
control("brake").set(0)
local prop=control("prop_brake");local saved=prop.get();prop.set(1)
check(not prop.enabled and prop.get()==saved,"disabled brake dependency rejects setter")
control("rpm_ctl").set(0)
local rpm=control("max_rpm");saved=rpm.get();rpm.set(50000)
check(not rpm.enabled and rpm.get()==saved,"disabled governor dependency rejects setter")
local battery=control("battery_type")
battery.set(2);control("undervoltage_cell").set(2000)
battery.set(1);check(control("undervoltage_cell").get()==1200,"chemistry retains original independent cutoff")
battery.set(2);check(control("undervoltage_cell").get()==2000,"chemistry retains local cutoff edit")
check(#sent==sentBeforeEdit and not options.onSave and not options.onTool,"local edits never queue MSP218, presets or any transport request")
options.onReload();answer(good)
check(control("bec_voltage").get()==5500 and text("gear_ratio")=="9.50" and not control("alarm_edit").get(),"Reload discards local draft and alarm unlock")
options.onReload(); answer(fixture({pairs=duplicates}))
check(text("bec_voltage")=="--" and text("battery_type")=="--", "page hides ambiguous fields")
options.onReload(); answer(empty)
check(isStatus("unavailable") and text("status_model")=="--" and text("bec_voltage")=="--", "valid empty replaces previous values")
options.onReload(); answer({0})
check(isStatus("incompatible"),"incompatible UI")
for _, case in ipairs({{true,"msp_error"},{"max_retries","timeout"},{"cleared","transport_error"}}) do
  options.onReload(); sent[#sent].errorHandler(case[1]); if case[1]=="max_retries" then clock=clock+30 end; handlers.wakeup()
  check(isStatus(case[2]),"UI distinguishes "..case[2])
end
options.onReload(); clock=3; answer(good)
check(isStatus("ready") and text("bec_voltage")=="5500 mV", "frozen acquisition survives transfer duration")
options.onReload(); answer(fixture({parameterAge=1900,modelAge=0}))
clock=63.2; handlers.wakeup()
check(text("bec_voltage")=="5500 mV" and text("status_model")=="KOLIBRI140+LV"
  and text("parameter_age")=="1900 ms" and text("read_duration")~="--", "capture ages separate from retrieval duration, no post-read expiry")
control("alarm_edit").set(true)
options.onReload(); check(dialogClosed,"Reload closes ESC alarm notice"); local late=sent[#sent]
session({connected=false}); handlers.wakeup()
late.processReply(late,copy(good[1])); handlers.wakeup()
check(isStatus("disconnected") and text("status_model")=="--" and not nav.reload,"disconnect clears and rejects late callback")
session(); handlers.wakeup(); options.onReload(); answer(good)
session({connected=true,isArmed=false,mspTransport="sport",handshake={apiVersion=false}}); handlers.wakeup()
check(text("bec_voltage")=="--", "handshake reset clears snapshot")
session(); handlers.wakeup(); options.onReload(); answer(good)
session({connected=true,isArmed=true,mspTransport="sport",handshake={apiVersion=true}}); handlers.wakeup()
check(text("bec_voltage")=="--" and not nav.reload,"arming invalidates page")
session(); handlers.wakeup(); options.onReload(); local closed=sent[#sent]
local stale=control("bec_voltage");local cleanup=handlers.cleanup; cleanup()
local beforeClose=#sent;if stale.set then stale.set(7000) end;check(#sent==beforeClose,"closed draft setters send nothing")
local _,live=deps["app/field_layout.lua"].poolStats();check(live==0,"close detaches pooled field accessors")
check(not handlers.wakeup and not handlers.event and not handlers.cleanup,"cleanup releases handlers")
closed.processReply(closed,copy(good[1])); closed.errorHandler(true)
open(); answer(empty)
check(isStatus("unavailable") and text("bec_voltage")=="--","reopening retains no prior values")
handlers.event(0,0)
check(not handlers.wakeup,"Back disposes page")
-- The maximum model must fit the smallest value column without losing raw metadata.
lcd = {getWindowSize=function() return 472,288 end, font=function() end,
  getTextSize=function(s) return #s*12,20 end}
open(); answer(shared[3])
check(not control("max_rpm").get and text("max_rpm")==tostring(received.fields.max_rpm),"oversized U32 remains visible without native widget overflow")
check(#text("status_model")*12 <= 216 and text("status_model"):sub(-3)=="..."
  and #assert(decodeTransaction(shared[3])).model==31,"long model fits X18 value column; raw name preserved")
session({connected=true,isArmed=false,mspTransport="crsf",handshake={apiVersion=true}}); handlers.wakeup()
check(text("status_model")=="--", "transport swap invalidates snapshot")
options.onReload(); answer(fixture({session=2,pairs={{0x2010,6000}}}))
check(text("bec_voltage")=="6000 mV" and text("pole_number")=="--", "new session snapshot replaces without merging")
handlers.cleanup()
system = {getVersion=function() return {simulation=true} end}
page = loadPage()
session(); open()
while sent[#sent].simulatorResponse do
  local previous=#sent;for i=1,5 do answer(sent[#sent].simulatorResponse) end;if #sent==previous then break end
end
local demoChanges={[0x2008]=800,[0x200A]=3000,[0x204C]=14300,[0x204A]=100,[0x2048]=10,[0x4004]=1116788,[0x203E]=100,[0x4058]=0xFFFD1C8F}
for i,p in ipairs(kolibri) do
 check(received.pairs[i].pointer==p[1] and received.pairs[i].value==(demoChanges[p[1]] or p[2]),"simulator demo pair "..i)
end
check(text("rc_check")=="@i18n(app.modules.esc_tools.mfg.kontr.rc_valid)@","demo RC endpoints valid")
check(control("gear_ratio").get()==100,"simulator ESC ratio is 1:1")
check(control("pole_number").get()==10,"simulator pole count is ten")
check(control("brake").get()==0,"simulator brake defaults Off")
local demoPropVisible=false
for _,w in ipairs(widgets) do if w.label==labelFor("prop_brake") then demoPropVisible=true end end
check(not demoPropVisible,"simulator Brake Off hides proportional brake")
local demoRequests=#sent
for _,c in ipairs({{0,800},{1,3000},{2,2300}}) do
 control("battery_type").set(c[1]);handlers.wakeup()
 check(control("undervoltage_cell").get()==c[2],"demo chemistry cutoff within known limits")
end
check(#sent==demoRequests,"demo chemistry changes emit no request")
clock = clock + 60; handlers.wakeup()
check(text("bec_voltage")=="5500 mV" and text("status_model")=="KOLIBRI140+LV",
  "simulator capture stays visible without live aging")
handlers.cleanup()
-- K-PROG/PDF field rules use a local draft and never change raw pairs or send writes.
local function changedPairs(changes)
  local ps={}
  for i,pair in ipairs(kolibri) do ps[i]={pair[1],changes[pair[1]] or pair[2]} end
  return ps
end
local function show(options)
  open();answer(fixture(options))
end
-- Four brake parameters: raw pointers, percentage projection and local rules.
show({})
control("prop_brake").set(1);handlers.wakeup()
local brakeKeys={"brake_pwm_min","brake_pwm_max","brake_slew_up","brake_slew_down"}
local brakeLabels={brake_pwm_min="Min brake PWM",brake_pwm_max="Max brake PWM",brake_slew_up="Brake ramp up",brake_slew_down="Brake ramp down"}
local function brakeField(key)
 for _,w in ipairs(widgets) do if w.label==brakeLabels[key] then return w end end
 error("Missing brake field "..key)
end
check(received.fields.brake_pwm_min==2 and received.fields.brake_pwm_max==99,"captured brake PWM raw81/4055 project to2/99 percent")
check(received.fields.brake_slew_up==500 and received.fields.brake_slew_down==105,"captured brake ramps project unscaled ms")
local brakeEditRequests=#sent
check(brakeField("brake_slew_down").get()==105,"received off-raster ramp retained")
brakeField("brake_pwm_min").set(0);brakeField("brake_pwm_max").set(100)
brakeField("brake_slew_up").set(10000);brakeField("brake_slew_down").set(100)
check(brakeField("brake_pwm_min").get()==0 and brakeField("brake_pwm_max").get()==100,"PDF PWM endpoints accepted")
for _,case in ipairs({{"brake_pwm_min",101},{"brake_pwm_max",-1},{"brake_slew_up",10100},{"brake_slew_down",150}}) do
 local f=brakeField(case[1]);local old=f.get();f.set(case[2]);check(f.get()==old,"invalid brake limit/raster rejected "..case[1])
end
brakeField("brake_pwm_min").set(40);brakeField("brake_pwm_max").set(30)
check(brakeField("brake_pwm_max").get()==100,"max below min rejected")
brakeField("brake_pwm_max").set(60);brakeField("brake_pwm_min").set(70)
check(brakeField("brake_pwm_min").get()==40,"min above max rejected")
local stalePwm=brakeField("brake_pwm_min")
control("prop_brake").set(0);handlers.wakeup()
for _,key in ipairs({"brake_pwm_min","brake_pwm_max"}) do
 local visible=false;for _,w in ipairs(widgets) do if w.label==brakeLabels[key] then visible=true end end
 check(not visible,"Proportional Off hides "..key)
end
check(focusedLabel==labelFor("prop_brake"),"proportional toggle retains viewport focus")
stalePwm.set(20)
check(brakeField("brake_slew_up").enabled and brakeField("brake_slew_down").enabled,"ramps remain available without proportional braking")
control("expert_settings").set(true)
check(lastFieldRuntime.data.brake_pwm_min==40,"Expert and stale hidden callback cannot alter PWM draft")
control("prop_brake").set(1);handlers.wakeup()
check(brakeField("brake_pwm_min").get()==40 and brakeField("brake_pwm_max").get()==60,"Proportional On restores PWM draft")
control("expert_settings").set(false)
for _,key in ipairs(brakeKeys) do check(brakeField(key).enabled,"Brake controls need no Expert opt-in: "..key) end
local staleBrake=brakeField("brake_slew_up")
control("brake").set(0);handlers.wakeup()
for _,key in ipairs(brakeKeys) do
 local visible=false;for _,w in ipairs(widgets) do if w.label==brakeLabels[key] then visible=true end end
 check(not visible,"Brake Off hides "..key)
end
staleBrake.set(200)
control("brake").set(1);handlers.wakeup()
check(brakeField("brake_slew_up").get()==10000,"hidden brake edits preserved and stale callback rejected")
control("default_parameter_set").set(4)
for _,key in ipairs(brakeKeys) do check(not brakeField(key).enabled,"Helicopter mask locks brake parameter "..key) end
control("default_parameter_set").set(0)
check(received.byPointer[0x200E]==500 and received.byPointer[0x203E]==105 and received.byPointer[0x3040]==81
 and received.byPointer[0x3042]==4055 and #sent==brakeEditRequests,"brake edits preserve raw capture and emit no transport")
handlers.cleanup()
for _,ambiguous in ipairs({false,true}) do
 local ps=changedPairs({});for _,pair in ipairs(ps) do if pair[1]==0x3040 then pair[1]=ambiguous and 0x3042 or 0x9999;break end end
 show({pairs=ps});control("prop_brake").set(1);handlers.wakeup()
 check(brakeField("brake_pwm_min").text=="--" and not brakeField("brake_pwm_min").set,"missing brake pointer unavailable")
 if ambiguous then check(brakeField("brake_pwm_max").text=="--","duplicate brake pointer unavailable") end
 handlers.cleanup()
end
-- K-PROG governor helper intentions keep raw observations and command units apart.
local function helperCapture(pwm,low,high)
 return assert(decodeTransaction(fixture({pairs=changedPairs({[0x3020]=pwm,[0x201C]=low,[0x201E]=high})})))
end
for _,mode in ipairs({0,1}) do
 local ranges=mode==1 and {{1280,1536},{1280,1536},{0,0}} or {{40,400},{1,500},{1,320}}
 for i=1,3 do for _,edge in ipairs({ranges[i][1],ranges[i][2]}) do
  local v={ranges[1][1],ranges[2][1],ranges[3][1]};v[i]=edge
  check(#assert(codec.planGovernorAdjustments(helperCapture(v[1],v[2],v[3]),mode))==0,"helper accepted range boundary mode "..mode.." input "..i)
 end end
 for i=1,3 do
  for _,outside in ipairs({ranges[i][1]-1,ranges[i][2]+1}) do
   if outside>=0 then
    local v={ranges[1][1],ranges[2][1],ranges[3][1]};v[i]=outside
    check(#assert(codec.planGovernorAdjustments(helperCapture(v[1],v[2],v[3]),mode))==1,"single helper outside boundary plans exactly one correction")
   end
  end
 end
 local plan=assert(codec.planGovernorAdjustments(helperCapture(0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF),mode))
 for i,pointer in ipairs({0x3020,0x201C,0x201E}) do
  check(plan[i].pointer==pointer and plan[i].value==(mode==1 and ({33,1365,0})[i] or ({1,327,204})[i]),"helper mismatch target and order")
  check(plan[i].unit==(i==1 and "percent" or "raw") and plan[i].observedRaw==0xFFFFFFFF,"helper command units separate from observed EEPROM")
 end
end
for _,pointer in ipairs({0x3020,0x201C,0x201E}) do
 local ps=changedPairs({});for _,p in ipairs(ps) do if p[1]==pointer then p[1]=0x9999;break end end
 check(codec.planGovernorAdjustments(assert(decodeTransaction(fixture({pairs=ps}))),1)==nil,"missing helper prevents partial plan")
 ps=changedPairs({});ps[#ps+1]={pointer,0}
 check(codec.planGovernorAdjustments(assert(decodeTransaction(fixture({pairs=ps}))),0)==nil,"ambiguous helper prevents partial plan")
end
show({})
check(lastFieldRuntime.data.governor_adjustments==nil,"capture never auto-prepares helper changes")
local governorRequests=#sent;local governorCapture=received
control("rpm_ctl").set(0);handlers.wakeup()
local plan=lastFieldRuntime.data.governor_adjustments
check(#plan==3 and plan[1].value==1 and plan[2].value==327 and plan[3].value==204,"local Governor Off prepares all three mismatches")
control("rpm_ctl").set(1);handlers.wakeup()
check(#lastFieldRuntime.data.governor_adjustments==0,"returning to captured Governor On cancels obsolete intentions")
check(governorCapture.byPointer[0x3020]==1365 and governorCapture.byPointer[0x201C]==1365 and governorCapture.byPointer[0x201E]==0
 and #sent==governorRequests,"helper intentions preserve capture and send no messages")
control("default_parameter_set").set(2);control("rpm_ctl").set(0)
check(lastFieldRuntime.data.rpm_ctl==1 and #lastFieldRuntime.data.governor_adjustments==0,"locked Governor setter cannot change helper intentions")
options.onReload();answer(fixture({}))
check(lastFieldRuntime.data.governor_adjustments==nil,"reload clears intentions without read-time adjustment")
handlers.cleanup()
local missingHelper=changedPairs({});for _,p in ipairs(missingHelper) do if p[1]==0x3020 then p[1]=0x9999;break end end
show({pairs=missingHelper});local helperMissingRequests=#sent
control("rpm_ctl").set(0);handlers.wakeup()
check(lastFieldRuntime.data.governor_adjustments==nil and lastFieldRuntime.data.governor_adjustment_error=="unavailable",
 "missing input marks preparation unavailable, never a complete partial transaction")
check(#sent==helperMissingRequests,"unavailable helper plan does not write")
handlers.cleanup()
show({pairs=changedPairs({[0x3020]=0,[0x201C]=0,[0x201E]=5})})
check(lastFieldRuntime.data.governor_adjustments==nil and received.byPointer[0x201E]==5,"reading an incompatible helper set is still read-only")
handlers.cleanup()
for _,reset in ipairs({"disconnect","arming","close"}) do
 show({});control("rpm_ctl").set(0);handlers.wakeup()
 local helperDraft=lastFieldRuntime.data;local helperRequests=#sent
 check(#helperDraft.governor_adjustments==3,"helper plan present before lifecycle reset")
 if reset=="close" then handlers.cleanup()
 else session({connected=reset~="disconnect",isArmed=reset=="arming",mspTransport="sport",handshake={apiVersion=true}}) end
 check(helperDraft.governor_adjustments==nil and #sent==helperRequests,"lifecycle discards local helper plan without writes: "..reset)
 if handlers.cleanup then handlers.cleanup() end;session()
end
-- Bluetooth wording separates common shutdown from independent re-enable bits.
show({})
local hintCount=0
for _,w in ipairs(widgets) do if w.text=="@i18n(app.modules.esc_tools.mfg.kontr.bluetooth_hint)@" then hintCount=hintCount+1 end end
check(hintCount==1,"Bluetooth has one compact common hint")
local bluetoothRequests=#sent
local button=control("bt_disable_motor_renable_button")
local stop=control("bt_disable_motor_renable_motor_stop")
local oldStop=stop.get();button.set(1-button.get())
check(stop.get()==oldStop,"Bluetooth button re-enable does not alter motor-stop setting")
local oldButton=button.get();stop.set(1-stop.get())
check(button.get()==oldButton and #sent==bluetoothRequests,"Bluetooth options independent and local only")
handlers.cleanup()
-- Brake off hides its dependent proportional-brake control, preserving edits.
show({})
control("brake").set(1);handlers.wakeup()
control("prop_brake").set(1)
local staleProp=control("prop_brake");local brakeRequests=#sent
control("brake").set(0);handlers.wakeup()
local hasProp=false;for _,w in ipairs(widgets) do if w.label==labelFor("prop_brake") then hasProp=true end end
check(not hasProp,"Brake off hides proportional brake")
check(focusedLabel==labelFor("brake"),"brake rebuild restores focus to triggering switch")
staleProp.set(0)
check(control("brake_position").get()~=nil,"independent RC brake endpoint remains visible")
control("expert_settings").set(true)
hasProp=false;for _,w in ipairs(widgets) do if w.label==labelFor("prop_brake") then hasProp=true end end
check(not hasProp,"Expert cannot reveal a Brake-off dependent field")
control("brake").set(1);handlers.wakeup()
check(control("prop_brake").get()==1 and control("prop_brake").enabled,"Brake on restores retained draft; hidden setter ignored")
check(#sent==brakeRequests,"brake visibility changes send no transport request")
handlers.cleanup()
-- RPM Control off hides governor children without dropping their draft.
show({})
control("rpm_ctl").set(1);handlers.wakeup()
control("how_adj_max_rpm").set(1);control("max_rpm").set(40000)
local staleRpm=control("max_rpm")
local beforeHideRequests=#sent
control("rpm_ctl").set(0);handlers.wakeup()
for _,key in ipairs({"how_adj_max_rpm","max_rpm","startuptime","p-gain","motor_resist"}) do
 local found=false;for _,w in ipairs(widgets) do if w.label==labelFor(key) then found=true end end
 check(not found,"RPM off hides "..key)
end
staleRpm.set(50000)
control("rpm_ctl").set(1);handlers.wakeup()
check(control("max_rpm").get()==40000 and control("max_rpm").enabled,"RPM on restores retained draft; hidden callback ignored")
check(focusedLabel==labelFor("rpm_ctl"),"governor rebuild restores switch focus")
check(#sent==beforeHideRequests,"governor visibility changes send no request")
handlers.cleanup()
-- APK updateUI hides only idcRPMcontrolSettings; MotorExperts is independent.
show({})
control("rpm_ctl").set(0);handlers.wakeup()
local dependencyRequests=#sent
for _,expert in ipairs({false,true}) do
 control("expert_settings").set(expert);handlers.wakeup()
 for _,key in ipairs({"how_adj_max_rpm","max_rpm","startuptime","p-gain","motor_resist"}) do
  local visible=false;for _,w in ipairs(widgets) do if w.label==labelFor(key) then visible=true end end
  check(not visible,"RPM off dependency stays hidden with Expert "..tostring(expert)..": "..key)
 end
 for _,key in ipairs({"PWM_min","slewrate_up","slewrate_down","extra_smooth_IU","alternate_startup","startup_curr_limit"}) do
  check(control(key).enabled==expert,"independent motor expert field follows Expert, not RPM: "..key)
 end
end
check(#sent==dependencyRequests,"RPM/Expert dependency inspection causes no transport")
handlers.cleanup()
-- APK idcMaxRPMSettings is hidden in At idle up mode, even with Expert.
show({})
control("rpm_ctl").set(1);control("how_adj_max_rpm").set(1);handlers.wakeup()
control("max_rpm").set(45000)
local staleMax=control("max_rpm");local idleRequests=#sent
control("how_adj_max_rpm").set(0);handlers.wakeup()
for _,expert in ipairs({false,true}) do
 control("expert_settings").set(expert)
 local visible=false;for _,w in ipairs(widgets) do if w.label==labelFor("max_rpm") then visible=true end end
 check(not visible,"At idle up hides Max RPM with Expert "..tostring(expert))
 check(control("startuptime").enabled and control("p-gain").enabled,"At idle up retains other governor settings")
end
staleMax.set(46000)
control("how_adj_max_rpm").set(1);handlers.wakeup()
check(control("max_rpm").get()==45000 and control("max_rpm").enabled,"stored target restores Max RPM draft; hidden setter ignored")
check(focusedLabel==labelFor("how_adj_max_rpm"),"target source rebuild restores selector focus")
check(#sent==idleRequests,"RPM source visibility emits no request")
handlers.cleanup()
-- Telemetry output bytes are local, model-qualified and independent.
local function port(label)
 for _,w in ipairs(widgets) do if w.label==label then return w end end
 error("Missing physical port "..label)
end
show({})
local portRequests=#sent
check(port("Middle").text=="Not fitted" and not port("Middle").set,"two-port KOLIBRI shows third row as Not fitted")
check(port("Front").get()==0 and text("status_model")=="KOLIBRI140+LV" and port("Side").get()==1,"0x0100 means Front Off and Side KONTRONIK")
for _,choice in ipairs(port("Side").choices) do check(choice[2]~=3,"side offers no Futaba") end
port("Front").set(2)
check(lastFieldRuntime.data.telemetry_word==0x0102 and port("Side").get()==1,"front edit preserves side byte")
port("Side").set(4)
check(lastFieldRuntime.data.telemetry_word==0x0402 and port("Front").get()==2,"side edit preserves front byte")
port("Front").set(4);check(port("Front").get()==2,"duplicate active protocol rejected")
port("Side").set(2);check(port("Side").get()==4,"duplicate active side protocol rejected")
port("Side").set(3);check(port("Side").get()==4,"side setter rejects Futaba")
port("Front").set(3);check(port("Front").get()==3,"front permits proven Futaba code")
port("Front").set(0);port("Side").set(0)
check(lastFieldRuntime.data.telemetry_word==0,"multiple Off ports allowed")
check(received.byPointer[0x2036]==256 and #sent==portRequests,"telemetry draft edits preserve capture and send nothing")
control("expert_settings").set(true);control("expert_settings").set(false)
check(port("Side").get()==0,"Expert opt-out does not reset ordinary port edits")
local stalePort=port("Front")
options.onReload();stalePort.set(6);answer(fixture({}))
check(port("Front").get()==0 and port("Side").get()==1,"reload restores captured port bytes")
handlers.cleanup()
show({pairs=changedPairs({[0x2036]=0xABCD0100})})
port("Front").set(6);port("Side").set(2)
check(lastFieldRuntime.data.telemetry_word==0xABCD0206,"port edits preserve U32 upper bits")
handlers.cleanup()
show({pairs=changedPairs({[0x2036]=0xFE00})})
check(port("Side").text=="Raw 0xFE" and not port("Side").set,"unknown side code displayed raw without editable selection")
port("Front").set(3)
check(lastFieldRuntime.data.telemetry_word==0xFE03 and received.byPointer[0x2036]==0xFE00,"unknown other byte preserved unchanged")
handlers.cleanup()
show({pairs=changedPairs({[0x2036]=0x0103})})
check(port("Front").get()==3 and port("Side").get()==1,"received front Futaba is readable")
handlers.cleanup()
for _,ambiguous in ipairs({false,true}) do
 local ps=changedPairs({})
 for _,p in ipairs(ps) do if p[1]==0x2036 then p[1]=ambiguous and 0x2038 or 0x9999;break end end
 show({pairs=ps})
 check(port("Front").text=="Not readable" and not port("Front").set and not port("Side").set,"missing telemetry pointer locks choices")
 handlers.cleanup()
end
show({version=0x0403,pairs=changedPairs({[0x2002]=0x0403})})
check(not port("Front").set and not port("Side").set,"unqualified EEPROM cannot grant port edits")
handlers.cleanup()
show({pairs=changedPairs({[0x2036]=0x0301})})
check(port("Side").text=="Futaba" and not port("Side").set,"received forbidden side code is preserved read-only")
port("Front").set(3);check(port("Front").get()==1,"duplicate active raw side code is still guarded")
handlers.cleanup()
show({});local armedPort=port("Front");local portCapture=received
session({connected=true,isArmed=true,mspTransport="sport",handshake={apiVersion=true}})
armedPort.set(6)
check(portCapture.byPointer[0x2036]==256,"arming detaches port setter without changing capture")
handlers.cleanup();session()
local dup=changedPairs({});dup[#dup+1]={0x2036,256}
show({pairs=dup});check(port("Front").text=="Not readable" and not port("Side").set,"duplicate frei0 cannot grant editing");handlers.cleanup()
show({model="UNKNOWN",pairs=changedPairs({})})
for _,label in ipairs({"Port 1","Port 2","Port 3"}) do
 check(port(label).text=="Not readable" and not port(label).set,"unknown model shows three unresolved rows without inferred connectors")
end
handlers.cleanup()
show({model="KOLIBRI 90 LV-I"})
check(port("Front").text=="Not readable" and not port("Front").set,"one-port model has unresolved front encoding")
for _,label in ipairs({"Side","Middle"}) do check(port(label).text=="Not fitted" and not port(label).set,"absent physical port shown but never selectable") end
handlers.cleanup()
show({model="KOLIBRI 140 HV-I"})
check(port("Front").text=="Not readable" and not port("Side").set,"documented HV-I physical ports do not infer EEPROM mapping");handlers.cleanup()
show({model="KOSMIK 210 HV-I",pairs=changedPairs({[0x2038]=2})})
for _,label in ipairs({"BEC side","LED side","Middle"}) do
 check(port(label).text=="Not readable" and not port(label).set,"documented three-port layout without inferred code: "..label)
end
check(received.byPointer[0x2038]==2,"frei1 never projected as Middle")
handlers.cleanup()
-- Gear proposals require confirmation, never mutate received data or transport.
local beforeGearReadDialogs=dialogCount
show({})
check(dialogCount==beforeGearReadDialogs,"snapshot read does not prompt for gear ratio")
local gear=control("gear_ratio")
local gearRequests,gearDialogs=#sent,dialogCount
check(gear.get()==950,"hardware fixture gear ratio remains 9.50")
gear.set(950);gear.set(99)
check(dialogCount==gearDialogs and gear.get()==950,"same and invalid ratio do not prompt")
gear.set(100)
check(dialogCount==gearDialogs+1 and gear.get()==950,"proposal waits for confirmation")
check(dialog.message=="Change the ESC Main Gear Ratio? Rotorflight uses the main gear ratio configured in the flight controller for rotor-speed calculation."
 and dialog.buttons[1].label=="Confirm" and dialog.buttons[2].label=="Cancel","gear confirmation copy and buttons are English")
local cancelled=dialog
cancelled.buttons[2].action();cancelled.buttons[1].action()
check(gear.get()==950,"cancel preserves ratio and invalidates stale confirm")
gear.set(100);dialog.buttons[1].action()
check(gear.get()==100 and received.byPointer[0x204A]==950,"confirm changes only local ratio")
local afterConfirmationDialogs=dialogCount
gear.set(101);gear.set(102);gear.set(101)
check(gear.get()==101 and dialogCount==afterConfirmationDialogs,"subsequent plus/minus edits do not repeat the notice")
gear.set(99)
check(gear.get()==101 and dialogCount==afterConfirmationDialogs,"acknowledgment does not bypass bounds")
control("default_parameter_set").set(6);control("expert_settings").set(true)
gear.set(103)
check(gear.get()==103 and dialogCount==afterConfirmationDialogs,"preview and Expert keep one-time acknowledgment")
check(#sent==gearRequests,"gear confirm/cancel emit no transport request")
options.onReload();local beforeReloadDialogs=dialogCount;answer(fixture({}))
gear=control("gear_ratio");gear.set(104)
check(gear.get()==950 and dialogCount==beforeReloadDialogs+1,"reload requires a fresh confirmation")
dialog.buttons[2].action()
handlers.cleanup()
for _,reset in ipairs({"reload","close","disconnect","arm"}) do
 show({});gear=control("gear_ratio");gear.set(1234)
 local stale=dialog;local requests=#sent
 if reset=="reload" then options.onReload();answer(fixture({}))
 elseif reset=="close" then handlers.cleanup();show({})
 elseif reset=="disconnect" then session({connected=false,isArmed=false,mspTransport="sport",handshake={apiVersion=true}})
 else session({connected=true,isArmed=true,mspTransport="sport",handshake={apiVersion=true}}) end
 check(dialogClosed,"reset closes pending gear dialog: "..reset)
 stale.buttons[1].action()
 if reset=="reload" or reset=="close" then
  check(control("gear_ratio").get()==950,"stale confirm cannot alter new draft: "..reset)
 else check(#sent==requests,"stale confirm queues nothing: "..reset) end
 handlers.cleanup();session()
end
-- Only explicit Car preview grants local forward/backward draft edits.
for _,bitValue in ipairs({0,1}) do
 local status=(1116789 & ~(1<<13)) | (bitValue<<13)
 local tx=fixture({pairs=changedPairs({[0x4004]=status})})
 show({pairs=changedPairs({[0x4004]=status})})
 local capture=received
 local draftValue=bitValue
 local function assertForwardState(target,expert,label)
  control("default_parameter_set").set(target);handlers.wakeup()
  control("expert_settings").set(expert)
  local requests=#sent
  local field=control("fwd_bckwd")
  check(field.enabled==(target==6) and field.get()==draftValue,label..": visibility and edit permission")
  field.set(1-draftValue)
  if target==6 then draftValue=1-draftValue end
  check(field.get()==draftValue and received.byPointer[0x4004]==status,label..": guarded setter preserves raw capture")
  local rotation=control("rotation");local old=rotation.get()
  check(rotation.enabled,label..": separate rotation control remains editable")
  rotation.set(1-old);check(rotation.get()==1-old,label..": rotation keeps own setter rules")
  check(#sent==requests and not options.onSave and not options.onTool,label..": no write or transport request")
 end
 check(control("default_parameter_set").get()==0,"open starts at --")
 for _,expert in ipairs({false,true}) do
  for _,target in ipairs({0,2,3,4,5,6,0,6,2}) do
   assertForwardState(target,expert,"target "..target.." Expert "..tostring(expert))
  end
 end
 control("default_parameter_set").set(6)
 options.onReload();answer(tx);draftValue=bitValue
 check(control("default_parameter_set").get()==0 and not control("expert_settings").get(),"reload clears Car and Expert")
 assertForwardState(0,false,"reload --")
 handlers.cleanup()
 check(capture.byPointer[0x4004]==status and capture.fields.fwd_bckwd==bitValue,"close preserves captured forward/backward")
 open();answer(tx);draftValue=bitValue
 check(control("default_parameter_set").get()==0,"reopen starts at --")
 assertForwardState(0,true,"reopen -- plus Expert")
 handlers.cleanup()
end
-- Missing/ambiguous BitStatus cannot be unlocked by Car or Expert.
for _,ps in ipairs({{{0x2010,5500}},{{0x4004,0},{0x4004,0}}}) do
 show({pairs=ps});control("default_parameter_set").set(6);control("expert_settings").set(true)
 check(text("fwd_bckwd")=="--","Car cannot grant missing/ambiguous forward/backward")
 handlers.cleanup()
end
-- Preset targets are local masks, not inferred current presets or commands.
show({})
local target=control("default_parameter_set")
check(target.get()==0,"no initial default-set target")
for i,value in ipairs({0,2,3,4,5,6}) do check(target.choices[i][2]==value,"explicit preset command value") end
local presetButton
for _,w in ipairs(widgets) do if w.press then presetButton=w end end
check(presetButton and not presetButton.enabled,"Load Preset visible and disabled")
local beforePreview=#sent
control("expert_settings").set(true)
control("brake").set(1);control("prop_brake").set(1)
control("rpm_ctl").set(1);control("how_adj_max_rpm").set(1)
control("max_rpm").set(40000);control("slewrate_up").set(500)
local captured=received
local groups={brake={"brake","prop_brake"},governor={"rpm_ctl","how_adj_max_rpm","max_rpm","startuptime","p-gain","motor_resist"},
 ramp={"slewrate_up","slewrate_down"},reverse={"fwd_bckwd"},endpoint={"brake_position"}}
local masks={[0]={},[2]={governor=true,reverse=true},[3]={reverse=true},[4]={brake=true,ramp=true,reverse=true,endpoint=true},[5]={},[6]={governor=true}}
for _,value in ipairs({2,3,4,5,6,0}) do
 target.set(value);handlers.wakeup()
 for group,fields in pairs(groups) do for _,key in ipairs(fields) do
  check(control(key).enabled==((key~="fwd_bckwd" or value==6) and not masks[value][group]),"preset mask "..value.." "..key)
 end end
 check(received==captured and control("max_rpm").get()==40000 and control("slewrate_up").get()==500,"preview preserves snapshot and draft")
 check(not control("max_discharge").enabled and not control("max_motor_current").enabled,"preview never grants alarms")
 if value==5 then
  local found=false;for _,w in ipairs(widgets) do if w.text=="@i18n(app.modules.esc_tools.mfg.kontr.f5a_note)@" then found=true end end
  check(found,"F5A missing mask notice")
 end
end
target.set(4);control("slewrate_up").set(600)
check(control("slewrate_up").get()==500,"masked stale callback rejected")
control("expert_settings").set(false);control("expert_settings").set(true)
check(target.get()==4 and not control("brake").enabled and not control("slewrate_up").enabled,"expert toggle retains mask")
target.set(99);check(target.get()==4,"unknown preview rejected")
target.set(0);control("rpm_ctl").set(0);target.set(3)
check(not control("max_rpm").enabled,"preview cannot override governor dependency")
presetButton.press()
check(#sent==beforePreview and not options.onSave and not options.onTool,"preview and disabled preset never queue transport")
local staleTarget=target
options.onReload();check(staleTarget.get()==0,"reload clears preview");staleTarget.set(6)
answer(fixture({}));check(control("default_parameter_set").get()==0,"busy stale preview ignored")
handlers.cleanup();staleTarget.set(6);check(staleTarget.get()==0,"closed preview callback ignored")
show({model="UNKNOWN"});control("default_parameter_set").set(5);control("expert_settings").set(true);control("alarm_edit").set(true)
check(not control("PWM_min").enabled and not control("max_discharge").enabled,"F5A cannot override device or expert/alarm locks")
handlers.cleanup()
show({});local armedTarget=control("default_parameter_set");armedTarget.set(6)
local armedRequests=#sent
session({connected=true,isArmed=true,mspTransport="sport",handshake={apiVersion=true}})
armedTarget.set(2);check(armedTarget.get()==0 and #sent==armedRequests,"arming clears preview and rejects stale target without requests")
handlers.cleanup();session()
show({});local disconnectedTarget=control("default_parameter_set");disconnectedTarget.set(3)
session({connected=false,isArmed=false,mspTransport="sport",handshake={apiVersion=true}})
disconnectedTarget.set(6);check(disconnectedTarget.get()==0,"disconnect clears preview and rejects stale target")
handlers.cleanup();session()
show({pairs=changedPairs({[0x2056]=30,[0x202C]=50})})
control("expert_settings").set(true)
check(text("max_discharge")=="3.0 Ah" and text("discharge_limit")=="5.0 Ah","discharge alarm and limiter use independent tenths of Ah")
check(received.byPointer[0x2056]==30 and received.fields.max_discharge==3,"alarm scaling preserves raw thirty")
control("alarm_edit").set(true);dialog.buttons[1].action()
local n=#sent
control("max_discharge").set(40)
check(text("max_discharge")=="4.0 Ah" and received.byPointer[0x2056]==30,"local Ah ticks never mutate captured raw alarm")
check(not control("max_motor_current").enabled and not control("max_bec_current").enabled,"unknown rated currents cannot be unlocked")
control("min_input_voltage").set(3600)
check(control("min_input_voltage").get()==3500,"received out-of-range pack alarm preserved, invalid new edit rejected")
control("min_input_voltage").set(12000)
check(control("min_input_voltage").get()==12000,"documented minimum pack alarm accepted")
for _,case in ipairs({{"p-gain",11,4},{"bec_voltage",8100,6000},{"slewrate_up",100,200},{"gear_ratio",99,100}}) do
  local f=control(case[1]);local old=f.get();f.set(case[2]);check(f.get()==old,"reject new out-of-range "..case[1]);f.set(case[3]);if case[1]=="gear_ratio" then dialog.buttons[1].action() end;check(f.get()==case[3],"accept PDF limit "..case[1])
end
for _,case in ipairs({{0,1200,700,1200},{1,1200,1200,3500},{2,2300,1800,2600}}) do
  control("battery_type").set(case[1]);handlers.wakeup()
  local f=control("undervoltage_cell")
  check(f.get()==case[2] and f.min==case[3] and f.max==case[4],"chemistry switches received value and widget bounds "..case[1])
  local expectedDefault=({[0]=800,[1]=3000,[2]=2300})[case[1]]
  check(f.defaultValue==expectedDefault and text("cutoff_default")==expectedDefault.." mV","factory default follows chemistry without overwriting capture")
  local old=f.get();f.set(600);check(f.get()==old,"invalid new chemistry cutoff rejected")
end
local beforeChemistryBuilds=builds
control("battery_type").set(0);handlers.wakeup();control("undervoltage_cell").set(800)
control("battery_type").set(1);handlers.wakeup();control("undervoltage_cell").set(3000)
control("battery_type").set(2);handlers.wakeup();control("undervoltage_cell").set(2300)
for chemistry,value in pairs({[0]=800,[1]=3000,[2]=2300}) do
 control("battery_type").set(chemistry);handlers.wakeup();check(control("undervoltage_cell").get()==value,"three cutoff drafts remain independent")
end
check(builds==beforeChemistryBuilds,"available chemistry transitions update bounds in place")
control("brake").set(1);control("prop_brake").set(1);control("brake").set(0)
check(not control("prop_brake").enabled and control("prop_brake").get()==1,"brake disable preserves child")
control("brake").set(1);check(control("prop_brake").enabled,"brake re-enables child")
control("rpm_ctl").set(1);control("how_adj_max_rpm").set(1);control("max_rpm").set(40000)
control("how_adj_max_rpm").set(0);check(not control("max_rpm").enabled,"stored target mode gates speed")
control("how_adj_max_rpm").set(1);control("rpm_ctl").set(0)
for _,key in ipairs({"how_adj_max_rpm","max_rpm","startuptime","p-gain","motor_resist"}) do check(not control(key).enabled,"governor off gates "..key) end
control("rpm_ctl").set(1);check(control("max_rpm").enabled and control("max_rpm").get()==40000,"governor re-enable preserves target")
check(#sent==n and not options.onSave and not options.onTool,"all draft/dependency actions emit no transport or preset action")
handlers.cleanup()
show({pairs={{0x2018,1100},{0x201A,1500},{0x2016,1000},{0x4004,1}}})
local endpointRequests=#sent
control("max_position").set(1150)
check(text("rc_check")=="@i18n(app.modules.esc_tools.mfg.kontr.rc_invalid)@","endpoint diagnostic updates on invalid local combination")
control("max_position").set(1500)
check(text("rc_check")=="@i18n(app.modules.esc_tools.mfg.kontr.rc_valid)@" and #sent==endpointRequests,"endpoint correction updates diagnostic without transport")
handlers.cleanup()
for _,case in ipairs({
  {1100,1200,1000,1,true},{1100,1199,1000,1,false},{1100,1200,1001,1,false},
  {1900,1800,2000,1,true},{1900,1801,2000,1,false},{1900,1800,1999,1,false},
  {1100,1500,1200,0,false},{1900,1500,1800,0,false},{1100,1100,1000,0,false},
  {499,1500,400,1,false},{1100,1500,1000,0,true}}) do
  show({pairs={{0x2018,case[1]},{0x201A,case[2]},{0x2016,case[3]},{0x4004,case[4]}}})
  check(text("rc_check")=="@i18n(app.modules.esc_tools.mfg.kontr."..(case[5] and "rc_valid" or "rc_invalid")..")@","joint endpoint ordering/spacing in both directions")
  check(control("off_position").enabled and control("max_position").enabled,"invalid endpoints remain correctable")
  local before=#sent;control("off_position").set(1200);check(#sent==before,"endpoint edit is local only")
  handlers.cleanup()
end
show({pairs={{0x2018,1100},{0x201A,1500},{0x4004,0}}})
check(text("rc_check")=="--","missing endpoint has no guessed diagnostic");handlers.cleanup()
for _,case in ipairs({{model="JIVE PRO 120",version=0x0401},{model="UNKNOWN"},{version=0x0400},{version=0x0403},{flags=3,version=0}}) do
 show(case);control("alarm_edit").set(true)
 check(not control("alarm_edit").enabled and not control("max_discharge").enabled,"alarm opt-in cannot bypass unknown/legacy layout")
 handlers.cleanup()
end
for _,pointer in ipairs({0x9999,0x2056}) do
 local ps=changedPairs({});for _,pair in ipairs(ps) do if pair[1]==0x204C then pair[1]=pointer;break end end
 show({pairs=ps});control("alarm_edit").set(true)
 check(text("min_input_voltage")=="--","missing alarm pointer unavailable")
 if pointer==0x2056 then check(text("max_discharge")=="--","ambiguous alarm pointer unavailable") end
 handlers.cleanup()
end
show({pairs={{0x2018,1100},{0x2018,1100},{0x201A,1500},{0x2016,1000},{0x4004,0}}})
check(text("off_position")=="--" and text("rc_check")=="--","ambiguous endpoint cannot produce a diagnostic")
handlers.cleanup()
show({version=0x0400,pairs=changedPairs({[0x2002]=0x0400})})
check(not control("alarm_edit").enabled,"actual legacy metadata and EEPROM agree but alarms remain locked")
handlers.cleanup()
local missingCutoff=changedPairs({});for _,pair in ipairs(missingCutoff) do if pair[1]==0x200A then pair[1]=0x9999 end end
show({pairs=missingCutoff});check(text("undervoltage_cell")=="--","missing selected cutoff unavailable")
control("battery_type").set(2);handlers.wakeup();check(control("undervoltage_cell").get()==2300,"other chemistry remains available")
handlers.cleanup()
local duplicateCutoff=changedPairs({});for _,pair in ipairs(duplicateCutoff) do if pair[1]==0x2008 then pair[1]=0x200A end end
show({pairs=duplicateCutoff});check(text("undervoltage_cell")=="--","ambiguous selected cutoff unavailable");handlers.cleanup()
-- Chemistry switches must never pass raw U32 values to signed native widgets.
show({pairs=changedPairs({[0x2008]=0xFFFFFFFF,[0x200C]=0xFFFFFFFE})})
control("battery_type").set(0);handlers.wakeup()
check(text("undervoltage_cell")=="4294967295 mV","large chemistry cutoff rendered faithfully as static text")
control("battery_type").set(2);handlers.wakeup()
check(text("undervoltage_cell")=="4294967294 mV","static-to-static chemistry switch refreshes cutoff")
control("battery_type").set(1);handlers.wakeup()
check(control("undervoltage_cell").get()==1200,"return from static U32 cutoff rebuilds number control")
control("expert_settings").set(true);control("battery_type").set(0);handlers.wakeup()
control("expert_settings").set(false)
check(text("undervoltage_cell")=="4294967295 mV","expert opt-out preserves oversized captured cutoff safely")
handlers.cleanup()
-- The manufacturer's default is distinct from a captured/staged cutoff.
show({})
check(control("battery_type").get()==1 and control("undervoltage_cell").get()==1200
 and control("undervoltage_cell").defaultValue==3000 and text("cutoff_default")=="3000 mV","LiPo capture and 3000mV default are kept separate")
control("expert_settings").set(true)
local cutoff=control("undervoltage_cell");local requestCount=#sent
cutoff.set(cutoff.defaultValue)
check(cutoff.get()==3000 and received.byPointer[0x200A]==1200 and #sent==requestCount,"explicit default applies only to local LiPo draft")
control("battery_type").set(0);handlers.wakeup()
check(control("undervoltage_cell").defaultValue==800,"NiMH default800")
control("battery_type").set(1);handlers.wakeup()
check(control("undervoltage_cell").get()==3000 and cutoff.defaultValue==3000,"LiPo draft/default survive chemistry roundtrip")
control("expert_settings").set(false)
check(control("undervoltage_cell").get()==1200 and control("undervoltage_cell").defaultValue==3000,"expert opt-out restores capture without changing factory default")
handlers.cleanup()
-- APK expert groups are a local editing lock, never a capability override.
local expertKeys={"undervoltage_behavior","undervoltage_cell","discharge_limit","PWM_min","slewrate_up","slewrate_down","extra_smooth_IU","alternate_startup","startup_curr_limit"}
show({})
local function verifyExpertMarkers()
 local count=0
 for _,w in ipairs(widgets) do if type(w.label)=="string" and w.label:sub(-2)==" *" then count=count+1 end end
 check(count==10,"exactly nine expert labels plus the switch are marked")
 for _,key in ipairs(expertLabelKeys) do check(control(key).label==markedLabels[key],"visible literal marker: "..key) end
 check(control("expert_settings").label=="Expert Settings *","switch wording and permanent marker")
 for _,key in ipairs({"battery_type","gear_ratio","p-gain","motor_resist","brake","off_position","max_discharge","alarm_edit","cutoff_default"}) do
  if control("rpm_ctl").get()~=0 or (key~="p-gain" and key~="motor_resist") then
   check(control(key).label:sub(-1)~="*","standard field stays unmarked: "..key)
  end
 end
end
verifyExpertMarkers()
local initialExpert={};local beforeExpertRequests=#sent
for _,key in ipairs(expertKeys) do
  local f=control(key);initialExpert[key]=f.get()
  check(not f.enabled,"default expert lock "..key)
end
local locked=control("slewrate_up");locked.set(2000)
check(locked.get()==initialExpert.slewrate_up,"locked expert setter rejected")
control("bec_voltage").set(6000);control("gear_ratio").set(1234);dialog.buttons[1].action()
control("brake").set(0);control("rpm_ctl").set(0)
control("expert_settings").set(true)
check(control("expert_settings").get(),"explicit expert opt-in")
verifyExpertMarkers()
for _,key in ipairs(expertKeys) do check(control(key).enabled,"known expert field unlocked "..key) end
check(not control("prop_brake").enabled and not control("max_rpm").enabled,"expert does not bypass brake/governor dependencies")
check(not control("max_discharge").enabled,"expert does not bypass alarm opt-in")
control("alarm_edit").set(true);dialog.buttons[1].action()
check(control("max_discharge").enabled and not control("max_bec_current").enabled,"expert retains alarm capability locks")
control("max_discharge").set(30)
control("slewrate_up").set(2000);control("discharge_limit").set(30)
control("undervoltage_behavior").set(1-initialExpert.undervoltage_behavior)
control("PWM_min").set(10);control("slewrate_down").set(2000)
control("extra_smooth_IU").set(1-initialExpert.extra_smooth_IU)
control("alternate_startup").set(1-initialExpert.alternate_startup)
control("startup_curr_limit").set(50)
for _,case in ipairs({{0,800},{1,3000},{2,2500}}) do
 control("battery_type").set(case[1]);handlers.wakeup();control("undervoltage_cell").set(case[2])
end
local expertStale=control("slewrate_up")
control("expert_settings").set(false)
for _,key in ipairs(expertKeys) do
  check(not control(key).enabled,"opt-out locks "..key)
  if key~="undervoltage_cell" then check(control(key).get()==initialExpert[key],"opt-out restores captured "..key) end
end
check(control("battery_type").get()==2 and control("undervoltage_cell").get()==2300,"opt-out preserves standard chemistry selection but restores its cutoff")
for _,case in ipairs({{0,1200},{1,1200},{2,2300}}) do
 control("battery_type").set(case[1]);handlers.wakeup();check(control("undervoltage_cell").get()==case[2],"all hidden cutoff drafts restored")
end
expertStale.set(3000);check(expertStale.get()==initialExpert.slewrate_up,"stale locked expert callback cannot restore hidden edit")
check(control("bec_voltage").get()==6000 and control("gear_ratio").get()==1234 and control("max_discharge").get()==30,"standard and alarm draft edits survive expert opt-out")
check(control("alarm_edit").get(),"expert opt-out preserves separate alarm switch")
verifyExpertMarkers()
check(control("undervoltage_cell").defaultValue==2300,"expert reset retains factory default for current chemistry")
control("expert_settings").set(true)
check(control("slewrate_up").get()==initialExpert.slewrate_up,"re-enable does not resurrect expert changes")
check(#sent==beforeExpertRequests and not options.onSave and not options.onTool,"expert toggles and edits emit no requests and enable no Save/presets")
options.onReload();answer(good)
check(not control("expert_settings").get() and not control("slewrate_up").enabled,"Reload resets expert switch")
control("expert_settings").set(true)
local staleSwitch=control("expert_settings")
session({connected=true,isArmed=true,mspTransport="sport",handshake={apiVersion=true}});handlers.wakeup()
staleSwitch.set(true);check(not staleSwitch.get(),"arming clears expert mode and rejects stale opt-in")
handlers.cleanup();session()
show({});control("expert_settings").set(true)
local staleOnClose=control("expert_settings");local staleEdit=control("slewrate_up")
handlers.cleanup();local count=#sent;staleOnClose.set(true);staleEdit.set(2000)
check(not staleOnClose.get() and #sent==count,"close resets mode and detaches callbacks")
show({});control("expert_settings").set(true)
local staleOnDisconnect=control("expert_settings")
session({connected=false});handlers.wakeup();staleOnDisconnect.set(true)
check(not staleOnDisconnect.get(),"disconnect resets mode and prevents late opt-in")
handlers.cleanup();session()
for _,case in ipairs({{model="UNKNOWN"},{version=0x0400,pairs=changedPairs({[0x2002]=0x0400})},{version=0x0403}}) do
 show(case);control("expert_settings").set(true)
 check(not control("expert_settings").enabled and not control("expert_settings").get() and not control("PWM_min").enabled,"expert cannot grant unknown device/layout permission")
 handlers.cleanup()
end
local missingExpert=changedPairs({});for _,pair in ipairs(missingExpert) do if pair[1]==0x2022 then pair[1]=0x9999 end end
show({pairs=missingExpert});control("expert_settings").set(true)
check(text("slewrate_up")=="--","expert cannot fabricate missing field");handlers.cleanup()
local ambiguousExpert=changedPairs({});for _,pair in ipairs(ambiguousExpert) do if pair[1]==0x2024 then pair[1]=0x2022 end end
show({pairs=ambiguousExpert});control("expert_settings").set(true)
check(text("slewrate_up")=="--" and text("slewrate_down")=="--","expert cannot expose ambiguous field");handlers.cleanup()
local file=assert(io.open("bin/esc_kontronik_preview/kosmik.frames","rb"));local hex=file:read("*a");file:close()
local lines={};for line in hex:gmatch("[^\r\n]+") do if line:sub(1,1)~="#" then lines[#lines+1]=line end end
local chars={};for b in table.concat(lines," "):gmatch("%x%x") do chars[#chars+1]=string.char(tonumber(b,16)) end
local e=assert(table.concat(chars):match("\xA7E([^\n]+)"));local kosmik={}
for value,pointer in e:gmatch("(%d+):(%d+);") do kosmik[#kosmik+1]={tonumber(pointer),tonumber(value)} end
check(#kosmik==39,"KOSMIK reconstructed capture contains 39 ordered pairs")
local kosmikDecoded=assert(decodeTransaction(fixture({model="KOSMIK200+HV",version=0x0401,pairs=kosmik})))
check(kosmikDecoded.fields.brake_pwm_min==0 and kosmikDecoded.fields.brake_pwm_max==100,"KOSMIK brake PWM exact0/4096 boundaries")
check(kosmikDecoded.fields.brake_slew_up==1000 and kosmikDecoded.fields.brake_slew_down==100,"KOSMIK brake ramp pointer mapping")
show({model="KOSMIK200+HV",version=0x0401,pairs=kosmik})
control("alarm_edit").set(true)
check(control("max_esc_temp").enabled and control("max_discharge").enabled,"recognized KOSMIK layout grants documented alarms")
check(not control("max_bec_current").enabled and not control("max_motor_current").enabled,"KOSMIK current limits remain unresolved")
handlers.cleanup()
print(string.format("PASS: %d KBiDir decoder/page checks",checks))
