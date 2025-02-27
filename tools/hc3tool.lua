--#!/usr/bin/env lua

if require and not QuickApp then require("hc3emu") end
--%%color=false
--%%shell script=true
--%%silent=true
--%%debug=info:false

local args = {"list","globalVariables","YY"}

local function printf(...) _print(string.format(...)) end

local cmds = {}
function cmds.help()
  printf("Usage: hc3tool <command> [args]")
  printf("Commands:")
  for k,_ in pairs(cmds) do 
    if cmds[k.."_help"] then printf(cmds[k.."_help"]) end
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

cmds.list_help = "list <resource type> [<id/name>] -- list given HC3 resource type"
function cmds.list(rsrc,id)
  __assert_type(rsrc, "string")
  if not id then
    local r = api.get("/"..rsrc)
    for i,v in ipairs(r) do
      printf("%s",v.name or v.id or "")
    end
  else
    local r = api.get("/"..rsrc.."/"..id)
    assert(r, "Resource not found")
    printf("%s", json.encode(r))
  end
end

cmds.lua_help = "lua <lua command> -- run lua command"
function cmds.lua(str)
  __assert_type(str, "string")
  local f,err = fibaro.hc3emu.load(str)
  if not f then
    printf("Error: %s",err)
    return
  end
  local r = {pcall(f)}
  if r[1] then
    for i=2,#r do
      local v = r[i]
      printf("%s",type(v)=='table' and json.encode(v) or v)
    end
  else
    printf("Error: %s",r[2])
  end
end

local stat,err = pcall(function()
  local cmd = args[1]
  if not cmd or cmds[cmd]==nil then
    cmds.help()
    return
  end
  cmds[cmd](table.unpack(args,2))
end)
if not stat then 
  print("Error occurred: " .. err) 
end
os.exit()
