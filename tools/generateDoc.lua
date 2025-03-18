local function readFile(f)
  local f = io.open(f,"r")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function writeFile(fname,s)
  local f = io.open(fname,"w")
  if not f then return false end
  f:write(s)
  f:close()
  return true
end

local function parseDoc(s)
  local lines = {}
  local out = {}
  for l in s:gmatch("[^\n]+") do
    lines[#lines+1] = l
  end
  local i = 1
  local function peek() return lines[i] end
  local function next() i=i+1 return lines[i-1] end

  while peek() do
    local l = next()
    local str = l:match("^%s*%-%-%s*@[DF]%s*(.*)")
    if str then 
      out[#out+1]="--%%"..str
      if peek():match("^%s*%-%-") then
        out[#out]=out[#out].."\n"..next():match("^%s*%-%-(.*)")
      end
    end
  end
  return out
end

local directives = parseDoc(readFile("src/emu.lua"))
table.sort(directives)
for _,d in ipairs(directives) do
  d = d:gsub("(.-)ex%.(.*)",function(a,b) return a.."\nex."..b end) or d
  print(d)
end