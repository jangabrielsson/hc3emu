--_DEVELOP =true
if require and not QuickApp then require("hc3emu") end

--%%name=Event test

--%%file=$hc3emu.eventlib:Events

------ENDOFDIRECTIVES------
---@diagnostic disable-next-line: undefined-global
Event_std = Event_std
local Event = Event_std
Event.id='start2'
Event{type='fromEventSender'}
function Event:handler(event)
  print("Incoming remote event",event.data)
end

function QuickApp:onInit()
  self:debug("QuickApp Initialized", self.name, self.id)
  self:setupForRemoteEvents()

  fibaro.hc3emu.tools.loadQAString([[
--%%name=EventSender
--%%breakOnLoad=true
--%%file=$hc3emu.eventlib:Events

local Event = Event_std

function QuickApp:setupForRemoteEvents()
  fibaro._APP.trigger.GlobalSourceTriggerGV = "GlobalEventVAR"
  api.post("/globalVariables", {name="GlobalEventVAR", value=""})
  function QuickApp:sendGlobalEvent(event)
    fibaro.setGlobalVariable("GlobalEventVAR", json.encode(event))
  end
end

function QuickApp:onInit()
  self:setupForRemoteEvents()
  setInterval(function()
    local event = {type='fromEventSender', data=os.date('%c')}
    self:sendGlobalEvent(event)
  end, 4000)
end
]])

end

Event.id='start'
Event{type='QAstart'}
function Event:handler(event)
  Event:attachRefreshstate()
end

function QuickApp:setupForRemoteEvents()
  fibaro._APP.trigger.GlobalSourceTriggerGV = "GlobalEventVAR"
  api.post("/globalVariables", {name="GlobalEventVAR", value=""})
  function QuickApp:sendGlobalEvent(event)
    fibaro.setGlobalVariable("GlobalEventVAR", json.encode(event))
  end
end
