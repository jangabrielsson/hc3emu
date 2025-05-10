
local function DEBUG(...)
  print(string.format(...))
end

ResourceDB = ResourceDB
class 'ResourceDB'
function ResourceDB:__init()
  self.db = {
    devices = { items = {}, inited = false, index='id', path="/devices" },
    globalVariables = { items = {}, inited = false, index='name', path="/globalVariables" },
    rooms = { items = {}, inited = false, index='id', path="/rooms" },
    sections = { items = {}, inited = false, index='id', idc=7000, path="/sections" },
    customEvents = { items = {}, inited = false, index='name', path="/customEvents" },
    scenes = { items = {}, inited = false, index='id', path="/scenes" },
    ['panels/location'] = { items = {}, inited = false, index='id', idc=200, path="/panels/location" },
    ['settings/location'] = { items = {}, inited = false, index=nil, path="/settings/location" },
    ['settings/info'] = { items = {}, inited = false, index=nil, path="/settings/info" },
    users = { items = {}, inited = false, index='id', idc=4000, path="/users" },
    home = { items = {}, inited = false, index=nil, path="/home" },
    weather = { items = {}, inited = false, index=nil, path="/weather" },
    internalStorage = { items = {}, inited = false, index=nil, path="/qa/variables" },
  }
end

local function toList(t) local r = {} for _,v in pairs(t) do r[#r+1] = v end return r end

local function merge(t1,t2)
  for k,v in pairs(t2) do
    if type(v) == 'table' then
      if not t1[k] then t1[k] = {} end
      merge(t1[k],v)
    else
      t1[k] = v
    end
  end
end

function ResourceDB:initRsrc(typ)
  local r = self.db[typ]
  r.inited = true
  if self.offline then return end
  local res = self.hc3.get(r.path)
  local idx,items = r.index,r.items
  if idx==nil then items = res or {}
  else 
    for _,v in ipairs(res or {}) do items[v[idx]] = v end
  end
  r.items = items
end

function ResourceDB:get(typ,id)
  local res = self.db[typ]
  if not res then return nil,501 end
  if res and not res.inited then self:initRsrc(typ) end
  if id == nil then 
    if res.index == nil then return res.items,200
    else return toList(res.items),200 end
  elseif not res.items[id] then return nil, 404 
  else return res.items[id],200 end
end

function ResourceDB:create(typ,data)
  local res = self.db[typ]
  if not res then return nil,501 end
  if res and not res.inited then self:initRsrc(typ) end
  local idx = res.index -- Is this an indexed resource?
  local id = data[idx or ""] -- Then this is it's index..
  if idx and id==nil then -- Creating an indexed resource without id, invent one...
    id = res.idc
    res.idc = res.idc + 1
  end
  if not id then res.items = data
  else 
    if res.items[id] then return nil,404
    else res.items[id] = data end
  end
  return data,201
end

function ResourceDB:delete(typ,id)
  local res = self.db[typ]
  if not res then return nil,501 end
  if res and not res.inited then self:initRsrc(typ) end
  if res.items[id] == nil then return nil,404
  else res.items[id] = nil end
  return nil,200
end

function ResourceDB:modify(typ,data)
  local res = self.db[typ]
  if not res then return nil,501 end
  if res and not res.inited then self:initRsrc(typ) end
  local idx = res.index
  local id,items = data[idx or ""],res.items
  if id then items=res.items[id] end
  merge(items,data)
  return nil,200
end

function ResourceDB:modifyProp(typ,data)
  local res = self.db['devices']
  if not res then return nil,501 end
  if res and not res.inited then self:initRsrc('devices') end
  local dev = res.items[data.id]
  if not dev then return nil,501 end
  dev.properties[data.property] = data.newValue
  return nil,200
end

local filter = { 
  GlobalVariableAddedEvent = true, GlobalVariableChangedEvent = true, GlobalVariableRemovedEvent = true, RoomModifiedEvent = true, 
  RoomCreatedEvent = true, RoomRemovedEvent = true, 
  SectionModifiedEvent = true, SectionCreatedEvent = true, SectionRemovedEvent = true,
  CustomEventModifiedEvent = true, CustomEventCreatedEvent = true, CustomEventRemovedEvent = true,
  DeviceModifiedEvent = true, DevicePropertyUpdatedEvent = true
}

local EventHandler = {}
EventQueue = EventQueue
class 'EventQueue'
function EventQueue:__init()
  self.queue = {}
end
function EventQueue:addEvent(event)
  if true or filter[event.type] then DEBUG("EventQueue:addEvent %s %s",event.type,json.encode(event.data)) end
  table.insert(self.queue, event)
end

EventDispatcher = EventDispatcher
class 'EventDispatcher'
function EventDispatcher:__init()
  self.queue = EventQueue()
  self.db = ResourceDB()
  self.offline = false
  self.poller = RefreshPoller(self)
end
function EventDispatcher:start(api) 
  self.api = api
  self.db.hc3 = api.hc3
  self:setupHandlers()
  self.poller:start()
end

function EventDispatcher:newEvent(event,lcl)
  local str = nil
  if filter[event.type] then
    str = event.type.." "..json.encode(event.data)
  end
  if self.offline then
    if str then DEBUG("Offline EventDispatcher:newEvent %s",str) end
    local res,code = self:updateDB(event)
    if code < 206 then
      self.queue:addEvent(event)
    end
    return res,code
  end
  -- Online mode
  if lcl then -- generated by api.* call
    if str then DEBUG("Local EventDispatcher:newEvent %s",str) end
    local res,code = self:updateHC3(event)
    if code < 206 then
      self:updateDB(event)
    end
    return res,code
  else -- generated by poller, from HC3
    if str then DEBUG("HC3 EventDispatcher:newEvent %s",str) end
    local res,code = self:updateDB(event)
    self.queue:addEvent(event)
    return res,code
  end
end

function EventDispatcher:newLocalEvent(event)
  return self:newEvent(event,true)
end

function EventDispatcher:updateDB(event)
  local handler = EventHandler[event.type]
  if handler then
    return handler(event.data, event, false)
  end
  return nil,999
end

function EventDispatcher:updateHC3(event)
  local handler = EventHandler[event.type]
  if handler then
    return handler(event.data, event, true)
  end
  return nil,501
end

RefreshPoller = RefreshPoller
class 'RefreshPoller'
function RefreshPoller:__init(eventDispatcher)
  self.eventDispatcher = eventDispatcher
end
function RefreshPoller:start()
  local refresh = RefreshStateSubscriber()
  refresh:subscribe(function() return true end,function(event) self.eventDispatcher:newEvent(event) end)
  refresh:run()
end

-- RefreshStateSubscriber subcribes to queue...

function EventDispatcher:setupHandlers()
  local db = self.db
  local api = self.api
  local hc3 = api.hc3
  local EH = EventHandler

  local function regEvent(typ)
    EH[typ] = function(data,event,ext)
      if ext then return nil,501 
      else return nil,501 end
    end
  end

  -- Global variables
  function EH.GlobalVariableAddedEvent(data,event,ext)
    if ext then 
      return hc3.post('/globalVariables',{name=data.variableName,value=data.newValue})
    else
      return db:create('globalVariables',{name=data.variableName, value=data.newValue})
    end
  end
  function EH.GlobalVariableRemovedEvent(data,event,ext)
    if ext then return hc3.delete('/globalVariables/'..data.variableName,{})
    else return db:delete('globalVariables',data.variableName) end
  end
  function EH.GlobalVariableChangedEvent(data,event,ext)
    if ext then return hc3.put('/globalVariables/'..data.variableName,{value=data.newValue})
    else return db:modify('globalVariables',{name=data.variableName, value=data.newValue}) end
  end

  -- Rooms
  function EH.RoomCreatedEvent(data,event,ext)
    if ext then return hc3.post('/rooms',data)
    else return db:create('rooms',{name=data.roomName}) end
  end
  function EH.RoomRemovedEvent(data,event,ext)
    if ext then return hc3.delete('/rooms/'..data.id,{})
    else return db:delete('rooms',data.id) end
  end
  function EH.RoomModifiedEvent(data,event,ext)
    if ext then return hc3.put('/rooms/'..data.id,{name=data.roomName})
    else return db:modify('rooms',{name=data.roomName}) end
  end

  -- Sections
  function EH.SectionCreatedEvent(data,event,ext)
    if ext then return hc3.post('/sections',data)
    else return db:create('sections',data) end
  end
  function EH.SectionRemovedEvent(data,event,ext)
    if ext then return hc3.delete('/sections/'..data.id,{})
    else return db:delete('sections',data.id) end
  end
  function EH.SectionModifiedEvent(data,event,ext)
    if ext then return hc3.put('/sections/'..data.id,data)
    else return db:modify('sections',data) end
  end

  -- CustomEvents
  function EH.CustomEventCreated(data,event,ext)
    if ext then return hc3.post('/customEvents',data)
    else return db:create('customEvents',data) end
  end
  function EH.CustomEvent(data,event,ext)
    if ext then return hc3.post('/customEvents',{name=data.eventName})
    else print("SEND CustomEvent") return nil,200 end
  end
  function EH.CustomEventRemoved(data,event,ext)
    if ext then return hc3.delete('/customEvents/'..data.name,{})
    else return db:delete('customEvents',data.name) end
  end
  function EH.CustomEventModified(data,event,ext)
    if ext then return hc3.put('/customEvents/'..data.name,data)
    else return db:modify('customEvents',data) end
  end

  -- Devices
  function EH.DeviceCreatedEvent(data,event,ext)
    if ext then return hc3.post('/devices',{name=data.deviceName})
    else return db:create('devices',{name=data.deviceName}) end
  end
  function EH.DeviceRemovedEvent(data,event,ext)
    if ext then return hc3.delete('/devices/'..data.deviceId,{})
    else return db:delete('devices',data.deviceId) end
  end
  function EH.DeviceModifiedEvent(data,event,ext)
    if ext then
      local ndata = table.copy(data)
      ndata.id = nil
      return hc3.put('/devices/'..data.id,ndata)
    else 
      local id = data.id
      local dev = hc3.get('/devices/'..id)
      local ndata = {id = id }
      for _,key in ipairs({'name','roomID','enabled','visible'}) do
        ndata[key] = dev[key]
      end
      return db:modify('devices',ndata) 
    end
  end
  function EH.DevicePropertyUpdatedEvent(data,event,ext)
    if ext then return hc3.put('/devices/'..data.deviceId..'/properties/'..data.propertyName,{value=data.newValue})
    else return db:modifyProp('devices',data) end
  end

  -- Weather 
  function EH.WeatherChangedEvent(data,event,ext)
    if ext then return data,200 --hc3.put('/weather',data)
    else return db:modify('weather',data) end
  end

  -- panels/location
  function EH.LocationCreatedEvent(data,event,ext)
    if ext then return hc3.post('/panels/location',data)
    else return db:create('panels/location',data) end
  end
  function EH.LocationRemovedEvent(data,event,ext)
    if ext then return hc3.delete('/panels/location/'..data.id,{})
    else return db:delete('panels/location',data.sectionId) end
  end
  function EH.LocationModifiedEvent(data,event,ext)
    if ext then return hc3.put('/panels/location/'..data.id,data)
    else return db:modify('panels/location',data) end
  end

  -- user
  function EH.UserCreatedEvent(data,event,ext)
    if ext then return hc3.post('/panels/location',data)
    else return db:create('panels/location',data) end
  end
  function EH.UserRemovedEvent(data,event,ext)
    if ext then return hc3.delete('/users/'..data.id,{})
    else return db:delete('users',data.id) end
  end
  function EH.UserModifiedEvent(data,event,ext)
    if ext then
      local ndata = table.copy(data)
      ndata.id = nil
      return hc3.put('/users/'..data.id,ndata)
    else 
      local id = data.id
      local user = hc3.get('/users/'..id)
      return db:modify('users',user) 
    end
  end
  
  -- Events below we don't generate from emulator, only pass on if coming from HC3
  ------------ Alarm
  regEvent('AlarmPartitionArmedEvent')
  regEvent('HomeArmStateChangedEvent')
  regEvent('HomeDisarmStateChangedEvent')
  regEvent('HomeBreachedEvent')
  
  --------------- Misc
  regEvent('DeviceActionRanEvent')
  regEvent('CentralSceneEvent')
  regEvent('SceneActivationEvent')
  regEvent('AccessControlEvent')
  regEvent('PluginChangedViewEvent')
  regEvent('WizardStepStateChangedEvent')
  regEvent('UpdateReadyEvent')
  regEvent('DeviceChangedRoomEvent')
  regEvent('PluginProcessCrashedEvent')
  regEvent('SceneStartedEvent')
  regEvent('SceneFinishedEvent')
  regEvent('SceneRunningInstancesEvent')
  regEvent('SceneRemovedEvent')
  regEvent('SceneModifiedEvent')
  regEvent('SceneCreatedEvent')
  regEvent('OnlineStatusUpdatedEvent')
  regEvent('ActiveProfileChangedEvent')
  regEvent('ClimateZoneChangedEvent')
  regEvent('ClimateZoneSetpointChangedEvent')
  regEvent('ClimateZoneTemperatureChangedEvent')
  regEvent('NotificationCreatedEvent')
  regEvent('NotificationRemovedEvent')
  regEvent('NotificationUpdatedEvent')
  regEvent('QuickAppFilesChangedEvent')
  regEvent('ZwaveDeviceParametersChangedEvent')
  regEvent('ZwaveNodeAddedEvent')
  regEvent('ZwaveNodeWokeUpEvent')
  regEvent('ZwaveNodeWentToSleepEvent')
  regEvent('RefreshRequiredEvent')
  regEvent('DeviceFirmwareUpdateEvent')
  regEvent('GeofenceEvent')
  regEvent('DeviceNotificationState')
  regEvent('DeviceInterfacesUpdatedEvent')
  regEvent('EntitiesAmountChangedEvent')
  regEvent('ActiveTariffChangedEvent')
  regEvent('UserModifiedEvent')
  regEvent('SprinklerSequenceStartedEvent')
  regEvent('SprinklerSequenceFinishedEvent')
  regEvent('DeviceGroupActionRanEvent')
  regEvent('PowerMetricsChangedEvent')
end
