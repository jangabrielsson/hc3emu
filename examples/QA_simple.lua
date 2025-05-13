_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=MyQA
--%%type=com.fibaro.binarySwitch
--%%state=test/fopp.db
--%%debug=time:true

pcall(json.decode,nil)
function QuickApp:onInit()
  self:debug("onInit",self.name,self.id)
  self:internalStorageSet("key", "val")
end