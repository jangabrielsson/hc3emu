local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local json = require("hc3emu.json")

--[[
<name>.lua
<name>_<module1>.lua
<name>_<module2>.lua
--]]

local win = (os.getenv('WINDIR') or (os.getenv('OS') or ''):match('[Ww]indows'))
and not (os.getenv('OSTYPE') or ''):match('cygwin') -- exclude cygwin
local sep = win and '\\' or '/'

local CRC16Lookup = {
  0x0000,0x1021,0x2042,0x3063,0x4084,0x50a5,0x60c6,0x70e7,0x8108,0x9129,0xa14a,0xb16b,0xc18c,0xd1ad,0xe1ce,0xf1ef,
  0x1231,0x0210,0x3273,0x2252,0x52b5,0x4294,0x72f7,0x62d6,0x9339,0x8318,0xb37b,0xa35a,0xd3bd,0xc39c,0xf3ff,0xe3de,
  0x2462,0x3443,0x0420,0x1401,0x64e6,0x74c7,0x44a4,0x5485,0xa56a,0xb54b,0x8528,0x9509,0xe5ee,0xf5cf,0xc5ac,0xd58d,
  0x3653,0x2672,0x1611,0x0630,0x76d7,0x66f6,0x5695,0x46b4,0xb75b,0xa77a,0x9719,0x8738,0xf7df,0xe7fe,0xd79d,0xc7bc,
  0x48c4,0x58e5,0x6886,0x78a7,0x0840,0x1861,0x2802,0x3823,0xc9cc,0xd9ed,0xe98e,0xf9af,0x8948,0x9969,0xa90a,0xb92b,
  0x5af5,0x4ad4,0x7ab7,0x6a96,0x1a71,0x0a50,0x3a33,0x2a12,0xdbfd,0xcbdc,0xfbbf,0xeb9e,0x9b79,0x8b58,0xbb3b,0xab1a,
  0x6ca6,0x7c87,0x4ce4,0x5cc5,0x2c22,0x3c03,0x0c60,0x1c41,0xedae,0xfd8f,0xcdec,0xddcd,0xad2a,0xbd0b,0x8d68,0x9d49,
  0x7e97,0x6eb6,0x5ed5,0x4ef4,0x3e13,0x2e32,0x1e51,0x0e70,0xff9f,0xefbe,0xdfdd,0xcffc,0xbf1b,0xaf3a,0x9f59,0x8f78,
  0x9188,0x81a9,0xb1ca,0xa1eb,0xd10c,0xc12d,0xf14e,0xe16f,0x1080,0x00a1,0x30c2,0x20e3,0x5004,0x4025,0x7046,0x6067,
  0x83b9,0x9398,0xa3fb,0xb3da,0xc33d,0xd31c,0xe37f,0xf35e,0x02b1,0x1290,0x22f3,0x32d2,0x4235,0x5214,0x6277,0x7256,
  0xb5ea,0xa5cb,0x95a8,0x8589,0xf56e,0xe54f,0xd52c,0xc50d,0x34e2,0x24c3,0x14a0,0x0481,0x7466,0x6447,0x5424,0x4405,
  0xa7db,0xb7fa,0x8799,0x97b8,0xe75f,0xf77e,0xc71d,0xd73c,0x26d3,0x36f2,0x0691,0x16b0,0x6657,0x7676,0x4615,0x5634,
  0xd94c,0xc96d,0xf90e,0xe92f,0x99c8,0x89e9,0xb98a,0xa9ab,0x5844,0x4865,0x7806,0x6827,0x18c0,0x08e1,0x3882,0x28a3,
  0xcb7d,0xdb5c,0xeb3f,0xfb1e,0x8bf9,0x9bd8,0xabbb,0xbb9a,0x4a75,0x5a54,0x6a37,0x7a16,0x0af1,0x1ad0,0x2ab3,0x3a92,
  0xfd2e,0xed0f,0xdd6c,0xcd4d,0xbdaa,0xad8b,0x9de8,0x8dc9,0x7c26,0x6c07,0x5c64,0x4c45,0x3ca2,0x2c83,0x1ce0,0x0cc1,
  0xef1f,0xff3e,0xcf5d,0xdf7c,0xaf9b,0xbfba,0x8fd9,0x9ff8,0x6e17,0x7e36,0x4e55,0x5e74,0x2e93,0x3eb2,0x0ed1,0x1ef0
}

local function crc16(bytes)
  local crc = 0
  for i=1,#bytes do
    local b = string.byte(bytes,i,i)
    crc = ((crc<<8) & 0xffff) ~ CRC16Lookup[(((crc>>8)~b) & 0xff) + 1]
  end
  return tonumber(crc)
end

local function printBuff()
  local self,buff = {},{}
  function self:printf(...) buff[#buff+1] = string.format(...) end
  function self:print(str) buff[#buff+1] = str end
  function self:tostring() return table.concat(buff,"\n") end
  return self
end

local function remove(t,e)
  for i,v in ipairs(t) do if v == e then table.remove(t,i) break end end
  return t
end

local function saveFile(path,content)
  local f = io.open(path,"w")
  if f then f:write(content) f:close()
  else error("Failed to save file:"..path) end
end

local function readFile(path)
  local f,c = io.open(path,"r")
  if f then c=f:read("*a") f:close() return c
  else error("Failed to read file:"..path) end
end

local fileNum = 0
local function createTempName(suffix)
  fileNum = fileNum + 1
  return os.date("hc3emu%M%M")..fileNum..suffix
end

local function findFirstLine(src)
  local n,first,init = 0,nil,nil
  for line in string.gmatch(src,"([^\r\n]*\r?\n?)") do
    n = n+1
    line = line:match("^%s*(.*)")
    if not (line=="" or line:match("^[%-]+")) then 
      if not first then first = n end
    end
    if line:match("%s*QuickApp%s*:%s*onInit%s*%(") then
      if not init then init = n end
    end
  end
  return first or 1,init
end

local function getFQA(id) -- Creates FQA structure from installed QA
  local qa = E:getQA(id)
  assert(qa,"QuickApp not found, ID"..tostring(id))
  return qa:createFQA()
end

--@F 
local function loadQA(path,optionalDirectives,noRun)   -- Load QA from file and maybe run it
  local f = io.open(path)
  if f then
    local src = f:read("*all")
    f:close()
    local info = { directives = nil, extraDirectives = optionalDirectives, src = src, fname = path, env = { require=true }, files = {} }
    if noRun then 
      return E.qa.QA(info,true)
    else
      return E.qa.QA(info):run()
    end
  else
    E:ERRORF("Could not read file %s",path)
  end
end

--@F 
local function loadScene(path,optionalDirectives)   -- Load Scene from file and maybe run it
  local f = io.open(path)
  if f then
    local src = f:read("*all")
    f:close()
    local info = { directives = nil, extraDirectives = optionalDirectives, src = src, fname = path, env = { require=false }, files = {} }
    return E.scene.Scene(info):run()
  else
    E:ERRORF("Could not read file %s",path)
  end
end

--@F 
local function loadQAString(src,optionalDirectives) -- Load QA from string and run it
  local path = E.tempDir..createTempName(".lua")
  local f = io.open(path,"w")
  assert(f,"Can't open file "..path)
  f:write(src)
  f:close()
  local info = { directives = nil, extraDirectives = optionalDirectives, src = src, fname = path, env = { require=true }, files = {} }
  ---@diagnostic disable-next-line: need-check-nil
  return E.qa.QA(info):run()
end

--@F 
local function saveQA(id,fileName) -- Save installed QA to disk as .fqa  //Move to QA class
  local info = E:getQA(id)           
  fileName = fileName or info.directives.save
  assert(fileName,"No save filename found")
  local fqa = getFQA(info.id)
  local vars = table.copy(fqa.initialProperties.quickAppVariables)
  vars = json.util.InitArray(vars)
  fqa.initialProperties.quickAppVariables = vars
  local conceal = info.directives.conceal or {}
  for _,v in ipairs(vars) do
    if conceal[v.name] then 
      v.value = conceal[v.name]
    end
  end
  local f = io.open(fileName,"w")
  assert(f,"Can't open file "..fileName)
  f:write(json.encode(fqa))
  f:close()
  E:DEBUG("Saved QuickApp to %s",fileName)
end

--@F
local function uploadQA(id)
  assert(E:getQA(id),"QuickApp not installed, ID"..tostring(id))
  local fqa = getFQA(id)
  local res,code = E.api.hc3.post("/quickApp/",fqa)
  if not code or code > 201 then
    E:ERRORF("Failed to upload QuickApp: %s", res)
  else
    E:DEBUG("Successfully uploaded QuickApp with ID: %d -> %s", id,res.id)
  end
  return res,code
end

--@F
local function updateQA(emuId,hc3Id,components)
  components = components or {name=true,interfaces=true,quickVars=true,UI=true,files=true}
  assert(type(emuId) == "number", "emuId must be a number")
  assert(type(hc3Id) == "number", "hc3Id must be a number")
  local hc3qa = E.api.hc3.get("/devices/"..hc3Id)
  assert(hc3qa,"Failed to get HC3 QuickApp, ID",tostring(hc3Id))
  local emuqa = getFQA(emuId)
  assert(emuqa,"Failed to get emulated QuickApp, ID",tostring(emuId))
  assert(hc3qa.type == emuqa.type,"QuickApp types no match")
  -- Update name,interfaces,quickVars,UI,files
  if components.name then
  end
  if components.interfaces then
  end
  if components.quickVars then
  end
  if components.UI then
  end
  if components.files then
    -- Update files
    local newFiles = {}
    local existingFiles = {}
    local deletedFiles = {}
    local hfile,hmap = hc3qa.files,{}
    local efile,emap = emuqa.files,{}
    for _,f in ipairs(hfile) do hmap[f.name] = f end
    for _,f in ipairs(efile) do emap[f.name] = f end
    for _,f in ipairs(efile) do
      if not hmap[f.name] then newFiles[#newFiles+1] = f
      else existingFiles[#existingFiles+1] = f end
    end
    for _,f in ipairs(hfile) do 
      if not emap[f.name] then deletedFiles[#deletedFiles+1] = f end
    end
    
    for _,f in ipairs(newFiles) do
      local res,code = E.api.hc3.post("/quickApp/"..hc3Id.."/files",f)
      if code > 201 then E:ERRORF("Failed to create file %s",f.name) end
    end
    
    local res,code = E.api.hc3.put("/quickApp/"..hc3Id.."/files",existingFiles)
    if code > 202 then 
      E:ERRORF("Failed to update files for QuickApp %d",hc3Id)
    end
    
    for _,f in ipairs(deletedFiles) do
      local res,code = E.api.hc3.delete("/quickApp/"..hc3Id.."/files/"..f.name)
      if code > 202 then E:ERRORF("Failed to delete file %s",f.name) end
    end
  end
end

--@F 
local function installFQA(id,optionalDirectives)          -- Installs QA from HC3 and run it.
  assert(type(id) == "number", "id must be a number")
  local path = E.tempDir
  local path = exports.downloadFQA(id,path)
  return exports.loadQA(path,optionalDirectives)
end

local function unpackFQAAux(id,fqa,path) -- Unpack fqa and save it to disk
  assert(type(path) == "string", "path must be a string")
  local fname = ""
  fqa = fqa or E.api.hc3.get("/quickApp/export/"..id) 
  assert(fqa, "Failed to download fqa")
  local name = fqa.name
  local typ = fqa.type
  local files = fqa.files
  local props = fqa.initialProperties or {}
  local ifs = fqa.initialInterfaces or {}
  ifs = remove(ifs,"quickApp")
  if next(ifs) == nil then ifs = nil end
  
  if path:sub(-4):lower() == ".lua" then
    fname = path:match("([^/\\]+)%.[Ll][uU][Aa]$")
    path = path:sub(1,-(#fname+4+1))
  else
    if path:sub(-1) ~= sep then path = path..sep end
    fname = name:gsub("[%s%-%.%%!%?%(%)]","_")
    if id then if fname:match("_$") then fname = fname..id else fname = fname.."_"..id end end
  end
  
  local mainIndex
  for i,f in ipairs(files) do if files[i].isMain then mainIndex = i break end end
  assert(mainIndex,"No main file found")
  local mainContent = files[mainIndex].content
  table.remove(files,mainIndex)
  
  mainContent = mainContent:gsub("(%-%-%%%%.-\n)","") -- Remove old directives
  
  local pr = printBuff()
  pr:printf('if require and not QuickApp then require("hc3emu") end')
  pr:printf('--%%%%name=%s',name)
  pr:printf('--%%%%type=%s',typ)
  if ifs then pr:printf('--%%%%interfaces=%s',json.encode(ifs):gsub('.',{['[']='{', [']']='}'})) end
  
  local qvars = props.quickAppVariables or {}
  for _,v in ipairs(qvars) do
    pr:printf('--%%%%var=%s:%s',v.name,type(v.value)=='string' and '"'..v.value..'"' or v.value)
  end
  
  if props.quickAppUuid then pr:printf('--%%%%uid=%s',props.quickAppUuid) end
  if props.model then pr:printf('--%%%%model=%s',props.model) end
  if props.manufacturer then pr:printf('--%%%%manufacturer=%s',props.manufacturer) end
  if props.deviceRole then pr:printf('--%%%%role=%s',props.deviceRole) end
  if props.userDescription then pr:printf('--%%%%description=%s',props.userDescription) end

  for _,f in ipairs(files) do
    local fn = path..fname.."_"..f.name..".lua"
    saveFile(fn,f.content)
    pr:printf("--%%%%file=%s:%s",fn,f.name)
  end
  
  local UI = ""
  if id then
    E.ui.logUI(id,function(str) UI = str end)
  else
    local UIstruct = E.ui.viewLayout2UI(props.viewLayout,props.uiCallbacks or {})
    E.ui.dumpUI(UIstruct,function(str) UI = str end)
  end
  UI = UI:match(".-\n(.*)") or ""
  pr:print(UI)
  
  pr:print("")
  pr:print(mainContent)
  local mainFilePath = path..fname..".lua"
  saveFile(mainFilePath,pr:tostring())
  return mainFilePath
end

--@F 
local function downloadFQA(id,path) -- Download QA from HC3,unpack and save it to disk
  assert(type(id) == "number", "id must be a number")
  assert(type(path) == "string", "path must be a string")
  return unpackFQAAux(id,nil,path)
end

--@F 
local function loadFQA(path,optionalDirectives)        -- Load FQA from file and stuct and run it (saves as temp files)
  local fqaPath = exports.unpackFQA(path,E.tempDir)
  return exports.loadQA(fqaPath,optionalDirectives)
end

--@F 
local function installFQAstruct(fqa,optionalDirectives)        -- Load FQA from file and run it (saves as temp files)
local path = E.tempDir..createTempName(".fqa")
  local f = io.open(path,"w")
  assert(f,"Can't open file "..path)
  f:write(json.encode(fqa))
  f:close()  
  return exports.loadFQA(path,optionalDirectives)
end

--@F 
local function unpackFQA(fqaPath,savePath)        -- Unpack FQA on disk  to lua files
  assert(type(fqaPath) == "string", "path must be a string")
  local f = io.open(fqaPath)
  assert(f,"Can't open file "..fqaPath)
  local src = f:read("*all")
  f:close()
  local fqa = json.decode(src)
  return unpackFQAAux(nil,fqa,savePath)
end

exports.getFQA = getFQA
exports.createTempName = createTempName
exports.crc16 = crc16
exports.findFirstLine = findFirstLine
exports.loadQA = loadQA
exports.loadScene = loadScene
exports.loadQAString = loadQAString
exports.saveQA = saveQA
exports.uploadQA = uploadQA
exports.updateQA = updateQA
exports.installFQA = installFQA
exports.unpackFQA = unpackFQA
exports.downloadFQA = downloadFQA
exports.loadFQA = loadFQA
exports.installFQAstruct = installFQAstruct

return exports