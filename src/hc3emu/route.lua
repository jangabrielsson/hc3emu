--[[
  There are 3 "route chains" for requests built up from 4 route components.
  - EmuRoute handles api requests to devices run in the emulator. If the device is not running in the emulator, it will pass the request to the next route.
  - OfflineRoute handles api requests to devices that are not running in the emulator when we are not allowed to access the HC3. It uses db.lua to keep a database of resources. If it can't handle it it will pass to next route in chain.
  - ProxyRoute handles api requests to devices that are running in the emulator but also have a proxy on the HC3. Its job is to synchronize the state of the emulated device with the proxy device on the HC3. If it can't handle it, it will pass to next route in chain.

  The route chains setup is as follows:
       1. EmuRoute -> OfflineRoute -> NotImplementedRoute -- When running in offline mode
       2. EmuRoute -> ProxyRoute -> HC3Route              -- When running in proxy mode (and online without proxy)
       3. HC3Route                                        -- Used by system to talk to the HC3
--]]

local exports = {}
Emulator = Emulator
local E = Emulator.emulator

local fmt = string.format

local function errorWrapper(fun) 
  return function(...) 
    local r = {pcall(fun,...)} 
    if r[1] then 
      return table.unpack(r,2) 
    else
      local err = r[2]
      if type(err) == 'table' then
        return nil,err.code,err.message
      else
        print(err)
        return nil,500,err
      end
    end
  end 
end

local urldecode = function(url)
  return (url:gsub("%%(%x%x)", function(x) return string.char(tonumber(x, 16)) end))
end

local function Route()   -- passThroughHandler is a function that takes method,path,data,flags and returns value,code
  local ROUTEDIR = { GET={}, POST={}, PUT={}, DELETE={} }
  local self = {
    ROUTEDIR = ROUTEDIR,
  }
  
  function self:add(method, path, handler) 
    if type(path) == 'function' then -- shift args
      handler = path 
      method,path = method:match("(.-)(/.+)") -- split method and path
    end 
    local path = string.split(path,'/')
    local d = ROUTEDIR[method:upper()]
    for _,p in ipairs(path) do
      p = ({['<id>']=true,['<name>']=true})[p] and '_match' or p
      local d0 = d[p]
      if d0 == nil then d[p] = {} end
      d = d[p]
    end
    assert(d._handler == nil,fmt("Duplicate path: %s/%s",method,path))
    d._handler = errorWrapper(handler)
  end

  function self:getRoute(method,path)
    local path = string.split(path,'/')
    local d,vars = ROUTEDIR[method:upper()],{}
    for _,p in ipairs(path) do
      if d._match and not d[p] then vars[#vars+1] = p p = '_match' end
      local d0 = d[p]
      if d0 == nil then return nil,vars end
      d = d0
    end
    return d._handler,vars
  end

  local function parseQuery(queryStr)
    local params = {}
    local query = urldecode(queryStr)
    local p = query:split("&")
    for _,v in ipairs(p) do
      local k,v = v:match("(.-)=(.*)")
      params[k] = tonumber(v) or v
    end
    return params
  end

  function self:getHandler(method,path,data,flags)
    if not flags.query then
      local pathStr,queryStr = path:match("(.-)%?(.*)") 
      flags.lookupPath = pathStr or path
      flags.callPath = method..flags.lookupPath
      flags.query = queryStr and parseQuery(queryStr) or {}
    end
    local handler,vars = self:getRoute(method,flags.lookupPath)
    if not handler then return function(_) return nil,nil end,{} end
    local args = {flags.callPath,table.unpack(vars)}
    args[#args+1] = data
    args[#args+1] = flags.query
    return handler,args
  end

  function self:call(method,path,data,flags) -- Easier to step over when debugging
    local handler,args = self:getHandler(method,path,data,flags)
    return handler(table.unpack(args))
  end

  return self
end

local NotImplementedRoute = {
  call = function(_,_,_,_,_) return nil,501 end,
}

local HC3Route = {
  call = function(_,method,path,data,flags) return E:HC3Call(method,path,data,flags) end,
}

local function Connection()
  local self = { routes = {} }
  function self:addRoute(route) self.routes[#self.routes+1] = route end
  function self:call(method,path,data)
    local flags, check = {}, function(code,value,route) if not (code == nil or code == 301) then E:DEBUGF('api',"api/%s: %s%s",route == HC3Route and 'r' or 'l',method,path) return true end end
    for _,route in ipairs(self.routes) do
      local value,code = route:call(method,path,data,flags)
      if check(code,value,route) then return value,code end
    end
    return nil,505
  end
  return self
end

local route

local function createConnections()
  local con = Connection()
  con:addRoute(E.route.EmuRoute())
  con:addRoute(E.route.OfflineRoute())
  con:addRoute(NotImplementedRoute)
  exports.offlineConnection = con

  con = Connection()
  con:addRoute(E.route.EmuRoute())
  con:addRoute(E.route.ProxyRoute())
  con:addRoute(HC3Route)
  exports.proxyConnection = con

  con = Connection()
  con:addRoute(HC3Route)
  exports.hc3Connection = con
end

exports.createRouteObject = Route
exports.createConnections = createConnections

return exports
