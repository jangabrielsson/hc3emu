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
---@diagnostic disable: cast-local-type
---@diagnostic disable-next-line: undefined-global
_DEVELOP = _DEVELOP

local VERSION = "1.0.15"

local cfgFileName = "hc3emu_cfg.lua"   -- Config file in current directory
local homeCfgFileName = ".hc3emu.lua"  -- Config file in home directory
local mainFileName, mainSrc = MAINFILE, nil -- Main file name and source

-- TQ defined in src/hc3emu.lua
TQ.DIR={} -- Directory for all QAs - devicesId -> QAinfo 
TQ.EMUVAR = "TQEMU" -- HC3 GV with connection data for HC3 proxy
TQ.emuPort = 8264   -- Port for HC3 proxy to connect to
TQ.emuIP = nil      -- IP of host running the emulator
TQ.api = {}         -- API functions
TQ.DBG = { info=true } -- Default flags and debug settings
TQ.require("hc3emu.util")(TQ) -- Utility functions

local DEVICEID = 5000 -- Start id for QA devices
local qaInfo = { env = {} }

local flags,runQA = {},nil

local __assert_type,urlencode,readFile,json = TQ.__assert_type,TQ.urlencode,TQ.readFile,TQ.json
local DEBUG,DEBUGF, WARNINGF, ERRORF = TQ.DEBUG, TQ.DEBUGF, TQ.WARNINGF, TQ.ERRORF
local addThread = TQ.addThread
local DBG = TQ.DBG
local api = TQ.api
local exports = {} -- functions to export to QA

local fmt = string.format

local f = io.open(mainFileName)
if f then mainSrc = f:read("*all") f:close()
else error("Could not read main file") end
if mainSrc:match("info:false") then DBG.info = false end -- Peek 
if mainSrc:match("dark=true") then DBG.dark = true end
if mainSrc:match("nodebug=true") then DBG.nodebug = true end
if mainSrc:match("shellscript=true") then DBG.nodebug = true DBG.shellscript=true end
if mainSrc:match("silent=true") then DBG.silent = true end
mainSrc = mainSrc:gsub("#!/usr/bin/env", "--#!/usr/bin/env") -- Fix shebang

if not DBG.silent then DEBUGF('info',"Main QA file %s",mainFileName) end

qaInfo.src = mainSrc
qaInfo.fname = mainFileName

-- Get home project file, defaults to {}
DEBUGF('info',"Loading home config file %s",homeCfgFileName)
local HOME = os.getenv("HOME") or ""
local homeCfg =TQ.ll(HOME.."/"..homeCfgFileName) or {}

-- Get project config file, defaults to {}
DEBUGF('info',"Loading project config file ./%s",cfgFileName)
local cfgFlags = TQ.ll(cfgFileName) or {}

local baseFlags = table.merge(homeCfg,cfgFlags) -- merge with home config

local socket = require("socket")
local ltn12 = require("ltn12")
local copas = require("copas")
copas.https = require("ssl.https")
require("copas.timer")
require("copas.http")
TQ.socket,TQ.copas = socket,copas

local mobdebug = { on = function() end, start = function(_,_) end }
if not DBG.nodebug then
  mobdebug = require("mobdebug") or mobdebug
  mobdebug.start('127.0.0.1', 8818)
end
TQ.mobdebug = mobdebug

-- Try to guess in what environment we are running (used for loading extra console colors)
TQ.isVscode = package.path:lower():match("vscode") ~= nil
TQ.isZerobrane = package.path:lower():match("zerobrane") ~= nil

local modules = {}
local MODULE = setmetatable({},{__newindex = function(t,k,v)
  modules[#modules+1]={name=k,fun=v}
end })

local function parseDirectives(info) -- adds {directives=flags,files=files} to info
  DEBUGF('info',"Parsing %s directives...",info.fname)
  
  local flags = {
    name='MyQA', type='com.fibaro.binarySwitch', debug={}, 
    var = {}, gv = {}, files = {}, creds = {}, u={}, conceal = {}, 
  }
  
  local function eval(str,d)
    local stat, res = pcall(function() return load("return " .. str, nil, "t", { config = baseFlags })() end)
    if stat then return res end
    ERRORF("directive '%s' %s",tostring(d),res)
    error()
  end
  
  local directive = {}
  function directive.name(d,val) flags.name = val end
  function directive.type(d,val) flags.type = val end
  function directive.id(d,val) flags.id = eval(val,d) assert(flags.id,"Bad id directive:"..d) end
  function directive.var(d,val) 
    ---local vs = val:split(",")
    --for _,v in ipairs(vs) do
    local v = val
    local name,expr = v:match("(.-):(.*)")
    assert(name and expr,"Bad var directive: "..d) 
    local e = eval(expr,d)
    if e then flags.var[#flags.var+1] = {name=name,value=e} end
    --end
  end
  function directive.conceal(d,val) 
    ---local vs = val:split(",")
    --for _,v in ipairs(vs) do
    local v = val
    local name,expr = v:match("(.-):(.*)")
    assert(name and expr,"Bad conceal directive: "..d) 
    --local e = eval(expr,d)
    if expr then flags.conceal[name] = expr end
    --end
  end
  function directive.file(d,val) 
    local path,m = val:match("(.-):(.*)")
    assert(path and m,"Bad file directive: "..d)
    flags.files[#flags.files+1] = {fname=path,name=m}
  end
  function directive.debug(d,val) 
    local vs = val:split(",")
    for _,v in ipairs(vs) do
      local name,expr = v:match("(.-):(.*)")
      assert(name and expr,"Bad debug directive: "..d) 
      local e = eval(expr,d)
      if e then flags[name] = e end
    end
  end
  function directive.u(d,val) flags.u[#flags.u+1] = eval(val,d) end
  function directive.save(d,val) flags.save = tostring(val) assert(flags.save:match("%.fqa$"),"Bad save directive:"..d)end
  function directive.proxy(d,val) flags.proxy = tostring(val) end
  function directive.dark(d,val) flags.dark = eval(val,d) end
  function directive.color(d,val) flags.logColor = eval(val,d) end
  function directive.speed(d,val) flags.speed = eval(val,d) assert(tonumber(flags.speed),"Bad speed directive:"..d)end
  function directive.logUI(d,val) flags.logUI = eval(val,d) end
  function directive.offline(d,val) flags.offline = eval(val,d) end
  directive['local'] = function(d,val) flags.offline = eval(val,d) end
  function directive.state(d,val) flags.state = tostring(val) end
  function directive.nodebug(d,val) flags.nodebug = eval(val,d) end
  function directive.silent(d,val) flags.silent = eval(val,d) end
  function directive.shellscript(d,val) 
    flags.shellscript = tostring(val)
    flags.nodebug = flags.shellscript
  end
  function directive.stateReadOnly(d,val) flags.stateReadOnly = eval(val,d) end
  function directive.latitude(d,val) flags.latitude = tonumber(val) end
  function directive.longitude(d,val) flags.longitude = tonumber(val) end
  function directive.time(d,val)
    local D,h = val:match("^(.*) ([%d:]*)$")
    if D == nil and val:match("^[%d/]+$") then D,h = val,os.date("%H:%M:%S")
    elseif D == nil and val:match("^[%d:]+$") then D,h = os.date("%Y/%m/%d"),val
    elseif D == nil then error("Bad time directive: "..d) end
    local y,m,d = D:match("(%d+)/(%d+)/?(%d*)")
    if d == "" then y,m,d = os.date("%Y"),y,m end
    local H,M,S = h:match("(%d+):(%d+):?(%d*)")
    if S == "" then H,M,S = H,M,0 end
    assert(y and m and d and H and M and S,"Bad time directive: "..d)
    flags.time = os.time({year=y,month=m,day=d,hour=H,min=M,sec=S})
    DEBUGF('info',"Time set to %s",os.date("%c",flags.time))
  end
  
  mainSrc:gsub("%-%-%%%%(%w-=.-)%s*\n",function(p)
    local f,v = p:match("(%w-)=(.*)")
    local v1,com = v:match("(.*)%s* %-%- (.*)$")
    if v1 then v = v1 end
    if directive[f] then
      directive[f](p,v)
    else WARNINGF("Unknown directive: %s",tostring(f)) end
  end)
  
  info.directives = table.merge(table.copy(baseFlags),flags)
  info.files = flags.files
end

function MODULE.log() TQ.require("hc3emu.log") end

function MODULE.net()
  local someRandomIP = "192.168.1.122" --This address you make up
  local someRandomPort = "3102" --This port you make up
  local mySocket = socket.udp() --Create a UDP socket like normal
  mySocket:setpeername(someRandomIP,someRandomPort)
  local myDevicesIpAddress,_ = mySocket:getsockname()-- returns IP and Port
  TQ.emuIP = myDevicesIpAddress == "0.0.0.0" and "127.0.0.1" or myDevicesIpAddress

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
      data = data== nil and "[]" or data
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
    if type(data) == 'table' then data = json.encode(data) end
    assert(TQ.URL,"Missing hc3emu.URL")
    assert(TQ.USER,"Missing hc3emu.USER")
    assert(TQ.PASSWORD,"Missing hc3emu.PASSSWORD")
    local t0 = socket.gettime()
    local res,stat,headers = httpRequest(method,TQ.URL.."api"..path,{
      ["Accept"] = '*/*',
      ["X-Fibaro-Version"] = 2,
      ["Fibaro-User-PIN"] = TQ.PIN,
    },
    data,15000,TQ.USER,TQ.PASSWORD)
    if stat == 401 then ERRORF("HC3 authentication failed, Access blocked") BLOCKED = true end
    local t1 = socket.gettime()
    local jf,data = pcall(json.decode,res)
    local t2 = socket.gettime()
    if not silent and DBG.http then DEBUGF('http',"API: %s %.4fs (decode %.4fs)",path,t1-t0,t2-t1) end
    return (jf and data or res),stat
  end
  TQ.HC3Call,TQ.httpRequest = HC3Call,httpRequest
  
  function api.get(path) return TQ.route:call("GET",path) end
  function api.post(path,data) return TQ.route:call("POST",path,data) end
  function api.put(path,data) return TQ.route:call("PUT",path, data) end
  function api.delete(path,data) return TQ.route:call("DELETE",path,data) end
end

function MODULE.db() TQ.require("hc3emu.db") end    -- Database for storing data
function MODULE.qapi() TQ.require("hc3emu.qapi") end    -- Standard API routes
function MODULE.proxy() TQ.require("hc3emu.proxy") end     -- Proxy creation and Proxy API routes
function MODULE.offline() TQ.require("hc3emu.offline") end -- Offline API routes
function MODULE.ui() TQ.require("hc3emu.ui") end

function MODULE.qa_manager()
  function TQ.getFQA(id) -- Move to module
    local qa = TQ.getQA(id)
    local dev = qa.device
    local files = {}
    local suffix = ""
    for _,f in ipairs(qa.files) do
      if f.name == "main" then suffix = "99" end -- User has main file already... rename ours to main99
      files[#files+1] = {name=f.name, isMain=false, isOpen=false, type='lua', content=f.src}
    end
    files[#files+1] = {name="main"..suffix, isMain=true, isOpen=false, type='lua', content=mainSrc}
    local initProps = {}
    local savedProps = {
      "uiCallbacks","quickAppVariables","uiView","viewLayout","apiVersion","useEmbededView","manufacturer","useUiView",
      "model","buildNumber","supportedDeviceRoles"
    }
    for _,k in ipairs(savedProps) do initProps[k]=dev.properties[k] end
    return {
      apiVersion = "1.3",
      name = dev.name,
      type = dev.type,
      initialProperties = initProps,
      initialInterfaces = dev.interfaces,
      file = files
    }
  end

  function TQ.registerQA(info) -- {id=id,directives=directives,fname=fname,src=src,env=env,device=dev,qa=qa,files=files,proxy=<bool>,child=<bool>}
    local id = info.id
    assert(id,"Can't register QA without id")
    TQ.DIR[id] = info 
    TQ.store.DB.devices[id] = info.device
  end
  function TQ.getQA(id) return TQ.DIR[id] end
  
  function TQ.setOffline(offline)
    flags.offline = offline
    if offline then
      TQ.route = TQ.offlineRoute
    else
      TQ.route = TQ.remoteRoute
    end
  end

  function TQ.loadQA(path)
    local f = io.open(path)
    if f then
      local src = f:read("*all")
      f:close()
      local info = { directives = nil, src = src, fname = path, env = { require=true }, files = {} }
---@diagnostic disable-next-line: need-check-nil
      runQA(info)
    else
      ERRORF("Could not read file %s",path)
    end
  end
end

parseDirectives(qaInfo)
flags = qaInfo.directives
DBG = flags.debug
TQ.DBG = DBG

TQ.USER = (flags.creds or {}).user or TQ.USER -- Get credentials, if available
TQ.PASSWORD = (flags.creds or {}).password or TQ.PASSWORD
TQ.URL = (flags.creds or {}).url or TQ.URL
TQ.PIN = (flags.creds or {}).pin or TQ.PIN

TQ.flags,TQ._type = flags,type

-- Load modules
for _,m in ipairs(modules) do DEBUGF('info',"Loading emu module %s",m.name) m.fun() end

local skip = load("return function(f) return function(...) return f(...) end end")()
local _type = type
local luaType = function(obj) -- We need to recognize our class objects as 'userdata' (table with __USERDATA key)
  local t = _type(obj)
  return t == 'table' and rawget(obj,'__USERDATA') and 'userdata' or t
end
luaType = skip(luaType)

local orgTime,orgDate,timeOffset = os.time,os.date,0
function TQ.setTimeOffset(offset,update) timeOffset = offset if update then TQ.post({type='time_changed'}) end end
function TQ.getTimeOffset() return timeOffset end
function TQ.milliClock() return socket.gettime() end
local function userTime(a) return a == nil and math.floor(TQ.milliClock() + timeOffset + 0.5) or orgTime(a) end
local function userDate(a, b) return b == nil and os.date(a, userTime()) or orgDate(a, b) end
function TQ.userTime(a) return userTime(a) end
function TQ.userDate(a,b) return userDate(a,b) end

TQ.offlineRoute = TQ.setupOfflineRoutes() -- Setup routes for offline API calls
TQ.remoteRoute = TQ.setupRemoteRoutes() -- Setup routes for remote API calls (incl proxy)

-- Load main file

local function loadQAFiles(info)
  
  if info.directives == nil then parseDirectives(info) end
  TQ.setOffline(info.directives.offline) 
  if info.directives.time then local t = info.directives.time  TQ.setTimeOffset(t - os.time()) end

  local env = info.env
  local os2 = { time = userTime, clock = os.clock, difftime = os.difftime, date = userDate, exit = nil }
  local fibaro = { hc3emu = TQ, HC3EMU_VERSION = VERSION, flags = info.directives, DBG = DBG }
  local args = nil
  if flags.shellscript then
    args = {}
    for i,v in pairs(arg) do if i > 0 then args[#args+1] = v end end
  end
  for k,v in pairs({
    __assert_type = __assert_type, fibaro = fibaro, api = api, json = json, urlencode = urlencode, args=args,
    collectgarbage = collectgarbage, os = os2, math = math, string = string, table = table, _print = print,
    getmetatable = getmetatable, setmetatable = setmetatable, tonumber = tonumber, tostring = tostring,
    type = luaType, pairs = pairs, ipairs = ipairs, next = next, select = select, unpack = table.unpack,
    error = error, assert = assert, pcall = pcall, xpcall = xpcall, bit32 = require("bit32"),
    dofile = dofile, package = package, _coroutine = coroutine, io = io, rawset = rawset, rawget = rawget,
    _loadfile = loadfile
  }) do env[k] = v end
  
  env.__TAG = info.directives.name..info.id
  env._G = env
  for k,v in pairs(exports) do env[k] = v end

  for _,path in ipairs({"hc3emu.class","hc3emu.qafuns","hc3emu.fibaro","hc3emu.quickapp","hc3emu.net"}) do
    DEBUGF('info',"Loading QA library %s",path)
    if _DEVELOP then
      path = "lib/"..path:match(".-%.(.*)")..".lua"
    else  path = package.searchpath(path,package.path) end
    loadfile(path,"t",env)()
  end
  
  function env.print(...) env.fibaro.debug(env.__TAG,...) end

  for _,lf in ipairs(info.files) do
    DEBUGF('info',"Loading user file %s",lf.fname)
    _,lf.src = readFile{file=lf.fname,eval=true,env=env,silent=false}
  end
  DEBUGF('info',"Loading user main file %s",info.fname)
  load(info.src,info.fname,"t",env)()
  assert(TQ.URL, TQ.USER and TQ.PASSWORD,"Please define URL, USER, and PASSWORD")
end

local function createQAstruct(info)
  if info.directives == nil then parseDirectives(info) end
  TQ.setOffline(info.directives.offline) 
  local flags = info.directives
  local env = info.env
  local qvs = flags.var
  
  local uiCallbacks,viewLayout,uiView
  if flags.u and #flags.u > 0 then
    uiCallbacks,viewLayout,uiView = TQ.compileUI(flags.u)
  end

  if flags.id == nil then flags.id = DEVICEID DEVICEID = DEVICEID + 1 end
  local deviceStruct = {
    id=tonumber(flags.id),
    type=flags.type or 'com.fibaro.binarySwitch',
    name=flags.name or 'MyQA',
    enabled = true,
    visible = true,
    properties = { quickAppVariables = qvs, uiCallbacks = uiCallbacks, viewLayout = viewLayout, uiView = uiView },
    useUiView = false,
    interfaces = {"quickApp"},
    created = os.time(),
    modified = os.time()
  }
  info.env.__TAG = (deviceStruct.name..(deviceStruct.id or "")):upper()
  -- Find or create proxy if specified
  if flags.offline and flags.proxy then
    flags.proxy = nil
    DEBUG("Offline mode, proxy directive ignored")
  end
  
  if flags.proxy then
    TQ.route = TQ.require("hc3emu.route")(TQ.HC3Call) -- Need this to do api.calls to setup proxy
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
      info.env.__TAG = (deviceStruct.name..(deviceStruct.id or "")):upper()
      api.post("/plugins/updateProperty",{deviceId= deviceStruct.id,propertyName='quickAppVariables',value=qvs})
      if flags.logUI then TQ.logUI(deviceStruct.id) end
      TQ.startServer()
      info.isProxy = true
    end
  end
  
  info.device = deviceStruct
  info.id = deviceStruct.id
  env.plugin = env.plugin or {}
  env.plugin._dev = deviceStruct
  env.plugin.mainDeviceId = deviceStruct.id -- Now we have a deviceId
  TQ.registerQA(info)
  
  if flags.save then
    local fileName = flags.save
    local fqa = TQ.getFQA(info.id)
    local vars = table.copy(fqa.initialProperties.quickAppVariables)
    fqa.initialProperties.quickAppVariables = vars
    for _,v in ipairs(vars) do
      if flags.conceal[v.name] then 
        v.value = flags.conceal[v.name]
      end
    end
    local f = io.open(fileName,"w")
    assert(f,"Can't open file "..fileName)
    f:write(json.encode(fqa))
    f:close()
    DEBUG("Saved QuickApp to %s",fileName)
  end
  
  return info
end

-- function runQA(info) -- The rest is run in a copas tasks...
--   mobdebug.on()
--   local isQA = info.src:match("fun".."ction%s+QuickApp:onInit") ~= nil
--   if isQA then  -- Start QuickApp if defined, e.g. run :onInit()
--     createQAstruct(info) 
--     loadQAFiles(info)
--     DEBUGF('info',"Starting QuickApp %s",info.device.name)
--     TQ.post({type='quickApp_started',id=info.id},true)
--     info.env.quickApp = info.env.QuickApp(info.device) -- quickApp defined first when we return from :onInit()...
--   else
--     loadQAFiles(info) -- No QA, just load the QA files...
--   end
-- end

function runQA(info) -- The rest is run in a copas tasks...
  mobdebug.on()
  createQAstruct(info) 
  loadQAFiles(info)
  if info.env.QuickApp.onInit then
    DEBUGF('info',"Starting QuickApp %s",info.device.name)
    TQ.post({type='quickApp_started',id=info.id},true)
    info.env.quickApp = info.env.QuickApp(info.device) -- quickApp defined first when we return from :onInit()...
  end
end

if not flags.silent then print(TQ.colorStr('orange',"HC3Emu - Tiny QuickApp emulator for the Fibaro Home Center 3, v"..VERSION)) end
while true do
  local startTime,t0 = os.clock(),os.time()
  TQ._shouldExit = true
  copas(function() addThread(function()
    TQ.post({type='emulator_started'},true)
    runQA(qaInfo) end) 
  end)
  DEBUG("Runtime %.3f sec (%s sec absolute time)",os.clock()-startTime,os.time()-t0)
  if TQ._shouldExit then os.exit(0) end
end
