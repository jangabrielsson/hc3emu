--This is a QA testing the various UI elements using a proxy on the HC3

---@diagnostic disable: duplicate-set-field
--_DEVELOP = true
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
  self:updateView("lbl1", "text", os.date("Hello %c"))
  local opts1 = {{text='A',type="option",value='a'},{text='B',type="option",value='b'}}
  self:updateView("select1","options",opts1)
  local opts2 = {{text='C',type="option",value='c'},{text='D',type="option",value='d'}}
  self:updateView("multi1","options",opts2)
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
  local val = event.values[1]
  self:debug("mySwitch",val)
  self:updateView("btn2","value",tostring(val))
end

function QuickApp:mySelect(event)
  self:debug("mySelect",event.values[1])
end

function QuickApp:myMulti(event)
  self:debug("myMulti",json.encode(event.values[1]))
end