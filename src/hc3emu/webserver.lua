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

local function handleUI(url)
  local path,query = url:match("([^%?]+)%?(.*)")
  local qs = query:split("&")
  local params = {}
  for _,p in ipairs(qs) do
    local k,v = p:match("([^=]+)=(.*)")
    if k == 'selectedOptions' then 
      params[k] = params[k] or {}
      table.insert(params[k],v)
    else params[k] = tonumber(v) or v end
  end
  if path=="multi" then params.selectedOptions = params.selectedOptions or {} end
  --print(path,json.encode(params))
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

local started = false
local function startServer(id)
  if started then return end
  started = true
  local ip = "0.0.0.0"
  local port = tonumber(E.emuPort) + 1
  E:DEBUGF('info',"Starting webserver at %s:%s",ip,port)

  local function handle(skt)
    E.mobdebug.on()
    E:setRunner(E.systemRunner)
    local name = skt:getpeername() or "N/A"
    --E._client = skt
    E:DEBUGF("server","New connection: %s",name)
    local request = nil
    while true do
      local reqdata = copas.receive(skt)
      request = request or reqdata
      if reqdata == "" then
        copas.send(skt, "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nAccess-Control-Allow-Origin: *\r\n\r\n")
        --copas.send(skt, "<html><body><h1>HC3 Emulator</h1><p>Emulator is running</p></body></html>")
        local url = request:match("GET /([^%s]+)")
        if url then handleUI(url) end
        break
      end
    end
    --E._client = nil
    E:DEBUGF("server","Connection closed: %s",name)
  end
  local server,err = socket.bind('*', port)
  if not server then error(fmt("Failed open socket %s: %s",port,tostring(err))) end
  --E._server = server
  copas.addserver(server, handle)
end

local header = [[
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Device View</title>
  <link rel="stylesheet" href="style.css"> <!-- Include external CSS -->
  <script>
    const SERVER_IP = "http://%s:%s"; // Define the server IP address
    const DEVICE_ID = "%s"; // Define the QA id
  </script>
  <script src="script.js" defer></script> <!-- Include external JavaScript -->
</head>
<body>
]]

local footer = [[
</body>
</html>
]]

local indexheader = [[
<!DOCTYPE html>
<html>
<head>
  <title>QuickApps</title>
</head>
<body>
  <h1>Installed QuickApps</h1>
  <ul>
]]
local indexfooter = [[
  </ul>
</body>
</html>
]]
local styles

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

local function generateUIpage(id,name,fname,UI,root,noIndex)
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
  local f = io.open(root..fname,"w")
  assert(f,"Failed to open file for writing: "..fname)
  f:write(pr:tostring())
  f:close()
  if not noIndex then -- generate index file
    local qa = E:getQA(id)
    local path = qa.uiPage:match("(.*[/\\])") or E.fileSeparator
    pages[#pages+1] = {id=qa.id,name=qa.name,path=fname}
    local pr = prBuff(indexheader)
    for _,f in ipairs(pages) do
      pr:printf('<li><a href="%s">%s %s</a></li>',f.path,f.id,f.name)
    end
    pr:print(indexfooter)
    pr:print(styles)
    local f = io.open(root.."_index.html","w")
    assert(f,"Failed to open file for writing: index.html")
    f:write(pr:tostring())
    f:close()
  end
  local elapsed = os.clock() - t0
  E:DEBUGF('info',"UI page generated in %.3f seconds",elapsed)
end

local ref = nil
local function updateView(id,name,fname,UI,root)
  if ref then return end
  ref = E:addThread(E.systemRunner,function()
    copas.sleep(0.3)
    ref=nil
    generateUIpage(id,name,fname,UI,root,true)
  end)
end

function E.EVENT.quickApp_updateView(ev)
  local id = ev.id
  local qa = E:getQA(id)
  if qa.uiPage then
    updateView(qa.id,qa.name,qa.uiPage,qa.UI, qa.html)
  end
end

styles = [[
<style>
  body {
    font-family: 'Arial', sans-serif;
    margin: 40px;
    background-color: #f9f9f9;
    color: #333;
    line-height: 1.6;
  }
  h1 {
    color: #2c3e50;
    text-align: center;
    margin-bottom: 30px;
  }
  ul {
    list-style-type: none;
    padding: 0;
  }
  li {
    margin-bottom: 15px;
  }
  a {
    text-decoration: none;
    color: #fff;
    background-color: #3498db;
    display: block;
    padding: 15px 20px;
    border-radius: 8px;
    transition: background-color 0.3s, transform 0.3s;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    border: none;
  }
  a:hover {
    background-color: #2980b9;
    transform: translateY(-2px);
    box-shadow: 0 6px 8px rgba(0, 0, 0, 0.15);
  }
</style>
]]

exports.startServer = startServer
exports.generateUIpage = generateUIpage
exports.updateView = updateView
exports.init = init

return exports