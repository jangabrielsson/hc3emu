TQ = TQ
local mobdebug = TQ.mobdebug
local DEBUGF = TQ.DEBUGF
local DEBUG = TQ.DEBUG
local json = TQ.json
local addThread = TQ.addThread

local SCENE_ID = 6000
local compileCond
function TQ.nextSceneId() SCENE_ID = SCENE_ID + 1; return SCENE_ID end

TQ.Scenes = {}
local setupDateEvent

local ENV = {}
local function createSceneStruct(info)
  local env = info.env
  ENV = env
  if info.directive == nil then TQ.parseDirectives(info) end
  local flags = info.directives or {}
  info.id = flags.id or TQ.nextSceneId()
  local os2 = { time = TQ.userTime, clock = os.clock, difftime = os.difftime, date = TQ.userDate, exit = os.exit, remove = os.remove }
  local fibaro = { hc3emu = TQ, HC3EMU_VERSION = TQ.VERSION, flags = info.directives, DBG = TQ.DBG }
  for k,v in pairs({
    __assert_type = __assert_type, fibaro = fibaro, json = json, urlencode = TQ.urlencode, args=args,
    collectgarbage = collectgarbage, os = os2, math = math, string = string, table = table, _print = print,
    getmetatable = getmetatable, setmetatable = setmetatable, tonumber = tonumber, tostring = tostring,
    type = TQ.luaType, pairs = pairs, ipairs = ipairs, next = next, select = select, unpack = table.unpack,
    error = error, assert = assert, pcall = pcall, xpcall = xpcall,
    rawset = rawset, rawget = rawget
  }) do env[k] = v end
  
  env._error = function(str) env.fibaro.error(env.tag,str) end
  local conditions = info.src:match("CONDITIONS%s*=%s*(%b{})") or "{}"
  info.conditions = load("return "..conditions,nil,"t",env)()
  local triggers = {}
  info.condTest = compileCond(info.conditions,triggers)
  info.created = os.time()
  
  local eventHandler = function(ev)
    DEBUGF('scene',"Event handler %s",json.encode(ev.event))
    local event = ev.event
    local flag = false
    if event.property == 'execute' then flag = true
    else 
      flag = info.condTest(
      {
        tmap = TQ.userDate("*t"),
        event=event,
        time = TQ.userTime(), -- So all rules are evaluated with the same time...
      }
    ) end
    if flag then
      DEBUGF('scene',"Scene %s triggered by %s %s",info.id,json.encode(event),TQ.userDate("%c"))
    else
      DEBUGF('scene',"Scene %s not triggered by %s %s",info.id,json.encode(event),TQ.userDate("%c"))
    end
    if flag then TQ.sceneTrigger(event,info.id) end
  end
  
  env._G = env
  for k,v in pairs(TQ.exports) do env[k] = v end
  
  for _,path in ipairs({"hc3emu.fibaro","hc3emu.net","hc3emu.sceneengine"}) do
    DEBUGF('info',"Loading Scene library %s",path)
    TQ.loadfile(path,env)
  end
  
  setTimeout = env.setTimeout
  env.tag = "Scene"..info.id
  env.sceneId = info.id
  ENV = env
  function env.print(...) 
    env.fibaro.debug(env.tag,...) 
  end
  
  local engine = env.__emu_sceneEngine
  if engine then engine.startRefreshListener(info) end
  
  TQ.setCoroData(nil,'env',env)
  engine.event({type='user',property='execute'},eventHandler) -- Add event listener for execute
  for _,ev in pairs(triggers) do -- Add event listeners for the type of events that trigger the scene
    DEBUGF('scene',"Adding event listener for %s",json.encode(ev))
    if ev.type=='date' then setupDateEvent(engine,ev,eventHandler) else engine.event(ev,eventHandler) end
  end 
end

local function loadSceneFile(info) end
local function saveScene(id) end
local function saveSceneProject(info) end

function setupDateEvent(engine,ev,eventHandler)
  if ev.property == 'sunrise' or ev.properties == 'sunset' then
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
    -- setup minute event loop that triggers scene
  elseif ev.property == 'interval' then
    -- setup minute event loop that triggers scene
  end
end

local function triggerScene(info,trigger)
  local env = {} -- New fresh environment
  local flags = info.directives or {}
  for k,v in pairs(info.env) do env[k] = v end
  env.sourceTrigger = trigger
  local timers = 0
  env.__emu_timerHook[1] = function(start)
    if start then timers = timers + 1 else timers = timers - 1 end
    if timers == 0 then DEBUG("Scene %s terminated", info.id) end
  end
  setTimeout = env.setTimeout
  addThread(env,function()
    TQ.mobdebug.on()
    TQ.setCoroData(nil,'env',env)
    if flags.speed then env.__emu_speed(flags.speed) end
    DEBUGF('info',"Loading user main file %s",info.fname)
    DEBUGF('info',"Running scene %s",info.id)
    load(info.src,info.fname,"t",env)()
    if not TQ.flags.offline then -- Move!
      assert(TQ.URL and TQ.USER and TQ.PASSWORD,"Please define URL, USER, and PASSWORD") -- Early check that creds are available
    end
  end)
end

local startTr = {type='user', property='execute', id=2}
local function runScene(info) -- Actually, register scene, run when triggered
  mobdebug.on()
  createSceneStruct(info)
  local flags = info.directives or {}
  local firstLine = TQ.findFirstLine(info.src)
  if flags.breakOnLoad and firstLine then TQ.mobdebug.setbreakpoint(info.fname,firstLine) end
  loadSceneFile(info)
  if flags.save then saveScene(info.id) end
  if flags.project then saveSceneProject(info) end
  DEBUGF('info',"Scene '%s' registered",flags.name)
  TQ.post({type='scene_registered',id=info.id},true)
  TQ.Scenes[info.id] = info
  for _,tr in pairs(flags.triggers or {}) do
    info.env.setTimeout(function() 
      info.env.__emu_sceneEngine.post(tr.trigger)
    end,1000*tr.delay)
  end
  return info
end

function TQ.sceneTrigger(trigger,id)
  if id then 
    local scene = TQ.Scenes[id]
    assert(scene,"Scene %d not found",id)
    triggerScene(scene,trigger)
  end
end

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
    a = function(_) return ENV.fibaro.getValue(id,property) end
  end
  local b = function() return value end
  local op = operators[cond.operator]
  if cond.isTrigger then
    trs[property..id] = {type='device',id=id,property=property}
  end
  return function(ctx) return op(a(ctx),b()) end
end

local function compileDateTest(date,op)
  local function ign(x) return x=='*' and nil or x end
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
    trs['cron'..key] = {type='date',property='cron',value=value}
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
    local t = TQ[typ.."Hour"]
    local h,m = t:match("(%d+):(%d+)")
    return 60*tonumber(h)+tonumber(m)+value
  end
  local b = function(ctx)
    local h,m = TQ.userDate("%H:%M",ctx.time):match("(%d+):(%d+)")
    return 60*tonumber(h)+tonumber(m)
  end
  if cond.isTrigger then
    trs[typ..value] = {type='date',property=typ,value=value}
  end
  return function (ctx)
    local a,b = a(ctx),b(ctx)
    --print(TQ.userDate("%c"),a//60,a%60,b//60,b%60)
    return a == b  
  end
end

function compilers.cron(cond,trs)
  local value = cond.value
  local op = cond.operator
  if op == 'matchInterval' then
    local cron = value.date
    local interval = value.interval
  else
    local cron = value
  end
  if cond.isTrigger then
    trs[property] = {type='cron',id=nil,propertyName=property}
  end
  return function(_) return false end
end

function compilers.weather(cond)
end

function compilers.alarm(cond)
end

compilers['global-variable'] = function(cond,trs)
  local name = cond.property
  local value = cond.value
  local a = function() return ENV.fibaro.getGlobalVariable(name) end
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
  local a = function() return ENV.fibaro.getCustomEvent(name) end
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

TQ.runScene = runScene