---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=Test
--%%type=com.fibaro.multilevelSwitch
--%%dark=true
--%%debug=sdk:false,info:true,proxyAPI:true,server:true,onAction:true,onUIEvent:true
--%%debug=http:true,color:true,blockAPI:true

function QuickApp:onInit()
  self:debug("onInit",self.name,self.id)

  local io = fibaro.hc3emu.lua.io
  io.stdout:write("Hello from Lua!\n")
  io.stdout:flush()
  local str 
  while str == nil do
    str = io.read()
  end
  io.stdout:write("You wrote: " .. str .. "\n")
  io.stdout:flush()
end
