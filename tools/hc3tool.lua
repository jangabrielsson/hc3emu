--#!/usr/bin/env lua

if require and not QuickApp then require("hc3emu") end
--%%color=false
--%%shell script=true
--%%silent=true
--%%debug=info:false

local function printf(...) _print(string.format(...)) end

local cmds = {}
function cmds.help()
  printf("Usage: hc3tool <command> [args]")
  printf("Commands:")
  for k,_ in pairs(cmds) do 
    if cmds[k.._"help"] then printf(cmds[k.._"help"]) end
  end
end

cmds.download_help = "download <id> [<path>] - Download QA with given id and unpacks it"
function cmds.download(id,savePath)
  id = tonumber(id)
  __assert_type(id, "number")
  fibaro.hc3emu.downloadFQA(id,savePath or "./")
end

cmds.unpack_help = "unpack <fqa path> [<save path>] - Unpacks given FQA file"
function cmds.unpack(path, savePath)
  __assert_type(path, "string")
  TQ.unpackFQA(path,savePath or "./")
end

local stat,err = pcall(function()
  local cmd = args[1]
  if not cmd or cmds[cmd] then
    cmds.help()
    return
  end
  cmds[cmd](table.unpack(args,2))
end)
if not stat then 
  print("Error occurred: " .. err) 
end
os.exit()
