_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=MyQA
--%%type=com.fibaro.binarySwitch
--%%dport=8172

function QuickApp:onInit()
  print("Hello")
  setInterval(function() print("Ping") end,3000)
  self:test()
end

local sys = fibaro.hc3emu.lua.require("system")
local io = fibaro.hc3emu.lua.io

local _term = {}
local function setupTerm()
  sys.autotermrestore()  -- set up auto restore of terminal settings on exit 
  -- setup Windows console to handle ANSI processing
  _term.of_in = sys.getconsoleflags(io.stdin)
  _term.of_out = sys.getconsoleflags(io.stdout)
  sys.setconsoleflags(io.stdout, sys.getconsoleflags(io.stdout) + sys.COF_VIRTUAL_TERMINAL_PROCESSING)
  sys.setconsoleflags(io.stdin, sys.getconsoleflags(io.stdin) + sys.CIF_VIRTUAL_TERMINAL_INPUT)
  
  -- setup Posix terminal to use non-blocking mode, and disable line-mode
  _term.of_attr = sys.tcgetattr(io.stdin)
  _term.of_block = sys.getnonblock(io.stdin)
  sys.setnonblock(io.stdin, true)
  sys.tcsetattr(io.stdin, sys.TCSANOW, {
    lflag = _term.of_attr.lflag - sys.L_ICANON - sys.L_ECHO, -- disable canonical mode and echo
  })
end

local function shutdownTerm()
  -- Clean up afterwards
  sys.setnonblock(io.stdin, false)
  sys.setconsoleflags(io.stdout, _term.of_out)
  sys.setconsoleflags(io.stdin, _term.of_in)
  sys.tcsetattr(io.stdin, sys.TCSANOW, _term.of_attr)
  sys.setnonblock(io.stdin, _term.of_block)
end

local keyHandler
function QuickApp:test()
  setupTerm()
  setInterval(function()
    local key, keytype = sys.readansi(0.01)
    if key then keyHandler(key, keytype) end
  end, 200)
end

function keyHandler(key, keytype)
  -- check if we got a key or ANSI sequence
  if keytype == "char" then
    -- just a key
    local b = key:byte()
    if b < 32 then
      key = "." -- replace control characters with a simple "." to not mess up the screen
    end
    
    print("you pressed: " .. key .. " (" .. b .. ")")
    if b == 27 then
      print("Escape pressed, exiting")
      shutdownTerm()
      fibaro.hc3emu.lua.os.exit(0)
    end
    
  elseif keytype == "ansi" then
    -- we got an ANSI sequence
    local seq = { key:byte(1, #key) }
    print("ANSI sequence received: " .. key:sub(2,-1), "(bytes: " .. table.concat(seq, ", ")..")")
    
  else
    print("unknown key type received: " .. tostring(keytype))
  end
end