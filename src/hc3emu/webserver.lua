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
  print(path,json.encode(params))
  if params.qa then
    local qa = E:getQA(params.qa)
    if qa then
      local typ = ({button='onReleased',switch='onReleased',slider='onChanged',select='onToggled',multi='onToggled'})[path]
      local args = {elementName=params.id,eventType=typ,values={params.value or params.selectedOptions or params.state=='on'}}
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

local function member(e,l) for _,k in ipairs(l) do if e == k then return true end end return false end

local function generateUIpage(id,name,fname,UI)
  local format = string.format
  local buff = {format(header,E.emuIP,E.emuPort+1,id)}
  local function add(s) table.insert(buff,s) end
  local function addf(s,...) table.insert(buff,format(s,...)) end
  print("Generating UI page")
  addf('<div class="label">Device: %s</div>',name)
  for _,row in ipairs(UI) do
    if not row[1] then row = {row} end
    add('<div class="device-card">')
    addf('  <div class="device-controls%s">',#row)
    for _,item in ipairs(row) do
      if item.label then
        addf('    <div class="label">%s</div>',item.text)
      elseif item.button then
        addf([[    <button id="%s" class="control-button" onclick="fetchAction('button', this.id)">%s</button>]],item.button,item.text)
      elseif item.slider then
        addf([[    <input id="%s" type="range" value="%s" class="slider-container" oninput="handleSliderInput(this)">
                   <span id="sliderValue">%s</span>]],item.slider,item.value or 0,item.value or 0)
      elseif item.switch then
        -- Determine the initial state based on item.value
        local state = item.value == "true" and "on" or "off"
        local color = state == "on" and "green" or "#007bff" -- Set color based on state
        print("SWITCH", state) -- Debugging output to verify the state
        addf([[   <button id="%s" class="control-button" data-state="%s" style="background-color: %s;" onclick="toggleButtonState(this)">%s</button>]],
             item.switch, state, color, item.text)
      elseif item.select then 
        addf('<select class="dropdown" name="cars" id="%s" onchange="handleDropdownChange(this)">',item.select)
        for _,opt in ipairs(item.options) do
          addf('<option %s value="%s">%s</option>',item.value == opt.value and "selected" or "",opt.value,opt.text)
        end
        add('  </select>')
      elseif item.multi then
        add('<div class="dropdown-container">')
        addf([[<button onclick="toggleDropdown('%s')" class="dropbtn">Select Options</button>]],item.multi)
        addf('<div id="%s" class="dropdown-content">',item.multi)
        for _,opt in ipairs(item.options) do
          local function isCheck(v) 
            return item.values and member(v,item.values) and "checked" or "" 
          end
          addf('<label><input type="checkbox" %s value="%s" onchange="sendSelectedOptions(this)"> %s</label>',isCheck(opt.value),opt.value,opt.text)
        end
        add('</div>')
        add('</div>')
      end
    end
    add ('  </div>')
    add('</div>')
  end
  add(footer)
  local f = io.open(fname,"w")
  assert(f,"Failed to open file for writing: "..fname)
  f:write(table.concat(buff,"\n"))
  f:close()
end

local function updateView(id,name,fname,UI,cache)
  for _,r in ipairs(UI) do
    if not r[1] then r = {r} end
    for _,item in ipairs(r) do
      if item.label then
        item.text = cache[item.label]['text'] or ""
      elseif item.button then
        item.text = cache[item.button]['text'] or ""
      elseif item.slider then
        item.value = cache[item.slider]['value'] or 0
      elseif item.switch then
        item.value = tostring(cache[item.switch]['value'])
      elseif item.select then
        item.options = cache[item.select]['options'] or {}
        item.value = cache[item.select]['value'] or ""
        print(json.encode(item.value))
      elseif item.multi then
        item.options = cache[item.multi]['options'] or {}
        item.values = cache[item.multi]['value'] or {}
        print(json.encode(item.values))
      end
    end
  end
  generateUIpage(id,name,fname,UI)
end

exports.startServer = startServer
exports.generateUIpage = generateUIpage
exports.updateView = updateView
exports.init = init

return exports