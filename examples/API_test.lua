--This QA test of local and external api calls return the same values

---@diagnostic disable: duplicate-set-field
--_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=APItest
--%%proxy=TestProxy
--%%dark=true
--%%local=true

local function printf(...) print(string.format(...)) end
local function setLocal(flag) fibaro.hc3emu.setOffline(flag) end

local ignore = {created=true,modified=true}
local function equal(e1,e2)
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

local function test(testf,str,method,path,...)
  setLocal(true)
  local r1,c1 = api[method](path,...)
  setLocal(false)
  local r2,c2 = api[method](path,...)
  setLocal(true)
  if c1==c2 and testf(r1,r2) then 
    printf("OK %s %s",method,str) 
  else 
    printf("FAILED %s %s",method,str)
    printf("  %s %s",tostring(c1),tostring(c2))
    r1 = type(r1)=="table" and json.encodeFast(r1) or tostring(r1)
    r2 = type(r2)=="table" and json.encodeFast(r2) or tostring(r2)
    printf("  %s %s",r1,r2)
  end
end

local function testRes2(str,method,path,...)
  test(equal,str,method,path,...)
end

local function testType2(str,method,path,...)
  test(function(a,b) return type(a)==type(b) end,str,method,path,...)
end

function QuickApp:onInit()
  testRes2("GlobalVariable undef","get","/globalVariables/shjdgfhgs")
  testRes2("GlobalVariable undef","put","/globalVariables/shjdgfhgs",{value='a'})
  testRes2("GlobalVariable","post","/globalVariables",{name="hc3emuvar",value='a'})
  testRes2("GlobalVariable","put","/globalVariables/hc3emuvar",{name="hc3emuvar",value='b'})
  testRes2("GlobalVariable","delete","/globalVariables/hc3emuvar",{})
  
  testRes2("Devices get self","get","/devices/"..self.id)
  testRes2("Devices get self name","get","/devices?name="..self.name)
  testType2("Devices get all","get","/devices")
  testRes2("Plugins updateProperty","post","/plugins/updateProperty",{deviceId=self.id,propertyName='value',value=true})
  testRes2("Plugins updateProperty","post","/plugins/updateProperty",{deviceId=self.id,propertyName='value',value=false})

end

