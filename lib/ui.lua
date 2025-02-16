local json = TQ.json
local fmt = string.format

-- arrayify table. Ensures that empty array is json encoded as "[]"
local function arrayify(t) 
  if type(t)=='table' then json.util.InitArray(t) end 
  return t
end

local function map(f,l) for _,v in ipairs(l) do f(v) end end

local function traverse(o,f)
  if type(o) == 'table' and o[1] then
    for _,e in ipairs(o) do traverse(e,f) end
  else f(o) end
end

local ELMS = {
  button = function(d,w)
    return {name=d.name,visible=true,style={weight=d.weight or w or "0.50"},text=d.text,type="button"}
  end,
  select = function(d,w)
    arrayify(d.options)
    if d.options then map(function(e) e.type='option' end,d.options) end
    return {name=d.name,style={weight=d.weight or w or "0.50"},text=d.text,type="select", visible=true, selectionType='single',
      options = d.options or arrayify({}),
      values = arrayify(d.values) or arrayify({})
    }
  end,
  multi = function(d,w)
    arrayify(d.options)
    if d.options then map(function(e) e.type='option' end,d.options) end
    return {name=d.name,style={weight=d.weight or w or "0.50"},text=d.text,type="select",visible=true, selectionType='multi',
      options = d.options or arrayify({}),
      values = arrayify(d.values) or arrayify({})
    }
  end,
  image = function(d,_)
    return {name=d.name,style={dynamic="1"},type="image", url=d.url}
  end,
  switch = function(d,w)
    d.value = d.value == nil and "false" or tostring(d.value)
    return {name=d.name,visible=true,style={weight=w or d.weight or "0.50"},text=d.text,type="switch", value=d.value}
  end,
  option = function(d,_)
    return {name=d.name, type="option", value=d.value or "Hupp"}
  end,
  slider = function(d,w)
    return {name=d.name,visible=true,step=tostring(d.step or 1),value=tostring(d.value or 0),max=tostring(d.max or 100),min=tostring(d.min or 0),style={weight=d.weight or w or "1.2"},text=d.text,type="slider"}
  end,
  label = function(d,w)
    return {name=d.name,visible=true,style={weight=d.weight or w or "1.2"},text=d.text,type="label"}
  end,
  space = function(_,w)
    return {style={weight=w or "0.50"},type="space"}
  end
}

local function typeOf(e)
  if e.button then return 'button'
  elseif e.slider then return 'slider'
  elseif e.label then return 'label'
  elseif e.select then return 'select'
  elseif e.switch then return 'switch'
  elseif e.multi then return 'multi'
  elseif e.image then return 'image'
  end
end

local function mkRow(elms,weight)
  local comp = {}
  if elms[1] then
    local c = {}
    local width = fmt("%.2f",1/#elms)
    if width:match("%.00") then width=width:match("^(%d+)") end
    for _,e in ipairs(elms) do c[#c+1]=ELMS[typeOf(e)](e,width) end
    if #elms > 1 then comp[#comp+1]={components=c,style={weight="1.2"},type='horizontal'}
    else comp[#comp+1]=c[1] end
    comp[#comp+1]=ELMS['space']({},"0.5")
  else
    comp[#comp+1]=ELMS[typeOf(elms)](elms,"1.2")
    comp[#comp+1]=ELMS['space']({},"0.5")
  end
  return {components=comp,style={weight=weight or "1.2"},type="vertical"}
end

local function mkViewLayout(UI,height,id)
  id = id or 52
  local items = {}
  for _,i in ipairs(UI) do items[#items+1]=mkRow(i) end
  return
  { ['$jason'] = {
      body = {
        header = {
          style = {height = tostring(height or #UI*50)},
          title = "quickApp_device_"..id
        },
        sections = {
          items = items
        }
      },
      head = {
        title = "quickApp_device_"..id
      }
    }
  }
end

-- Convert UI table to new uiView format
local function UI2NewUiView(UI)
  local uiView = {}
  for _,row in ipairs(UI) do
    local urow = {
      style = { weight = "1.0"},
      type = "horizontal",
    }
    row = #row==0 and {row} or row
    local weight = ({'1.0','0.5','0.25','0.33','0.20'})[#row]
    local uels = {}
    for _,el in ipairs(row) do
      local name = el.button or el.slider or el.label or el.select or el.switch or el.multi
      local typ = typeOf(el)
      local function mkBinding(name,action,fun,actionName)
        local r = {
          params = {
            actionName = 'UIAction',
            args = {action,name,'$event.value'}
          },
          type = "deviceAction"
        }
        return {r}
      end 
      local uel = {
        eventBinding = {
          onReleased = (typ=='button' or typ=='switch') and mkBinding(name,"onReleased",typ=='switch' and "$event.value" or nil,el.onReleased) or nil,
          onLongPressDown = (typ=='button' or typ=='switch') and mkBinding(name,"onLongPressDown",typ=='switch' and "$event.value" or nil,el.onLongPressDown) or nil,
          onLongPressReleased = (typ=='button' or typ=='switch') and mkBinding(name,"onLongPressReleased",typ=='switch' and "$event.value" or nil,el.onLongPressReleased) or nil,
          onToggled = (typ=='select' or typ=='multi') and mkBinding(name,"onToggled","$event.value",el.onToggled) or nil,
          onChanged = typ=='slider' and mkBinding(name,"onChanged","$event.value",el.onChanged) or nil,
        },
        max = el.max,
        min = el.min,
        step = el.step,
        name = el[typ],
        options = arrayify(el.options),
        values = arrayify(el.values) or ((typ=='select' or typ=='multi') and arrayify({})) or nil,
        value = el.value,
        style = { weight = weight},
        type = typ=='multi' and 'select' or typ,
        selectionType = (typ == 'multi' and 'multi') or (typ == 'select' and 'single') or nil,
        text = el.text,
        visible = true,
      }
      arrayify(uel.options)
      arrayify(uel.values)
      if not next(uel.eventBinding) then 
        uel.eventBinding = nil 
      end
      uels[#uels+1] = uel
    end
    urow.components = uels
    uiView[#uiView+1] = urow
  end
  return uiView
end

-- Converts UI table to uiCallbacks table
local function UI2uiCallbacks(UI)
  local cbs = {}
  traverse(UI,
  function(e)
    local typ = e.button and 'button' or e.switch and 'switch' or e.slider and 'slider' or e.select and 'select' or e.multi and 'multi'
    local name = e[typ]
    if typ=='button' or typ=='switch' then
      cbs[#cbs+1]={callback=e.onReleased or "",eventType='onReleased',name=name}
      cbs[#cbs+1]={callback=e.onLongPressDown or "",eventType='onLongPressDown',name=name}
      cbs[#cbs+1]={callback=e.onLongPressReleased or "",eventType='onLongPressReleased',name=name}
    elseif typ == 'slider' then
      cbs[#cbs+1]={callback=e.onChanged or "",eventType='onChanged',name=name}
    elseif typ == 'select' then
      cbs[#cbs+1]={callback=e.onToggled or "",eventType='onToggled',name=name}
    elseif typ == 'multi' then
      cbs[#cbs+1]={callback=e.onToggled or "",eventType='onToggled',name=name}
    end
  end)
  return cbs
end

function TQ.compileUI(UI)
  local callBacks = UI2uiCallbacks(UI)
  local uiView = UI2NewUiView(UI)
  local viewLayout = mkViewLayout(UI)
  if next(callBacks)==nil then callBacks = nil end
  if next(uiView)==nil then uiView = nil end
  return callBacks,viewLayout,uiView
end