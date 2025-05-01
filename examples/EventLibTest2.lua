_DEVELOP =true
if require and not QuickApp then require("hc3emu") end

--%%name=Event test

--%%file=$hc3emu.eventlib:Events

Event_std = Event_std
local Event = Event_std

-- local other = { X = 'Y', Y = 'X' }
-- local events = {}
-- local last = 0
-- Event.id='_'
-- Event{type='input',id=_,value=_}
-- function Event:handler(event)
--   local now = os.time()
--   local device = event.id
--   local other = other[device]
--   events[device] = event.value
--   if events[device] == events[other] and now-last < 2 then 
--     last = 0
--     events = {}
--     return self:post({type='input',id='XY',value=event.value})
--   else events[other] = nil last = now end
-- end

-- local last,x,y = 0,nil,nil

-- local lastTime,lastEvent = 0,nil
-- Event.id='_'
-- Event{type='device',id='X',value=_}
-- Event{type='device',id='Y',value=_}
-- function Event:handler(event)
--   event.time = os.time()
--   if lastEvent then self:post({type='device2',curr=event,last=lastEvent})
--   else lastEvent = event end
-- end

Event.id='_'
Event{type='device',id='X',value=_}
Event{type='device',id='Y',value=_}
local last,time = {id='_',value=0},0
local fmt = string.format
function Event:handler(event)
  local now = os.time()
  self:post({type='combo',e1=last,e2=event,time=now-time})
  last = event
  time = os.time()
end

Event.id='_'
Event{type='combo',e1={id='X',value='$value'},e2={id='Y',value='$value'},time='$<=1'}
Event{type='combo',e1={id='Y',value='$value'},e2={id='X',value='$value'},time='$<=1'}
function Event:handler(event)
  print("Combined XY",event.e1.value)
end


Event:post({type='device',id='X',value=1})
setTimeout(function() Event:post({type='device',id='Y',value=1}) end, 2000)