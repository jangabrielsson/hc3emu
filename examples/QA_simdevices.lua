_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=SimDevices
--%%type=com.fibaro.deviceController
--%%offline=true
--%%html=html
--%%debug=refresh:true

function QuickApp:onInit()
  self:debug("onInit",self.name,self.id)
  local dev = fibaro.hc3emu.createSimDevice('remote')
end