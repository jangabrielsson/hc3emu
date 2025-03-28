--This is a QA running in offline mode and testing some APIs

---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=Offline2QA
--%%type=com.fibaro.multilevelSwitch
--%%dark=true
--%%color=true
--%%time=12/31 10:00:12
--%%state=state.db
--%%project=5566
--%%offline=true
--%%uiPage=html/MyPage.html
--% %installHtmlFiles=html
--%%debug=info:true,api:true,onAction:true,onUIEvent:true
--%%var=debug:"main,wsc,child,color,battery,speaker,send,late"

--%%u={label='lbl1', text="<font color='red'>My Label</font>"}
--%%u={button='b1', text='My Button', onReleased='myButton'}
--%%u={slider='s1', onChanged='mySlider', value='75'}
--%%u={switch='sw1', text='My Switch', onReleased='myButton'}
--%%u={select='select1',text="Select", onToggled="mySelect",options={{text='A',value='A'},{text='B',value='B'}}}
--%%u={multi='multi1',text="Multi", onToggled="myMulti" ,options={{text='A',value='A'},{text='B',value='B'}}}


local function printf(...) print(string.format(...)) end

function QuickApp:onInit()
  print("Offline2 QA started",self.name,self.id)
  self:updateView('lbl1','text',os.date("Hello world %c"))

  setTimeout(function() 
    self:updateView('s1','value',"75")
  end,4000)

  setTimeout(function() 
    self:updateView('select1','options',{{text='C0',value='C0'},{text='D1',value='D1'}})
  end,8000)

  setTimeout(function() 
    --self:updateView('multi1','selectedItems',{"B"})
  end,12000)
end

function QuickApp:myButton(ev)
  --self:updateView("sw1","value",tostring(ev.values[1]))
  printf("Button pressed")
end

function QuickApp:mySlider(value)
  printf("Slider value %s",value.values[1])
end

function QuickApp:myMulti(value)
  printf("Multi value %s",json.encode(value.values[1]))
end

function QuickApp:mySelect(value)
  printf("Select value %s",value.values[1])
end

