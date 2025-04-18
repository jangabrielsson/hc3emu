if require and not QuickApp then require('hc3emu') end

--%%name=TimePlay
--%%type=com.fibaro.binarySwitch






local ostime = os.time
local osdate = os.date

function os.time(t) if t then return ostime(t) else return ostime()+10*3600 end end

function QuickApp:onInit()
  setInterval(function()
    print("PING")
  end,1000*4)  
end


