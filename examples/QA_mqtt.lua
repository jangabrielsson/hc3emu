_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=MQTT
--%%type=com.fibaro.binarySwitch

--local url = "mqtt://mqtt.flespi.io"
local url = "mqtt://test.mosquitto.org"

function QuickApp:ping(name)
  local client
  local function handleConnect(event)
    self:debug("connected: "..json.encode(event))
    client:subscribe("hc3emu/pong",{qos=1})
    for i=1,5 do
      setTimeout(function()
        client:publish("hc3emu/ping", "Ping from "..name,{qos=1})
      end,i*1000)
    end
  end

  client = mqtt.Client.connect(url, { port="1883", clientId="HC3ping",})
  client._debug = true
  client:addEventListener('published', function(event) self:debug("published: "..json.encode(event)) end)  
  local n = 0
  client:addEventListener('message', function(event)
    if event.topic == "hc3emu/pong" then 
      n = n + 1
      self:debug("MQTT Got message from test.mosquitto.org: "..event.payload)
      if n == 5 then client:disconnect() end
    end
  end)
  client:addEventListener('connected', handleConnect)
end

function QuickApp:pong(name)
  local client
  local function handleConnect(event)
    self:debug("connected: "..json.encode(event))
    client:subscribe("hc3emu/ping",{qos=1})
  end

  client = mqtt.Client.connect(url, { port="1883", clientId="HC3pong"})
  client._debug = true
  client:addEventListener('published', function(event) self:debug("published: "..json.encode(event)) end)  
  local n = 0
  client:addEventListener('message', function(event)
    if event.topic == "hc3emu/ping" then 
      n = n+1
      self:debug("MQTT Got message from test.mosquitto.org: "..event.payload)
      client:publish("hc3emu/pong", "Pong from "..name,{qos=1})
      if n == 5 then client:disconnect() end
    end
  end)
  client:addEventListener('connected', handleConnect)
end


function QuickApp:onInit()
  self:pong('ClientB')
  self:ping('ClientA')
end