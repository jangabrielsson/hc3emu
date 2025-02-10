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
  print(i,inf.currentline,inf.source)
end
assert(MAINFILE,"Cannot find main lua file")
local path = "hc3emu.emu"
if _DEVELOP then
  path = "lib/"..path:match(".-%.(.*)")..".lua" -- If developing, we pick it up from our own directory
  dofile(path)
else 
  require(path)  -- else require the package
end
