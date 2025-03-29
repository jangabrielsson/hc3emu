
-- Extra UI declarations added first in QAs

local stockUIs = {
  ["com.fibaro.binarySwitch"] = {
    {{label='__binarysensorValue',text='0'}},
    {{button='__turnOn',text='Turn On',onReleased='turnOn'},{button='__turnOff',text='Turn Off',onReleased='turnOff'}}
  },
  ["com.fibaro.multilevelSwitch"] = {
    {{label='__multiswitchValue',text='0'}},
    {{button='__turnOn',text='Turn On',onReleased='turnOn'},{button='__turnOff',text='Turn Off',onReleased='turnOff'}},
    {{slider='__setValue',text='Set Value',onChanged='setValue'}}
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
local function title(f,...) return fmt("<center><font size='6' color='blue'>%s</font></center>",fmt(f,...)) end
local function dflt(val,def) if val == nil then return def else return val end end

-- Special formatter. Maps a property to UI element that should be updated when the property changes.
local stockProps  = {
  __binarysensorValue = function(qa)
    local function format(value) return title(value and "On" or "Off") end
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__binarysensorValue','text',format(value))
    end
    return format(dflt(qa.device.properties.value, 0))
  end,
  __multiswitchValue = function(qa)
    local format = function(value) return title("%.2f%%",value) end
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
    local format = function(value) return title("%.2f%%",value) end
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__multisensorValue','text',format(value))
    end
    return format(dflt(qa.device.properties.value, 0))
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
    local function format(value) return title("%.2f°",value) end
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__temperatureSensor','text',format(value))
    end
    return format(dflt(qa.device.properties.value, 0))
  end,
  __humiditySensor = function(qa)
    local function format(value) return title("%.2f%%",value) end
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__humiditySensor','text',format(value)) 
    end
    return format(dflt(qa.device.properties.value, 0))
  end,
}

return {
  stockUIs = stockUIs,
  stockProps = stockProps,
}


