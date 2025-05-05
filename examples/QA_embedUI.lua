_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=MyQA
--%%type=com.fibaro.colorController
--%%description=My description
--%%proxy=ColorEmbed
--%%webui=true
--%%debug=onAction:true,onUIEvent:true,server:true,info:true

-- Color controller type should handle actions: turnOn, turnOff, setValue, setColor
-- To update color controller state, update property color with a string in the following format: "r,g,b,w" eg. "200,10,100,255"
-- To update brightness, update property "value" with integer 0-99

api.post("/plugins/interfaces", {action='add',deviceId=3908, interfaces={"colorTemperature","ringColor"}})
function QuickApp:turnOn()
    self:debug("color controller turned on")
    self:updateProperty("value", 99)
end

function QuickApp:turnOff()
    self:debug("color controller turned off")
    self:updateProperty("value", 0)    
end

-- Value is type of integer (0-99)
function QuickApp:setValue(value)
    self:debug("color controller value set to: ", value)
    self:updateProperty("value", value)    
end

-- Color is type of table, with format [r,g,b,w]
-- Eg. relaxing forest green, would look like this: [34,139,34,150]
function QuickApp:setColor(r,g,b,w)
    local color = string.format("%d,%d,%d,%d", r or 0, g or 0, b or 0, w or 0) 
    self:debug("color controller color set to: ", color)
    self:updateProperty("color", color)
    self:setColorComponents({red=r, green=g, blue=b, warmWhite=w})
end

function QuickApp:setColorComponents(colorComponents)
    local cc = self.properties.colorComponents
    local isColorChanged = false
    for k,v in pairs(colorComponents) do
        if cc[k] and cc[k] ~= v then
            cc[k] = v
            isColorChanged = true
        end
    end
    if isColorChanged == true then
        self:updateProperty("colorComponents", cc)
        self:setColor(cc["red"], cc["green"], cc["blue"], cc["warmWhite"])
    end
end

function QuickApp:onInit()
    self:debug(self.name,self.id)
   local a,b = fibaro.hc3emu.api.hc3.post("/plugins/updateProperty",{deviceId=self.id,propertyName='value',value=100})
    local ifs = self.interfaces
    local done = 0
    for _,k in ipairs(ifs) do
        if k == 'colorTemperature' then done = done + 1 end
        if k == 'ringColor' then done = done+1 end
    end
    if done < 2 then 
      self:addInterfaces({'colorTemperature','ringColor'})
    end
    self:updateProperty("colorComponents", {red=0, green=0, blue=0, warmWhite=0})
end
