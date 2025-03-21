_DEVELOP =true
if require and not QuickApp then require("hc3emu") end

--%%name=Scene test
--%%type=scene
--%%offline=true
--%%debug=info1:false,scene1:true,post1:true,timer1:true
--%%trigger=3:{type='user',property='execute',id=2} -- start trigger after 3s
--% %tri gger=3:{type='device',id=46,property='centralSceneEvent',value={keyAttribute = "Pressed",keyId = 2}} -- start trigger after 3s
--%%speed=78

CONDITIONS = {
  conditions = { 
    {
      id = 46,
      isTrigger = true,
      operator = "==",
      property = "centralSceneEvent",
      type = "device",
      value = {
        keyAttribute = "Pressed",
        keyId = 2
      }
    },
    -- {
    --   isTrigger = true,
    --   operator = "<=",
    --   property = "A",
    --   type = "global-variable",
    --   value = "20"
    -- },
    -- {
    --   type = "date",
    --   property = "sunrise",
    --   operator = "==",
    --   value = 120,
    --   isTrigger = true
    -- }
     {
      type = "date",
      property = "cron",
      operator = "match",
      value = {"15", "*", "*", "*", "*", "*"}, -- Every minute
      isTrigger = true
    }   
  },
  operator = "any"
}
--__emu_speed(7*24)
print(json.encode(sourceTrigger))

local prop = sourceTrigger.property
if prop == 'execute' then
  print("Execute with 3s delay")
  print("Sunrise today is "..fibaro.getValue(1,"sunriseHour"))
end
if prop == 'sunrise' then
  print("Sunrise triggered with "..sourceTrigger.value.." minutes delay")
  print("Sunrise today is "..fibaro.getValue(1,"sunriseHour"))
end

-- local a = (tonumber((fibaro.getGlobalVariable("A"))) or 0)
-- print("UPP")
-- print(a)
-- setTimeout(function() fibaro.setGlobalVariable("A",tostring(a+1)) end, 2000)