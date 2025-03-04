local TQ = TQ
local copas = TQ.copas
local mobdebug = TQ.mobdebug

local ref,timers = 0,{}
local fmt = string.format

local setTimeoutAuxSpeed

local function cancelTimers(id) 
  if id == nil then 
    for _,t in pairs(timers) do t.ref:cancel() end timers = {} 
  else
    for _,t in pairs(timers) do 
      if TQ.getCoroData(t.co,'deviceId') == id then t.ref:cancel() timers[t]= nil end 
    end
  end
end

local setTimeoutStd
local setTimeoutSpeed
local setInterval
local clearTimeout
local __setTimeout
local __speed

local function callback(_,args) 
  mobdebug.on()
  timers[args[2]] = nil 
  args[1]() 
end

local function setTimeoutAuxStd(fun,ms,tag)
  local id = TQ.getCoroData(nil,'deviceId')
  local env = id and TQ.getQA(id).env or nil
  ref = ref+1
  local refIdx = tostring(ref)
  local ref0 = refIdx
  local t = copas.timer.new({
    name = "setTimeout:"..refIdx,
    delay = ms / 1000.0,
    recurring = false,
    initial_delay = nil,
    callback = callback,
    params = {fun,ref0,tag},
    errorhandler = function(err, coro, skt)
      if env then
        env.fibaro.error(tostring(env.__TAG),fmt("setTimeout:%s",tostring(err)))
      end
      timers[refIdx]=nil
      copas.seterrorhandler()
      --print(copas.copas.gettraceback(err,coro,skt))
    end
  })
  local ta = TQ.socket.gettime() + TQ.getTimeOffset() + ms/1000.0
  timers[refIdx] = {ref=t,time=ta,fun=fun,tag=tag}
  -- Keep track of what QA started what timer
  -- Will allows us to kill all timers started by a QA when it is deleted
  TQ.setCoroData(t.co,'deviceId',(env and env.plugin or {}).mainDeviceId)
  return tonumber(refIdx)
end

function setTimeoutStd(fun,ms,tag) return setTimeoutAuxStd(fun,ms,tag) end

function clearTimeout(ref)
  local refIdx = tostring(ref)
  if timers[refIdx] then
    timers[refIdx].ref:cancel()
  end
  timers[refIdx]=nil
  copas.pause(0)
end

local times = nil
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
local function insert(t,fun,env,idx,tag)
  local v = nil
  v = {t=t,fun=fun,cancel=function() remove(v) end,env=env,idx=idx,tag=tag}
  if not times then times = v return v end
  if t < times.t then
    times.prev = v
    v.next = times
    times = v
    return v
  end
  local p = times
  while p.next and p.next.t < t do p = p.next end
  v.next = p.next
  if p.next then p.next.prev = v end
  p.next = v
  v.prev = p
  return v
end
local function pop()
  if not times then return end
  local t = times
  if t.next then times = t.next times.prev=nil else times = nil end
  return t
end
local function numTimers()
  local n = 0
  local t = times
  while t do n = n + 1 t = t.next end
  return n
end

function setTimeoutAuxSpeed(fun,ms,idx,tag)
  local id = TQ.getCoroData(nil,'deviceId')
  local env = id and TQ.getQA(id).env or nil
  local ta = TQ.socket.gettime() + TQ.getTimeOffset() + ms/1000.0
  return insert(ta,fun,env,idx,tag)
end

function setTimeoutSpeed(fun,ms,tag)
  ref = ref+1
  local refIdx = tostring(ref)
  local tr = setTimeoutAuxSpeed(fun,ms,refIdx,tag)
  timers[refIdx] = {ref=tr,time=tr.t,fun=fun,tag=tag}
  return tonumber(refIdx)
end

local function rescheduleTimer(ref,fun,ms)
  local rs = tostring(ref)
  local nr = tostring(__setTimeout(fun,ms))
  timers[rs] = timers[nr]
  timers[nr] = nil
end

function setInterval(fun,ms)
  local ref = nil
  local function loop()
    rescheduleTimer(ref,loop,ms)
    fun()
  end
  ref = __setTimeout(loop,ms)
  return ref
end

local function round(x) return math.floor(x+0.5) end

local speedFlag = false
function TQ.startSpeedTime(hours)
  TQ.addThread(nil,function()
    speedFlag = true
    local start = TQ.userTime()
    local stop,rs = start + hours*3600,nil

    rs = __setTimeout(function()
      rs = nil 
      local thours = round((TQ.userTime()-start)/3600)
      TQ.DEBUG("Speed run ended after %s hours, %s",thours,TQ.userDate("%c"))
      __speed(0)
    end,round((hours*3600)*1000),"__speed")

    TQ.DEBUG("Speed run started, will run for %s hours, until %s",hours,TQ.userDate("%c",round(stop)))
    while speedFlag do
      if times then
        local t = pop()
        if t then
          local time = t.t
          timers[t.idx] = nil
          TQ.setTimeOffset(time-TQ.socket.gettime())
          local stat,err = pcall(t.fun)
          if not stat then
            t.env.fibaro.error(tostring(t.env.__TAG),fmt("setTimeout:%s",tostring(err)))
          end
        end
      end
      TQ.copas.pause(0)
    end
    if rs then rs = clearTimeout(rs) end
    TQ.DEBUG("Normal speed resumed, %s",TQ.userDate("%c"))
  end)
end

local speedHook = nil
function __speed(hours,hook) -- Start/stop speeding
  assert(type(hours)=='number',"Invalid __emu_speed hours")
  speedHook = hook or speedHook
  local ns = hours > 0
  if ns == speedFlag then return end
  speedFlag = ns
  -- if not speedFlag then
  --   print("speed")
  -- end
  for ref,t in pairs(timers) do
    t.ref:cancel() -- Cancel and reschedule all current timers
    rescheduleTimer(ref,t.fun,(t.time-TQ.userTime())*1000.0)
  end
  if speedHook then pcall(speedHook,speedFlag) end
  if speedFlag then TQ.startSpeedTime(hours) end
end

-------------- Exported functions -------------------

function __setTimeout(fun,ms,tag)
  if speedFlag then return setTimeoutSpeed(fun,ms,tag)
  else return setTimeoutStd(fun,ms,tag) end
end

local function __setInterval(fun,ms) return setInterval(fun,ms) end

local function __clearTimeout(ref) return clearTimeout(ref) end

local function __clearInterval(ref) return clearTimeout(ref) end

local function midnightLoop()
  local d = TQ.userDate("*t")
  d.hour,d.min,d.sec = 24,0,0
  local midnxt = TQ.userTime(d)
  local function loop()
    TQ.post({type="midnight"},true)
    local d = TQ.userDate("*t")
    d.hour,d.min,d.sec = 24,0,0
    midnxt = TQ.userTime(d)
    __setTimeout(loop,(midnxt-TQ.userTime())*1000)
  end
  __setTimeout(loop,(midnxt-TQ.userTime())*1000)
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

TQ.exports.__emu_setTimeout = __setTimeout
TQ.exports.__emu_setInterval = __setInterval
TQ.exports.__emu_clearTimeout = __clearTimeout
TQ.exports.__emu_clearInterval = __clearInterval
TQ.exports.__emu_speed = __speed
TQ.cancelTimers = cancelTimers
TQ.midnightLoop = midnightLoop
TQ.startSpeedTime = TQ.startSpeedTime or function() end
TQ.parseTime = parseTime