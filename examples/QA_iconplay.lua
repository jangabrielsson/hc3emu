_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=MyQA
--%%type=com.fibaro.binarySwitch
--%%plugin=$hc3emu.image
--%%iconImage=lib/BikeChargerOff.png,BikeChargerOff
--%%save=test/icon.fqa

function QuickApp:onInit()
  print("OK")
end

function QuickApp:onInit()
  self:installIcons({'lock1','lock2'},true)
end

function QuickApp:turnOn() self:updateProperty("value", true) end
function QuickApp:turnOff() self:updateProperty("value", false) end

fibaro.ICONS = {
  lock1 = [[454E44AE426082]],
  lock2 = [[89504E470D0A1A0]]
}

function QuickApp:installIconsClear() self:internalStorageRemove("iconsInstalled") end

function QuickApp:installIcons(iconNames,set,cb,timeout)
  if self:internalStorageGet("iconsInstalled") == true then  
    print("icon alread set") return
  end
  local iconSet = {}
  for _,name in ipairs(iconNames) do
    local icon,data = {},fibaro.ICONS[name]
    assert(data,"No such icon:"..name)
    _ = data:gsub("(..)",function(d) icon[#icon+1]=tonumber(d,16) end)
    iconSet[#iconSet+1] = string.char(table.unpack(icon))
  end
  local http = net.HTTPClient
  pcall(function()
    function net.HTTPClient(opts) return http({timeout=timeout or 12000}) end
    local types = self.deviceIconTypeMapping[self.type]
    assert(types,"Unsupported device type")
    assert(#types.fileNames == #iconSet,"Expecting "..(#types.fileNames).." icons") 
    local data = { files=iconSet, fileNames = types.fileNames, deviceType = self.type }
    self:uploadIconFiles(data,{},function(id)
      self:internalStorageSet("iconsInstalled", true)
      if set then print("setting iconId ",id) self:updateProperty("deviceIcon", id) end 
      if cb then cb(true,id) else print("icon installed") end end, 
      function(err) if cb then cb(false,err) else print(err) end end)
    end)
    net.HTTPClient = http
  end