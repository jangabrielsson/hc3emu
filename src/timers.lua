local TQ = TQ
local copas = TQ.copas
local DEBUGF = TQ.DEBUGF
local mobdebug = TQ.mobdebug

local fmt = string.format

local timerIdx = 0   -- Every timer gets a new number
local timers = {}    -- Table of all timers, string(idx)->TimerRef
local function createTimerRef(timer,ms,fun,tag,hook)
  timerIdx = timerIdx + 1
  DEBUGF('timer',"createTimerRef:%s",timerIdx)
  local ref = {
    ms = ms, -- Time in ms when timer should fire
    timer = timer, -- Should support timer:cancel()
    time = TQ.userMilli() + ms/1000.0, -- Absolute time when timer should fire msepoch
    fun = fun, -- Function to call
    tag = tag, -- Tag for timer (debug)
    hook = hook, -- Hook function to call when timer is started or stopped
    id = timerIdx
  }
  timers[tostring(timerIdx)] = ref
  return timerIdx, ref
end
local function getTimerRef(id)
  return timers[tostring(id)]
end
local function setTimerRef(id,ref)
  timers[tostring(id)] = ref
end
local function cancelTimerRef(id)
  local id = tostring(id)
  local t = timers[id]
  if t then
    DEBUGF('timer',"cancelTimerRef:%s",id)
    t.timer:cancel()
    if t.hook then pcall(t.hook,false) end
    timers[id] = nil
  end
end


local setTimeoutAuxSpeed

local function cancelTimers(env) 
  if env == nil then 
    for t,_ in pairs(timers) do cancelTimerRef(t) end timers = {} 
  else
    for t,_ in pairs(timers) do 
      local cenv = TQ.getCoroData(t.timer.co,'env')
      if cenv == env then cancelTimerRef(t) end
    end
  end
end

local setTimeoutStd
local setTimeoutSpeed
local setTimeoutRef
local setInterval
local clearTimeout
local setTimeout
local __speed

local function callback(_,id) 
  mobdebug.on()
  local ref = getTimerRef(id)
  DEBUGF('timer',"timer std expire:%s",id)
  setTimerRef(id,nil)
  ref.fun()
  if ref.hook then pcall(ref.hook,false) end
end

local function setTimeoutAuxStd(ref)
  local env = TQ.getCoroData(nil,'env')
  DEBUGF('timer',"setTimeoutStd:%s %s",ref.id,ref.tag or "")
  local t = copas.timer.new({
    name = "setTimeout:"..ref.id,
    delay = ref.ms / 1000.0,
    recurring = false,
    initial_delay = nil,
    callback = callback,
    params = ref.id,
    errorhandler = function(err, coro, skt)
      if env then
        env._error(fmt("setTimeout:%s",tostring(err)))
      end
      setTimerRef(ref.id,nil)
      copas.seterrorhandler()
      --print(copas.copas.gettraceback(err,coro,skt))
    end
  })
  ref.timer = t
  -- Keep track of what QA started what timer
  -- Will allows us to kill all timers started by a QA when it is deleted
  TQ.setCoroData(t.co,'env',env)
  return ref.id
end

function setTimeoutStd(ref) return setTimeoutAuxStd(ref) end

function clearTimeout(ref)
  cancelTimerRef(ref)
  copas.pause(0)
end

-------------------- Speed timer -----------------------
local times = nil -- linked list of sorted timers

local function remove(t)
  --assert(type(ref)=='string',"Invalid timer reference")
  if t and not t.dead then
    t.dead = true
    if t.prev == nil then
      times = t.next
      if times then times.prev = nil end
    elseif t.next == nil then
      t.prev.next = nil
    else
      t.prev.next = t.next
      t.next.prev = t.prev
    end
  end
end

local function insert(time,id,env)
  local v = nil
  v = {time=time,id=id,env=env,cancel = function() remove(v) end }
  if not times then times = v return v end
  if time < times.time then
    times.prev = v
    v.next = times
    times = v
    return v
  end
  local p = times
  while p.next and p.next.time < time do p = p.next end
  v.next = p.next
  if p.next then p.next.prev = v end
  p.next = v
  v.prev = p
  return v
end

local function pop()
  if not times then return end
  local t = times
  if t.next then times = t.next times.prev = nil else times = nil end
  t.dead = true
  return t
end

local function printTimers()
  local n,n2 = 0,0
  local t = times
  local r1,r2 = {},{}
  while t do n = n + 1 r1[#r1+1]=tostring(t.id) t = t.next end
  for t,_ in pairs(timers) do n2=n2+1 r2[#r2+1]=tostring(t) end
  print(fmt("Timers: list=%s:%s table=%s:%s",n,table.concat(r1,","),n2,table.concat(r2,",")))
end

function setTimeoutSpeed(ref)
  DEBUGF('timer',"setTimeoutSpeed:%s %s",ref.id,ref.tag or "")
  local env = TQ.getCoroData(nil,'env')
  ref.timer = insert(ref.time,ref.id,env)
end

local function rescheduleTimer(ref)
  setTimerRef(tostring(ref.id),ref)
  assert(ref,"Invalid timer reference")
  DEBUGF('timer',"rescheduleTimer:%s %s",ref.id,ref.tag or "")
  local time = ref.time-TQ.userMilli()
  --print(TQ.userDate("%c",math.floor(ref.time)),TQ.userDate("%c"))
  ref.ms = time*1000
  setTimeoutRef(ref)
end

function setInterval(fun,ms,tag,hook)
  tag = tag or "interval"
  local id
  local ref
  local function loop()
    setTimeoutRef(ref)
    fun()
  end
  id = setTimeout(loop,ms,tag,hook)  
  ref = getTimerRef(id)
  return id
end

local function round(x) return math.floor(x+0.5) end

local speedFlag = false

function TQ.startSpeedTimeAux(hours)
  --TQ.addThread(nil,function()
    speedFlag = true
    local start = TQ.userTime()
    local stop,rs = start + hours*3600,nil

    rs = setTimeout(function()
      rs = nil 
      local thours = round((TQ.userTime()-start)/3600)
      TQ.DEBUG("Speed run ended after %s hours, %s",thours,TQ.userDate("%c"))
      __speed(0)
    end,round((hours*3600)*1000),"__speed")

    TQ.DEBUG("Speed run started, will run for %s hours, until %s",hours,TQ.userDate("%c",round(stop)))
    while speedFlag do
      if times then
        if TQ.DBG.timer then printTimers() end
        local t = pop()
        if t then
          local ref = getTimerRef(t.id)
          setTimerRef(t.id,nil)
          if ref and ref.hook then pcall(ref.hook,false) end
          local time = t.time
          TQ.setTimeOffset(time-TQ.milliClock())
          local stat,err = pcall(ref.fun)
          if not stat then
            t.env._error(fmt("setTimeout:%s",tostring(err)))
          end
        end
      end
      TQ.copas.pause(0)
    end
    if rs then rs = clearTimeout(rs) end
    TQ.DEBUG("Normal speed resumed, %s",TQ.userDate("%c"))
  --end)
end

local speedHook = nil
function __speed(hours,hook) -- Start/stop speeding
  assert(type(hours)=='number',"Invalid __emu_speed hours")
  speedHook = hook or speedHook
  local ns = hours > 0
  if ns == speedFlag then return end
  speedFlag = ns
  for t,ref in pairs(timers) do
    ref.timer:cancel() -- Cancel and reschedule all current timers
    rescheduleTimer(ref)
  end
  if speedHook then pcall(speedHook,speedFlag) end
  if speedFlag then TQ.startSpeedTimeAux(hours) end
end

function TQ.startSpeedTime(hours) __speed(hours) end

-------------- Exported functions -------------------

function setTimeoutRef(ref)
  timers[tostring(ref.id)] = ref
  ref.time = TQ.userMilli() + ref.ms/1000.0
  if speedFlag then 
    setTimeoutSpeed(ref) 
  else 
    setTimeoutStd(ref)
  end
  return ref.id
end

function setTimeout(fun,ms,tag,hook)
  local _,ref = createTimerRef(nil,ms,fun,tag,hook)
  return setTimeoutRef(ref)
end

local function midnightLoop()
  local d = TQ.userDate("*t")
  d.hour,d.min,d.sec = 24,0,0
  local midnxt = TQ.userTime(d)
  local function loop()
    TQ.post({type="midnight"},true)
    local d = TQ.userDate("*t")
    d.hour,d.min,d.sec = 24,0,0
    midnxt = TQ.userTime(d)
    --print("MID",TQ.userDate("%c",midnxt))
    setTimeout(loop,(midnxt-TQ.userTime())*1000,"Midnight")
  end
  --print("MID",TQ.userDate("%c",midnxt))
  setTimeout(loop,(midnxt-TQ.userTime())*1000,"Midnight")
end

local function parseTime(str)
  local D,h = str:match("^(.*) ([%d:]*)$")
  if D == nil and str:match("^[%d/]+$") then D,h = str,os.date("%H:%M:%S")
  elseif D == nil and str:match("^[%d:]+$") then D,h = os.date("%Y/%m/%d"),str
  elseif D == nil then error("Bad time value: "..str) end
  local y,m,d = D:match("(%d+)/(%d+)/?(%d*)")
  if d == "" then y,m,d = os.date("%Y"),y,m end
  local H,M,S = h:match("(%d+):(%d+):?(%d*)")
  if S == "" then H,M,S = H,M,0 end
  assert(y and m and d and H and M and S,"Bad time value: "..str)
  return os.time({year=y,month=m,day=d,hour=H,min=M,sec=S})
end

TQ.exports.__emu_setTimeout = setTimeout
TQ.exports.__emu_setInterval = setInterval
TQ.exports.__emu_clearTimeout = clearTimeout
TQ.exports.__emu_clearInterval = clearTimeout
TQ.exports.__emu_speed = __speed
TQ.cancelTimers = cancelTimers
TQ.midnightLoop = midnightLoop
TQ.startSpeedTime = TQ.startSpeedTime or function() end
TQ.parseTime = parseTime