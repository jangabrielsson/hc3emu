local exports = {}
Emulator = Emulator
local E = Emulator.emulator
local json = require("hc3emu.json")
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

local function nameOf(e)
  local t = typeOf(e)
  return e[t]
end

local ELMS = {
  button = function(d,w)
    return {name=nameOf(d),visible=true,style={weight=d.weight or w or "0.50"},text=d.text,type="button"}
  end,
  select = function(d,w)
    arrayify(d.options)
    if d.options then map(function(e) e.type='option' end,d.options) end
    return {name=nameOf(d),style={weight=d.weight or w or "0.50"},text=d.text,type="select", visible=true, selectionType='single',
      options = d.options or arrayify({}),
      values = arrayify(d.values) or arrayify({})
    }
  end,
  multi = function(d,w)
    arrayify(d.options)
    if d.options then map(function(e) e.type='option' end,d.options) end
    return {name=nameOf(d),style={weight=d.weight or w or "0.50"},text=d.text,type="select",visible=true, selectionType='multi',
      options = d.options or arrayify({}),
      values = arrayify(d.values) or arrayify({})
    }
  end,
  image = function(d,_)
    return {name=nameOf(d),style={dynamic="1"},type="image", url=d.url}
  end,
  switch = function(d,w)
    d.value = d.value == nil and "false" or tostring(d.value)
    return {name=nameOf(d),visible=true,style={weight=w or d.weight or "0.50"},text=d.text,type="switch", value=d.value}
  end,
  option = function(d,_)
    return {name=nameOf(d), type="option", value=d.value or "Hupp"}
  end,
  slider = function(d,w)
    return {name=nameOf(d),visible=true,step=tostring(d.step or 1),value=tostring(d.value or 0),max=tostring(d.max or 100),min=tostring(d.min or 0),style={weight=d.weight or w or "1.2"},text=d.text,type="slider"}
  end,
  label = function(d,w)
    return {name=nameOf(d),visible=true,style={weight=d.weight or w or "1.2"},text=d.text,type="label"}
  end,
  space = function(_,w)
    return {style={weight=w or "0.50"},type="space"}
  end
}

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
            args = {action,name,fun~=nil and fun or nil} --'$event.value'}
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
        value = el.value or (typ=='switch' and "false") or nil,
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

local function compileUI(UI)
  local callBacks = UI2uiCallbacks(UI)
  local uiView = UI2NewUiView(UI)
  local viewLayout = mkViewLayout(UI)
  if next(callBacks)==nil then callBacks = nil end
  if next(uiView)==nil then uiView = nil end
  return callBacks,viewLayout,uiView
end

local sortKeys = {
  "button", "slider", "label","select","switch","multi",
  "text",
  "min", "max", "value",
  "visible",
  "onRelease", "onChanged",
}
local sortOrder = {}
for i, s in ipairs(sortKeys) do sortOrder[s] = "\n" .. string.char(i + 64) .. " " .. s end
local function keyCompare(a, b)
  local av, bv = sortOrder[a] or a, sortOrder[b] or b
  return av < bv
end

local function toLua(t)
  if type(t) == 'table' then
    if t[1] or next(t)==nil then
      local res = {}
      for _, v in ipairs(t) do
        res[#res + 1] = toLua(v)
      end
      return "{" .. table.concat(res, ",") .. "}"
    else
      local res, keys = {}, {}
      for k, _ in pairs(t) do keys[#keys + 1] = k end
      table.sort(keys, keyCompare)
      for _, k in ipairs(keys) do
        local tk = type(t[k]) == 'table' and toLua(t[k]) 
        or (type(t[k]) == 'boolean' or type(t[k])=='number') and tostring(t[k])
        or '"'..t[k]..'"'
        res[#res + 1] = string.format('%s=%s', k, tk)
      end
      return "{" .. table.concat(res, ",") .. "}"
    end
  else
    if type(t) == 'string' then return '"' .. t .. '"' 
    else return tostring(t) end
  end
end

local function dumpUI(UI,pr)
  local lines = {}
  for _, row in ipairs(UI or {}) do
    for _,l in ipairs(row) do l.type=nil end
    if row[1] and not row[2] then row = row[1] end
    lines[#lines+1]="--%%u="..toLua(row)
  end
  (pr or print)("Proxy UI:\n"..table.concat(lines,"\n"))
end


local function collectViewLayoutRow(u,map)
  local row = {}
  local function empty(a) return a~="" and a or "" end
  local function conv(u)
    if type(u) == 'table' then
      local typ = u.type
      local name = u.name
      if name then
        if typ=='label' then
          row[#row+1]={label=name, text=u.text}
        elseif typ=='button' then
          local e ={[typ]=name, text=u.text, value=u.value, visible=u.visible==nil and true or u.visible}
          e.onReleased = empty((map[name] or {}).onReleased)
          e.onLongPressDown = empty((map[name] or {}).onLongPressDown)
          e.onLongPressReleased = empty((map[name] or {}).onLongPressReleased)
          row[#row+1]=e
        elseif typ=='switch' then
          local e ={[typ]=name, text=u.text, value=u.value, visible=u.visible==nil and true or u.visible}
          e.onReleased = empty((map[name] or {}).onReleased)
          e.onLongPressDown = empty((map[name] or {}).onLongPressDown)
          e.onLongPressReleased = empty((map[name] or {}).onLongPressReleased)
          row[#row+1]=e
        elseif typ=='slider' then
          row[#row+1]={
            slider=name, 
            text=u.text, 
            onChanged=(map[name] or {}).onChanged,
            max = u.max,
            min = u.min,
            step = u.step,
            visible = u.visible==nil and true or u.visible,
          }
        elseif typ=='select' then
          row[#row+1]={
            [u.selectionType=='multi' and 'multi' or 'select']=name, 
            text=u.text, 
            options=arrayify(u.options),
            visible = u.visible==nil and true or u.visible,
            onToggled=(map[name] or {}).onToggled,
          }
        else
          print("Unknown type",json.encode(u))
        end
      else
        for _,v in pairs(u) do conv(v) end
      end
    end
  end
  conv(u)
  return row
end

local function viewLayout2UIAux(u,map)
  local function conv(u)
    local rows = {}
    for _,j in pairs(u.items) do
      local row = collectViewLayoutRow(j.components,map)
      if #row > 0 then
        if #row == 1 then row=row[1] end
        rows[#rows+1]=row
      end
    end
    return rows
  end
  return conv(u['$jason'].body.sections)
end

local function viewLayout2UI(view,callbacks)
  local map = {}
  for _,c in ipairs(callbacks) do
    map[c.name]=map[c.name] or {}
    map[c.name][c.eventType]=c.callback
  end
  local UI = viewLayout2UIAux(view,map)
  return UI
end

local function logUI(id,pr)
  local qa = E:apiget("/devices/"..id)
  local UI = viewLayout2UI(qa.properties.viewLayout,qa.properties.uiCallbacks or {})
  dumpUI(UI,pr)
end

exports.logUI = logUI
exports.viewLayout2UI = viewLayout2UI
exports.dumpUI = dumpUI
exports.compileUI = compileUI

return exports