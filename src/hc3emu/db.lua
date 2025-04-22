local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local json = require("hc3emu.json")

local function keyMap(list,key)
  if list == nil then return {} end
  local r = {}
  for _,v in ipairs(list) do r[v[key]] = v end
  return r
end

-- Internal storage (always local)
local store = { 
  devices = {}, 
  globalVariables = {}, 
  rooms = {}, 
  sections = {}, 
  settings={}, 
  internalStorage={}, 
  quickapp={},
  customEvents = {},
}
local mainStore = {}

local userTime,userDate

local function updateSunTime()
  local longitude,latitude = store.settings.location.longitude,store.settings.location.latitude
  local sunrise,sunset = E.util.sunCalc(userTime(),latitude,longitude)
  E.sunriseHour = sunrise
  E.sunsetHour = sunset
  E.sunsetDate = userDate("%c")
  E:DEBUGF('time',"Suntime updated sunrise:%s, sunset:%s",sunrise,sunset)
  store.devices[1].properties.sunriseHour = sunrise
  store.devices[1].properties.sunsetHour = sunset
end

local hasState, stateFileName = false, nil
local function init()
  userTime,userDate = E.timers.userTime,E.timers.userDate
  stateFileName = E.DBG.state
  hasState = type(stateFileName)=='string'
  if hasState then 
    local f = io.open(stateFileName,"r")
    if f then 
      E:DEBUGF('db',"Reading state file",stateFileName)
      mainStore = json.decode(f:read("*a")) f:close()
      if type(mainStore)~='table' then mainStore = {} end
      local store2 = mainStore[E.mainFile] or {}
      store2.devices = keyMap(store2.devices or {},'id')
      store2.rooms = keyMap(store2.rooms or {},'id')
      store2.sections = keyMap(store2.sections or {},'id')
      store2.globalVariables = keyMap(store2.globalVariables or {},'name')
      for k,v in pairs(store2) do store[k] = v end
      mainStore[E.mainFile] = store
    else
      E:DEBUGF('db',"State file not found",stateFileName)
    end
  end
  
  do
    local std = E.config.loadResource("stdStructs.json",true)
    if not store.settings.info then store.settings.info = std.info end
    if not store.home then store.home = std.home end
    if not store.settings.location then store.settings.location = std.location end
    if not store.devices[1] then store.devices[1] = std.device1 end
  end
  
  function E.EVENT._emulator_started() -- Update lat,long,suntime at startup
    if E.DBG.latitude and E.DBG.longitude then
      store.settings.location.latitude = E.DBG.latitude
      store.settings.location.longitude = E.DBG.longitude
    else
      if not E.DBG.offline then
        local loc = E:apiget("/settings/location")
        store.settings.location = loc
      end
    end
    updateSunTime()
  end
  
  function E.EVENT._midnight() updateSunTime() end -- Update suntime at midnight
  
end

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
  mainStore[E.mainFile] = r
end

local function flush(force)
  if not hasState then return end
  if E.DBG.stateReadOnly and not force then return end
  local f = io.open(stateFileName,"w")
  prepareDB()
  if f then 
    f:write(json.encode(mainStore)) f:close() 
    E:DEBUGF('db',"State file written",stateFileName)
  else
    E:DEBUGF('db',"State file write failed",stateFileName)
  end
end

local function getDevice(id,prop)
  id = tonumber(id)
  assert(id,"Device ID must be a number")
  if not store.devices[id] then store.devices[id] = {} end
  if not prop then return store.devices[id] end
  if not store.devices[id][prop] then store.devices[id][prop] = {} end
  return store[id][prop],store[id]
end

local function copyHC3()
  local devices = keyMap(E:apiget("/devices"),'id')
  local rooms = keyMap(E:apiget("/rooms"),'id')
  local sections = keyMap(E:apiget("/sections"),'id')
  local globalVariables = keyMap(E:apiget("/globalVariables"),'name')
  local locations = E:apiget("/panels/location")
  local info = E:apiget("/settings/info")
  local location = E:apiget("/settings/location")
  local categories = E:apiget("/categories")
  local home = E:apiget("/home")
  local iosDevices = E:apiget("/iosDevices")
  local profiles = E:apiget("/profiles")
  local users = E:apiget("/users")
  local weather = E:apiget("/weather")
  local alarmsPartitions = E:apiget("/alarms/v1/partitions")
  local alarmsDevices = E:apiget("/alarms/v1/devices")
  local climate = E:apiget("/panels/climate")
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
  E:DEBUG("HC3 data copied to store")
  flush(true)
end

exports.getDevice = getDevice
exports.flush = flush
exports.DB = store
exports.copyHC3 = copyHC3
exports.init = init

return exports