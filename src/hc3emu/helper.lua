local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local copas = require("copas")
local json = require("hc3emu.json")

local helperStarted = false
local HELPER_UUID = "hc3emu-00-01"

local function installHelper()
  local fqa = E.config.loadResource("hc3emuHelper.fqa",true)
  if not fqa then
    E:ERRORF("Failed to load helper")
    return nil
  end
  fqa.visible = false
  local helper,err = E.tools.uploadFQA(fqa)
  if not helper then
    E:ERRORF("Failed to install helper: %s",err or "Unknown error")
    return nil
  end
  E.api.hc3.put("/devices/"..helper.id,{visible=false}) -- Hide helper
end

RequestServer = RequestServer
class 'RequestServer'(E.util.SocketServer)
function RequestServer:__init(ip,port) SocketServer.__init(self,ip,port,"helper connection") end
function RequestServer:handler(skt)
  local queue = copas.queue.new()
  while true do
    local req = queue:pop(math.huge)
    copas.send(skt,req.request)
    local reqdata = copas.receive(skt)
    req.response = reqdata
    req.sem:destroy()
    if not reqdata then break end
  end
end
function RequestServer:send(msg)
  local req = {request=msg,response=nil,sem = copas.semaphore.new(1,0,math.huge)}
  self.queue:push(req)
  req.sem:take()
  return req.response
end

local function startHelper()
  if helperStarted then return end
  local ip = E.emuIP
  local port = E.emuPort+1
  local helper = (E.api.hc3.get("/devices?property=[quickAppUuid,"..HELPER_UUID.."]") or {})[1]
  if not helper or helper.properties.quickAppUuid ~= HELPER_UUID then helper = installHelper() end
  if not helper then
    return E:ERRORF("Failed to install helper")
  end
  local helperId = helper.id
  if helperId then
    E.api.hc3.post("/devices/"..helperId.."/action/close",{ args={ip,port}} )
    --copas.pause(2)
    exports.connection = RequestServer(ip,port)
    exports.connection:start()
    E.api.hc3.post("/devices/"..helperId.."/action/connect",{args={ip,port}})
  end
  
  helperStarted = true

  E.util.systemTask(function()
    while true do
      local _ = exports.connection:send("Ping\n")
      copas.pause(10)
    end
  end)
end

exports.start = startHelper
return exports