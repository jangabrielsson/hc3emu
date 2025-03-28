_DEVELOP =true
if require and not QuickApp then require("hc3emu") end

--%%name=Scene trigger test
--%%type=scene
--% %offline=true
--%%debug=info:true,scene:true,post2:true,timer2:true,files2:true
--%%trigger=3:{type='user',property='execute',id=2} -- start trigger after 3s
----ENDOFDIRECTIVES----------

CONDITIONS = {
  conditions = { 
    {
      id = 3605,
      isTrigger = true,
      operator = "==",
      property = "value",
      type = "device",
      value = true
    },
  },
  operator = "all"
}

print(json.encode(sourceTrigger))

local qa = api.get("/devices/3605")
if not qa or not qa.isProxy then
  fibaro.hc3emu.tools.loadQAString([[
--%%name=QA1
--%%type=com.fibaro.binarySwitch
--%%uiPage=html/SceneQA.html
--%%proxy=SceneQAProxy

function QuickApp:onInit() end
function QuickApp:turnOn() 
  self:debug("Turn on")
  self:updateProperty("value",true)
end
function QuickApp:turnOff() 
  self:debug("Turn off")
  self:updateProperty("value",false)
end
]])
end

local prop = sourceTrigger.property
if prop == 'execute' then
  print("Execute with 3s delay")
  print("Sunrise today is "..fibaro.getValue(1,"sunriseHour"))
end

if prop == 'value' then
  print("Value is",sourceTrigger.value)
end
