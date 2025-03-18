-- Cahecking behaviours for different types of errors


_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=APItest
--%%p roxy=TestProxy
--%%dark=true

--barf()
local function foo()
  --bar()
end

function QuickApp:onInit()
  --bar()

  --setTimeout(foo3,0)
  net.HTTPClient():request("http://www.google.com",{
    options = {
      method = "GET",
      headers = {
        ["Content-Type"] = "application/json"
      }
    },
    success = function(response)
      --foop()
      print("Success")
    end,
    error = function(err)
      print("Error",err)
    end
  })
end

