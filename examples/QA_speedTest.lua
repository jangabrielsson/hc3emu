--This is a QA rinning in local mode and speeding the timers...

_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=SpeedTest
--%%type=com.fibaro.multilevelSwitch
--%%dark=true
--%%state=myState.db
--%%debug=timer1:true,db:true
--%%local=true
-- %%speed=24*7 -- One week

function QuickApp:interval()
  setInterval(function() -- Ping every day
    self:debug("Hello from hc3emu",fibaro.getValue(1,"sunriseHour"))
  end,24*3600*1000)
end

function QuickApp:onInit()
  self:debug("onInit",self.name,self.id)
  setTimeout(function() 
    print("PING")
    __emu_speed(7*24,function(speed) 
      if speed then return end
      setTimeout(function() print("Ping after 3s") end,3000)
    end)
  end,2000)

  self:interval()
end

function QuickApp:onInit2()
  self:debug("onInit",self.name,self.id)
  local n,speed = 0,false
  setInterval(function()
    n = n + 1
    if n % 5 == 0 then
      speed = not speed
      __emu_speed(speed and 24*7 or 0)
    end
    self:debug("Interval executed")
  end, 2000)
end
