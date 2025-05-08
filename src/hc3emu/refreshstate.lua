local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local json = require("hc3emu.json")
local copas = require("copas")

local queue = {}
local last,first = 1,0
local setupRefreshState

local listeners = {}
local function addRefreshStateListener(listener)
  setupRefreshState()
  listeners[listener] = true
end
local function removeRefreshStateListener(listener) listeners[listener] = nil end

local function addEvent(event,exclListener)
  E:DEBUGF("refresh","Refresh %s:%s",event.type,json.encode(event.data))
  if not event.created then event.created = os.time() end
  first = first + 1
  queue[first] = event
  if first-last > 250 then
    queue[last] = nil
    last = last + 1
  end
  -- if event.type == 'CentralSceneEvent' then 
  --   print("addEvent") 
  -- end
  for l,_ in pairs(listeners) do 
    if l ~= exclListener then 
      l(event) 
    end 
  end
end

local events = require("hc3emu.refreshstateevents")
local post = {}
for k,v in pairs(events) do
  local f,m = k,v
  post[k] = function(...) addEvent(m(...)) end
end

local function getEvents(l)
  setupRefreshState()
  l = l or 0
  local res = {}
  if l > first or first==0 then
    return res,first+1
  end
  l = math.max(l,last)
  for i = l,first do
    res[#res+1] = queue[i]
  end
  return res,first+1
end

local function refreshStatePoller()
  local path = "/refreshStates"
  local last,events=1,nil
  local suffix = "&lang=en&rand=7784634785"
  while true do
    local data, status = E:HC3Call("GET", (last and path..("?last="..last) or path) .. suffix, nil, true)
    --print(status)
    if status ~= 200 then
      E:ERRORF("Failed to get refresh state: %s",status)
      return
    end
    assert(data, "No data received")
    ---@diagnostic disable-next-line: undefined-field
    last = math.floor(data.last) or last
    ---@diagnostic disable-next-line: undefined-field
    events = data.events
    if events ~= nil then
      for _, event in pairs(events) do
        --E:DEBUGF("refresh","Refresh %s:%s",event.type,json.encode(event.data))
        addEvent(event)
      end
    end
    --if next(data.changes) then print("CHANGE:",json.encode(data.changes)) end
    copas.pause(E._refreshInterval or 0.01)
  end
end

local inited = false
function setupRefreshState()
  if inited then return else inited = true end
  if not E.DBG.offline then
    E:addThread(E.systemRunner,refreshStatePoller)
  end
end

exports.addRefreshStateListener = addRefreshStateListener
exports.removeRefreshStateListener = removeRefreshStateListener
exports.getRefreshStateEvents = getEvents -- (last)
exports.addRefreshStateEvent = addEvent -- (event)
exports.post = post -- (event)

return exports