_DEVELOP = true

if require and not QuickApp then require('hc3emu') end

--%%name=QA1
--%%type=com.fibaro.binarySwitch

-------ENDOFDIRECTIVES---------

fibaro.hc3emu.tools.loadQAString([[
--%%name=QA2
function QuickApp:onInit()
  self:debug("Started",self.id)
  setTimeout(function() print("Hello from",self.id) end,2000)
end
]])

function fibaro.hc3emu.EVENT.qa_finished(ev)
  print("QA finished",ev.id)
end

function QuickApp:onInit()
  self:debug("Started",self.id)
  setTimeout(function() print("Hello from",self.id) end,2000)
end