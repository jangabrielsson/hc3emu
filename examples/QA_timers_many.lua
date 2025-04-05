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
--%%webui=true

function QuickApp:onInit()
    self:debug("onInit",self.name,self.id)

    for i=1,100 do
        setTimeout(function()
            self:debug("setTimeout",i)
        end, (i*0.5+10)*1000)
    end

    self:debug("All timers set")
end