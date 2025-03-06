--This QA test loading URL from forum and running it

---@diagnostic disable: duplicate-set-field
--_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=Forum loader
--%%dark=true

local url = "https://forum.fibaro.com/applications/core/interface/file/attachment.php?id=48804&key=7e81634276979bd5a0ac50612be3062e"

local function base64encode(data)
  __assert_type(data,"string")
  local bC='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  return ((data:gsub('.', function(x) 
          local r,b='',x:byte() for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
          return r;
        end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return bC:sub(c+1,c+1)
      end)..({ '', '==', '=' })[#data%3+1])
end

net.HTTPClient():request(url,{
  options = {
    method = "GET",
    headers = {
     ['Accept'] = 'application/json',
     ['Content-Type'] = 'application/json',
     ['Authorization'] = "Bearer "..base64encode("jan@gabrielsson.com:Dani0961!")
    },
    checkCertificate = true
  },
  success = function(response)
    print(response.data)
  end,
  error = function(err)
    print(err)
  end
})

