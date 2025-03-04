-- lua-json >= 1.0.0-1
local json = require("json") -- Reasonable fast json parser, not to complicated to build...
local copy

local mt = { __toJSON = function (t) 
  local isArray = nil
  if t[1]~=nil then isArray=true 
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
  local stat,res = pcall(function()
  if obj == nil then return "null" end
  if type(obj) == 'number' then return tostring(obj) end
  if type(obj) == 'string' then return '"'..obj..'"' end
  local omt = getmetatable(obj)
  setmetatable(obj,mt)
  local r = encode(obj,'__toJSON')
  setmetatable(obj,omt)
  return r
  end)
  if not stat then error("json.encode error: "..tostring(res),2) end
  return res
end
local function handler(t) if t.__array then t.__array = nil end return t end
function json.decode(str,_,_) 
  local stat,res = pcall(decode,str,nil,handler) 
  if not stat then error("json.decode error: "..tostring(res),2) end
  return res
end
json.util = {}
function json.util.InitArray(t) 
  local mt = getmetatable(t) or {}
  mt.__isARRAY=true 
  --print(t)
  setmetatable(t,mt) 
  return t
end

return json