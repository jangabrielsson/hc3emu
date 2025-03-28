_DEVELOP = true
 if require and not QuickApp then require('hc3emu') end

--%%name=Tester
--%%type=com.fibaro.binarySwitch
--%%lock=true

local loadQA = fibaro.hc3emu.tools.loadQA
local EVENT = fibaro.hc3emu.EVENT

function EVENT.quickApp_finished(ev)
  print("QA finished",ev.id)
end

local QAs = { 
  --"examples/QA_offline.lua", 
  "examples/QA_start_scene.lua",
}


function QuickApp:onInit()
  local q = loadQA(QAs[1])
end