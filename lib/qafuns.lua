local TQ = fibaro.hc3emu
local copas = TQ.copas
local mobdebug = TQ.mobdebug

local ref,timers = 0,{}
local fmt = string.format

function TQ.cancelTimers() for _,t in pairs(timers) do t:cancel() end end

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