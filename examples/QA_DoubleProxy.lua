_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=A
--%%type=com.fibaro.binarySwitch
--%%proxy=ProxyA

--ENDOFDIRECTIVES--

fibaro.hc3emu.tools.loadQAString([[
--%%name=B
--%%type=com.fibaro.binarySwitch
--%%proxy=ProxyB

function QuickApp:onInit()
  print(self.name,self.id)
end

function QuickApp:testB(a,b)
  print("testB")
  print("test",a,'+',b,"=",a+b)
end
]])

function QuickApp:onInit()
  print(self.name,self.id)
  setTimeout(function() self:testA() end,1000)
end

function QuickApp:testA()
  print("testA")
  local qa = api.get("/devices?name=ProxyB")[1]
  fibaro.callhc3(qa.id,"testB",17,42) -- Go directly to proxy on HC3
end