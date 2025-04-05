local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local json = require("hc3emu.json")
local copas = require("copas")
local socket = require("socket")
local urlencode
local fmt = string.format

local function init()
  urlencode = E.util.urlencode
end

local function urldecode(str) 
  return str and str:gsub('%%(%x%x)',function(x)
    return string.char(tonumber(x, 16)) 
  end)
end

local commands = {}
function commands.install(params,_)
  if E.config[params.cmd] then E.config[params.cmd](params) end
end

function commands.getLocal(params,skt)
  local path = urldecode(params.path)
  local content = nil
  if params.type and params.type == 'rsrc' then
    content = E.config.loadResource(path)
  else
    local f = io.open(path,"r")
    if f then content = f:read("*a") f:close() end
  end
  if content then
    copas.send(skt,"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: "..(#content).."\r\n\r\n"..content)
    return true
  else
    E:ERRORF("Failed to open file for reading: %s",params.path)
  end
end

function commands.saveSettings(data,params,skt)
  local typ = params.type
  E.config.saveSettings(typ,data)
end

local function parseUrl(url)
  local path,query = url:match("([^%?]+)%?(.*)")
  if path==nil then path = url query = "" end
  local qs = query:split("&")
  local params = {}
  for _,p in ipairs(qs) do
    local k,v = p:match("([^=]+)=(.*)")
    if k == 'selectedOptions' then 
      params[k] = params[k] or {}
      table.insert(params[k],v)
    else params[k] = tonumber(v) or v end
  end
  if path:sub(1,1) == '/' then path = path:sub(2) end
  return path,params
end

local function handleGET(url,headers,skt)
  local path,params = parseUrl(url)
  if path=="multi" then params.selectedOptions = params.selectedOptions or {} end
  --print(path,json.encode(params))
  if commands[path] then
    return commands[path](params,skt)
  end
  if params.qa then
    local qa = E:getQA(params.qa)
    if qa then
      local typ = ({button='onReleased',switch='onReleased',slider='onChanged',select='onToggled',multi='onToggled'})[path]
      if params.id:sub(1,2)=="__" then -- special embedded UI element
        local actionName = params.id:sub(3)
        local args = {
          deviceId=qa.id,
          actionName=actionName,
          args={params.value or params.selectedOptions or params.state=='on' or nil}
        }
        if qa.isChild then qa = E:getQA(qa.device.parentId) end
        return qa:onAction(params.qa,args)
      end
      local args = {
        deviceId=qa.id,
        elementName=params.id,
        eventType=typ,
        values={params.value or params.selectedOptions or params.state=='on'}
      }
      if qa.isChild then qa = E:getQA(qa.device.parentId) end
      qa:onUIEvent(params.qa,args)
    end
  end
end

local function handlePOST(url,headers,skt)
  local path,params = parseUrl(url)
  local len = 0
  for _,header in ipairs(headers) do
    len = header:match("Content%-Length: (%d+)")
    if len then len = tonumber(len) or 0 break end
  end
  local data = copas.receive(skt,len)
  if commands[path] then
    commands[path](data,params,skt)
  end
  copas.send(skt,"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n")
  return true
end

-- CORS control from client - answer yes...
local function handleOPTIONS(path,headers,skt)
  local date = os.date("!%a, %d %b %Y %H:%M:%S GMT")
  copas.send(skt,
  "HTTP/1.1 200 OK\r\nDate: " .. date .. "\r\nServer: Apache/2.0.61 (Unix)\r\nAccess-Control-Allow-Origin:*\r\nAccess-Control-Allow-Methods: POST, GET, OPTIONS\r\nAccess-Control-Allow-Headers:X-PINGOTHER, Content-Type\r\n\r\n")
  return true
end

local started = false
local function startServer(id)
  if started then return end
  started = true
  local ip = "0.0.0.0"
  local port = tonumber(E.emuPort) + 1
  E:DEBUGF('info',"Starting webserver at %s:%s",ip,port)
  E.stats.ports[port] = true
  
  local function handle(skt)
    E.mobdebug.on()
    E:setRunner(E.systemRunner)
    local name = skt:getpeername() or "N/A"
    --E._client = skt
    E:DEBUGF("server","New connection: %s",name)
    local request = copas.receive(skt)
    local headers = {}
    while true do
      local header = copas.receive(skt)
      headers[#headers+1] = header
      if header == "" then
        local method,path = request:match("([^%s]+) ([^%s]+)")
        if method == 'GET' and handleGET(path,headers,skt) then 
          break
        end
        if method == "OPTIONS" then 
          handleOPTIONS(path,headers,skt) break 
        end
        if method == "POST" then 
          handlePOST(path,headers,skt) break
        end
        copas.send(skt, "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nAccess-Control-Allow-Origin: *\r\n\r\n")
        break
      end
      E:DEBUGF("server","Connection closed: %s",name)
    end
  end
  
  local server,err = socket.bind('*', port)
  if not server then 
    error(fmt("Failed open socket %s: %s",port,tostring(err)))
  end
  copas.addserver(server, handle)
end

local header = [[
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Device View</title>
  <link rel="stylesheet" href="pages/style.css"> <!-- Include external CSS -->
  <script>
    const SERVER_IP = "http://%s:%s"; // Define the server IP address
    const DEVICE_ID = "%s"; // Define the QA id
  </script>
  <script src="pages/script.js" defer></script> <!-- Include external JavaScript -->
</head>
<body>
]]

local footer = [[
</body>
</html>
]]

local function member(e,l) for _,k in ipairs(l) do if e == k then return true end end return false end

local pages = {}
local render = {}
function render.label(pr,item)
  pr:printf('<div class="label">%s</div>',item.text)
end
function render.button(pr,item)
  pr:printf([[<button id="%s" class="control-button" onclick="fetchAction('button', this.id)">%s</button>]],item.button,item.text)
end
function render.slider(pr,item)
  local indicator = item.slider.."Indicator"
  pr:printf([[<input id="%s" type="range" value="%s" class="slider-container" oninput="handleSliderInput(this,'%s')">
<span id="%s">%s</span>]],item.slider,item.value or 0,indicator,indicator,item.value or 0)
end
function render.switch(pr,item)
  -- Determine the initial state based on item.value
  local state = tostring(item.value) == "true" and "on" or "off"
  local color = state == "on" and "blue" or "#4272a8" -- Set color based on state #578ec9;
  pr:printf([[<button id="%s" class="control-button" data-state="%s" style="background-color: %s;" onclick="toggleButtonState(this)">%s</button>]],
  item.switch, state, color, item.text)
end
function render.select(pr,item)
  pr:printf('<select class="dropdown" name="cars" id="%s" onchange="handleDropdownChange(this)">',item.select)
  for _,opt in ipairs(item.options) do
    pr:printf('<option %s value="%s">%s</option>',item.value == opt.value and "selected" or "",opt.value,opt.text)
  end
  pr:print('</select>')
end
function render.multi(pr,item)
  pr:print('<div class="dropdown-container">')
  pr:printf([[<button onclick="toggleDropdown('%s')" class="dropbtn">Select Options</button>]],item.multi)
  pr:printf('<div id="%s" class="dropdown-content">',item.multi)
  for _,opt in ipairs(item.options) do
    local function isCheck(v) 
      return item.value and member(v,item.value) and "checked" or "" 
    end
    pr:printf('<label><input type="checkbox" %s value="%s" onchange="sendSelectedOptions(this)"> %s</label>',isCheck(opt.value),opt.value,opt.text)
  end
  pr:print('</div></div>')
end

local function prBuff(init)
  local self,buff = {},{}
  if init then buff[#buff+1] = init end
  function self:print(s) buff[#buff+1]=s end
  function self:printf(...) buff[#buff+1]=fmt(...) end
  function self:tostring() return table.concat(buff,"\n") end
  return self
end

local function generateUIpage(id,name,fname,UI)
  local format,t0 = string.format,os.clock()
  local pr = prBuff(format(header,E.emuIP,E.emuPort+1,id))
  --print("Generating UI page")
  pr:printf('<div class="label">Device: %s %s</div>',id,name)
  for _,row in ipairs(UI) do
    if not row[1] then row = {row} end
    pr:print('<div class="device-card">')
    pr:printf('  <div class="device-controls%s">',#row)
    for _,item in ipairs(row) do
      render[item.type](pr,item)
    end
    pr:print('</div>')
    pr:print('</div>')
  end
  pr:print(footer)
  local f = io.open(E.config.EMU_DIR.."/"..fname,"w")
  if f then
    f:write(pr:tostring())
    f:close()
    pages[fname] = {name=name,link=fname}
  else
    E:ERRORF("Failed to open file for writing: %s",E.config.EMU_DIR.."/"..fname)
  end
  local elapsed = os.clock() - t0
  E:DEBUGF('web',"UI page generated in %.3f seconds",elapsed)
end

local ref = nil
local function updateView(id,name,fname,UI)
  if ref then return end
  ref = E:addThread(E.systemRunner,function()
    copas.sleep(0.3)
    ref=nil
    generateUIpage(id,name,fname,UI)
  end)
end

function E.EVENT.quickApp_updateView(ev)
  local id = ev.id
  local qa = E:getQA(id)
  if qa.uiPage then
    updateView(qa.id,qa.name,qa.uiPage,qa.UI)
  end
end

local function updateEmuPage()
  local p = {} 
  for _,e in pairs(pages) do p[#p+1]= e end
  table.sort(p,function(a,b) return a.name < b.name end)
  local po = {} 
  for p,_ in pairs(E.stats.ports) do po[#po+1] = tostring(p) end
  local emuInfo = {
    stats = {
      version = E.VERSION,
      memory = fmt("%.2f KB", collectgarbage("count")),
      numqas = E.stats.qas,
      timers = E.stats.timers,
      ports =  table.concat(po,","),
    },
    quickApps = p,
    rsrcLink = ("/"..E.rsrcsDir.."/"):gsub("\\","/"),
  }
  local f = io.open(E.config.EMUSUB_DIR.."/info.json","w")
  if f then f:write((json.encode(emuInfo))) f:close() end
end
    
local started = false
local function generateEmuPage()
  if started then return else started = true end
  E:addThread(E.systemRunner,function()
    while true do
      updateEmuPage()
      copas.pause(2.0)
    end
  end)
end

exports.startServer = startServer
exports.generateUIpage = generateUIpage
exports.generateEmuPage = generateEmuPage
exports.updateEmuPage = updateEmuPage
exports.updateView = updateView
exports.init = init

return exports