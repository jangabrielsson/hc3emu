---@diagnostic disable: duplicate-set-field
--_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

local debug = fibaro.hc3emu.luadebug

local function hook()
  local function myHook(w,...) 
    if w == "call" or w == "return" or w == "line" then
      local f = debug.getinfo(2, "nfS")
      if f.what == "C" then
        if f.name=='pcall' then
          f.func = nil
          print("PCALL",json.encode(f))
        end
        return
      end
      if f.source:match("^@/opt/homebrew") then return end
      if f.source:match("^@/Users/jangabrielsson/.vscode/extensions") then return end
      f.func = nil
      f.source = nil
      print(w,json.encode(f))
    end
    -- f(w,...)
  end
  debug.sethook(myHook,"crl",1)
end

hook()
print("Hello from hc3emu")

local function Fopp()
  local t = 99
end
print("FUN",Fopp)
function QuickApp:onInit()
  self:debug("onInit",self.name,self.id)
  print("<font color='red'>Hello from hc3emu</font>")
  setInterval(function()
    hook()
    pcall(Fopp)
    print("PING")
  end,2000)
end
