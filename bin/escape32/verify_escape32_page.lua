-- Real page + session + codec, with a narrow Ethos form and MSP transport double.
local root = debug.getinfo(1,"S").source:sub(2):match("^(.*)/bin/escape32/") or "."
local prefix=root.."/src/rfsuite/"
local fields, pending, sub, tick, cleanup, event, back = {}, {}, nil, nil, nil, nil, false
local count=0
local function check(ok,msg)count=count+1;assert(ok,msg)end
local function field(key, getter, setter)
 local f={enabled=true,getter=getter,setter=setter}
 function f:enable(v)self.enabled=v end
 function f:value(v)self.text=v end
 fields[key]=f;return f
end
FONT_S=0;CENTERED=0;TEXT_LEFT=0
form={clear=function()fields={}end,addLine=function(s)return s end,
 getFieldSlots=function()return {{},{}}end,
 addStaticText=function(line,_,text)return field(line)end,
 addChoiceField=function(line,_,choices,g,s)local f=field(line,g,s);f.choices=choices;return f end,
 addNumberField=function(line,_,min,max,g,s)return field(line,g,s)end,
 addButton=function(_,__,o)local f=field(o.text);f.press=o.press;return f end}
local bus={publish=function(topic,m)if topic=="msp.request" then pending[#pending+1]=m end end,
 subscribe=function(_,h)sub=h;h({connected=true,isArmed=false});return h end,
 unsubscribe=function(_,h)if sub==h then sub=nil end end}
local modules={['lib/bus.lua']=bus,['app/header.lua']={build=function(_,o)back=o.onBack end},
 ['app/close_key.lua']={shouldHandleClose=function()return true end}}
package.loaded['rfsuite.lib.require']=function(path)return modules[path] or assert(loadfile(prefix..path))()end
local page=assert(loadfile(prefix..'app/pages/esc_forward_escape32.lua'))()
local function key(k)return '@i18n(app.modules.esc_tools.escape32.'..k..')@'end
local function click(k)local f=assert(fields[key(k)],k);check(f.enabled,'enabled '..k);f.press();tick()end
local function response(op,changes)
 local m=table.remove(pending,1);check(m and m.payload[2]==op,'expected op '..op)
 local b={1,op,0,3,1,0,0,0,1,0,0,16,255,17,3,1,0,0,0,0,1,14,32,0,16,39,15,0,1,0,0,0}
 for i,v in pairs(changes or {})do b[i]=v end
 m.processReply(m,b);tick()
end
local opts={setWakeupHandler=function(h)tick=h end,setCleanupHandler=function(h)cleanup=h end,
 setEventHandler=function(h)event=h end,onBack=function()back=true end}
page.open(opts);tick()
check(#pending==0,'no automatic OPEN or probe')
check(not fields[key('open')].enabled,'open disabled before CAPS')
click('probe');response(0,{[4]=0,[5]=0,[9]=0,[11]=255,[12]=17,[21]=0,[27]=1,[29]=0})
check(not fields[key('open')].enabled and fields[key('target')].choices==nil,'core-only shows static target placeholder')
click('probe');response(0,{[4]=0,[5]=0,[9]=0,[11]=255})
check(#fields[key('target')].choices==1,'only validated target offered')
click('open');response(1)
check(not fields[key('raw')].enabled,'must read before edit')
click('read');response(3,{[9]=2,[12]=24,[13]=0,[17]=0})
check(fields[key('raw')].enabled,'supported read enables edit')
fields[key('raw')].setter(1);tick();check(fields[key('apply')].enabled,'local edit enables apply')
click('apply');response(4,{[9]=3,[12]=26,[13]=0,[17]=0,[3]=8})
check(fields[key('raw')].text==0 and not fields[key('apply')].enabled,'normalized same-as-old value replaces draft')
check(fields[key('save')].enabled,'dirty permits flash save')
click('save');response(5,{[9]=4})
check(fields[key('status')].text==key('save_confirmed'),'save status does not claim persistence')
check(not fields[key('save')].enabled,'clean session cannot flash again')
sub({connected=true,isArmed=true});tick()
check(not fields[key('apply')].enabled and not fields[key('save')].enabled,'arming locks page actions')
local dispose=cleanup;dispose()
check(sub==nil and tick==nil and event==nil and cleanup==nil,'page removes subscriptions and handlers')
for _,identity in ipairs({{revision=17,patch=4,schema=0},{revision=17,patch=4,schema=1},{revision=16,patch=3,schema=1}}) do
 pending={};page.open(opts);tick()
 click('probe');response(0,{[4]=0,[5]=0,[9]=0,[11]=255})
 click('open');response(1,{[14]=identity.revision,[15]=identity.patch,[16]=identity.schema})
 check(fields[key('identity')].text==('rev'..identity.revision..'.'..identity.patch..' / schema '..identity.schema),'unknown identity displayed honestly')
 check(not fields[key('read')].enabled and not fields[key('raw')].enabled
  and not fields[key('apply')].enabled and not fields[key('save')].enabled,'unknown revision exposes no parameter actions')
 check(#pending==0,'unknown revision sends no automatic parameter request')
 cleanup()
end
print('ESCape32 page: '..count..' checks passed')
