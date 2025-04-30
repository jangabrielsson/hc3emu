local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local json = require("hc3emu.json")
local lclass = require("hc3emu.class") -- use simple class implementation
local copas = require("copas")
local fmt = string.format
local userTime,userDate,urlencode,deviceTypes

local function init()
  userTime,userDate = E.timers.userTime,E.timers.userDate
  urlencode = E.util.urlencode
  deviceTypes = E.config.loadResource("devices.json",true)
end

Runner = Runner 

local QA = lclass('QA',Runner)

function QA:__init(info,noRun) -- create QA struct, 
  Runner.__init(self,"QA")
  self.fname = info.fname
  self.src = info.src
  if info.directives == nil then E:parseDirectives(info) end
  self.files = info.files
  self.directives = info.directives
  self.dbg = info.directives.debug or {}
  self.env = info.env
  
  self.propWatches = {}
  self.timerCount = 0
  self._lock = E:newLock()
  
  local flags = info.directives
  local q5001 = E:getQA(5001)
  local ds = E.api.resources.resources.devices.items[5001]
  local uiCallbacks,viewLayout,uiView = self:setupUI(flags)
  
  local deviceStruct =self:setupStruct(flags,uiCallbacks,viewLayout,uiView)
  
  if flags.offline and flags.proxy then
    flags.proxy = nil
    E:DEBUG("Offline mode, proxy directive ignored")
  end
  
  if flags.proxy and not noRun then 
    deviceStruct = self:setupProxy(flags,info,deviceStruct) 
  end
  
  self.name = deviceStruct.name
  self.device = deviceStruct
  self.isProxy = deviceStruct.isProxy
  self.id = deviceStruct.id -- Now we have a deviceId
  
  E:registerQA(self)
  
  E:post({type='quickApp_registered',id=self.id})
end

function QA:lock() self._lock:get() end
function QA:unlock() self._lock:release() end
function QA:nextId() return E:getNextDeviceId() end

function QA:setupStruct(flags,uiCallbacks,viewLayout,uiView)
  if flags.id == nil then flags.id = self:nextId() end
  local qvs = json.util.InitArray(flags.var or {})
  ---@diagnostic disable-next-line: undefined-field
  local ifs = table.copy(flags.interfaces or {})
  ---@diagnostic disable-next-line: undefined-field
  if not table.member(ifs,"quickApp") then ifs[#ifs+1] = "quickApp" end
  flags.type = flags.type or "com.fibaro.binarySwitch"
  local deviceStruct = table.copy(deviceTypes[flags.type])
  assert(deviceStruct,"Device type "..flags.type.." not found")
  deviceStruct.id=tonumber(flags.id)
  deviceStruct.type=flags.type
  deviceStruct.name=flags.name or 'MyQA'
  deviceStruct.roomID = 219
  deviceStruct.enabled = true
  deviceStruct.visible = true
  deviceStruct.properties = {}
  deviceStruct.properties.apiVersion = "1.3"
  deviceStruct.properties.quickAppVariables = qvs
  deviceStruct.properties.uiCallbacks = uiCallbacks
  deviceStruct.properties.useUiView = false
  deviceStruct.properties.viewLayout = viewLayout
  deviceStruct.properties.uiView = uiView
  deviceStruct.properties.typeTemplateInitialized = true 
  deviceStruct.useUiView = false
  deviceStruct.interfaces = ifs
  deviceStruct.created = os.time()
  deviceStruct.modified = os.time()
  for k,p in pairs({
    model="model",uid="quickAppUuid",manufacturer="manufacturer",
    role="deviceRole",description="userDescription"
  }) do deviceStruct.properties[p] = flags[k] end
  return deviceStruct
end

function QA:setupProxy(flags,info,deviceStruct)
  -- Find or create proxy
  local pname = tostring(flags.proxy)
  local pop = pname:sub(1,1)
  if pop == '-' or pop == '+' then -- delete proxy if name is preceeded with "-" or "+"
    pname = pname:sub(2)
    flags.proxy = pname
    local qa = E.api.hc3.get("/devices?name="..urlencode(pname))
    assert(type(qa)=='table')
    for _,d in ipairs(qa) do
      E.api.hc3.delete("/devices/"..d.id)
      E:DEBUGF('info',"Proxy device %s deleted",d.id)
    end
    if pop== '-' then flags.proxy = false end -- If '+' go on and generate a new Proxy
  end
  if flags.proxy then
    deviceStruct = E.proxy.getProxy(flags.proxy,deviceStruct) -- Get deviceStruct from HC3 proxy
    assert(deviceStruct, "Can't get proxy device")
    local id,name = deviceStruct.id,deviceStruct.name
    info.env.__TAG = (name..(id or "")):upper()
    E.api.hc3.post("/plugins/updateProperty",{
      deviceId=id,
      propertyName='quickAppVariables',
      value=deviceStruct.properties.quickAppVariables
    })
    if flags.logUI then E.ui.logUI(id) end
    E.proxy.start()
    E.api.hc3.post("/devices/"..id.."/action/CONNECT",{args={{ip=E.emuIP,port=E.emuPort}}})
    info.isProxy = true
  end
  return deviceStruct
end

function QA:setupUI(flags)
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
  if flags.u == nil then flags.u = {} end
  self.UI = flags.u
  return uiCallbacks,viewLayout,uiView
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

function QA:saveProject() -- Save project to .project file
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

function QA:setupEnv()
  local env,flags = self.env,self.directives or {}
  env.__debugFlags = flags.debug or {}
  env.__TAG = (self.name..(self.id or "")):upper()
  env.plugin = env.plugin or {}
  env.plugin._dev = self.device
  env.plugin.mainDeviceId = self.id 
end

function QA:run() -- run QA:  load QA files. Runs in a copas task.
  E.mobdebug.on()
  local env,flags = self.env,self.directives or {}
  E:addThread(self,function()
    E:setRunner(self)
    local firstLine,onInitLine = E.tools.findFirstLine(self.src)
    if flags.breakOnLoad and firstLine then E.mobdebug.setbreakpoint(self.fname,firstLine) end
    self:setupEnv()
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

local embeds = require("hc3emu.embedui")
local embedUIs = embeds.embedUIs
local embedProps = embeds.embedProps

local function addEmbedUI(typ,UI)
  local embed = embedUIs[typ]
  if not embed then return end
  for i,r in ipairs(embed) do table.insert(UI,i,r) end
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
  if componentName then -- Also primes the UI element with default values, in paricular from embedded UI elements
    local sval = embedProps[componentName] and embedProps[componentName](QA) or nil
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
  E.refreshState.post.DeviceCreatedEvent(ev.id)
  if (qa.directives or qa.flags).webui then
    qa.webui = true
    if qa.isChild then
      local name = (qa.device.name or "Child"):gsub("[^%w]","")
      qa.uiPage = fmt("%s_%s.html",name,qa.id)
    else
      local name = qa.device.name:gsub("[^%w]","")
      qa.uiPage = fmt("%s.html",name)
    end
    addEmbedUI(qa.device.type,qa.UI)
    local index = {}
    initializeUI(qa,qa.UI,index)
    setmetatable(qa.UI,{
      __index=function(t,k) if index[k] then return index[k] else return rawget(t,k) end end,
    })
    E.webserver.generateUIpage(qa.id,qa.name,qa.uiPage,qa.UI)
    E.webserver.generateEmuPage()
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
  if self.isProxy then 
    local a,b = E.api.hc3.post("/plugins/updateView",data)
    a=b
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
    if self.flags.exit then
      E.webserver.updateEmuPage()
      os.exit() 
    end
  end
end

function QA:_error(str)
  self.env.fibaro.error(self.env.__TAG,self:trimErr(str))
end

local QAChild = lclass('QAChild') --  Just a placeholder for child QA, NOT a runner, only mother QA is runner

function QAChild:__init(info)
  self.id = info.id
  self.env = info.env
  self.device = info.device
  self.name = info.device.name or ("Child_"..self.id)
  if self.device.properties.uiView then
    self.UI = E.ui.uiView2UI(self.device.properties.uiView,self.device.properties.uiCallbacks or {})
  else self.UI = {} end
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

----------------------
local function findFile(name,files)
  for i,f in ipairs(files) do if f.name == name then return i end end
end

local function addApiHooks(api)
  local function notImpl() error("QA func not implemented",2) end
  
  function api.qa.call(id,action,data)  
    local qa = E:getQA(id)
    if qa.device.parentId and qa.device.parentId > 0 then
      qa = E:getQA(qa.device.parentId)
      assert(qa,"Parent QA not found")
    end
    qa:onAction(id,{actionName=action,deviceId=id, args=data.args})
    return 'OK',200
  end
  
  local props = {"name","visible","enabled","roomID"}
  function api.qa.update(id,data) -- Change toplevel props like name....
    local qa = E:getQA(id)
    local QA = qa.qa  
    for _,k in ipairs(props) do if data[k]~=nil then QA[k] = data[k] end end
    qa.env.plugin.restart(0)
    return true,200
  end 
  
  function api.qa.prop(id,prop,value) 
    local qa = E:getQA(id)
    qa.device.properties[prop] = value
    qa:watchesProperty(prop,value)
    return 'OK',200
  end

  function api.qa.getFile(id,name)
    local qa = E:getQA(tonumber(id))
    if not qa then return nil,301 end
    if name == nil then
      local fs = {}
      for _,f in ipairs(qa.files) do
        fs[#fs+1] = {name=f.name, type='lua', isOpen=false, isMain=false}
      end
      fs[#fs+1] = {name='main', type='lua', isOpen=false, isMain=true}
      return fs,200
    else
      local i = findFile(name,qa.files)
      if i then return qa.files[i],200
      else return nil,404 end
    end
  end
  
  function api.qa.writeFile(id,name,data) 
    local qa = E:getQA(tonumber(id))
    if not qa then return nil,301 end
    local files = data
    if name then files = {data} end
    for _,f in ipairs(files) do
      local i = f.name=='main' or findFile(f.name,qa.files)
      if not i then return nil,404 end
    end
    for _,f in ipairs(files) do
      if f.name == 'main' then
        qa.src = f.content
      else
        local i = findFile(f.name,qa.files)
        qa.files[i] = f
      end
    end
    qa.env.plugin.restart(0) -- Restart the QA immediately
    return true,200
  end
  
  function api.qa.createFile(id,data) 
    local qa = E:getQA(id)
    if not qa then return nil,301 end
    if findFile(data.name,qa.files) then return nil,409 end
    data.fname="new" -- What fname to give it?
    table.insert(qa.files,data)
    qa.env.plugin.restart(0) -- Restart the QA
  end
  
  function api.qa.deleteFile(id,name) 
    local qa = E:getQA(id)
    if not qa then return nil,301 end
    local i = findFile(name,qa.files)
    if i then 
      table.remove(qa.files,i) 
      qa.env.plugin.restart(0)
    else return nil,404 end
  end
  
  function api.qa.createFQA(id)
    local qa = E:getQA(id)
    return qa:createFQA(id),200 
   end
  
  function api.qa.updateView(id,data)
    local qa = E:getQA(tonumber(data.deviceId))
    qa:updateView(data)
    return nil,200
  end
  
  function api.qa.restart(id) 
    local qa = E:getQA(id)
    qa.env.plugin.restart(0) -- Restart the QA
  end
  
  function api.qa.createChildDevice(parentId,data)
    local qa = E:getQA(parentId)
    local dev,code = nil,nil
    if qa.isProxy and not E.api.offline then
      dev,code = E.api.hc3.post("/plugins/createChildDevice",data)
      if code > 206 then return nil,code end
    else
      dev = table.copy(deviceTypes[data.type])
      assert(dev,"Device type "..data.type.." not found")
      dev.id = E:getNextDeviceId()
    end
    E.api.resources:create("devices",dev)
    return dev,200
  end
  
  function api.qa.removeChildDevice(id)
    E.api.resources:delete("devices",id)
    return nil,200
  end
  
  function api.qa.debugMessages(id,data) notImpl() end
end

exports.QA = QA
exports.QAChild = QAChild
exports.embedUIs = embedUIs
exports.embedProps = embedProps
exports.addApiHooks = addApiHooks
exports.init = init

return exports