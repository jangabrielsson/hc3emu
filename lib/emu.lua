---@diagnostic disable: cast-local-type
--[[
hc3emu - Tiny QuickApp emulator for the Fibaro Home Center 3
Copyright (c) 2025 Jan Gabrielsson
Email: jan@gabrielsson.com
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.
--]]
local VERSION = "1.0.6"
print("HC3Emu - Tiny QuickApp emulator for the Fibaro Home Center 3, v"..VERSION)

local cfgFileName = "hc3emu_cfg.lua"   -- Config file in current directory
local homeCfgFileName = ".hc3emu.lua"  -- Config file in home directory
local mainFileName, mainSrc = MAINFILE, nil -- Main file name and source
TQ = {}
TQ.EMUVAR = "TQEMU" -- HC3 GV with connection data for HC3 proxy
TQ.emuPort = 8264   -- Port for HC3 proxy to connect to
TQ.emuIP = nil      -- IP of host running the emulator

local _type = type
local __TAG = "INIT"

local flags,DBG = {},{ info=true }
local fibaro = { hc3emu = TQ, HC3EMU_VERSION = VERSION, flags = flags, DBG = DBG }
local api,plugin,net = {},{},{}
local exports = { fibaro = fibaro, api = api, net = net, plugin = plugin, hub = fibaro } -- Collect all functions that should be exported to the QA environment
local __assert_type,urlencode,readFile
local quickApp,json

--  Default directives/flags from main lua file (--%%key=value)
flags={
  name='MyQA', type='com.fibaro.binarySwitch', debug={}, dark = false, id = 5001,
  var = {}, gv = {}, file = {}, proxy=false, creds = {}, state=false, save=false,
}

local fmt = string.format
local function DEBUG(f,...) print("[SYS]",fmt(f,...)) end
local function DEBUGF(flag,f,...) if DBG[flag] then DEBUG(f,...) end end
local function WARNINGF(f,...) print("[SYSWARN]",fmt(f,...)) end
local function ERRORF(f,...) print("[SYSERR]",fmt(f,...)) end
local function pcall2(f,...) local res = {pcall(f,...)} if res[1] then return table.unpack(res,2) else return nil end end
local function ll(fn) local f,e = loadfile(fn) if f then return f() else return not tostring(e):match("such file") and error(e) or nil end end
TQ.DBG, TQ.DEBUG, TQ.DEBUGF, TQ.WARNINGF, TQ.ERRORF = DBG, DEBUG,DEBUGF, WARNINGF, ERRORF
TQ.fibaro, TQ.api, TQ.plugin = fibaro, api, plugin

local f = io.open(mainFileName)
if f then mainSrc = f:read("*all") f:close()
else error("Could not read main file") end
if mainSrc:match("info:false") then DBG.info = false end

-- Get home project file, defaults to {}
DEBUGF('info',"Loading home config file %s",homeCfgFileName)
local HOME = os.getenv("HOME") or ""
local homeCfg =ll(HOME.."/"..homeCfgFileName) or {}

-- Get project config file, defaults to {}
DEBUGF('info',"Loading project config file ./%s",cfgFileName)
local cfgFlags = ll(cfgFileName) or {}

local socket = require("socket")
local ltn12 = require("ltn12")
local copas = require("copas")
copas.https = require("ssl.https")
require("copas.timer")
require("copas.http")
TQ.socket = socket

--local a = package.searchpath('hc3emu.ws', package.path)

local mobdebug = pcall2(require, 'mobdebug') or { on = function() end, start = function(_,_) end }
mobdebug.start('127.0.0.1', 8818)
TQ.mobdebug = mobdebug

local modules = {}
local MODULE = setmetatable({},{__newindex = function(t,k,v)
  modules[#modules+1]={name=k,fun=v}
end })

local tasks = {}
local function addthread(call,...)
  local task = 42
  task = copas.addthread(function(...) mobdebug.on() call(...) tasks[task]=nil end,...)
  tasks[task] = true
  return task
end
function TQ.cancelTasks() for t,_ in pairs(tasks) do copas.removethread(t) end end

function MODULE.lib()
  _,json =  pcall(require, "rapidjson") -- Use if available
  if not _ then
    json = require("json") -- Reasonable fast json parser, not to complicated to build...
    local mt
    local function copy(t)
      local r = {}
      for k, v in pairs(t) do if type(v) == 'table' then setmetatable(v,mt) end r[k] = v end
      return r
    end
    mt = { __toJSON = function (t) local t = copy(t) if t[1] then t.__array=true end return t end }
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
  end
  TQ.json = json 

  function urlencode(str) -- very useful
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
    if _type(obj) == 'table' then
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

  function readFile(args)
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
      err,res = pcall(code)
      if err == false then error(content) end
    end
    return res,content
  end

end

function MODULE.directives()
  DEBUGF('info',"Parsing %s directives...",mainFileName)

  cfgFlags = table.merge(homeCfg,cfgFlags) -- merge with home config

  local function eval(str)
    local stat, res = pcall(function() return load("return " .. str, nil, "t", { config = cfgFlags })() end)
    if stat then return res end
    ERRORF("directive '%s' %s",tostring(str),res)
    error()
  end

  mainSrc:gsub("%-%-%%%%(%w+)=(.-)%s*\n",function(f,v)
    if flags[f]~=nil then
      if type(flags[f])=='table' then
        local tab = flags[f]
        assert(type(tab)=='table',"Expected table")
        for _,vs in ipairs(v:split(',')) do
          table.insert(tab,1,vs)
        end
      else
        flags[f]=eval(v)
      end
    else WARNINGF("Unknown directive: %s",tostring(f)) end
  end)

  for _,d in ipairs(flags.debug) do local n,v = d:match("(.-):(.*)") assert(n and v,"Bad debug directive: "..d) DBG[n] = eval(v) end
  local var = {}
  for _,d in ipairs(flags.var) do local n,v = d:match("(.-):(.*)") assert(n and v,"Bad var directive: "..d) var[n] = eval(v) end
  flags.var = var
  for i,f in ipairs(flags.file) do local n,v = f:match("(.-):(.*)") assert(n and v,"Bad file directive: "..f) flags.file[i] = {name=v,file=n} end

  flags.debug = DBG
  flags = table.merge(cfgFlags,flags)

  fibaro.USER = (flags.creds or {}).user -- Get credentials, if available
  fibaro.PASSWORD = (flags.creds or {}).password
  fibaro.URL = (flags.creds or {}).url
end

function MODULE.log()

  local ANSICOLORMAP = {
    black="\027[30m",brown="\027[31m",green="\027[32m",orange="\027[33m",navy="\027[34m", -- Seems to work in both VSCode and Zerobrane console...
    purple="\027[35m",teal="\027[36m",grey="\027[37m", gray="\027[37m",red="\027[31;1m",
    tomato="\027[31;1m",neon="\027[32;1m",yellow="\027[33;1m",blue="\027[34;1m",magenta="\027[35;1m",
    cyan="\027[36;1m",white="\027[37;1m",darkgrey="\027[30;1m",
  }

  TQ.SYSCOLORS = { debug='green', trace='blue', warning='orange', ['error']='red', text='black' }
  if flags.dark then TQ.SYSCOLORS.text='gray' TQ.SYSCOLORS.trace='cyan' end

  TQ.COLORMAP = ANSICOLORMAP
  local colorEnd = '\027[0m'

  local function html2ansiColor(str, dfltColor) -- Allows for nested font tags and resets color to dfltColor
    local COLORMAP = TQ.COLORMAP
    local EXTRA = TQ.extraColors or {}
    dfltColor = COLORMAP[dfltColor] or EXTRA[dfltColor]
    local st, p = { dfltColor }, 1
    return dfltColor..str:gsub("(</?font.->)", function(s)
      if s == "</font>" then
        p = p - 1; return st[p]
      else
        local color = s:match("color=\"?([#%w]+)\"?") or s:match("color='([#%w]+)'")
        if color then color = color:lower() end
        color = COLORMAP[color] or EXTRA[color] or dfltColor
        p = p + 1; st[p] = color
        return color
      end
    end)..colorEnd
  end

  function TQ.debugOutput(tag, str, typ)
    for _,p in ipairs(TQ.logFilter or {}) do if str:find(p) then return end end
    str = str:gsub("(&nbsp;)", " ")  -- transform html space
    str = str:gsub("</br>", "\n")    -- transform break line
    str = str:gsub("<br>", "\n")     -- transform break line
    if DBG.color==false then
      str = str:gsub("(</?font.->)", "") -- Remove color tags
      print(fmt("%s[%s][%s]: %s", os.date("[%d.%m.%Y][%H:%M:%S]"), typ:upper(), tag, str))
    else
      local fstr = "<font color='%s'>%s[<font color='%s'>%-6s</font>][%-7s]: %s</font>"
      local txtColor = TQ.SYSCOLORS.text
      local typColor = TQ.SYSCOLORS[typ:lower()] or txtColor
      local outstr = fmt(fstr,txtColor,os.date("[%d.%m.%Y][%H:%M:%S]"),typColor,typ:upper(),tag,str)
      print(html2ansiColor(outstr,TQ.SYSCOLORS.text))
    end
  end

  local someRandomIP = "192.168.1.122" --This address you make up
  local someRandomPort = "3102" --This port you make up
  local mySocket = socket.udp() --Create a UDP socket like normal
  mySocket:setpeername(someRandomIP,someRandomPort)
  local myDevicesIpAddress,_ = mySocket:getsockname()-- returns IP and Port
  TQ.emuIP = myDevicesIpAddress == "0.0.0.0" and "127.0.0.1" or myDevicesIpAddress

end

function MODULE.net()
  local function httpRequest(method,url,headers,data,timeout,user,pwd)
    local resp, req = {}, {}
    req.url = url
    req.method = method or "GET"
    req.headers = headers or {}
    req.timeout = timeout and timeout / 1000
    req.sink = ltn12.sink.table(resp)
    req.headers["Accept"] = req.headers["Accept"] or "*/*"
    req.headers["Content-Type"] = req.headers["Content-Type"] or "application/json"
    req.user = user
    req.password = pwd
    if method == "PUT" or method == "POST" then
      data = data== nil and "[]" or json.encode(data)
      req.headers["Content-Length"] = #data
      req.source = ltn12.source.string(data)
    else
      req.headers["Content-Length"] = 0
    end
    local r,status,h
    if url:starts("https") then r,status,h = copas.https.request(req)
    else r,status,h = copas.http.request(req) end
    if tonumber(status) and status < 300 then
      return resp[1] and table.concat(resp) or nil, status, h
    else
      return nil, status, h, resp
    end
  end

  local BLOCK = false
  local function HC3Call(method,path,data,silent)
    if BLOCK then ERRORF("HC3 authentication failed again, Access blocked") return nil, 401, "Blocked" end
    assert(fibaro.URL,"Missing fibaro.URL")
    assert(fibaro.USER,"Missing fibaro.USER")
    assert(fibaro.PASSWORD,"Missing fibaro.PASSSWORD")
    local ic = {TQ.interceptAPI(method,path,data)}
    if ic[1] then return table.unpack(ic,2) end
    local t0 = socket.gettime()
    local res,stat,headers = httpRequest(method,fibaro.URL.."api"..path,{
      ["Accept"] = '*/*',
      ["X-Fibaro-Version"] = 2,
      ["Fibaro-User-PIN"] = fibaro.PIN,
    },
    data,15000,fibaro.USER,fibaro.PASSWORD)
    if stat == 401 then ERRORF("HC3 authentication failed, Access blocked") BLOCKED = true end
    local t1 = socket.gettime()
    local jf,data = pcall(json.decode,res)
    local t2 = socket.gettime()
    if not silent and DBG.http then DEBUGF('http',"API: %s %.4fs (decode %.4fs)",path,t1-t0,t2-t1) end
    return (jf and data or res),stat
  end
  TQ.HC3Call,TQ.httpRequest = HC3Call,httpRequest

  function api.get(path) return HC3Call("GET",path) end
  function api.post(path,data) return HC3Call("POST",path,data) end
  function api.put(path,data) return HC3Call("PUT",path, data) end
  function api.delete(path,data) return HC3Call("DELETE",path,data) end

end

function MODULE.proxy()
  loadfile("lib/proxy.lua","t",_G)()
end

function MODULE.timers()
  local e = exports
  local ref,timers = 0,{}

  function TQ.cancelTimers() for _,t in pairs(timers) do t:cancel() end end

  local function callback(_,args) mobdebug.on() timers[args[2]] = nil args[1]() end
  local function _setTimeout(rec,fun,ms)
    ref = ref+1
    local ref0 = not rec and ref or "n/a"
    timers[ref]= copas.timer.new({
      name = "setTimeout:"..ref,
      delay = ms / 1000.0,
      recurring = rec,
      initial_delay = rec and ms / 1000.0 or nil,
      callback = callback,
      params = {fun,ref0},
      errorhandler = function(err, coro, skt)
        local qa = TQ.getQA()
        fibaro.error(tostring(qa.env.__TAG),fmt("setTimeout:%s",tostring(err)))
        timers[ref]=nil
        copas.seterrorhandler()
      end
    })
    return ref
  end

  function e.setTimeout(fun,ms) return _setTimeout(false,fun,ms) end
  function e.setInterval(fun,ms) return _setTimeout(true,fun,ms) end
  function e.clearTimeout(ref)
    if timers[ref] then
      timers[ref]:cancel()
    end
    timers[ref]=nil
    copas.pause(0)
  end
  e.clearInterval = e.clearTimeout
end

TQ.copas,TQ.flags,TQ._type,TQ.addthread = copas,flags,_type,addthread

-- Load modules
for _,m in ipairs(modules) do DEBUGF('info',"Loading emu module %s",m.name) m.fun() end

local skip = load("return function(f) return function(...) return f(...) end end")()
local luaType = function(obj) -- We need to recognize our class objects as 'userdata' (table with __USERDATA key)
  local t = _type(obj)
  return t == 'table' and rawget(obj,'__USERDATA') and 'userdata' or t
end
type = skip(luaType)

if flags.sdk then -- Try to hide functions from debugger - may work...
  local e = exports
  for n,f in pairs(api) do local f0=f; api[n] = skip(f0) end
  e.setTimeout = skip(e.setTimeout)
  e.clearTimeout = skip(e.clearTimeout)
  e.setInterval = skip(e.setInterval)
  e.clearInterval = skip(e.clearInterval)
  json.encode = skip(json.encode)
  json.decode = skip(json.decode)
  for n,f in pairs(fibaro) do
    if _type(f) == 'function' then local f0=f fibaro[n]=skip(f0) end
  end
end

-- Load main file
local os2 = { time = os.time, clock = os.clock, difftime = os.difftime, date = os.date, exit = nil }
local env = {
  __assert_type = __assert_type, __TAG = __TAG, quickApp = quickApp, json = json,
  collectgarbage = collectgarbage, os = os2, math = math, string = string, table = table,
  getmetatable = getmetatable, setmetatable = setmetatable, tonumber = tonumber, tostring = tostring,
  type = type, pairs = pairs, ipairs = ipairs, next = next, select = select, unpack = table.unpack,
  error = error, assert = assert, pcall = pcall, xpcall = xpcall, bit32 = require("bit32"),
  dofile = dofile, package = package, _require = require, _coroutine = coroutine, io = io, rawset = rawset, rawget = rawget,
  _DEVELOP = _DEVELOP, _loadfile = loadfile
}
function env.print(...) env.fibaro.debug(env.__TAG,...) end
for name,fun in pairs(exports) do env[name]=fun end -- export functions to environment
env._G = env

for _,path in ipairs({"hc3emu.class","hc3emu.fibaro","hc3emu.quickapp","hc3emu.net"}) do
  DEBUGF('info',"Loading QA library %s",path)
  if _DEVELOP then
    path = "lib/"..path:match(".-%.(.*)")..".lua"
  else  path = package.searchpath(path,package.path) end
  loadfile(path,"t",env)()
end

local function init() -- The rest is run in a copas tasks...
  mobdebug.on()

  for _,lf in ipairs(flags.file) do
    DEBUGF('info',"Loading user file %s",lf.file)
    _,lf.src = readFile{file=lf.file,eval=true,env=env,silent=false}
  end
  DEBUGF('info',"Loading user main file %s",mainFileName)
  load(mainSrc,mainFileName,"t",env)()
  assert(fibaro.URL, fibaro.USER and fibaro.PASSWORD,"Please define URL, USER, and PASSWORD")

  if env.QuickApp.onInit then   -- Start QuickApp if defined
    local qvs = {}
    for k,v in pairs(flags.var or {}) do qvs[#qvs+1]={name=k,value=v} end

    local deviceStruct = {
      id=tonumber(flags.id) or 5000,
      type=flags.type or 'com.fibaro.binarySwitch',
      name=flags.name or 'MyQA',
      enabled = true,
      visible = true,
      properties = { quickAppVariables = qvs },
      interfaces = {"quickApp"},
      created = os.time(),
      modified = os.time()
    }

    -- Find or create proxy if specified
    if flags.proxy then
      local pname = tostring(flags.proxy)
      if pname:starts("-") then -- delete proxy if name is preceeded with "-"
        pname = pname:sub(2)
        local qa = api.get("/devices?name="..urlencode(pname))
        assert(type(qa)=='table')
        for _,d in ipairs(qa) do
          api.delete("/devices/"..d.id)
          DEBUGF('info',"Proxy device %s deleted",d.id)
        end
        flags.proxy = false
      else
        deviceStruct = TQ.getProxy(flags.proxy,deviceStruct) -- Get deviceStruct from HC3 proxy
        assert(deviceStruct, "Can't get proxy device")
        api.post("/plugins/updateProperty",{deviceId= deviceStruct.id,propertyName='quickAppVariables',value=qvs})
        TQ.startServer()
      end
    end

    plugin._dev = deviceStruct            -- Now we have an device structure
    plugin.mainDeviceId = deviceStruct.id -- Now we have an deviceId

    function TQ.getFQA() -- Move to module
      local files = {}
      for _,f in ipairs(flags.file) do
        files[#files+1] = {name=f.lib, isMain=false, isOpen=false, type='lua', content=f.src}
      end
      files[#files+1] = {name="main", isMain=true, isOpen=false, type='lua', content=mainSrc}
      local initProps = {}
      local savedProps = {
        "uiCallbacks","quickAppVariables","uiView","viewLayout","apiVersion","useEmbededView","manufacturer","useUiView",
        "model","buildNumber","supportedDeviceRoles"
      }
      for _,k in ipairs(savedProps) do initProps[k]=plugin._dev.properties[k] end
      return {
        apiVersion = "1.3",
        name = plugin._dev.name,
        type = plugin._dev.type,
        initialProperties = initProps,
        initialInterfaces = plugin._dev.interfaces,
        file = files
      }
    end
    function TQ.getQA() return {id=plugin.mainDeviceId,env=env,device=plugin._dev} end

    if flags.save then
      local fileName = flags.save
      local fqa = TQ.getFQA()
      local f = io.open(fileName,"w")
      assert(f,"Can't open file "..fileName)
      f:write(json.encode(fqa))
      f:close()
      DEBUG("Saved QuickApp to %s",fileName)
    end

    TQ.setupInterceptors(plugin.mainDeviceId) -- Setup interceptors for some API calls
    DEBUGF('info',"Starting QuickApp %s",plugin._dev.name)
    quickApp = env.QuickApp(plugin._dev) -- quickApp defined first when we return from :onInit()...
  end
end

while true do
  local startTime = os.clock()
  TQ._shouldExit = true
  copas(function() addthread(init) end)
  DEBUG("Runtime %.3f sec",os.clock()-startTime)
  if TQ._shouldExit then os.exit(0) end
end
