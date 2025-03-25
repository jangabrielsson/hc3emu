--This is a QA loading another Scene locally, and starts it

---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=StartScene
--%%type=com.fibaro.multilevelSwitch
--%%dark=true
--%%debug=info:true,proxyAPI:true,server:true,onAction:true,onUIEvent:true
--% %debug=timer:true

local scene = fibaro.hc3emu.tools.loadScene("examples/Scene_call.lua")
scene:setVariable('QA', plugin.mainDeviceId)

function QuickApp:onInit()
  fibaro.scene("execute",{scene.id}) -- fix api.get("/scenes/<id>")
end

function QuickApp:foo(a,b) 
  print("Call from scene")
  self:debug("Sum",a+b)
end