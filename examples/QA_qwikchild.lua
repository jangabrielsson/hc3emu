--This is a QA testing the QwikAppChild library

---@diagnostic disable: duplicate-set-field
--_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--NOTE: This is a test for the QwikAppChild class you need to have --%%state set so internalStorage data is saved for children

--%%name=QwikChilTest
--%%type=com.fibaro.genericDevice
--%%proxy=QCProxy
--%%port=8265
--%%offline=true
--%%dark=true
--%%state=state.db
--%%debug=info:true,http:true,onAction:true,onUIEvent:true,proxyAPI:true
--%%var=debug:"main,wsc,child,color,battery,speaker,send,late"
--%%file=../fibemu/lib/QwikChild.lua:QC

local function printf(...) print(string.format(...)) end

class 'MyChild'(QwikAppChild)
function MyChild:__init(dev)
  QwikAppChild.__init(self,dev)
end
function MyChild:myButton1()
  self:debug("myButton1 pressed")
end
function MyChild:mySlider(event)
  self:debug("mySlider",event.values[1])
end
function MyChild:setValue(v)
  self:debug("setValue",v)
end
function MyChild:childFun(a,b)
  printf("childFun called %s+%s=%s",a,b,a+b)
end

local children = {
  bar135 = {
    name = "Bar1",
    type = "com.fibaro.multilevelSwitch",
    className = "MyChild",
    UI = {
      {button='b1',text='B1',onReleased='myButton1'},
      {button='b2',text='My new button',onReleased='myButton1'},
      {slider='s1',text='S1',onChanged='mySlider'}
    },
  },
  bar22 = {
    name = "Bar2",
    type = "com.fibaro.multilevelSwitch",
    className = "MyChild"
  },
  bar3 = {
    name = "Bar3",
    type = "com.fibaro.multilevelSwitch",
    className = "MyChild"
  },
}
function QuickApp:onInit()
  self:initChildren(children)
  fibaro.call(self.children.bar3.id,"childFun",5,7)
end

