--This is a QA loading another QA locally, and pinging it

---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=Timers
--%%type=com.fibaro.multilevelSwitch
--%%dark=true
--%%exit=true
--%%time=10:45
--%%debug=timer2:true
--%%debug=sdk:false,info:false,server:true,onAction:true,onUIEvent:true
--%%debug=http2:true

function QuickApp:onInit()
    self:debug("onInit",self.name,self.id)

    setTimeout(function()
        self:debug("Timer executed")
    end, 1000)

    local ref = setInterval(function()
        self:debug("Interval executed")
    end, 2000)

    setTimeout(function()
        self:debug("Timer2 executed")
        clearTimeout(ref)
    end, 6000)

    local ref2,n = nil,0
    ref2 = setInterval(function()
        n = n + 1
        self:debug("Interval2 executed",n)
        if n == 3 then 
            clearInterval(ref2) 
        end
    end, 2000)

    self:debug("Set interval with ref:", ref)

end