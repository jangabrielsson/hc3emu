local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local json = require("hc3emu.json")
local fmt = string.format

local function writeFile(filename, content)
  local file = io.open(filename, "w")
  if file then
    file:write(content)
    file:close()
    return true
  else
    E:ERRORF("Error writing to file %s", filename)
    return false
  end
end

local PROJFILE = E.cfgFileName
local GLOBFILE = E.homeDir..E.fileSeparator..E.homeCfgFileName

local function readFile(filename,decode,silent)
  local file = io.open(filename, "r")
  if file then
    local content = file:read("*a")
    file:close()
    if decode then
      local stat, data = pcall(json.decode, content)
      if not stat then
        if not silent then E:ERRORF("Error decoding JSON from file %s: %s", filename, data) end
        return nil
      end
      return data
    end
    return content
  else
    if not silent then E:ERRORF("Error reading file %s", filename) end
    return nil
  end
end

local function loadResource(file,decode)
  local datafile = require("datafile")
  local f,p = datafile.open(file)
  assert(f, "Failed to open file: " .. file)
  local data = f:read("*a")
  f:close()
  if decode then
    local stat, data = pcall(json.decode, data)
    if not stat then
      E:ERRORF("Error decoding JSON from file %s: %s", file, data)
      return nil
    end
    return data,p
  end
  return data,p
end

local function settings() --const EMU_API = "127.0.0.1:8888";
  local page,p = loadResource("rsrcs/setup.html",false)
  assert(page and p,"Failed to load setup.html")
  local function patchVar(var,value)
    page = page:gsub(var.." = \"(.-)\";",function(ip) 
      return fmt(var.." = \"%s\";",value)
    end)
  end
  p = p:sub(1,-12)
  p = p:gsub("\\","/")
  patchVar("EMU_API",fmt("http://%s:%s",E.emuIP,E.emuPort+1))
  patchVar("USER_HOME",E.homeDir:gsub("\\","/"))
  patchVar("RSRC_DIR",p)
  writeFile("setup.html", page)
  E:DEBUG("setup.html installed")
end

local function vscode()
  local homedir = E.homeDir
  local page = loadResource("rsrcs/vscode.lua")
  writeFile(homedir..E.fileSeparator..".vscode.lua", page)
  E:DEBUG(".vscode.lua installed")
end

local function css()
  local id,qa = next(E.QA_DIR)
  assert(qa,"No QA installed")
  local dir = qa.flags.html
  local page = loadResource("rsrcs/style.css")
  writeFile(dir.."style.css", page)
  page = loadResource("rsrcs/script.js")
  writeFile(dir.."script.js", page)
  E:DEBUG("style.css and script.js installed")
end

local function createconfig(file,templ)
  local cfg = readFile(file,true,true) or {}
  local cfgTemp = loadResource(templ,true)
  local index = {}
  for _,e in ipairs(cfg) do index[e.name] = e end
  for i,e in ipairs(cfgTemp) do
    if index[e.name]==nil then -- missing add
      table.insert(cfg,i,e)
    end
  end
  if writeFile(file, json.encodeFormated(cfg)) then
    E:DEBUG("%s installed",file)
  end
  return cfg
end

local function createProj()
  return createconfig(PROJFILE,"rsrcs/settings.json")
end

local function createGlobal()
  return createconfig(GLOBFILE,"rsrcs/settings.json")
end

local function saveSettings(typ,jsondata)
  local stat,data = pcall(json.decode,jsondata)
  if not stat then
    E:ERRORF("Failed to decode json data: %s",data)
    return
  end
  local file = typ == 'global' and GLOBFILE or PROJFILE

  local cfg = readFile(file,true,true) or {}
  if next(cfg) == nil then
    cfg = createconfig(file,"rsrcs/settings.json")
    assert(cfg,"Failed to create config")
  end
  local index = {}
  for _,e in ipairs(cfg) do index[e.name] = e end
  for i,e in ipairs(data) do
    if index[e.name]==nil then -- missing add
      table.insert(cfg,i,e)
    elseif e.value and type(e.value)=='string' and e.value:sub(1,1) ~= "<" then
      index[e.name].value = e.value
    end
  end
  writeFile(file, json.encodeFormated(cfg))
  E:DEBUG("%s settings saved",typ)
end

local function getSettings()
  local homecfg = readFile(GLOBFILE,true,true) or {}
  local projcfg = readFile(PROJFILE,true,true) or {}
  local index = {}
  for _,e in ipairs(projcfg) do index[e.name] = e end
  for i,e in ipairs(homecfg) do
    if index[e.name]==nil then -- missing add
      table.insert(projcfg,i,e)
    elseif e.value and type(e.value)=='string' and e.value:sub(1,1) ~= "<" then
      index[e.name].value = e.value
    elseif e.value and e.value ~= json.null then
      index[e.name].value = e.value
    end
  end
  local cfg = {}
  local function isTempl(v) return type(v)=='string' and v:sub(1,1) == "<" end
  local function toBool(b) 
    if b =='true' then return true elseif b == 'false' then return false else return b end
  end
  local function trim(s)
    if type(s)~='string' then return s end
    return s:match("^%s*(.-)%s*$")
  end
  for _,e in ipairs(projcfg) do
    local value = trim(e.value)
    if value then
      if e.value == json.null then
      elseif e.type == 'string' then
        if not isTempl(value) then cfg[e.name] = value end
      elseif e.type == 'boolean' then
        if not isTempl(value) then cfg[e.name] = toBool(value) end
      elseif e.type == 'number' then
        if not isTempl(value) then cfg[e.name] = tonumber(value) end
      elseif e.type == 'array' then
        if type(value) ~= 'table' then return end
        local arr = {}
        for _,v in ipairs(value) do
          if not isTempl(v) then arr[#arr+1]= v end
        end
        cfg[e.name] = arr
      end
    end
  end
  return cfg
end

exports = {}
exports.settings = settings
exports.vscode = vscode
exports.css = css
exports.createProj = createProj
exports.createGlobal = createGlobal
exports.getSettings = getSettings
exports.saveSettings = saveSettings

return exports