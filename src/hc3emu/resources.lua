Emulator = Emulator
local E = Emulator.emulator
local fmt = string.format
local copas = require("copas")
local json = require("hc3emu.json")
local lclass = require("hc3emu.class")

local ResourceDB = lclass('ResourceDB')
function ResourceDB:__init()
  self.db = {
    devices = { items = {}, inited = false, index='id', path="/devices" },
    globalVariables = { items = {}, inited = false, index='name', path="/globalVariables" },
    rooms = { items = {}, inited = false, index='id', idc=6000, path="/rooms" },
    sections = { items = {}, inited = false, index='id', idc=7000, path="/sections" },
    customEvents = { items = {}, inited = false, index='name', path="/customEvents" },
    scenes = { items = {}, inited = false, index='id', path="/scenes" },
    ['panels/location'] = { items = {}, inited = false, index='id', idc=200, path="/panels/location" },
    ['settings/location'] = { items = {}, inited = false, index=nil, path="/settings/location" },
    ['settings/info'] = { items = {}, inited = false, index=nil, path="/settings/info" },
    users = { items = {}, inited = false, index='id', idc=4000, path="/users" },
    home = { items = {}, inited = false, index=nil, path="/home" },
    weather = { items = {}, inited = false, index=nil, path="/weather" },
    internalStorage = { items = {}, inited = false, index=nil, path="/qa/variables" },
  }
end

local function toList(t) local r = {} for _,v in pairs(t) do r[#r+1] = v end return r end

local function merge(t1,t2)
  for k,v in pairs(t2) do
    if type(v) == 'table' then
      if not t1[k] then t1[k] = {} end
      merge(t1[k],v)
    else
      t1[k] = v
    end
  end
end

local function OST(_) return os.time() end
local defaults = {
  globalVariables = { enumValues = {}, isEnum = false, readOnly=false, modified=OST(), created=OST() },
}
local function addDefaults(typ,data)
  for k,v in pairs(defaults[typ] or {}) do
    if data[k] == nil then data[k] = v end
  end
end

function ResourceDB:initRsrc(typ)
  local r = self.db[typ]
  r.inited = true
  if self.offline then return end
  local res = self.hc3.get(r.path)
  local idx,items = r.index,r.items
  if idx==nil then items = res or {}
  else 
    for _,v in ipairs(res or {}) do items[v[idx]] = v end
  end
  r.items = items
end

function ResourceDB:get(typ,id)
  local res = self.db[typ]
  if not res then return nil,501 end
  if res and not res.inited then self:initRsrc(typ) end
  if id == nil then 
    if res.index == nil then return res.items,200
    else return toList(res.items),200 end
  elseif not res.items[id] then return nil, 404 
  else return res.items[id],200 end
end

function ResourceDB:create(typ,data)
  local res = self.db[typ]
  if not res then return nil,501 end
  if res and not res.inited then self:initRsrc(typ) end
  local idx = res.index -- Is this an indexed resource?
  local id = data[idx or ""] -- Then this is it's index..
  if idx and id==nil then -- Creating an indexed resource without id, invent one...
    id = res.idc
    res.idc = res.idc + 1
    data[idx] = id
  end
  if not id then res.items = data
  else 
    if res.items[id] then return nil,404
    else addDefaults(typ, data) res.items[id] = data end
  end
  return data,201
end

function ResourceDB:delete(typ,id)
  local res = self.db[typ]
  if not res then return nil,501 end
  if res and not res.inited then self:initRsrc(typ) end
  if res.items[id] == nil then return nil,404
  else res.items[id] = nil end
  return nil,200
end

function ResourceDB:modify(typ,data)
  local res = self.db[typ]
  if not res then return nil,501 end
  if res and not res.inited then self:initRsrc(typ) end
  local idx = res.index
  local id,items = data[idx or ""],res.items
  if id then 
    if not items[id] then return nil,404
    else items = items[id] end
  end
  merge(items,data)
  return nil,200
end

function ResourceDB:modifyProp(typ,data)
  local res = self.db['devices']
  if not res then return nil,501 end
  if res and not res.inited then self:initRsrc('devices') end
  local dev = res.items[data.id]
  if not dev then return nil,501 end
  dev.properties[data.property] = data.newValue
  return nil,200
end

return ResourceDB