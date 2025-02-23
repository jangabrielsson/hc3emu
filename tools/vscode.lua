--#!/usr/bin/env lua

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

local cmd = args[1]
local arg = args[2]

local cmds = {}

function cmds.downloadQA()
  printf("Downloading QA:%s",arg) --id
  --TBD
end

function cmds.uploadQA()
  printf("Downloading QA:%s",arg) -- name
  --TBD
end

function cmds.uploadFile()
  local f = io.open(".project","r")
  if f then 
    local p = f:read("*a")
    f:close()
    p = json.decode(p)
    for qn,fn in pairs(p.files or {}) do
      if arg==fn then 
        local content = readFile(fn)
        local f = {name=qn, isMain=qn=='main', isOpen=false, type='lua', content=content}
        local r,err = api.put("/quickApps/"..p.id.."/files/"..qn,f)
        if not r then 
          local r,err = api.post("/quickApps/"..p.id.."/files",f)
          if err then
            printf("Error  QA:%s, file:%s, QAfile%s",p.id,fn,qn)
          else
            printf("Created QA:%s, file:%s, QAfile%s",p.id,fn,qn)
          end
        else 
          printf("Updated QA:%s, file%s, QAfile:%s ",p.id,fn,qn)
        end
        os.exit()
      end
      print(fn," not found in current project")
    end
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
os.exit()