_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=MyQA
--%%type=com.fibaro.binarySwitch

function QuickApp:onInit()
  self:debug("onInit",self.name,self.id)
end