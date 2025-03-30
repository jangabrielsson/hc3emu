local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local json = require("hc3emu.json")
local urlencode
local fmt = string.format

local devices = {
  remote = "_remote.lua"
}

local function createSimDevice(type)
  local file,path = devices[type],"rsrcs"..E.fileSeparator.."simdevs"..E.fileSeparator
  if not _DEVELOP then 
    error("Not implemented")
  end
  local runner = E:getRunner()
  local html = nil
  if runner.flags.html then
    html = {"html="..runner.flags.html}
  end
  local qa = E.tools.loadQA(path..file,html)
  return qa.id
end


E.createSimDevice = createSimDevice
return {}
