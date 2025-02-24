--THis is a test file that is not an QA (should still be able to do api calls etc)

_DEVELOP = true
if require and not QuickApp then require("hc3emu") end


fibaro.debug(__TAG, "Hello!")
setTimeout(function() print("Hello again!") end, 1000)

-- fibaro.hc3emu.loadQAsrc([[
-- --%%name=Test42
-- function QuickApp:onInit()
--     self:debug("onInit",self.name,self.id)
--     setInterval(function()
--       print("PING")
--     end,2000)
-- end
-- ]])