_DEVELOP = true
if require and not QuickApp then require('hc3emu') end

--%%name=ProxyTest
--%%proxy=ProxyTestProxy
--%%type=com.fibaro.binarySwitch

local hc3 =  fibaro.hc3emu.api.hc3
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

local function compare(a1,a2,b1,b2)
  if not equal(a1,a2) or b1~=b2 then fibaro.error(__TAG,"GlobalVariable compare failed",a1,a2,b1,b2) end
end


function QuickApp:onInit()
  self:updateProperty("value",true)
  local a1,b1 = api.get("/devices/"..self.id.."/properties/value")
  local a2,b2 = hc3:get("/devices/"..self.id.."/properties/value")
  compare(a1,a2,b1,b2)
  print("OK")
end