_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=EventMgrTest
--%%type=com.fibaro.binarySwitch

local function match(pattern,event) -- See if pattern matches event
  if type(pattern) == 'table' and type(event) == 'table' then
    for k,v in pairs(pattern) do
      if type(v) == 'table' and v._constr then
        return v._constr(event[k]) -- check if all keys in pattern are present in event
      end
      if not match(v,event[k]) then return false end -- check if all keys in pattern are present in event 
    end
    return true
  else return pattern == event end -- strings, numbers, booleans
end

local function coerce(x,y) local v = tonumber(x) if v then return v,tonumber(y) else return x,y end end
local constrains = {}
constrains['<'] = function(val) return function(v) v,val=coerce(v,val) return v < val end end
constrains['>'] = function(val) return function(v) v,val=coerce(v,val) return v > val end end
constrains['<='] = function(val) return function(v) v,val=coerce(v,val) return v <= val end end
constrains['>='] = function(val) return function(v) v,val=coerce(v,val) return v >= val end end
constrains['!'] = function(val) return function(v) v,val=coerce(v,val) return v ~= val end end

local function compilePattern(p)
  if type(p) == 'table' then
    for k,v in pairs(p) do
      if type(v) == 'string' and v:sub(1,1) == '$' then
        local op,val = v:match("^%$([<>=!])(.*)")
        local constr = constrains[op](tonumber(val) or val)
        p[k] = { _constr = constr }
      elseif type(v) == 'table' then
        compilePattern(v)
      end
    end
  end
end

-- toTime("10:00")     -> 10*3600+0*60 secs
-- toTime("10:00:05")  -> 10*3600+0*60+5*1 secs
-- toTime("t/10:00")    -> (t)oday at 10:00. midnight+10*3600+0*60 secs
-- toTime("n/10:00")    -> (n)ext time. today at 10.00AM if called before (or at) 10.00AM else 10:00AM next day
-- toTime("+/10:00")    -> Plus time. os.time() + 10 hours
-- toTime("+/00:01:22") -> Plus time. os.time() + 1min and 22sec
-- toTime("sunset")     -> todays sunset in relative secs since midnight, E.g. sunset="05:10", =>toTime("05:10")
-- toTime("sunrise")    -> todays sunrise
-- toTime("sunset+10")  -> todays sunset + 10min. E.g. sunset="05:10", =>toTime("05:10")+10*60
-- toTime("sunrise-5")  -> todays sunrise - 5min
-- toTime("t/sunset+10")-> (t)oday at sunset in 'absolute' time. E.g. midnight+toTime("sunset+10")

local function midnight() local t = os.date("*t"); t.hour,t.min,t.sec = 0,0,0; return os.time(t) end

local function hm2sec(hmstr,ns)
  local offs,sun
  sun,offs = hmstr:match("^(%a+)([+-]?%d*)")
  if sun and (sun == 'sunset' or sun == 'sunrise') then
    hmstr,offs = fibaro.getValue(1,sun.."Hour"), tonumber(offs) or 0
  end
  local sg,h,m,s = hmstr:match("^(%-?)(%d+):(%d+):?(%d*)")
  assert(h and m,"Bad hm2sec string "..hmstr)
  return (sg == '-' and -1 or 1)*(tonumber(h)*3600+tonumber(m)*60+(tonumber(s) or 0)+(tonumber(offs or 0))*60)
end

local function toTime(time) -- returns epoc time in seconds
  local p = time:sub(1,2)
  if p == '+/' then return hm2sec(time:sub(3))+os.time()
  elseif p == 'n/' then
    local t1,t2 = midnight()+hm2sec(time:sub(3),false),os.time()
    return t1 > t2 and t1 or t1+24*60*60
  elseif p == 't/' then return  hm2sec(time:sub(3))+midnight()
  else return hm2sec(time) end
end

EventMgr = EventMgr 
class 'EventMgr'
function EventMgr:__init()
  self.events = {}
  self:setupSourceTriggers()
  local refresh = RefreshStateSubscriber()
  refresh:subscribe(function() return true end,function(event) self:post(event) end)
  refresh:run()
end

function EventMgr:addHandler(pattern,handler) 
  compilePattern(pattern)
  self.events[pattern.type] = self.events[pattern.type] or {}
  table.insert(self.events[pattern.type],{pattern=pattern,handler=handler}) 
end

function EventMgr:getHandlers(event)
  return self.events[event.type] or {} 
end

function EventMgr:post(event,time)  -- Optional time in seconds
  --print(json.encode(event))
  if type(time)=="string" then  -- time string spec, convert.
    time = toTime(time)  
    if time < 0 then return end -- Negative time, post in the past, do not post
  else 
    local now = os.time()
    time = time or now
    if time >= now then time = time - now else time = time + now end -- Absolute time in the future
  end
  return setTimeout(function() -- Do it as asynchronously as possible
    local handlers = self:getHandlers(event)
    for _,v in ipairs(handlers) do -- look through each defined event handler for this event type
      if match(v.pattern,event) and v.handler(event) then return end -- if matches event pattern , call handler with event
    end
  end,math.floor(1000*(time or 0)+0.5))
end


function EventMgr:allOf(events,timeout,handler)
  local seen,first,ref = {},true,nil
  local function action(res) -- reset, and call handler with false/fail, or list of events
    if ref then ref = clearTimeout(ref) end
    for i,_ in ipairs(seen) do seen[i] = false end
    first = true
    handler(res)
  end
  for i,event in ipairs(events) do
    seen[i] = false
    local n = i
    self:addHandler(event,function(event) 
      if seen[n] then return end -- Already seen
      seen[n] = event
      if first then ref = setTimeout(function() action(false) end,1000*timeout) first = false end
      for _,e in ipairs(seen) do if not e then return true end end
      action(seen)
      return true -- Stop further processing
    end)
  end
end

function EventMgr:sequence(_events ,handler)
  local events,i,timers,seen = {},2,{},{}
  events[#events+1] = { event = _events[1], timeout = math.huge } -- First event, no timeout 
  while i <= #_events do  -- Collect event arguments {type=...},<number>,{type=...}
    local timeout = math.huge -- Event followed by number denotes timeout
    if tonumber(_events[i]) then timeout = 1000*_events[i] i = i + 1 end
    local event = _events[i]
    events[#events+1] = { event = event, timeout = timeout}
    i = i + 1
  end
  
  for i,e in ipairs(events) do
    local timeout,pattern,n = e.timeout,e.event,i
    local nextHandler = events[i+1]
    self:addHandler(pattern,function(event)
      if n > 1 then
        if not timers[n] then return end           -- Not triggered yet
        timers[n] = clearTimeout(timers[n])        -- Ok, made it this far...
      elseif next(seen) then return end            -- First event, already seen
      seen[#seen+1] = event
      if nextHandler then
        timers[n+1] = setTimeout(function() timers,seen={},{} handler(false) end,nextHandler.timeout) -- Watch next event
      else
        timers = {}
        handler(seen) -- Call handler with event
        seen = {}
      end
    end)
  end
end

function EventMgr:anyOf(events ,handler) -- for completness...
  for _,event in ipairs(events) do self:addHandler(event,function(e) handler(e) return true end) end
end

function EventMgr:setupSourceTriggers() -- Setup some transformation to sourceTrigger style events
  
  local keyTime = {}
  self:addHandler({type='CentralSceneEvent'},function(event)
    -- local id,time = event.data.id,nil
    -- time,keyTime[id] = keyTime[id] or 0,os.time()
    -- local last = keyTime[id] - time
    self:post({type='key', id=event.data.id, key = event.data.keyId, attribute = event.data.keyAttribute, last = last})
  end)
  
  self:addHandler({type='DevicePropertyUpdatedEvent'},function(event)
    self:post({type='device', id=event.data.id, property = event.data.property, value = event.data.newValue})
  end)
  
  self:addHandler({type='GlobalVariableChangedEvent'},function(event)
    local d = event.data
    self:post({type='global-variable', name=d.variableName, value=d.newValue, old=d.oldValue})
  end)
  
  self:addHandler({type='GlobalVariableAddedEvent'},function(event)
    local d = event.data
    self:post({type='global-variable', id=d.id, name=d.variableName, value=d.value, old=nil})
  end)
  
  self:addHandler({type='CustomEvent'},function(event)
    local name = event.data.name
    local value = api.get("/customEvents/"..name)
    self:post({type='custom-event', name=name, value=value and value.userDescription})
  end)
  
  self:addHandler({type='GeofenceEvent'},function(event)
    local d = event.data
    self:post({type='location',id=d.userId,property=d.locationId,value=d.geofenceAction,timestamp=d.timestamp})
  end)
  
  self:addHandler({type='AlarmPartitionArmedEvent'},function(event)
    self:post({type='alarm', property='armed', id = event.data.partitionId, value=event.data.armed})
  end)
  
  self:addHandler({type='AlarmPartitionBreachedEvent'},function(event)
    self:post({type='alarm', property='breached', id = event.data.partitionId, value=event.data.breached})
  end)
  
  self:addHandler({type='HomeArmStateChangedEvent'},function(event)
    self:post({type='alarm', property='homeArmed', value=event.data.newValue})
  end)
  
  self:addHandler({type='HomeDisarmStateChangedEvent'},function(event)
    self:post({type='alarm', property='homeArmed', value=not event.data.newValue})
  end)
  
  self:addHandler({type='HomeBreachedEvent'},function(event)
    self:post({type='alarm', property='homeBreached', value=event.data.breached})
  end)
  
  self:addHandler({type='WeatherChangedEvent'},function(event)
    self:post({type='weather',property=event.data.change, value=event.data.newValue, old=event.data.oldValue})
  end)
  
end

if fibaro then fibaro.EventMgr = EventMgr end

----------- Test the librray with a keypad event --------------------
local em = EventMgr()

em:addHandler({type='key'},function(event) print("Event",json.encode(event)) end)
em:addHandler({type='device',property='value'},function(event) print("Event",json.encode(event)) end)

-- em:sequence({{type='key',key=2},3,{type='key',key=3},3,{type='key',key=2}},
--   function(e) 
--     if e then print("Unlock") else print("Timeout") end
--   end)
-- em:allOf({{type='key',key=2},{type='key',key=3},{type='key',key=2}},5,
--   function(e) 
--     if e then print("Unlock") else print("Timeout") end
--   end)

-- <event>,<State> -> <Action>,<State>
-- <timeout>,<State> -> <Action>,<State>

local function equal(e1,e2)
  if e1==e2 then return true
  else
    if type(e1) ~= 'table' or type(e2) ~= 'table' then return false
    else
      for k1,v1 in pairs(e1) do if e2[k1] == nil or not equal(v1,e2[k1]) then return false end end
      for k2,_  in pairs(e2) do if e1[k2] == nil then return false end end
      return true
    end
  end
end

local fsms = {}
local fevents = {}
function EventMgr:fsm(id,state,event,action,newState,brk)
  local fsm = fsms[id] or {state = nil, timeouts = {}, trans = {}}
  fsms[id] = fsm
  if tonumber(event) then
    fsm.timeouts[state] = {d=tonumber(event)}
    self:fsm(id,state,{type='_timeout'},action,newState)
    return
  end

  if not fevents[event.type] then
    fevents[event.type] = true
    self:addHandler({type=event.type},function(e) -- Repost ST as fsm event
      self:post({type='_fsm',fsm=id,event=e,state=fsms[id].state})
    end)
  end

  local found = nil
  for _,t in ipairs(fsm.trans) do
    if equal(t.event,event) then found = t break end
  end
  if found == nil then
    table.insert(fsm.trans,{event=event,states={state=true}})
    if fsm.state==nil then fsm.state = state end
  else 
    assert(not found.states[state],"Duplicate state "..state.." for event "..event.type)
    found.states[state] = true
  end
  
  self:addHandler({type='_fsm',event=event,fsm=id,state=state},function(e)
    --print("Event",json.encode(e))
    e = e.event
    local t = fsm.timeouts[state]
    if t and t.ref then 
      --print("Clearing timout for state",state)
      t.ref = clearTimeout(t.ref)
    end
    fsm.state = newState
    local t = fsm.timeouts[newState]
    if t and t.d then 
      --print("Setting timout for state",newState)
      t.ref = setTimeout(function ()
        self:post({type='_timeout',_fsm=id,_state=newState})
      end,t.d*1000) end
      if action then action(e) end
      if brk then return true end
    end)
  end
  
  local function unlock() print("Key3: Unlock") end
  local function first() print("Key1") end
  local function second() print("Key2") end
  local function start() print("Start") end
  
  -- em:fsm('code','Start',{type='key',key=2,attribute='Pressed'},first,'First')
  -- em:fsm('code','First',{type='key',key=3,attribute='Pressed'},second,'Second')
  -- em:fsm('code','First',{type='key',key='$!3',attribute='Pressed'},start,'Start')
  -- em:fsm('code','First',3,start,'Start')
  -- em:fsm('code','Second',{type='key',key=2,attribute='Pressed'},unlock,'Start')
  -- em:fsm('code','Second',{type='key',key='$!2',attribute='Pressed'},start,'Start')
  -- em:fsm('code','Second',3,start,'Start')
  
  local bath = 8
  -- open_door
  -- inside_open
  -- maybe_inside
  -- inside

  -- em:fsm('bt','empty',{type='open',id=bath},turnOn,'open_door')
  -- em:fsm('bt','open_door',{type='breached',id=bath},nil,'inside_open')
  -- em:fsm('bt','open_door',{type='close',id=bath},nil,'maybe_inside')
  -- em:fsm('bt','inside_open',{type='close',id=bath},nil,'maybe_inside')
  -- em:fsm('bt','inside_open',{type='breached',id=bath},nil,'inside_open')
  -- em:fsm('bt','maybe_inside',{type='breached',id=bath},nil,'inside')
  -- em:fsm('bt','maybe_inside',{type='open',id=bath},nil,'open_inside')
  -- em:fsm('bt','maybe_inside',30,turnOff,'empty')
  
  function QuickApp:onInit()
    
  end