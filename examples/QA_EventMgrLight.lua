_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=EventMgrTest
--%%type=com.fibaro.binarySwitch
--%%speed=48

--%%file=lib/EventMgrLight.lua,event

function QuickApp:onInit()
  self:debug(self.name,self.id)
  
  local emgr = fibaro.EventMgr()
  emgr:addHandler({type='key'},function(event)
    print("Key event: ",event.id,event.key,event.attribute)
  end)
  
  local schedule = {
    ['sunset+10'] = {name="Action 1", fun=function() print("Sunset + 10min") end},
    ['10:00'] = {name="Action 2", fun=function() print("10:00") end},
    ['12:00'] = {name="Action 3", fun=function() print("12:00") end},
    ['14:00'] = {name="Action 4", fun=function() print("14:00") end},
    ['16:00'] = {name="Action 5", fun=function() print("16:00") end},
    ['18:00'] = {name="Action 6", fun=function() print("18:00") end},
    ['20:00'] = {name="Action 7", fun=function() print("20:00") end},
    ['22:00'] = {name="Action 8", fun=function() print("22:00") end},
  }
  
  emgr:post({type='schedule',times=schedule})
  emgr:post({type='reschedule',times=schedule},"n/00:00")
  
  emgr:addHandler({type='schedule'},function(event)
    for time,vs in pairs(event.times) do
      print("Scheduling",vs.name,"for",time)
      emgr:post({type='action',fun=vs.fun,name=vs.name},"t/"..time)
    end
  end)
  
  emgr:addHandler({type='action'},function(event)
    print("Running action:",event.name)
    pcall(event.fun)
  end)

  emgr:addHandler({type='reschedule'},function(event)
    emgr:post({type='schedule',times=event.times})
    emgr:post(event,"n/00:00")
  end)
end
