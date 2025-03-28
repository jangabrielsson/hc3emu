_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=ChildTest
--%%type=com.fibaro.binarySwitch
--%%proxy=ChildTestProxy
--% %offline=true
--%%installHtmlFiles=html
--%%uiPage=html/ChildTest.html

--%%u={label='lbl1', text="<font color='red'>My Label</font>"}
--%%u={button='b1', text='My Button', onReleased='myButton'}

local function printf(...) print(string.format(...)) end

MyChildSwitch = MyChildSwitch

class 'MyChildSwitch'(QuickAppChild)
function MyChildSwitch:__init(dev) QuickAppChild.__init(self,dev) end
function MyChildSwitch:turnOn()
  self:debug("Child turn on")
  self:updateProperty("value",true)
end
function MyChildSwitch:turnOff()
  self:debug("Child turn off")
  self:updateProperty("value",false)
end

class 'MyChildSwitch'(QuickAppChild)
function MyChildSwitch:__init(dev) QuickAppChild.__init(self,dev) end
function MyChildSwitch:turnOn()
  self:debug("Child turn on")
  self:updateProperty("value",true)
end
function MyChildSwitch:turnOff()
  self:debug("Child turn off")
  self:updateProperty("value",false)
end

MyChildDim = MyChildDim

class 'MyChildDim'(QuickAppChild)
function MyChildDim:__init(dev) QuickAppChild.__init(self,dev) end
function MyChildDim:turnOn()
  self:debug("Child turn on")
  self:updateProperty("value",99)
  --self:updateProperty("state",true)
end
function MyChildDim:turnOff()
  self:debug("Child turn off")
  self:updateProperty("value",0)
  --self:updateProperty("state",false)
end
function MyChildDim:setValue(v)
  self:debug("Child set value",v)
  self:updateProperty("value",v)
end

function QuickApp:onInit()
  self:initChildDevices({
    ["com.fibaro.binarySwitch"]=MyChildSwitch,
    ["com.fibaro.multilevelSwitch"]=MyChildDim
  })
  local children = api.get("/devices?parentId="..self.id)
  if #children == 0 then 
    self:createChildDevice({
      name = "myChild Switch",
      type = "com.fibaro.binarySwitch",
    }, 
    MyChildSwitch)
    self:createChildDevice({
      name = "myChild Dimmer",
      type = "com.fibaro.multilevelSwitch",
    }, 
    MyChildDim)
  end
  
  for _,c in pairs(self.childDevices) do 
    printf("Have child %s %s",c.id,c.name)
  end

end

function QuickApp:turnOn()
  print("Turn on")
end
