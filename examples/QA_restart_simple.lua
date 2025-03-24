_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=RestartSimple
--%%dark=true
--%%debug=info:true,files:true

function QuickApp:onInit()
  self:debug("Started",self.id)
  self:debug("Memory:",collectgarbage("count"),"KB")
  local n = 0
  setInterval(function() 
    print("PING",n) 
    n=n+1
  end,1000)

  setTimeout(function()
    print("Restarting...")
    --plugin.restart()
    os.exit(0)
  end,5000)
end

