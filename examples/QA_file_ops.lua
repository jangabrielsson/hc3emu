--This is a QA testing the /quickApp/ api
_DEVELOP = true
if require and not QuickApp then require("hc3emu") end

--%%name=Files
--%%type=com.fibaro.multilevelSwitch
--%%dark=true
--%%offline=true
--%%debug=sdk:false,info:true,server:true,onAction:true,onUIEvent:true
--%%debug=blockAPI:true


function QuickApp:onInit()
  self:debug(self.name,self.id)
  local done = false
  local files = api.get("/quickApp/"..self.id.."/files")
  for _,f in ipairs(files) do
    if f.name=='newFile' then done=true end
  end

  if done then return end -- Already added ou file

  local newCode = [[
     print("Hello from the new file")
  ]]
  local newFile = {
    name = "newFile",
    type = "lua",
    isOpen = false,
    isMain = false,
    content = newCode
  }

  api.post("/quickApp/"..self.id.."/files",newFile)
end