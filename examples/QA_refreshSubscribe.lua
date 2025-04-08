if require and not QuickApp then require('hc3emu') end

--%%name=MyQA
--%%type=com.fibaro.binarySwitch

local function EventMgr(QA)
  local self = {}
  local refresh = RefreshStateSubscriber()
  local handler = function(event)
    if event.type == "DevicePropertyUpdatedEvent" then
      local key = event.data.property..event.data.id
      if QA[key] then QA[key](QA,event.data.newValue) end
    end
  end
  refresh:subscribe(function() return true end,handler)
  refresh:run()
  return self
end

function QuickApp:onInit()
  self:debug("welcome")
  
  EventMgr(self)
end

function QuickApp:value3078(value)
  self:debug("3078 value changed to",value)
end

function QuickApp:value3079(value)
  self:debug("3079 value changed to",value)
end
