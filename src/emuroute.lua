--[[ Emulator api routes
--]]

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

local function findFile(name,files)
  for i,f in ipairs(files) do if f.name == name then return i end end
end

local function getQAfiles(p,id,name) 
  local qa = TQ.getQA(tonumber(id))
  if not qa then return nil,301 end
  if name == nil then
    local fs = {}
    for _,f in ipairs(qa.files) do
      fs[#fs+1] = {name=f.name, type='lua', isMain=false}
    end
    fs[#fs+1] = {name='main', type='lua', isMain=true}
    return fs,200
  end
end

local function createQAfile(p,id,data) 
  local qa = TQ.getQA(tonumber(id))
  if not qa then return nil,301 end
  if findFile(data.name,qa.files) then return nil,409 end
  data.fname="new" -- What fname to give it?
  table.insert(qa.files,data)
  qa.env.plugin.restart() -- Restart the QA
end

local function setQAfiles(p,id,name,data) 
  local qa = TQ.getQA(tonumber(id))
  if not qa then return nil,301 end
  if name then
    local i = findFile(name,qa.files)
    if not i then return nil,404 end
    qa.files[i] = data
    qa.env.plugin.restart()
  else return nil,505 end
end

local function deleteQAfiles(p,id,name) 
  local qa = TQ.getQA(tonumber(id))
  if not qa then return nil,301 end
  local i = findFile(name,qa.files)
  if i then 
    table.remove(qa.files,i) 
    qa.env.plugin.restart()
  else return nil,404 end
end

--------------- EmuRoute -----------------------------------------------------------------

function TQ.EmuRoute() -- Create emulator route, redirecting API calls to emulated devices
  local route = TQ.route.createRouteObject()

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

  return route
end
