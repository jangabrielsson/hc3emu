local E = Emulator.emulator
local fmt = string.format
local json = require("hc3emu.json")

--[[ Emulator events
{type='emulator_started'}             -- when emulator is initialized
{type='quickApp_registered',id=qaId}  -- when a quickApp is registered in emulator but not started
{type='quickApp_loaded',id=qaId}      -- when a quickApp files are loaded
{type='quickApp_initialized',id=qaId} -- before :onInit, QuickApp instance created
{type='quickApp_started',id=qaId}     -- after :onInit
{type='quickApp_finished',id=qaId}    -- no timers left
{type='scene_registered',id=sceneId}
{type='time_changed'}
{type='midnight'}
--]]

--@D image=path,name - add image file to QA, ex. --%%image=examples/myImage.png,myImage
function E._directive.image(d,val,flags) -- Register a new directive
  flags.images = flags.images or {}
  local path,name = val:match("([^,]+),([^,]+)")
  assert(path and name,"Bad image directive: "..d)
  flags.images[path] = name
end

--@D iconImage=path,name - add image file to QA, ex. --%%iconImage=examples/myImage.png,myImage
function E._directive.iconImage(d,val,flags) -- Register a new directive
  flags.iconImages = flags.iconImages or {}
  local path,name = val:match("([^,]+),([^,]+)")
  assert(path and name,"Bad image directive: "..d)
  flags.iconImages[path] = name
end

local function base64encode(data)
  local bC = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  return ((data:gsub('.', function(x)
    local r, b = '', x:byte()
    for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
    return r;
  end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if (#x < 6) then return '' end
    local c = 0
    for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
    return bC:sub(c + 1, c + 1)
  end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

local function getSize(b)
  local buf = {}
  for i = 1, 8 do buf[i] = b:byte(16 + i) end
  local width = (buf[1] << 24) + (buf[2] << 16) + (buf[3] << 8) + (buf[4] << 0)
  local height = (buf[5] << 24) + (buf[6] << 16) + (buf[7] << 8) + (buf[8] << 0);
  return width, height
end

local charMap = {
  ['\"']="%22",
  ['!']="%21",
  ['#']="%23",
  ['$']="%24",
  ['%']="%25",
  ['&']="%26",
  ['\'']="%27",
  [',']="%2C",
  -- ['<']="%3C",
  -- ['>']="%3E",
  ['=']="%3D",
  ['?']="%3F",
  ['@']="%40",
  ['\n']=""
}

local function addImages(images,files,env)
  local imcont = { "_IMAGES=_IMAGES or {};\n" }
  for fname,name in pairs(images) do
    local file = io.open(fname, "rb")
    local typ = fname:match("%.(%w+)$")
    typ = typ and typ:lower() or "png"
    assert(file, "Image not found:" .. name, name)
    local img = file:read("*all")
    local w, h = 0,0
    if typ == 'png' then w,h = getSize(img) end
    local data
    if typ == "svg" then
      data = "data:image/svg+xml;utf8," .. img:gsub(".",charMap)
    else
      data = "data:image/png;base64," .. base64encode(img)
    end
    imcont[#imcont + 1] = string.format([[
          _IMAGES['%s']={data='%s',type='%s',w=%s,h=%s}
          ]], name, data, typ, w or 0, h or 0)
    file:close()
  end
  local content = table.concat(imcont, "\n")
  local qa2, res = load(content, "images", "t", env)() -- Load QA
  table.insert(files, 1, {
    qa = qa2,
    name = "IMAGES",
    content = content,
    type = 'lua',
    isMain = false,
    isOpen = false
  })
end

local function addIconImages(images,files,env)
  local imcont = { "_ICONS=_ICONS or {};\n" }
  for fname,name in pairs(images) do
    local file = io.open(fname, "rb")
    assert(file, "Image not found:" .. name, name)
    local img = file:read("*all")
    file:close()
    local res = {}
    for i=1,#img do
      res[#res+1]=string.format("%02X",string.byte(img,i))
    end
    local iconData = table.concat(res,"")
    imcont[#imcont + 1] = string.format([[
_ICONS['%s']='%s'
]], name, iconData)
  end
  local content = table.concat(imcont, "\n")
  local qa2, res = load(content, "icons", "t", env)() -- Load QA
  table.insert(files, 1, {
    qa = qa2,
    name = "ICONS",
    content = content,
    type = 'lua',
    isMain = false,
    isOpen = false
  })
end

function E.EVENT._quickApp_registered(event) -- Add image file to QA when loaded
  local qa = E:getQA(event.id)
  if not qa then return end
  local images = qa.directives.images
  if images then addImages(images, qa.files, qa.env) end
  local iconImages = qa.directives.iconImages
  if iconImages then addIconImages(iconImages, qa.files, qa.env) end
end