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

local DB = {}
local urlReg

local function getGlobals(name) if name then return DB.globalVariables[name] else return valueList(DB.globalVariables) end end
local function createGlobal(data) DB.globalVariables[data.name]=data end
local function setGlobal(name,data) DB.globalVariables[name].value = data.value end

urlReg('GET/globalVariables',getGlobals)
urlReg('GET/globalVariables/<name>',getGlobals)
urlReg('POST/globalVariables',createGlobal) -- data = {name="name",value="value"}
urlReg('PUT/globalVariables/<name>',setGlobal) -- data = {value="value"}

urlReg('GET/devices/',getDevices)
urlReg('GET/devices/<id>',getDevices)
urlReg('GET/devices/<id>/properties/<property>',getDeviceProp)
urlReg('GET/devices?parentId=<id>',getDevices)
urlReg('GET/devices?name=<name>',getDevices)
urlReg('PUT/devices/<id>',putDeviceKey) --data = {key="value"}
urlReg('POST/devices/<id>/action/<name>',callAction) --data = {args={}}
urlReg('DELETE/devices/<id>',deleteDevice)

urlReg('GET/rooms',getRooms)
urlReg('GET/rooms/<id>',getRooms)

urlReg('POST/plugins/updateProperty',putDeviceProp) -- data = {key="value"}
urlReg('POST/plugins/updateView',updateDeviceView) -- data = {key="value"}
urlReg('POST/plugins/publishEvent',publishEvent) -- data = {type="type",source="source",data={}}

urlReg('POST/plugins/createChildDevice data',blocked)
urlReg('DELETE/plugins/removeChildDevice/<id>',blocked)

urlReg('GET/alarms/v1/partitions/<id>',blocked)
urlReg('GET/alarms/v1/partitions',blocked)

urlReg('POST/customEvents/<name>',blocked)