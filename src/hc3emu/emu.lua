--[[
hc3emu - QuickApp emulator for the Fibaro Home Center 3
Copyright (c) 2025 Jan Gabrielsson
Email: jan@gabrielsson.com
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.
--]]

--[[
Installation:
>luarocks install hc3emu

Dependencies:
lua >= 5.3, <= 5.4
copas >= 4.7.1-1  (luasocket, luasec, timerwheel)
luamqtt >= 3.4.3-1
lua-json >= 1.0.0-1
bit32 >= 5.3.5.1-1
lua-websockets-bit32 >= 2.0.1-7
mobdebug >= 0.80-1
--]]
local VERSION = "1.0.49"
local class = require("hc3emu.class")

local fmt = string.format

local socket = require("socket")
local ltn12 = require("ltn12")
local copas = require("copas")
copas.https = require("ssl.https")
require("copas.timer")
require("copas.http")

local _print = print
local json,urlencode

class 'Emulator'
local Emulator = _G['Emulator']

function Emulator:__init()
  self.VERSION = VERSION
  self.cfgFileName = "hc3emu_cfg.lua"   -- Config file in current directory
  self.homeCfgFileName = ".hc3emu.lua"  -- Config file in home directory
  
  local win = (os.getenv('WINDIR') or (os.getenv('OS') or ''):match('[Ww]indows')) and not (os.getenv('OSTYPE') or ''):match('cygwin') -- exclude cygwin
  self.fileSeparator = win and '\\' or '/'
  self.tempDir = os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp/" -- temp directory
  self.homeDir = os.getenv("HOME") or os.getenv("homepath") or ""
  self.emuPort = 8264
  -- Try to guess in what environment we are running (used for loading extra console colors)
  self.isVscode = package.path:lower():match("vscode") ~= nil
  self.isZerobrane = package.path:lower():match("zerobrane") ~= nil
  
  self.util = require("hc3emu.util") -- Utility functions
  self.util.emulator = self
  self.EVENT = self.util.EVENT
  self.post = function(_,...) return self.util.post(...) end
  self.addThread = function(_,...) return self.util.addThread(...) end
  
  self.DIR={} -- Directory for all QAs - devicesId -> QAinfo 
  self.EMUVAR = "TQEMU" -- HC3 GV with connection data for HC3 proxy
  self.emuPort = 8264   -- Port for HC3 proxy to connect to
  self.emuIP = nil      -- IP of host running the emulator
  self.api = {}         -- API functions
  self.DBG = {} -- Default flags and debug settings
  self.exports = {} -- functions to export to QA
  
  local someRandomIP = "192.168.1.122" --This address you make up
  local someRandomPort = "3102" --This port you make up
  local mySocket = socket.udp() --Create a UDP socket like normal
  mySocket:setpeername(someRandomIP,someRandomPort)
  local myDevicesIpAddress,_ = mySocket:getsockname()-- returns IP and Port
  self.emuIP = myDevicesIpAddress == "0.0.0.0" and "127.0.0.1" or myDevicesIpAddress
  
  self.DEVICEID = 5000 -- Start id for QA devices
  
  self.json = require("hc3emu.json")
  function print(...) if self.silent then return else _print(...) end end
  
  -- Attempt to hide type function for debuggers...
  -- We need to recognize our class objects as 'userdata' (table with __USERDATA key)
  local luaTypeCode = [[return function(obj) local t = type(obj) local r = t == 'table' and rawget(obj,'__USERDATA') and 'userdata' or t return r end]]
  local luaType,_ = load(luaTypeCode,nil,"t",{type=type,rawget=rawget})()
  self.luaType = luaType
  
  self.lua = {require = require, dofile = dofile, loadfile = loadfile, type = type, io = io, print = _print, package = package } -- used from fibaro.hc3emu.lua.x 
  
  json,urlencode = self.json,self.util.urlencode
end

function Emulator:init(debug) 
  self.silent = debug.silent
  self.nodebug = debug.nodebug
  self.DBG = debug
  
  local function ll(fn) local f,e = loadfile(fn) if f then return f() else return not tostring(e):match("such file") and error(e) or nil end end
  
  -- Get home project file, defaults to {}
  self:DEBUGF('info',"Loading home config file %s",self.homeCfgFileName)
  local homeCfg = ll(self.homeDir.."/"..self.homeCfgFileName) or {}
  
  -- Get project config file, defaults to {}
  self:DEBUGF('info',"Loading project config file ./%s",self.cfgFileName)
  local cfgFlags = ll(self.cfgFileName) or {}
  
  ---@diagnostic disable-next-line: undefined-field
  self.baseFlags = table.merge(homeCfg,cfgFlags) -- merge with home config
  for _,globalFlag in ipairs({'offline','state','logColor','stateReadOnly','dark'}) do
    if self.baseFlags[globalFlag]~=nil then self.DBG[globalFlag] = self.baseFlags[globalFlag] end
  end
  
  self.mobdebug = { on = function() end, start = function(_,_) end }
  if not self.nodebug then
    self.mobdebug = require("mobdebug") or self.mobdebug
    self.mobdebug.start('127.0.0.1', 8818)
  end
  
  local function loadModule(name)
    self:DEBUGF('modules',"Loading module %s",name)
    local r = require(name)
    r.emulator = self
    if r.init then r:init() end
    return r
  end
  
  self.log = loadModule("hc3emu.log")
  self.timers = loadModule("hc3emu.timers") 
  self.store = loadModule("hc3emu.db")                   -- Database for storing data
  self.route = loadModule("hc3emu.route")                -- Route object
  self.emuroute = loadModule("hc3emu.emuroute")          -- Emulator API routes
  self.proxy = loadModule("hc3emu.proxy")                -- Proxy creation and Proxy API routes
  self.offline = loadModule("hc3emu.offline")            -- Offline API routes
  self.refreshState = loadModule("hc3emu.refreshstate") 
  self.ui = loadModule("hc3emu.ui") 
  self.tools = loadModule("hc3emu.tools") 
  self.scene = loadModule("hc3emu.scene") 

    
  self.route.createConnections() -- Setup connections for API calls, emulator/offline/proxy
  self.connection = self.route.hc3Connection
end

function Emulator:DEBUG(f,...) print("[SYS]",fmt(f,...)) end
function Emulator:DEBUGF(flag,f,...) 
  local env = self:getCoroData(nil,'env')
  if env and env.__debugFlags then 
    local v = env.__debugFlags[flag]
    if v~=nil then if v then self:DEBUG(f,...) end return end
  end
  if self.DBG[flag] then self:DEBUG(f,...) end
end
function Emulator:WARNINGF(f,...) print("[SYSWARN]",fmt(f,...)) end
function Emulator:ERRORF(f,...) _print("[SYSERR]",fmt(f,...)) end

function Emulator:parseDirectives(info) -- adds {directives=flags,files=files} to info
  self:DEBUGF('info',"Parsing %s directives...",info.fname)
  
  local flags = {
    name='MyQA', type='com.fibaro.binarySwitch', debug={}, logColor = true,
    var = {}, gv = {}, files = {}, creds = {}, u={}, conceal = {}, 
  }
  
  local function eval(str,d,force)
    local stat, res = pcall(function() return load("return " .. str, nil, "t", { config = self.baseFlags })() end)
    if stat then return res end
    if force then return str end
    self:ERRORF("directive '%s' %s",tostring(d),res)
    error()
  end
  
  local directive = {}
  --@D name=<name> - Name of the QA
  function directive.name(d,val) flags.name = val end
  --@D type=<type> - Type of the QA, ex. --%%type=com.fibaro.binarySwitch
  function directive.type(d,val) flags.type = val end
  --@D id=<id> - Device id for the QA, ex. --%%id=5000. Proxy gets id from HC3.
  function directive.id(d,val) flags.id = eval(val,d) assert(flags.id,"Bad id directive:"..d) end
  --@D project=<id> - Project id for the QA, ex. --%%project=5566
  --This the deviceId for the QA on HC3, used to save files back to HC3
  function directive.project(d,val) flags.project = eval(val,d) assert(flags.project,"Bad project directive:"..d) end
  --@D var=<name>:<expr> - Set a quickAppVariable variable, ex. --%%var=password:"hubba"
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
  --@D conceal=<name>:<expr> - Change qvar when fqa is saved, ex. --%%conceal:password:"<your password here>"
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
  --@D file=<path>:<name> - Add a file to the QA, ex. --%%file=src/lib.lua:lib
  function directive.file(d,val) 
    local path,m = val:match("(.-)[:,](.-);?%s*$")
    if path:match("%$") then 
      path = package.searchpath(path:sub(2),package.path)
    end
    assert(path and m,"Bad file directive: "..d)
    flags.files[#flags.files+1] = {fname=path,name=m}
  end
  --@D debug=<name>:<expr> - Set debug flag, ex. --%%debug=info:true,http:true,onAction:true,onUIEvent:true
  function directive.debug(d,val) 
    local vs = val:split(",")
    for _,v in ipairs(vs) do
      local name,expr = v:match("(.-):(.*)")
      assert(name and expr,"Bad debug directive: "..d) 
      local e = eval(expr,d)
      if e~=nil then flags.debug[name] = e end
    end
  end
  --@D u=<expr> - Adds UI element, ex. --%%u={button='bt1',text="MyButton",onReleased="myButton"}
  function directive.u(d,val) flags.u[#flags.u+1] = eval(val,d) end
  --@D interfaces=<list expr> - Set interfaces, ex. --%%interfaces={"energy","battery"}
  function directive.interfaces(d,val) flags.interfaces = eval(val,d) end
  --@D uid=<UID> - Set quickAppUuid property, ex. --%%uid=345345235324
  function directive.uid(d,val) flags.uid = val end
  --@D manufacturer=name - Set manufacturer property, ex. --%%manufacturer=Acme Inc
  function directive.manufacturer(d,val) flags.manufacturer = val end
  --@D model=name - Set model property, ex. --%%model=standard
  function directive.model(d,val) flags.model = val end
  --@D role=<role> - Set deviceRole property, ex. --%%role=Light
  function directive.role(d,val) flags.role = val end
  --@D decsription=<text> - Set userDescription property, ex. --%%description=This is a QA
  function directive.description(d,val) flags.description = val end
  --@D save=<name> - Save QA as fqa at run, ex. --%%save=MyQA.fqa
  function directive.save(d,val) flags.save = tostring(val) assert(flags.save:match("%.fqa$"),"Bad save directive:"..d)end
  --@D proxy=<name> - Set name of proxy on HC3, ex. --%%proxy=MyProxy
  function directive.proxy(d,val) flags.proxy = tostring(val) end
  --@D dark=<bool> - Set dark mode,affects log colors, ex. --%%dark=true
  function directive.dark(d,val) flags.dark = eval(val,d) end
  --@D color=<bool> - Set log in color, ex. --%%color=true
  function directive.color(d,val) flags.logColor = eval(val,d) end
  --@D speed=<val> - Speeds the emulator for <val> hours, ex. --%%speed=10
  function directive.speed(d,val) flags.speed = eval(val,d) assert(tonumber(flags.speed),"Bad speed directive:"..d)end
  --@D port=<val> - Set port for HC3 proxy, ex. --%%port=8264
  function directive.port(d,val) self.emuPort = eval(val,d) assert(tonumber(self.emuPort),"Bad port directive:"..d)end
  --@D logUI=<bool> - Log UI directives from proxy, ex. --%%logUI=true
  function directive.logUI(d,val) flags.logUI = eval(val,d) end
  --@D breakOnLoad=<bool> - Break on first line when loading file, ex. --%%breakOnLoad=true
  function directive.breakOnLoad(d,val) flags.breakOnLoad = eval(val,d) end
  --@D breakOnInit=<bool> - Break on :onInit line, ex. --%%breakOnInit=true
  function directive.breakOnInit(d,val) flags.breakOnInit = eval(val,d) end
  --@D offline=<bool> - Run in offline mode, no HC3 calls, ex. --%%offline=true
  function directive.offline(d,val) flags.offline = eval(val,d) end
  directive['local'] = function(d,val) flags.offline = eval(val,d) end
  --@D state=<name> - Set file for saving state between runs, ex. --%%state=state.db
  function directive.state(d,val) flags.state = tostring(val) end
  --@D nodebug=<bool> - If true don't load debugger, ex. --%%nodebug=true
  function directive.nodebug(d,val) flags.nodebug = eval(val,d) end
  --@D silent=<bool> - If true minimize log output, ex. --%%silent=true
  function directive.silent(d,val) flags.silent = eval(val,d) end
  --@D shellscript=<bool> - If true don't load debugger, ex. --%%shellscript=true
  function directive.shellscript(d,val) 
    flags.shellscript = tostring(val)
    flags.nodebug = flags.shellscript
  end
  --@D tempDir=<path> - Set temp directory, ex. --%%tempDir=/tmp/
  function directive.tempDir(d,val) self.tempDir = tostring(val) end
  --@D stateReadOnly=<bool> - If true state file is read only, ex. --%%stateReadOnly=true
  function directive.stateReadOnly(d,val) flags.stateReadOnly = eval(val,d) end
  --@D latitude=<val> - Set latitude for time calculations, ex. --%%latitude=59.3
  function directive.latitude(d,val) flags.latitude = tonumber(val) end
  --@D longitude=<val> - Set longitude for time calculations, ex. --%%longitude=18.1
  function directive.longitude(d,val) flags.longitude = tonumber(val) end
  --@D time=<val> - Set start time for the emulator, ex. --%%time=12/31 10:00:12
  function directive.time(d,val) flags.startTime = val end
  --@D trigger=<delay>:<trigger> - Trigger for scene, ex. --%%trigger=2:{type='user',property='execute',id=2}
  function directive.trigger(d,val)
    flags.triggers = flags.triggers or {}
    local delay,trigger = val:match("(%d+):(.*)")
    assert(delay and trigger,"Bad trigger directive: "..d)
    flags.triggers[#flags.triggers + 1] = {delay = tonumber(delay), trigger = eval(trigger,d)}
  end
  
  local truncCode = info.src:match("(.-)%-%-+ENDOFDIRECTIVES%-%-") or info.src
  --@D include=<file> - Include a file with additional directives. Format <direct>=<value>
  local include = truncCode:match("%-%-%%%%include=(.-)%s*\n")
  if include then
    info.extraDirectives = info.extraDirectives or {}
    local f = io.open(include)
    assert(f,"Can't open include file "..tostring(include))
    local src = f:read("*all") f:close()
    src:gsub("%-%-%%%%(%w-=.-)%s*\n",function(p)
      table.insert(info.extraDirectives,p)
    end)
  end
  if info.extraDirectives then
    local extras = {}
    for _,d in ipairs(info.extraDirectives) do extras[#extras+1] = fmt("--%%%%%s",d) end
    local extraStr = table.concat(extras,"\n")
    truncCode = truncCode.."\n"..extraStr.."\n"
  end
  
  local ignore = {root=true,remote=true,include=true}
  truncCode:gsub("%-%-%%%%(%w-=.-)%s*\n",function(p)
    local f,v = p:match("(%w-)=(.*)")
    if ignore[f] then return end
    local v1,com = v:match("(.*)%s* %-%- (.*)$") -- remove comments
    if v1 then v = v1 end
    if f:match("^u%d+$") then f="u" end -- backward compatibility
    if directive[f] then
      directive[f](p,v)
    else self:WARNINGF("Unknown directive: %s",tostring(f)) end
  end)
  
  info.directives = table.merge(table.copy(self.baseFlags),flags)
  info.files = flags.files
end

function Emulator:httpRequest(method,url,headers,data,timeout,user,pwd)
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
  local env = self.getCoroData(nil,'env')
  if url:starts("https") then r,status,h = copas.https.request(req)
  else r,status,h = copas.http.request(req) end
  if tonumber(status) and status < 300 then
    return resp[1] and table.concat(resp) or nil, status, h
  else
    return nil, status, h, resp
  end
end

local BLOCK = false 
function Emulator:HC3Call(method,path,data,silent)
  --print(path)
  if BLOCK then self:ERRORF("HC3 authentication failed again, Access blocked") return nil, 401, "Blocked" end
  if type(data) == 'table' then data = json.encode(data) end
  assert(self.URL,"Missing hc3emu.URL")
  assert(self.USER,"Missing hc3emu.USER")
  assert(self.PASSWORD,"Missing hc3emu.PASSWORD")
  local t0 = socket.gettime()
  local res,stat,headers = self:httpRequest(method,self.URL.."api"..path,{
    ["Accept"] = '*/*',
    ["X-Fibaro-Version"] = 2,
    ["Fibaro-User-PIN"] = self.PIN,
  },
  data,35000,self.USER,self.PASSWORD)
  if stat == 401 then self:ERRORF("HC3 authentication failed, Access blocked") BLOCKED = true end
  if stat == 'closed' then self:ERRORF("HC3 connection closed %s",path) end
  if stat == 500 then self:ERRORF("HC3 error 500 %s",path) end
  local t1 = socket.gettime()
  local jf,data = pcall(json.decode,res)
  local t2 = socket.gettime()
  if not silent and self.DBG.http then self:DEBUGF('http',"API: %s %.4fs (decode %.4fs)",path,t1-t0,t2-t1) end
  return (jf and data or res),stat
end

function Emulator:apiget(...) return self.connection:call("GET",...) end
function Emulator:apipost(...) return self.connection:call("POST",...) end
function Emulator:apiput(...) return self.connection:call("PUT",...) end
function Emulator:apidelete(...) return self.connection:call("DELETE",...) end

local coroMetaData = setmetatable({},{__mode = "k"})
function Emulator:getCoroData(co,key) return (coroMetaData[co or coroutine.running()] or {})[key] end
function Emulator:setCoroData(co,key,val)
  co = co or coroutine.running()
  local md = coroMetaData[co] or {}
  coroMetaData[co] = md
  md[key] = val
  return val
end

function Emulator:registerQA(info) -- {id=id,directives=directives,fname=fname,src=src,env=env,device=dev,qa=qa,files=files,proxy=<bool>,child=<bool>}
  local id = info.id
  assert(id,"Can't register QA without id")
  self.DIR[id] = info 
  self.store.DB.devices[id] = info.device
end

function Emulator:getQA(id) return self.DIR[id] end

function Emulator:saveProject(info)
  local r = {}
  for _,f in ipairs(info.files) do
    r[f.name] = f.fname
  end
  r.main = info.fname
  local f = io.open(".project","w")
  assert(f,"Can't open file "..".project")
  f:write(json.encodeFormated({files=r,id=info.directives.project}))
  f:close()
end

-------------------------------------------------------------
-- Our own setTimout, used by non-user code, not working with speed time
-- function setTimeout(fun,ms) return copas.timer.new({name = "SYS",delay = ms / 1000.0, callback = function() self.mobdebug.on() fun() end}) end
-- function clearTimeout(ref) return ref:cancel() end

function Emulator:getNextDeviceId() self.DEVICEID = self.DEVICEID + 1 return self.DEVICEID end

function Emulator:loadfile(path,env)
  path = package.searchpath(path,package.path)
  return loadfile(path,"t",env)()
end

-------------------------------- QA setup/start ----------------------------
-- Creates a QA device structure and registers it with the HC3 emulator
-- @param info Table containing configuration information for the QA

function Emulator:createQAstruct(info,noRun) -- noRun -> Ignore proxy
  if info.directives == nil then self:parseDirectives(info) end
  local flags = info.directives
  local env = info.env
  local qvs = json.util.InitArray(flags.var or {})
  
  local uiCallbacks,viewLayout,uiView
  if flags.u and #flags.u > 0 then
    uiCallbacks,viewLayout,uiView = self.ui.compileUI(flags.u)
  else
    viewLayout = json.decode([[{
        "$jason": {
          "body": {
            "header": {
              "style": { "height": "0" },
              "title": "quickApp_device_57"
            },
            "sections": { "items": [] }
          },
          "head": { "title": "quickApp_device_57" }
        }
      }
  ]])
    viewLayout['$jason']['body']['sections']['items'] = json.util.InitArray({})
    uiView = json.util.InitArray({})
    uiCallbacks = json.util.InitArray({})
  end
  
  if flags.id == nil then flags.id = self:getNextDeviceId() end
  ---@diagnostic disable-next-line: undefined-field
  local ifs = table.copy(flags.interfaces or {})
  ---@diagnostic disable-next-line: undefined-field
  if not table.member(ifs,"quickApp") then ifs[#ifs+1] = "quickApp" end
  local deviceStruct = {
    id=tonumber(flags.id),
    type=flags.type or 'com.fibaro.binarySwitch',
    name=flags.name or 'MyQA',
    enabled = true,
    visible = true,
    properties = { apiVersion = "1.3", quickAppVariables = qvs, uiCallbacks = uiCallbacks, useUiView = false, viewLayout = viewLayout, uiView = uiView, typeTemplateInitialized = true },
    useUiView = false,
    interfaces = ifs,
    created = os.time(),
    modified = os.time()
  }
  for k,p in pairs({
    model="model",uid="quickAppUuid",manufacturer="manufacturer",
    role="deviceRole",description="userDescription"
  }) do deviceStruct.properties[p] = flags[k] end
  info.env.__TAG = (deviceStruct.name..(deviceStruct.id or "")):upper()
  -- Find or create proxy if specified
  if flags.offline and flags.proxy then
    flags.proxy = nil
    self:DEBUG("Offline mode, proxy directive ignored")
  end
  
  if flags.proxy and not noRun then
    local pname = tostring(flags.proxy)
    local pop = pname:sub(1,1)
    if pop == '-' or pop == '+' then -- delete proxy if name is preceeded with "-" or "+"
      pname = pname:sub(2)
      flags.proxy = pname
      local qa = self:apiget("/devices?name="..urlencode(pname))
      assert(type(qa)=='table')
      for _,d in ipairs(qa) do
        self:apidelete("/devices/"..d.id)
        self:DEBUGF('info',"Proxy device %s deleted",d.id)
      end
      if pop== '-' then flags.proxy = false end -- If '+' go on and generate a new Proxy
    end
    if flags.proxy then
      deviceStruct = self.proxy.getProxy(flags.proxy,deviceStruct) -- Get deviceStruct from HC3 proxy
      assert(deviceStruct, "Can't get proxy device")
      local id,name = deviceStruct.id,deviceStruct.name
      info.env.__TAG = (name..(id or "")):upper()
      self:apipost("/plugins/updateProperty",{deviceId=id,propertyName='quickAppVariables',value=qvs})
      if flags.logUI then self.ui.logUI(id) end
      self.proxy.startServer(id)
      self:apipost("/devices/"..id.."/action/CONNECT",{args={{ip=self.emuIP,port=self.emuPort}}})
      info.isProxy = true
    end
  end
  
  info.device = deviceStruct
  info.id = deviceStruct.id
  env.plugin = env.plugin or {}
  env.plugin._dev = deviceStruct
  env.plugin.mainDeviceId = deviceStruct.id -- Now we have a deviceId
  self:registerQA(info)
  
  return info
end

--- Loads sets up Environment and loads (QA) files into the environment
-- @param info Table containing configuration information for loading QA files
function Emulator:loadQAFiles(info)
  local flags = info.directives
  self.flags = flags
  if info.directives == nil then self:parseDirectives(info) end
  if info.directives.startTime then 
    local t = self.timers.parseTime(info.directives.startTime)
    self.timers.setTime(t) 
  end
  local userTime,userDate = self.timers.userTime,self.timers.userDate

  local env = info.env
  local os2 = { time = userTime, clock = os.clock, difftime = os.difftime, date = userDate, exit = os.exit, remove = os.remove, require = require }
  local fibaro = { hc3emu = self, HC3EMU_VERSION = self.VERSION, flags = info.directives, DBG = self.DBG }
  local args = nil
  if flags.shellscript then
    args = {}
    for i,v in pairs(arg) do if i > 0 then args[#args+1] = v end end
  end
  for k,v in pairs({
    __assert_type = __assert_type, fibaro = fibaro, json = json, urlencode = self.util.urlencode, args=args,
    collectgarbage = collectgarbage, os = os2, math = math, string = string, table = table, _print = print,
    getmetatable = getmetatable, setmetatable = setmetatable, tonumber = tonumber, tostring = tostring,
    type = self.luaType, pairs = pairs, ipairs = ipairs, next = next, select = select, unpack = table.unpack,
    error = error, assert = assert, pcall = pcall, xpcall = xpcall, bit32 = require("bit32"),
    rawset = rawset, rawget = rawget,
  }) do env[k] = v end
  env._error = function(str) env.fibaro.error(env.__TAG,str) end
  env.__TAG = info.directives.name..info.id
  env._G = env
  for k,v in pairs(self.exports) do env[k] = v end
  
  for _,path in ipairs({"hc3emu.fibaro","hc3emu.class","hc3emu.quickapp","hc3emu.net"}) do
    self:DEBUGF('info',"Loading QA library %s",path)
    self:loadfile(path,env)
  end
  
  function env.print(...) env.fibaro.debug(env.__TAG,...) end
  
  -- if flags.speed then self.timers.startSpeedTime(flags.speed) end
  
  for _,lf in ipairs(info.files) do
    self:DEBUGF('info',"Loading user file %s",lf.fname)
    if lf.content then
      load(lf.content,lf.fname,"t",env)()
    else
      _,lf.content = self.util.readFile{file=lf.fname,eval=true,env=env,silent=false}
    end
  end
  self:DEBUGF('info',"Loading user main file %s",info.fname)
  load(info.src,info.fname,"t",env)()
  if not flags.offline then 
    assert(self.URL and self.USER and self.PASSWORD,"Please define URL, USER, and PASSWORD") -- Early check that creds are available
  end
end

function Emulator:runQA(info) -- run QA:  create QA struct, load QA files. Runs in a copas task.
  self.mobdebug.on()
  self:createQAstruct(info)
  self:addThread(info.env,function()
    self:setCoroData(nil,'env',info.env)
    local flags = info.directives or {}
    info.env.__debugFlags = flags.debug or {}
    local firstLine,onInitLine = self.tools.findFirstLine(info.src)
    if flags.breakOnLoad and firstLine then self.mobdebug.setbreakpoint(info.fname,firstLine) end
    self:loadQAFiles(info)
    if flags.save then self.tools.saveQA(info.id) end
    if flags.project then self:saveProject(info) end
    if info.env.QuickApp.onInit then
      if flags.breakOnInit and onInitLine then self.mobdebug.setbreakpoint(info.fname,onInitLine+1) end
      self:DEBUGF('info',"Starting QuickApp %s",info.device.name)
      self:post({type='quickApp_started',id=info.id},true)
      info.env.quickApp = info.env.QuickApp(info.device) -- quickApp defined first when we return from :onInit()...
      if flags.speed then self:startSpeedTime(flags.speed) end
    end
  end)
  return info
end


function Emulator:run(args)
  self:DEBUGF('info',"Main QA file %s",args.fname)
  self.mainFile = args.fname
  local info = {fname=self.mainFile,src=args.src,env={}}
  self:parseDirectives(info)
  local flags = info.directives
  for _,globalFlag in ipairs({'offline','state','logColor','stateReadOnly','dark'}) do
    if flags[globalFlag]~=nil then self.DBG[globalFlag] = flags[globalFlag] end
  end

  self.USER = (flags.creds or {}).user or self.USER            -- Get credentials (again), if changed
  self.PASSWORD = (flags.creds or {}).password or self.PASSWORD
  self.URL = (flags.creds or {}).url or self.URL
  self.PIN = (flags.creds or {}).pin or self.PIN
  
  self.timers.midnightLoop() -- Setup loop for midnight events, used to ex. update sunrise/sunset hour
  
  print(self.log.colorStr('orange',"HC3Emu - Tiny QuickApp emulator for the Fibaro Home Center 3, v"..self.VERSION))
  
  local object = info.directives.type == 'scene' and self.scene.Scene(info) or nil

  while true do
    local startTime,t0 = os.clock(),os.time()
    self._shouldExit = true
    copas(function() -- This is the first task we create
      self.mobdebug.on()
      self:post({type='emulator_started'},true)
      if object then object:run()
      else self:runQA(info) end
    end)
    self:DEBUG("Runtime %.3f sec (%s sec absolute time)",os.clock()-startTime,os.time()-t0)
    if self._shouldExit then os.exit(0) end
  end
end

return Emulator
