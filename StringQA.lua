if require and not QuickApp then require("hc3emu") end
--%%name=StringQA
--%%type=com.fibaro.binarySwitch


function QuickApp:onInit()
  print(self.id)
  self:debug("onInit",self.name,self.id)
end
