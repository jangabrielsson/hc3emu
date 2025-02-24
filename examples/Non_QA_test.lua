--THis is a test file that is not an QA (should still be able to do api calls etc)

--_DEVELOP = true
if require and not QuickApp then require("hc3emu") end


fibaro.debug(__TAG, "Hello!")
setTimeout(function() print("Hello again!") end, 1000)