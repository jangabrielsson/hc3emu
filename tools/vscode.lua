if require and not QuickApp then require("hc3emu") end
--%%color=false
--%%shellscript=true
--%%silent=true
--%%debug=info:false

local function printf(fmt,...) _print(string.format(fmt,...)) end

local function readFile(fn)
  local f = io.open(fn,"r")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local cmds = {}

function cmds.downloadQA()
  printf("Downloading QA: %s",arg) -- id
  local deviceId = tonumber(arg)
  __assert_type(deviceId, "number")
  if arg2=="." or arg2=="" then arg2="./" end
  fibaro.hc3emu.downloadFQA(deviceId,arg2)
end

function cmds.uploadQA()
  printf("Downloading QA: %s",arg) -- name
  printf("Not implemented yet") -- name
end

function cmds.updateFile()
  printf("Updating QA file: %s",arg) -- fname
  local f = io.open(".project","r")
  if f then 
    local p = f:read("*a")
    f:close()
    p = json.decode(p)
    for qn,fn in pairs(p.files or {}) do
      if arg==fn then 
        local content = readFile(fn)
        local f = {name=qn, isMain=qn=='main', isOpen=false, type='lua', content=content}
        local r,err = api.put("/quickApp/"..p.id.."/files/"..qn,f)
        if not r then 
          local r,err = api.post("/quickApp/"..p.id.."/files",f)
          if err then
            printf("Error  QA:%s, file:%s, QAfile%s",p.id,fn,qn)
          else
            printf("Created QA:%s, file:%s, QAfile%s",p.id,fn,qn)
          end
        else 
          printf("Updated QA:%s, file%s, QAfile:%s ",p.id,fn,qn)
        end
        os.exit(-1)
      end
    end
    _print(arg," not found in current project")
  else
    _print("No .project file found")
  end
end

local c = cmds[cmd]
if not c then
  _print("Unknown command:",cmd)
else
  local stat,err = pcall(c)
  if not stat then
    _print("Error:",err)
  end
end
os.exit(-1)