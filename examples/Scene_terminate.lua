_DEVELOP =true
if require and not QuickApp then require("hc3emu") end

--%%name=Scene test
--%%type=scene
--%%debug=info:true
--%%trigger=3:{type='user',property='execute',id=2} -- start trigger after 3s

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
    } 
  },
  operator = "any"
}

print(json.encode(sourceTrigger))
local ref
local n = 0
ref = setInterval(function() 
  n=n+1  
  print("Hello!") 
  if n == 3 then clearTimeout(ref) end
  end,3000)