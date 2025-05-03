local E = Emulator.emulator
local fmt = string.format
local copas = require("copas")

--[[ Emulator events
{type='emulator_started'}             -- when emulator is initialized
{type='quickApp_registered',id=qaId}  -- when a quickApp is registered in emulator but not started
{type='quickApp_loaded',id=qaId}      -- when a quickApp files are loaded
{type='quickApp_initialized',id=qaId} -- before :onInit, QuickApp instance created
{type='quickApp_started',id=qaId}     -- after :onInit
{type='quickApp_finished',id=qaId}    -- no timers left
{type='scene_registered',id=sceneId}
{type='time_changed'}
{type='midnight'}
--]]

local sys = require("system")

local _term = {}
local exitKey = 0x1b  -- default to ESC key

local isSetup = false
local function setupTerm()
  if isSetup then return end
  isSetup = true
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
local isPoller = false
local function keyPoller()
  if isPoller then return end
  isPoller = true
  E.util.systemTask(function()
    while true do
      local key, keytype = sys.readansi(0.01)
      if keytype == 'char' and key:byte() == exitKey then
        print("Exit key pressed, exiting")
        shutdownTerm()
        os.exit(0)
      end
      if key and keyHandler then keyHandler(key, keytype) end
      copas.pause(0.01)
    end
  end)
end

E.terminal = {}
E.terminal.setExitKey = function(b) setupTerm() exitKey = b end
E.terminal.setKeyHandler = function(f) setupTerm() keyPoller() keyHandler = f end
function E.terminal.clear() print("\027[2J") end