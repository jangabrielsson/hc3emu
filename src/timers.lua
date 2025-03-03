local TQ = TQ
local copas = TQ.copas
local mobdebug = TQ.mobdebug

local ref,timers = 0,{}
local fmt = string.format

local function cancelTimers(id) 
  if id == nil then 
    for _,t in pairs(timers) do t:cancel() end timers = {} 
  else
    for _,t in pairs(timers) do 
      if TQ.getCoroData(t.co,'deviceId') == id then t:cancel() timers[t]= nil end 
    end
  end
end

local __setTimeout
local __setInterval
local __clearTimeout
local __clearInterval

if not TQ.flags.speed then
  local function callback(_,args) mobdebug.on() timers[args[2]] = nil args[1]() end
  local function setTimeoutAux(rec,fun,ms,env)
    local id = TQ.getCoroData(nil,'deviceId')
    local env = id and TQ.getQA(id).env or nil
    ref = ref+1
    local ref0 = not rec and ref or "n/a"
    local t = copas.timer.new({
      name = "setTimeout:"..ref,
      delay = ms / 1000.0,
      recurring = rec,
      initial_delay = rec and ms / 1000.0 or nil,
      callback = callback,
      params = {fun,ref0},
      errorhandler = function(err, coro, skt)
        if env then
          env.fibaro.error(tostring(env.__TAG),fmt("setTimeout:%s",tostring(err)))
        end
        timers[ref]=nil
        copas.seterrorhandler()
        --print(copas.copas.gettraceback(err,coro,skt))
      end
    })
    timers[ref] = t
    -- Keep track of what QA started what timer
    -- Will allows us to kill all timers started by a QA when it is deleted
    TQ.setCoroData(t.co,'deviceId',(env and env.plugin or {}).mainDeviceId)
    return ref
  end
  
  function __setTimeout(fun,ms)
    if type(fun) ~= "function" then error("setTimeout: first argument must be a function",2) end
    if type(ms) ~= "number" then error("setTimeout: second argument must be a number",2) end
    return setTimeoutAux(false,fun,ms)
  end
  function __setInterval(fun,ms) 
    if type(fun) ~= "function" then error("setInterval: first argument must be a function",2) end
    if type(ms) ~= "number" then error("setInterval: second argument must be a number",2) end
    return setTimeoutAux(true,fun,ms) 
  end
  function __clearTimeout(ref)
    if timers[ref] then
      timers[ref]:cancel()
    end
    timers[ref]=nil
    copas.pause(0)
  end
  __clearInterval = __clearTimeout
end

if TQ.flags.speed then
  local times = nil
  local function insert(t,fun,env)
    local v = {t=t,fun=fun,cancel=function() end,env=env}
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
  local function remove(ref)
    local t = timers[ref]
    if t then
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
  local function pop()
    if not times then return end
    local t = times
    if t.next then times = t.next times.prev=nil else times = nil end
    return t
  end
  
  local function setTimeoutAux(fun,ms)
    local id = TQ.getCoroData(nil,'deviceId')
    local env = id and TQ.getQA(id).env or nil
    local ta = TQ.socket.gettime() + TQ.getTimeOffset() + ms/1000.0
    return insert(ta,fun,env)
  end
  function __setTimeout(fun,ms)
    if type(fun) ~= "function" then error("setTimeout: first argument must be a function",2) end
    if type(ms) ~= "number" then error("setTimeout: second argument must be a number",2) end
    timers[#timers+1] = setTimeoutAux(fun,ms)
    return #timers
  end
  function __clearTimeout(ref)
    local t = timers[ref]
    if t then
      timers[ref] = nil
      remove(t)
    end
  end
  
  function __setInterval(fun,ms,env)
    if type(fun) ~= "function" then error("setInterval: first argument must be a function",2) end
    if type(ms) ~= "number" then error("setInterval: second argument must be a number",2) end
    local ref = nil
    local function loop()
      if ref == nil or timers[ref]==nil then return end
      fun()
      timers[ref] = __setTimeout(loop,ms)
    end
    ref = __setTimeout(loop,ms)
    return ref
  end
  
  __clearInterval = clearTimeout
  
  function TQ.startSpeedTime()
    TQ.addThread(nil,function()
      local start = TQ.userTime()
      local stop = start + TQ.flags.speed*3600
      TQ.DEBUG("Speed run started, will run for %s hours",TQ.flags.speed)
      while true do
        if times then
          local t = pop()
          if t then
            local time = t.t
            TQ.setTimeOffset(time-TQ.socket.gettime())
            local stat,err = pcall(t.fun)
            if not stat then
              t.env.fibaro.error(tostring(t.env.__TAG),fmt("setTimeout:%s",tostring(err)))
            end
          end
        end
        if TQ.userTime() >= stop then
          TQ.DEBUG("Speed run ended after %s hours",TQ.flags.speed)
          os.exit()
        end
        TQ.copas.pause(0)
      end
    end)
  end
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
    __setTimeout(loop,(midnxt-TQ.userTime())*1000)
  end
  __setTimeout(loop,(midnxt-TQ.userTime())*1000)
end

TQ.exports.__emu_setTimeout = __setTimeout
TQ.exports.__emu_setInterval = __setInterval
TQ.exports.__emu_clearTimeout = __clearTimeout
TQ.exports.__emu_clearInterval = __clearInterval
TQ.cancelTimers = cancelTimers
TQ.midnightLoop = midnightLoop
TQ.startSpeedTime = TQ.startSpeedTime or function() end