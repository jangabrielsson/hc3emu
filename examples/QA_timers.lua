--This is a QA loading another QA locally, and pinging it

---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=Timers
--%%type=com.fibaro.multilevelSwitch
--%%dark=true
--%%debug=sdk:false,info:true,proxyAPI:true,server:true,onAction:true,onUIEvent:true
--%%debug=http:true,color:true,blockAPI:true

function QuickApp:onInit()
    self:debug("onInit",self.name,self.id)

    setTimeout(function()
        self:debug("Timer executed")
    end, 1000)

    setInterval(function()
        self:debug("Interval executed")
    end, 2000)
end