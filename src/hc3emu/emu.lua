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
argparse >= 0.7.1-1
mobdebug >= 0.80-1
--]]
local VERSION = "1.0.54"
local class = require("hc3emu.class") -- use simple class implementation

local fmt = string.format

local socket = require("socket")
local ltn12 = require("ltn12")
local copas = require("copas")
copas.https = require("ssl.https")
require("copas.timer")
require("copas.http")

local _print = print
local json,urlencode

class 'Emulator' -- Main class 'Emulator'
class 'Runner'   -- Base class for stuff that runs in the emulator, QuickApps, Scenes, System tasks

local logTime = os.time
local userDate = os.date
local dateMark = function(str) return os.date("[%d.%m.%Y][%H:%M:%S][",logTime())..str.."]" end

Emulator = Emulator -- fool linting...
function Emulator:__init()
  self.VERSION = VERSION
  Emulator.emulator = self
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
  
  self.QA_DIR={} -- Directory for all QAs - devicesId -> QA object
  self.SCENE_DIR={} -- Directory for all Scenes - sceneId -> Scene object
  self.EMUVAR = "TQEMU" -- HC3 GV with connection data for HC3 proxy
  self.emuPort = 8264   -- Port for HC3 proxy to connect to
  self.emuIP = nil      -- IP of host running the emulator
  self.api = {}         -- API functions
  self.DBG = {} -- Default flags and debug settings
  self.exports = {} -- functions to export to QA
  self.RunnerClass = Runner
  
  local someRandomIP = "192.168.1.122" --This address you make up
  local someRandomPort = "3102" --This port you make up
  local mySocket = socket.udp() --Create a UDP socket like normal
  mySocket:setpeername(someRandomIP,someRandomPort)
  local myDevicesIpAddress,_ = mySocket:getsockname()-- returns IP and Port
  self.emuIP = myDevicesIpAddress == "0.0.0.0" and "127.0.0.1" or myDevicesIpAddress
  
  self.DEVICEID = 5000 -- Start id for QA devices
  self.SCENEID = 7000 -- Start id for Scene devices
  
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

function Emulator:init(debug,info) 
  self.silent = debug.silent
  self.nodebug = debug.nodebug
  self.DBG = debug
  self.systemRunner = SystemRunner()
  self:setRunner(self.systemRunner)
  self.mainFile = info.fname
  
  local function ll(fn) local f,e = loadfile(fn) if f then return f() else return not tostring(e):match("such file") and error(e) or nil end end
  
  -- Get home project file, defaults to {}
  self:DEBUGF('info',"Loading home config file %s",self.homeCfgFileName)
  local homeCfg = ll(self.homeDir.."/"..self.homeCfgFileName) or {}
  
  -- Get project config file, defaults to {}
  self:DEBUGF('info',"Loading project config file ./%s",self.cfgFileName)
  local cfgFlags = ll(self.cfgFileName) or {}
  
  ---@diagnostic disable-next-line: undefined-field
  self.baseFlags = table.merge(homeCfg,cfgFlags) -- merge with home config
  
  self.mobdebug = { on = function() end, start = function(_,_) end }
  if not self.nodebug then
    self.mobdebug = require("mobdebug") or self.mobdebug
    self.mobdebug.start('127.0.0.1', 8818)
  end
  
  self:parseDirectives(info)

  for _,globalFlag in ipairs({'offline','state','logColor','stateReadOnly','dark','longitude','latitude','lock'}) do
    if info.directives[globalFlag]~=nil then self.DBG[globalFlag] = info.directives[globalFlag] end
  end

  local function loadModule(name)
    self:DEBUGF('modules',"Loading module %s",name)
    local r = require(name)
    if r.init then r:init() end
    return r
  end
  
  self.log = loadModule("hc3emu.log")
  self.timers = loadModule("hc3emu.timers") 
  logTime = self.timers.userTime
  userDate = self.timers.userDate
  self.store = loadModule("hc3emu.db")                   -- Database for storing data
  self.route = loadModule("hc3emu.route")                -- Route object
  self.emuroute = loadModule("hc3emu.emuroute")          -- Emulator API routes
  self.proxy = loadModule("hc3emu.proxy")                -- Proxy creation and Proxy API routes
  self.offline = loadModule("hc3emu.offline")            -- Offline API routes
  self.refreshState = loadModule("hc3emu.refreshstate") 
  self.ui = loadModule("hc3emu.ui") 
  self.tools = loadModule("hc3emu.tools") 
  self.qa = loadModule("hc3emu.qa") 
  self.scene = loadModule("hc3emu.scene") 
  
  self.route.createConnections() -- Setup connections for API calls, emulator/offline/proxy
  self.connection = self.route.hc3Connection
end

function Emulator:newLock()
  if self.DBG.lock then return copas.lock.new(math.huge)           -- Lock with no timeout
  else return {get = function() end, release = function() end} end -- Nop lock
end

function Emulator:getNextDeviceId() self.DEVICEID = self.DEVICEID + 1 return self.DEVICEID end
function Emulator:getNextSceneId() self.SCENEID = self.SCENEID + 1 return self.SCENEID end

function Emulator:registerQA(qa) 
  assert(qa.id,"Can't register QA without id")
  self.QA_DIR[qa.id] = qa 
  self.store.DB.devices[qa.id] = qa.device
end

function Emulator:unregisterQA(id) 
  self.QA_DIR[id] = nil 
  self.store.DB.devices[id] = nil
end

function Emulator:registerScene(scene) 
  assert(scene.id,"Can't register Scene without id")
  self.SCENE_DIR[scene.id] = scene
  --self.store.DB.scenes[scene.id] = scene.device
end

function Emulator:getQA(id) return self.QA_DIR[id] end
function Emulator:getScene(id) return self.SCENE_DIR[id] end

function Emulator:DEBUG(f,...) print(dateMark('SYS'),fmt(f,...)) end
function Emulator:DEBUGF(flag,f,...) if self:DBGFLAG(flag) then self:DEBUG(f,...) end end
function Emulator:DBGFLAG(flag) 
  local runner = self:getRunner()
  if not runner then return self.DBG[flag] end
  local v = runner.dbg[flag]
  if v~=nil then return v else return self.DBG[flag] end
end

function Emulator:WARNINGF(f,...) print(dateMark('SYSWARN'),fmt(f,...)) end
function Emulator:ERRORF(f,...) _print(dateMark('SYSERR'),fmt(f,...)) end

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
  --@D exit=<bool> - Exit QA when no timers left, ex. --%%exit=true
  function directive.exit(d,val) flags.exit = eval(val,d) end
  --@D exit0=<bool> - If true exit QA with os.exit(0), else restart, ex. --%%exit0=true
  function directive.exit0(d,val) flags.exit0 = eval(val,d) end
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
  --@D lock=<bool> - If true state use mutex for QA I/O, ex. --%%lock=true
  function directive.lock(d,val) flags.lock = eval(val,d) end
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
  
  local truncCode = info.src
  local eod = info.src:find("ENDOFDIRECTIVES")
  if eod then truncCode = info.src:sub(1,eod-1) end
  --local truncCode = info.src:match("(.-)ENDOFDIRECTIVES%-%-") or info.src
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
  local t0 = socket.gettime()
  if url:starts("https") then r,status,h = copas.https.request(req)
  else r,status,h = copas.http.request(req) end
  local t1 = socket.gettime()
  self:DEBUGF('http',"HTTP %s %s %s (%.3fs)",method,url,status,t1-t0)
  if tonumber(status) and status < 300 then
    return resp[1] and table.concat(resp) or nil, status, h
  else
    return nil, status, h, resp
  end
end

local BLOCK = false 
function Emulator:HC3Call(method,path,data,silent)
  --print(path)
  if BLOCK then self:ERRORF("HC3 authentication failed again, Emu access cancelled") return nil, 401, "Blocked" end
  if type(data) == 'table' then data = json.encode(data) end
  assert(self.URL,"Missing hc3emu.URL")
  assert(self.USER,"Missing hc3emu.USER")
  assert(self.PASSWORD,"Missing hc3emu.PASSWORD")
  local res,stat,headers = self:httpRequest(method,self.URL.."api"..path,{
    ["Accept"] = '*/*',
    ["X-Fibaro-Version"] = 2,
    ["Fibaro-User-PIN"] = self.PIN,
  },
  data,35000,self.USER,self.PASSWORD)
  if stat == 401 then self:ERRORF("HC3 authentication failed, Emu access cancelled") BLOCKED = true end
  if stat == 'closed' then self:ERRORF("HC3 connection closed %s",path) end
  if stat == 500 then self:ERRORF("HC3 error 500 %s",path) end
  if stat and stat >= 400 then return nil,stat end
  local jf,data = pcall(json.decode,res)
  return (jf and data or res),stat
end

function Emulator:apiget(...) return self.connection:call("GET",...) end
function Emulator:apipost(...) return self.connection:call("POST",...) end
function Emulator:apiput(...) return self.connection:call("PUT",...) end
function Emulator:apidelete(...) return self.connection:call("DELETE",...) end

local coroMetaData = setmetatable({},{__mode = "k"}) -- Use to associate QA/Scene environment with coroutines
function Emulator:getCoroData(co,key,silent) 
  local coro = co or coroutine.running()
  local data = (coroMetaData[coro] or {})[key] 
  assert(silent or data~=nil,"Coro data not found: "..tostring(key).." "..tostring(coro))
  return data
end
function Emulator:setCoroData(co,key,val)
  co = co or coroutine.running()
  local md = coroMetaData[co] or {}
  coroMetaData[co] = md
  md[key] = val
  return val
end
function Emulator:getRunner(co,silent) return self:getCoroData(co,'runner',silent) end
function Emulator:setRunner(runner,co)
  local oldRunner = self:getRunner(co,true)
  self:setCoroData(co,'runner',runner) 
  return oldRunner
end

function Emulator:loadfile(path,env) -- Loads a file into specific environment
  path = package.searchpath(path,package.path)
  return loadfile(path,"t",env)()
end

function Emulator:run(info) -- { fname = "file.lua", src = "source code" } 
  self:DEBUGF('info',"Main QA file %s",info.fname)
  self.mainFile = info.fname
  info.src = info.src:gsub("#!/usr/bin/env","--#!/usr/bin/env") 
  info.env = {}
  if not info.directives then self:parseDirectives(info) end
  local flags = info.directives
  for _,globalFlag in ipairs({'offline','state','logColor','stateReadOnly','dark','longitude','latitude','lock'}) do
    if flags[globalFlag]~=nil then self.DBG[globalFlag] = flags[globalFlag] end
  end
  
  self.USER = (flags.creds or {}).user or self.USER            -- Get credentials (again), if changed
  self.PASSWORD = (flags.creds or {}).password or self.PASSWORD
  self.URL = (flags.creds or {}).url or self.URL
  self.PIN = (flags.creds or {}).pin or self.PIN
  
  print(self.log.colorStr('orange',"HC3Emu - Tiny QuickApp emulator for the Fibaro Home Center 3, v"..self.VERSION))
  local fileType = flags.type == 'scene' and 'Scene' or 'QuickApp'
  
  copas(function() -- This is the first task we create
    self.mobdebug.on()
    self:setRunner(self.systemRunner) -- Set environment for this coroutine 
    self.timers.midnightLoop() -- Setup loop for midnight events, used to ex. update sunrise/sunset hour
    local runner = fileType == 'Scene' and self.scene.Scene(info) or self.qa.QA(info,nil)
    self:post({type='emulator_started'},true)
    runner:run()
  end)
end

function Emulator:getTimers() return self.timers.getTimers() end

function Runner:__init(kind)
  self.kind = kind.."Runner"
  self.name = "0"
end
function Runner:lock() end -- Nop
function Runner:unlock() end -- Nop
function Runner:printErr(date,str) _print(date,str) end
function Runner:trimErr(str) return str:gsub("%[string \"", "[file \"") or str end
function Runner:__tostring(r) return fmt("%s:%s",self.kind,self.name) end

local function round(num) return math.floor(num + 0.5) end
function Runner:timerCallback(ref,what)
  if not self.flags.debug.timer then return end
  if ref.tag == 'runSentry' then return end
  if what == 'start' then
    local info = debug.getinfo(5 + (ref.ctx=='setInterval' and 1 or 0))
    local line = info.currentline
    ref.src = ref.src or string.format("%s:%s",info.source,line)
    local t = userDate("%m.%d/%H:%M:%S",round(ref.time))
    Emulator.emulator:DEBUG("%s:%s %s %s",ref.ctx,ref.tag or ref.id,t,ref.src)
  elseif what == 'expire' then
    Emulator.emulator:DEBUG("%s:%s expired",ref.ctx,ref.tag or ref.id)
  elseif what == 'cancel' then
    Emulator.emulator:DEBUG("%s:%s canceled",ref.ctx,ref.tag or ref.id)
  end
end

SystemRunner = SystemRunner
class 'SystemRunner'(Runner)


function SystemRunner:__init()
  Runner.__init(self,"System")
  self.name = "main"
  self.dbg = {}
end

function SystemRunner:_error(str)
  _print(dateMark('SYSERR'),self:trimErr(str))
end

return Emulator
