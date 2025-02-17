---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--fibaro.USER = "admin" -- set creds in ./hc3emu_cfg.lua or ~/.hc3emu.lua
--fibaro.PASSWORD = "admin"
--fibaro.URL = "http://192.168.1.57/"

--%%name=Test
--%%type=com.fibaro.multilevelSwitch
--%%proxy=MyProxy
--%%dark=true
--%%id=5001
--%%state="state.db"
--%%save=MyQA.fqa
--%%var=foo:config.secret
--%%debug=sdk:false,info:true,proxyAPI:true,server:true,onAction:true,onUIEvent:true
--%%debug=http:true,color:true,blockAPI:true
--%%file=examples/include_example.lua:lib

--%%u={button='bt1',text="MyButton",onReleased="myButton"}
--%%u={slider='s1',text="MySlider",onChanged="mySlider"}

local function printf(...) print(string.format(...)) end

if fibaro.hc3emu then
  fibaro.hc3emu.require("hc3emu.colors")(fibaro) -- We can load extra colors working in vscode, don't work in zbs
  print("<font color='salmon'>Salmon</font> <font=color=green>Green</font> <font color=\"blue\">Blue</font>")

  fibaro.hc3emu.logFilter = {"DevicePropertyUpdatedEvent"} -- We can filter out some log messages containing string
end

function QuickApp:onInit()
  self:debug(self.name,self.id,self.type)
  local fqa = api.get("/quickApp/export/"..self.id) -- Get my own fqa struct
  printf("Size of '%s' fqa: %s bytes",self.name,#json.encode(fqa))
  self:testRefreshStates()
  self:testBasic()
  self:testChildren() -- Only works with proxy
  self:testTCP()
  self:testMQTT()
  self:testWebSocket() -- have problem with work with wss
  --self:listFuns()
  print("Done!")
end

function QuickApp:testBasic()
  local info = api.get("/settings/info")
  printf("SW version:%s",info.currentVersion.version)
  printf("Serial nr:%s",info.serialNumber)
  printf("Sunrise: %s, Sunset: %s",fibaro.getValue(1,"sunriseHour"),fibaro.getValue(1,"sunsetHour"))
  
  local qas = api.get("/devices?interface=quickApp")
  printf("QuickApps:%s",#qas)
  local qvs = api.get("/globalVariables")
  printf("GlobalVariables:%s",#qvs)
  
  self:debug("Start")
  local delay = 0.2
  setTimeout(function() 
    self:debug("End",delay,"sec later") 
  end,delay*1000)
  
  local i,iref = 0,nil
  iref = setInterval(function() 
    i=i+1 
    print("This is a repeating message nr:",i) 
    if i >= 5 then 
      -- os.exit(0) -- This exits the emulator imidiatly
      clearInterval(iref) -- This just stops the loop
    end
  end,3000)
  
  self:debug("This is a debug statement")
  self:trace("This is a trace statement")
  self:warning("This is a warning statement")
  self:error("This is an error statement")
  
  local varName = "EmuTest"
  api.post("/globalvariables",{name=varName,value=66})
  self:setVariable(varName,42)
  if self:getVariable(varName) == 42 then self:debug("setVar is OK")
  else self:error("setVar FAIL") end
  api.delete("/globalVariables/"..varName)
  
  self:updateProperty("value",77)
  if fibaro.getValue(self.id,"value") == 77 then self:debug("updateProperty is OK")
  else self:error("updateProperty FAIL") end
  
  --  self:setName("MyNewName") -- This should restart the QA...
  --  if api.get("/devices/"..self.id).name == "MyNewName" then self:debug("setName OK") 
  --  else self:debug("setName FAIL") end
  
  self:internalStorageSet("key",42)
  if self:internalStorageGet("key") == 42 then self:debug("internalStorage Set/Get OK") 
  else self:error("internalStorage Set/Get FAIL") end
  
  self:internalStorageRemove("key")
  if self:internalStorageGet("key") == nil then self:debug("internalStorageRemove OK") 
  else self:error("internalStorageRemove FAIL") end
  
  --self:addInterfaces({'battery'}) -- Restarts the QA on the HC3...
  local a,b = api.get("/settings/network")
  
  local data = {
    type =  "centralSceneEvent",
    source = plugin.mainDeviceId,
    data = { keyAttribute = 'Pressed', keyId = 1 }
  }
  local a,b = api.post("/plugins/publishEvent", data)
  if b==200 then self:debug("publishEvent OK") 
  else self:error("publishEvent FAIL",a,b) end
  
  setTimeout(function() 
    error("This is an intentional error in a setTimeout function") 
  end,0)
end

class 'MyChild'(QuickAppChild)
function MyChild:__init(dev) QuickAppChild.__init(self,dev) end

function QuickApp:testChildren()
  if not fibaro.hc3emu.proxyId then 
    self:debug("testChildren only works with proxy")
    return
  end
  self:initChildDevices({["com.fibaro.binarySwitch"]=MyChild})
  local children = api.get("/devices?parentId="..self.id)
  if #children == 0 then 
    self:createChildDevice({
      name = "myChild",
      type = "com.fibaro.binarySwitch",
    }, 
    MyChild)
  end
  
  for _,c in pairs(self.childDevices) do 
    printf("Have child %s %s",c.id,c.name)
  end
  
  for id,_ in pairs(self.childDevices) do 
    printf("Deleting child %s",id)
    self:removeChildDevice(id)
  end
end

function QuickApp:testMQTT()
  --local url = "mqtt://mqtt.flespi.io"
  local url = "mqtt://test.mosquitto.org"
  local ref = nil
  local function handleConnect(event)
    self:debug("connected: "..json.encode(event))
    self.client:subscribe("test/#",{qos=1})
    self.client:publish("test/blah", "Hello from "..self.name,{qos=1})
    ref = setTimeout(function() 
      self:debug("No message within 5s, disconnecting")
      self.client:disconnect() 
    end,5000)
  end
  self.client = mqtt.Client.connect(url, {
    port="1883", clientId="HC3",
    --username = "stPwSVV73Eqw5LSv0iMXbc4EguS7JyuZR9lxU5uLxI5tiNM8ToTVqNpu85pFtJv9",
  })
  self.client._debug = true
  self.client:addEventListener('published', function(event) self:debug("published: "..json.encode(event)) end)  
  self.client:addEventListener('message', function(event)
    if event.topic == "test/blah" then 
      self:debug("MQTT Got message from test.mosquitto.org: "..event.payload)
      clearTimeout(ref)
      self.client:disconnect()
    end
  end)
  self.client:addEventListener('connected', handleConnect)
  self.client:addEventListener('connected', handleConnect)
end

function QuickApp:testTCP()
  net.HTTPClient():request("https://timeapi.io/api/time/current/zone?timeZone=Europe/Amsterdam",{
    options = {
      method = "GET",
      headers = { ["Accept"] = "application/json" }
    },
    success = function(response) self:debug("Response",response.data) end,
    error = function(err) self:error(err) end
  })
  print("HTTP call to https://timeapi.io (can take a while zzzz...)") -- async, so we get answer later
  
  local tcp = net.TCPSocket()
  tcp:connect("www.google.com",80,{
    success = function() 
      self:debug("TCP connected")
      tcp:write("GET / HTTP/1.1\r\nHost: www.google.com\r\n\r\n",{
        success = function() 
          self:debug("TCP sent") 
          tcp:readUntil("*l",{
            success = function(data) 
              self:debug("TCP received from www.google.com: "..(data:match("(.-)\n") or data))
            end,
            error = function(err) self:error("TCP receive error: "..err) end
          })
        end,
        error = function(err) self:error("TCP send error: "..err) end
      })
    end,
    error = function(err) self:error("TCP error: "..err) end,
  })
end

function QuickApp:testWebSocket()
  local sock = net.WebSocketClientTls()
  local n=0
  local function handleConnected()
    self:debug("connected")
    setInterval(function()
        n=n+1
        sock:send("WebSocket: Hello from hc3emu "..n.."\n")
    end,2000)
  end
  
  local function handleDisconnected() self:warning("handleDisconnected") end
  local function handleError(error) self:error("handleError:", error) end
  local function handleDataReceived(data) self:trace("dataReceived:", data) end
  
  sock:addEventListener("connected", function() handleConnected() end)
  sock:addEventListener("disconnected", function() handleDisconnected() end)
  sock:addEventListener("error", function(error) handleError(error) end)
  sock:addEventListener("dataReceived", function(data) handleDataReceived(data) end)
  sock:connect("wss://ws.postman-echo.com/raw")
end

function QuickApp:testRefreshStates()
  local refresh = RefreshStateSubscriber()
  refresh:subscribe(function() return true end,
  function(event) 
    printf("RefreshState: %s %s",event.type,json.encode(event.data))
  end)
  refresh:run()
end

function QuickApp:listFuns()
  local buff = {}
  local function pr(...) buff[#buff+1] = string.format(...) end
  for k,v in pairs(fibaro) do pr("- fibaro.%s%s",k,type(v)=='function' and "(...)" or "") end
  for k,v in pairs(api) do pr("- api.%s%s",k,type(v)=='function' and "(...)" or "") end
  for k,v in pairs(net) do pr("- net.%s%s",k,type(v)=='function' and "(...)" or "") end
  for k,v in pairs(plugin) do pr("- plugin.%s%s",k,type(v)=='function' and "(...)" or "") end
  table.sort(buff)
  pr("- json.encode(expr)")
  pr("- json.decode(str)")
  pr("- setTimeout(fun,ms)")
  pr("- setTimeout(ref)")
  pr("- setInterval(fun,ms)")
  pr("- clearInterval(ref)")
  pr("- setInterval(fun,ms)")
  pr("- clearInterval(ref)")
  pr("- class <name>(<parent>)")
  pr("- property(...)")
  pr("- class QuickAppBase()")
  pr("- class QuickApp()")
  pr("- class QuickAppChild")
  pr("- hub = fibaro")
  local s = table.concat(buff,"\n")
  self:debug("\n"..s)
end

function QuickApp:turnOn() print("Turn on called") end
function QuickApp:turnOff() print("Turn off called") end
function QuickApp:setValue(v) print("setValue called",v) end
function QuickApp:mySlider(v) print("mySlider called",v.values[1]) end
function QuickApp:myButton() print("MyButton called") end