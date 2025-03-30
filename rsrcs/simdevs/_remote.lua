--%%name=Remote
--%%type=com.fibaro.remote
--%%html=html

--%%u={{button='b1',text='□',onReleased="b1"},{button='b2',text='O',onReleased="b2"}}
--%%u={{button='b3',text='X',onReleased="b3"},{button='b4',text='△',onReleased="b4"}}
--%%u={{button='b5',text='-',onReleased="b5"},{button='b6',text='+',onReleased="b6"}}
function QuickApp:onInit()
  self:debug(self.name,self.id)
end

local modifier = {"Pressed","HeldDown","Released","Released"}
local refresh = fibaro.hc3emu.refreshState.post
function QuickApp:post(keyId,keyAttribute)
  refresh.CentralSceneEvent(plugin.mainDeviceId,keyId,keyAttribute)
end

function QuickApp:b1() self:post(1,"Pressed") end
function QuickApp:b2() self:post(2,"Pressed") end
function QuickApp:b3() self:post(3,"Pressed") end
function QuickApp:b4() self:post(4,"Pressed") end
function QuickApp:b5() self:post(5,"Pressed") end
function QuickApp:b6() self:post(6,"Pressed") end
