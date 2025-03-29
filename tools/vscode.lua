--_DEVELOP=true
if require and not QuickApp then require("hc3emu") end
--%%color=false
--%%shellscript=true
--%%silent=true
--%%debug=info:false
--%%exit0=true

--[[
downloadQA(id,path)
uploadQA(fname)
updateFile(fname)
--]]

local cmds = {}
local tools = fibaro.hc3emu.tools
local io = fibaro.hc3emu.lua.io
local _print = fibaro.hc3emu.lua.print

local function printf(fmt,...) _print(string.format(fmt,...)) end
local function ERROR(fmt,...) printf("Error: "..fmt,...) os.exit(-1) end
local function SUCCESS() printf("Success") end

_print("HC3 Tool")

local function readFile(fn)
  local f = io.open(fn,"r")
  assert(f,"File not found: "..tostring(fn))
  local s = f:read("*a")
  f:close()
  return s
end

function cmds.downloadQA(id,path) -- HC3 QA deviceId, dir path
  printf("Downloading QA: %s",tostring(id)) -- id
  local deviceId = tonumber(id)
  __assert_type(deviceId, "number")
  if path=="." or path=="" then path="./" end
  tools.downloadFQA(deviceId,path)
  SUCCESS()
end

--args = {"uploadQA",".","examples/QA_test.lua"}
function cmds.uploadQA(fname,cf) -- current buffer file
  if fname == '.' then fname = cf end
  fname = tostring(fname)
  printf("Uploading QA: %s",fname) -- name
  local qainfo = tools.loadQA(fname,nil,"noRun")
  if not qainfo then ERROR("loading QA") end
  if not(
    qainfo.src:match("function%s+QuickApp:onInit") or
    qainfo.src:match("if require and not QuickApp then require(\"hc3emu\"")
  ) then 
    ERROR("file %s does not seem to be a QuickApp",fname)
  end
  local dev,code = tools.uploadQA(qainfo.device.id)
  if dev then
    printf("Uploaded QA: %s, deviceId: %s",fname,dev.id)
    SUCCESS()
    os.exit(0)
  else
    ERROR("Uploading QA: %s, error: %s",fname,code)
  end
end

function cmds.updateFile(fname) -- current buffer file, needs .project file
  printf("Updating QA file: %s",tostring(fname)) -- fname
  local f = io.open(".project","r")
  assert(f,"No .project file found")
  local p = f:read("*a")
  f:close()
  p = json.decode(p)
  for qn,fn in pairs(p.files or {}) do
    if fname==fn then 
      local content = readFile(fn)
      local f = {name=qn, isMain=qn=='main', isOpen=false, type='lua', content=content}
      local r,err = api.put("/quickApp/"..p.id.."/files/"..qn,f)
      if not r then 
        local r,err = api.post("/quickApp/"..p.id.."/files",f)
        if err then
          ERROR("creating QA:%s, file:%s, QAfile%s",p.id,fn,qn)
        else
          printf("Created QA:%s, file:%s, QAfile%s",p.id,fn,qn)
        end
      else 
        printf("Updated QA:%s, file%s, QAfile:%s ",p.id,fn,qn)
      end
      SUCCESS()
      os.exit(0)
    end
  end
  ERROR("%s not found in current project",fname)
end

--args = ("downloadQA 3568 test"):split(" ")
local cmd = args[1]
local c = cmds[cmd]
if not c then ERROR("Unknown command: %s",tostring(cmd)) end

local stat,err = pcall(c,table.unpack(args,2))
if not stat then
  ERROR("%s",err)
  os.exit(-1)
end

os.exit(0)