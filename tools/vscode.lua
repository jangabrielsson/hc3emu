#!/usr/bin/env lua

if require and not QuickApp then require("hc3emu") end
--%%color=false
--%%shellscript=true
--%%silent=true
--%%debug=info:false

local cmd = args[1]
local arg = args[2]

print(cmd,arg)
local function main()
  if cmd == "updateFile" then
    local f = io.open(".project","r")
    if f then 
      local p = f:read("*a")
      f:close()
      p = json.decode(p)
      for qn,fn in pairs(p.files or {}) do
        if arg==fn then 
          _print("Updating file",p.id,fn,qn)
          os.exit()
        end
        print(fn," not found in current project")
      end
    else
      _print("No .project file found")
    end
  end
end

local stat,err = pcall(main)
if not stat then
  _print("Error:",err)
end
os.exit()