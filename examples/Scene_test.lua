_DEVELOP =true
if require and not QuickApp then require("hc3emu") end

--%%name=Scene test
--%%type=scene
--%%debug=info:true,scene:true
--%%trigger=3:{type='user',property='execute',id=2} -- start trigger after 3s
--% %trigger=3:{type='device',id=46,property='centralSceneEvent',value={keyAttribute = "Pressed",keyId = 2}} -- start trigger after 3s
--%%speed=24

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
    {
      isTrigger = true,
      operator = "<=",
      property = "A",
      type = "global-variable",
      value = "20"
    },
    {
      type = "date",
      property = "sunrise",
      operator = "==",
      value = 120,
      isTrigger = true
    }
  },
  operator = "any"
}
--__emu_speed(7*24)
print(json.encode(sourceTrigger))
print("OK",os.time())
-- local a = (tonumber((fibaro.getGlobalVariable("A"))) or 0)
-- print("UPP")
-- print(a)
-- setTimeout(function() fibaro.setGlobalVariable("A",tostring(a+1)) end, 2000)