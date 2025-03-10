--if require and not QuickApp then require("hc3emu") end 

--This is the hc3emu file we require. It gets the calling file, main file, and then loads the emulator and runs it.
--If _DEVELOP is set to true ot will load the files from the local directory to allow us to develop and debug the emulator.
--If _DEVELOP is false it will load the files from the package directory, the standard require way...

-- Get main lua file
local flag = false
local file2find = SCRIPTNAME or "%.lua$"
for i=1,20 do -- We do a search up the stack just in case that different debuggers are used... for mobdebug our offset is 5...
  local inf = debug.getinfo(i)
  if not inf then break end
  if flag and inf.source:match(file2find) then 
    MAINFILE = inf.source:match("@*(.*)")
    break 
  end
  if inf.source:match("hc3emu%.lua$") then flag=true end
end
assert(MAINFILE,"Cannot find main lua file")

TQ = { _PREFIX = "" }
local prefix = ""
if type(_DEVELOP)=='string' then
  prefix = _DEVELOP
  if not prefix:match("/$") then prefix = prefix.."/" end
  _DEVELOP = true
  TQ._PREFIX = prefix
end

function TQ.require(path)
  if _DEVELOP then
    if not path:match("^hc3emu") then return require(path) end
    path = prefix.."src/"..path:match(".-%.(.*)")..".lua" -- If developing, we pick it up from our own directory
    return dofile(path)
  else 
    return require(path)  -- else require the package
  end
end

function TQ.pathto(module)
  if _DEVELOP then
    if not module:match("^hc3emu") then return package.searchpath(module,package.path) end
    return prefix.."src/"..module:match(".-%.(.*)")..".lua" -- If developing, we pick it up from our own directory
  else 
    return package.searchpath(module,package.path)  
  end
end

TQ.require("hc3emu.emu") -- This is the main emulator that we load and that will emulate the main file for us.
