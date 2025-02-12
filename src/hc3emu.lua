--if require and not QuickApp then require("hc3emu") end 

--This is the hc3emu file we require. It gets the calling file, main file, and then loads the emulator and runs it.
--If _DEVELOP is set to true ot will load the files from the local directory to allow us to develop and debug the emulator.
--If _DEVELOP is false it will load the files from the package directory, the standard require way...

-- Get main lua file
local flag = false
for i=1,20 do -- We do a search up the stack just in case that different debuggers are used... for mobdebug it's offset 5.
  local inf = debug.getinfo(i)
  if not inf then break end
  if flag and inf.source:match("%.lua$") then 
    MAINFILE = inf.source:match("@*(.*)")
    break 
  end
  if inf.source:match("hc3emu%.lua$") then flag=true end
end
assert(MAINFILE,"Cannot find main lua file")

function REQUIRE(path)
  if _DEVELOP then
    path = "lib/"..path:match(".-%.(.*)")..".lua" -- If developing, we pick it up from our own directory
    return dofile(path)
  else 
    return require(path)  -- else require the package
  end
end

REQUIRE("hc3emu.emu") -- This is the main emulator that we load and that will emulate the main file for us.
