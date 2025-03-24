if require and not QuickApp then require('hc3emu') end

--%%name=Notifier
--%%type=com.fibaro.binarySwitch
--%%proxy=NotifyProxy

do
  local refs = {}
  function QuickApp.INTERACTIVE_OK_BUTTON(_,ref)
    ref,refs[ref]=refs[ref],nil
    if ref then ref(true) end
  end

  function QuickApp:pushYesNo(mobileId,title,message,callback,timeout)
    local ref = tostring({}):match("%s(.*)")
    local res,err = api.post("/mobile/push", 
      {
        category = "YES_NO", 
        title = title, 
        message = message, 
        service = "Device", 
        data = {
          actionName = "INTERACTIVE_OK_BUTTON", 
          deviceId = self.id, 
          args = {ref}
        }, 
        action = "RunAction", 
        mobileDevices = { mobileId }, 
      })
    timeout = timeout or (20)
    local timer = setTimeout(function()
        local r
        r,refs[ref] = refs[ref],nil
        if r then r(false) end 
      end, 
      timeout*1000)
    refs[ref]=function(val) clearTimeout(timer) callback(val) end
  end
end

function QuickApp:onInit()
  self:debug("onInit",self.name,self.id)
  self:pushYesNo(923,"Test","Do you want to turn on the light?",function(val)
    if val then fibaro.call(self.id,"turnOn") end
  end)
end