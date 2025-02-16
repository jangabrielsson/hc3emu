---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--NOTE: This is a test for the QwikAppChild class you need to have --%%state set so internalStorage data is saved for children

--%%name=QwikChilTest
--%%type=com.fibaro.genericDevice
--%%proxy=QCProxy
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

local children = {
  bar1 = {
    name = "Bar1",
    type = "com.fibaro.multilevelSwitch",
    className = "MyChild"
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
end

