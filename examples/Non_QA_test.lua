--This is a test file that is not a QA (should still be able to do api calls etc)

_DEVELOP = true
if require and not QuickApp then require("hc3emu") end


fibaro.debug(__TAG, "Hello!")
setTimeout(function() print("Hello again!") end, 1000)

--ENDOFDIRECTIVES--

-- Create QA from string and run it
-- Also, set directive breakOnLoad which will make the debugger stop on the first code line in the QA (in a new window)
fibaro.hc3emu.tools.loadQAString([[
--%%name=Test42
--%%breakOnInit=true
--%%save=test.fqa
function QuickApp:onInit()
    self:debug("onInit",self.name,self.id)
    setInterval(function()
      print("PING")
    end,2000)
end
]])