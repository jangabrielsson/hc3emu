--This is a QA loading another QA locally, and pinging it

---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=StartQA
--%%type=com.fibaro.multilevelSwitch
--%%dark=true
--%%debug=sdk:false,info:true,proxyAPI:true,server:true,onAction:true,onUIEvent:true
--%%debug=http:true,color:true,blockAPI:true

function QuickApp:onInit()
    self:debug("onInit",self.name,self.id)
    for i=1,100 do
      local friend = i == 100 and 5002 or 5002+i
      fibaro.hc3emu.tools.loadQA("examples/QA_test.lua",{"var=friend:"..friend})
    end
    setTimeout(function()
      fibaro.call(5002,"pass","Potato")
    end,0)
    setInterval(function()
      print("PING")
    end,2000)
end