_DEVELOP = true
_DEBUGEMU = true
if require and not QuickApp then require('hc3emu'){debug=true} end
--%%offline=true
--%%webui=true
function QuickApp:onInit()
  self:debug("welcome")
end
