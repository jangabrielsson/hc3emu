if require and not QuickApp then require('hc3emu') end

--%%name=GenerateDeviceData
--%%type=com.fibaro.binarySwitch

local lua = fibaro.hc3emu.lua

local hierarchy = api.get("/devices/hierarchy")

local function getDevices(t,d)
  d = d or {}
  d[#d+1] = t.type
  for _,v in ipairs(t.children) do
    getDevices(v,d)
  end
  return d
end

local devices = getDevices(hierarchy)
print(#devices)
print(json.encode(devices))

local f = lua.io.open("rsrcs/devices.json","r")
assert(f,"Cannot open rsrcs/devices.json")
local devs = json.decode(f:read("*a"))
f:close()
for _,typ in ipairs(devices) do
  if not devs[typ] then
    local fqa = {
      apiVersion = "1.3",
      name = "xyz",
      type = typ,
      initialProperties = {},
      initialInterfaces = json.util.InitArray({}),
      files = {{name="main", isMain=true, isOpen=false, type='lua', content=""}},
    }
    print("Creating device "..typ)
    local dev,err = api.post("/quickApp",fqa)
    if dev and dev.id then
      devs[typ] = dev
      api.delete("/devices/"..dev.id)
    else print("Error creating device "..typ,err) end
  end
end
local f = lua.io.open("rsrcs/devices.json","w")
f:write(json.encode(devs))
f:close()
print("Devices saved to rsrcs/devices.json")

