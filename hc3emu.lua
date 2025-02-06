package.path = "/opt/homebrew/Cellar/luarocks/3.9.2/share/lua/5.4/?.lua;/opt/homebrew/share/lua/5.4/?.lua;/opt/homebrew/share/lua/5.4/?/init.lua;" .. package.path .. ";/Users/jangabrielsson/.luarocks/share/lua/5.4/?.lua"
package.cpath = package.cpath .. ";/opt/homebrew/lib/lua/5.4/?.so;/Users/jangabrielsson/.luarocks/lib/lua/5.4/?.so"

--[[
TQ - Tiny QuickApp emulator for the Fibaro Home Center 3
Copyright (c) 2025 Jan Gabrielsson
Email: jan@gabrielsson.com
                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.
--]]

socket = require("socket")
ltn12 = require("ltn12")
copas = require("copas")
timer = require("copas.timer")
http = require("copas.http")
json = require("cjson")

local cfgFileName = "hc3emu_cfg.lua"
local _type,_print = type,print

local TQ = {}
TQ.EMUVAR = "TQEMU"
TQ.emuPort = 8264
TQ.emuIP = nil 
__TAG = "INIT"

fibaro = { TQ = TQ }
net,api,plugin = {},{},{}
local flags,cfgFlags,DBG = {},{},{ info=true }

local stat, mobdebug = pcall(require, 'mobdebug')
TQ.mobdebug = mobdebug

local function DEBUG(f,...) _print("[SYS]",string.format(f,...)) end
local function DEBUGF(flag,f,...) if DBG[flag] then DEBUG(f,...) end end
local function WARNINGF(f,...) _print("[SYSWARN]",string.format(f,...)) end
local function ERRORF(f,...) _print("[SYSERR]",string.format(f,...)) end

local modules = {}
local MODULE = setmetatable({},{__newindex = function(t,k,v) 
      modules[#modules+1]={name=k,fun=v} 
    end })

local fmt = string.format

-- Get config file
local cfgf = loadfile(cfgFileName)
if cfgf then DEBUGF('info',"Loading config file %s",cfgFileName) 
  cfgFlags = cfgf()
end

-- Get main lua file
local info = debug.getinfo(3)
local fileName = info.source:match("@*(.*)")
local f = io.open(fileName)
local src = f:read("*all")
f:close()

--  Directives from main lua file (--%%key=value)
flags={ 
  name='MyQA', type='com.fibaro.binarySwitch', debug={}, dark = false, id = 5001, 
  var = {}, gv = {}, proxy=false, creds = {}
}

local function readDirectives(src)
  DEBUGF('info',"Reading %s directives...",fileName)

  function string.split(inputstr, sep)
    local t={}
    for str in string.gmatch(inputstr, "([^"..(sep or "%s").."]+)") do t[#t+1] = str end
    return t
  end

  local function eval(str)
    local stat, res = pcall(function() return load("return " .. str, nil, "t", { config = cfgFlags })() end)
    if stat then return res end
    ERRORF("directive '%s' %s",tostring(str),res)
    error()
  end

  src:gsub("%-%-%%%%(%w+)=(.-)%s*\n",function(f,v)
      if flags[f]~=nil then
        if _type(flags[f])=='table' then
          for _,vs in ipairs(v:split(',')) do 
            table.insert(flags[f],1,vs)
          end
        else 
          flags[f]=eval(v) 
        end
      else WARNINGF("Unknown directive: %s",tostring(f)) end
    end)

  for _,d in ipairs(flags.debug) do local n,v = d:match("(.-):(.*)") DBG[n] = eval(v) end
  local var = {}
  for _,d in ipairs(flags.var) do local n,v = d:match("(.-):(.*)") var[n] = eval(v) end
  flags.var = var

  flags.debug = DBG
  for k,v in pairs(cfgFlags) do 
    if flags[k]==nil then
      flags[k] = v
    elseif type(flags[k])=='table' and type(v)=='table' then
      local fv = flags[k]
      for k,v in pairs(v) do
        if fv[k]==nil then fv[k]=v end
      end
    end
  end

  fibaro.USER = flags.creds.user
  fibaro.PASSWORD = flags.creds.password
  fibaro.URL = flags.creds.url
end

function MODULE.lib()
  function urlencode(str) -- very useful
    if str then
      str = str:gsub("\n", "\r\n")
      str = str:gsub("([^%w %-%_%.%~])", function(c)
          return ("%%%02X"):format(string.byte(c))
        end)
      str = str:gsub(" ", "%%20")
    end
    return str
  end

  function table.copy(obj)
    if _type(obj) == 'table' then
      local res = {} for k,v in pairs(obj) do res[k] = table.copy(v) end
      return res
    else return obj end
  end

  function string.starts(str, start) return str:sub(1,#start)==start end

  function __assert_type(param, typ)
    if type(param) ~= typ then
      error(fmt("Wrong parameter type, %s required. Provided param '%s' is type of %s",typ, tostring(param), type(param)), 3) 
    end
  end

  local ZBCOLORMAP = {
    black="\027[30m",brown="\027[31m",green="\027[32m",orange="\027[33m",navy="\027[34m",
    purple="\027[35m",teal="\027[36m",grey="\027[37m", gray="\027[37m",red="\027[31;1m",
    tomato="\027[31;1m",neon="\027[32;1m",yellow="\027[33;1m",blue="\027[34;1m",magenta="\027[35;1m",
    cyan="\027[36;1m",white="\027[37;1m",darkgrey="\027[30;1m",
  }

  TQ.COLORS = { debug='green', trace='blue', warning='orange', ['error']='red', text='black' }
  if flags.dark then 
    TQ.COLORS.text='gray' 
    TQ.COLORS.trace='cyan' 
  end

  function TQ.html2color(str,startColor)
    local st,p = {ZBCOLORMAP[startColor or ""] or '\027[0m'},1
    return str:gsub("(</?font.->)",function(s)
        if s=="</font>" then
          p=p-1; return '\027[0m'..st[p]
        else
          local color = s:match("color=['\"]?([#%w]+)['\"]?")
          color = ZBCOLORMAP[color] or ZBCOLORMAP[TQ.COLORS['text']]
          p=p+1; st[p]=color
          return color
        end
      end)
  end

  local someRandomIP = "192.168.1.122" --This address you make up
  local someRandomPort = "3102" --This port you make up
  local mySocket = socket.udp() --Create a UDP socket like normal
  mySocket:setpeername(someRandomIP,someRandomPort) 
  local myDevicesIpAddress,_ = mySocket:getsockname()-- returns IP and Port
  TQ.emuIP = myDevicesIpAddress == "0.0.0.0" and "127.0.0.1" or myDevicesIpAddress

end

function MODULE.class()

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
      if _type(v)=='table' and v.__PROP then
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
      if _type(v)=='table' and rawget(v,'__PROP') and not props then props=setupProps(cl,t,k,v)
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
    _G[name] = setmetatable({ __org = cl },cl2)
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
end

function MODULE.net()

  local function httpRequest(method,url,headers,data,timeout,user,pwd)
    local resp, req = {}, {}
    req.url = url
    req.method = method
    req.headers = headers
    req.timeout = timeout and timeout / 1000
    req.sink = ltn12.sink.table(resp)
    req.headers["Accept"] = req.headers["Accept"] or "*/*"
    req.headers["Content-Type"] = req.headers["Content-Type"] or "application/json"
    req.user = user
    req.password = pwd
    if method == "PUT" or method == "POST" then
      data = data== nil and "[]" or json.encode(data)
      req.headers["Content-Length"] = #data
      req.source = ltn12.source.string(data)
    else
      req.headers["Content-Length"] = 0
    end
    local r,status,h = copas.http.request(req)
    if tonumber(status) and status < 300 then
      return resp[1] and table.concat(resp) or nil, status, h
    else
      return nil, status, h, resp
    end
  end

  local function HC3Call(method,path,data)
    assert(fibaro.URL,"Missing fibaro.URL")
    assert(fibaro.USER,"Missing fibaro.USER")
    assert(fibaro.PASSWORD,"Missing fibaro.PASSSWORD")
    local ic = {TQ.interceptAPI(method,path,data)}
    if ic[1] then return table.unpack(ic,2) end
    local t0 = socket.gettime()
    local res,stat,headers = httpRequest(method,fibaro.URL.."api"..path,{
        ["Accept"] = '*/*', 
        ["X-Fibaro-Version"] = 2, 
        ["Fibaro-User-PIN"] = fibaro.PIN,
      },
      data,15000,fibaro.USER,fibaro.PASSWORD)
    local t1 = socket.gettime()
    local jf,data = pcall(json.decode,res)
    local t2 = socket.gettime()
    if DBG.http then print(fmt("API: %s %.4fs (decode %.4fs)",path,t1-t0,t2-t1)) end
    return (jf and data or res),stat
  end

  function api.get(path) return HC3Call("GET",path) end
  function api.post(path,data) return HC3Call("POST",path,data) end
  function api.put(path,data) return HC3Call("PUT",path, data) end
  function api.delete(path,data) return HC3Call("DELETE",path,data) end

  function net.HTTPClient()
    return {
      request = function(_,url,options)
        copas.addthread(function()
            local res, status = httpRequest(options.method,url,options.headers,options.data,options.timeout)
            if res < 300 and options.success then options.success(res)
            elseif options.error then options.error(status) end
          end,0)
      end
    }
  end

  function net.TCPSocket(opts) 
    local self = { opts = opts or {} }
    self.sock = copas.wrap(socket.tcp())
    if tonumber(opts.timeout) then
      self.sock:settimeout(opts.timeout/1000) -- timeout in ms
    end
    function self:connect(ip, port, opts) 
      for k,v in pairs(self.opts) do opts[k]=v end
      local _, err = self.sock:connect(ip,port)
      if err==nil and opts and opts.success then opts.success()
      elseif opts and opts.error then opts.error(err) end
    end
    function self:read(opts) -- I interpret this as reading as much as is available...?
      local data,res = {}
      local b,err = self.sock:receive(1)
      if not err then
        data[#data+1]=b
        while socket.select({self.sock.socket},nil,0.1)[1] do
          b,err = self.sock:receive(1)
          if b then data[#data+1]=b else break end
        end
        res = table.concat(data)
      end
      if res and opts and opts.success then opts.success(res)
      elseif res==nil and opts and opts.error then opts.error(err) end
    end
    local function check(data,del)
      local n = #del
      for i=1,#del do if data[#data-n+i]~=del:sub(i,i) then return false end end
      return true
    end
    function self:readUntil(delimiter, opts) -- Read until the cows come home, or closed
      local data,ok,res = {},true,nil
      local b,err = self.sock:receive(sock,1)
      if not err then
        data[#data+1]=b
        if not check(data,delimiter) then
          ok = false
          while true do
            b,err = self.sock:receive(sock,1)
            if b then 
              data[#data+1]=b 
              if check(data,delimiter) then ok=true break end
            else break end
          end -- while
        end
        if ok then
          for i=1,#delimiter do table.remove(data,#data) end
          res = table.concat(data)
        end
      end
      if res and opts and opts.success then opts.success(res)
      elseif res==nil and opts and opts.error then opts.error(err) end
    end
    function self.readUntil(_,delimiter, callbacks) end
    function self:write(data, opts) 
      local res,err = self.sock:send(data)
      if res and opts and opts.success then opts.success(res)
      elseif res==nil and opts and opts.error then opts.error(err) end
    end
    function self:close() self.sock:close() end
    local pstr = "TCPSocket object: "..tostring(self):match("%s(.*)")
    setmetatable(self,{__tostring = function(_) return pstr end})
    return self
  end

  function net.UDPSocket(opts) 
    local self = { opts = opts or {} }
    self.sock = copas.wrap(socket.udp())
    if self.opts.broadcast~=nil then 
      self.sock:setsockname(TQ.IPAddress, 0)
      self.sock:setoption("broadcast", self.opts.broadcast) 
    end
    if tonumber(opts.timeout) then self.sock:settimeout(self2.opts.timeout / 1000) end

    function self:sendTo(datagram, ip,port, callbacks)
      local stat, res = self.sock:sendto(datagram, ip, port)
      if stat and callbacks.success then 
        pcall(callbacks.success,1)
      elseif stat==nil and callbacks.error then
        pcall(callbacks.error,res)
      end
    end 
    function self:bind(ip,port) self.sock:setsockname(ip,port) end
    function self:receive(callbacks) 
      local stat, res = self.sock:receivefrom()
      if stat and callbacks.success then 
        pcall(callbacks.success,stat, res)
      elseif stat==nil and callbacks.error then
        pcall(callbacks.error,res)
      end
    end
    function self:close() self.sock:close() end
    local pstr = "UDPSocket object: "..tostring(self):match("%s(.*)")
    setmetatable(self,{__tostring = function(_) return pstr end})
    return self
  end

end

function MODULE.proxy()

  function TQ.createProxy(name,devTempl)
    local code = [[
local fmt = string.format

function QuickApp:onInit()
  self:debug("Started", self.name, self.id)
  quickApp = self

  local send

  local IGNORE={ MEMORYWATCH=true,APIFUN=true}

  function quickApp:actionHandler(action)
    if IGNORE[action.actionName] then
      print(action.actionName)
      return quickApp:callAction(action.actionName, table.unpack(action.args))
    end
    send({type='action',value=action})
  end

  function quickApp:UIHandler(ev) send({type='ui',value=ev}) end

  function QuickApp:APIFUN(id,method,path,data)
    local stat,res,code = pcall(api[method:lower()],path,data)
    send({type='resp',id=id,value={stat,res,code}})
  end

  function QuickApp:initChildDevices() end

  local ip,port = nil,nil
  
  local function getAddress() -- continously poll for new address from emulator
    local var = __fibaro_get_global_variable("TQEMU") or {}
    local success,values = pcall(json.decode,var.value)
    if success then
      ip = values.ip
      port = values.port
    end
    setTimeout(getAddress,5000)
  end
  getAddress()

  local queue = {}
  local sender = nil
  local connected = false
  local sock = nil
  local runSender

  local function retry()
    if sock then sock:close() end
    connected = false
    queue = {}
    sender = setTimeout(runSender,1500)
  end
  
  function runSender()
    if connected then
      if #queue>0 then 
        sock:write(queue[1],{
          success = function() print("Sent",table.remove(queue,1)) runSender() end,
        })
      else sender = nil print("Sleeping") end
    else
      if not (ip and sender) then sender = setTimeout(runSender,1500) return end
      print("Connecting...")
      sock = net.TCPSocket()
      sock:connect(ip,port,{
          success = function(message)
            sock:read({
              succcess = retry,
              error = retry 
            })
            print("Connected") connected = true runSender() 
          end,
          error = retry
      })
    end  
  end 
 
  function send(msg) 
    msg = json.encode(msg).."\n"
    queue[#queue+1]=msg 
    if not sender then print("Starting") sender=setTimeout(runSender,0) end
  end   

end
]]

    local props = {
      apiVersion = "1.3",
      --quickAppVariables = devTempl.quickAppVariables or {},
--      viewLayout = {},
--      uiView = {},
      useUiView=false,
      typeTemplateInitialized = true,
    }
    local fqa = {
      apiVersion = "1.3",
      name = name,
      type = devTempl.type,
      initialProperties = props,
      --initialInterfaces = devTempl.interfaces,
      files = {{name="main", isMain=true, isOpen=false, type='lua', content=code}},
    }
    local res,code2 = api.post("/quickApp/", fqa)
    return res
  end

  function fibaro.callHC3(deviceId, actionName, ...)
    __assert_type(actionName, "string")
    __assert_type(deviceId, "number")
    local arg = { ... }; -- arg = #arg > 0 and arg or nil
    return api.post("/devices/" .. deviceId .. "/action/" .. actionName, {args = arg},"hc3")
  end

  function TQ.interceptAPI(method,path,data) end
  function TQ.setupInterceptors(id)
    local patterns,paths = {},{}

    local ref = 0
    local function proxyAPI(m,p,data)
      DEBUGF('proxyAPI',"proxyAPI: %s",p)
      if TQ.proxyId then
        local res = TQ.callAPIFUN(m,p,data)
        local _,d,c = table.unpack(res,1)
        if type(d)=='function' then d = nil end
        return true,d,c
      else return block(m,p,data) end
    end
    local function blockDeviceId(m,p,data)
      if data.deviceId == plugin.mainDeviceId and not TQ.proxyId then
        DEBUGF('blockAPI',"Blocked API: %s, (only proxy)",p)
        return true,nil,200
      end
    end
    local function call(m,p,data)
      if not TQ.proxyId then 
        return block(m,p,data)
      end
    end
    local function blockParentId(m,p,data)
      if data.parentId == plugin.mainDeviceId and not TQ.proxyId then return block(m,p,data) end
    end
    local function getStruct(m,p,d) if not TQ.proxyId then return true,plugin._dev,200 end end
    local function putStruct(m,p,d)
      for k,v in pairs(d) do plugin._dev[k] = v end
      if not TQ.proxyId then return true,d,200 end
    end
    local function getProp(m,p,d,id,prop)
      if not TQ.proxyId  or true then
        local value = plugin._dev.properties[prop]
        return true,{value=value,modified = plugin._dev.modified},200
      end
    end
    local store = {}
    local function getStore(m,p,d,_,v)
      if TQ.proxyId and false then return proxyAPI(m,p,d,_,v)
      else
        if v == "" then
          local res = {} for k,v in pairs(store) do res[#res+1]={name=k,value=v} end
          return true,res,200
        end
        local v = store[v]
        if v~=nil then return true,{value=v},200
        else return true,nil,409 end
      end
    end
    local function postStore(m,p,d)
      if TQ.proxyId and false then return proxyAPI(m,p,d)
      elseif not store[d.name] then return true,nil,409
      else 
        store[d.name]=d.value
        return true,d.value,200
      end
    end
    local function putStore(m,p,d)
      if TQ.proxyId and false then return proxyAPI(m,p,d)
      else
        store[d.name]=d.value
        return true,d.value,200
      end
    end
    local function deleteStore(m,p,d,_,v)
      if TQ.proxyId and false then return proxyAPI(m,p,d)
      else
        if v == "" then store = {} 
        else store[v]=nil end
        return true,true,200
      end
    end

    patterns["(%w+)/devices/"..id.."/?"] = {
      ['POST/devices/(%d+)/action'] = call,
      ['GET/devices/(%d+)/properties/([%w_]+)$'] = getProp,
    }
    patterns["(%w+)/plugins/"..id.."/"] = {
      ['GET/plugins/(%d+)/variables/?(.*)'] = getStore,
      ['PUT/plugins/(%d+)/variables/(.*)'] = putStore,
      ['POST/plugins/(%d+)/variables'] = postStore,
      ['DELETE/plugins/(%d+)/variables/?(.*)'] = deleteStore,
    }

    paths[fmt('GET/devices/(%s)',id)] = getStruct
    paths[fmt('PUT/devices/(%s)',id)] = putStruct
    paths[fmt('DELETE/devices/(%s)',id)] = block
    paths['POST/plugins/updateView'] = blockDeviceId
    paths['POST/plugins/updateProperty'] = blockDeviceId
    paths['POST/plugins/createChildDevice'] = blockParentId
    paths['POST/plugins/publishEvent'] = proxyAPI
    paths['POST/plugins/interfaces'] = proxyAPI

    function TQ.interceptAPI(method,path,data)
      local key = method..path
      if paths[key] then return paths[key](method,path,data)
      else
        for p,ps in pairs(patterns) do
          if key:match(p) then
            for p0,f in pairs(ps) do
              local m = {key:match(p0)}
              if #m>0 then return f(method,path,data,table.unpack(m)) end
            end
          end
        end
      end
    end
  end

  function TQ.getProxy(name,devTempl)
    local devStruct = api.get("/devices?name="..urlencode(name))
    if devStruct==nil or next(devStruct)==nil then
      devStruct = TQ.createProxy(name,devTempl)
      if not devStruct then return fibaro.error(__TAG,"Can't create proxy on HC3") end
      devStruct.id = math.floor(devStruct.id)
      DEBUG("Proxy installed: %s %s",devStruct.id,name)
    else
      devStruct = devStruct[1]
      devStruct.id = math.floor(devStruct.id)
      DEBUG("Proxy found: %s %s",devStruct.id,name)
    end
    TQ.proxyId = devStruct.id

    return devStruct
  end

  local callRef = {}
  local ref = 0
  function TQ.callAPIFUN(...)
    local id = ref; ref = ref+1
    local msg = {false,nil,'timeout'}
    local semaphore = copas.semaphore.new(10, 0, 100)
    fibaro.call(plugin.mainDeviceId,"APIFUN",id,...)
    callRef[id] = function(data) msg = data; semaphore:give(1) end
    semaphore:take(1)
    callRef[id] = nil
    return msg
  end

  function TQ.startServer()
    local emuval = json.encode({ip = TQ.emuIP, port = TQ.emuPort}) -- Update HC3 var with emulator connection data
    api.post("/globalVariables", {name=TQ.EMUVAR, value=emuval})
    api.put("/globalVariables/"..TQ.EMUVAR, {name=TQ.EMUVAR, value=emuval})
    DEBUGF('info',"Server started at %s:%s",TQ.emuIP,TQ.emuPort)

    local function handle(skt)
      mobdebug.on()
      local name = skt:getpeername() or "N/A"
      DEBUGF("server","New connection: %s",name)
      while true do
        local reqdata = copas.receive(skt)
        if not reqdata then break end
        local stat,msg = pcall(json.decode,reqdata)
        if stat then
          if msg.type == 'action' then onAction(msg.value.deviceId,msg.value)
          elseif msg.type == 'ui' then onUIEvent(msg.value.deviceId,msg.value)
          elseif msg.type == 'resp' then
            if callRef[msg.id] then local c = callRef[msg.id] callRef[msg.id] = nil pcall(c,msg.value) end
          else DEBUGF('server',"Unknown data %s",reqdata) end
        end
      end
      DEBUGF("server","Connection closed: %s",name)
    end
    local server = socket.bind('*', TQ.emuPort)
    copas.addserver(server, handle)
  end
end

function MODULE.fibaroSDK()

  function __ternary(c, t,f) if c then return t else return f end end
  function __fibaro_get_devices() return api.get("/devices/") end
  function __fibaro_get_device(deviceId) return api.get("/devices/"..deviceId) end
  function __fibaro_get_room(roomId) return api.get("/rooms/"..roomId) end
  function __fibaro_get_scene(sceneId) return api.get("/scenes/"..sceneId) end
  function __fibaro_get_global_variable(varName) return api.get("/globalVariables/"..varName) end
  function __fibaro_get_device_property(deviceId, propertyName) return api.get("/devices/"..deviceId.."/properties/"..propertyName) end
  function __fibaro_get_devices_by_type(type) return api.get("/devices?type="..type) end
  function __fibaro_add_debug_message(tag, msg, typ)
    typ = fmt("<font color='%s'>%s</font>",TQ.COLORS[typ],typ:upper())
    local str = fmt("%s[%s][%s]: %s",os.date("[%d.%m.%y][%H:%M:%S]"),typ,tag,msg)
    _print((TQ.html2color(str,TQ.COLORS['text'])))
  end

  function __fibaro_get_partition(id) return api.get('/alarms/v1/partitions/' .. tostring(id)) end
  function __fibaro_get_partitions() return api.get('/alarms/v1/partitions') end
  function __fibaro_get_breached_partitions() return api.get("/alarms/v1/partitions/breached") end
  function __fibaroSleep(ms)
    copas.pause(ms/1000.0)
  end

  fibaro = fibaro or {}
  hub = fibaro

  function  fibaro.getPartition(id)
    __assert_type(id, "number")
    return __fibaro_get_partition(id)
  end

  function fibaro.getPartitions() return __fibaro_get_partitions(id) end
  function fibaro.alarm(arg1, action)
    if type(arg1) == "string" then return fibaro.__houseAlarm(arg1) end
    __assert_type(arg1, "number")
    __assert_type(action, "string")
    local url = "/alarms/v1/partitions/" .. arg1 .. "/actions/arm"
    if action == "arm" then api.post(url)
    elseif action == "disarm" then api.delete(url)
    else error("Wrong parameter: " .. action .. ". Available parameters: arm, disarm", 2) end
  end

  function fibaro.__houseAlarm(action)
    __assert_type(action, "string")
    local url = "/alarms/v1/partitions/actions/arm"
    if action == "arm" then api.post(url)
    elseif action == "disarm" then api.delete(url)
    else error("Wrong parameter: '" .. action .. "'. Available parameters: arm, disarm", 3) end
  end

  function fibaro.alert(alertType, ids, notification)
    __assert_type(alertType, "string")
    __assert_type(ids, "table")
    __assert_type(notification, "string")
    local isDefined = "false"
    local actions = {
      email = "sendGlobalEmailNotifications",
      push = "sendGlobalPushNotifications",
      simplePush = "sendGlobalPushNotifications",
    }
    if actions[alertType] == nil then
      error("Wrong parameter: '" .. alertType .. "'. Available parameters: email, push, simplePush", 2)
    end
    for _,id in ipairs(ids) do __assert_type(id, "number") end

    if alertType == 'push' then
      local mobileDevices = __fibaro_get_devices_by_type('iOS_device')
      local usersId = ids
      ids = {}
      for _, userId in ipairs(usersId) do
        for _, device in ipairs(mobileDevices) do
          if device.properties.lastLoggedUser == userId then
            table.insert(ids, device.id)
          end
        end
      end
    end
    for _, id in ipairs(ids) do
      fibaro.call(id, actions[alertType], notification, isDefined)
    end
  end

  function fibaro.emitCustomEvent(name)
    __assert_type(name, "string")
    api.post("/customEvents/"..name)
  end

  function fibaro.call(deviceId, action, ...)
    __assert_type(action, "string")
    if type(deviceId) == "table" then
      for _,id in pairs(deviceId) do __assert_type(id, "number") end      
      for _,id in pairs(deviceId) do fibaro.call(id, action, ...) end 
    else
      __assert_type(deviceId, "number")
      local arg = {...}
      arg = #arg>0 and arg or nil
      return api.post("/devices/"..deviceId.."/action/"..action, { args = arg })
    end
  end

  function fibaro.callGroupAction(actionName, actionData)
    __assert_type(actionName, "string")
    __assert_type(actionData, "table")
    local response, status = api.post("/devices/groupAction/"..actionName, actionData)
    if status ~= 202 then return nil end
    return response.devices
  end

  function fibaro.get(deviceId, prop)
    __assert_type(deviceId, "number")
    __assert_type(prop, "string")
    prop = __fibaro_get_device_property(deviceId, prop)
    if prop == nil then return end
    return prop.value, prop.modified
  end

  function fibaro.getValue(deviceId, propertyName)
    __assert_type(deviceId, "number")
    __assert_type(propertyName, "string")
    return (fibaro.get(deviceId, propertyName))
  end

  function fibaro.getType(deviceId)
    __assert_type(deviceId, "number")
    local dev = __fibaro_get_device(deviceId)
    return dev and dev.type or nil
  end

  function fibaro.getName(deviceId)
    __assert_type(deviceId, 'number')
    local dev = __fibaro_get_device(deviceId)
    return dev and dev.name or nil
  end

  function fibaro.getRoomID(deviceId)
    __assert_type(deviceId, 'number')
    local dev = __fibaro_get_device(deviceId)
    return dev and dev.roomID or nil
  end

  function fibaro.getSectionID(deviceId)
    __assert_type(deviceId, 'number')
    local dev = __fibaro_get_device(deviceId)
    if dev == nil then return end
    return __fibaro_get_room(dev.roomID).sectionID
  end

  function fibaro.getRoomName(roomId)
    __assert_type(roomId, 'number')
    local room = __fibaro_get_room(roomId)
    return room and room.name or nil
  end

  function fibaro.getRoomNameByDeviceID(deviceId, propertyName)
    __assert_type(deviceId, 'number')
    local dev = __fibaro_get_device(deviceId)
    if not dev == nil then return end
    local room = __fibaro_get_room(dev.roomID)
    return room and room.name or nil
  end

  function fibaro.getDevicesID(filter)
    if not (type(filter) == 'table' and next(filter)) then
      return fibaro.getIds(__fibaro_get_devices())
    end

    local args = {}
    for key, val in pairs(filter) do
      if key == 'properties' and type(val) == 'table' then
        for n,p in pairs(val) do
          if p == "nil" then
            args[#args+1]='property='..tostring(n)
          else
            args[#args+1]='property=['..tostring(n)..','..tostring(p)..']'
          end
        end
      elseif key == 'interfaces' and type(val) == 'table' then
        for _,i in pairs(val) do
          args[#args+1]='interface='..tostring(i)
        end
      else
        args[#args+1]=tostring(key).."="..tostring(val)
      end
    end
    args = table.concat(args,"&")
    return fibaro.getIds(api.get('/devices/?'..args))
  end

  function fibaro.getIds(devices)
    local res = {}
    for _,d in pairs(devices) do
      if type(d) == 'table' and d.id ~= nil and d.id > 3 then res[#res+1]=d.id end
    end
    return res
  end

  function fibaro.getGlobalVariable(name)
    __assert_type(name, 'string')
    local var = __fibaro_get_global_variable(name)
    if globalVar == nil then return end
    return var.value, var.modified
  end

  function fibaro.setGlobalVariable(name, value)
    __assert_type(name, 'string')
    __assert_type(value, 'string')
    return api.put("/globalVariables/"..name, {value=tostring(value), invokeScenes=true})
  end

  function fibaro.scene(action, ids)
    __assert_type(action, "string")
    __assert_type(ids, "table")
    assert(action=='execute' or action =='kill',"Wrong parameter: "..action..". Available actions: execute, kill")
    for _, id in ipairs(ids) do __assert_type(id, "number") end      
    for _, id in ipairs(ids) do api.post("/scenes/"..id.."/"..action) end
  end

  function fibaro.profile(action, id)
    __assert_type(id, "number")
    __assert_type(action, "string")
    if action ~= "activeProfile" then
      error("Wrong parameter: " .. action .. ". Available actions: activateProfile", 2) 
    end
    return api.post("/profiles/activeProfile/"..id)
  end

  function fibaro.setTimeout(timeout, action, errorHandler)
    __assert_type(timeout, "number")
    __assert_type(action, "function")
    local fun = action
    if errorHandler then
      fun = function() 
        local stat,err = pcall(action)
        if not stat then pcall(errorHandler,err) end
      end
    end
    return setTimeout(fun, timeout)
  end

  function fibaro.clearTimeout(ref)
    __assert_type(ref, "number")
    clearTimeout(ref)
  end

  function fibaro.wakeUpDeadDevice(deviceID)
    __assert_type(deviceID, 'number')
    fibaro.call(1,'wakeUpDeadDevice',deviceID)
  end

  function fibaro.sleep(ms)
    __assert_type(ms, "number")
    __fibaroSleep(ms)
  end

  local function concatStr(...) 
    local args = {}
    for _,o in ipairs({...}) do args[#args+1]=tostring(o) end
    return table.concat(args," ")
  end

  function fibaro.debug(tag, ...)
    __assert_type(tag, "string")
    __fibaro_add_debug_message(tag, concatStr(...), "debug")
  end

  function fibaro.warning(tag, ...)
    __assert_type(tag, "string")
    __fibaro_add_debug_message(tag,  concatStr(...), "warning")
  end

  function fibaro.error(tag, ...)
    __assert_type(tag, "string")
    __fibaro_add_debug_message(tag,  concatStr(...), "error")
  end

  function fibaro.trace(tag, ...)
    __assert_type(tag, "string")
    __fibaro_add_debug_message(tag,  concatStr(...), "trace")
  end

  function fibaro.useAsyncHandler(value)
    __assert_type(value, "boolean")
    __fibaroUseAsyncHandler(value)
  end

  function fibaro.isHomeBreached()
    local ids = __fibaro_get_breached_partitions()
    return next(ids) ~= nil
  end

  function fibaro.isPartitionBreached(partitionId)
    __assert_type(partitionId, "number")
    for _,id in pairs(__fibaro_get_breached_partitions()) do
      if id == partitionId then return true end
    end
  end

  function fibaro.getPartitionArmState(partitionId)
    __assert_type(partitionId, "number")
    local partition = __fibaro_get_partition(partitionId)
    if partition ~= nil then
      return partition.armed and 'armed' or 'disarmed'
    end
  end

  function fibaro.getHomeArmState()
    local n,armed = 0,0
    for _,partition in pairs(__fibaro_get_partitions() or {}) do
      n = n + 1; armed = armed + (partition.armed and 1 or 0)
    end
    if armed == 0 then return 'disarmed'
    elseif armed == n then return 'armed'
    else return 'partially_armed' end
  end

end

function MODULE.plugin()
  plugin = plugin or {}
  function plugin.getDevice(deviceId) return api.get("/devices/"..deviceId) end
  function plugin.deleteDevice(deviceId) return api.delete("/devices/"..deviceId) end
  function plugin.getProperty(deviceId, propertyName) return api.get("/devices/"..deviceId).properties[propertyName] end
  function plugin.getChildDevices(deviceId) return api.get("/devices?parentId="..deviceId) end
  function plugin.createChildDevice(parentId, type, name)
    return api.post("/plugins/createChildDevice", {parentId=parentId, type=type, name=name,initialProperties=initialProperties})
  end
  function plugin.restart() os.exit() end
end

function MODULE.timers()
  local ref,timers = 0,{}

  local function callback(_,fun) mobdebug.on() fun() end
  function setTimeout(fun,ms)
    ref = ref+1
    timers[ref]= copas.timer.new({
        name = "setTimeout:"..ref,
        delay = ms / 1000.0,
        callback = callback,
        params = fun,
        errorhandler = function(err, coro, skt)
          copas.seterrorhandler()
          fibaro.error(__TAG,fmt("setTimeout:%s",err))
        end
      })
    return ref
  end

  function clearTimeout(ref) 
    if timers[ref] then timers[ref].cancel() end
    timers[ref]=nil
  end
end

function MODULE.QuickApp()

  class 'QuickAppBase'

  function QuickAppBase:__init(dev)
    plugin._dev = self
    if _type(arg) == 'number' then dev = api.get("/devices/" .. dev)
    elseif not _type(arg) == 'table' then error('expected number or table') end

    self.id = dev.id
    self.type = dev.type
    self.name = dev.name
    self.parentId = dev.parentId
    self.properties = dev.properties
    self.interfaces = dev.interfaces
    self.uiCallbacks = {}
    self.childDevices = {}
  end

  function QuickAppBase:debug(...) fibaro.debug(__TAG, ...) end
  function QuickAppBase:warning(...) fibaro.warning(__TAG, ...) end
  function QuickAppBase:error(...) fibaro.error(__TAG, ...) end
  function QuickAppBase:trace(...) fibaro.trace(__TAG, ...) end

  function QuickAppBase:updateProperty(name, value, forceUpdate)
    if (self.properties[name] ~= value or forceUpdate == true) then
      self.properties[name] = value
      api.post("/plugins/updateProperty", {
          deviceId= self.id,
          propertyName= name,
          value= value
        })
    end
  end

  function QuickAppBase:updateView(componentName, propertyName, newValue, forceUpdate)
    api.post("/plugins/updateView",{
        deviceId = self.id,
        componentName = componentName,
        propertyName = propertyName,
        newValue = newValue
      })
  end

  function QuickAppBase:hasInterface(name)
    for _, v in pairs(self.interfaces) do
      if v == name then
        return true
      end
    end
    return false
  end

  function QuickAppBase:addInterfaces(values)
    assert(type(values) == "table")
    self:updateInterfaces("add",values)
    for _, v in pairs(values) do
      table.insert(self.interfaces, v)
    end
  end

  function QuickAppBase:deleteInterfaces(values)
    assert(type(values) == "table")
    self:updateInterfaces("delete", values)
    for _, value in pairs(values) do
      for key, interface in pairs(self.interfaces) do
        if interface == value then
          table.remove(self.interfaces, key)
          break
        end
      end
    end
  end

  function QuickAppBase:updateInterfaces(action, interfaces)
    api.post("/plugins/interfaces", {action = action, deviceId = self.id, interfaces = interfaces})
  end
  function QuickAppBase:setName(name) api.put("/devices/" .. self.id,  {name=name}) end
  function QuickAppBase:setEnabled(enabled) api.put("/devices/" .. self.id, {enabled=enabled} ) end
  function QuickAppBase:setVisible(visible) api.put("/devices/" .. self.id, {visible=visible} ) end

  function QuickAppBase:registerUICallback(elm, typ, fun)
    local uic = self.uiCallbacks
    uic[elm] = uic[elm] or {}
    uic[elm][typ] = fun
  end

  function QuickAppBase:setupUICallbacks()
    local callbacks = (self.properties or {}).uiCallbacks or {}
    for _, elm in pairs(callbacks) do
      self:registerUICallback(elm.name, elm.eventType, elm.callback)
    end
  end

  function QuickAppBase:getVariable(name)
    __assert_type(name, 'string')
    for _, v in ipairs(self.properties.quickAppVariables or {}) do if v.name == name then return v.value end end
    return ""
  end

  local function copy(l)
    local r = {}; for _, i in ipairs(l) do r[#r + 1] = { name = i.name, value = i.value } end
    return r
  end
  function QuickAppBase:setVariable(name, value)
    __assert_type(name, 'string')
    local vars = copy(self.properties.quickAppVariables or {})
    for _, v in ipairs(vars) do
      if v.name == name then
        v.value = value
        api.post("/plugins/updateProperty", { deviceId = self.id, propertyName = 'quickAppVariables', value = vars })
        self.properties.quickAppVariables = vars
        return
      end
    end
    vars[#vars + 1] = { name = name, value = value }
    api.post("/plugins/updateProperty", { deviceId = self.id, propertyName = 'quickAppVariables', value = vars })
    self.properties.quickAppVariables = vars
  end

  function QuickAppBase:callAction(name, ...)
    if (type(self[name]) == 'function') then return self[name](self, ...)
    else _print(string.format("[WARNING] Class does not have '%s' function defined - action ignored",tostring(name))) end
  end

  function QuickAppBase:isTypeOf(baseType) return getHierarchy():isTypeOf(baseType, self.type) end

  function QuickAppBase:internalStorageSet(key, value, isHidden)
    local data = { name = key, value = value, isHidden = isHidden }
    local _, status = api.post("/plugins/"..self.id.."/variables", data)
    if status == 409 then api.put("/plugins/"..self.id.."/variables/"..key, data) end
  end

  function QuickAppBase:internalStorageGet(key)
    if key ~= nil then
      local response, status = api.get("/plugins/"..self.id.."/variables/"..key)
      return status == 200 and response.value or nil
    else
      local response, status = api.get("/plugins/"..self.id.."/variables")
      if status == 200 then
        local res = {}
        for _, v in pairs(response) do res[v.name] = v.value end
        return res
      end
    end
  end

  function QuickAppBase:internalStorageRemove(key) api.delete("/plugins/"..self.id.."/variables/"..key) end
  function QuickAppBase:internalStorageClear() api.delete("/plugins/"..self.id.."/variables") end

  class 'QuickApp'(QuickAppBase)
  function QuickApp:__init(dev) 
    QuickAppBase.__init(self,dev)
    __TAG = self.name:upper()..self.id
    plugin.quickApp = self
    self.childDevices = {}
    self:setupUICallbacks()
    if self.onInit then
      self:onInit()
    end
    if self._childsInited == nil then self:initChildDevices() end
  end

  function QuickApp:createChildDevice(props, deviceClass)
    __assert_type(props, 'table')
    props.parentId = self.id
    props.initialInterfaces = props.initialInterfaces or {}
    table.insert(props.initialInterfaces, 'quickAppChild')
    local device, res = api.post("/plugins/createChildDevice", props)
    assert(res == 200, "Can't create child device " .. tostring(res) .. " - " .. json.encode(props))
    deviceClass = deviceClass or QuickAppChild
    local child = deviceClass(device)
    child.parent = self
    self.childDevices[device.id] = child
    return child
  end

  function QuickApp:removeChildDevice(id)
    __assert_type(id, 'number')
    if self.childDevices[id] then
      api.delete("/plugins/removeChildDevice/" .. id)
      self.childDevices[id] = nil
    end
  end

  function QuickApp:initChildDevices(map)
    map = map or {}
    local children = api.get("/devices?parentId=" .. self.id) or {}
    local childDevices = self.childDevices
    for _, c in pairs(children) do
      if childDevices[c.id] == nil and map[c.type] then
        childDevices[c.id] = map[c.type](c)
      elseif childDevices[c.id] == nil then
        self:error(string.format(
            "Class for the child device: %s, with type: %s not found. Using base class: QuickAppChild", c.id, c.type))
        childDevices[c.id] = QuickAppChild(c)
      end
      childDevices[c.id].parent = self
    end
    self._childsInited = true
  end

  function onAction(id,event)
    local quickApp = plugin.quickApp
    if DBG.onAction then print("onAction: ", json.encode(event)) end
    if quickApp.actionHandler then return quickApp:actionHandler(event) end
    if event.deviceId == quickApp.id then
      return quickApp:callAction(event.actionName, table.unpack(event.args)) 
    elseif quickApp.childDevices[event.deviceId] then
      return quickApp.childDevices[event.deviceId]:callAction(event.actionName, table.unpack(event.args)) 
    end
    fibaro.warning(__TAG,string.format("Child with id:%s not found",id))
  end

  function onUIEvent(id, event)
    local quickApp = plugin.quickApp
    if DBG.onUIEvent then print("UIEvent: ", json.encode(event)) end
    if quickApp.UIHandler then quickApp:UIHandler(event) return end
    if quickApp.uiCallbacks[event.elementName] and quickApp.uiCallbacks[event.elementName][event.eventType] then 
      quickApp:callAction(quickApp.uiCallbacks[event.elementName][event.eventType], event)
    else
      fibaro.warning(__TAG,string.format("UI callback for element:%s not found.", event.elementName))
    end 
  end
end

-- Parse directives
readDirectives(src)

-- Load modules
for _,m in ipairs(modules) do DEBUGF('info',"Loading library %s",m.name) m.fun() end

local skip = load("return function(f) return function(...) return f(...) end end")()
local luaType = function(obj)
  local t = _type(obj)
  return t == 'table' and rawget(obj,'__USERDATA') and 'userdata' or t
end
type = skip(luaType)
function print(...) fibaro.debug(__TAG,...) end

if flags.sdk then
  for n,f in pairs(api) do local f0=f; api[n] = skip(f0) end
  setTimeout = skip(setTimeout)
  clearTimeout = skip(clearTimeout)
  json.encode = skip(json.encode)
  json.decode = skip(json.decode)
  for n,f in pairs(fibaro) do
    if _type(f) == 'function' then local f0=f fibaro[n]=skip(f0) end
  end
end

-- Load main file
DEBUGF('info',"Loading user file %s",fileName)
local mainFile = loadfile(fileName)
mainFile()

local function init()
-- Start QuickApp if defined
  mobdebug.on()
  if QuickApp.onInit then
    local qvs = {}
    for k,v in pairs(flags.var or {}) do qvs[#qvs+1]={name=k,value=v} end
    local deviceStruct = {  --  create simple deviceStruct..
      id=tonumber(flags.id) or 5000,
      type=flags.type or 'com.fibaro.binarySwitch',
      name=flags.name or 'MyQA',
      properties = { quickAppVariables = qvs },
      interfaces = {"quickApp"},
      created = os.time(),
      modified = os.time(),
    }

    -- Find or create proxy if specified
    if flags.proxy then 
      deviceStruct = TQ.getProxy(flags.proxy,deviceStruct) -- Get deviceStruct from HC3 proxy
      api.post("/plugins/updateProperty",{deviceId= deviceStruct.id,propertyName='quickAppVariables',value=qvs})
      TQ.startServer()
    end

    plugin._dev = deviceStruct
    plugin.mainDeviceId = deviceStruct.id
    TQ.setupInterceptors(plugin.mainDeviceId)
    quickApp = QuickApp(deviceStruct)
  end
end

copas(init)

