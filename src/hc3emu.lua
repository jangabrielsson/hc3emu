--if require and not QuickApp then require("hc3emu") end 

--This is the hc3emu file we require. It gets the calling file, main file, and then loads the emulator and runs it.
--If _DEVELOP is set to true it will load the files from the local directory to allow us to develop and debug the emulator.
--If _DEVELOP is false it will load the files from the package directory, the standard require way...

_SCRIPTNAME = _SCRIPTNAME
_DEVELOP = _DEVELOP

-- Get main lua file
local flag = false
local mainfile
local file2find = _SCRIPTNAME or "%.lua$"
for i=1,20 do -- We do a search up the stack just in case that different debuggers are used... for mobdebug our offset is 5...
  local inf = debug.getinfo(i)
  if not inf then break end
  if flag and inf.source:match(file2find) then 
    mainfile = inf.source:match("@*(.*)")
    break 
  end
  if inf.source:match("hc3emu%.lua$") then flag=true end
end
assert(mainfile,"Cannot find main lua file")

if _DEVELOP then -- find our development files first if developing...
  print("_DEVELOP set, using local hc3emu codebase")
  if type(_DEVELOP)=='boolean' then
    package.path = ";src/?;src/?.lua;"..package.path
  else
    package.path = _DEVELOP.."/src/?;".._DEVELOP.."/src/?.lua;"..package.path
  end
end

local Emulator = require("hc3emu.emu") -- This is the emulator that we load and that will emulate the main file for us.
local emulator = Emulator(mainfile)
emulator:run()