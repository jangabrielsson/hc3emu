---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=OfflineQA
--%%type=com.fibaro.multilevelSwitch
--%%proxy=MyProxy
--%%dark=true
--%%id=5001
--%%offline=true
--%%debug=info:true,http:true,onAction:true,onUIEvent:true

-- This QA is not allowed to calll the HC3 at all. Other http calls are allowed.
-- It can be used to test the QA logic without access to the HC3.

local function printf(...) print(string.format(...)) end

function QuickApp:myFun(a,b)
  printf("myFun called %s+%s=%s",a,b,a+b)
end

function QuickApp:onInit()
  print("Offline QA started",self.name,self.id)
  
  local info = api.get("/settings/info")
  printf("SW version:%s",info.currentVersion.version)
  printf("Serial nr:%s",info.serialNumber)
  printf("Sunrise: %s, Sunset: %s",fibaro.getValue(1,"sunriseHour"),fibaro.getValue(1,"sunsetHour"))

  api.post("/globalVariables",{name='TestVar',value="42"})
  self:check("getGlobalVariable",fibaro.getGlobalVariable("TestVar"),"42")
  fibaro.setGlobalVariable("TestVar",tostring(43))
  self:check("setGlobalVariable",fibaro.getGlobalVariable("TestVar"),"43")
  api.delete("/globalVariables/TestVar")
  self:check("deleteGlobalVariable",fibaro.getGlobalVariable("TestVar"),nil)

  fibaro.call(self.id,"myFun",7,8)

  local qas = api.get("/devices?interface=quickApp")
  self:checkType("Get QuickApps",qas,function(r) return type(r) and next(r) and r[1].id end)
end

function QuickApp:check(str,val1,val2)
  if val1 ~= val2 then
    self:error(str,val1,"!=",val2)
  else self:debug(str,"OK",val1,"=",val2) end
end

function QuickApp:checkType(str,val,f)
  local r = f(val)
  if not r then
    self:error(str,val)
  else self:debug(str,"OK",r) end
end