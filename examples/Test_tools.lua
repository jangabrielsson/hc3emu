_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=Tool test

local loadQAString = fibaro.hc3emu.loadQAString   -- Load QA from string and run it (saves as temp file)
local downloadFQA = fibaro.hc3emu.downloadFQA     -- Download QA from HC3, unpack and save it to disk
local unpackFQA = fibaro.hc3emu.unpackFQA         -- Unpacks FQA on disk (to disk)
local loadFQA = fibaro.hc3emu.loadFQA             -- Load FQA from file and run it (saves as temp files)
local saveQA = fibaro.hc3emu.saveQA               -- Save installed QA to disk as .fqa file
local installFQA = fibaro.hc3emu.installFQA       -- Installs QA from HC3 and run it. (saves as temp files)
local loadQA = fibaro.hc3emu.loadQA               -- Load QA from file and run it
local getFQA = fibaro.hc3emu.getFQA               -- Creates FQA structure from installed QA

--ENDOFDIRECTIVES--
loadQAString([[
--%%name=StringQA
function QuickApp:onInit()
  self:debug("onInit",self.name,self.id)
end
]])

--local sqa = api.get("/devices?name=StringQA") -- FIX, this is not found
local fqa = getFQA(plugin.mainDeviceId)
print("Name of this QA",fqa.name)

saveQA(5002,"StringQA.fqa")

loadFQA("StringQA.fqa")           -- Running new instance of the QA (5003)

unpackFQA("StringQA.fqa","./")

loadQA("StringQA.lua")            -- Running new instance of the QA (5004)