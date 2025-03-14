TQ = TQ
local copas = TQ.copas
local json = TQ.json
local addThread = TQ.addThread
local ERRORF = TQ.ERRORF

local queue = {}
local last,first = 1,0
local setupRefreshState

local listeners = {}
function TQ.addRefreshStateListener(listener)
  setupRefreshState()
  listeners[listener] = true
end
function TQ.removeRefreshStateListener(listener) listeners[listener] = nil end

local function addEvent(event)
  if not event.created then event.created = os.time() end
  first = first + 1
  queue[first] = event
  if first-last > 250 then
    queue[last] = nil
    last = last + 1
  end
  for l,_ in pairs(listeners) do l(event) end
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
    local data, status = TQ.HC3Call("GET", (last and path..("?last="..last) or path) .. suffix, nil, true)
    --print(status)
    if status ~= 200 then
      ERRORF("Failed to get refresh state: %s",status)
      return
    end
    assert(data, "No data received")
    ---@diagnostic disable-next-line: undefined-field
    last = math.floor(data.last) or last
    ---@diagnostic disable-next-line: undefined-field
    events = data.events
    if events ~= nil then
      for _, event in pairs(events) do
        --print(json.encode(event))
        addEvent(event)
      end
    end
    copas.pause(TQ._refreshInterval or 0.01)
  end
end

local inited = false
function setupRefreshState()
  if inited then return else inited = true end
  if not TQ.flags.offline then
    addThread(_G,refreshStatePoller)
  end
end

TQ.getRefreshStateEvents = getEvents -- (last)
TQ.addRefreshStateEvent = addEvent -- (event)