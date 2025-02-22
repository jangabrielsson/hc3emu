#!/usr/bin/env lua

if require and not QuickApp then require("hc3emu") end
--%%color=false
--%%shellscript=true
--%%silent=true
--%%debug=info:false

local deviceId = tonumber(args[1])
local property = args[2]
local qa = api.get("/devices/"..deviceId)
_print(string.format("Device %s property '%s' = %s",deviceId,property,qa.properties[property]))
os.exit()
