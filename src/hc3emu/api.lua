--[[ Emulator api routes
--
-- API Routes Summary:
--
-- Devices:
--   GET/devices                           - Get all devices (with filtering)
--   GET/devices/<id>                      - Get device by ID
--   GET/devices/<id>/properties/<name>    - Get device property
--   POST/devices/<id>/action/<name>       - Call device action
--   PUT/devices/<id>                      - Update device
--   DELETE/devices/<id>                   - Delete device
--
-- Global Variables:
--   GET/globalVariables                   - Get all global variables
--   GET/globalVariables/<name>            - Get global variable by name
--   POST/globalVariables                  - Create global variable
--   PUT/globalVariables/<name>            - Update global variable
--   DELETE/globalVariables/<name>         - Delete global variable
--
-- Rooms:
--   GET/rooms                             - Get all rooms
--   GET/rooms/<id>                        - Get room by ID
--   POST/rooms                            - Create room
--   POST/rooms/<id>/action/setAsDefault   - Set room as default
--   POST/rooms/<id>/groupAssignment       - Assign devices to room, ToDo
--   PUT/rooms/<id>                        - Update room
--   DELETE/rooms/<id>                     - Delete room
--
-- Sections:
--   GET/sections                          - Get all sections
--   GET/sections/<id>                     - Get section by ID
--   POST/sections                         - Create section
--   PUT/sections/<id>                     - Update section
--   DELETE/sections/<id>                  - Delete section
--
-- Custom Events:
--   GET/customEvents                      - Get all custom events
--   GET/customEvents/<name>               - Get custom event by name
--   POST/customEvents                     - Create custom event
--   POST/customEvents/<name>              - Trigger custom event
--   PUT/customEvents/<name>               - Update custom event
--   DELETE/customEvents/<name>            - Delete custom event
--
-- Scenes:
--   GET/scenes                            - Get all scenes
--   GET/scenes/<id>                       - Get scene by ID
--   POST/scenes/<id>/<name>               - Execute scene action
--
-- Plugins:
--   POST/plugins/updateProperty           - Update plugin property
--   POST/plugins/interfaces               - Update plugin interfaces
--   POST/plugins/updateView               - Update plugin view
--   POST/plugins/restart                  - Restart plugin
--   POST/plugins/createChildDevice        - Create child device
--   DELETE/plugins/removeChildDevice/<id> - Remove child device
--   POST/plugins/publishEvent             - Publish event
--   GET/plugins/<id>/variables            - Get plugin variables
--   GET/plugins/<id>/variables/<name>     - Get plugin variable by name
--   POST/plugins/<id>/variables           - Create plugin variable
--   PUT/plugins/<id>/variables/<name>     - Update plugin variable
--   DELETE/plugins/<id>/variables/<name>  - Delete plugin variable
--   DELETE/plugins/<id>/variables         - Delete all plugin variables
--
-- QuickApp:
--   GET/quickApp/<id>/files              - Get all QuickApp files
--   POST/quickApp/<id>/files             - Create QuickApp file
--   GET/quickApp/<id>/files/<name>       - Get QuickApp file by name
--   PUT/quickApp/<id>/files/<name>       - Update QuickApp file
--   PUT/quickApp/<id>/files              - Update all QuickApp files
--   DELETE/quickApp/<id>/files/<name>    - Delete QuickApp file
--   GET/quickApp/export/<id>             - Export QuickApp
--   POST/quickApp/                       - Create QuickApp
--
-- Debug:
--   POST/debugMessages                    - Send debug messages
--
-- Users:
--   GET/users                             - Get all users
--   GET/users/<id>                        - Get user by ID
--   POST/users                            - Create user
--   PUT/users/<id>                        - Update user
--   DELETE/users/<id>                     - Delete user
--
-- Other:
--   GET/panels/location                   - Get location panels
--   GET/panels/location/<id>              - Get location panel by ID
--   POST/panels/location                  - Create location panel
--   PUT/panels/location/<id>              - Update location panel
--   DELETE/panels/location/<id>           - Delete location panel
--   GET/settings/location                 - Get location settings
--   GET/settings/info                     - Get system info
--   GET/weather                           - Get weather information
--   PUT/weather                           - Set weather information (for debugging)

--]]

local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local fmt = string.format
local json = require("hc3emu.json")
local lclass = require("hc3emu.class")

local function hc3(api)
  local self = { sync={}}
  local function call(method,path,data,headers)
    return E:HC3Call(method,path,data)
  end
  function self.get(path) return call("GET",path) end
  function self.post(path,data) return call("POST",path,data) end
  function self.put(path,data) return call("PUT",path,data) end
  function self.delete(path) return call("DELETE",path) end
  local seqID = 0
  local function syncCall(method,path,data)
    if not api.helper then return nil,501 end
    local req = json.encode({method=method,path=path,data=data or {},seqID=seqID}).."\n"
    seqID = seqID + 1
    local resp = api.helper.connection:send(req)
    if resp then
      local data = json.decode(resp)
      local res,code = table.unpack(data)
      if res == json.null then res = nil end
      E:DEBUGF('http',"HTTP %s %s %s",method,path,code)
      return res,code
    end
    return nil,404
  end
  function self.sync.get(path) return syncCall("GET",path) end
  function self.sync.post(path,data) return syncCall("POST",path,data) end
  function self.sync.put(path,data) return syncCall("PUT",path,data) end
  function self.sync.delete(path) return syncCall("DELETE",path) end
  return self
end

local API  = lclass('API')

function API:__init(dispatcher)
  self.E = E
  self.helper = E.helper
  self.DIR = { GET={}, POST={}, PUT={}, DELETE={} }
  self.dispatcher = dispatcher
  self.offline = dispatcher.offline
  self.db = self.dispatcher.db
  self.hc3 = hc3(self)
  
  function self.get(path) return self:call("GET",path) end
  function self.post(path,data) return self:call("POST",path,data) end
  function self.delete(path) return self:call("DELETE",path) end
  function self.put(path,data) return self:call("PUT",path,data) end
  
  self:setup()
end

function API:start()
  if not self.offline then E.helper.start() end
  if self.offline then self:loadResources(self) end
end

local converts = {
  ['<id>'] = function(v) return tonumber(v) end,
  ['<name>'] = function(v) return v end,
}

function API:add(method, path, handler)
  if type(path) == 'function' then -- shift args
    handler = path 
    method,path = method:match("(.-)(/.+)") -- split method and path
  end
  local path = string.split(path,'/')
  local d = self.DIR[method:upper()]
  for _,p in ipairs(path) do
    local p0 = p
    p = ({['<id>']=true,['<name>']=true})[p] and '_match' or p
    local d0 = d[p]
    if d0 == nil then d[p] = {} end
    if p == '_match' then d._fun = converts[p0] d._var = p0:sub(2,-2) end
    d = d[p]
  end
  assert(d._handler == nil,fmt("Duplicate path: %s/%s",method,path))
  d._handler = handler
end

local urldecode = function(url)
  return (url:gsub("%%(%x%x)", function(x) return string.char(tonumber(x, 16)) end))
end

local function parseQuery(queryStr)
  local params = {}
  local query = urldecode(queryStr)
  local p = query:split("&")
  for _,v in ipairs(p) do
    local k,v = v:match("(.-)=(.*)")
    params[k] = tonumber(v) or v
  end
  return params
end

function API:getRoute(method,path)
  local pathStr,queryStr = path:match("(.-)%?(.*)") 
  path = pathStr or path
  local query = queryStr and parseQuery(queryStr) or {}
  local path = string.split(path,'/')
  local d,vars = self.DIR[method:upper()],{}
  for _,p in ipairs(path) do
    if d._match and not d[p] then 
      local v = d._fun(p)
      if v == nil then return nil,vars end
      vars[d._var] =v 
      p = '_match'
    end
    local d0 = d[p]
    if d0 == nil then return nil,vars end
    d = d0
  end
  return d._handler,vars,query
end

function API:call(method, path, data) 
  local handler, vars, query = self:getRoute(method, path)
  if not handler then
    if not self.offline then
      E:DEBUG("API not implemented: %s %s - trying HC3",method,path)
      return self.hc3[method:lower()](path,data)
    end
    return nil, 501 
  end
  return handler({method=method, path=path, data=data, vars=vars, query=query})
end

local filterkeys = {
  parentId=function(d,v) return tonumber(d.parentId) == tonumber(v) end,
  name=function(d,v) return d.name == v end,
  type=function(d,v) return d.type == v end,
  enabled=function(d,v) return tostring(d.enabled) == tostring(v) end,
  visible=function(d,v) return tostring(d.visible) == tostring(v) end,
  roomID=function(d,v) return tonumber(d.roomID) == tonumber(v) end,
  interface=function(d,v)
    local ifs = d.interfaces
    for _,i in ipairs(ifs) do if i == v then return true end end
  end,
  property=function(d,v)
    local prop,val = v:match("%[([^,]+),(.+)%]")
    if not prop then return false end
    return tostring(d.properties[prop]) == tostring(val)
  end,
}

-- local var = api.get("/devices?property=[lastLoggedUser,"..val.."]") 
local function filter1(q,d)
  for k,v in pairs(q) do 
    if not(filterkeys[k] and filterkeys[k](d,v)) then return false end 
  end
  return true
end

local function filter(q,ds)
  local r = {}
  for _,d in pairs(ds) do if filter1(q,d) then r[#r+1] = d end end
  return r
end

function API:setup()
  local db = self.db
  self.ED = self.dispatcher

  local function num(x) return tonumber(x) or x end
  local function get(ctx,typ) return db:get(typ,num(ctx.vars[1])) end
  local function mod(ctx,typ) return db:modify(typ,num(ctx.vars[1]),ctx.data) end
  local function event(typ,data)
    return self.ED:newLocalEvent({type=typ,data=data})
  end
  self:add("GET/devices",function(ctx)
    local devices,code = db:get('devices')
    if not devices then return nil,code end
    devices = filter(ctx.query,devices)
    return devices,200
  end)
  self:add("GET/devices/<id>",function(ctx) return db:get('devices',ctx.vars.id) end)
  self:add("GET/devices/<id>/properties/<name>",function(ctx)
    local device,code = db:get('devices',ctx.vars.id)
    if not device then return nil, code end
    return {value=device.properties[ctx.vars.name],modified=device.modified or os.time()}, 200
  end)

  local function call(qa,action,data)  
    local id = qa.id
    if qa.device.parentId and qa.device.parentId > 0 then
      qa = E:getQA(qa.device.parentId)
      assert(qa,"Parent QA not found")
    end
    qa:onAction(id,{actionName=action, deviceId=id, args=data.args})
    return 'OK',200
  end

  self:add("POST/devices/<id>/action/<name>",function(ctx) 
    local id = ctx.vars.id
    local qa = E:getQA(id)
    if qa then
      return call(qa,ctx.vars.name,ctx.data)
    elseif not self.offline then
      return self.hc3.post(ctx.path,ctx.data)
    else
      return nil,501
    end
  end)
  self:add("GET/devices/<id>/action/<name>",function(ctx)
    local id = ctx.vars.id
    local qa = E:getQA(id)
    local action = ctx.vars.name
    if qa then
      local data,args = {},{}
      for k,v in pairs(ctx.query) do data[#data+1] = {k,v} end
      table.sort(data,function(a,b) return a[1] < b[1] end)
      for _,d in ipairs(data) do args[#args+1] = d[2] end
      return call(qa,action,{args=args})
    elseif not self.offline then
      return self.hc3.get(ctx.path)
    end
    return nil,501
  end)

  self:add("PUT/devices/<id>",function(ctx) 
    local data = table.copy(ctx.data)
    data.id = ctx.vars.id
    return event('DeviceModifiedEvent',data)
  end)

  self:add("DELETE/devices/<id>",function(ctx) 
    local id = ctx.vars.id
    return event('DeviceRemovedEvent',{id=id})
  end)

  self:add("GET/globalVariables",function(ctx) return db:get('globalVariables') end)
  self:add("GET/globalVariables/<name>",function(ctx) return db:get('globalVariables',ctx.vars.name) end)
  self:add("POST/globalVariables",function(ctx)
    local data = table.copy(ctx.data)
    data.variableName = data.name
    data.name = nil
    return event('GlobalVariableAddedEvent',data)
  end)
  self:add("PUT/globalVariables/<name>",function(ctx)
    local data = table.copy(ctx.data)
    data.variableName = ctx.vars.name
    data.name = nil
    return event('GlobalVariableChangedEvent',data)
  end)
  self:add("DELETE/globalVariables/<name>",function(ctx)
    return event('GlobalVariableRemovedEvent',{variableName=ctx.vars.name})
  end)
  
  self:add("GET/rooms",function(ctx) return db:get("rooms") end)
  self:add("GET/rooms/<id>",function(ctx) return db:get("rooms",ctx.vars.id) end)
  self:add("POST/rooms",function(ctx) 
    return event('RoomCreatedEvent',ctx.data) 
  end)
  self:add("POST/rooms/<id>/action/setAsDefault",function(ctx) 
    local id = ctx.vars.id
    self.db.defaultRoom = id
    if not self.offline then
      return self.hc3.post("/rooms/"..id.."/action/setAsDefault",{})
    else return id,200 end
  end)
  self:add("POST/rooms/<id>/groupAssignment",function(ctx)
    if not self.offline then
      return self.hc3.post(ctx.path,ctx.data)
    else 
      local roomID = ctx.vars.id
      for _,id in ipairs(ctx.data.deviceIds or {}) do
        event('DeviceModifiedEvent',{id=id,roomID=roomID})
      end
      return roomID,200
    end
  end)
  self:add("PUT/rooms/<id>",function(ctx) 
    local data = table.copy(ctx.data)
    data.id = ctx.vars.id
    return event('RoomModifiedEvent',data) 
  end)
  self:add("DELETE/rooms/<id>",function(ctx) 
    return event('RoomRemovedEvent',{id=ctx.vars.id})
  end)

  self:add("GET/sections",function(ctx) return db:get('sections') end)
  self:add("GET/sections/<id>",function(ctx) return db:get('sections',ctx.vars.id) end)
  self:add("POST/sections",function(ctx) 
    return event('SectionCreatedEvent',ctx.data)
  end)
  self:add("PUT/sections/<id>",function(ctx) 
    local data = table.copy(ctx.data)
    data.id = ctx.vars.id
    return event('SectionModifiedEvent',data)
  end)
  self:add("DELETE/sections/<id>",function(ctx) 
    return event('SectionRemovedEvent',{id=ctx.vars.id})
  end)

  self:add("GET/customEvents",function(ctx) return db:get('customEvents') end)
  self:add("GET/customEvents/<name>",function(ctx) return db:get('customEvents',ctx.vars.name) end)
  self:add("POST/customEvents",function(ctx) 
    return event('CustomEventCreatedEvent',ctx.data)
  end)
  self:add("POST/customEvents/<name>",function(ctx) 
    if not self.offline then
      self.hc3.post(ctx.path)
    else
      local event = db:get('customEvents',ctx.vars.name)
      if event then 
        return event('CustomEvent',ctx.data)
      else return nil,404 end
    end
  end)
  self:add("PUT/customEvents/<name>",function(ctx) 
    local data = table.copy(ctx.data)
    data.name = ctx.vars.name
    return event('CustomEventModifiedEvent',data)
  end)
  self:add("DELETE/customEvents/<name>",function(ctx) 
    return event('CustomEventRemovedEvent',{name=ctx.vars.name})
  end)

  self:add("GET/scenes",function(ctx) return db:get('scenes') end)
  self:add("GET/scenes/<id>",function(ctx) return db:get('scenes',ctx.vars.id) end)
  self:add("POST/scenes/<id>/<name>" , function(ctx)
    local id = ctx.vars.id
    local name = ctx.vars.name
    local scene = E:getScene(id)
    if scene then
      assert(name=='execute',"Invalid scene action")
      return scene:trigger({type='user', property='execute',id=2}),200
    elseif not self.offline then
      return self.hc3.post(ctx.path)
    else return nil,501 end
  end) 
  
  self:add("GET/weather",function(ctx) return db:get('weather') end)
  self:add("PUT/weather",function(ctx) -- for debugging
    return event('WeatherChangedEvent',ctx.data)
  end)

  self:add("POST/plugins/updateProperty",function(ctx)
    local data = ctx.data
    local id = data.deviceId
    local args = {id=id,property=data.propertyName,newValue=data.value}
    local res,code = event('DevicePropertyUpdatedEvent',args)
    return res,code
  end)

  self:add("POST/plugins/updateView",function(ctx) 
    local data = ctx.data
    local qa = E:getQA(data.deviceId)
    if qa then
      qa:updateView(data)
      return nil,200
    elseif not self.offline then
      return self.hc3.post(ctx.path,ctx.data)
    else return nil,501 end
  end)

  self:add("POST/plugins/interfaces",function(ctx) 
    local data = ctx.data
    local id = data.deviceId
    if not self.offline then
      local res,code = self.hc3.sync.post(ctx.path,ctx.data)
      return res,code
    else return nil,501 end
  end)

  self:add("POST/plugins/restart",function(ctx)
    local id = ctx.data.deviceId
    local qa = E:getQA(id)
    if qa then
      return qa:restart(),200
    elseif not self.offline then
      return self.hc3.post(ctx.path)
    else return nil,501 end
  end)
  self:add("POST/plugins/createChildDevice",function(ctx) 
    local qa = E:getQA(ctx.data.parentId)
    if qa then return qa:createChildDevice(ctx.data)
    elseif not self.offline then
      return self.hc3.post(ctx.path,ctx.data)
    else return nil,501 end
  end)
  self:add("DELETE/plugins/removeChildDevice/<id>",function(ctx)
    local id = tonumber(ctx.vars.id)
    local child = db:get('devices',id)
    if not child.parentId or child.parentId == 0 then
      return nil,404
    end
    local parent = E:getQA(child.parentId)
    if parent and not parent.isProxy or self.offline then
      self.dispatcher:addEvent({type='DeviceRemovedEvent',data={id=id}})
      return db:delete('devices',id) 
    else 
      return self.hc3.delete(ctx.path)
    end
  end)
  
  self:add("POST/debugMessages",function(ctx)
    local qa = E:getQA(ctx.data.deviceId)
    if qa then
      return qa:debugMessages(ctx.data),200
    elseif not self.offline then
      return self.hc3.post(ctx.path,ctx.data)
    else return nil,501 end
  end)
  
  self:add("POST/plugins/publishEvent",function(ctx) 
    if self.offline then 
      return nil,501
    else return self.hc3.sync.post(ctx.path,ctx.data) end
  end)
  
  self:add("GET/panels/location",function(ctx) return db:get('panels/location') end)
  self:add("GET/panels/location/<id>",function(ctx) return db:get('panels/location',ctx.vars.id) end)
  self:add("POST/panels/location",function(ctx)
    return event('LocationCreatedEvent',ctx.data)
  end)
  self:add("PUT/panels/location/<id>",function(ctx)
    local data = table.copy(ctx.data)
    data.id = ctx.vars.id
    return event('LocationModifiedEvent',data)
  end)
  self:add("DELETE/panels/location/<id>",function(ctx)
    return event('LocationRemovedEvent',{id=ctx.vars.id})
  end)

  self:add("GET/settings/location",function(ctx) return db:get('settings/location') end)
  self:add("GET/settings/info",function(ctx) return db:get('settings/info') end)

  self:add("GET/users",function(ctx) return db:get('users') end)
  self:add("GET/users/<id>",function(ctx) return db:get('users',ctx.vars.id) end)
  self:add("POST/users",function(ctx)
    return event('UserCreatedEvent',ctx.data)
  end)
  self:add("PUT/users/<id>",function(ctx)
    local data = table.copy(ctx.data)
    data.id = ctx.vars.id
    return event('UserModifiedEvent',data)
  end)
  self:add("DELETE/users/<id>",function(ctx)
    return event('UserRemovedEvent',{id=ctx.vars.id})
  end)

  self:add("GET/quickApp/<id>/files",function(ctx) 
    local qa = E:getQA(ctx.vars.id)
    if not self.offline and not qa then
      return self.hc3.get(ctx.path)
    end
    if qa then
      if qa.isChild then return nil,501 end
      local res = qa:getFile()
      if res then return res, 200 end
    end
    return nil, 404
  end)
  self:add("POST/quickApp/<id>/files",function(ctx) 
    local qa = E:getQA(ctx.vars.id)
    if not self.offline and not qa then
      return self.hc3.post(ctx.path,ctx.data)
    end
    if qa then
      if qa.isChild then return nil,501 end
      local res = qa:createFile(ctx.data)
      if res then return res, 200 end
    end
    return nil, 404
  end)
  self:add("GET/quickApp/<id>/files/<name>",function(ctx) 
    local qa = E:getQA(ctx.vars.id)
    if not self.offline and not qa then
      return self.hc3.get(ctx.path)
    end
    if qa then
      if qa.isChild then return nil,501 end
      local name = ctx.vars.name
      local res = qa:getFile(name)
      if res then return res, 200 end
    end
    return nil, 404
  end)
  self:add("PUT/quickApp/<id>/files/<name>",function(ctx)
    local qa = E:getQA(ctx.vars.id)
    if not self.offline and not qa then
      return self.hc3.put(ctx.path,ctx.data)
    end
    if qa then
      if qa.isChild then return nil,501 end
      local name = ctx.vars.name
      local res = qa:writeFile(name,ctx.data)
      if res then return res, 200 end
    end
    return nil, 404
  end)
  self:add("PUT/quickApp/<id>/files",function(ctx) 
    local qa = E:getQA(ctx.vars.id)
    if not self.offline and not qa then
      return self.hc3.put(ctx.path,ctx.data)
    end
    if qa then
      if qa.isChild then return nil,501 end
      local res = qa:writeFile(nil,ctx.data)
      if res then return res, 200 end
    end
    return nil, 404
  end)
  self:add("DELETE/quickApp/<id>/files/<name>",function(ctx) 
    local qa = E:getQA(ctx.vars.id)
    if not self.offline and not qa then
      return self.hc3.delete(ctx.path)
    end
    if qa then
      if qa.isChild then return nil,501 end
      local name = ctx.vars.name
      local res = qa:deleteFile(name)
      if res then return res, 200 end
    end
    return nil, 404
  end)
  
  self:add("GET/quickApp/export/<id>",function(ctx)
    local id = ctx.vars.id
    local qa = E:getQA(id)
    if qa then
      if qa.isChild then return nil,501 end
      return qa:createFQA(),200
    end
    if not self.offline then
      return self.hc3.get(ctx.path)
    end
    return nil, 501
  end)
  self:add("POST/quickApp/",function(ctx) 
    local info = E.tools.installFQAstruct(ctx.data)
    if info then return info.device,201 else return nil,401 end
  end)
  
  local function isProxy(id) local qa = E:getQA(id) return qa and qa.isProxy end

  -- These we run via emuHelper with hc3.sync.* because they are not allowed remotely
  self:add("GET/plugins/<id>/variables",function(ctx) 
    local id = ctx.vars.id
    if not self.offline and isProxy(id) then
      return self.hc3.sync.get(ctx.path)
    end
    local vars = db.db.internalStorage.items[tostring(id)]
    if not vars then return nil, 404 end
    local res = {}
    for k,v in pairs(vars) do res[#res+1]= {name=k, value=v, isHidden=false} end
    return res,200
  end)
  self:add("GET/plugins/<id>/variables/<name>",function(ctx) 
    local id = ctx.vars.id
    if not self.offline and isProxy(id) then
      return self.hc3.sync.get(ctx.path)
    end
    local vars = db.db.internalStorage.items[tostring(id)]
    local name = ctx.vars.name
    if not (vars and vars[name] ~= nil) then return nil, 404 end
    return {value=vars[name],name=name, isHidden=false},200
  end)
  self:add("POST/plugins/<id>/variables",function(ctx) 
    local id = ctx.vars.id
    local ids = tostring(id)
    if not self.offline and isProxy(id) then
      return self.hc3.sync.post(ctx.path,ctx.data)
    end
    local data = ctx.data
    local vars = db.db.internalStorage.items[ids]
    if vars == nil then vars = {} db.db.internalStorage.items[ids] = vars end
    if vars[data.name] ~= nil then return nil, 409 end
    vars[data.name] = data.value
    E:flushState()
    return nil,200
  end)
  self:add("PUT/plugins/<id>/variables/<name>",function(ctx)
    local id = ctx.vars.id
    local ids = tostring(id)
    if not self.offline and isProxy(id) then
      return self.hc3.sync.put(ctx.path,ctx.data)
    end
    local data = ctx.data
    local vars = db.db.internalStorage.items[ids]
    if not (vars and vars[ctx.vars.name]~=nil) then return nil, 404 end
    vars[ctx.vars.name] = data.value
    E:flushState()
    return data.value, 200
  end)
  self:add("DELETE/plugins/<id>/variables/<name>",function(ctx)
    local id = ctx.vars.id
    local ids = tostring(id)
    if not self.offline and isProxy(id) then
      return self.hc3.sync.delete(ctx.path)
    end
    local vars = db.db.internalStorage.items[ids]
    local name = ctx.vars.name
    if not (vars and vars[name]~=nil) then return nil, 404 end
    vars[name] = nil
    E:flushState()
    return nil, 200
  end)
  self:add("DELETE/plugins/<id>/variables",function(ctx)
    local id = ctx.vars.id
    local ids = tostring(id)
    if not self.offline and isProxy(id) then
      return self.hc3.sync.delete(ctx.path)
    end
    local vars = db.db.internalStorage
    if vars.items[ids] == nil then return nil, 404 end
    vars.items[ids] = {}
    E:flushState()
    return nil, 200
  end)
end

exports.API = API
return exports
