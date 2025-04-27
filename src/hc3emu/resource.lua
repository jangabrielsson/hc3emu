--[[ Emulator api routes
--]]
local json = require("hc3emu.json")

class 'Resources'
local Resources = _G['Resources']; _G['Resources'] = nil

function Resources:__init(api)
  self.resources = {
    devices = { items = {}, cached = false, index='id', path="/devices" },
    globalVariables = { items = {}, cached = false, index='name', path="/globalVariables" },
    rooms = { items = {}, cached = false, index='id', path="/rooms" },
    sections = { items = {}, cached = false, index='id', path="/sections" },
    customEvents = { items = {}, cached = false, index='name', path="/customEvents" },
    scenes = { items = {}, cached = false, index='id', path="/scenes" },
    panels_location = { items = {}, cached = false, index='id', path="/panels/location" },
    settings_location = { items = {}, cached = false, index=nil, path="/settings/location" },
    settings_info = { items = {}, cached = false, index=nil, path="/settings/info" },
    users = { items = {}, cached = false, index='id', path="/users" },
    home = { items = {}, cached = false, index=nil, path="/home" },
    weather = { items = {}, cached = false, index=nil, path="/weather" },
    internalStorage = { items = {}, cached = false, index=nil, path="/qa/variables" },
  }
  self.api = api
  self.hc3 = api.hc3
  self.offline = api.offline
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

local function OST(_) return os.time() end
local defaults = {
  globalVariables = { enumValues = {}, isEnum = false, readOnly=false, modified=OST, created=OST },
}

function Resources:_init(typ)
  local r = self.resources[typ]
  r.inited = true
  if self.offline then return end
  local res = self.hc3:get(r.path)
  local idx,items = r.index,r.items
  if idx==nil then items = res or {}
  else 
    for _,v in ipairs(res or {}) do items[v[idx]] = v end
  end
  r.items = items
end

function Resources:get(typ,id)
  local r = self.resources[typ] assert(r)
  if not r.inited then self:_init(typ) end  
  if id == nil then 
    if r.idx == nil then return r.items,200
    else return toList(r.items),200 end
  elseif not r.items[id] then return nil, 404 
  else return r.items[id],200 end
end

local RSRCINDEX = { rooms = 300, sections = 400 }
function Resources:create(typ,data,hc3,refresh)
  local r = self.resources[typ] 
  assert(r)
  if not r.inited then self:_init(typ) end
  local id = data[r.index]
  if not id then
    if self.offline then
      if not RSRCINDEX[typ] then error("Resource "..typ.." does not have an index") end
      id = RSRCINDEX[typ] + 1; RSRCINDEX[typ] = id+1
      data[r.index] = id
    else return  self.hc3:post(r.path,data) end
  end
  if r.items[id] then 
    if hc3 then merge(r.items[id], data) end -- assume better data from HC3...
    return nil, 409
  end
  if not (self.offline or hc3) then
    local res,code = self.hc3:post(r.path,data)
    if code > 204 then return nil, code end
    data = res
  end
  if defaults[typ] then 
    for k,v in pairs(defaults[typ]) do
      if data[k] == nil then if type(v)=='function' then data[k] = v(data) else data[k]=v end end
    end
  end
  r.items[id] = data
  if self.offline or refresh then self:refresh('created',typ,id,data) end
  return data,201
end

local blockedMod = { weather=true }
function Resources:modify(typ,id,data,hc3,refresh)
  local r = self.resources[typ] assert(r)
  if not r.inited then self:_init(typ) end
  local res,force = r.items,false
  if id then
    if not r.items[id] then return nil, 404 end
    res = r.items[id]
  end
  merge(res,data)
  if not (self.offline or hc3) then
    if blockedMod[typ] then -- Special hack for weather, but could be used for other?
      force = true
      res = data
    elseif not id then
      local res,code = self.hc3:put(r.path,data)
      if code > 204 then return nil, code end
    else
      local res,code = self.hc3:put(r.path.."/"..id,data)
      if code > 204 then return nil, code end
    end
    data = res
  end
  if self.offline or force or refresh then self:refresh('modified',typ,id,data) end
  return res,200
end

function Resources:delete(typ,id,hc3,refresh)
  local r = self.resources[typ] assert(r)
  if not r.inited then self:_init(typ) end
  if not r.items[id] then return nil, 404 end
  r.items[id] = nil
  if not (self.offline or hc3) then
    local res,code = self.hc3:delete(r.path.."/"..id)
    if code > 204 then return nil, code end
  end
  if self.offline or refresh then self:refresh('deleted',typ,id) end
  return nil,200
end

function Resources:modProp(id,prop,value,hc3,refresh)
  local r = self.resources['devices'] assert(r)
  if not r.inited then self:_init('devices') end
  if not r.items[id] then return nil, 404 end
  local oldProp = r.items[id].properties[prop]
  if not (self.offline or hc3) then
    local res,code = self.hc3:post("/plugins/updateProperty",{deviceId=id,propertyName=prop,value=value})
    if code > 204 then return nil, code end
  end
  if table.equal(oldProp,value) then return nil, 200 end
  r.items[id].properties[prop] = value
  if self.offline or refresh then self:refresh('modified','property',id,{id=id,property=prop,newValue=value,oldValue=oldProp}) end
  return nil,200
end

local refreshes = { created={}, modified={}, deleted={}, ops={} }

function Resources:refreshOrg(event)
  self.addEvent(event)
  --print("Refresh:",event.type,json.encode(event.data))
end

function Resources:refresh(op,typ,id,data)
  local r = refreshes[op][typ]
  if not r then return end
  self:refreshOrg(r(id,data))
end

class 'EventMgr'
local EventMgr = _G['EventMgr']; _G['EventMgr'] = nil

local function match(pattern,event) -- See if pattern matches event
  if type(pattern) == 'table' and type(event) == 'table' then
    for k,v in pairs(pattern) do
      if not match(v,event[k]) then return false end -- check if all keys in pattern are present in event 
    end
    return true
  else return pattern == event end -- strings, numbers, booleans
end

function EventMgr:__init(emulator)
  self.events = {}
  self.emulator = emulator
  local handler = function(event) self:post(event) end
  if not self.offline then
    emulator.refreshState.addRefreshStateListener(handler)
  end
  function self.addEvent(event) emulator.refreshState.addRefreshStateEvent(event,handler) end
end

function EventMgr:addHandler(pattern,handler) 
  self.events[pattern.type] = self.events[pattern.type] or {}
  table.insert(self.events[pattern.type],{pattern=pattern,handler=handler}) 
end

function EventMgr:getHandlers(event)
  return self.events[event.type] or {} 
end

local filter = { DeviceActionRanEvent = true }
function EventMgr:post(event,time)  -- Optional time in seconds
  if filter[event.type] then return end
  print("Event:",event.type,json.encode(event.data))
  self.emulator.util.systemTask(function() -- Do it as asynchronously as possible
    local handlers = self:getHandlers(event)
    for _,v in ipairs(handlers) do -- look through each defined event handler for this event type
      if match(v.pattern,event) and v.handler(event) then return end -- if matches event pattern , call handler with event
    end
  end)
end

function Resources:run()
  if self.offline then self.api:loadResources(self) end
  local eventMgr = EventMgr(self.api.E)
  self.addEvent = eventMgr.addEvent
  local rsrc = self
  
  local function regEvent(typ) 
    eventMgr:addHandler({type=typ},function(event)
      rsrc:refreshOrg(event)
    end)
  end

  -- GlobalVariables
  function refreshes.created.globalVariables(id,data)
    return { type='GlobalVariableAddedEvent', data={variableName=data.name, value=data.value }}
  end
  eventMgr:addHandler({type='GlobalVariableAddedEvent'},function(event)
    local d = event.data
    rsrc:create('globalVariables',{name=d.variableName, value=d.value},true)
    rsrc:refreshOrg(event)
  end)
  
  function refreshes.modified.globalVariables(id,data)
    return { type='GlobalVariableChangedEvent', data={variableName=data.name, newValue=data.value }}
  end
  eventMgr:addHandler({type='GlobalVariableChangedEvent'},function(event)
    local d = event.data
    rsrc:modify('globalVariables',d.variableName,{value=d.newValue},true)
    rsrc:refreshOrg(event)
  end)
  
  function refreshes.deleted.globalVariables(id,data)
    return { type='GlobalVariableRemovedEvent', data={variableName=id }}
  end
  eventMgr:addHandler({type='GlobalVariableRemovedEvent'},function(event)
    rsrc:delete('globalVariables',event.data.variableName,true)
    rsrc:refreshOrg(event)
  end)
  
  -- Rooms
  function refreshes.created.rooms(id,data)
    return { type='RoomCreatedEvent', data=data}
  end
  eventMgr:addHandler({type='RoomCreatedEvent'},function(event)
    rsrc:create('rooms',event.data,true)
    rsrc:refreshOrg(event)
  end)
  
  function refreshes.modified.rooms(id,data)
    return { type='RoomModifiedEvent', data=data }
  end
  eventMgr:addHandler({type='RoomModifiedEvent'},function(event)
    rsrc:modify('rooms', event.data.id, event.data,true)
    rsrc:refreshOrg(event)
  end)
  
  function refreshes.deleted.rooms(id,data)
    return { type='RoomRemovedEvent', data={ id=id }}
  end
  eventMgr:addHandler({type='RoomRemovedEvent'},function(event)
    rsrc:delete('rooms',event.data.id,true)
    rsrc:refreshOrg(event)
  end)
  
  -- Sections
  function refreshes.created.sections(id,data)
    return { type='SectionCreatedEvent', data=data}
  end
  eventMgr:addHandler({type='SectionCreatedEvent'},function(event)
    rsrc:create('sections',event.data,true)
    rsrc:refreshOrg(event)
  end)
  
  function refreshes.modified.sections(id,data)
    return { type='SectionModifiedEvent', data=data }
  end
  eventMgr:addHandler({type='SectionModifiedEvent'},function(event)
    rsrc:modify('sections',event.data.id,event.data,true)
    rsrc:refreshOrg(event)
  end)
  
  function refreshes.deleted.sections(id,data)
    return { type='SectionRemovedEvent', data={ id=id }}
  end
  eventMgr:addHandler({type='SectionRemovedEvent'},function(event)
    rsrc:delete('sections',event.data.id,true)
    rsrc:refreshOrg(event)
  end)
  
  ---------- Custom Events
  function refreshes.ops.customEvents(id,data)
    return { type='CustomEvent', data={name = id}}
  end
  eventMgr:addHandler({type='CustomEvent'},function(event)
    rsrc:refreshOrg(event)
  end)
  
  function refreshes.created.customEvents(id,data)
    return { type='CustomEventCreatedEvent', data=data}
  end
  eventMgr:addHandler({type='CustomEventCreatedEvent'},function(event)
    rsrc:create('customEvents',event.data,true)
    rsrc:refreshOrg(event)
  end)
  
  function refreshes.modified.customEvents(id,data)
    return { type='CustomEventModifiedEvent', data=data }
  end
  eventMgr:addHandler({type='CustomEventModifiedEvent'},function(event)
    rsrc:modify('customEvents',event.data.id,event.data,true)
    rsrc:refreshOrg(event)
  end)
  
  function refreshes.deleted.customEvents(id,data)
    return { type='CustomEventRemovedEvent', data={ id=id }}
  end
  eventMgr:addHandler({type='CustomEventRemovedEvent'},function(event)
    rsrc:delete('customEvents',event.data.id,true)
    rsrc:refreshOrg(event)
  end)
  
  ------------------  Devices ----------
  function refreshes.deleted.devices(id,data)
    return { type='DeviceModifiedEvent', data={ id=id }}
  end
  local props = {'name','roomID','viewXml','hasUIView','visible','enabled'}
  eventMgr:addHandler({type='DeviceModifiedEvent'},function(event)
    local src = self.api.hc3:get("/devices/"..event.data.id)
    local dest = self:get("devices",event.data.id)
    for _,p in ipairs(props) do dest[p] = src[p] end
    rsrc:refreshOrg(event)
  end)

  function refreshes.created.devices(id,data)
    return { type='DeviceCreatedEvent', data={ id=id }}
  end
  eventMgr:addHandler({type='DeviceCreatedEvent'},function(event)
    rsrc:refreshOrg(event)
  end)

  function refreshes.deleted.devices(id,data)
    return { type='DeviceRemovedEvent', data={ id=id }}
  end
  eventMgr:addHandler({type='DeviceRemovedEvent'},function(event)
    rsrc:refreshOrg(event)
  end)

  function refreshes.modified.property(id,data)
    data.id = id
    return { type='DevicePropertyUpdatedEvent', data=data}
  end
  eventMgr:addHandler({type='DevicePropertyUpdatedEvent'},function(event)
    local d = event.data
    rsrc:modProp(d.id,d.property,d.newValue,true)  -- id,prop,value,hc3)
    rsrc:refreshOrg(event)
  end)

  ----------------- Weather-----
  function refreshes.modified.weather(id,data)
    return { type='WeatherChangedEvent', data=data}
  end
  eventMgr:addHandler({type='WeatherChangedEvent'},function(event)
    local weather = rsrc:get("weather")
    weather[event.data.change] = event.data.newValue
    rsrc:refreshOrg(event)
  end)

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

return Resources