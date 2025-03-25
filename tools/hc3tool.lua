--#!/usr/bin/env lua

_DEVELOP = true
SCRIPTNAME = "hc3tool"
if require and not QuickApp then require("hc3emu") end
--%%color=false
--%%shell script=true
--%%silent=true
--%%debug=info:false

io = fibaro.hc3emu.lua.io
local lua = fibaro.hc3emu.lua
local path = lua.package.searchpath("argparse",lua.package.path)
local argparse = lua.loadfile(path,"t",_G)()
print = lua.print
local output = lua.print

local function ERROR(fmt,...) output(string.format("Error: "..fmt,...)) os.exit(-1) end

local parser = argparse("hc3tool", "Script to interact with HC3")
parser:command_target("command")

local list = parser:command("list", "List HC3 resources")
list:argument("resource", "Resource type"):choices({"devices","globalVariables","quickApps","scenes","rooms","sections","users","settings","gateways","notifications","plugins","scenes","sections","rooms","globalVariables","gateways","notifications","plugins","settings","users","quickApps"})
list:argument("id", "Resource id"):args("?")
list:flag("-p --pretty", "Pretty print")

local quickApp = parser:command("qa", "QuickApp operations")
quickApp:argument("id", "QuickApp id"):convert(tonumber)
quickApp:argument("file", "QuickApp file"):args("?")

local download = parser:command("download", "Download QuickApp or Scene")
download:argument("what", "qa or scene"):choices({"qa","scene"})
download:argument("id", "QuickApp or Scene id"):convert(tonumber)

local upload = parser:command("upload", "Upload QuickApp or Scene")
upload:argument("file", "QuickApp or Scene file, .fqa, .scene")

local call = parser:command("call", "fibaro.call")
call:argument("id", "QuickApp id"):convert(tonumber)
call:argument("method", "method")
call:argument("args", "args"):args("*")

local arg = "list devices 602 -p"
local arg = "list devices"
-- arg = "list globalVariables A -p"
-- arg = "qa 602"
-- arg = "qa 602 main"
-- arg="-h"
-- arg="download qa 602"
-- arg="call 3476 turnOn 55 {\"color\":0}"

if _DEVELOP then args = string.split(arg) end
args = parser:parse(args)
if _DEVELOP then output(json.encode(args)) end

local function printf(...) output(string.format(...)) end

local cmds = {}

function cmds.download(args)
  if args.what == "qa" then
    local fqa = api.get("/quickApp/export/"..args.id)
    printf("%s",json.encode(fqa))
  elseif args.what == "scene" then
    local scene = api.get("/scene/"..args.id)
    printf("%s",json.encode(scene))
  end
end

function cmds.qa(args)
  local id = args.id
  if not args.file then
    local r = api.get("/quickApp/"..id.."/files")
    for i,v in ipairs(r) do
      printf("%s",v.name)
    end
  elseif args.file then
    local r = api.get("/quickApp/"..id.."/files/"..args.file)
    print(r.content)
  elseif args.save then
    cmds.unpack(id,args.save)
  end
end
function cmds.list(args)
  local rsrc = args.resource
  local id = args.id
  if not id then
    local r = api.get("/"..rsrc)
    for i,v in ipairs(r) do
      printf("%s %s",v.id or v.name or "",v.value or v.name or "")
    end
  else
    local r = api.get("/"..rsrc.."/"..id)
    assert(r, "Resource not found")
    if args.pretty then
      printf("%s", json.encodeFormated(r))
    else
      printf("%s", json.encode(r))
    end
  end
end

function cmds.call(args)
  local id = args.id
  local cmd = args.method
  local params = {}
  for _,p in ipairs(args.args) do
    local c = p:sub(1,1)
    if c == '"' then params[#params+1] = p:sub(2,-2)
    elseif c == "{" then params[#params+1] = json.decode(p)
    elseif tonumber(p) then params[#params+1] = tonumber(p)
    elseif p == "true" then params[#params+1] = true
    elseif p == "false" then params[#params+1] = false
    else params[#params+1] = p end
  end
  local res,code = fibaro.call(id,cmd,table.unpack(params))
  printf(code)
end

local stat,err = pcall(function()
  local cmd = args.command
  cmds[cmd](args)
end)
if not stat then ERROR(err) end
os.exit(0)
