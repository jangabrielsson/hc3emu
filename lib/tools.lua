TQ = TQ
local api = TQ.api 
local json = TQ.json

--[[
<name>.lua
<name>_<module1>.lua
<name>_<module2>.lua
--]]

local win = (os.getenv('WINDIR') or (os.getenv('OS') or ''):match('[Ww]indows'))
  and not (os.getenv('OSTYPE') or ''):match('cygwin') -- exclude cygwin
local sep = win and '\\' or '/'

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

function TQ.downloadFQA(id,path)
  assert(type(id) == "number", "id must be a number")
  assert(type(path) == "string", "path must be a string")
  local fname = ""
  local fqa = api.get("/quickApp/export/"..id)
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
    if fname:match("_$") then fname = fname..id else fname = fname.."_"..id end
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

  for _,f in ipairs(files) do
    local fn = path..fname.."_"..f.name..".lua"
    saveFile(fn,f.content)
    pr:printf("--%%%%file=%s:%s",fn,f.name)
  end

  local UI = "" 
  TQ.logUI(id,function(str) UI = str end)
  UI = UI:match(".-\n(.*)") or ""
  pr:print(UI)

  pr:print("")
  pr:print(mainContent)
  saveFile(path..fname..".lua",pr:tostring())
end

