-- Standard api routes

local json = TQ.json
local plugin = TQ.plugin

local fmt = string.format

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

local function internalStoragePut(id,key,data)
  local store = getDeviceStore(id,'internalStorage')
  if not store[key] then return nil,404 end
  store[key] = data
  flushStore()
  return true,200
end

local function internalStoragePost(id,data)
  local store = getDeviceStore(id,'internalStorage')
  local key = data.name
  if store[key] then return nil,409 end
  store[key] = data
  flushStore()
  return true,200
end

local function internalStorageGet(id,key,data)
  local store = getDeviceStore(id,'internalStorage')
  if key ~= nil then 
    if store[key] then return store[key],200
    else return nil,404 end
  else 
    local r = {}
    for _, v in pairs(store) do r[v.name] = v.value end
    return r,200
  end
end

local function internalStorageDelete(id,key,data) 
  local store,db = getDeviceStore(id,'internalStorage')
  if key then
    if not store[key] then return nil,404 end
    store[key] = nil flushStore() 
  else
    db.internalStorage = {}
    flushStore()
  end
  return true,200
end

local function getProp(p,prop) -- fetch local properties
  local value = plugin._dev.properties[prop]
  return {value=value,modified = plugin._dev.modified},200
end

local function callAction(p,name,data)
  local id = TQ.plugin.mainDeviceId
  local qa = TQ.getQA(tonumber(id))
  qa.qa:callAction(name,table.unpack(data.args)) return 'OK',200
end

function TQ.addStandardAPIRoutes(route) -- Adds standard API routes to an route object.
  local id = plugin.mainDeviceId

  route:add(fmt('GET/devices/%s',id),function(p,d) return plugin._dev,200 end) -- Fetch our local device structure
  route:add(fmt('POST/devices/%s/action/<name>',id),callAction)       -- Call to ourself
  route:add(fmt('GET/devices/%s/properties/<name>',id),getProp) -- Get properties from ourselves, fetch it locally
  
  route:add(fmt('GET/quickApp/export/%s',id),function() return TQ.getFQA(),200 end) -- Get our local QA
  route:add('PUT/plugins/<id>/variables/<name>', function(p,...) return internalStoragePut(...) end) --id,key,data
  route:add('POST/plugins/<id>/variables', function(p,...) return internalStoragePost(...) end) --id,data
  route:add('GET/plugins/<id>/variables/<name>', function(p,...) return internalStorageGet(...) end) --id,key,data
  route:add('GET/plugins/<id>/variables', function(p,id,...) return internalStorageGet(id,...) end) --id,nil,data
  route:add('DELETE/plugins/<id>/variables/<name>', function(p,...) return internalStorageDelete(...) end) --id,key,data
  route:add('DELETE/plugins/<id>/variables', function(p,id,...) return internalStorageDelete(id,...) end) --id,nil,data

end

TQ.internalStoragePut = internalStoragePut
TQ.internalStoragePost = internalStoragePost
TQ.internalStorageGet = internalStorageGet
TQ.internalStorageDelete = internalStorageDelete