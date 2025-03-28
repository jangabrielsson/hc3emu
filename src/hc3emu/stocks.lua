local stockUIs = {
  ["com.fibaro.binarySwitch"] = {
    {{label='__binarysensorValue',text='0'}},
    {{button='__turnOn',text='Turn On',onReleased='turnOn'},{button='__turnOff',text='Turn Off',onReleased='turnOff'}}
  },
  ["com.fibaro.multilevelSwitch"] = {
    {{label='__multisensorValue',text='0'}},
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

local stockProps  = {
  __setValue = function(qa)
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__setValue','value',tostring(value)) 
      qa.qa:updateView('__multisensorValue','text',title("%.2f%%",value))
    end
    return qa.device.properties.value,qa.propWatches['value']
  end,
  __binarysensorValue = function(qa)
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__binarysensorValue','text',title(value and "On" or "Off"))
    end
    return qa.device.properties.value,qa.propWatches['value']
  end,
  __multisensorValue = function(qa)
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__multisensorValue','text',title("%.2f%%",value))
    end
    return qa.device.properties.value,qa.propWatches['value']
  end,
  __doorSensor = function(qa)
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__doorSensor','text',title(value and "Closed" or "Open"))
    end
    return qa.device.properties.value,qa.propWatches['value']
  end,
  __windowSensor = function(qa)
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__windowSensor','text',title(value and "Closed" or "Open"))
    end
    return qa.device.properties.value,qa.propWatches['value']
  end,
  __temperatureSensor = function(qa)
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__temperatureSensor','text',title("%.2f°",value))
    end
    return qa.device.properties.value,qa.propWatches['value']
  end,
  __humiditySensor = function(qa)
    qa.propWatches['value'] = function(value) 
      qa.qa:updateView('__humiditySensor','text',title("%.2f°",value)) 
    end
    return qa.device.properties.value,qa.propWatches['value']
  end,
}

return {
  stockUIs = stockUIs,
  stockProps = stockProps,
}


