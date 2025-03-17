_DEVELOP =true
if require and not QuickApp then require("hc3emu") end

--%%name=Scene call
--%%type=scene
--% %offline=true
--%%debug=info:true,scene:true,post:true

CONDITIONS = {
  conditions = { 
    {
      isTrigger = true,
      operator = "<=",
      property = "A",
      type = "global-variable",
      value = "20"
    },
  },
  operator = "any"
}

print(json.encode(sourceTrigger))

print("Scene being called")
print("Calling QA 5001")
fibaro.call(5001,"foo",4,6)