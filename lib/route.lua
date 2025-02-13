  -- A router can operate in 2 modes. router.local=true or router.local=false
  -- If false it route to local handler if it exists, otherwise it routes (pass through) to HC3
  -- If true it routes to local handler if it exists, otherwise it returns 501
  
local fmt = string.format
local DBG = TQ.DBG
local DEBUGF = TQ.DEBUGF

local function errorWrapper(fun) 
  return function(...) local r = {pcall(fun,...)} if r[1] then return table.unpack(r,2) else return table.unpack(r[2]) end end 
end

local urldecode = function(url)
  return (url:gsub("%%(%x%x)", function(x) return string.char(tonumber(x, 16)) end))
end

function Route(passThroughHandler)   -- passThroughHandler is a function that takes method,path,data,flags and returns value,code
  local ROUTEDIR = { GET={}, POST={}, PUT={}, DELETE={} }
  local self = {
    ROUTEDIR = ROUTEDIR,
    passThroughHandler = passThroughHandler
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
      if d0 == nil then return nil end
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

  function self:setLocal(lcl) self['local'] = lcl end

  function self:call(method,path,data,flags) 
    flags = flags or {}
    local orgPath = path
    local path2,query = path:match("(.-)%?(.*)") 
    path = path2 or path
    local handler,vars = self:getRoute(method,path)
    if self['local'] then -- offline, if we don't have a handler it's an error (unimplemented)
      if not flags.silent and DBG.http then DEBUGF('http',"API: %s%s",method,orgPath) end
      if handler == nil then return nil,501 end
      if handler then vars[#vars+1]=data vars[#vars+1]=query and parseQuery(query) or {} vars[#vars+1]=flags end
      local value,code = handler(method..path,table.unpack(vars))
      return value,code
    else -- proxy or no proxy, use route if it exists, otherwise call through
      if handler then
        if handler then vars[#vars+1]=data vars[#vars+1]=query and parseQuery(query) or {} vars[#vars+1]=flags end
        local value,code = handler(method..path,table.unpack(vars))
        if code == 301 then -- handler didn't want to handle it, pass through
          return self.passThroughHandler(method,orgPath,data,flags)  -- redirect to hc3
        else
          return value,code 
        end
      else
        return self.passThroughHandler(method,orgPath,data,flags)
      end
    end
  end

  return self
end

return Route
