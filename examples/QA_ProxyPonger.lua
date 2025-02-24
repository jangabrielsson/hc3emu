if require and not QuickApp then require('hc3emu') end

--%%name=Ponger
--%%type=com.fibaro.binarySwitch
--%%port=8266
--%%debug=info:true
--%%proxy=PongerProxy

function QuickApp:ping(id) -- When we receiev a ping, we reply with a pong
  self:debug("Ping received from",id)
  fibaro.call(id,"pong",self.id)
end

function QuickApp:onInit()
  self:debug(self.name,self.id)
end
