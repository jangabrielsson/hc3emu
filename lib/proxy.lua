local DEBUGF = TQ.DEBUGF
local DEBUG = TQ.DEBUG
local fibaro = TQ.fibaro
local api = TQ.api
local plugin = TQ.plugin
local copas = TQ.copas
local socket = TQ.socket
local json = TQ.json
local mobdebug = TQ.mobdebug
local urlencode = TQ.urlencode

local fmt = string.format

function TQ.createProxy(name,devTempl)
  local code = [[
local fmt = string.format

function QuickApp:onInit()
self:debug("Started", self.name, self.id)
quickApp = self

local send

local IGNORE={ MEMORYWATCH=true,APIFUN=true}

function quickApp:actionHandler(action)
  if IGNORE[action.actionName] then
    print(action.actionName)
    return quickApp:callAction(action.actionName, table.unpack(action.args))
  end
  send({type='action',value=action})
end

function quickApp:UIHandler(ev) send({type='ui',value=ev}) end

function QuickApp:APIFUN(id,method,path,data)
  local stat,res,code = pcall(api[method:lower()],path,data)
  send({type='resp',id=id,value={stat,res,code}})
end

function QuickApp:initChildDevices(_) end

local ip,port = nil,nil

local function getAddress() -- continously poll for new address from emulator
  local var = __fibaro_get_global_variable("TQEMU") or {}
  local success,values = pcall(json.decode,var.value)
  if success then
    ip = values.ip
    port = values.port
  end
  setTimeout(getAddress,5000)
end
getAddress()

local queue = {}
local sender = nil
local connected = false
local sock = nil
local runSender

local function retry()
  if sock then sock:close() end
  connected = false
  queue = {}
  sender = setTimeout(runSender,1500)
end

function runSender()
  if connected then
    if #queue>0 then
      sock:write(queue[1],{
        success = function() print("Sent",table.remove(queue,1)) runSender() end,
      })
    else sender = nil print("Sleeping") end
  else
    if not (ip and sender) then sender = setTimeout(runSender,1500) return end
    print("Connecting...")
    sock = net.TCPSocket()
    sock:connect(ip,port,{
        success = function(message)
          sock:read({
            succcess = retry,
            error = retry
          })
          print("Connected") connected = true runSender()
        end,
        error = retry
    })
  end
end

function send(msg)
  msg = json.encode(msg).."\n"
  queue[#queue+1]=msg
  if not sender then print("Starting") sender=setTimeout(runSender,0) end
end

end
]]

  local props = {
    apiVersion = "1.3",
    --quickAppVariables = devTempl.quickAppVariables or {},
    --viewLayout = {},
    --uiView = {},
    useUiView=false,
    typeTemplateInitialized = true,
  }
  local fqa = {
    apiVersion = "1.3",
    name = name,
    type = devTempl.type,
    initialProperties = props,
    --initialInterfaces = devTempl.interfaces,
    files = {{name="main", isMain=true, isOpen=false, type='lua', content=code}},
  }
  local res,code2 = api.post("/quickApp/", fqa)
  return res
end

function TQ.interceptAPI(method,path,data) end

function TQ.setupInterceptors(id)
  local patterns,paths = {},{}
  local function block(m,p,data)
    DEBUGF('blockAPI',"Blocked API: %s",p)
    return true,nil,403
  end
  local function proxyAPI(m,p,data)
    DEBUGF('proxyAPI',"proxyAPI: %s",p)
    if TQ.proxyId then
      local res = TQ.callAPIFUN(m,p,data)
      local _,d,c = table.unpack(res,1)
      if type(d)=='function' then d = nil end
      return true,d,c
    else return block(m,p,data) end
  end
  local function blockDeviceId(m,p,data)
    if data.deviceId == plugin.mainDeviceId and not TQ.proxyId then
      DEBUGF('blockAPI',"Blocked API: %s, (only proxy)",p)
      return true,nil,200
    end
  end
  local function call(m,p,data)
    if not TQ.proxyId then
      return block(m,p,data)
    end
  end
  local function blockParentId(m,p,data)
    if data.parentId == plugin.mainDeviceId and not TQ.proxyId then return block(m,p,data) end
  end
  local function getStruct(m,p,d) if not TQ.proxyId then return true,plugin._dev,200 end end
  local function putStruct(m,p,d)
    for k,v in pairs(d) do plugin._dev[k] = v end
    if not TQ.proxyId then return true,d,200 end
  end
  local function getProp(m,p,d,id,prop)
    if not TQ.proxyId  or true then
      local value = plugin._dev.properties[prop]
      return true,{value=value,modified = plugin._dev.modified},200
    end
  end

  patterns["(%w+)/devices/"..id.."/?"] = {
    ['POST/devices/(%d+)/action'] = call,
    ['GET/devices/(%d+)/properties/([%w_]+)$'] = getProp,
  }

  paths[fmt('GET/quickApp/export/%s',id)] = function()
    return true,TQ.getFQA(),200
  end
  paths[fmt('GET/devices/%s',id)] = getStruct
  paths[fmt('PUT/devices/%s',id)] = putStruct
  paths[fmt('DELETE/devices/%s',id)] = block
  paths['POST/plugins/updateView'] = blockDeviceId
  paths['POST/plugins/updateProperty'] = blockDeviceId
  paths['POST/plugins/createChildDevice'] = blockParentId
  paths['POST/plugins/publishEvent'] = proxyAPI
  paths['POST/plugins/interfaces'] = proxyAPI

  function TQ.interceptAPI(method,path,data)
    local key = method..path
    if paths[key] then return paths[key](method,path,data)
    else
      for p,ps in pairs(patterns) do
        if key:match(p) then
          for p0,f in pairs(ps) do
            local m = {key:match(p0)}
            if #m>0 then return f(method,path,data,table.unpack(m)) end
          end
        end
      end
    end
  end
end

function TQ.getProxy(name,devTempl)
  local devStruct = api.get("/devices?name="..urlencode(name))
  assert(type(devStruct)=='table',"API error")
  if next(devStruct)==nil then
    devStruct = TQ.createProxy(name,devTempl)
    if not devStruct then return fibaro.error(__TAG,"Can't create proxy on HC3") end
    devStruct.id = math.floor(devStruct.id)
    DEBUG("Proxy installed: %s %s",devStruct.id,name)
  else
    devStruct = devStruct[1]
    devStruct.id = math.floor(devStruct.id)
    DEBUG("Proxy found: %s %s",devStruct.id,name)
  end
  TQ.proxyId = devStruct.id

  return devStruct
end

local callRef = {}
local ref = 0
function TQ.callAPIFUN(...)
  local id = ref; ref = ref+1
  local msg = {false,nil,'timeout'}
  local semaphore = copas.semaphore.new(10, 0, 100)
  fibaro.call(plugin.mainDeviceId,"APIFUN",id,...)
  callRef[id] = function(data) msg = data; semaphore:give(1) end
  semaphore:take(1)
  callRef[id] = nil
  return msg
end

function TQ.startServer()
  local emuval = json.encode({ip = TQ.emuIP, port = TQ.emuPort}) -- Update HC3 var with emulator connection data
  api.post("/globalVariables", {name=TQ.EMUVAR, value=emuval})
  api.put("/globalVariables/"..TQ.EMUVAR, {name=TQ.EMUVAR, value=emuval})
  DEBUGF('info',"Server started at %s:%s",TQ.emuIP,TQ.emuPort)

  local function handle(skt)
    mobdebug.on()
    local name = skt:getpeername() or "N/A"
    TQ._client = skt
    DEBUGF("server","New connection: %s",name)
    while true do
      local reqdata = copas.receive(skt)
      if not reqdata then break end
      local stat,msg = pcall(json.decode,reqdata)
      if stat then
        local QA = TQ.getQA()
        if msg.type == 'action' then QA.env.onAction(msg.value.deviceId,msg.value)
        elseif msg.type == 'ui' then QA.env.onUIEvent(msg.value.deviceId,msg.value)
        elseif msg.type == 'resp' then
          if callRef[msg.id] then local c = callRef[msg.id] callRef[msg.id] = nil pcall(c,msg.value) end
        else DEBUGF('server',"Unknown data %s",reqdata) end
      end
    end
    TQ._client = nil
    DEBUGF("server","Connection closed: %s",name)
  end
  local server,err= socket.bind('*', TQ.emuPort)
  if not server then error(fmt("Failed open socket %s: %s",TQ.emuPort,tostring(err))) end
  TQ._server = server
  copas.addserver(server, handle)
end
