local fmt = string.format 

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

local function urlencode(str) -- very useful
  if str then
    str = str:gsub("\n", "\r\n")
    str = str:gsub("([^%w %-%_%.%~])", function(c)
      return ("%%%02X"):format(string.byte(c))
    end)
    str = str:gsub(" ", "%%20")
  end
  return str
end
TQ.urlencode = urlencode

function table.merge(a, b)
  if type(a) == 'table' and type(b) == 'table' then
    for k,v in pairs(b) do if type(v)=='table' and type(a[k] or false)=='table' then table.merge(a[k],v) else a[k]=v end end
  end
  return a
end

function table.copy(obj)
  if type(obj) == 'table' then
    local res = {} for k,v in pairs(obj) do res[k] = table.copy(v) end
    return res
  else return obj end
end

function table.member(key,tab)
  for i,elm in ipairs(tab) do if key==elm then return i end end
end

function string.starts(str, start) return str:sub(1,#start)==start end

function string.split(inputstr, sep)
  local t={}
  for str in string.gmatch(inputstr, "([^"..(sep or "%s").."]+)") do t[#t+1] = str end
  return t
end

function __assert_type(param, typ)
  if type(param) ~= typ then
    error(fmt("Wrong parameter type, %s required. Provided param '%s' is type of %s",typ, tostring(param), type(param)), 3)
  end
end

local function readFile(args)
  local file,eval,env,silent = args.file,args.eval,args.env,args.silent~=false
  local f,err,res = io.open(file, "rb")
  if f==nil then if not silent then error(err) end end
  assert(f)
  local content = f:read("*all")
  f:close()
  if eval then
    if type(eval)=='function' then eval(file) end
    local code,err = load(content,file,"t",env or _G)
    if code == nil then error(err) end
    _,res = pcall(code)
    if _ == false then error(content) end
  end
  return res,content
end

return {
  json = json,
  urlencode = urlencode,
  __assert_type = __assert_type,
  readFile = readFile,
}