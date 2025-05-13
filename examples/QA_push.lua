
_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=MyQA
--%%type=com.fibaro.binarySwitch


function QuickApp:onInit()
  hub.alert('push', { 2 }, 'text', false, '')
end