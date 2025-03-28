local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local json = require("hc3emu.json")
local class = require("hc3emu.class") -- use simple class implementation
local copas = require("copas")
local userTime,userDate,urlencode

local function init()
  userTime,userDate = E.timers.userTime,E.timers.userDate
  urlencode = E.util.urlencode
end
Runner = Runner 

class 'QA'(Runner)
local QA = _G['QA']; _G['QA'] = nil

function QA:__init(info,noRun)
  Runner.__init(self,"QA")
  self.info = info
  self.propWatches = {}
  self:createQAstruct(info,noRun)
  self._lock = E:newLock()
  return self
end

function QA:lock() self._lock:get() end
function QA:unlock() self._lock:release() end

function QA:createQAstruct(info,noRun) -- noRun -> Ignore proxy
  if info.directives == nil then E:parseDirectives(info) end
  self.fname = info.fname
  self.src = info.src
  self.files = info.files
  self.directives = info.directives
  self.dbg = info.directives.debug or {}
  self.env = info.env
  local flags = info.directives
  local env = info.env
  local qvs = json.util.InitArray(flags.var or {})
  self.timerCount = 0
  
  local uiCallbacks,viewLayout,uiView
  if flags.u and #flags.u > 0 then
    uiCallbacks,viewLayout,uiView = E.ui.compileUI(flags.u)
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
  
  if flags.id == nil then flags.id = self:nextId() end
  ---@diagnostic disable-next-line: undefined-field
  local ifs = table.copy(flags.interfaces or {})
  ---@diagnostic disable-next-line: undefined-field
  if not table.member(ifs,"quickApp") then ifs[#ifs+1] = "quickApp" end
  local deviceStruct = {
    id=tonumber(flags.id),
    type=flags.type or 'com.fibaro.binarySwitch',
    name=flags.name or 'MyQA',
    roomID = 219,
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
    E:DEBUG("Offline mode, proxy directive ignored")
  end
  
  if flags.proxy and not noRun then
    local pname = tostring(flags.proxy)
    local pop = pname:sub(1,1)
    if pop == '-' or pop == '+' then -- delete proxy if name is preceeded with "-" or "+"
      pname = pname:sub(2)
      flags.proxy = pname
      local qa = E:apiget("/devices?name="..urlencode(pname))
      assert(type(qa)=='table')
      for _,d in ipairs(qa) do
        E:apidelete("/devices/"..d.id)
        E:DEBUGF('info',"Proxy device %s deleted",d.id)
      end
      if pop== '-' then flags.proxy = false end -- If '+' go on and generate a new Proxy
    end
    if flags.proxy then
      deviceStruct = E.proxy.getProxy(flags.proxy,deviceStruct) -- Get deviceStruct from HC3 proxy
      assert(deviceStruct, "Can't get proxy device")
      local id,name = deviceStruct.id,deviceStruct.name
      info.env.__TAG = (name..(id or "")):upper()
      E:apipost("/plugins/updateProperty",{deviceId=id,propertyName='quickAppVariables',value=qvs})
      if flags.logUI then E.ui.logUI(id) end
      E.proxy.startServer(id)
      E:apipost("/devices/"..id.."/action/CONNECT",{args={{ip=E.emuIP,port=E.emuPort}}})
      info.isProxy = true
    end
  end

  -- info.device = deviceStruct
  -- info.id = deviceStruct.id
  env.plugin = env.plugin or {}
  env.plugin._dev = deviceStruct
  env.plugin.mainDeviceId = deviceStruct.id -- Now we have a deviceId
  self.name = deviceStruct.name
  self.device = deviceStruct
  self.isProxy = deviceStruct.isProxy
  self.id = deviceStruct.id
  E:registerQA(self)

  if flags.u == nil then flags.u = {} end
  self.UI = flags.u

  E:post({type='quickApp_registered',id=self.id})

  return self
end

function QA:loadQAFiles()
  local flags = self.directives
  self.flags = flags
  if self.directives == nil then error("QA directive nil") end
  if flags.startTime then 
    local t = E.timers.parseTime(flags.startTime)
    E.timers.setTime(t) 
  end
  local userTime,userDate = E.timers.userTime,E.timers.userDate

  local env = self.env
  local os2 = { time = userTime, clock = os.clock, difftime = os.difftime, date = userDate, exit = os.exit, remove = os.remove, require = require }
  local fibaro = { hc3emu = E, HC3EMU_VERSION = E.VERSION, flags = flags, DBG = E.DBG }
  local args = nil
  if flags.shellscript then
    args = {}
    for i,v in pairs(arg) do if i > 0 then args[#args+1] = v end end
  end
  for k,v in pairs({
    __assert_type = __assert_type, fibaro = fibaro, json = json, urlencode = E.util.urlencode, args=args,
    collectgarbage = collectgarbage, os = os2, math = math, string = string, table = table, _print = print,
    getmetatable = getmetatable, setmetatable = setmetatable, tonumber = tonumber, tostring = tostring,
    type = E.luaType, pairs = pairs, ipairs = ipairs, next = next, select = select, unpack = table.unpack,
    error = error, assert = assert, pcall = pcall, xpcall = xpcall, bit32 = require("bit32"),
    rawset = rawset, rawget = rawget,
  }) do env[k] = v end
  env._error = function(str) env.fibaro.error(env.__TAG,str) end
  env.__TAG = self.name..self.id
  env._G = env
  for k,v in pairs(E.exports) do env[k] = v end
  
  for _,path in ipairs({"hc3emu.fibaro","hc3emu.class","hc3emu.quickapp","hc3emu.net"}) do
    E:DEBUGF('files',"Loading QA library %s",path)
    E:loadfile(path,env)
  end
  
  function env.print(...) env.fibaro.debug(env.__TAG,...) end
  
  for _,lf in ipairs(self.files) do
    E:DEBUGF('files',"Loading user file %s",lf.fname)
    if lf.content then
      load(lf.content,lf.fname,"t",env)()
    else
      local stat,res = pcall(function()
        _,lf.content = E.util.readFile{file=lf.fname,eval=true,env=env,silent=false}
      end)
      if not stat then
        error(string.format("Error loading included user --%%%%file=%s: %s", lf.fname, res))
      end 
    end
  end
  E:DEBUGF('files',"Loading user main file %s",self.fname)
  local f,err = load(self.src,self.fname,"t",env)
  if not f then error(err) end
  f()
  E:post({type='quickApp_loaded',id=self.id})
  if not flags.offline then 
    assert(E.URL and E.USER and E.PASSWORD,"Please define URL, USER, and PASSWORD in config file") -- Early check that creds are available
  end
end

function QA:nextId() return E:getNextDeviceId() end

function QA:saveProject()
  local r = {}
  for _,f in ipairs(self.files) do
    r[f.name] = f.fname
  end
  r.main = self.fname
  local f = io.open(".project","w")
  assert(f,"Can't open file "..".project")
  f:write(json.encodeFormated({files=r,id=self.directives.project}))
  f:close()
end

function QA:run() -- run QA:  create QA struct, load QA files. Runs in a copas task.
  E.mobdebug.on()
  local env = self.env
  E:addThread(self,function()
    E:setRunner(self)
    local flags = self.directives or {}
    env.__debugFlags = flags.debug or {}
    local firstLine,onInitLine = E.tools.findFirstLine(self.src)
    if flags.breakOnLoad and firstLine then E.mobdebug.setbreakpoint(self.fname,firstLine) end
    self:loadQAFiles()
    if flags.save then E.tools.saveQA(self.id) end
    if flags.project then self:saveProject() end
    if env.QuickApp.onInit then
      if flags.breakOnInit and onInitLine then E.mobdebug.setbreakpoint(self.fname,onInitLine+1) end
      E:DEBUGF('info',"Starting QuickApp '%s'",self.name)
      env.setTimeout(function() end,0,"runSentry")
      env.quickApp = env.QuickApp(self.device) -- quickApp defined first when we return from :onInit()...
      E:post({type='quickApp_started',id=self.id})
      if flags.speed then E.timers.startSpeedTime(flags.speed) end
    end
  end)
  return self
end

function QA:restart(delay) -- delay in ms
  E.timers.cancelTimers(self) 
  E.util.cancelThreads(self)
  self.env.setTimeout(function() self:run() end,delay or 0)
end

function QA:callAction(name,...)
  assert(self.qa,"QA not running")
  local args = {...}
  E:addThread(self,function() self.qa:callAction(name,table.unpack(args)) end)
  copas.sleep(0.01) -- Give called QA a chance to run
end

function QA:onAction(deviceId,value)
  E:addThread(self,self.env.onAction,deviceId,value)
  copas.sleep(0.01) -- Give called QA a chance to run
end

function QA:watchesProperty(name,value)
  if self.propWatches[name] then self.propWatches[name](value) end
end

local UIMap={onReleased='value',onChanged='value',onToggled='value',onLongPressDown='value',onLongPressReleased='value'}
function QA:onUIEvent(deviceId,value)
  E:addThread(self,self.env.onUIEvent,deviceId,value)
  local componentName = value.elementName
  local propertyName = UIMap[value.eventType]
  local value2 = value.values
  if propertyName == 'text' then value2 = value2[1] end
  self:updateView({componentName=componentName,propertyName=propertyName,newValue=value2})
  copas.sleep(0.01) -- Give called QA a chance to run
end

local stocks = require("hc3emu.stocks")
local stockUIs = stocks.stockUIs
local stockProps = stocks.stockProps

local function addStockUI(typ,UI)
  local stock = stockUIs[typ]
  if not stock then return end
  for i,r in ipairs(stock) do table.insert(UI,i,r) end
end

local function getElmType(e) return e.button and 'button' or e.label and 'label' or e.slider and 'slider' or e.switch and 'switch' or e.select and 'select' or e.multi and 'multi' end

-- add type='button' or 'label' or 'slider' or 'switch' or 'select' or 'multi' to UI elements
-- creates metatable index for UI elements (typed on identifier)
local function initializeUI(QA,UI,index)
  if type(UI) ~= 'table' then return end
  local typ = getElmType(UI)
  if not typ then for _,r in ipairs(UI) do initializeUI(QA,r,index) end return end
  UI.type = typ
  local componentName = UI[typ]
  if index[componentName] then
    E:DEBUGF('warn',"Duplicate UI element %s in %s",componentName,QA.name)
  end
  index[componentName] = UI
  if componentName then -- Also primes the UI element with default values, in paricular from stock UI elements
    local sval = stockProps[componentName] and stockProps[componentName](QA) or nil
    if UI.label then UI.text = sval or UI.text end
    if UI.button then UI.text = UI.text end
    if UI.slider then 
      UI.value = sval or UI.value 
    end
    if UI.switch then UI.value = UI.value end
    if UI.select then 
      UI.value = UI.values 
      UI.options = UI.options or {}
    end
    if UI.multi then 
      UI.value = UI.values 
      UI.options = UI.options or {}
    end
  end
end


function E.EVENT._quickApp_initialized(ev)
  local qa = E:getQA(ev.id)
  if qa.flags.uiPage then
    qa.uiPage = qa.flags.uiPage
    if qa.isChild then
      local m,e = qa.uiPage:match("(.-)(%.[hHtTmMlL]+)$")
      qa.uiPage = m.."_child_"..qa.id..e
    end
    addStockUI(qa.device.type,qa.UI)
    local index = {}
    initializeUI(qa,qa.UI,index)
    setmetatable(qa.UI,{
      __index=function(t,k) if index[k] then return index[k] else return rawget(t,k) end end,
    })
    E.webserver.generateUIpage(qa.id,qa.name,qa.uiPage,qa.UI)
    return
  end
end

local compMap = {
  text = function(v) return v end,
  value = function(v) if type(v)=='table' then return v[1] else return v end end,
  options = function(v) return v end,
  selectedItem = function(v) return v end,
  selectedItems = function(v) return v end
}
function QA:updateView(data)
  local UI = self.UI
  local componentName = data.componentName
  local propertyName = data.propertyName
  local value = data.newValue
  local elm = UI[componentName]
  if not elm then return end
  if compMap[propertyName] then value = compMap[propertyName](value) end
  if value ~= elm[propertyName] then 
    elm[propertyName] = value 
    E:post({type='quickApp_updateView',id=self.id})
  end
end

function QA:remove()
  E.timers.cancelTimers(self) 
  E.util.cancelThreads(self)
  E:unregisterQA(self.id)
end

function QA:createFQA() -- Creates FQA structure from installed QA
  local dev = self.device
  local files = {}
  local suffix = ""
  for _,f in ipairs(self.files) do
    if f.content == nil then f.content = E.util.readFile(f.fname) end
    if f.name == "main" then suffix = "99" end -- User has main file already... rename ours to main99
    files[#files+1] = {name=f.name, isMain=false, isOpen=false, type='lua', content=f.content}
  end
  files[#files+1] = {name="main"..suffix, isMain=true, isOpen=false, type='lua', content=self.src}
  local initProps = {}
  local savedProps = {
    "uiCallbacks","quickAppVariables","uiView","viewLayout","apiVersion","useEmbededView",
    "manufacturer","useUiView","model","buildNumber","supportedDeviceRoles",
    "userDescription","typeTemplateInitialized","quickAppUuid","deviceRole"
  }
  for _,k in ipairs(savedProps) do initProps[k]=dev.properties[k] end
  return {
    apiVersion = "1.3",
    name = dev.name,
    type = dev.type,
    initialProperties = initProps,
    initialInterfaces = dev.interfaces,
    files = files
  }
end

function QA:timerCallback(ref,what)
  Runner.timerCallback(self,ref,what)
  if what == 'start' then self.timerCount = self.timerCount + 1 else self.timerCount = self.timerCount - 1 end
  --print("Timer count:",self.timerCount,ref.id,what,self.name)
  if self.timerCount == 0 then
    E:post({type='quickApp_finished',id=self.id})
    if self.flags.exit then os.exit() end
  end
end

function QA:_error(str)
  self.env.fibaro.error(self.env.__TAG,self:trimErr(str))
end

class 'QAChild' -- Just a placeholder for child QA, NOT a runner, only mother QA is runner
local QAChild = _G['QAChild']; _G['QAChild'] = nil

function QAChild:__init(info)
  self.info = info
  self.id = info.id
  self.env = info.env
  self.device = info.device
  self.name = info.device.name or ("Child_"..self.id)
  self.UI = {}
  local parentQA = E:getQA(self.device.parentId)
  self.isProxy = parentQA.isProxy
  self.flags = parentQA.flags
  self.isChild = true
  self.propWatches = {}
  E:registerQA(self)
  return self
end

function QAChild:watchesProperty(name,value)
  if self.propWatches[name] then self.propWatches[name](value) end
end

function QAChild:updateView(data)
  local UI = self.UI
  local componentName = data.componentName
  local propertyName = data.propertyName
  local value = data.newValue
  local elm = UI[componentName]
  if not elm then return end
  if compMap[propertyName] then value = compMap[propertyName](value) end
  if value ~= elm[propertyName] then 
    elm[propertyName] = value 
    E:post({type='quickApp_updateView',id=self.id})
  end
end

function QAChild:run() error("Child can not be installed in emulator - create child from main QA") end
function QAChild:createFQA() error("Child can not be converted to .fqa") end
function QAChild:save() error("Child can not be saved") end

exports.QA = QA
exports.QAChild = QAChild
exports.stockUIs = stockUIs
exports.stockProps = stockProps
exports.init = init

return exports