#!/usr/bin/env lua

if require and not QuickApp then require("hc3emu") end
--%%color=false
--%%shellscript=true
--%%silent=true
--%%debug=info:false

local stat,err = pcall(function()
  
  local deviceId = tonumber(args[1])
  __assert_type(deviceId, "number")
  fibaro.hc3emu.downloadFQA(deviceId,"./")

end)
if not stat then 
  print("Error occurred: " .. err) 
end
os.exit()
