TQ = fibaro.hc3emu
local async = TQ.addthread
local copas = TQ.copas
local socket = TQ.socket
local httpRequest = TQ.httpRequest
local mobdebug = TQ.mobdebug
  
-------------- HTTPClient ----------------------------------
function net.HTTPClient()
  local self = {}
  function self:request(url,options)
    local call = function()
      mobdebug.on()
      local opts = options.options or {}
      local res, status, headers = httpRequest(opts.method,url,opts.headers,opts.data,opts.timeout)
      if tonumber(status) and status < 300 and options.success then 
        options.success({status=status,data=res,headers=headers})
      elseif options.error then options.error(status) end
    end
    async(call)
  end
  return self
end

-------------- UDPSocket ----------------------------------
function net.TCPSocket(opts)
  local opts = opts or {}
  local self = { opts = opts }
  self.sock = copas.wrap(socket.tcp())
  if tonumber(opts.timeout) then
    self.sock:settimeout(opts.timeout/1000) -- timeout in ms
  end
  function self:connect(ip, port, opts)
    for k,v in pairs(self.opts) do opts[k]=v end
    local _, err = self.sock:connect(ip,port)
    if err==nil and opts and opts.success then async(opts.success)
    elseif opts and opts.error then async(opts.error,err) end
  end
  function self:read(opts) -- I interpret this as reading as much as is available...?
    local data = {}
    local b,err = self.sock:receive()
    if b and not err then data[#data+1]=b end -- ToDO: This is not correct...?
    -- while b and b~="" and not err do
    --   data[#data+1]=b
    --   b,err = self.sock:receive()
    -- end
    if #data>0 and opts and opts.success then async(opts.success,(table.concat(data,"\n")))
    elseif opts and opts.error then async(opts.error,err) end
  end
  function self:readUntil(delimiter, opts) -- Read un..til the cows come home, or closed
    local res,err = self.sock:receive(delimiter)
    if res and not err and opts and opts.success then async(opts.success,res)
    elseif err and opts and opts.error then async(opts.error,err) end
  end
  function self:write(data, opts)
    local res,err = self.sock:send(data)
    if res and opts and opts.success then async(opts.success,res)
    elseif res==nil and opts and opts.error then async(opts.error,err) end
  end
  function self:close() self.sock:close() end
  local pstr = "TCPSocket object: "..tostring(self):match("%s(.*)")
  setmetatable(self,{__tostring = function(_) return pstr end})
  return self
end

function net.UDPSocket(opts)
  local self = { opts = opts or {} }
  self.sock = copas.wrap(socket.udp())
  if self.opts.broadcast~=nil then
    self.sock:setsockname(TQ.IPAddress, 0)
    self.sock:setoption("broadcast", self.opts.broadcast)
  end
  if tonumber(opts.timeout) then self.sock:settimeout(opts.timeout / 1000) end
  
  function self:sendTo(datagram, ip,port, callbacks)
    local stat, res = self.sock:sendto(datagram, ip, port)
    if stat and callbacks.success then
      async(callbacks.success,1)
    elseif stat==nil and callbacks.error then
      async(callbacks.error,res)
    end
  end
  function self:bind(ip,port) self.sock:setsockname(ip,port) end
  function self:receive(callbacks)
    local stat, res = self.sock:receivefrom()
    if stat and callbacks.success then
      async(callbacks.success,stat, res)
    elseif stat==nil and callbacks.error then
      async(callbacks.error,res)
    end
  end
  function self:close() self.sock:close() end
  
  local pstr = "UDPSocket object: "..tostring(self):match("%s(.*)")
  setmetatable(self,{__tostring = function(_) return pstr end})
  return self
end

-------------- WebSocket ----------------------------------
local websock = _require("hc3emu.ws")
if websock then
  net._LuWS_VERSION = websock.version or "unknown"
  function net.WebSocketClientTls(options)
    local POLLINTERVAL = 1
    local conn,err,lt = nil,nil,nil
    local self = { }
    local handlers = {}
    local function dispatch(h,...)
      if handlers[h] then async(handlers[h],...) end
    end
    local function listen()
      if not conn then return end
      lt = async(function() mobdebug.on()
        while true do
          websock.wsreceive(conn)
          copas.pause(POLLINTERVAL)
        end
      end)
    end
    local function stopListen() if lt then copas.removethread(lt) lt = nil end end
    local function disconnected() 
      websock.wsclose(conn) 
      conn=nil; 
      stopListen(); 
      dispatch("disconnected")
    end
    local function connected() listen();  dispatch("connected") end
    local function dataReceived(data) dispatch("dataReceived",data) end
    local function error(err2) dispatch("error",err2) end
    local function message_handler( conn2, opcode, data, ... )
      if not opcode then 
        error(data) disconnected()
      else dataReceived(data) end
    end
    function self:addEventListener(h,f) handlers[h]=f end 
    function self:connect(url,headers)
      if conn then return false end
      local wopts = {upgrade_headers=headers, } 
      if url:match("^wss:") then
        function wopts.connect(ip,port)
          local sock = copas.wrap(socket.tcp(),{wrap={protocol='any',mode='client',verify='none'}})
          --sock:settimeout(5)
          local res,err = sock:connect(ip,port)
          if not res then return nil,err end
          return sock
        end
        wopts.ssl_mode = "client"
        wopts.ssl_protocol = "tlsv1_2"
        --wopts.ssl_protocol = "any"
        wopts.ssl_verify = "none"
      end
      conn, err = websock.wsopen( url, message_handler,  wopts) 
      if not err then async(connected); return true
      else return false,err end
    end
    
    function self:send(data)
      if not conn then return false end
      if not websock.wssend(conn,1,data) then 
        return disconnected() 
      end
      return true
    end
    function self:isOpen() return conn and true end
    function self:close() if conn then disconnected() return true end end
    
    local pstr = "WebSocket object: "..tostring(self):match("%s(.*)")
    setmetatable(self,{__tostring = function(_) return pstr end})
    return self
  end
  net.WebSocketClient = net.WebSocketClientTls
end
-------------- MQTT ----------------------------------
local luamqtt = _require("mqtt")
mqtt = { interval = 1000, Client = {}, QoS = { EXACTLY_ONCE = 1 } }

mqtt.MSGT = { 
  CONNECT = 1, CONNACK = 2, PUBLISH = 3, PUBACK = 4, PUBREC = 5,PUBREL = 6, PUBCOMP = 7, SUBSCRIBE = 8, SUBACK = 9,
  UNSUBSCRIBE = 10, UNSUBACK = 11, PINGREQ = 12, PINGRESP = 13, DISCONNECT = 14, AUTH = 15,
}
mqtt.MSGMAP = {
  [9] = 'subscribed', [11] = 'unsubscribed', [14] = 'closed', [4] = 'published', -- Should be onpublished according to doc?
}

function mqtt.Client.connect(uri, options)
  uri = string.gsub(uri, "mqtt://", "")
  --cafile="...", certificate="...", key="..." (default false)
  local secure = nil
  if options.clientCertificate then -- Not in place...
    secure = {
      certificate = options.clientCertificate,
      cafile = options.certificateAuthority,
      key = "",
    }
  end
  local client = luamqtt.client{
    uri = uri,
    username = options.username, 
    password = options.password,
    clean = not (options.cleanSession==false),
    will = options.lastWill,
    keep_alive = options.keepAlivePeriod,
    id = options.clientId,
    secure = secure,
    connector = _require("mqtt.luasocket-copas"),
  }
  
  local callbacks = {}
  client:on{
    connect = function(connack)
      if callbacks.connected then callbacks.connected(connack) end
    end,
    message = function(msg)
      local msgt = mqtt.MSGMAP[msg.type]
      if msgt and callbacks[msgt] then callbacks[msgt](msg)
      elseif callbacks.message then callbacks.message(msg) end
    end,
    error = function(err)
      if callbacks.error then callbacks.error(err) end
    end,
    close = function()
      if callbacks.close then callbacks.close() end
    end
  }
  
  local mqttClient = {}
  function mqttClient:addEventListener(message, handler) callbacks[message] = handler end
  
  function mqttClient:subscribe(topic, options)
    local qos = options and options.qos or 1
    return client:subscribe({ topic=topic, qos=qos, callback=function(suback) end })
  end
  
  function mqttClient:unsubscribe(topics, options)
    if type(topics) == 'string' then return client:unsubscribe(topics)
    else
      local res; for _, t in ipairs(topics) do res = self:unsubscribe(t) end; return res
    end
  end
  
  function mqttClient:publish(topic, payload, options)
    local qos = options and options.qos or 1
    return client:publish({ topic = topic, payload = payload, qos = qos }) 
  end
  
  function mqttClient:disconnect(options)
    return client:disconnect(nil, { callback = (options or {}).callback })
  end
  
  async(function() mobdebug.on() luamqtt.run_sync(client) end)
  
  local pstr = "MQTT object: " .. tostring(mqttClient):match("%s(.*)")
  setmetatable(mqttClient, { __tostring = function(_) return pstr end })
  return mqttClient
end
