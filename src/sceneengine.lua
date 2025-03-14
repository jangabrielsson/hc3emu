TQ = fibaro.hc3emu

local rs2st = TQ.loadfile("hc3emu.sourcetrigger",_G).refreshStateEvent2SourceTrigger
local lib = TQ.loadfile("hc3emu.lib",_G)
local EVENT = TQ.loadfile("hc3emu.event",_G)
local event = EVENT.event
local post = EVENT.post

local function startRefreshListener(info)
  TQ.addRefreshStateListener(function(ev) -- Add event listener for refresh state events
    if ev.created < info.created  then return end -- Skip events before scene were created
    rs2st(ev,post)
  end)
end

local sceneEngine = {
  event = event,
  post = post,
  startRefreshListener = startRefreshListener
}

---@diagnostic disable-next-line: lowercase-global
__emu_sceneEngine = sceneEngine

