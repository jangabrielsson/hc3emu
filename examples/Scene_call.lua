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

local callingQA = fibaro.getSceneVariable('QA')
print("Scene being called")
print("Calling QA",callingQA)
fibaro.call(callingQA,"foo",4,6)
