  -- A router can operate in 2 modes. router.local=true or router.local=false
  -- If false it route to local handler if it exists, otherwise it routes (pass through) to HC3
  -- If true it routes to local handler if it exists, otherwise it returns 501

--[[
       EmuRoute -> OfflineRoute -> NotImplementedRoute
       EmuRoute -> ProxyRoute -> HC3Route
       -- EmuRoute -> HC3Route
       HC3Route
--]]
local exports = {}
local E = setmetatable({},{ __index=function(t,k) return exports.emulator[k] end })

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

  function self:call(method,path,data,flags)
    if not flags.query then
      local pathStr,queryStr = path:match("(.-)%?(.*)") 
      flags.lookupPath = pathStr or path
      flags.callPath = method..flags.lookupPath
      flags.query = queryStr and parseQuery(queryStr) or {}
    end
    local handler,vars = self:getRoute(method,flags.lookupPath)
    if not handler then return nil,nil end
    if not flags.silent and E.DBG.http then E:DEBUGF('http',"API: %s%s",method,flags.lookupPath) end
    local args = {flags.callPath,table.unpack(vars)}
    args[#args+1] = data
    args[#args+1] = flags.query
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
    local flags = {}
    for _,route in ipairs(self.routes) do
      local value,code = route:call(method,path,data,flags)
      if not (code == nil or code == 301) then return value,code end
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
