local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local json = require("hc3emu.json")
local urlencode
local fmt = string.format

local remote = [[
--%%name=Remote
--%%type=com.fibaro.remote
--%%html=html

--%%u={{button='b1',text='□',onReleased="b1"},{button='b2',text='O',onReleased="b2"}}
--%%u={{button='b3',text='X',onReleased="b3"},{button='b4',text='△',onReleased="b4"}}
--%%u={{button='b5',text='-',onReleased="b5"},{button='b6',text='+',onReleased="b6"}}
function QuickApp:onInit()
end
function QuickApp:b1() self:debug("b1") end
function QuickApp:b2() self:debug("b2") end
function QuickApp:b3() self:debug("b3") end
function QuickApp:b4() self:debug("b4") end
function QuickApp:b5() self:debug("b5") end
function QuickApp:b6() self:debug("b6") end
]]

local devices = {
  remote = remote
}

local function createSimDevice(type)
  local code = devices[type]
  assert(code, fmt("No such device type %s",type))
  return E.tools.loadQAString(code)
end

E.createSimDevice = createSimDevice
return {}
