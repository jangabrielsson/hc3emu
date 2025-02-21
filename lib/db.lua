
local json = TQ.json

-- Internal storage (always local)
local store = { devices = {}, globalVariables = {}, rooms = {}, sections = {}, settings={}, internalStorage={}, quickapp={} }
local stateFileName = TQ.flags.state
local hasState = type(stateFileName)=='string'
if hasState then 
  local f = io.open(stateFileName,"r")
  if f then 
    local store2 = json.decode(f:read("*a")) f:close()
    if type(store2)~='table' then store2 = {} end
    for k,v in pairs(store2) do store[k] = v end
  end
end

local function flush(force)
  if not hasState then return end
  if TQ.flags.stateReadOnly and not force then return end
  local f = io.open(stateFileName,"w")
  if f then f:write(json.encode(store)) f:close() end
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

local function keyMap(list,key)
  local r = {}
  for _,v in ipairs(list) do r[v[key]] = v end
  return r
end

function TQ.store.copyHC3()
  local devices = keyMap(api.get("/devices"),'id')
  local rooms = api.get("/rooms")
  local sections = api.get("/sections")
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
end