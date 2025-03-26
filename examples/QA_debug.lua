_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=Debug
--%%type=com.fibaro.binarySwitch
--%%debug=api:true,http:true,timer:true

local function round(x) return math.floor(x+0.5) end
local function userDate(fmt,ts) return os.date(fmt,ts) end
local MT = {
  __tostring = function(ref)
    local t = userDate("%m.%d/%H:%M:%S",round(ref.time))
    return string.format("%s:%s %s %s",ref.ctx,ref.tag or ref.id,t,ref.src or ref.runner or "")
  end
}


function QuickApp:onInit()
  self:debug("onInit")
  local devices = api.get("/devices")
  setTimeout(function() 
    print("Ping")
  end,5000)

  for id,timer in pairs(fibaro.hc3emu:getTimers()) do
    setmetatable(timer,MT)
    self:debug("Timer "..id.." "..tostring(timer))
    self:debug("Runner for Timer "..id.." is "..tostring(timer.runner))
  end
end

