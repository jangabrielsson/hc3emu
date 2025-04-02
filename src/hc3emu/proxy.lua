local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local json = require("hc3emu.json")
local copas = require("copas")
local socket = require("socket")
local urlencode
local fmt = string.format

local function init()
  urlencode = E.util.urlencode
  E.route.ProxyRoute = exports.ProxyRoute
end

local function createProxy(name,devTempl)
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
  
  function quickApp:UIHandler(ev) send({type='ui',deviceId=self.id,value=ev}) end
  
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
    useUiView=false,
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
  local res,code2 = E:apipost("/quickApp/", fqa)
  return res
end

local function getProxy(name,devTempl)
  local devStruct = E:apiget("/devices?name="..urlencode(name))
  assert(type(devStruct)=='table',"API error")
  if next(devStruct)==nil then
    devStruct = createProxy(name,devTempl)
    if not devStruct then return E:ERROR("Can't create proxy on HC3") end
    devStruct.id = math.floor(devStruct.id)
    E:DEBUG("Proxy installed: %s %s",devStruct.id,name)
  else
    devStruct = devStruct[1]
    devStruct.id = math.floor(devStruct.id)
    E:DEBUG("Proxy found: %s %s",devStruct.id,name)
  end
  devStruct.isProxy = true
  E.proxyId = devStruct.id -- Just save the last proxy to be used for restricted API calls
  return devStruct
end

local callRef = {}
local ref = 0
local function callAPIFUN(method,path,data)
  local id = ref; ref = ref+1
  local msg = {false,nil,'timeout'}
  local semaphore = copas.semaphore.new(10, 0, 100)
  local args = {id,method,path,data}
  local stat,res = pcall(function()
  E:HC3Call("POST","/devices/"..E.proxyId.."/action/APIFUN",{args=args})
  end)
  copas.pause(0)
  callRef[id] = function(data) msg = data; semaphore:give(1) end
  semaphore:take(1)
  callRef[id] = nil
  return msg
end

local started = false
local function startServer(id)
  if started then return end
  started = true
  E:DEBUGF('info',"Starting server at %s:%s",E.emuIP,E.emuPort)
  E.stats.ports[E.emuPort] = true

  local function handle(skt)
    E.mobdebug.on()
    E:setRunner(E.systemRunner)
    local name = skt:getpeername() or "N/A"
    E._client = skt
    E:DEBUGF("server","New connection: %s",name)
    while true do
      local reqdata = copas.receive(skt)
      if not reqdata then break end
      local stat,msg = pcall(json.decode,reqdata)
      if stat then
        local deviceId = msg.deviceId
        local QA = E:getQA(deviceId)
        if QA and msg.type == 'action' then QA:onAction(msg.value.deviceId,msg.value)
        elseif QA and msg.type == 'ui' then QA:onUIEvent(msg.value.deviceId,msg.value)
        elseif msg.type == 'resp' then
          if callRef[msg.id] then local c = callRef[msg.id] callRef[msg.id] = nil pcall(c,msg.value) end
        else E:DEBUGF('server',"Unknown data %s",reqdata) end
      end
    end
    E._client = nil
    E:DEBUGF("server","Connection closed: %s",name)
  end
  local server,err = socket.bind('*', E.emuPort)
  if not server then error(fmt("Failed open socket %s: %s",E.emuPort,tostring(err))) end
  E._server = server
  copas.addserver(server, handle)
end

------------------- ProxyRoute -------------------------------------
local function ProxyRoute()
  local route = E.route.createRouteObject()
  
  local function block(p,data)
    E:DEBUGF('blockAPI',"Blocked API: %s",p)
    return nil,501
  end
  
  local function proxyAPI(p,data)
    E:DEBUGF('proxyAPI',"proxyAPI: %s",p)
    if not E.proxyId then return nil,501 end
    local method,path = p:match("(.-)(/.+)") -- split method and path
    local res = callAPIFUN(method:lower(),path,data)
    local _,d,c = table.unpack(res,1)
    if type(d)=='function' then d = nil end
    return d,c
  end
  
  local function getDevices(p,query)
    -- Get all devices from HC3
    local qas = E:apiget('/devices')
      -- Add emulated QAs 
    for id,q in pairs(E.QA_DIR) do
      if id >= 5000 then qas[#qas+1] = q.device end
    end
    if next(query) then return E.offline.queryFilter(query,qas),200 end   -- if query, filter the list.
    return qas,200
  end

  local function putProp(p,data)
    local qa = E:getQA(data.deviceId)
    if qa then -- emulated QA
      qa.device.properties[data.propertyName] = data.value
      qa:watchesProperty(data.propertyName,data.value)
      if qa.isProxy then return nil,301 end -- continue to update HC3 proxy
    end
    return nil,301
  end
  
  local function blockParentId(p,data)
    local p = E:getQA(data.parentId)
    if p and not p.isProxy then return block(p,data) end
    return nil,301
  end
  
  local function blockIfEmulated(p,id,data)
    if E:getQA(tonumber(id)) then return block(p,data)
    else return nil,301 end
  end
  
  local function updateView(p,data) --ToDo, update local view
    local qa = E:getQA(tonumber(data.deviceId))
    if not qa then return nil,301 end
    if not qa.qa then return nil,404 end
    qa:updateView(data)
    if qa.isProxy then return nil,301 end -- and update the HC3 proxy
    return nil,200  end
  
  local function putStruct(p,id,d) -- Update local struct, and then update HC3...
    local qa = E:getQA(tonumber(id))
    if qa then
      for k,v in pairs(d) do qa.dev[k] = v end -- update local properties 
      if qa.isProxy then return nil,301 -- and update the HC3 proxy 
      else return d,200 end
    else return nil,301 end
  end
  
  local function installFQA(p,data)
    if E.installLocal then
      local info = E:installFQAstruct(data)
      if info then return info.dev,200 else return nil,401 end
    else return nil,301 end
  end

  route:add('GET/devices',function(p,...) return getDevices(p,...) end)
  route:add('PUT/devices/<id>',putStruct)
  route:add('DELETE/devices/<id>',blockIfEmulated)                    -- Block delete
  route:add('POST/plugins/updateView',updateView)           -- Update local and remote view
  route:add('POST/plugins/updateProperty',putProp)          -- Update local and remote properties
  route:add('POST/plugins/createChildDevice',blockParentId) -- Block if it is for local QA and we don't have a proxy
  route:add('POST/plugins/publishEvent',proxyAPI)           -- Proxy if we have a proxy
  route:add('POST/plugins/interfaces',proxyAPI)             -- Proxy if we have a proxy
  
  route:add('POST/quickApp/',installFQA)                   -- Install a new FQA
  return route
end


exports.createProxy = createProxy
exports.getProxy = getProxy
exports.startServer = startServer
exports.ProxyRoute = ProxyRoute
exports.init = init

return exports