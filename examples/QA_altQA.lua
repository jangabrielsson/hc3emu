if require and not QuickApp then require('hc3emu') end

--%%name=MyQA
--%%type=com.fibaro.binarySwitch


BinarySwitch = BinarySwitch
class 'BinarySwitch'
function BinarySwitch:__init(qa)
  self._qa = qa
  if self.onInit then self:onInit() end
  self.vars = {}
  self.value = property(
    function(self,name) return self.vars[name] end,
    function(self,name,value) self.vars[name] = value end
  )
end

function BinarySwitch:onInit()
  self.value = true
  print(self.value)

end

function QuickApp:onInit() BinarySwitch(self) end