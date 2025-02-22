local TQ = fibaro.hc3emu
local copas = TQ.copas
local mobdebug = TQ.mobdebug

local ref,timers = 0,{}
local fmt = string.format

function TQ.cancelTimers() for _,t in pairs(timers) do t:cancel() end end

if not TQ.flags.speed then
  local function callback(_,args) mobdebug.on() timers[args[2]] = nil args[1]() end
  local function _setTimeout(rec,fun,ms)
    ref = ref+1
    local ref0 = not rec and ref or "n/a"
    timers[ref]= copas.timer.new({
      name = "setTimeout:"..ref,
      delay = ms / 1000.0,
      recurring = rec,
      initial_delay = rec and ms / 1000.0 or nil,
      callback = callback,
      params = {fun,ref0},
      errorhandler = function(err, coro, skt)
        fibaro.error(tostring(__TAG),fmt("setTimeout:%s",tostring(err)))
        timers[ref]=nil
        copas.seterrorhandler()
      end
    })
    return ref
  end
  
  function setTimeout(fun,ms) return _setTimeout(false,fun,ms) end
  function setInterval(fun,ms) return _setTimeout(true,fun,ms) end
  function clearTimeout(ref)
    if timers[ref] then
      timers[ref]:cancel()
    end
    timers[ref]=nil
    copas.pause(0)
  end
  clearInterval = clearTimeout
end

if TQ.flags.speed then
  local times = nil
  local function insert(t,fun)
    local v = {t=t,fun=fun, cancel=function() end}
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

  local function _setTimeout(fun,ms)
    local ta = TQ.socket.gettime() + TQ.getTimeOffset() + ms/1000.0
    return insert(ta,fun)
  end
  function setTimeout(fun,ms)
    timers[#timers+1] = _setTimeout(fun,ms)
    return #timers
  end
  function clearTimeout(ref)
    local t = timers[ref]
    if t then
      timers[ref] = nil
      remove(t)
    end
  end

  function setInterval(fun,ms)
    local ref = nil
    local function loop()
      if ref == nil or timers[ref]==nil then return end
      fun()
      timers[ref] = _setTimeout(loop,ms)
    end
    ref = setTimeout(loop,ms)
    return ref
  end

  function clearInterval(ref)
    clearTimeout(ref)
  end

  TQ.addThread(function()
    local start = TQ.userTime()
    local stop = start + TQ.flags.speed*3600
    TQ.DEBUG("Speed run started, will run for %s hours",TQ.flags.speed)
    while true do
      if times then
        local t = pop()
        if t then
          local time = t.t
          TQ.setTimeOffset(time-TQ.socket.gettime())
          t.fun()
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

local d = TQ.userDate("*t")
d.hour,d.min,d.sec = 24,0,0
local midnxt = TQ.userTime(d)
local function midnightLoop()
  TQ.post({type="midnight"},true)
  local now = TQ.userDate("*t")
  local d = TQ.userDate("*t")
  d.hour,d.min,d.sec = 24,0,0
  midnxt = TQ.userTime(d)
  setTimeout(midnightLoop,(midnxt-TQ.userTime())*1000)
end

setTimeout(midnightLoop,(midnxt-TQ.userTime())*1000)