_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=OfflineRefresh
--%%type=com.fibaro.binarySwitch
--%%offline=true
--%%debug=refresh:true


function QuickApp:onInit()
  self:debug(self.name,self.id)

  api.post("/globalVariables",{ name = "test",value = "test"})
  fibaro.setGlobalVariable("test","abc")
  api.delete("/globalVariables/test")

  local room = api.post("/rooms",{ name = "test" })
  api.put("/rooms/"..room.id,{ name = "test2" })
  api.delete("/rooms/"..room.id)

  local section = api.post("/sections",{ name = "test"})
  api.put("/sections/"..section.id,{ name = "test2"})
  api.delete("/sections/"..section.id)

  local custom = api.post("/customEvents",{ name = "test", userDescription="fopp"})
  api.put("/customEvents/test",{ userDescription="hupp"})
  api.post("/customEvents/test")
  api.delete("/customEvents/test")
end