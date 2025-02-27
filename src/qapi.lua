-- Standard api routes

local json = TQ.json

local fmt = string.format

local getDeviceStore = TQ.store.getDevice
local flushStore = TQ.store.flush
local internalStore = TQ.store.DB.internalStorage

local function internalStoragePut(id,key,data)
  local store = internalStore[id] or {}
  internalStore[id] = store
  if not store[key] then return nil,404 end
  store[key] = data
  flushStore(true)
  return true,200
end

local function internalStoragePost(id,data)
  local store = internalStore[id] or {}
  internalStore[id] = store
  local key = data.name
  if store[key] then return nil,409 end
  store[key] = data
  flushStore(true)
  return true,200
end

local function internalStorageGet(id,key,data)
  local store = internalStore[id] or {}
  internalStore[id] = store
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
  local store = internalStore[id] or {}
  internalStore[id] = store
  if key then
    if not store[key] then return nil,404 end
    store[key] = nil flushStore() 
  else
    internalStore[id] = {}
    flushStore(true)
  end
  return true,200
end

local function getProp(p,id,prop) -- fetch local properties
  local qa = TQ.getQA(tonumber(id))
  if qa == nil then return nil,301 end
  local value = qa.device.properties[prop]
  return {value=value,modified = qa.device.modified},200
end

local function callAction(p,id,name,data)
  local qa = TQ.getQA(tonumber(id))
  if qa == nil then return nil,301 end
  qa.qa:callAction(name,table.unpack(data.args)) return 'OK',200
end

local function getDevices(p,query)
  -- Get all devices from HC3
  local qa = TQ.HC3Call('GET','/devices')
    -- Add emulated QAs 
  for id,q in pairs(TQ.DIR) do
    if id >= 5000 then qa[#qa+1] = q.device end
  end
  if next(query) then return TQ.queryFilter(query,qa),200 end   -- if query, filter the list.
  return qa,200
end

function TQ.addStandardAPIRoutes(route) -- Adds standard API routes to a route object.

  route:addOver('GET/devices',function(p,query,...) return getDevices(p,query,...) end)
  route:add('GET/devices/<id>',function(p,id,d)  -- Fetch our local device structure
    local qa = TQ.getQA(tonumber(id))
    if qa == nil then return nil,301 end
    return qa.device,200 
  end)
  route:add('POST/devices/<id>/action/<name>',callAction)       -- Call to ourself
  route:add('GET/devices/<id>/properties/<name>',getProp) -- Get properties from ourselves, fetch it locally
  
  route:add('GET/quickApp/export/<id>',function(p,id,_)  -- Get our local QA
    local qa = TQ.getQA(tonumber(id))
    if qa == nil then return nil,301 end
    return TQ.getFQA(tonumber(id)),200 
  end)

  local function getQAfiles() end
  local function createQAfile() end
  local function setQAfiles() end
  local function deleteQAfiles() end
  -- QuickApp file methods 
  route:add('GET/quickApp/<id>/files', function (p,id) return getQAfiles(id,id,nil) end)
  route:add('GET/quickApp/<id>/files/<name>', function (p,id,name) return getQAfiles(p,id,name) end)
  route:add('POST/quickApp/<id>/files', createQAfile)
  route:add('PUT/quickApp/<id>/files/<name>', setQAfiles)
  route:add('PUT/quickApp/<id>/files', function (p,id,...) return setQAfiles(p,id,nil,...) end)
  route:add('DELETE/quickApp/<id>/files/<name>', deleteQAfiles)
    
  route:add('PUT/plugins/<id>/variables/<name>', function(p,...) return internalStoragePut(...) end) --id,key,data
  route:add('POST/plugins/<id>/variables', function(p,...) return internalStoragePost(...) end) --id,data
  route:add('GET/plugins/<id>/variables/<name>', function(p,...) return internalStorageGet(...) end) --id,key,data
  route:add('GET/plugins/<id>/variables', function(p,id,...) return internalStorageGet(id,...) end) --id,nil,data
  route:add('DELETE/plugins/<id>/variables/<name>', function(p,...) return internalStorageDelete(...) end) --id,key,data

end

TQ.internalStoragePut = internalStoragePut
TQ.internalStoragePost = internalStoragePost
TQ.internalStorageGet = internalStorageGet
TQ.internalStorageDelete = internalStorageDelete