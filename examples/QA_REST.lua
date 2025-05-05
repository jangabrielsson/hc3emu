_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=MyQA
--%%type=com.fibaro.binarySwitch

function QuickApp:test(a,b)
  print("test",a,'+',b,"=",a+b)
end

function QuickApp:onInit()
  setTimeout(function() self:callAPI() end,1000)
end

function QuickApp:callAPI()
  net.HTTPClient():request("https://USER:PASSW@hc3emu/api/devices/"..self.id.."/action/test?arg1=17&arg2=42",{
    options = { method = 'GET' },
    success = function(resp)
      print("Response: ", json.encode(resp))
    end,
    error = function(err)
      print("Error: ",err)
    end,
  })
end