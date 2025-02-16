---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=UItest
--%%type=com.fibaro.multilevelSwitch
--%%proxy=UItestProxy
--%%dark=true
--%%debug=sdk:false,info:true,proxyAPI:true,server:true,onAction:true,onUIEvent:true
--%%debug=http:true,color:true,blockAPI:true

--%%u={label='lbl1',text="LABEL"}
--%%u={button='btn1',text="Btn1", onReleased="myButton"}
--%%u={switch='btn2',text="Btn2", onReleased="mySwitch"}
--%%u={slider='slider1',text="", onChanged="mySlider"}
--%%u={select='select1',text="Select", onToggled="mySelect",options={}}
--%%u={multi='multi1',text="Multi", onToggled="myMulti",options={}}

function QuickApp:onInit()
  self:debug("onInit",self.name,self.id)
  self:updateView("info", "text", os.date("Hello %c"))
end

function QuickApp:setValue(value)
  self:debug("multilevel slider",value)
end

function QuickApp:myButton()
  self:debug("myButton pressed")
end

function QuickApp:mySlider(event)
  self:debug("mySlider",event.values[1])
end

function QuickApp:mySwitch(event)
  self:debug("mySwitch",event.values[1])
end

function QuickApp:mySelect(event)
  self:debug("mySelect",event.values[1])
end

function QuickApp:myMulti(event)
  self:debug("myMulti",json.encode(event.values[1]))
end