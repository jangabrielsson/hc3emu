_DEVELOP=true
if require and not QuickApp then require('hc3emu') end
--%%offline=true
--%%save=Hello.fqa
--%%webui=true
--%%u={button='b1', text='Hello', onReleased='onButton'}
--%%u={multi='m1', text='Hello', onToggled='onButton',visible=true,options={}}

function QuickApp:onInit()
  self:debug("welcome")
end

function QuickApp:onButton()
  self:debug("button pressed")
end
