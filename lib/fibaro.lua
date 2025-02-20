local fmt = string.format 
function __ternary(c, t,f) if c then return t else return f end end
function __fibaro_get_devices() return api.get("/devices/") end
function __fibaro_get_device(deviceId) return api.get("/devices/"..deviceId) end
function __fibaro_get_room(roomId) return api.get("/rooms/"..roomId) end
function __fibaro_get_scene(sceneId) return api.get("/scenes/"..sceneId) end
function __fibaro_get_global_variable(varName) return api.get("/globalVariables/"..varName) end
function __fibaro_get_device_property(deviceId, propertyName) return api.get("/devices/"..deviceId.."/properties/"..propertyName) end
function __fibaro_get_devices_by_type(type) return api.get("/devices?type="..type) end
function __fibaro_add_debug_message(tag, msg, typ) fibaro.hc3emu.debugOutput(tag, msg, typ, os.time()) end

function __fibaro_get_partition(id) return api.get('/alarms/v1/partitions/' .. tostring(id)) end
function __fibaro_get_partitions() return api.get('/alarms/v1/partitions') end
function __fibaro_get_breached_partitions() return api.get("/alarms/v1/partitions/breached") end
function __fibaroSleep(ms)
  fibaro.hc3emu.WARNINGF("Avoid using fibaro.sleep in QuickApps")
  fibaro.hc3emu.copas.pause(ms/1000.0)
end
function __fibaroUseAsyncHandler(_) return true end

function  fibaro.getPartition(id)
  __assert_type(id, "number")
  return __fibaro_get_partition(id)
end

function fibaro.getPartitions() return __fibaro_get_partitions() end
function fibaro.alarm(arg1, action)
  if type(arg1) == "string" then return fibaro.__houseAlarm(arg1) end
  __assert_type(arg1, "number")
  __assert_type(action, "string")
  local url = "/alarms/v1/partitions/" .. arg1 .. "/actions/arm"
  if action == "arm" then api.post(url)
  elseif action == "disarm" then api.delete(url)
  else error(fmt("Wrong parameter: %s. Available parameters: arm, disarm",action),2) end
end

function fibaro.__houseAlarm(action)
  __assert_type(action, "string")
  local url = "/alarms/v1/partitions/actions/arm"
  if action == "arm" then api.post(url)
  elseif action == "disarm" then api.delete(url)
  else error("Wrong parameter: '" .. action .. "'. Available parameters: arm, disarm", 3) end
end

function fibaro.alert(alertType, ids, notification)
  __assert_type(alertType, "string")
  __assert_type(ids, "table")
  __assert_type(notification, "string")
  local isDefined = "false"
  local actions = {
    email = "sendGlobalEmailNotifications",
    push = "sendGlobalPushNotifications",
    simplePush = "sendGlobalPushNotifications",
  }
  if actions[alertType] == nil then
    error("Wrong parameter: '" .. alertType .. "'. Available parameters: email, push, simplePush", 2)
  end
  for _,id in ipairs(ids) do __assert_type(id, "number") end
  
  if alertType == 'push' then
    local mobileDevices = __fibaro_get_devices_by_type('iOS_device')
    assert(type(mobileDevices) == 'table', "Failed to get mobile devices")
    local usersId = ids
    ids = {}
    for _, userId in ipairs(usersId) do
      for _, device in ipairs(mobileDevices) do
        if device.properties.lastLoggedUser == userId then
          table.insert(ids, device.id)
        end
      end
    end
  end
  for _, id in ipairs(ids) do
    fibaro.call(id, actions[alertType], notification, isDefined)
  end
end

function fibaro.emitCustomEvent(name)
  __assert_type(name, "string")
  api.post("/customEvents/"..name)
end

function fibaro.call(deviceId, action, ...)
  __assert_type(action, "string")
  if type(deviceId) == "table" then
    for _,id in pairs(deviceId) do __assert_type(id, "number") end
    for _,id in pairs(deviceId) do fibaro.call(id, action, ...) end
  else
    __assert_type(deviceId, "number")
    local arg = {...}
    local arg2 = #arg>0 and arg or nil
    return api.post("/devices/"..deviceId.."/action/"..action, { args = arg2 })
  end
end

function fibaro.callGroupAction(actionName, actionData)
  __assert_type(actionName, "string")
  __assert_type(actionData, "table")
  local response, status = api.post("/devices/groupAction/"..actionName, actionData)
  if status ~= 202 then return nil end
  return response and response.devices
end

function fibaro.get(deviceId, prop)
  __assert_type(deviceId, "number")
  __assert_type(prop, "string")
  prop = __fibaro_get_device_property(deviceId, prop)
  if prop == nil then return end
  return prop.value, prop.modified
end

function fibaro.getValue(deviceId, propertyName)
  __assert_type(deviceId, "number")
  __assert_type(propertyName, "string")
  return (fibaro.get(deviceId, propertyName))
end

function fibaro.getType(deviceId)
  __assert_type(deviceId, "number")
  local dev = __fibaro_get_device(deviceId)
  return dev and dev.type or nil
end

function fibaro.getName(deviceId)
  __assert_type(deviceId, 'number')
  local dev = __fibaro_get_device(deviceId)
  return dev and dev.name or nil
end

function fibaro.getRoomID(deviceId)
  __assert_type(deviceId, 'number')
  local dev = __fibaro_get_device(deviceId)
  return dev and dev.roomID or nil
end

function fibaro.getSectionID(deviceId)
  __assert_type(deviceId, 'number')
  local dev = __fibaro_get_device(deviceId)
  if dev == nil then return end
  return __fibaro_get_room(dev.roomID).sectionID
end

function fibaro.getRoomName(roomId)
  __assert_type(roomId, 'number')
  local room = __fibaro_get_room(roomId)
  return room and room.name or nil
end

function fibaro.getRoomNameByDeviceID(deviceId, propertyName)
  __assert_type(deviceId, 'number')
  local dev = __fibaro_get_device(deviceId)
  if dev == nil then return end
  local room = __fibaro_get_room(dev.roomID)
  return room and room.name or nil
end

function fibaro.getDevicesID(filter)
  if not (type(filter) == 'table' and next(filter)) then
    return fibaro.getIds(__fibaro_get_devices())
  end
  
  local args = {}
  for key, val in pairs(filter) do
    if key == 'properties' and type(val) == 'table' then
      for n,p in pairs(val) do
        if p == "nil" then
          args[#args+1]='property='..tostring(n)
        else
          args[#args+1]='property=['..tostring(n)..','..tostring(p)..']'
        end
      end
    elseif key == 'interfaces' and type(val) == 'table' then
      for _,i in pairs(val) do
        args[#args+1]='interface='..tostring(i)
      end
    else
      args[#args+1]=tostring(key).."="..tostring(val)
    end
  end
  local argsStr = table.concat(args,"&")
  return fibaro.getIds(api.get('/devices/?'..argsStr))
end

function fibaro.getIds(devices)
  local res = {}
  for _,d in pairs(devices) do
    if type(d) == 'table' and d.id ~= nil and d.id > 3 then res[#res+1]=d.id end
  end
  return res
end

function fibaro.getGlobalVariable(name)
  __assert_type(name, 'string')
  local var = __fibaro_get_global_variable(name)
  if var == nil then return end
  return var.value, var.modified
end

function fibaro.setGlobalVariable(name, value)
  __assert_type(name, 'string')
  __assert_type(value, 'string')
  return api.put("/globalVariables/"..name, {value=tostring(value), invokeScenes=true})
end

function fibaro.scene(action, ids)
  __assert_type(action, "string")
  __assert_type(ids, "table")
  assert(action=='execute' or action =='kill',"Wrong parameter: "..action..". Available actions: execute, kill")
  for _, id in ipairs(ids) do __assert_type(id, "number") end
  for _, id in ipairs(ids) do api.post("/scenes/"..id.."/"..action) end
end

function fibaro.profile(action, id)
  __assert_type(id, "number")
  __assert_type(action, "string")
  if action ~= "activeProfile" then
    error("Wrong parameter: " .. action .. ". Available actions: activateProfile", 2)
  end
  return api.post("/profiles/activeProfile/"..id)
end

local FUNCTION = "func".."tion"
function fibaro.setTimeout(timeout, action, errorHandler)
  __assert_type(timeout, "number")
  __assert_type(action, FUNCTION)
  local fun = action
  if errorHandler then
    fun = function()
      local stat,err = pcall(action)
      if not stat then pcall(errorHandler,err) end
    end
  end
  return setTimeout(fun, timeout)
end

function fibaro.clearTimeout(ref)
  __assert_type(ref, "number")
  clearTimeout(ref)
end

function fibaro.wakeUpDeadDevice(deviceID)
  __assert_type(deviceID, 'number')
  fibaro.call(1,'wakeUpDeadDevice',deviceID)
end

function fibaro.sleep(ms)
  __assert_type(ms, "number")
  __fibaroSleep(ms)
end

local function concatStr(...)
  local args = {}
  for _,o in ipairs({...}) do args[#args+1]=tostring(o) end
  return table.concat(args," ")
end

function fibaro.debug(tag, ...)
  __assert_type(tag, "string")
  __fibaro_add_debug_message(tag, concatStr(...), "debug")
end

function fibaro.warning(tag, ...)
  __assert_type(tag, "string")
  __fibaro_add_debug_message(tag,  concatStr(...), "warning")
end

function fibaro.error(tag, ...)
  __assert_type(tag, "string")
  __fibaro_add_debug_message(tag,  concatStr(...), "error")
end

function fibaro.trace(tag, ...)
  __assert_type(tag, "string")
  __fibaro_add_debug_message(tag,  concatStr(...), "trace")
end

function fibaro.useAsyncHandler(value)
  __assert_type(value, "boolean")
  __fibaroUseAsyncHandler(value)
end

function fibaro.isHomeBreached()
  local ids = __fibaro_get_breached_partitions()
  assert(type(ids)=="table")
  return next(ids) ~= nil
end

function fibaro.isPartitionBreached(partitionId)
  __assert_type(partitionId, "number")
  local ids = __fibaro_get_breached_partitions()
  assert(type(ids)=="table")
  for _,id in pairs(ids) do
    if id == partitionId then return true end
  end
end

function fibaro.getPartitionArmState(partitionId)
  __assert_type(partitionId, "number")
  local partition = __fibaro_get_partition(partitionId)
  if partition ~= nil then
    return partition.armed and 'armed' or 'disarmed'
  end
end

function fibaro.getHomeArmState()
  local n,armed = 0,0
  local partitions = __fibaro_get_partitions()
  assert(type(partitions)=="table")
  for _,partition in pairs(partitions) do
    n = n + 1; armed = armed + (partition.armed and 1 or 0)
  end
  if armed == 0 then return 'disarmed'
  elseif armed == n then return 'armed'
  else return 'partially_armed' end
end