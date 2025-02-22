---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--This is how to run a "clean" QA without directives
--We include QA_Wrapped.lua and set the QA file name to main...

--%%name=Test
--%%file=examples/QA_Wrapped.lua:main
--%%type=com.fibaro.multilevelSwitch
--%%dark=true
--%%debug=sdk:false,info:true,proxyAPI:true,server:true,onAction:true,onUIEvent:true
--%%debug=http:true,color:true,blockAPI:true
