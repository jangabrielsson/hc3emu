_DEVELOP =true
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

local fqa = getFQA(plugin.mainDeviceId)
print("Name of this QA",fqa.name)

-- Run instance of QA (5002)
loadQAString([[
--%%name=StringQA
--%%breakOnLoad=true
function QuickApp:onInit()
  print(self.id)
  self:debug("onInit",self.name,self.id)
end
]])   


local sqa = api.get("/devices?name=StringQA") -- Works almost, check proxy...

saveQA(5002,"StringQA.fqa")       -- Save running QA to disk as .fqa

loadFQA("StringQA.fqa",{"breakOnLoad=true"})           -- Running new instance of the QA (5003)

unpackFQA("StringQA.fqa","./")    -- Unpack fqa on disk to lua file

loadQA("StringQA.lua")            -- Running new instance of the QA (5004)

fqa = getFQA(5004)                -- Get FQA structure from installed QA

local dev,err = api.post("/quickApp/",fqa) -- Install QA from fqa file

print("Installed QA's deviceId",dev.id)

installFQA(dev.id)                -- Running new instance of the QA downloaded from HC3 (5005)

-- Clean up
print("Cleaning up")
os.remove("StringQA.fqa")         -- Remove saved fqa file
os.remove("StringQA.lua")         -- Remove saved lua file
api.delete("/devices/"..dev.id)   -- Remove installed QA

print("Done")