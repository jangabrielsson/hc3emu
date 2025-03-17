
local json = TQ.json
local api = TQ.api
local DEBUGF = TQ.DEBUGF

local function keyMap(list,key)
  if list == nil then return {} end
  local r = {}
  for _,v in ipairs(list) do r[v[key]] = v end
  return r
end

-- Internal storage (always local)
local store = { devices = {}, globalVariables = {}, rooms = {}, sections = {}, settings={}, internalStorage={}, quickapp={} }
local mainStore = {}
local stateFileName = TQ.flags.state
local hasState = type(stateFileName)=='string'
if hasState then 
  local f = io.open(stateFileName,"r")
  if f then 
    mainStore = json.decode(f:read("*a")) f:close()
    if type(mainStore)~='table' then mainStore = {} end
    local store2 = mainStore[TQ.mainFile] or {}
    store2.devices = keyMap(store2.devices or {},'id')
    store2.rooms = keyMap(store2.rooms or {},'id')
    store2.sections = keyMap(store2.sections or {},'id')
    store2.globalVariables = keyMap(store2.globalVariables or {},'name')
    for k,v in pairs(store2) do store[k] = v end
    mainStore[TQ.mainFile] = store
  end
end

do
  local data = TQ.require("hc3emu.stdStructs")
  local std = json.decode(data)
  if not store.settings.info then store.settings.info = std.info end
  if not store.home then store.home = std.home end
  if not store.settings.location then store.settings.location = std.location end
  if not store.devices[1] then store.devices[1] = std.device1 end
end

local function updateSunTime()
  local longitude,latitude = store.settings.location.longitude,store.settings.location.latitude
  local sunrise,sunset = TQ.sunCalc(TQ.userTime(),latitude,longitude)
  TQ.sunriseHour = sunrise
  TQ.sunsetHour = sunset
  TQ.sunsetDate = TQ.userDate("%c")
  DEBUGF('time',"Suntime updated sunrise:%s, sunset:%s",sunrise,sunset)
  store.devices[1].properties.sunriseHour = sunrise
  store.devices[1].properties.sunsetHour = sunset
end

function TQ.EVENT.emulator_started() -- Update lat,long,suntime at startup
  if TQ.flags.latitude and TQ.flags.longitude then
    store.settings.location.latitude = TQ.flags.latitude
    store.settings.location.longitude = TQ.flags.longitude
  else
    if not TQ.flags.offline then
      local loc = api.get("/settings/location")
      store.settings.location = loc
    end
  end
  updateSunTime()
end

function TQ.EVENT.midnight() updateSunTime() end -- Update suntime at midnight

local function stripIndex(t)
  local r = {}
  for k,v in pairs(t) do r[#r+1] = v end
  return r
end

local function prepareDB()
  local r = {}
  for k,v in pairs(store) do r[k] = v end
  r.devices = stripIndex(r.devices)
  r.globalVariables = stripIndex(r.globalVariables)
  r.rooms = stripIndex(r.rooms)
  r.sections = stripIndex(r.sections)
  mainStore[TQ.mainFile] = r
end

local function flush(force)
  if not hasState then return end
  if TQ.flags.stateReadOnly and not force then return end
  local f = io.open(stateFileName,"w")
  prepareDB()
  if f then f:write(json.encode(mainStore)) f:close() end
end

local pathFuns = {}
local function getDevice(id,prop)
  id = tonumber(id)
  assert(id,"Device ID must be a number")
  if not store.devices[id] then store.devices[id] = {} end
  if not prop then return store.devices[id] end
  if not store.devices[id][prop] then store.devices[id][prop] = {} end
  return store[id][prop],store[id]
end

TQ.store = { DB = store }
TQ.store.getDevice = getDevice
TQ.store.flush = flush

function TQ.store.copyHC3()
  local devices = keyMap(api.get("/devices"),'id')
  local rooms = keyMap(api.get("/rooms"),'id')
  local sections = keyMap(api.get("/sections"),'id')
  local globalVariables = keyMap(api.get("/globalVariables"),'name')
  local locations = api.get("/panels/location")
  local info = api.get("/settings/info")
  local location = api.get("/settings/location")
  local categories = api.get("/categories")
  local home = api.get("/home")
  local iosDevices = api.get("/iosDevices")
  local profiles = api.get("/profiles")
  local users = api.get("/users")
  local weather = api.get("/weather")
  local alarmsPartitions = api.get("/alarms/v1/partitions")
  local alarmsDevices = api.get("/alarms/v1/devices")
  local climate = api.get("/panels/climate")
  for id,d in pairs(devices) do if not store.devices[id] then store.devices[id] = d end end
  for _,r in ipairs(rooms) do if not store.rooms[r.id] then store.rooms[r.id] = r end end
  for _,s in ipairs(sections) do if not store.sections[s.id] then store.sections[s.id] = s end end
  for name,v in pairs(globalVariables) do if not store.globalVariables[name] then store.globalVariables[name] = v end end
  store.settings = store.settings or {}
  store.settings.info = info
  store.settings.location = location
  store.panels = store.panels or {}
  store.panels.location = locations
  store.climate = climate
  store.categories = categories
  store.home = home
  store.iosDevices = iosDevices
  store.profiles = profiles
  store.users = users
  store.weather = weather
  store.alarms = store.alarms or {}
  store.alarms.v1 = store.alarms.v1 or {}
  store.alarms.v1.partitions = alarmsPartitions
  store.alarms.v1.devices = alarmsDevices
  TQ.DEBUG("HC3 data copied to store")
  flush(true)
end