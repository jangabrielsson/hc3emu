local exports = {}
local E = setmetatable({},{ __index=function(t,k) return exports.emulator[k] end })

local fmt = string.format
local copas = require("copas")
local socket = require("socket")

---------- Time functions --------------------------
--- User has own time that can be an offset to real time
local orgTime,orgDate,timeOffset = os.time,os.date,0
function exports.setTime(t,update)
  if type(t) == 'string' then t = exports.parseTime(t) end
  timeOffset = t - orgTime() 
  if update~=false then E:post({type='time_changed'}) end
  E:DEBUGF('info',"Time set to %s",exports.userDate("%c"))
end

local function round(x) return math.floor(x+0.5) end
local function userTime(a) return a == nil and round(socket.gettime() + timeOffset) or orgTime(a) end
local function userMilli() return socket.gettime() + timeOffset end
local function userDate(a, b) return b == nil and orgDate(a, userTime()) or orgDate(a, round(b)) end
local function milliClock() return socket.gettime() end

function exports.getTimeOffset() return timeOffset end
function exports.setTimeOffset(offs) timeOffset = offs end
exports.milliClock = milliClock
exports.userTime = userTime
exports.userMilli = userMilli
exports.userDate = userDate
----------------------------------------------------------
---
local timerIdx = 0   -- Every timer gets a new number
local timers = {}    -- Table of all timers, string(idx)->TimerRef
local function createTimerRef(timer,ms,fun,tag,runner)
  timerIdx = timerIdx + 1
  E:DEBUGF('timer_dev',"createTimerRef:%s",timerIdx)
  local ref = {
    ms = ms, -- Time in ms when timer should fire
    timer = timer, -- Should support timer:cancel()
    time = userMilli() + ms/1000.0, -- Absolute time when timer should fire msepoch
    fun = fun, -- Function to call
    tag = tag, -- Tag for timer (debug)
    runner = runner, -- Runner starting this timer
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
    E:DEBUGF('timer_dev',"cancelTimerRef:%s",id)
    t.timer:cancel()
    pcall(t.runner.timerCallback,t.runner,t,"cancel")
    timers[id] = nil
  end
end


local setTimeoutAuxSpeed

local function cancelTimers(runner) 
  if runner == nil then 
    for t,_ in pairs(timers) do cancelTimerRef(t) end timers = {} 
  else
    for t,ref in pairs(timers) do 
      local crunner = E:getRunner(ref.timer.co)
      if crunner == runner then cancelTimerRef(t) end
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
  E.mobdebug.on()
  local ref = getTimerRef(id)
  E:DEBUGF('timer_dev',"timer std expire:%s",id)
  setTimerRef(id,nil)
  local oldRunner = E:setRunner(ref.runner)
  local stat,err = pcall(ref.fun)
  E:setRunner(oldRunner)
  pcall(ref.runner.timerCallback,ref.runner,ref,"expire")
  if not stat then
    ref.runner:_error(fmt("setTimeout:%s",tostring(err)))
  end
end

local function setTimeoutStd(ref)
  local runner = E:getRunner()
  E:DEBUGF('timer_dev',"setTimeoutStd:%s %s",ref.id,ref.tag or "")
  local t = copas.timer.new({
    name = "setTimeout:"..ref.id,
    delay = ref.ms / 1000.0,
    recurring = false,
    initial_delay = nil,
    callback = callback,
    params = ref.id,
  })
  ref.timer = t
  -- Keep track of what QA started what timer
  -- Will allows us to kill all timers started by a QA when it is deleted
  E:setRunner(runner,t.co) -- New coroutine inherits runner
  return ref.id
end

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

local function insert(time,id,runner)
  local v = nil
  v = {time=time,id=id,runner=runner,cancel = function() remove(v) end }
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
  E:DEBUGF('timer_dev',"setTimeoutSpeed:%s %s",ref.id,ref.tag or "")
  local runner = E:getRunner()
  ref.timer = insert(ref.time,ref.id,runner)
end

local function rescheduleTimer(ref)
  assert(ref,"Invalid timer reference")
  setTimerRef(tostring(ref.id),ref)
  E:DEBUGF('timer_dev',"rescheduleTimer:%s %s",ref.id,ref.tag or "")
  local time = ref.time-userMilli()
  --print(userDate("%c",math.floor(ref.time)),userDate("%c"))
  ref.ms = time*1000
  setTimeoutRef(ref)
end

local logTimer
function setInterval(fun,ms,tag)
  tag = tag or "interval"
  local id,ref,src
  local function loop()
    setTimeoutRef(ref)
    if E:DBGFLAG('timer') then logTimer("setInterval",ref,src) end
    local stat,re = pcall(fun)
    if not stat then
      ref.runner:_error(fmt("setInterval: %s", tostring(re)))
      cancelTimerRef(id)
    end
  end
  id = setTimeout(loop,ms,tag)  
  ref = getTimerRef(id)
  if E:DBGFLAG('timer') then
    local info = debug.getinfo(2)
    src = fmt("%s:%s",info.source,info.currentline)
    logTimer("setInterval",ref) 
  end
  return id
end

local speedFlag = false

local function startSpeedTimeAux(hours)
  speedFlag = true
  local start = userTime()
  local stop,rs = start + hours*3600,nil
  
  rs = setTimeout(function()
    rs = nil 
    local thours = round((userTime()-start)/3600)
    E:DEBUG("Speed run ended after %s hours, %s",thours,userDate("%c"))
    __speed(0)
  end,round((hours*3600)*1000),"__speed")
  
  E:DEBUG("Speed run started, will run for %s hours, until %s",hours,userDate("%c",round(stop)))
  while speedFlag do
    if times then
      if E:DBGFLAG('timer') then printTimers() end
      local t = pop()
      if t then
        local ref = getTimerRef(t.id)
        setTimerRef(t.id,nil)
        local time = t.time
        exports.setTimeOffset(time-milliClock())
        local oldRunner = E:setRunner(ref.runner)
        local stat,err = pcall(ref.fun)
        E:setRunner(oldRunner)
        pcall(ref.runner.timerCallback,ref.runner,ref,"expire")
        if not stat then
          t.runner:_error(fmt("setTimeout:%s",tostring(err)))
        end
      end
    end
    copas.pause(0)
  end
  if rs then rs = clearTimeout(rs) end
  E:DEBUG("Normal speed resumed, %s",userDate("%c"))
  --printTimers()
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
  if speedHook then pcall(speedHook,speedFlag,"__speed") end
  if speedFlag then startSpeedTimeAux(hours) end
end

local function startSpeedTime(hours) __speed(hours) end

-------------- Exported functions -------------------

function setTimeoutRef(ref)
  timers[tostring(ref.id)] = ref
  ref.time = userMilli() + ref.ms/1000.0
  if speedFlag then 
    setTimeoutSpeed(ref) 
  else 
    setTimeoutStd(ref)
  end
  pcall(ref.runner.timerCallback,ref.runner,ref,"start")
  return ref.id
end

function logTimer(f,ref,src)
  if src == nil then
    local info = debug.getinfo(3)
    src = fmt("%s:%s",info.source,info.currentline)
  end
  local info = debug.getinfo(3)
  local t = userDate("%m.%d/%H:%M:%S",round(ref.time))
  E:DEBUG("%s:%s %s %s",f,ref.id,t,src)
end

function setTimeout(fun,ms,tag)
  local runner = E:getRunner()
  local _,ref = createTimerRef(nil,ms,fun,tag,runner)
  if E:DBGFLAG('timer') and tag ~= 'interval' then -- setInterval have their own logger
    logTimer("setTimeout ",ref) 
  end
  return setTimeoutRef(ref)
end

local function midnightLoop()
  local d = userDate("*t")
  d.hour,d.min,d.sec = 24,0,0
  local midnxt = userTime(d)
  local function loop()
    --print("MID1",E:getRunner(),coroutine.running())
    E:post({type="midnight"},true)
    local d = userDate("*t")
    d.hour,d.min,d.sec = 24,0,0
    midnxt = userTime(d)
    --print("MID",userDate("%c",midnxt))
    setTimeout(loop,(midnxt-userTime())*1000,"Midnight")
  end
  --print("MID0",E:getRunner(),coroutine.running())
  --print("MID",userDate("%c",midnxt))
  setTimeout(loop,(midnxt-userTime())*1000,"Midnight")
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

local function init()
  E.exports.__emu_setTimeout = setTimeout
  E.exports.__emu_setInterval = setInterval
  E.exports.__emu_clearTimeout = clearTimeout
  E.exports.__emu_clearInterval = clearTimeout
  E.exports.__emu_speed = __speed
end

exports.cancelTimers = cancelTimers
exports.midnightLoop = midnightLoop
exports.startSpeedTime = startSpeedTime
exports.parseTime = parseTime
exports.init = init

return exports