TQ = TQ
local DEBUGF = TQ.DEBUGF
local DEBUG = TQ.DEBUG
local api = TQ.api
local copas = TQ.copas
local socket = TQ.socket
local json = TQ.json
local mobdebug = TQ.mobdebug
local urlencode = TQ.urlencode

local fmt = string.format

function TQ.createProxy(name,devTempl)
  local code = [[
local fmt = string.format
local con = nil
local ip,port = nil,nil

function QuickApp:onInit()
  self:debug("Started", self.name, self.id)
  quickApp = self
  con = self:internalStorageGet("con") or {}
  ip = con.ip
  port = con.port
  local send
  
  local IGNORE={ MEMORYWATCH=true,APIFUN=true,CONNECT=true }
  
  function quickApp:CONNECT(con)
    con = con or {}
    self:internalStorageSet("con",con)
    ip = con.ip
    port = con.port
    self:debug("Connected")
  end

  function quickApp:actionHandler(action)
    if IGNORE[action.actionName] then
      print(action.actionName)
      return quickApp:callAction(action.actionName, table.unpack(action.args))
    end
    send({deviceId=self.id,type='action',value=action})
  end
  
  function quickApp:UIHandler(ev) send({type='ui',value=ev}) end
  
  function quickApp:APIFUN(id,method,path,data)
    local stat,res,code = pcall(api[method:lower()],path,data)
    send({type='resp',deviceId=self.id,id=id,value={stat,res,code}})
  end
  
  function quickApp:initChildDevices(_) end
  
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
  local emptyArr = json.util.InitArray({})
  local props = {
    apiVersion = "1.3",
    quickAppVariables = devTempl.properties.quickAppVariables or emptyArr,
    viewLayout = devTempl.properties.viewLayout,
    uiView = devTempl.properties.uiView,
    uiCallbacks = devTempl.properties.uiCallbacks,
    useUiView=true,
    typeTemplateInitialized = true,
  }
  if props.quickAppVariables then json.util.InitArray(props.quickAppVariables) end
  if props.uiCallbacks then json.util.InitArray(props.uiCallbacks) end
  local fqa = {
    apiVersion = "1.3",
    name = name,
    type = devTempl.type,
    initialProperties = props,
    initialInterfaces = devTempl.interfaces,
    files = {{name="main", isMain=true, isOpen=false, type='lua', content=code}},
  }
  --print(json.encode(fqa))
  local res,code2 = api.post("/quickApp/", fqa)
  return res
end

local Route = TQ.require('hc3emu.route')

function TQ.setupRemoteRoutes() -- Proxy routes updates both local QA data and remote Proxy data
  local route = Route(TQ.HC3Call)
  local proxy = TQ.proxyId
  
  local function block(p,data)
    DEBUGF('blockAPI',"Blocked API: %s",p)
    return nil,501
  end

  local function proxyAPI(p,data)
    DEBUGF('proxyAPI',"proxyAPI: %s",p)
    if not proxy then return nil,501 end
    local method,path = p:match("(.-)(/.+)") -- split method and path
    local res = TQ.callAPIFUN(method:lower(),path,data)
    local _,d,c = table.unpack(res,1)
    if type(d)=='function' then d = nil end
    return d,c
  end

  local function putProp(p,data)
    if data.deviceId == proxy then
      local qa = TQ.getQA(data.deviceId)
      qa.device.properties[data.propertyName] = data.value
    end
    if proxy then return nil,301
    else return nil,200 end
  end

  local function blockParentId(p,data)
    if data.parentId == proxy and not proxy then return block(p,data) end
    return nil,301
  end

  local function blockIfEmulated(p,id,data)
    if TQ.getQA(tonumber(id)) then return block(p,data)
    else return nil,301 end
  end

  local function updateView(p,data) --ToDo, update local view
    return nil,301
  end

  local function putStruct(p,id,d) -- Update local struct, and then update HC3...
    local qa = TQ.getQA(tonumber(id))
    if qa then
      for k,v in pairs(d) do qa.dev[k] = v end -- update local properties 
      if proxy then return nil,301 -- and update the HC3 proxy 
      else return d,200 end
    else return nil,301 end
  end

  TQ.addStandardAPIRoutes(route)

  route:add('PUT/devices/<id>',putStruct)
  route:add('DELETE/devices/<id>',blockIfEmulated)                    -- Block delete
  route:add('POST/plugins/updateView',updateView)           -- Update local and remote view
  route:add('POST/plugins/updateProperty',putProp)          -- Update local and remote properties
  route:add('POST/plugins/createChildDevice',blockParentId) -- Block if it is for local QA and we don't have a proxy
  route:add('POST/plugins/publishEvent',proxyAPI)           -- Proxy if we have a proxy
  route:add('POST/plugins/interfaces',proxyAPI)             -- Proxy if we have a proxy
  
  return route
end

function TQ.getProxy(name,devTempl)
  TQ.route = TQ.require('hc3emu.route')(TQ.HC3Call) -- Setup standard route to HC3, needed to do api.* to install proxy
  local devStruct = api.get("/devices?name="..urlencode(name))
  assert(type(devStruct)=='table',"API error")
  if next(devStruct)==nil then
    devStruct = TQ.createProxy(name,devTempl)
    if not devStruct then return TQ.ERROR("Can't create proxy on HC3") end
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
function TQ.callAPIFUN(method,path,data)
  local id = ref; ref = ref+1
  local msg = {false,nil,'timeout'}
  local semaphore = copas.semaphore.new(10, 0, 100)
  local args = {id,method,path,data}
  TQ.HC3Call("POST","/devices/"..plugin.mainDeviceId.."/action/APIFUN",{args=args})
  copas.pause(0)
  callRef[id] = function(data) msg = data; semaphore:give(1) end
  semaphore:take(1)
  callRef[id] = nil
  return msg
end

local started = false
function TQ.startServer(id)
  if started then return end
  started = true
  -- local emuval = json.encode({id = id, ip = TQ.emuIP, port = TQ.emuPort}) -- Update HC3 var with emulator connection data
  -- api.post("/globalVariables", {name=TQ.EMUVAR, value=emuval})
  -- api.put("/globalVariables/"..TQ.EMUVAR, {name=TQ.EMUVAR, value=emuval})
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
        local deviceId = msg.deviceId
        local QA = TQ.getQA(deviceId)
        if QA and msg.type == 'action' then QA.env.onAction(msg.value.deviceId,msg.value)
        elseif QA and msg.type == 'ui' then QA.env.onUIEvent(msg.value.deviceId,msg.value)
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
