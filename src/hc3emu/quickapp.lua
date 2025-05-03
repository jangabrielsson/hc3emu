local hc3emu = fibaro.hc3emu 
local E = hc3emu
local json = hc3emu.json
local _type = E.lua.type
local copas = E.lua.require("copas")
local fmt = string.format

local function shutdown()
  if E._server then copas.removeserver(E._server) end
  if E._client then copas.close(E._client) end
  E.timers.cancelTimers() 
  E.util.cancelThreads() 
end

plugin = plugin or {}
function plugin.getDevice(deviceId) return api.get("/devices/"..deviceId) end
function plugin.deleteDevice(deviceId) return api.delete("/devices/"..deviceId) end
function plugin.getProperty(deviceId, propertyName) return api.get("/devices/"..deviceId).properties[propertyName] end
function plugin.getChildDevices(deviceId) return api.get("/devices?parentId="..deviceId) end
function plugin.createChildDevice(opts) return api.post("/plugins/createChildDevice", opts) end
function plugin.restart(t)
  t = t or 5000
  local id = plugin.mainDeviceId
  if t == 0 then
    E:DEBUG("Restarting QuickApp "..id)
  else
    E:DEBUG("Restarting QuickApp "..id.." in 5 seconds")
  end
  local qa = E:getQA(id)
  qa:restart(t)
end

local exit = os.exit
function os.exit(code) 
  E:DEBUG("Exit %s",code or 0)
  if code == -1 then shutdown() exit(-1) end -- Hard exit...
  local id = plugin.mainDeviceId
  local qa = E:getQA(id)
  if qa.flags.exit0 then exit(0) end
  plugin.restart()
end

class 'QuickAppBase'

function QuickAppBase:__init(dev)
  if _type(dev) == 'number' then dev = api.get("/devices/" .. dev)
  elseif not _type(dev) == 'table' then error('expected number or table') end
  self.id = dev.id
  self.type = dev.type
  self.name = dev.name
  self.enabled = dev.enabled
  self.parentId = dev.parentId
  self.properties = dev.properties
  self.interfaces = dev.interfaces
  self.uiCallbacks = {}
  self.childDevices = {}
  self.viewCache = {}
  self.isProxy = dev.isProxy
end

function QuickAppBase:debug(...) fibaro.debug(__TAG, ...) end
function QuickAppBase:warning(...) fibaro.warning(__TAG, ...) end
function QuickAppBase:error(...) fibaro.error(__TAG, ...) end
function QuickAppBase:trace(...) fibaro.trace(__TAG, ...) end

function QuickAppBase:updateProperty(name, value, forceUpdate)
  if (type(value)=='table' or self.properties[name] ~= value or forceUpdate == true) then
    self.properties[name] = value
    api.post("/plugins/updateProperty", {
      deviceId= self.id,
      propertyName= name,
      value= value
    })
  end
end

function QuickAppBase:updateView(componentName, propertyName, newValue, forceUpdate)
  api.post("/plugins/updateView",{
    deviceId = self.id,
    componentName = componentName,
    propertyName = propertyName,
    newValue = newValue
  })
end

function QuickAppBase:hasInterface(name) return table.member(name, self.interfaces) end

function QuickAppBase:addInterfaces(values)
  assert(type(values) == "table")
  self:updateInterfaces("add",values)
  for _, v in pairs(values) do
    table.insert(self.interfaces, v)
  end
end

function QuickAppBase:deleteInterfaces(values)
  assert(type(values) == "table")
  self:updateInterfaces("delete", values)
  for _, value in pairs(values) do
    for key, interface in pairs(self.interfaces) do
      if interface == value then
        table.remove(self.interfaces, key)
        break
      end
    end
  end
end

function QuickAppBase:updateInterfaces(action, interfaces)
  api.post("/plugins/interfaces", {action = action, deviceId = self.id, interfaces = interfaces})
end
function QuickAppBase:setName(name) api.put("/devices/"..self.id,{name=name}) end
function QuickAppBase:setEnabled(enabled) api.put("/devices/"..self.id,{enabled=enabled}) end
function QuickAppBase:setVisible(visible) api.put("/devices/"..self.id,{visible=visible}) end

function QuickAppBase:registerUICallback(elm, typ, fun)
  local uic = self.uiCallbacks
  uic[elm] = uic[elm] or {}
  uic[elm][typ] = fun
end

function QuickAppBase:setupUICallbacks()
  local callbacks = (self.properties or {}).uiCallbacks or {}
  for _, elm in pairs(callbacks) do
    self:registerUICallback(elm.name, elm.eventType, elm.callback)
  end
end

QuickAppBase.registerUICallbacks = QuickAppBase.setupUICallbacks

function QuickAppBase:getVariable(name)
  __assert_type(name, 'string')
  for _, v in ipairs(self.properties.quickAppVariables or {}) do if v.name == name then return v.value end end
  return ""
end

local function copy(l)
  local r = {}; for _, i in ipairs(l) do r[#r + 1] = { name = i.name, value = i.value } end
  return r
end
function QuickAppBase:setVariable(name, value)
  __assert_type(name, 'string')
  local vars = copy(self.properties.quickAppVariables or {})
  for _, v in ipairs(vars) do
    if v.name == name then
      v.value = value
      api.post("/plugins/updateProperty", { deviceId = self.id, propertyName = 'quickAppVariables', value = vars })
      self.properties.quickAppVariables = vars
      return
    end
  end
  vars[#vars + 1] = { name = name, value = value }
  api.post("/plugins/updateProperty", { deviceId = self.id, propertyName = 'quickAppVariables', value = vars })
  self.properties.quickAppVariables = vars
end

function QuickAppBase:callAction(name, ...)
  --if name == "" then return end
  if (type(self[name]) == 'function') then return self[name](self, ...)
  else print(fmt("[WARNING] Class does not have '%s' function defined - action ignored",tostring(name))) end
end

function QuickAppBase:internalStorageSet(key, val, hidden)
  __assert_type(key, 'string')
  local data = { name = key, value = val, isHidden = hidden }
  local _, stat = api.put("/plugins/" .. self.id .. "/variables/" .. key, data)
  --print(key,stat)
  if stat > 206 then
    local _, stat = api.post("/plugins/" .. self.id .. "/variables", data)
    --print(key,stat)
    return stat
  end
end

function QuickAppBase:internalStorageGet(key)
  __assert_type(key, 'string')
  if key then
    local res, stat = api.get("/plugins/" .. self.id .. "/variables/" .. key)
    if stat ~= 200 then return nil end
    return res.value
  else
    local res, stat = api.get("/plugins/" .. self.id .. "/variables")
    if stat ~= 200 then return nil end
    local values = {}
    for _, v in pairs(res) do values[v.name] = v.value end
    return values
  end
end

function QuickAppBase:internalStorageRemove(key) return api.delete("/plugins/" .. self.id .. "/variables/" .. key) end

function QuickAppBase:internalStorageClear() return api.delete("/plugins/" .. self.id .. "/variables") end

class 'QuickApp'(QuickAppBase)
function QuickApp:__init(dev)
  QuickAppBase.__init(self,dev)
  __TAG = self.name:upper()..self.id
  plugin._quickApp = self
  self.childDevices = {}

  E:getQA(dev.id).qa = self -- Link QuickApp instance to Emulator QA entry
  E:post({type='quickApp_initialized', id=self.id})

  self:setupUICallbacks()
  if self.onInit then self:onInit() end
  if not self._childsInited then self:initChildDevices() end
end

function QuickApp:createChildDevice(props, deviceClass)
  __assert_type(props, 'table')
  props.parentId = self.id
  props.initialInterfaces = props.initialInterfaces or {}
  if props.initialProperties then json.util.InitArray(props.initialProperties) end
  table.insert(props.initialInterfaces, 'quickAppChild')
  local device, res = api.post("/plugins/createChildDevice", props)
  assert(res == 200 and device, "Can't create child device " .. tostring(res) .. " - " .. json.encode(props))
  deviceClass = deviceClass or QuickAppChild
  local child = deviceClass(device)
  child.parent = self
  self.childDevices[device.id] = child
  return child
end

function QuickApp:removeChildDevice(id)
  __assert_type(id, 'number')
  if self.childDevices[id] then
    api.delete("/plugins/removeChildDevice/" .. id)
    self.childDevices[id] = nil
  end
end

---@diagnostic disable-next-line: duplicate-set-field
function QuickApp:initChildDevices(map)
  map = map or {}
  local children = api.get("/devices?parentId="..self.id)
  -- assert(type(children)=='table',"get children failed")
  local childDevices = self.childDevices
  for _, c in pairs(children) do
    if childDevices[c.id] == nil and map[c.type] then
      childDevices[c.id] = map[c.type](c)
    elseif childDevices[c.id] == nil then
      self:error(fmt("Class for the child device: %s, with type: %s not found. Using base class: QuickAppChild", c.id, c.type))
      childDevices[c.id] = QuickAppChild(c)
    end
---@diagnostic disable-next-line: inject-field
    childDevices[c.id].parent = self
  end
  self._childsInited = true
end

class 'QuickAppChild' (QuickAppBase)
function QuickAppChild:__init(device)
  QuickAppBase.__init(self, device)

  local qaChild = E.qa.QAChild({id=self.id,device=device,env=_G,qa=self})
  qaChild.qa = self
  E:registerQA(qaChild) -- A child device, register it locally
  E:post({type='quickApp_initialized', id=self.id})

  if self.onInit then self:onInit() end
end

function onAction(id,event)
  local quickApp = plugin._quickApp
  if E:DBGFLAG('onAction') then print("onAction: ", json.encode(event)) end
---@diagnostic disable-next-line: undefined-field
  if quickApp.actionHandler then return quickApp:actionHandler(event) end
  if event.deviceId == quickApp.id then
    return quickApp:callAction(event.actionName, table.unpack(event.args))
  elseif quickApp.childDevices[event.deviceId] then
    return quickApp.childDevices[event.deviceId]:callAction(event.actionName, table.unpack(event.args))
  end
  fibaro.warning(__TAG,fmt("Child with id:%s not found",id))
end

function onUIEvent(id, event)
  local quickApp = plugin._quickApp
  if E:DBGFLAG('onUIEvent') then print("UIEvent: ", json.encode(event)) end
---@diagnostic disable-next-line: undefined-field
  if quickApp.UIHandler then quickApp:UIHandler(event) return end
  if quickApp.uiCallbacks[event.elementName] and quickApp.uiCallbacks[event.elementName][event.eventType] then
    quickApp:callAction(quickApp.uiCallbacks[event.elementName][event.eventType], event)
  else
    fibaro.warning(__TAG,fmt("UI callback for element:%s not found.", event.elementName))
  end
end

function QuickAppBase:UIAction(eventType, elementName, arg)
  local event = {
    deviceId = self.id, 
    eventType = eventType,
    elementName = elementName
  }
  event.values = arg ~= nil and  { arg } or json.util.InitArray({})
  onUIEvent(self.id, event)
end

class 'RefreshStateSubscriber'
local refreshStatePoller

function RefreshStateSubscriber:subscribe(filter, handler)
  return self.subject:filter(function(event) return filter(event) end):subscribe(function(event) handler(event) end)
end

function RefreshStateSubscriber:__init()
 self.time = os.time() -- Skip events before this time
  self.subscribers = {}
  self.last = 0
  function self.handle(event)
    if self.time > event.created+2 then return end -- Allow for 2 seconds mismatch between emulator and HC3
    for sub,_ in pairs(self.subscribers) do
      if sub.filter(event) then pcall(sub.handler,event) end
    end
  end
end

local MTsub = { __tostring = function(self) return "Subscription" end }

local SUBTYPE = '%SUBSCRIPTION%'
function RefreshStateSubscriber:subscribe(filter, handler)
  local sub = setmetatable({ type=SUBTYPE, filter = filter, handler = handler },MTsub)
  self.subscribers[sub]=true
  return sub
end

function RefreshStateSubscriber:unsubscribe(subscription)
  if type(subscription)=='table' and subscription.type==SUBTYPE then 
    self.subscribers[subscription]=nil
  end
end

function RefreshStateSubscriber:run() E.refreshState.addRefreshStateListener(self.handle) end
function RefreshStateSubscriber:stop() E.refreshState.removeRefreshStateListener(self.handle) end

function __onAction(id, actionName, args)
  print("__onAction", id, actionName, args)
  onAction(id, { deviceId = id, actionName = actionName, args = json.decode(args).args })
end
