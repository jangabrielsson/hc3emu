local TQ = fibaro.hc3emu
local addThread = TQ.addThread
local copas = TQ.copas
local socket = TQ.socket
local httpRequest = TQ.httpRequest
local mobdebug = TQ.mobdebug
local json = TQ.json

local function async(fun,...) return addThread(_G,fun,...) end
------------------------ base ------------------------------
---
---
------------------------- net ------------------------------
net = {}
-------------- HTTPClient ----------------------------------
function net.HTTPClient()
  local self = {}
  function self:request(url,options)
    local call = function()
      mobdebug.on()
      local opts = options.options or {}
      local res, status, headers = httpRequest(opts.method,url,opts.headers,opts.data,opts.timeout)
      if tonumber(status) and status <= 302 and options.success then 
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
local websock = TQ.require("websocket")

if websock then
  
  -- ws:connect('wss://ws.postman-echo.com/raw', {
  --   protocols = {"echo"},
  --   verify = "none"
  -- })
  
  function net.WebSocketClientTls(goptions)
    local POLLINTERVAL = 1
    local conn,err,lt = nil,nil,nil
    local self = { }
    local handlers = {}
    local ws_client = TQ.require('websocket.client').copas()
    self.ws_client = ws_client
    local listen,connected,disconnected
    goptions = goptions or {}
    
    local function dispatch(h,...)
      if handlers[h] then async(handlers[h],...) end
    end
    
    function self:connect(url,headers,ssl_params,protocols)
      if conn then return false end
      protocols = protocols or goptions.protocols or {}
      headers = headers or {}
      if headers['Sec-WebSocket-Protocol'] then 
        table.insert(protocols,1,headers['Sec-WebSocket-Protocol'])
        headers['Sec-WebSocket-Protocol'] = nil
      end
      --protocols = next(protocols)==nil and {"echo"} or protocols --{"echo"}
      local options = {
        --"all",
        -- "cipher_server_preference",
        -- "cookie_exchange",
        "dont_insert_empty_fragments",
        "ephemeral_rsa",
        -- "microsoft_big_sslv3_buffer",
        -- "microsoft_sess_id_bug",
        -- "msie_sslv2_rsa_padding",
        -- "netscape_ca_dn_bug",
        -- "netscape_challenge_bug",
        -- "netscape_demo_cipher_change_bug",
        -- "netscape_reuse_cipher_change_bug",
        "no_query_mtu",
        "no_session_resumption_on_renegotiation",
        "no_sslv2",
        -- "no_sslv3",
        "no_ticket",
        -- "no_tlsv1",
        -- "pkcs1_check_1",
        -- "pkcs1_check_2",
        "single_dh_use",
        "single_ecdh_use",
        "ssleay_080_client_dh_bug",
        "sslref2_reuse_cert_type_bug",
        "tls_block_padding_bug",
        "tls_d5_bug",
        "tls_rollback_bug",
        "allow_unsafe_legacy_renegotiation",
        "legacy_server_connect",
        -- "cisco_anyconnect",
        -- "cryptopro_tlsext_bug",
        "no_compression",
      }
      --{ verify = "none", cafile = "/etc/ssl/cert.pem", protocol="tlsv1_2", mode='client', options = {'all',"no_sslv3"} }
      ssl_params = ssl_params or goptions.ssl_params or { verify = "none", protocol="any", mode='client', options = {'all',"no_sslv3"} }
      conn, err =  ws_client:connect(url, protocols, ssl_params, headers, self.debug)
      ws_client.sock = TQ.copas.wrap(ws_client.sock)
      if conn then async(connected) return true
      else dispatch("error",err) return false,err end
    end
    
    function connected() 
      listen()  
      dispatch("connected") 
    end
    
    function disconnected() 
      if not conn then return end
      conn=nil 
      ws_client:close() 
      if lt then copas.removethread(lt) lt = nil end 
      dispatch("disconnected")
    end
    
    function ws_client.on_close() disconnected() end

    function listen()
      if not conn then return end
      lt = async(function() 
        mobdebug.on()
        while conn do
          local msg,code = ws_client:receive()
          if msg and msg ~="" then dispatch("dataReceived",msg,code)
          elseif conn then
            dispatch("error",code)
            disconnected()
          end
        end
      end)
    end
    
    function self:addEventListener(h,f) handlers[h]=f end 
    
    function self:listen() listen() end
    
    function self:send(data)
      if not conn then return false end
        local b,err = ws_client:send(data)
        if not b then
          dispatch("error",err)
          disconnected() 
          return false
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
local luamqtt = TQ.require("mqtt")
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
    connector = TQ.require("mqtt.luasocket-copas"),
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
  
  -- local loop = TQ.require("mqtt.ioloop").get(true, {timeout=0.005})
  -- --local loop = luamqtt.get_ioloop()
  -- loop:add(client)
  -- async(function() mobdebug.on()
  --   while true do
  --     loop:iteration()
  --     copas.sleep(0.05)
  --   end
  -- end)

  async(function() mobdebug.on() luamqtt.run_sync(client) end)
  
  -- async(function() mobdebug.on() luamqtt.run_ioloop(client) end)

  local pstr = "MQTT object: " .. tostring(mqttClient):match("%s(.*)")
  setmetatable(mqttClient, { __tostring = function(_) return pstr end })
  return mqttClient
end
