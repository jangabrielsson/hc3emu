---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=Test
--%%type=com.fibaro.multilevelSwitch
--%%dark=true
--%%debug=sdk:false,info:false,proxyAPI:true,server:true,onAction:true,onUIEvent:true
--%%debug=http:true,color:true,blockAPI:true

function QuickApp:onInit()
  self:debug("onInit",self.name,self.id)
end

local gotPotato = false
function QuickApp:pass(str)
  if gotPotato then
    print(self.id,"gotPotato",str)
    return
  end
  local friend = self:getVariable("friend")
  print(self.id,"pass",str,friend)
  fibaro.call(friend,"pass",str)
  gotPotato = true
  api.delete("/devices/"..self.id)
end
