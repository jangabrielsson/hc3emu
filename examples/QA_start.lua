--This is a QA loading another QA locally, and pinging it

---@diagnostic disable: duplicate-set-field
--_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=StartQA
--%%type=com.fibaro.multilevelSwitch
--%%dark=true
--%%debug=sdk:false,info:true,proxyAPI:true,server:true,onAction:true,onUIEvent:true
--%%debug=http:true,color:true,blockAPI:true

function QuickApp:onInit()
    self:debug("onInit",self.name,self.id)
    fibaro.hc3emu.loadQA("examples/QA_test.lua")
    setInterval(function()
      print("PING")
    end,2000)
end