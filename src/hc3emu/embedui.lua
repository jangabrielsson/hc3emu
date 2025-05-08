
-- Extra UI declarations added first in QAs
local json = require("hc3emu.json")

local embedUIs = {
  ["com.fibaro.binarySwitch"] = {
    {{label='__binarysensorValue',text='0'}},
    {{button='__turnOn',text='Turn On',onReleased='turnOn'},{button='__turnOff',text='Turn Off',onReleased='turnOff'}}
  },
  ["com.fibaro.multilevelSwitch"] = {
    {{label='__multiswitchValue',text='0'}},
    {{button='__turnOn',text='Turn On',onReleased='turnOn'},{button='__turnOff',text='Turn Off',onReleased='turnOff'}},
    {{slider='__setValue',text='Set Value',onChanged='setValue'}}
  },
  ["com.fibaro.colorController"] = {
    {{label='__colorComponentValue',text='white'}},
    {{button='__turnOn',text='Turn On',onReleased='turnOn'},{button='__turnOff',text='Turn Off',onReleased='turnOff'}},
    {{slider='__setValue',text='',onChanged='setValue'}},
    {{slider='__setColorComponentR',text='Red:',max='255',onChanged='setValue'}},
    {{slider='__setColorComponentG',text='Green:',max='255',onChanged='setValue'}},
    {{slider='__setColorComponentB',text='Blue:',max='255',onChanged='setValue'}},
    {{slider='__setColorComponentW',text='WW:',max='255',onChanged='setValue'}}

  },
  ["com.fibaro.multilevelSensor"] = {
    {{label='__multisensorValue',text='0'}},
  },
  ["com.fibaro.binarySensor"] = {
    {{label='__binarysensorValue',text='0'}},
  },
  ["com.fibaro.doorSensor"] = {
    {{label='__doorSensor',text='0'}},
  },
  ["com.fibaro.windowSensor"] = {
    {{label='__windowSensor',text='0'}},
  },
  ["com.fibaro.temperatureSensor"] = {
    {{label='__temperatureSensor',text='0'}},
  },
  ["com.fibaro.humiditySensor"] = {
    {{label='__humiditySensor',text='0'}},
  },
}

local fmt = string.format
local function title(f,...) return fmt("<center><font size='5' color='blue'>%s</font></center>",fmt(f,...)) end
local function dflt(val,def) if val == nil then return def else return val end end

-- Special formatter. Maps an UI element to a property that should be updated when the property changes.
local embedProps  = {
  __binarysensorValue = function(qa)
    local function format(value) return title(value and "On" or "Off") end
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__binarysensorValue','text',format(value))
    end
    return format(dflt(qa.device.properties.value, 0))
  end,
  __multiswitchValue = function(qa)
    local format = function(value) return title("%.2f%%",tonumber(value) or 0) end
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__setValue','value',tostring(value)) 
      qa.qa:updateView('__multiswitchValue','text',format(value))
    end
    return format(dflt(qa.device.properties.value, 0))
  end,
  __setValue = function(qa)
    return tostring(dflt(qa.device.properties.value, 0))
  end,
  __multisensorValue = function(qa)
    local format = function(value) return title("%.2f %s",tonumber(value) or 0,qa.qa.properties.unit or "") end
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__multisensorValue','text',format(value))
    end
    return format(dflt(qa.device.properties.value, 0))
  end,
  __colorComponentValue = function(qa)
    local format = function(value)
      -- local r, g, b = value.red or 0, value.green or 0, value.blue or 0
      -- local w = value.warmWhite or 0
      
      -- -- Simple white blending algorithm (approximate how white light affects perception)
      -- if w > 0 then
      --   local wFactor = w / 255
      --   r = math.min(255, r + (w * 0.9))
      --   g = math.min(255, g + (w * 0.85))
      --   b = math.min(255, b + (w * 0.8))
      -- end

      local col = fmt('style="background-color:rgb(%s, %s, %s); font-size: 16px; color: black"',value.red,value.green,value.blue)  -- corrected 'font-color' to 'color'
      local str = fmt('R:%s,G:%s,B:%s,W:%s',value.red or "",value.green or "",value.blue or "",value.warmWhite or "")
      return title(fmt('<div %s>%s</div>',col,str)) end
    qa.propWatches['colorComponents'] = function(value) 
      qa.qa:updateView('__colorComponentValue','text',format(value))
      qa.qa:updateView('__setColorComponentR','value',tostring(value.red))
      qa.qa:updateView('__setColorComponentG','value',tostring(value.green))
      qa.qa:updateView('__setColorComponentB','value',tostring(value.blue))
      qa.qa:updateView('__setColorComponentW','value',tostring(value.warmWhite))
    end
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__setValue','value',tostring(value))
    end
    return format(dflt(qa.device.properties.colorComponents, {red=0,green=0,blue=0}))
  end,
  __doorSensor = function(qa)
    local function format(value) return title(value and "Open" or "Closed") end
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__doorSensor','text',format(value))
    end
    return format(dflt(qa.device.properties.value,false))
  end,
  __windowSensor = function(qa)
    local function format(value) return title(value and "Open" or "Closed") end
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__windowSensor','text',format(value))
    end
    return format(dflt(qa.device.properties.value,false))
  end,
  __temperatureSensor = function(qa)
    local function format(value) return title("%.2f°",tonumber(value) or 0) end
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__temperatureSensor','text',format(value))
    end
    return format(dflt(qa.device.properties.value, 0))
  end,
  __humiditySensor = function(qa)
    local function format(value) return title("%.2f%%",tonumber(value) or 0) end
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__humiditySensor','text',format(value)) 
    end
    return format(dflt(qa.device.properties.value, 0))
  end,
}

-- Special hack for translating slider event from one color into a combined setColorComponents for all colors...
local function setColorComponents(qa,color,params)
  local cc = table.copy(qa.qa.properties.colorComponents)
  cc[color] = params.value
  params.id = '__setColorComponents'
  params.value = cc
end

local embedHooks = {
  __setColorComponentR = function(qa,params) setColorComponents(qa,'red', params)
  end,
  __setColorComponentG = function(qa,params) setColorComponents(qa,'green', params)
  end,
  __setColorComponentB = function(qa,params) setColorComponents(qa,'blue', params)
  end,
  __setColorComponentW = function(qa,params) setColorComponents(qa,'warmWhite', params)
  end,
}

return {
  embedUIs = embedUIs,
  embedProps = embedProps,
  embedHooks = embedHooks,
}


