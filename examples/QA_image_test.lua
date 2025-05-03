_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=ImageTest
--%%type=com.fibaro.binarySwitch
--%%plugin=$hc3emu.image
--%%image=lib/bikeChargerOff.png,bike
--%%save=test/imateTest.fqa
--%%webui=true

--%%u={label='image',text=''}
_IMAGES = _IMAGES

function QuickApp:onInit()
  self:debug("onInit")
  local image = _IMAGES['bike']
  local d = string.format('<img alt="Bike" src="%s"/>',image.data)
  self:updateView('image','text',d)
  self:setVariable("x",os.date("%c"))
  self:setVariable("y",{a=42,b=17})
end