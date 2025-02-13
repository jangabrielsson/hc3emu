local json = require("json") -- Reasonable fast json parser, not to complicated to build...
local copy

local mt = { __toJSON = function (t) 
  local isArray = nil
  if t[1] then isArray=true 
  elseif next(t)== nil and (getmetatable(t) or {}).__isARRAY then isArray=true end
  t = copy(t) 
  t.__array = isArray
  return t 
end 
}

function copy(t)
  local r = {}
  for k, v in pairs(t) do 
    if type(v) == 'table' then
      local m = getmetatable(v) 
      if m then m.__toJSON = mt.__toJSON else setmetatable(v,mt) end
    end 
    r[k] = v
  end
  return r
end

local encode,decode = json.encode,json.decode
function json.encode(obj,_)
  local omt = getmetatable(obj)
  setmetatable(obj,mt)
  local r = encode(obj,'__toJSON')
  setmetatable(obj,omt)
  return r
end
local function handler(t) if t.__array then t.__array = nil end return t end
function json.decode(str,_,_) return decode(str,nil,handler) end
json.util = {}
function json.util.InitArray(t) 
  local mt = getmetatable(t) or {}
  mt.__isARRAY=true 
  print(t)
  setmetatable(t,mt) 
  local a = getmetatable(t)
  return t
end

return json