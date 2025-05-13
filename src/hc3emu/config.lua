local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local json = require("hc3emu.json")
local lfs = require("lfs")
local fmt = string.format

local PROJFILE = E.cfgFileName
local GLOBFILE = E.homeDir..E.fileSeparator..E.homeCfgFileName
local EMU_DIR = "emu"
local EMUSUB_DIR = "emu/pages"

local function findFile(path,fn,n)
  n = n or 0
  if n > 4 then return nil end
  local dirs = {}
  for file in lfs.dir(path) do
    if file ~= "." and file ~= ".." then
      local f = path..'/'..file
      if fn == file then return f end
      local attr = lfs.attributes (f)
      assert(type(attr) == "table")
      if attr.mode == "directory" then
        dirs[#dirs+1] = f
      end
    end
  end
  for i,dir in ipairs(dirs) do
    local f = findFile(dir,fn,n+1)
    if f then return f end
  end
  return nil
end

-- Try to locate the user's rsrcrs directory in the installed rock
local function setupRsrscsDir()
  local file = "stdStructs.json"
  local path = "rsrcs/"..file
  local len = -(#file+2)
  if type(_DEVELOP) == 'string' then
    local lfs = require("lfs") 
    path = _DEVELOP.."/rsrcs"
    local currentDir = lfs.currentdir()
    local prefs = _DEVELOP:match("([/\\%.]+)")
    prefs:gsub("(%.%.)",function() 
      path = path:match("^.-[/\\](.*)")
      currentDir = currentDir:match("(.-)[/\\][%w+%-_ ]+$") 
    end)
    path = currentDir.."/"..path
    local attr = lfs.attributes(path)
    if attr and attr.mode == "directory" then return path end
    assert(attr, "Failed to get _DEVELOP path tp /rsrsc "..path)
  end
  local datafile = require("datafile")
  local f,p = datafile.open(path)
  if (not _DEVELOP) and p:match("^.[/\\]rsrcs") then f:close(); f = nil end -- found wrong (local) directory
  if f then f:close() return p:sub(1,len) end
  p = package.searchpath("hc3emu",package.path)
  assert(p,"Failed to find "..path)

  -- Try to locate scoop installed rock
  -- C:\Users\jgab\scoop\apps\luarocks\3.11.1\rocks\lib\luarocks\rocks-5.4\hc3emu\1.0.70-1\rsrcs
  local dir = p:match(".:\\Users\\%w+\\scoop\\apps\\luarocks\\")
  if dir then
    dir = dir.."3.11.1\\rocks\\lib\\luarocks\\rocks-5.4\\hc3emu\\"
    local p = findFile(dir,file)
    if p then return p:sub(1,len) end
  end

  local p = os.getenv("EMU_RSRCS")
  if p then 
    local f = findFile(p,file)
    if f then return f:sub(1,len) end
  end
end

local function rsrcPath(file,open) -- Like datafile's open...
  assert(E.rsrcsDir,"rsrcsDir not set")
  local p = findFile(E.rsrcsDir,file)
  if p then
    if open then return io.open(p,open == true and "r" or open),p end
    return p 
  end
end

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
  local f,p = rsrcPath(file,true)
  if not f then
    E:ERRORF("Failed to load resource %s", E.rsrcsDir..E.fileSeparator..file)
  end
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

local function vscode()
  local homedir = E.homeDir
  local page = loadResource("vscode.lua")
  writeFile(homedir..E.fileSeparator..".vscode.lua", page)
  E:DEBUG(".vscode.lua installed")
end

local function setupDirectory(flag)
  local function transVars(page)
    local function patchVar(var,value)
      page = page:gsub(var.." = \"(.-)\";",function(ip) 
        return fmt(var.." = \"%s\";",value)
      end)
    end
    patchVar("EMU_API",fmt("http://%s:%s",E.emuIP,E.emuPort+1))
    patchVar("USER_HOME",E.homeDir:gsub("\\","/"))
    patchVar("EMUSUB_DIR",EMUSUB_DIR)
    return page
  end

  local files = {
    ['style.css']={dest=EMUSUB_DIR.."/style.css"},
    ['script.js']={dest=EMUSUB_DIR.."/script.js"},
    ['quickapps.html']={dest=EMUSUB_DIR.."/quickapps.html"},
    ['devices.html']={dest=EMUSUB_DIR.."/devices.html",trans=transVars},
    ['editSettings.html']={dest=EMUSUB_DIR.."/editSettings.html"},
    ['emu.html']={dest=EMU_DIR.."/_emu.html"},
    ['setup.html']={dest=EMU_DIR.."/_setup.html",trans=transVars},
  }

  local a,b = lfs.mkdir(EMU_DIR)
  local a,b = lfs.mkdir(EMUSUB_DIR)
  assert((b==nil or b=="File exists"),"Failed to create directory "..EMU_DIR)
  if flag ~= "install" and b == "File exists" then return end

  for source,dest in pairs(files) do
    local page = loadResource(source)
    if dest.trans then page = dest.trans(page) end
    writeFile(dest.dest, page)
    E:DEBUG("%s installed",dest.dest)
  end
end

local function clearDirectory()
  for file in lfs.dir(EMU_DIR) do
    if file ~= "." and file ~= ".." and file:sub(1,1) ~= "_" then
      if file:match("%.html") then
        os.remove(EMU_DIR.."/"..file)
      end
    end
  end
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
  return createconfig(PROJFILE,"settings.json")
end

local function createGlobal()
  return createconfig(GLOBFILE,"settings.json")
end

local function installation(creds,directives)
  setupDirectory("install")
  createGlobal()
  createProj()
  local homecfg = readFile(GLOBFILE,true,true) or {}
  local function findOption(name)
    for _,e in ipairs(homecfg) do
      if e.name == name then return e or {} end
    end
  end
  local user = findOption("user")
  user.value = creds.user
  directives.user = user.value
  local password = findOption("password")
  password.value = creds.pass
  directives.password = password.value
  local IP = findOption("IP")
  local url = creds.url
  directives.IP = url
  if not url:match("https?://") then
    url = "http://"..url
  end
  IP.value = url
  exports.saveSettings("global",json.encode(homecfg))
  E:DEBUG("Set user,password,url in %s",GLOBFILE)
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
    cfg = createconfig(file,"settings.json")
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
  if next(homecfg) == nil and next(projcfg) == nil then
    homecfg = createGlobal()
    homecfg = readFile(GLOBFILE,true,true) or {}
    E:DEBUG("Created config file .hc3emu.json in %s",E.homeDir)
  end
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
exports.EMU_DIR = EMU_DIR
exports.EMUSUB_DIR = EMUSUB_DIR
exports.vscode = vscode
exports.setupDirectory = setupDirectory
exports.clearDirectory = clearDirectory
exports.createProj = createProj
exports.createGlobal = createGlobal
exports.getSettings = getSettings
exports.saveSettings = saveSettings
exports.setupRsrscsDir = setupRsrscsDir
exports.rsrcPath = rsrcPath
exports.loadResource = loadResource
exports.installation = installation

return exports