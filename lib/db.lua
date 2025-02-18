
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
  if not store.devices[id] then store.devices[id] = {} end
  if not prop then return store.devices[id] end
  if not store.devices[id][prop] then store.devices[id][prop] = {} end
  return store[id][prop],store[id]
end

TQ.store = { DB = store }
TQ.store.getDevice = getDevice
TQ.store.flush = flush