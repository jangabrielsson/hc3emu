local fmt = string.format
local con = nil
local ip,port = nil,nil

function QuickApp:onInit()
  self:debug("Started", self.name, self.id)
  quickApp = self
  con = self:internalStorageGet("con") or {}
  ip = con.ip
  port = con.port
  local send
  
  local IGNORE={ MEMORYWATCH=true, APIFUN=true, CONNECT=true }
  
  function quickApp:CONNECT(con2)
    con = con or {}
    self:internalStorageSet("con",con)
    ip = con.ip
    port = con.port
    self:debug("Connected")
  end

  function quickApp:actionHandler(action)
    if IGNORE[action.actionName] then
      print(action.actionName)
      return quickApp:callAction(action.actionName, table.unpack(action.args))
    end
    send({deviceId=self.id,type='action',value=action})
  end
  
  function quickApp:UIHandler(ev) send({type='ui',value=ev}) end
  
  function quickApp:APIFUN(id,method,path,data)
    local stat,res,code = pcall(api[method:lower()],path,data)
    send({type='resp',deviceId=self.id,id=id,value={stat,res,code}})
  end
  
  function quickApp:initChildDevices(_) end
  
  local queue = {}
  local sender = nil
  local connected = false
  local sock = nil
  local runSender
  
  local function retry()
    if sock then sock:close() end
    connected = false
    queue = {}
    sender = setTimeout(runSender,1500)
  end
  
  function runSender()
    if connected then
      if #queue>0 then
---@diagnostic disable-next-line: need-check-nil, undefined-field
        sock:write(queue[1],{
          success = function() print("Sent",table.remove(queue,1)) runSender() end,
        })
      else sender = nil print("Sleeping") end
    else
      if not (ip and sender) then sender = setTimeout(runSender,1500) return end
      print("Connecting...")
      sock = net.TCPSocket()
      sock:connect(ip,port,{
        success = function(message)
          sock:read({
            succcess = retry,
            error = retry
          })
          print("Connected") connected = true runSender()
        end,
        error = retry
      })
    end
  end
  
  function send(msg)
    msg = json.encode(msg).."\n"
    queue[#queue+1]=msg
    if not sender then print("Starting") sender=setTimeout(runSender,0) end
  end
  
end
