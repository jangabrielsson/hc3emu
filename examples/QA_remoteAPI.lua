_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=MyQA
--%%type=com.fibaro.binarySwitch

local hc3 = fibaro.hc3emu.api.hc3.sync
local a,b = api.get("/diagnostics")
print(b,json.encode(a))
local a,b = api.get("/userActivity")
print(b,json.encode(a))
local a,b = api.get("/settings/network")
print(b,json.encode(a))
local a,b = hc3.get("/settings/certificates/ca")
print(b,json.encode(a))

