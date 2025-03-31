-- WORK IN PROGRESS...
--[[
GET/globalVariables
GET/globalVariables/<name>
POST/globalVariables data
PUT/globalVariables/<name> data

GET/devices/
GET/devices/<id>
GET/devices/<id>/properties/<property>
GET/devices?parentId=<id>
GET/devices?name=<name>
PUT/devices/<id> data
POST/devices/<id>/action/<name> data
DELETE/devices/<id>

GET/rooms
GET/rooms/<id>

POST/plugins/updateProperty data
POST/plugins/updateView data
POST/plugins/publishEvent data

POST/plugins/createChildDevice data
DELETE/plugins/removeChildDevice/<id>

GET/alarms/v1/partitions/<id>
GET/alarms/v1/partitions

POST/customEvents/<name>
--]]

local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local json = require("hc3emu.json")
local function printf(...) print(string.format(...)) end

local DB,refresh

local function init() 
  DB = E.store.DB 
  E.route.OfflineRoute = exports.OfflineRoute
  refresh = E.refreshState.post
end

local filterkeys = {
  parentId=function(d,v) return tonumber(d.parentId) == tonumber(v) end,
  name=function(d,v) return d.name == v end,
  type=function(d,v) return d.type == v end,
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
  for k,v in pairs(q) do if not(filterkeys[k] and filterkeys[k](d,v)) then return false end end
  return true
end

local function filter(q,ds)
  local r = {}
  for _,d in pairs(ds) do
    if filter1(q,d) then r[#r+1] = d end
  end
  return r
end

local function rerror(code,msg) error({code=code,message=msg}) end
local function valueList(t) local r = {} for _,v in pairs(t) do r[#r+1]=v end return r end
local function DEVICE(id) id = tonumber(id) if DB.devices[id] then return DB.devices[id],200 else rerror(404,"not found") end end

local function CHK(x,v,e) if x==nil then return nil,e else return x,v end end

------------- GlobalVariables -------------------
local function getGlobals(p,name) 
  if name then return CHK(DB.globalVariables[name],200,404) 
  else return valueList(DB.globalVariables),200 end
end

local function createGlobal(p,data)
  local d = {name=data.name,value=data.value,created=os.time(),modified=os.time(),readOnly=false,isEnum=false,enumValues={}}
  DB.globalVariables[data.name]=d 
  refresh.GlobalVariableAddedEvent(data.name,data.value)
  return d,201
end

local function setGlobal(p,name,data)
  local d = DB.globalVariables[name]
  if not d then return nil,404 
  else  
    local oldValue = d.value
    d.value = data.value 
    refresh.GlobalVariableChangedEvent(data.name,d.value,oldValue)
    return d,200 
  end
end

local function deleteGlobal(p,name) 
  if not DB.globalVariables[name] then return nil,404 
  else  
    DB.globalVariables[name].value = nil 
    refresh.GlobalVariableRemovedEvent(name)
    return nil,200
  end 
end

--------------------- Rooms -----------------------
local function getRooms(p,id,_) 
  if id then return CHK(DB.rooms[id],200,404) else 
  return valueList(DB.rooms),200 end
end

local ROOM_ID = 9000
local SECTION_ID = 10000
local function getNextRoomId() ROOM_ID=ROOM_ID+1 return ROOM_ID end
local function getNextSectionId() SECTION_ID=SECTION_ID+1 return SECTION_ID end

local function createRoom(p,data) 
  local id = getNextRoomId()
  local room = {id=id,name=data.name,devices={}}
  DB.rooms[id] = room
  refresh.RoomCreatedEvent(id)
  return room,201
end

local function putRoom(p,id,data) 
  id = tonumber(id)
  local room = DB.rooms[id]
  if not room then return nil,404 end
  room.name = data.name or room.name
  refresh.RoomModifiedEvent(id)
  return room,200
end

local function deleteRoom(p,id) 
  id = tonumber(id) assert(id,"Room ID must be a number")
  if not DB.rooms[id] then return nil,404 end 
  DB.rooms[id] = nil 
  refresh.RoomRemovedEvent(id)
  return true,200
end
--------------------- Sections -----------------------
local function getSections(p,id,_) if id then return CHK(DB.sections[id],200,404) else return valueList(DB.sections),200 end end

local function createSection(p,data) 
  local id = getNextSectionId()
  local section = {id=id,name=data.name,devices={}}
  DB.sections[id] = section
  refresh.SectionCreatedEvent(tonumber(id))
  return section,201
end

local function putSection(p,id,data)
  id = tonumber(id)
  local section = DB.sections[id]
  if not section then return nil,404 end
  section.name = data.name or section.name
  refresh.SectionModifiedEvent(id)
  return section,200
end

local function deleteSection(p,id) 
  id = tonumber(id) assert(id,"Section ID must be a number")
  if not DB.sections[id] then return nil,404 end 
  DB.sections[id] = nil 
  refresh.SectionRemovedEvent(id)
  return true,200
end

--------------------- CustomEvents -----------------------
local function getCustom(p,name,...) 
  if name then return CHK(DB.customEvents[name],200,404) 
  else return valueList(DB.customEvents),200 end
end

local function createCustom(p,data) 
  local name = data.name
  if DB.customEvents[name] then return nil,409 end
  local ce = {name=name,userDescription=data.userDescription or ""}
  DB.customEvents[name] = ce
  refresh.CustomEventCreatedEvent(ce.name,ce.userDescription)
  return ce,201
end
local function emitCustom(p,name) 
  local ce = DB.customEvents[name]
  if not ce then return nil,404 end
  refresh.CustomEvent(ce.name,ce.userDescription)
  return nil,200
end
local function putCustom(p,name,data) 
  local ce = DB.customEvents[name]
  if not ce then return nil,404 end
  ce.userDescription = data.userDescription or ce.userDescription
  refresh.CustomEventModifiedEvent(ce.name,ce.userDescription)
  return nil,200
end
local function deleteCustom(p,name) 
  local ce = DB.customEvents[name]
  if not ce then return nil,404 end
  DB.customEvents[name] = nil
  refresh.CustomEventRemovedEvent(name)
  return nil,200
end
-------------------- Devices -----------------------
local function getDevices(p,id,query) 
  if id then return DEVICE(id) 
  else
    if next(query) then return filter(query,DB.devices),200 end
    return valueList(DB.devices),200
  end 
end
local function getDeviceProp(p,id,property) return {value=DEVICE(id).properties[property]},200 end 
local function putDeviceKey(p,id,data) for k,v in pairs(data) do DB.devices[id][k] = v end return true,200 end

local function callAction(p,id,name,data)
  id = tonumber(id)
  local qa = E:getQA(id)
  assert(qa,"QA not found")
  if qa.device.parentId and qa.device.parentId > 0 then
    qa = E:getQA(qa.device.parentId)
    assert(qa,"Parent QA not found")
  end
  qa:onAction(id,{actionName=name,deviceId=id, args=data.args})
  return 'OK',200
end

local function deleteDevice(p,id) 
  id = tonumber(id)
  assert(id,"Device ID must be a number")
  if not DB.devices[id] then return nil,404 end 
  DB.devices[id] = nil 
  refresh.DeviceRemovedEvent(id)
  return true,200
end

local function putDeviceProp(p,data) 
  local d = data.deviceId if not d  then return nil,404 end
  local dev = DB.devices[d] if not dev then return nil,404 end
  dev.properties[data.propertyName] = data.value
  local qa = E:getQA(d)
  if qa then qa:watchesProperty(data.propertyName,data.value) end
  return nil,200
end

local function updateDeviceView(p,data)
  local qa = E:getQA(tonumber(data.deviceId))
  if not qa then return nil,301 end
  if not qa.qa then return nil,404 end
  qa:updateView(data)
  return nil,200
  --- TBD
end
local function createChild(p,data)
  local parentId = tonumber(data.parentId)
  local parent = DB.devices[parentId]
  if not parent then return nil,404 end
  local id = E:getNextDeviceId()
  local dev = {
    id=id,
    name=data.name,
    type=data.type,
    parentId=parentId,
    interfaces=data.initialInterfaces or {},
    properties=data.initialProperties or {},
  }
  DB.devices[id] = dev
  refresh.DeviceCreatedEvent(id)
  return dev,200
end

local function deleteChild(p,id)
  local id = tonumber(id)
  if not id then return nil,501 end
  if not DB.devices[id] then return nil,404 end
  DB.devices[id] = nil
  refresh.DeviceRemovedEvent(id)
  return nil,200
end

local function blocked(p) return nil,501 end
local function refreshState(p) return {},200 end
local function installFQA(p,data)
  local info = E:installFQAstruct(data)
  if info then return info.dev,200 else return nil,401 end
end

------------------- OfflineRoute -----------------------------
local function OfflineRoute()
  local route = E.route.createRouteObject()
  
  route:add('GET/globalVariables',getGlobals)
  route:add('GET/globalVariables/<name>',getGlobals)
  route:add('POST/globalVariables',createGlobal) -- data = {name="name",value="value"}
  route:add('PUT/globalVariables/<name>',setGlobal) -- data = {value="value"}
  route:add('DELETE/globalVariables/<name>',deleteGlobal) 
  
  route:add('GET/rooms',function (p,...) return getRooms(p,nil,...) end)
  route:add('GET/rooms/<id>',getRooms)
  route:add('POST/rooms',createRoom) 
  route:add('PUT/rooms/<id>',putRoom)
  route:add('DELETE/rooms/<id>',deleteRoom)
  route:add('GET/sections',function(p,...) return getSections(p,nil,...) end)
  route:add('GET/sections/<id>',getSections)
  route:add('POST/sections',createSection)
  route:add('PUT/sections/<id>',putSection)
  route:add('DELETE/sections/<id>',deleteSection)
  route:add('GET/customEvents',function (p,...) return getCustom(p,nil,...) end)
  route:add('GET/customEvents/<name>',getCustom)
  route:add('POST/customEvents',createCustom)
  route:add('POST/customEvents/<name>',emitCustom)
  route:add('PUT/customEvents/<name>',putCustom)
  route:add('DELETE/customEvents/<name>',deleteCustom)

  -- filters ?parentId=<id> ?name=<name> ?type=<type>
  route:add('GET/devices',function(p,...) return getDevices(p,nil,...) end)
  route:add('GET/devices/1',function() return DB.devices[1],200 end)
  route:add('GET/devices/<id>',getDevices)
  route:add('GET/devices/<id>/properties/<name>',getDeviceProp)
  route:add('PUT/devices/<id>',putDeviceKey) --data = {key="value"}
  route:add('POST/devices/<id>/action/<name>',callAction) --data = {args={}}
  route:add('DELETE/devices/<id>',deleteDevice)
  route:add("GET/devices/1/properties/<name>",function(p,name) 
    return {value=DB.devices[1].properties[name]},200 
  end)
  
  route:add('POST/plugins/updateProperty',putDeviceProp) -- data = {key="value"}
  route:add('POST/plugins/updateView',updateDeviceView) -- data = {key="value"}
  
  route:add('POST/plugins/createChildDevice',createChild) 
  route:add('DELETE/plugins/removeChildDevice/<id>',deleteChild)
  
  route:add('GET/alarms/v1/partitions/<id>',blocked)
  route:add('GET/alarms/v1/partitions',blocked)
  
  route:add('GET/settings/info',function() return DB.settings.info,200 end)
  route:add('GET/settings/location',function() return DB.settings.location,200 end)
  route:add('GET/home',function() return DB.home,200 end)
  
  route:add('GET/refreshStates',refreshState)
    
  route:add('POST/quickApp/',installFQA)

  return route
end

exports.OfflineRoute = OfflineRoute
exports.init = init
exports.queryFilter = filter
return exports