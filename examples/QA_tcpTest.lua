_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=TcpTest
--%%type=com.fibaro.binarySwitch

local ip,port = "localhost",8432

local SocketServer = fibaro.hc3emu.util.SocketServer
MyServer = MyServer
class 'MyServer'(SocketServer)
function MyServer:__init(ip,port) SocketServer.__init(self,ip,port,"proxy","server") end
function MyServer:handler(io)
  while true do
    local reqdata = io.read()
    if not reqdata then break end
    print("Data",reqdata)
    io.write("OK\n")
  end
end

MyServer(ip,port):start()

function QuickApp:onInit()
  self:debug("onInit",self.name,self.id)
  
  local sock = net.TCPSocket()
  
  local function err(code) self:error(code) end
  local function connected()
    self:debug("Connected")
    sock:write("0001\n",{
      success = function() 
        sock:read({
          success = function(data)
            self:debug("Got",data)
            sock:close()
          end,
          error = err
        })
      end,
      error = err
    })
    
  end
  sock:connect(ip,port,{success = connected, error = err})
end