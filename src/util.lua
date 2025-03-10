TQ = TQ
local fmt = string.format 
local json = TQ.require("hc3emu.json")

local function DEBUG(f,...) if not (TQ.flags or {}).silent then print("[SYS]",fmt(f,...)) end end
local function DEBUGF(flag,f,...) if TQ.DBG[flag] then DEBUG(f,...) end end
local function WARNINGF(f,...) print("[SYSWARN]",fmt(f,...)) end
local function ERRORF(f,...) print("[SYSERR]",fmt(f,...)) end
local function pcall2(f,...) local res = {pcall(f,...)} if res[1] then return table.unpack(res,2) else return nil end end
local function ll(fn) local f,e = loadfile(fn) if f then return f() else return not tostring(e):match("such file") and error(e) or nil end end

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

local function merge(a, b)
  if type(a) == 'table' and type(b) == 'table' then
    for k,v in pairs(b) do if type(v)=='table' and type(a[k] or false)=='table' then merge(a[k],v) else a[k]=v end end
  end
  return a
end

function table.merge(a,b) return merge(table.copy(a),b) end

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
    if _ == false then error(res) end
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
  
  function sunCalc(time,latitude,longitude)
    local lat = latitude or 0
    local lon = longitude or 0
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

do
  local sortKeys = {"type","device","deviceID","id","value","oldValue","val","key","arg","event","events","msg","res"}
  local sortOrder={}
  for i,s in ipairs(sortKeys) do sortOrder[s]="\n"..string.char(i+64).." "..s end
  local function keyCompare(a,b)
    local av,bv = sortOrder[a] or a, sortOrder[b] or b
    return av < bv
  end
  
  -- our own json encode, as we don't have 'pure' json structs, and sorts keys in order (i.e. "stable" output)
  local function prettyJsonFlat(e0) 
    local res,seen = {},{}
    local function pretty(e)
      local t = type(e)
      if t == 'string' then res[#res+1] = '"' res[#res+1] = e res[#res+1] = '"'
      elseif t == 'number' then res[#res+1] = e
      elseif t == 'boolean' or t == 'function' or t=='thread' or t=='userdata' then res[#res+1] = tostring(e)
      elseif t == 'table' then
        if next(e)==nil then res[#res+1]='{}'
        elseif seen[e] then res[#res+1]="..rec.."
        elseif e[1] or #e>0 then
          seen[e]=true
          res[#res+1] = "[" pretty(e[1])
          for i=2,#e do res[#res+1] = "," pretty(e[i]) end
          res[#res+1] = "]"
        else
          seen[e]=true
          if e._var_  then res[#res+1] = fmt('"%s"',e._str) return end
          local k = {} for key,_ in pairs(e) do k[#k+1] = tostring(key) end
          table.sort(k,keyCompare)
          if #k == 0 then res[#res+1] = "[]" return end
          res[#res+1] = '{'; res[#res+1] = '"' res[#res+1] = k[1]; res[#res+1] = '":' t = k[1] pretty(e[t])
          for i=2,#k do
            res[#res+1] = ',"' res[#res+1] = k[i]; res[#res+1] = '":' t = k[i] pretty(e[t])
          end
          res[#res+1] = '}'
        end
      elseif e == nil then res[#res+1]='null'
      else error("bad json expr:"..tostring(e)) end
    end
    pretty(e0)
    return table.concat(res)
  end
  json.encodeFast = prettyJsonFlat
end

do -- Used for print device table structs - sortorder for device structs
  local sortKeys = {
    'id','name','value','roomID','type','baseType','enabled','visible','isPlugin','parentId','viewXml','configXml',
    'interfaces','hasUIView','properties','view', 'actions','created','modified','sortOrder'
  }
  local sortOrder={}
  for i,s in ipairs(sortKeys) do sortOrder[s]="\n"..string.char(i+64).." "..s end
  local function keyCompare(a,b)
    local av,bv = sortOrder[a] or a, sortOrder[b] or b
    return av < bv
  end

  local function prettyJsonStruct(t0)
    local res = {}
    local function isArray(t) return type(t)=='table' and t[1] end
    local function isEmpty(t) return type(t)=='table' and next(t)==nil end
    local function printf(tab,fm,...) res[#res+1] = string.rep(' ',tab)..fmt(fm,...) end
    local function pretty(tab,t,key)
      if type(t)=='table' then
        if isEmpty(t) then printf(0,"[]") return end
        if isArray(t) then
          printf(key and tab or 0,"[\n")
          for i,k in ipairs(t) do
            local _ = pretty(tab+1,k,true)
            if i ~= #t then printf(0,',') end
            printf(tab+1,'\n')
          end
          printf(tab,"]")
          return true
        end
        local r = {}
        for k,_ in pairs(t) do r[#r+1]=k end
        table.sort(r,keyCompare)
        printf(key and tab or 0,"{\n")
        for i,k in ipairs(r) do
          printf(tab+1,'"%s":',k)
          local _ =  pretty(tab+1,t[k])
          if i ~= #r then printf(0,',') end
          printf(tab+1,'\n')
        end
        printf(tab,"}")
        return true
      elseif type(t)=='number' then
        printf(key and tab or 0,"%s",t)
      elseif type(t)=='boolean' then
        printf(key and tab or 0,"%s",t and 'true' or 'false')
      elseif type(t)=='string' then
        printf(key and tab or 0,'"%s"',t:gsub('(%")','\\"'))
      end
    end
    pretty(0,t0,true)
    return table.concat(res,"")
  end
  json.encodeFormated = prettyJsonStruct
end

local eventHandlers = {}
local EVENT = setmetatable({}, {
  __newindex = function(t,k,v)
    eventHandlers[k] = eventHandlers[k] or {}
    eventHandlers[k][#eventHandlers[k]+1] = v
  end
})

local function post(event,immidiate) ---{type=..., ...}
  local evhs = eventHandlers[event.type]
  local function poster() 
    for _,evh in ipairs(evhs or {}) do 
      local stat,err = pcall(evh,event)
      if not stat then ERRORF("Event handler error: %s",err) end
    end 
  end
  if not immidiate then TQ.addThread(nil,poster) else poster() end
end

local tasks = {}
local function errfun(msg,co,skt)
  -- Try to figure what QA started this task
  local deviceId = TQ.getCoroData(co,'deviceId') -- We use that to make the right fibaro.debug call
  if deviceId then
    local dev = TQ.getQA(deviceId)
    if dev then
      if dev.env.fibaro.error then
        dev.env.fibaro.error(tostring(dev.env.__TAG),msg)
        print(TQ.copas.gettraceback("",co,skt))
        return
      end
    end
    TQ.ERRORF("Task error: %s",msg)
  end
  local str = TQ.copas.gettraceback(msg,co,skt)
  TQ.ERRORF(msg)
end

local function addThread(env,call,...)
  TQ.mobdebug.on()
  local task = 42
  task = TQ.copas.addthread(function(...) 
    TQ.mobdebug.on() 
    TQ.copas.seterrorhandler(errfun)
    local stat,res = call(...) 
    -- if not stat then 
    --   ERRORF("Task error: %s",res) 
    --   print(TQ.copas.gettraceback("",coroutine.running(),nil))
    -- end
    tasks[task]=nil 
  end,...)
  -- Keep track of what QA started what task
  -- Will allow us to kill all tasks started by a QA when it is deleted
  TQ.setCoroData(task,'deviceId',(env and env.plugin or {}).mainDeviceId) 
  tasks[task] = true
  return task
end
local function cancelThreads(id) 
  if id == nil then 
    for t,_ in pairs(tasks) do TQ.copas.removethread(t) end 
    tasks = {}
  else
    for t,_ in pairs(tasks) do 
      if TQ.getCoroData(t,'deviceId') == id then 
        TQ.copas.removethread(t) 
        tasks[t]=nil 
      end 
    end
  end
end

TQ.DEBUG = DEBUG
TQ.DEBUGF = DEBUGF
TQ.WARNINGF = WARNINGF
TQ.ERRORF = ERRORF
TQ.pcall2 = pcall2
TQ.ll = ll
TQ.json = json
TQ.urlencode = urlencode
TQ.__assert_type = __assert_type
TQ.readFile = readFile
TQ.sunCalc = sunCalc
TQ.EVENT = EVENT
TQ.post = post
TQ.addThread = addThread
TQ.cancelThreads = cancelThreads