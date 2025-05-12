_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=QAAPI
--%%type=com.fibaro.genericDevice
--%%webui=true
--%%debug=info:true,server:true,refresh:true,rawrefresh:true,http:true

--%%u={{button='b1',text='Create GV',onReleased='createGV'},{button='b2',text='Update GV',onReleased='updateGV'},{button='b3',text='Del GV',onReleased='delGV'}}
--%%u={{button='b12',text='Create GV L',onReleased='createGV_local'},{button='b22',text='Update GV L',onReleased='updateGV_local'},{button='b32',text='Del GV L',onReleased='delGV_local'}}

--%%u={{button='r1',text='Create Room',onReleased='createRoom'},{button='r2',text='Update Room',onReleased='updateRoom'},{button='r3',text='Del Room',onReleased='delRoom'}}
--%%u={{button='r12',text='Create Room L',onReleased='createRoom_local'},{button='r22',text='Update Rom L',onReleased='updateRoom_local'},{button='r32',text='Del Room L',onReleased='delRoom_local'}}

--%%u={{button='s1',text='Create Section',onReleased='createSection'},{button='s2',text='Update Section',onReleased='updateSection'},{button='s3',text='Del Section',onReleased='delSection'}}
--%%u={{button='s12',text='Create Section L',onReleased='createSection_local'},{button='s22',text='Update Section L',onReleased='updateSection_local'},{button='s32',text='Del Section L',onReleased='delSection_local'}}

--%%u={{button='q1',text='Create QA',onReleased='createQA'},{button='q2',text='Update QA',onReleased='updateQA'},{button='q3',text='Upd. QAP',onReleased='updateQAProp'},{button='q4',text='Del QA',onReleased='delQA'}}
--%%u={{button='q12',text='Create QA L',onReleased='createQA_local'},{button='q22',text='Update QA L',onReleased='updateQA_local'},{button='q32',text='Upd, QAP L',onReleased='updateQAProp_local'},{button='q42',text='Del QA L',onReleased='delQA_local'}}


local fapi = api

local function printj(...)
  local args,res = {...},{}
  for i=1,#args do res[i] = type(args[i]) == 'table' and json.encode(args[i]) or tostring(args[i]) end
  print(table.concat(res," "))
end

function QuickApp:createGV() printj("CreateGV",api.hc3.post('/globalVariables',{name="testGV",value=os.date("%c")})) end
function QuickApp:updateGV() printj("ModGV",api.hc3.put('/globalVariables/testGV',{value=os.date("%c")})) end
function QuickApp:delGV() printj("DelGV",api.hc3.delete('/globalVariables/testGV',{})) end

function QuickApp:createGV_local() printj("CreateGV",fapi.post('/globalVariables',{name="testGV",value=os.date("%c")})) end
function QuickApp:updateGV_local() printj("ModGV",fapi.put('/globalVariables/testGV',{value=os.date("%c")})) end
function QuickApp:delGV_local() printj("DelGV",fapi.delete('/globalVariables/testGV',{})) end

local room = {}
local function GR(res,code) if code == 200 or code == 201 then room = res end return res,code end
function QuickApp:createRoom() printj("CreateRoom",GR(api.hc3.post('/rooms',{name='testRoom', sectionID = 219, icon = "unsigned", category='other'}))) end
function QuickApp:updateRoom() printj("ModRoom",api.hc3.put('/rooms/'..room.id,{name='testRoom'})) end
function QuickApp:delRoom() printj("DelRoom",api.hc3.delete('/rooms/'..room.id,{})) end

function QuickApp:createRoom_local() printj("CreateRoom",GR(fapi.post('/rooms',{name='testRoom', sectionID = 219, icon = "unsigned", category='other'}))) end
function QuickApp:updateRoom_local() printj("ModRoom",fapi.put('/rooms/'..room.id,{name='testRoom'})) end
function QuickApp:delRoom_local() printj("DelRoom",fapi.delete('/rooms/'..room.id,{})) end

local sections = {}
local function GS(res,code) if code == 200 or code == 201 then sections = res end return res,code end
function QuickApp:createSection() printj("CreateSection",GS(api.hc3.post('/sections',{name='testSection', icon = "unsigned"}))) end
function QuickApp:updateSection() printj("ModSection",api.hc3.put('/sections/'..sections.id,{name='testSection'})) end
function QuickApp:delSection() printj("DelSection",api.hc3.delete('/sections/'..sections.id,{})) end

function QuickApp:createSection_local() printj("CreateSection",GS(fapi.post('/sections',{name='testSection', icon = "unsigned"}))) end
function QuickApp:updateSection_local() printj("ModSection",fapi.put('/sections/'..sections.id,{name='testSection'})) end
function QuickApp:delSection_local() printj("DelSection",fapi.delete('/sections/'..sections.id,{})) end

local qa = {}
local fqa = {
  name = "TestQA",
  type = "com.fibaro.multilevelSensor",
  apiVersion = "1.3",
  files = {
    {name="main", isMain=true, isOpen=false, type='lua', content="function QuickApp:onInit() print('Hello from',self.id) end"},
  }
}
local counter = 0
local function GQ(res,code) if code < 206 then qa = res end return res,code end
function QuickApp:createQA() printj("CreateQA",GQ(api.hc3.post('/quickApp',fqa))) end
function QuickApp:updateQA() counter=counter+1 printj("ModQA",api.hc3.put('/devices/'..qa.id,{name='name'..counter})) end
function QuickApp:updateQAProp() counter=counter+1 printj("ModQAP",api.hc3.post('/plugins/updateProperty',{
  deviceId=qa.id,propertyName='value', value=counter
})) end
function QuickApp:delQA() printj("DelQA",api.hc3.delete('/devices/'..qa.id,{})) end

function QuickApp:createQA_local() printj("CreateQA L",GQ(api.post('/quickApp',fqa))) end
function QuickApp:updateQA_local() counter=counter+1 printj("ModQA L",api.put('/devices/'..qa.id,{name='name'..counter})) end
function QuickApp:updateQAProp_local() counter=counter+1 printj("ModQAP L",api.post('/plugins/updateProperty',{
  deviceId=qa.id,propertyName='value', value=counter
})) end
function QuickApp:delQA_local() printj("DelQA L",api.delete('/devices/'..qa.id,{})) end

function QuickApp:onInit()
  local a = api.get('/panels/location')
  printj("Location",a)
  -- setTimeout(function() 
  --   api.put("/weather",{Wind=13})
  -- end, 1000)
  -- api.hc3.delete('/panels/location/227', {
  --   -- name = "My Home2",
  --   -- address = "Serdeczna 3, Wysogotowo",
  --   -- longitude = 16.791597,
  --   -- latitude = 52.404958,
  --   -- radius = 150
  -- })
end