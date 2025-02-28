_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=RestartTest
--%%dark=true
--%%debug=info:true

if not api.get("/devices/5002") then
fibaro.hc3emu.loadQAString([[
function QuickApp:onInit()
  self:debug("B RestartTest started",self.id)
  self:debug("Memory:",collectgarbage("count"),"KB")

  setTimeout(function()
    print("B Restarting...")
    plugin.restart()
  end,4000)
  local n = 64
  setInterval(function() n=n+1 print("PING",string.char(n)) end,1000)
end
]])
end

function QuickApp:onInit()
  self:debug("A RestartTest started",self.id)
  self:debug("Memory:",collectgarbage("count"),"KB")

  setTimeout(function()
    print("A Restarting...")
    plugin.restart()
  end,5000)
  local n = 0
  setInterval(function() n=n+1 print("PING",n) end,1000)
end

