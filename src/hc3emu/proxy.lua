local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local json = require("hc3emu.json")
local copas = require("copas")
local lclass = require("hc3emu.class")
local urlencode
local fmt = string.format

local function init()
  urlencode = E.util.urlencode
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
  local props = {
    apiVersion = "1.3",
    quickAppVariables = devTempl.properties.quickAppVariables or {},
    viewLayout = devTempl.properties.viewLayout,
    uiView = devTempl.properties.uiView,
    uiCallbacks = devTempl.properties.uiCallbacks,
    useUiView=false,
    typeTemplateInitialized = true,
  }
  local fqa = {
    apiVersion = "1.3",
    name = name,
    type = devTempl.type,
    initialProperties = props,
    initialInterfaces = devTempl.interfaces,
    files = {{name="main", isMain=true, isOpen=false, type='lua', content=code}},
  }
  --print(json.encode(fqa))
  local res,code2 = E.tools.uploadFQA(fqa)
  return res
end

local function getProxy(name,devTempl)
  local devStruct = E.api.hc3.get("/devices?name="..urlencode(name))
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

local SocketServer = E.util.SocketServer
local ProxyServer = lclass('ProxyServer',SocketServer)
function ProxyServer:__init(ip,port) SocketServer.__init(self,ip,port,"proxy","server") end
function ProxyServer:handler(io)
  while true do
    ---print("Waiting for data")
    local reqdata = io.read()
    if not reqdata then break end
    local stat,msg = pcall(json.decode,reqdata)
    if stat then
      local deviceId = msg.deviceId
      local QA = E:getQA(deviceId)
      if QA and msg.type == 'action' then QA:onAction(msg.value.deviceId,msg.value)
      elseif QA and msg.type == 'ui' then QA:onUIEvent(msg.value.deviceId,msg.value) end
    end
  end
end

local _proxyServer = nil
local function start() 
  if _proxyServer then return end
  _proxyServer = ProxyServer(E.emuIP,E.emuPort) 
  _proxyServer:start()
end

exports.createProxy = createProxy
exports.getProxy = getProxy
exports.start = start
exports.init = init

return exports