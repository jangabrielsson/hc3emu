---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=createStructs
--%%type=com.fibaro.multilevelSwitch
--%%dark=true
--%%id=5001
--%%debug=info:true,http:true,onAction:true,onUIEvent:true
local fmt = string.format 
local io = fibaro.hc3emu.lua.io

local paths = {
  "/settings/info",
  "/settings/location",
  "/home",
}

local function printf(...) print(string.format(...)) end

local function traverse(d,f)
  if type(d)~='table' then return end
  for k,v in pairs(d) do
    d[k] = f(k,v)
    traverse(d[k],f)
  end
end

function QuickApp:onInit()
  local data = {
    info = api.get("/settings/info"),
    location = api.get("/settings/location"),
    home = api.get("/home"),
    device1 = api.get("/devices/1"),
  }

  traverse(data,function(k,v)
    if k=='serialNumber' or k=='hcName' then return "HC312345667" end
    if k=='city' then return "Stockholm" end
    return v
  end)

  local f = io.open("rsrcs/stdStructs.lua", "w")
  assert(f)
  f:write(fmt("return [[%s]]",json.encode(data)))
  f:close()

  print("Done")
end