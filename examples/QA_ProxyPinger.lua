--This is a QA pining the QA_ProxyPonger.lua 
--Run them in different workspaces with different ports
--They communicate via their proxies on the HC3

if require and not QuickApp then require('hc3emu') end

--%%name=Pinger
--%%type=com.fibaro.binarySwitch
--%%port=8265 -- IMportant that pinger and ponger have different ports
--%%proxy=PingerProxy

function QuickApp:ping(id)
  fibaro.call(id,"ping",self.id)
end

function QuickApp:pong(id)
  self:debug("Pong received from",id)
  setTimeout(function() self:ping(id) end,1000)
end

local function lookForPonger()
  local qas = api.get("/devices?name=".."PongerProxy") -- Find pongerproxy on HC3
  if qas and qas[1] then
    quickApp:ping(qas[1].id) -- When found, start to ping
  else
    print("Looking..")
    setTimeout(lookForPonger,2000)
  end
end

function QuickApp:onInit()
  quickApp=self
  self:debug(self.name,self.id)
  lookForPonger()
end
