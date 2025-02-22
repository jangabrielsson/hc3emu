---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=SpeedTest
--%%type=com.fibaro.multilevelSwitch
--%%dark=true
--%%local=true
--%%speed=24*7 -- One week
--%%debug=sdk:false,info:true,proxyAPI:true,server:true,onAction:true,onUIEvent:true
--%%debug=http:true,color:true,blockAPI:true

function QuickApp:onInit()
  setInterval(function() -- Ping every day
    self:debug("Hello from hc3emu",fibaro.getValue(1,"sunriseHour"))
  end,24*3600*1000)
end
