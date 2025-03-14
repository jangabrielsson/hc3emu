--This is a QA testing inclusion of emu.lib file

---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=IncludeTest
--%%type=com.fibaro.multilevelSwitch
--%%file=$hc3emu.event,events
--%%file=$hc3emu.lib,lib
--%%file=$hc3emu.sourcetrigger,trigg

fibaro.event = fibaro.FILE['hc3emu.event'].event
fibaro.post = fibaro.FILE['hc3emu.event'].post
fibaro.FILE['hc3emu.event'].refreshStates()

fibaro.event({type='global-variable',name='A'},function(ev)
   print("Event received: ", json.encode(ev.event))
end)

function QuickApp:onInit()
  --setTimeout(function()
    fibaro.setGlobalVariable("A",tostring(os.time()))
  --end,0)
end

