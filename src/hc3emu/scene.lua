local exports = {}
local E = setmetatable({},{ __index=function(t,k) return exports.emulator[k] end })
local json = require("hc3emu.json")
local userTime,userDate

local function init()
  userTime,userDate = E.timers.userTime,E.timers.userDate
end

local compileCond
local scenes = {}
local setupDateEvent, sceneTrigger, minuteLoop, minuteFuns

---------------------- Scene class ---------------------------------------
class 'Scene'
local Scene = _G['Scene']; _G['Scene'] = nil
function Scene:__init(info)
  E.mobdebug.on()
  self.info = info
  self.fname = info.fname
  self.src = info.src
  self.env = info.env
  self:createSceneStruct()
end

function Scene:nextId() return E:getNextSceneId() end

function Scene:createSceneStruct()
  local env = self.env
  if self.info.directives == nil then E:parseDirectives(self.info) end
  self.flags = self.info.directives
  env.__debugFlags = self.flags.debug or {}
  self.name = self.flags.name
  local flags = self.flags
  self.id = flags.id or self:nextId()
  local os2 = { time = userTime, clock = os.clock, difftime = os.difftime, date = userDate, exit = os.exit, remove = os.remove }
  local fibaro = { hc3emu = E, HC3EMU_VERSION = E.VERSION, flags = flags, DBG = E.DBG }
  for k,v in pairs({
    __assert_type = __assert_type, fibaro = fibaro, json = json, urlencode = E.util.urlencode, args=args,
    collectgarbage = collectgarbage, os = os2, math = math, string = string, table = table, _print = print,
    getmetatable = getmetatable, setmetatable = setmetatable, tonumber = tonumber, tostring = tostring,
    type = E.luaType, pairs = pairs, ipairs = ipairs, next = next, select = select, unpack = table.unpack,
    error = error, assert = assert, pcall = pcall, xpcall = xpcall,
    rawset = rawset, rawget = rawget
  }) do env[k] = v end
  
  env._error = function(str) env.fibaro.error(env.tag,str) end
  local conditions = self.src:match("CONDITIONS%s*=%s*(%b{})") or "{}"
  self.conditions = load("return "..conditions,nil,"t",env)()
  local triggers = {}
  self.condTest = compileCond(self.conditions,triggers)
  self.created = os.time()
  
  local eventHandler = function(ev)
    E:DEBUGF('scene',"Event handler %s",json.encodeFast(ev.event))
    local event = ev.event
    local flag = false
    if event.property == 'execute' then flag = true
    else 
      flag = self.condTest(
      {
        tmap = userDate("*t"),
        event=event,
        time = userTime(), -- So all rules are evaluated with the same time...
      }
    ) end
    if flag then
      E:DEBUGF('scene',"Scene %s triggered by %s %s",self.id,json.encode(event),userDate("%c"))
    else
      E:DEBUGF('scene',"Scene %s not triggered by %s %s",self.id,json.encode(event),userDate("%c"))
    end
    if flag then sceneTrigger(event,self.id) end
  end
  
  env._G = env
  for k,v in pairs(E.exports) do env[k] = v end
  
  env.tag = "Scene"..self.id
  env.sceneId = self.id

  for _,path in ipairs({"hc3emu.fibaro","hc3emu.net","hc3emu.sceneengine"}) do
    E:DEBUGF('info',"Loading Scene library %s",path)
    E:loadfile(path,env)
  end
  
  setTimeout = env.setTimeout
  function env.print(...) 
    env.fibaro.debug(env.tag,...) 
  end
  
  local engine = env.__emu_sceneEngine
  if engine then engine.startRefreshListener(self) end
  
  E:setCoroData(nil,'env',env)
  engine.event({type='user',property='execute'},eventHandler) -- Add event listener for execute
  for _,ev in pairs(triggers) do -- Add event listeners for the type of events that trigger the scene
    E:DEBUGF('scene',"Adding event listener for %s",json.encodeFast(ev))
    if ev.type=='date' then setupDateEvent(engine,ev,eventHandler) else engine.event(ev,eventHandler) end
  end 
end

function Scene:run() -- Actually, register scene, run when triggered
  local flags = self.flags
  local firstLine = E.tools.findFirstLine(self.src)
  if flags.breakOnLoad and firstLine then E.mobdebug.setbreakpoint(self.fname,firstLine) end
  self:loadFiles() -- nop
  if flags.save then self:save() end
  if flags.project then self:saveProject() end
  E:DEBUGF('info',"Scene '%s' registered",self.name)
  E:post({type='scene_registered',id=self.id},true)
  scenes[self.id] = self
  for _,tr in pairs(flags.triggers or {}) do
    self.env.setTimeout(function() 
      self.env.__emu_sceneEngine.post(tr.trigger)
    end,1000*tr.delay)
  end
  --E:DEBUGF('info',"Scene '%s' run completed",self.name)
  return self
end

function Scene:register() return self:run() end

function Scene:trigger(trigger) -- Start scene
  trigger = trigger or {type='user',property='execute', id=2}
  local env = {} -- New fresh environment
  local flags = self.flags
  -- copy all globals from the scene environment
  for k,v in pairs(self.env) do env[k] = v end 
  env.sourceTrigger = trigger
  local timers = 0
  
  env.__emu_timerHook[1] = function(start,tag)
    if start then timers = timers + 1 else timers = timers - 1 end
    if timers == 0  then 
      E:DEBUG("Scene %s terminated", self.id) 
      env.__emu_timerHook[1] = nil
    end
    --print(t0,timers,start,tag)
  end
  
  minuteLoop(self.env)
  
  -- addThread(env,function()
  env.setTimeout(function()
    E.mobdebug.on()
    E:setCoroData(nil,'env',env)
    E:DEBUGF('scene',"Loading user main file %s",self.fname)
    E:DEBUGF('info',"Running scene %s",self.id)
    load(self.src,self.fname,"t",env)()
    if flags.speed then env.__emu_speed(flags.speed) end
    --if timers == 0 then DEBUG("Scene %s terminated", info.id) end
    if not E.DBG.offline then -- Move!
      assert(E.URL and E.USER and E.PASSWORD,"Please define URL, USER, and PASSWORD") -- Early check that creds are available
    end
    -- end)
  end,0)
end

function Scene:loadFiles() end
function Scene:save() end
function Scene:saveProject() end

-------------------------------------------------------------------------
---

function sceneTrigger(trigger,id)
  if id then 
    local scene = scenes[id]
    assert(scene,"Scene %d not found",id)
    scene:trigger(trigger)
  end
end

minuteFuns = {}
local mlr = nil
function minuteLoop(env)
  if mlr then return end
  E:DEBUGF('scene',"Starting cron loop")
  local m = (userTime() // 60 + 1)*60
  local function loop()
    for _,f in ipairs(minuteFuns) do f() end
    m = m+60
    mlr = env.__emu_setTimeout(loop,(m-userTime())*1000,"minuteLoop",nil)
  end
  mlr = env.__emu_setTimeout(loop,(m-userTime())*1000,"minuteLoop",nil)
end

function setupDateEvent(engine,ev,eventHandler)
  if ev.property == 'sunrise' or ev.property == 'sunset' then
    local prop = ev.property
    local value = ev.value
    local offset = value >= 0 and "+"..value or tostring(value)
    engine.event(ev,eventHandler)
    local function fun()
      engine.post(ev)                     -- Post event at time
      engine.post(fun,"n/"..prop..offset) -- and reschedule function for next day
    end
    engine.post(fun,"n/"..prop..offset) -- This should repeat every day
  elseif ev.property == 'cron' then
    local event = {type='date',property='cron',value=ev.value}
    local test = ev.test
    engine.event(event,eventHandler)
    minuteFuns[#minuteFuns+1] = function() 
      local t = userDate("*t")
      if test(t) then engine.handleEvent(event) end  
    end
  elseif ev.property == 'interval' then
    -- setup minute event loop that triggers scene
  end
end

-------------------- Conditions compiler ---------------------------------------
local function map(f,lst,trs)
  local res = {}
  for _,v in ipairs(lst) do table.insert(res,f(v,trs)) end
  return res
end

local operators = {
  ["=="] = function(a,b) return table.equal(a,b) end,
  [">"] = function(a,b) return a> b end, 
  ["<"] = function(a,b) return a< b end, 
  [">="] = function(a,b) return a>= b end,
  ["<="] = function(a,b) return a<= b end,
  ["!="] = function(a,b) return a~= b end,
  ["anyValue"] = function(_,_) return true end,
  ['match>'] = function(a,b) return a > b end,
  ['match>='] = function(a,b) return a >= b end,
  ['match<='] = function(a,b) return a <= b end,
  ['match<'] = function(a,b) return a < b end,
  ['match=='] = function(a,b) return a == b end,  
  ['match'] = function(a,b) return a == b end,
  ['match!='] = function(a,b) return a ~= b end,
}

local compilers = {}
function compilers.device(cond,trs)
  local id = cond.id
  local property = cond.property
  local value,a = cond.value,nil
  if property == 'centralSceneEvent' then
    a = function(ctx) return ctx.event.value or {} end
  else
    a = function(ctx) return ctx.fibaro.getValue(id,property) end
  end
  local b = function() return value end
  local op = operators[cond.operator]
  if cond.isTrigger then
    trs[property..id] = {type='device',id=id,property=property}
  end
  return function(ctx) return op(a(ctx),b()) end
end

local function compileDateTest(date,op)
  local function ign(x) return x~='*' and tonumber(x) or nil end
  local dmap = { 
    min = ign(date[1]), hour = ign(date[2]), day = ign(date[3]), 
    month = ign(date[4]), wday = ign(date[5]), year = ign(date[6]) 
  }
  return function(cdmap)
    for k,v in pairs(dmap) do if not op(cdmap[k],v) then return false end end
    return true
  end
end

function compilers.cron(cond,trs)
  if cond.operator == 'matchInterval' then return compilers.interval(cond,trs) end
  local value = cond.value
  local op = operators[cond.operator]
  local key = table.concat(value,",")
  local dateTest = compileDateTest(value,op)
  if cond.isTrigger then
    trs['cron'..key] = {type='date',property='cron',value=value,test=dateTest}
  end
  return function(ctx)
    return dateTest(ctx.tmap) 
  end
end

function compilers.interval(cond,trs)
  local value = cond.value.date
  local interval = cond.value.interval
  local key = table.concat(value,",")..interval
  if cond.isTrigger then
    trs['cron'..key] = {type='date',property='interval',value=value,interval=interval}
  end
  return function(ctx)
    return true  
  end
end

function compilers.date(cond,trs)
  if cond.property == 'cron' then return compilers.cron(cond,trs) end
  local typ = cond.property
  local value = cond.value or 0
  local a = function(ctx) 
    local t = E[typ.."Hour"]
    local h,m = t:match("(%d+):(%d+)")
    return 60*tonumber(h)+tonumber(m)+value
  end
  local b = function(ctx)
    local h,m = userDate("%H:%M",ctx.time):match("(%d+):(%d+)")
    return 60*tonumber(h)+tonumber(m)
  end
  if cond.isTrigger then
    trs[typ..value] = {type='date',property=typ,value=value}
  end
  return function (ctx)
    local a,b = a(ctx),b(ctx)
    --print(userDate("%c"),a//60,a%60,b//60,b%60)
    return a == b  
  end
end

function compilers.weather(cond)
end

function compilers.alarm(cond)
end

compilers['global-variable'] = function(cond,trs)
  local name = cond.property
  local value = cond.value
  local a = function(ctx) return ctx.env.fibaro.getGlobalVariable(name) end
  local b = function() return value end
  local op = operators[cond.operator]
  if cond.isTrigger then
    trs[name] = {type='global-variable',name=name}
  end
  return function(ctx) return op(a(),b()) end
end

compilers['custom-event'] = function(cond,trs)
  local name = cond.name
  local value = cond.value
  local a = function(ctx) return ctx.env.fibaro.getCustomEvent(name) end
  local b = function() return value end
  local op = operators[cond.operator]
  if cond.isTrigger then
    trs[name] = {type='custom-event',name=name}
  end
  return function(ctx) return op(a(),b()) end
end

function compileCond(cond,trs)
  assert(type(cond) == 'table',"Expected table, got %s",type(cond))
  if cond.operator and not cond.type then
    if cond.operator == 'all' then
      local args = map(compileCond,cond.conditions,trs)
      return function(ctx) for _,f in ipairs(args) do if not f(ctx) then return false end end; return true end
    elseif cond.operator == 'any' then
      local args = map(compileCond,cond.conditions,trs)
      return function(ctx) for _,f in ipairs(args) do if f(ctx) then return true end end; return false end
    else
      error("Unknown operator %s",cond.operator)
    end
  else
    local f = compilers[cond.type or ""]
    assert(f,"Unknown condition type %s",cond.type)
    return f(cond,trs)
  end
end

exports.Scene = Scene
exports.scenes = scenes
exports.trigger = sceneTrigger -- (trigger,id)
exports.init = init

return exports