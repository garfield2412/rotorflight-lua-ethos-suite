-- Actual Suite queue + framing + V4 reader: lost middle block is recovered on a later cycle.
-- Controlled software link, NOT an RF timing/reliability measurement.
local checks=0
local function check(ok,label) checks=checks+1;assert(ok,label) end
local clock=0
os.clock=function() clock=clock+0.000001;return clock end
system={getVersion=function() return {simulation=false} end}
local deps={}
package.loaded["rfsuite.lib.require"]=function(name) return assert(deps[name],name) end
deps["lib/mspcodec.lua"]=dofile("src/rfsuite/lib/mspcodec.lua")
deps["lib/debug_log.lua"]={msp=function() end,mspEnabled=function() return false end}
local codec=dofile("src/rfsuite/lib/msp_esc_parameters_kontronik.lua")
local file=assert(io.open(arg[1] or "bin/esc_kontronik_preview/kbidir_msp217_v4_vectors.json","r"))
local vectors=file:read("*a");file:close()
local scenarios,group={},nil
for kind,hex in vectors:gmatch('"kind"%s*:%s*"([%w_]+)".-"response_hex"%s*:%s*"([%x%s]+)"') do
  local p={};for b in hex:gmatch("%x%x") do p[#p+1]=tonumber(b,16) end
  if kind=="metadata" then group={};scenarios[#scenarios+1]=group end
  if kind=="metadata" or kind=="block" then group[#group+1]=p end
end
check(#scenarios==3,"shared V4 scenarios")
for _,width in ipairs({6,58}) do
 for _,framing in ipairs({2,3}) do
  for _,which in ipairs({1,3}) do
    clock=0
    local tx=scenarios[which]
    local common=dofile("src/rfsuite/tasks/msp/common.lua")
    local Queue=dofile("src/rfsuite/tasks/msp/queue.lua")
    local queue=Queue.new(common)
    if framing==3 then queue:setFirmwareApi(12,10) end
    local active,frames,head,polled=nil,{},1,false
    local attempts={}
    local cursor=1
    local function response(payload)
      local body
      if framing==2 then body={0,217,0,#payload,0} else body={217,0,#payload} end
      for i=1,#payload do body[#body+1]=payload[i] end
      local pos,seq=1,0
      repeat
        local packet={(framing<<5)|(pos==1 and 16 or 0)|seq}
        for i=2,width do packet[i]=body[pos] or 0;pos=pos+1 end
        frames[#frames+1]=packet;seq=(seq+1)&15
      until pos>#body
    end
    local send=common.mspSendRequest
    common.mspSendRequest=function(cmd,payload,isWrite)
      check(cmd==217 and not isWrite,"only MSP217 reads")
      check(#payload==0,"empty cyclic request")
      local expected=tx[cursor]
      local offset=expected[2]==0 and -1 or expected[8]+expected[9]*256
      attempts[offset]=(attempts[offset] or 0)+1
      active={payload=payload,offset=offset,expected=expected,sent=0,chunks=1}
      cursor=cursor%#tx+1
      return send(cmd,payload,isWrite)
    end
    common.setTransport({maxTxBufferSize=width==6 and 6 or 8,maxRxBufferSize=width,
      mspSend=function()
        active.sent=active.sent+1
        if active.sent==active.chunks then
          -- Lose the entire first response for the middle block at offset14.
          if not (active.offset==14 and attempts[14]==1) then
            response(active.expected)
          end
        end
        return true
      end,
      mspPoll=function()
        if polled then return nil end
        polled=true
        local p=frames[head]
        if p then head=head+1 end
        return p
      end})
    local result,err
    local reader=codec.newReader(function(m)
      check(queue:isProcessed(),"one request in flight across whole retrieval")
      check(m.simulatorResponse==nil,"real link does not allocate simulator response")
      queue:add(m)
    end,function(d) result=d end,function(e) err=e end)
    for tick=1,2000 do
      clock=clock+0.05;polled=false
      reader:wakeup();queue:wakeup()
      if result or err then break end
    end
    check(result and not err and #result.pairs==(which==1 and 41 or 64),"completed despite middle-block loss")
    check(attempts[14]==2 and attempts[-1]==2 and attempts[0]==2,"lost middle response recovered in next cycle")
    check(result.retrievalSeconds>0,"separate duration measured by reader")
    if width==6 then check(result.retrievalSeconds>2,"slow sliced link still publishes configuration after >2s") end
    if which==1 then
      check(result.byPointer[0x4004]==1116789 and result.byPointer[0x4058]==4294791047,"U32 shared vectors survive retry and framing")
    end
  end
 end
end
print(string.format("PASS: %d real-queue V4 software-link checks (no RF measurements)",checks))
