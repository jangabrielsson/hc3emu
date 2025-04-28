--This QA test of local and external api calls return the same values

---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=APItest
--%%proxy=TestProxy
--%%debug=info:false,api:true,http:true
--%%dark=true
--%%state=test/apitest.db
--%%offline=true
--%%webui="install"

local function printf(...) print(string.format(...)) end
local function setLocal(flag) fibaro.setOffline(flag) end
local compare,equal
local hc3 = fibaro.hc3emu.api.hc3
local hc3id = hc3.get("/devices?name=TestProxy")[1].id
fibaro.hc3emu.helper.start()

function QuickApp:part1()
  local a,b = hc3.delete("/globalVariables/hc3emuvar")

  local a1,b1 = api.get("/globalVariables/hc3emuvar")
  local a2,b2 = hc3.get("/globalVariables/hc3emuvar")
  compare(a1,a2,b1,b2)

  a1,b1 = api.put("/globalVariables/hc3emuvar",{value='a'})
  a2,b2 = hc3.put("/globalVariables/hc3emuvar",{value='a'})
  compare(a1,a2,b1,b2)

  a1,b1 = api.post("/globalVariables",{name='hc3emuvar',value='a'})
  a2,b2 = hc3.post("/globalVariables/hc3emuvar",{name='hc3emuvar',value='a'})
  compare(a1,a2,b1,b2)


  a1,b1 = api.delete("/globalVariables/hc3emuvar",{})
  a2,b2 = hc3.delete("/globalVariables/hc3emuvar")
  compare(a1,a2,b1,b2)
  
  a1,b2 = api.get("/devices/"..self.id)
  a2,b2 = hc3.get("/devices/"..hc3id)
  compare(nil,nil,b1,b2)

  a1,b2 = api.get("/devices?interface=quickApp")
  a2,b2 = hc3.get("/devices?interface=quickApp")
  compare(type(a1),type(a2),b1,b2)

  a1,b1 = api.post("/plugins/updateProperty",{deviceId=self.id,propertyName='value',value=false})
  a2,b2 = hc3.post("/plugins/updateProperty",{deviceId=3636,propertyName='value',value=false})
  compare(a1,a2,b1,b2)

  self:setName("NewName")
  print("Name",self.name)
end

function QuickApp:part2()
  api.delete("/plugins/"..self.id.."/variables/fopp")
  local a1,b2 = hc3.sync.delete("/plugins/"..hc3id.."/variables/fopp")

  local a1,b1 = api.get("/plugins/"..self.id.."/variables/fopp")
  local a2,b2 = hc3.get("/plugins/"..hc3id.."/variables/fopp")
  compare(a1, a2, b1, b2)

  local a1,b1 = api.put("/plugins/"..self.id.."/variables/fopp",{name='fopp',value='a'})
  local a2,b2 = hc3.sync.put("/plugins/"..hc3id.."/variables/fopp",{name='fopp',value='a'})
  compare(a1, a2, b1, b2)

  local a1,b1 = api.post("/plugins/"..self.id.."/variables",{name='fopp',value='a'})
  local a2,b2 = hc3.sync.post("/plugins/"..hc3id.."/variables",{name='fopp',value='a'})
  compare(a1, a2, b1, b2)

  local a1,b1 = api.get("/plugins/"..self.id.."/variables/fopp")
  local a2,b2 = hc3.get("/plugins/"..hc3id.."/variables/fopp")
  compare(a1, a2, b1, b2)

  api.delete("/plugins/"..self.id.."/variables/fopp")
  local a1,b2 = hc3.sync.delete("/plugins/"..hc3id.."/variables/fopp")
  plugin.restart()
end

function QuickApp:part3()
  local fqa = {
    name="TestQA",
    type="com.fibaro.binarySwitch",
    --initialProperties = {},
    --initialInterfaces = {},
    apiVersion = "1.3",
    files = {
      {name="main", isMain=true, isOpen=false, type='lua', content="function QuickApp:onInit() print('Hello from',self.id) end"},
    },
  }
  local a1,b1 = api.post("/quickApp/", fqa)
  local a2,b2 = hc3.post("/quickApp/", fqa)
  compare(type(a1)=='table',type(a2)=='table',b1,b2)
  local a1,b1 = api.delete("/devices/"..a1.id)
  local a2,b2 = hc3.delete("/devices/"..a2.id)
  compare(a1,a2,b1,b2)
end

function QuickApp:setPart(part) self:internalStorageSet("Part",part) end
function QuickApp:onInit()
  print(self.name,self.id)
  local part = tonumber(self:internalStorageGet("Part"))
  if part == nil then part = 1 self:setPart(part)  end
  local fun = "part"..part
  if self[fun] then 
    print("Running part ",part)
    self:setPart(part+1)
    self[fun](self)
  else 
    self:setPart(nil)
    return print("Please restart")
  end
  print("Done part",part)
end

local ignore = {created=true,modified=true}
function equal(e1,e2)
  if e1==e2 then return true
  else
    if type(e1) ~= 'table' or type(e2) ~= 'table' then return false
    else
      for k1,v1 in pairs(e1) do
        if ignore[k1] then 
          if not e2[k1] then return false end
        elseif e2[k1] == nil or not equal(v1,e2[k1]) then return false end
      end
      for k2,_  in pairs(e2) do 
        if e1[k2] == nil then return false end
      end
      return true
    end
  end
end

function compare(a1,a2,b1,b2)
  if not equal(a1,a2) or b1~=b2 then fibaro.error(__TAG,"GlobalVariable compare failed",a1,a2,b1,b2) end
end