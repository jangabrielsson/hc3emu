---@diagnostic disable: duplicate-set-field
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=Test
--%%type=com.fibaro.multilevelSwitch
--%%dark=true
--%%debug=sdk:false,info:true,proxyAPI:true,server:true,onAction:true,onUIEvent:true
--%%debug=http:true,color:true,blockAPI:true


function QuickApp:onInit()
  local sock = net.WebSocketClientTls()
  local n=0
  local function handleConnected()
    self:debug("connected")
    setInterval(function()
        n=n+1
        sock:send("WebSocket: Hello from hc3emu "..n.."\n")
    end,100)
  end
  
  local function handleDisconnected() self:warning("handleDisconnected") end
  local function handleError(error) self:error("handleError:", error) end
  local function handleDataReceived(data) self:trace("dataReceived:", data) end
  
  sock:addEventListener("connected", function() handleConnected() end)
  sock:addEventListener("disconnected", function() handleDisconnected() end)
  sock:addEventListener("error", function(error) handleError(error) end)
  sock:addEventListener("dataReceived", function(data) handleDataReceived(data) end)
  --sock:connect("wss://echo.websocket.events/")
  sock:connect("wss://ws.postman-echo.com/raw")
  --sock:connect("wss://echo.websocket.org/") -- ssl handshake results in connection closed(!)
end
