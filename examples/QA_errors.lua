-- Cahecking behaviours for different types of errors


_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=Error test
--%%dark=true

--barf()
local function foo()
  --bar()
end

function QuickApp:onInit()
  --json.decode("")
  --bar()
  assert(false,"assertion failed")
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

