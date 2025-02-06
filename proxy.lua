---@diagnostic disable: undefined-global, duplicate-set-field
local fmt = string.format
local quickApp

function QuickApp:onInit()
  self:debug("Started", self.name, self.id)
  quickApp = self

  local send

  local IGNORE={ MEMORYWATCH=true,APIFUN=true}

  function quickApp:actionHandler(action)
    if IGNORE[action.actionName] then
      print(action.actionName)
      return quickApp:callAction(action.actionName, table.unpack(action.args))
    end
    send({type='action',value=action})
  end

  function quickApp:UIHandler(ev) send({type='ui',value=ev}) end

  function QuickApp:APIFUN(id,method,path,data)
    local stat,res,code = pcall(api[method:lower()],path,data)
    send({type='resp',id=id,value={stat,res,code}})
  end

  function QuickApp:initChildDevices(t) end

  local ip,port = nil,nil
  
  local function getAddress() -- continously poll for new address from emulator
    local var = __fibaro_get_global_variable("TQEMU") or {}
    local success,values = pcall(json.decode,var.value)
    if success then
      ip = values.ip
      port = values.port
    end
    setTimeout(getAddress,5000)
  end
  getAddress()

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
        assert(sock)
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