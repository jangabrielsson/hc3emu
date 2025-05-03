_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=MyQA
--%%type=com.fibaro.binarySwitch
--%%plugin=$hc3emu.terminal

local sys = fibaro.hc3emu.lua.require("system")
local term = fibaro.hc3emu.terminal
local pr = fibaro.hc3emu.lua.print

function QuickApp:onInit()
  print("Hello")
  --setInterval(function() print("Ping") end,3000)
  term.setExitKey(27)
  term.setKeyHandler(function(key, keytype)
    --term.clear() -- clear screen  
    --pr("\027[H")
    if keytype == "char" then
      -- just a key
      local b = key:byte()
      if b < 32 then
        key = "." -- replace control characters with a simple "." to not mess up the screen
      end

      print("Key received: " .. key .. " (byte: " .. b .. ")")
      
    elseif keytype == "ansi" then
      -- we got an ANSI sequence
      local seq = { key:byte(1, #key) }
      print("ANSI sequence received: " .. key:sub(2,-1), "(bytes: " .. table.concat(seq, ", ")..")")
      
    else
      print("unknown key type received: " .. tostring(keytype))
    end
  end)
end
