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

local sunCalc
do
  ---@return number
  local function sunturnTime(date, rising, latitude, longitude, zenith, local_offset)
    local rad,deg,floor = math.rad,math.deg,math.floor
    local frac = function(n) return n - floor(n) end
    local cos = function(d) return math.cos(rad(d)) end
    local acos = function(d) return deg(math.acos(d)) end
    local sin = function(d) return math.sin(rad(d)) end
    local asin = function(d) return deg(math.asin(d)) end
    local tan = function(d) return math.tan(rad(d)) end
    local atan = function(d) return deg(math.atan(d)) end
    
    local function day_of_year(date2)
      local n1 = floor(275 * date2.month / 9)
      local n2 = floor((date2.month + 9) / 12)
      local n3 = (1 + floor((date2.year - 4 * floor(date2.year / 4) + 2) / 3))
      return n1 - (n2 * n3) + date2.day - 30
    end
    
    local function fit_into_range(val, min, max)
      local range,count = max - min,nil
      if val < min then count = floor((min - val) / range) + 1; return val + count * range
      elseif val >= max then count = floor((val - max) / range) + 1; return val - count * range
      else return val end
    end
    
    -- Convert the longitude to hour value and calculate an approximate time
    local n,lng_hour,t =  day_of_year(date), longitude / 15,nil
    if rising then t = n + ((6 - lng_hour) / 24) -- Rising time is desired
    else t = n + ((18 - lng_hour) / 24) end -- Setting time is desired
    local M = (0.9856 * t) - 3.289 -- Calculate the Sun^s mean anomaly
    -- Calculate the Sun^s true longitude
    local L = fit_into_range(M + (1.916 * sin(M)) + (0.020 * sin(2 * M)) + 282.634, 0, 360)
    -- Calculate the Sun^s right ascension
    local RA = fit_into_range(atan(0.91764 * tan(L)), 0, 360)
    -- Right ascension value needs to be in the same quadrant as L
    local Lquadrant = floor(L / 90) * 90
    local RAquadrant = floor(RA / 90) * 90
    RA = RA + Lquadrant - RAquadrant; RA = RA / 15 -- Right ascension value needs to be converted into hours
    local sinDec = 0.39782 * sin(L) -- Calculate the Sun's declination
    local cosDec = cos(asin(sinDec))
    local cosH = (cos(zenith) - (sinDec * sin(latitude))) / (cosDec * cos(latitude)) -- Calculate the Sun^s local hour angle
    if rising and cosH > 1 then return -1 --"N/R" -- The sun never rises on this location on the specified date
    elseif cosH < -1 then return -1 end --"N/S" end -- The sun never sets on this location on the specified date
    
    local H -- Finish calculating H and convert into hours
    if rising then H = 360 - acos(cosH)
    else H = acos(cosH) end
    H = H / 15
    local T = H + RA - (0.06571 * t) - 6.622 -- Calculate local mean time of rising/setting
    local UT = fit_into_range(T - lng_hour, 0, 24) -- Adjust back to UTC
    local LT = UT + local_offset -- Convert UT value to local time zone of latitude/longitude
    ---@diagnostic disable-next-line: missing-fields
    return os.time({day = date.day,month = date.month,year = date.year,hour = floor(LT),min = math.modf(frac(LT) * 60)})
  end
  
  ---@diagnostic disable-next-line: param-type-mismatch
  local function getTimezone() local now = os.time() return os.difftime(now, os.time(os.date("!*t", now))) end
  
  function sunCalc(time)
    local hc3Location = api.get("/settings/location")
    local lat = hc3Location.latitude or 0
    local lon = hc3Location.longitude or 0
    local utc = getTimezone() / 3600
    local zenith,zenith_twilight = 90.83, 96.0 -- sunset/sunrise 90°50′, civil twilight 96°0′
    
    local date = os.date("*t",time or os.time())
    if date.isdst then utc = utc + 1 end
    local rise_time = os.date("*t", sunturnTime(date, true, lat, lon, zenith, utc))
    local set_time = os.date("*t", sunturnTime(date, false, lat, lon, zenith, utc))
    local rise_time_t = os.date("*t", sunturnTime(date, true, lat, lon, zenith_twilight, utc))
    local set_time_t = os.date("*t", sunturnTime(date, false, lat, lon, zenith_twilight, utc))
    local sunrise = fmt("%.2d:%.2d", rise_time.hour, rise_time.min)
    local sunset = fmt("%.2d:%.2d", set_time.hour, set_time.min)
    local sunrise_t = fmt("%.2d:%.2d", rise_time_t.hour, rise_time_t.min)
    local sunset_t = fmt("%.2d:%.2d", set_time_t.hour, set_time_t.min)
    return sunrise, sunset, sunrise_t, sunset_t
  end
end 

return {
  json = json,
  urlencode = urlencode,
  __assert_type = __assert_type,
  readFile = readFile,
  sunCalc = sunCalc
}