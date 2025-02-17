
local json = TQ.json

-- Internal storage (always local)
local store = {}
local stateFileName = TQ.flags.state
local hasState = type(stateFileName)=='string'
if hasState then 
  local f = io.open(stateFileName,"r")
  if f then store = json.decode(f:read("*a")) f:close() end
end
local function flushStore()
  if not hasState then return end
  local f = io.open(stateFileName,"w")
  if f then f:write(json.encode(store)) f:close() end
end
local function getDeviceStore(id,storeName)
  if not store[id] then store[id] = {} end
  if not store[id][storeName] then store[id][storeName] = {} end
  return store[id][storeName],store[id]
end

TQ.getDeviceStore = getDeviceStore
TQ.flushStore = flushStore