local HELPER_UUID = "hc3emu-00-01"
local HELPER_VERSION = "1.0.2"
local connections = {}
local DBG = true
local function DEBUG(...) if DBG then print(string.format(...)) end end

function QuickApp:onInit()
   print("Helper")
   self:updateProperty("quickAppUuid",HELPER_UUID)
   self:updateProperty("model",HELPER_VERSION)
end

local function doCommand(msg)
   --DEBUG("MSG: %s",msg)
   local req = json.decode(msg)
   --print("DECODED")
   local stat = {pcall(function() return api[req.method:lower()](req.path,req.data) end)}
   if not stat[1] then 
       print(stat[2]) 
       return json.encode({nil,506}).."\n"
   end
   local res = json.encode({stat[2],stat[3]})
   --print("RET",res)
   return res
end

local function startConnection(key,ip,port)
   local sock = net.TCPSocket()
   local cmd 

   local function err(err) 
      DEBUG("Disconnected from %s %s",key,tostring(err)) 
      if connections[key] then connections[key]:close() end
      connections[key]=nil 
   end

   local function readParts(data,n,parts)
      --print("RP",n,data)
      if data == nil then return err('No data') end
      parts[#parts+1]= data
      if n < 1 then return cmd(table.concat(parts):gsub("\n","")) end
      sock:read({
         success=function(data) readParts(data,n-1,parts) end,
         error = err
      })
   end

   local function read()
      sock:read({
         success=function(data)
            --print("FP",1,data)
            if not data then return err('No data') end
            local n = tonumber(data:sub(1,3))
            if not n then return end
            data = data:sub(5)
            if n == 1 then return cmd(data:gsub("\n","")) end
            sock:read({
               success=function(resp) readParts(resp,n-2,{data}) end,
               error=err
            })
         end,
         error=err
      })
   end

   local function writeParts(str,i,n,n0)
      if n < 1 then return read() end
      --print("WP1",n,str:sub(i,i+n0-1))
      sock:write(str:sub(i,i+n0-1).."\n",{
         success=function() writeParts(str,i+n0,n-1,n0) end,
         error=err
      })
   end

   local n0 = 500
   local function write(str)
      local len = #str
      local n = (len-1) // n0 + 1
      local p = str:sub(1,1+n0-1)
      --print("WP0",n,p)
      sock:write(string.format("%03d:%s\n",n,p),{
         success=function() writeParts(str,1+n0,n-1,n0) end,
         error=err
      })
   end

   function cmd(msg)
      --print("LAST",string.byte(msg:sub(-1)),msg:sub(-1) == '\n')
      local resp = "Pong"
      if msg~="Ping" then
         resp = doCommand(msg) 
      end
      write(resp)
   end
   
   local function connected()
      connections[key]=sock
      DEBUG("Connected to %s",key)
      read()
   end

   sock:connect(ip,port,{success = connected, error = err})
end

function QuickApp:connect(ip,port)
   local key = ip..":"..port 
   if connections[key] then return end
   startConnection(key,ip,port)
end

function QuickApp:close(ip,port)
   local key = ip..":"..port
   if connections[key] then 
      DEBUG("Close called")
      connections[key]:close()
      connections[key] = nil
   end
end
