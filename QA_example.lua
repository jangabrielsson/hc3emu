---@diagnostic disable: undefined-global, duplicate-set-field
local home = "/Users/jangabrielsson/.luarocks"
package.path = 
home.."/share/lua/5.4/?.lua;"..
home.."/share/lua/5.4/?/init.lua;"..
package.path
package.cpath = package.cpath..";"..home.."/lib/lua/5.4/?.so"

if not QuickApp then dofile("hc3emu.lua") end
--if not QuickApp then require("hc3emu") end

--fibaro.USER = "admin" -- set creds in TQ_cfg.lua instead
--fibaro.PASSWORD = "admin"
--fibaro.URL = "http://192.168.1.57/"

--%%name="Test"
--%%type="com.fibaro.multilevelSwitch"
--%%proxy="MyProxy"
--%%dark=true
--%%id=5001
--%%var=foo:config.secret
--%%debug=sdk:false,info:true,proxyAPI:true,server:true,onAction:true,onUIEvent:true
--%%debug=http:true,color:true

--%%file=lib_example.lua:lib

local function printf(...) print(string.format(...)) end

function QuickApp:onInit()
  self:debug(self.name,self.id,self.type)
  self:testBasic()
  self:testChildren()
  print("Done!")
end

function QuickApp:testBasic()
  local info = api.get("/settings/info")
  printf("SW version:%s",info.currentVersion.version)
  printf("Serial nr:%s",info.serialNumber)
  printf("Sunrise: %s, Sunset: %s",fibaro.getValue(1,"sunriseHour"),fibaro.getValue(1,"sunsetHour"))

  setTimeout(function()
      local qas = api.get("/devices?interface=quickApp")
      printf("QuickApps:%s",#qas)
      local qvs = api.get("/globalVariables")
      printf("GlobalVariables:%s",#qvs)
    end,0)

  self:debug("Start")
  local delay = 0.2
  setTimeout(function() 
      self:debug("End",delay,"sec later") 
    end,delay*1000)

  self:debug("This is a debug statement")
  self:trace("This is a trace statement")
  self:warning("This is a warning statement")
  self:error("This is an error statement")

  self:setVariable("Foo",42)
  if self:getVariable("Foo") == 42 then self:debug("setVar is OK")
  else self:error("setVar FAIL") end

  self:updateProperty("value",66)
  if fibaro.getValue(self.id,"value") == 66 then self:debug("updateProperty is OK")
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

  setTimeout(function() error("This is an intentional error in a setTimeout function") end,0)
end

class 'MyChild'(QuickAppChild)
function MyChild:__init(dev) QuickAppChild.__init(self,dev) end

function QuickApp:testChildren()
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

function QuickApp:turnOn() print("Turn on called") end
function QuickApp:turnOff() print("Turn off called") end
function QuickApp:setValue(v) print("setValue called",v) end
function QuickApp:mySlider(v) print("mySlider called",v.values[1]) end
function QuickApp:myButton() print("MyButton called") end