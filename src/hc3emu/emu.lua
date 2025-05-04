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
local VERSION = "1.0.94"
local lclass = require("hc3emu.class") -- use simple class implementation

local fmt = string.format

local socket = require("socket")
local ltn12 = require("ltn12")
local copas = require("copas")
copas.https = require("ssl.https")
require("copas.timer")
require("copas.http")

local _print = print
local json = require("hc3emu.json")

Emulator = lclass('Emulator') -- Main class 'Emulator'
Runner = lclass('Runner')   -- Base class for stuff that runs in the emulator, QuickApps, Scenes, System tasks
local SystemRunner

local logTime = os.time
local userDate = os.date
local dateMark = function(str) return os.date("[%d.%m.%Y][%H:%M:%S][",logTime())..str.."]" end

--[[ Emulator events
  {type='emulator_started'}             -- when emulator is initialized
  {type='quickApp_registered',id=qaId}  -- when a quickApp is registered in emulator but not started
  {type='quickApp_loaded',id=qaId}      -- when a quickApp files are loaded
  {type='quickApp_initialized',id=qaId} -- before :onInit, QuickApp instance created
  {type='quickApp_started',id=qaId}     -- after :onInit
  {type='quickApp_finished',id=qaId}    -- no timers left
  {type='scene_registered',id=sceneId}
  {type='time_changed'}
  {type='midnight'}
--]]
Emulator = Emulator -- fool linting...
function Emulator:__init(debug,info)
  Emulator.emulator = self
  self.VERSION = VERSION
  self.cfgFileName = "hc3emu.json"   -- Config file in current directory
  self.homeCfgFileName = ".hc3emu.json"  -- Config file in home directory
  
  local win = (os.getenv('WINDIR') or (os.getenv('OS') or ''):match('[Ww]indows')) and not (os.getenv('OSTYPE') or ''):match('cygwin') -- exclude cygwin
  self.fileSeparator = win and '\\' or '/'
  self.tempDir = os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp/" -- temp directory
  self.homeDir = os.getenv("HOME") or os.getenv("homepath") or ""
  -- Try to guess in what environment we are running (used for loading extra console colors)
  self.isVscode = package.path:lower():match("vscode") ~= nil
  self.isZerobrane = package.path:lower():match("zerobrane") ~= nil
  
  self.util = require("hc3emu.util") -- Utility functions
  self.util.emulator = self
  self.EVENT = self.util.EVENT
  self.post = function(_,...) return self.util.post(...) end
  self.addThread = function(_,...) return self.util.addThread(...) end
  
  self.stats = { qas = 0, scenes = 0, timers = 0, ports = {} }

  self.DEVICEID = 5000 -- Start id for QA devices
  self.SCENEID = 7000 -- Start id for Scene devices
  self.QA_DIR={} -- Directory for all QAs - devicesId -> QA object
  self.SCENE_DIR={} -- Directory for all Scenes - sceneId -> Scene object

  self.emuPort = 8264   -- Port for HC3 proxy to connect to
  self.emuIP = nil      -- IP of host running the emulator
  self.DBG = {} -- Default flags and debug settings
  self.exports = {} -- functions to export to QA
  self.RunnerClass = Runner
  self.json = json -- Used by some lua libraries...
  
  -- Determine the IP address of the emulator
  do
    local someRandomIP = "192.168.1.122" --This address you make up
    local someRandomPort = "3102" --This port you make up
    local mySocket = socket.udp() --Create a UDP socket like normal
    mySocket:setpeername(someRandomIP,someRandomPort)
    local myDevicesIpAddress,_ = mySocket:getsockname()-- returns IP and Port
    self.emuIP = myDevicesIpAddress == "0.0.0.0" and "127.0.0.1" or myDevicesIpAddress
  end
  
  function print(...) if self.silent then return else _print(...) end end
  
  -- Attempt to hide type function for debuggers...
  -- We need to recognize our class objects as 'userdata' (table with __USERDATA key)
  local luaTypeCode = [[return function(obj) local t = type(obj) local r = t == 'table' and rawget(obj,'__USERDATA') and 'userdata' or t return r end]]
  local luaType,_ = load(luaTypeCode,nil,"t",{type=type,rawget=rawget})()
  self.luaType = luaType
  
  self.lua = {os = os, require = require, dofile = dofile, loadfile = loadfile, type = type, io = io, print = _print, package = package } -- used from fibaro.hc3emu.lua.x 

  self.silent = debug.silent
  self.nodebug = debug.nodebug
  self.DBG = debug
  self.systemRunner = SystemRunner()
  self:setRunner(self.systemRunner)
  self.mainFile = info.fname
  
  self.config = require("hc3emu.config")

  self.baseFlags = self.config.getSettings() or {}
  
  self.mobdebug = { on = function() end, start = function(_,_) end }
  if not self.nodebug then
    self.mobdebug = require("mobdebug") or self.mobdebug
    self.mobdebug.start('localhost',self.DBG.dport or 8172) 
  end

  -- The QA/Scene we invoke the emulator with is the ""main" file
  -- and will set the flags fo some overal settings self.DBG (offline, etc)
  self:parseDirectives(info)

  local flags = info.directives
  for _,globalFlag in ipairs({'offline','state','logColor','stateReadOnly','dark','longitude','latitude','lock'}) do
    if flags[globalFlag]~=nil then self.DBG[globalFlag] = flags[globalFlag] end
  end
  self.systemRunner.dbg = flags.debug or {}

  self.rsrcsDir = self.config.setupRsrscsDir()
  assert(self.rsrcsDir,"Failed to find rsrcs directory")
  self.config.setupDirectory(info.directives.webui)
  self.config.clearDirectory()

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
  self.helper = loadModule("hc3emu.helper") -- Helper functions
  self.API = loadModule("hc3emu.api")
  self.proxy = loadModule("hc3emu.proxy")        -- Proxy creation and Proxy API routes
  self.refreshState = loadModule("hc3emu.refreshstate")
  self.ui = loadModule("hc3emu.ui") 
  self.tools = loadModule("hc3emu.tools")
  self.qa = loadModule("hc3emu.qa") 
  self.scene = loadModule("hc3emu.scene")
  loadModule("hc3emu.simdevices") 
  self.webserver = loadModule("hc3emu.webserver")
  self.webserver.startServer()

  if info.directives.installation then self.config.installation(info.directives.installation) end
end

function Emulator:newLock()
  if self.DBG.lock then return copas.lock.new(math.huge)           -- Lock with no timeout
  else return {get = function() end, release = function() end} end -- Nop lock
end

function Emulator:getNextDeviceId() self.DEVICEID = self.DEVICEID + 1 return self.DEVICEID end
function Emulator:getNextSceneId() self.SCENEID = self.SCENEID + 1 return self.SCENEID end

function Emulator:setupApi()
  self.api = self.API.API({offline=self.DBG.offline})
  local EM = self
  function self.api:loadResources(resources)
    local res = EM.config.loadResource("stdStructs.json",true)
    local resources = EM.api.resources
    resources.resources.home.items = res.home
    resources.resources.settings_info.items = res.info
    resources.resources.settings_location.items = res.location
    resources.resources.devices.items[1] = res.device1
    local defroom = {id = 219, name = "Default Room", sectionID = 219, isDefault = true, visible = true}
    resources.resources.rooms.items[219] = defroom
  end
  function self.api.qa.isEmulated(id) return self.QA_DIR[id]~= nil end
  function self.api.scene.isEmulated(id) return self.SCENE_DIR[id]~= nil end
  self.qa.addApiHooks(self.api)
  self.scene.addApiHooks(self.api)
  self.api:start()
end

function Emulator:setupResources()
  local userTime,userDate = self.timers.userTime,self.timers.userDate
  
  local function updateSunTime()
    local location = self.api.resources:get("settings_location")
    local dev1 =  self.api.resources:get("devices",1)
    local longitude,latitude = location.longitude,location.latitude
    local sunrise,sunset = self.util.sunCalc(userTime(),latitude,longitude)
    self.sunriseHour = sunrise
    self.sunsetHour = sunset
    self.sunsetDate = userDate("%c")
    self:DEBUGF('time',"Suntime updated sunrise:%s, sunset:%s",sunrise,sunset)
    dev1.properties.sunriseHour = sunrise
    dev1.properties.sunsetHour = sunset
  end
    
  function self.EVENT._emulator_started() -- Update lat,long,suntime at startup
    local location = self.api.resources:get("settings_location")
    if self.DBG.latitude and self.DBG.longitude then
      location.latitude = self.DBG.latitude
      location.longitude = self.DBG.longitude
    end
    updateSunTime()
  end
    
  function self.EVENT._midnight() updateSunTime() end -- Update suntime at midnight
  function self.EVENT._time_changed() updateSunTime() end -- Update suntime at time changed
end

function Emulator:readInState()
  local hasState, stateFileName = false, nil
  stateFileName = self.DBG.state
  self.stateData = {[self.mainFile] = {}}
  self.hasState = type(stateFileName)=='string'
  if self.hasState then 
    self.stateFileName = stateFileName
    local f = io.open(stateFileName,"r")
    if f then 
      self:DEBUGF('db',"Reading state file %s",tostring(stateFileName))
      local stat,states = pcall(function() return json.decode(f:read("*a")) end)
      if not stat then states = {} end
      f:close()
      if type(states)~='table' then states = {} end
      self.stateData = states
      local states2 = states[self.mainFile] or {} -- Key on main file
      local qintern = self.api.resources.resources.internalStorage.items
      for id,vars in pairs(states2.internalStorage or {}) do
        qintern[id] = vars
      end
    else
      self:DEBUGF('db',"State file not found %s",tostring(stateFileName))
    end
  end
end

function Emulator:flushState()
  if self.hasState then
    local f = io.open(self.stateFileName,"w")
    if f then
      local states = {internalStorage = self.api.resources.resources.internalStorage.items }
      self.stateData[self.mainFile] = states
      f:write(json.encode(self.stateData)) f:close() 
      self:DEBUGF('db',"State file written %s",self.stateFileName)
    else
      self:DEBUGF('db',"State file write failed %s",self.stateFileName)
    end
  end
end

function Emulator:registerQA(qa) 
  assert(qa.id,"Can't register QA without id")
  if not self.QA_DIR[qa.id] then
    self.stats.qas = self.stats.qas + 1
  end
  self.QA_DIR[qa.id] = qa 
  self.api.resources.resources.devices.items[qa.id] = qa.device
end

function Emulator:unregisterQA(id) 
  self.QA_DIR[id] = nil 
  self.api.resources:delete("devices",id,true,true)
  self.stats.qas = self.stats.qas - 1
end

function Emulator:registerScene(scene) 
  assert(scene.id,"Can't register Scene without id")
  self.SCENE_DIR[scene.id] = scene
  self.stats.scenes = self.stats.scenes + 1
  self.api.resources.resources.scenes.items[scene.id] = scene.device
end

function Emulator:getQA(id) return self.QA_DIR[id] end
function Emulator:getScene(id) return self.SCENE_DIR[id] end

function Emulator:DEBUG(f,...) print(dateMark('SYS').." "..fmt(f,...)) end
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
  local baseFlags = table.copy(self.baseFlags)

  local flags = {
    name='MyQA', type='com.fibaro.binarySwitch', debug={}, logColor = true,
    var = {}, gv = {}, files = {}, u={}, conceal = {}, 
  }
  
  local function eval(str,d,force)
    local stat, res = pcall(function() return load("return " .. str, nil, "t", { config = self.baseFlags })() end)
    if stat then return res end
    if force then return str end
    self:ERRORF("directive '%s' %s",tostring(d),res)
    error()
  end
  
  local directive = {}
  self._directive = directive
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
    if baseFlags.var then v=v..","..baseFlags.var baseFlags.var=nil end
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
    if baseFlags.conceal then v=v..","..baseFlags.conceal baseFlags.conceal=nil end
    local name,expr = v:match("(.-):(.*)")
    assert(name and expr,"Bad conceal directive: "..d) 
    --local e = eval(expr,d)
    if expr then flags.conceal[name] = expr end
    --end
  end
  --@D file=<path>;<name> - Add a file to the QA, ex. --%%file=src/lib.lua;lib
  function directive.file(d,val)
    local function addFile(val) 
      local path,m = val:match("(.-),(.-);?%s*$")
      if not path then path,m = val:match("(.-):(.+);?%s*$") end
      if path:match("%$") then 
        path = package.searchpath(path:sub(2),package.path)
      end
      assert(path and m,"Bad file directive: "..d)
      flags.files[#flags.files+1] = {fname=path,name=m}
    end
    addFile(val)
    if baseFlags.file then
      local fs = baseFlags.file:split(",")
      for _,f in ipairs(fs) do addFile(f:gsub(";",",")) end
      baseFlags.file = nil
    end
  end
  --@D debug=<name>:<expr> - Set debug flag, ex. --%%debug=info:true,http:true,onAction:true,onUIEvent:true
  function directive.debug(d,val)
    if baseFlags.debug then val=val..","..baseFlags.debug baseFlags.debug=nil end
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
  function directive.interfaces(d,val)
    local ifs = self.baseFlags.interfaces
    if ifs then ifs = ifs:split(",") self.baseFlags.interfaces= nil end
    flags.interfaces = eval(val,d)
    for _,i in ipairs(ifs or {}) do
      if not table.member(i,flags.interfaces) then table.insert(flags.interfaces,i) end
    end
  end
  --@D install=<hc3 user>,<hc3 password><uc3 url>
  function directive.install(d,val)
    local user,pass,url = val:match("([^,]+),([^,]+),(.+)")
    flags.installation = {user=user,pass=pass,url=url}
  end
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
  --@D webui=<bool> - If true generates UI webpages in /emu, ex. --%%webui=true
  function directive.webui(d,val) flags.webui = eval(val) end
  --@D plugin=<path> - loads emulator extensions, ex. --%%plugin=$hc3emu.image
  function directive.plugin(d,val)
    local path = val
    if path:match("^%$") then 
      path = package.searchpath(path:sub(2),package.path)
    end
    dofile(path)
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
  
  local ignore = {root=true,remote=true,include=true, port=true}
  if truncCode:sub(-1)~="\n" then truncCode = truncCode.."\n" end
  truncCode:gsub("%-%-%%%%(%w-=.-)%s*\n",function(p)
    local f,v = p:match("(%w-)=(.*)")
    if ignore[f] then return end
    local v1,com = v:match("(.*)%s* %-%- (.*)$") -- remove comments
    if v1 then v = v1 end
    if f:match("^u%d+$") then f="u" end -- backward compatibility
    if directive[f] then
      directive[f](p,v,flags)
    else self:WARNINGF("Unknown directive: %s",tostring(f)) end
  end)
  
  info.directives = table.merge(table.copy(baseFlags),flags)
  info.files = flags.files
end

function Emulator:checkConnection(flags)
  self.USER = flags.user or self.USER -- Get credentials
  self.PASSWORD = flags.password or self.PASSWORD
  self.URL = flags.IP or self.URL
  self.PIN = flags.pin or self.PIN
  if self.URL and self.URL:sub(-1)~="/" then self.URL = self.URL.."/" end
  if not self.DBG.offline then -- Early check if we are connected.
    if not self.URL then 
      self:ERRORF("Missing hc3emu.URL - Please set url to HC3 in config file")
      os.exit(1)
    end
    if not self.URL:match("https?://%w+%.%w+%.%w+%.%w+/") then
      self:ERRORF("Invalid format, hc3emu.URL - Must be http(s)://<ip>/")
      os.exit(1)
    end
    if not self.USER then 
      self:ERRORF("Missing hc3emu.USER - Please set user to HC3 in config file")
      os.exit(1)
    end
    if not self.PASSWORD then 
      self:ERRORF("Missing hc3emu.PASSWORD - Please set password to HC3 in config file")
      os.exit(1)
    end
    local a,b,c = self:HC3Call("GET","/settings/info")
    if not a then
      self:ERRORF("Failed to connect to HC3, please check your config file")
      self:ERRORF("Error: %s",tostring(b))
      self:ERRORF("Please check your network connection and the HC3 IP address")
      os.exit(1)
    end
  end
end

function Emulator:httpRequest(method,url,headers,data,timeout,user,pwd,silent)
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
  if url:starts("https") then
    req.ssl_verify = false
    r,status,h = copas.https.request(req)
  else r,status,h = copas.http.request(req) end
  local t1 = socket.gettime()
  if not silent then self:DEBUGF('http',"HTTP %s %s %s (%.3fs)",method,url,status,t1-t0) end
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
  assert(self.URL,"Missing hc3emu.URL - Please set url to HC3 in config file")
  assert(self.USER,"Missing hc3emu.USER - Please set user of HC3 in config file")
  assert(self.PASSWORD,"Missing hc3emu.PASSWORD - Please set password of HC3 in config file")
  local res,stat,headers = self:httpRequest(method,self.URL.."api"..path,{
    ["Accept"] = '*/*',
    ["X-Fibaro-Version"] = 2,
    ["Fibaro-User-PIN"] = self.PIN,
  },
  data,35000,self.USER,self.PASSWORD,silent)
  if stat == 401 then self:ERRORF("HC3 authentication failed, Emu access cancelled") BLOCKED = true end
  if stat == 'closed' then self:ERRORF("HC3 connection closed %s",path) end
  if stat == 500 then self:ERRORF("HC3 error 500 %s",path) end
  if not tonumber(stat) then return res,stat end
  if stat and stat >= 400 then return nil,stat end
  local jf,data = pcall(json.decode,res)
  return (jf and data or res),stat
end

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
  info.src = info.src:gsub("#!/usr/bin/env","--#!/usr/bin/env") 
  info.env = {}
  local flags = info.directives
  
  print(self.log.colorStr('orange',"HC3Emu - Tiny QuickApp emulator for the Fibaro Home Center 3, v"..self.VERSION))
  local fileType = flags.type == 'scene' and 'Scene' or 'QuickApp'

  copas(function() -- This is the first task we create
    self.mobdebug.on()
    self:setRunner(self.systemRunner) -- Set environment for this coroutine
    self:checkConnection(flags) -- If online, check connection to HC3 or bail-out
    self:setupApi()
    self:setupResources() -- Setup resources for the API
    self:readInState()    -- Read in state from file
    self.timers.midnightLoop() -- Setup loop for midnight events, used to ex. update sunrise/sunset hour
    local runner = fileType == 'Scene' and self.scene.Scene(info) or self.qa.QA(info,nil)
    self:post({type='emulator_started'})
    runner:run()
  end)
end

function Emulator:getTimers() return self.timers.getTimers() end
function Emulator:addEmbedPropWatcher(prop,fun) self.qa.embedProps[prop]=fun end
function Emulator:addEmbedUI(typ,UI) self.qa.embedUIs[typ] = UI end 

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

SystemRunner = lclass('SystemRunner',Runner)

function SystemRunner:__init()
  Runner.__init(self,"System")
  self.name = "main"
  self.dbg = {}
end

function SystemRunner:_error(str)
  _print(dateMark('SYSERR'),self:trimErr(str))
end

return Emulator
