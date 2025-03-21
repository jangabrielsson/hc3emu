local type = type
if fibaro then type = fibaro.hc3emu.lua.type end

function property(get,set)
  return {__PROP=true,get=get,set=set}
end

local function setupProps(cl,t,k,v)
  local props = {}
  function cl.__index(t,k)
    if props[k] then return props[k].get(t)
    else return cl[k] end -- rawget(cl,k)
  end
  function cl.__newindex(t,k,v)
    if type(v)=='table' and v.__PROP then
      props[k]=v
    elseif props[k] then props[k].set(t,v)
    else rawset(t,k,v) end
  end
  cl.__newindex(t,k,v)
  return props
end

function class(name)
  local cl,fmt,index,props = {},string.format,0,nil
  cl.__index = cl
  local cl2 = {}
  cl2.__index = cl
  cl2.__newindex = cl
  function cl.__newindex(t,k,v)
    if type(v)=='table' and rawget(v,'__PROP') and not props then props=setupProps(cl,t,k,v)
    else rawset(t,k,v) end
  end
  local pname = fmt("class %s",name)
  cl.__USERDATA = true
  function cl2.__tostring() return pname end
  function cl2.__call(_,...)
    index = index + 1
    local obj = setmetatable({___index=index,__USERDATA = true},cl)
    local init = rawget(cl,'__init')
    if init then init(obj,...) end
    return obj
  end
  _G[name] = setmetatable({ __org = cl,__USERDATA = true },cl2)
  return function(parent)
    if parent == nil then error("Parent class not found") end
    setmetatable(cl,parent.__org)
    if parent.__org.__tostring then -- inherent parent tostring
      cl.__tostring = parent.__org.__tostring
    else
      function cl.__tostring(obj)
        return fmt("[obj:%s:%s]",name,obj.___index)
      end
    end
  end
end

local function class3(name)
  local cls = setmetatable({__USERDATA=true}, {
    __call = function(t,...)
      assert(rawget(t,'__init'),"No constructor")
      local obj = {__USERDATA=true}
      setmetatable(obj,{__index=t, __tostring = t.__tostring or function() return "object "..name end})
      obj:__init(...)
      return obj
    end,
    __tostring = function() return "class "..name end,
  })
  _G[name] = cls
  return function(p) getmetatable(cls).__index = p end
end

return class3