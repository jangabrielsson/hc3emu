---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=Test
--%%type=com.fibaro.multilevelSwitch
--%%dark=true
--%%debug=sdk:false,info:true,proxyAPI:true,server:true,onAction:true,onUIEvent:true
--%%debug=http:true,color:true,blockAPI:true

local function copy(t) local r = {} for k,v in pairs(t) do r[k] = v end return r end

function class3(name)
  local cls = setmetatable({__USERDATA=true}, {
    __call = function(t,...)
      assert(rawget(t,'__init'),"No constructor")
      local obj = {__USERDATA=true}
      setmetatable(obj,{__index=t, __tostring = t.__tostring or function() return "object "..name end})
      obj:__init(...)
      return obj
    end,
    __tostring = function() return "class "..name end,
  })
  _G[name] = cls
  return function(p) getmetatable(cls).__index = p end
end

class3 'A'
function A:__init(x) self.x = x self.y = 1 end
function A:foo() print(self.x+self.y) end
function A:__tostring() return "A:"..self.x end
A.z = 2
local a = A(42)
print(type(A))
print(type(a))
print(A)
print(a)
a:foo()
print("------------")

class3 'B'(A)
function B:__init(x)
  A.__init(self,x) 
  self.y=2 
end
class3 'C'(A)
function C:__init(x) 
  A.__init(self,x) 
  self.z = 3
end

local b = B(52)
local c = C(62)
print(json.encode(b))
print(json.encode(c))
b:foo()
c:foo()


function property(get,set) return {__PROP=true,get=get,set=set} end

local function setupProps(mt,t,k,v)
  local props = {}
  function mt.__index(t,k)
    if props[k] then return props[k].get(t)
    else return t[k] end -- rawget(t,k)
  end
  function mt.__newindex(t,k,v)
    if type(v)=='table' and v.__PROP then props[k]=v
    elseif props[k] then props[k].set(t,v)
    else rawset(t,k,v) end
  end
  mt.__newindex(t,k,v)
  return props
end

local function checkProp(t,k,v)
  if type(v)~='table' or not v.__PROP then return end
  local mt = getmetatable(t)
  if mt.__index then return end
  setupProps(mt,t,k,v)
end
local function isClass(t) return type(t)=='userdata' and t.__cls end
local skipMembers = {__cls=true,__init=true}
function class2(name)
  local cls = {}
  local objMT = {
    __newindex = function(t,k,v) if not checkProp(t,k,v) then rawset(t,k,v) end end,
    __tostring = function() return "object "..name end
  }
  local classObject = setmetatable({__cls=cls,__USERDATA=true}, {
    __index = function(t,k) 
      local v = cls[k] 
      assert(v,"No static "..k) 
      return v
    end,
    __newindex = function(t,k,v) 
      cls[k] = v 
    end,
    __call = function(t,...)
      assert(cls.__init,"No constructor")
      local obj = copy(cls)
      setmetatable(obj,objMT)
      cls.__init(obj,...)
      return obj
    end,
    __tostring = function() return "class "..name end,
    -- __ipairs = function() error("No ipairs") end, -- Ignored in 5.4
    -- __pairs = function() error("No pairs") end, -- Ignored in 5.4
  })
  _G[name] = classObject
  return function(parent)
    assert(isClass(parent),"Parent class not found")
    for k,v in pairs(parent.__cls or {}) do -- copy parents static members
      if not skipMembers[k] then cls[k]=v end 
    end
  end
end

class2 'A'
function A:__init(x) self.x = x self.w = 88 end
function A:foo() print("A") end
function A:__tostring() return "A:"..self.x end
A.z = 99
A.q = 66

class2 'B'(A)
function B:__init(x,y) 
  A.__init(self,x) 
  self.w = 99
  self.y = y 
  self.t = property(function(self) return self.x+self.y end,function(self,v) self.y = v-self.x end)
end
B.q = 77

function B:print() print(self.x+self.y,self.z) end

local a = A(42)
local b = B(42, 24)

print(b.q)
b:print()
b:foo()
print(b.t)

print("START",a.x)
if a['x'] == 42 then print("B") end

print(type(A))
print(A)
print(a)
print(type(a))
--local b = A.x
--print(A.x)
print(a.x)
for k,v in pairs(a) do print(k,v) end
