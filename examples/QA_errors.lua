-- Cahecking behaviours for different types of errors


_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=APItest
--%%p roxy=TestProxy
--%%dark=true


local function foo()
  bar()
end

function QuickApp:onInit()
  --bar()

  setTimeout(foo3,0)
end

