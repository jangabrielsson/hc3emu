_DEVELOP=true
if require and not QuickApp then require('hc3emu') end

--%%name=MyQA
--%%type=com.fibaro.binarySwitch

print("Starting API tests...")

-- Function to test API call and print result
local function testAPI(method, endpoint, payload, expectedCode)
    local res, code
    if method == "get" then
        res, code = api.get(endpoint)
    elseif method == "post" then
        res, code = api.post(endpoint, payload)
    elseif method == "put" then
        res, code = api.put(endpoint, payload)
    elseif method == "delete" then
        res, code = api.delete(endpoint)
    end
    
    local maxCode = expectedCode or 206
    local success = code <= maxCode
    print(string.format("[%s] %s %s: %s (Code: %s)", 
        success and "PASS" or "FAIL", 
        method:upper(), 
        endpoint, 
        success and "Success" or "Failed", 
        code or "nil"))
    
    return res, code, success
end

print("\n----- Testing Alarms API -----")
-- Alarms API tests
testAPI("get", "/alarms/v1/devices/")
testAPI("get", "/alarms/v1/partitions/")
testAPI("get", "/alarms/v1/history/")

print("\n----- Testing Devices API -----")
-- Devices API tests
testAPI("get", "/devices")
testAPI("get", "/devices/hierarchy")
testAPI("get", "/uiDeviceInfo")
-- Get a specific device (assumes device ID 1 exists)
testAPI("get", "/devices/1")
-- Get devices by room
testAPI("get", "/devices?roomID=219")
-- Get devices by interface
testAPI("get", "/devices?interface=light")
-- Get devices by type
testAPI("get", "/devices?type=com.fibaro.binarySwitch")
-- Call action on a device (this is just a test example)
testAPI("post", "/devices/1/action/turnOn", {args = {}})
-- Call more complex action on a device
testAPI("post", "/devices/1/action/setValue", {args = {50}})
-- Add polling interface
--testAPI("put", "/devices/1/interfaces/polling")
-- Delete polling interface
--testAPI("delete", "/devices/1/interfaces/polling")
-- Filter devices request
testAPI("post", "/devices/filter", {filters = {{filter = "interfaces", value = {"alarm"}}}})
-- Add interface to devices
--testAPI("post", "/devices/addInterface", {devicesId = {1, 2}, interfaces = {"light"}})
-- Delete interface from devices
--testAPI("post", "/devices/deleteInterface", {devicesId = {1, 2}, interfaces = {"light"}})
-- Call group action
testAPI("post", "/devices/groupAction/turnOn", {filters = {{filter = "interfaces", value = {"light"}}}})

print("\n----- Testing Rooms API -----")
-- Rooms API tests
testAPI("get", "/rooms")
-- Get a specific room (assumes room ID 1 exists)
testAPI("get", "/rooms/219")
-- Create new room
local room = testAPI("post", "/rooms", {name = "Test Room", sectionID = 219, icon = "unsigned", category='other'})
-- Modify room
if room then
  testAPI("put", "/rooms/"..room.id, {name = "Modified Room"})
-- Delete room
  testAPI("delete", "/rooms/"..room.id) -- Be careful with this one!
end

print("\n----- Testing Sections API -----")
-- Sections API tests
testAPI("get", "/sections")
-- Get a specific section (assumes section ID 1 exists)
testAPI("get", "/sections/219")
-- Create new section
local sect = testAPI("post", "/sections", {name = "Test Section", icon = "unsigned"})
-- Modify section
if sect then
  testAPI("put", "/sections/"..sect.id, {name = "Modified Section"})
  -- Delete section
  testAPI("delete", "/sections/"..sect.id) -- Be careful with this one!
end
print("\n----- Testing Weather API -----")
-- Weather API tests
testAPI("get", "/weather")

print("\n----- Testing Energy API -----")
-- Energy API tests
testAPI("get", "/energy/devices")
testAPI("get", "/energy/consumption/summary?period=Yearly")
testAPI("get", "/energy/consumption/metrics")
testAPI("get", "/energy/consumption/detail?period=2019-07")
testAPI("get", "/energy/consumption/room/219/detail")

print("\n----- Testing Scenes API -----")
-- Scenes API tests
local scenes = testAPI("get", "/scenes")
-- Get a specific scene (assumes scene ID 1 exists)
testAPI("get", "/scenes/"..scenes[1].id)
-- Call scene action
--testAPI("post", "/scenes/"..scenes[1].id.."/action/start", {})
-- Call scene action with arguments
--testAPI("post", "/scenes/1/action/start", {args = {"test"}})
-- Call scene action with delay
--testAPI("post", "/scenes/1/action/start", {delay = 10})
-- Get scene conditions
--testAPI("get", "/scenes/1/conditions")
-- Create new scene
-- testAPI("post", "/scenes", {name = "Test Scene", type = "lua", mode = "automatic"})

print("\n----- Testing Users API -----")
-- Users API tests
local users = testAPI("get", "/users")
-- Get a specific user (assumes user ID 1 exists)
testAPI("get", "/users/"..users[1].id)
-- Modify user
-- testAPI("put", "/users/1", {name = "Modified User"})

print("\n----- Testing Variables API -----")
-- Global Variables API tests
testAPI("get", "/globalVariables")
-- Get specific variable
testAPI("get", "/globalVariables/test",nil,404)
-- Create or modify variable
testAPI("put", "/globalVariables/test", {value = "test value"},404)
-- Create new variable
testAPI("post", "/globalVariables", {name = "test_var", value = "new value"})
-- Delete variable
testAPI("delete", "/globalVariables/test_var")

print("\n----- Testing Settings API -----")
-- Settings API tests
testAPI("get", "/settings/info")
testAPI("get", "/settings/location")
testAPI("get", "/settings/network")
testAPI("get", "/settings/led")

print("\n----- Testing Home API -----")
-- Home API test
testAPI("get", "/home")

print("\n----- Testing System Status API -----")
-- System Status API test
testAPI("get", "/service/systemStatus?lang=en&_=32453245")

print("\n----- Testing Icons API -----")
-- Icons API test
testAPI("get", "/icons")

print("\n----- Testing Login Status API -----")
-- Login Status API test
testAPI("get", "/loginStatus")

print("\n----- Testing Notifications API -----")
-- Notifications API tests
testAPI("get", "/notificationCenter")
--testAPI("get", "/notificationCenter/markAsRead/all")

print("\n----- Testing Plugins API -----")
-- Plugins API tests
local qa = api.get("/devices?interface=quickApp")
testAPI("get", "/plugins")
-- Get plugin variables
testAPI("get", "/plugins/"..qa[1].id.."/variables")
-- Get specific plugin variable
testAPI("get", "/plugins/"..qa[1].id.."/variables/test", nil, 404)
-- Update plugin property
--testAPI("post", "/plugins/updateProperty", {deviceId = 1, propertyName = "value", value = true})

print("\n----- Testing QuickApp API -----")
-- Get QuickApp files
testAPI("get", "/quickApp/"..qa[1].id.."/files")
-- Get specific QuickApp file
testAPI("get", "/quickApp/"..qa[1].id.."/files/main")

print("\n----- Testing Profiles API -----")
-- Profiles API tests
testAPI("get", "/profiles")
-- Get specific profile
testAPI("get", "/profiles/1")

print("\n----- Testing Consumption API -----")
-- Consumption API test
--testAPI("get", "/consumption")

print("\n----- Testing Categories API -----")
-- Categories API test
testAPI("get", "/categories")

print("\n----- Testing Debug Messages API -----")
-- Debug Messages API test
testAPI("get", "/debugMessages")

print("\n----- Testing Favorite Colors API -----")
-- Favorite Colors API tests
testAPI("get", "/panels/favoriteColors")
testAPI("get", "/panels/favoriteColors/v2")

print("\n----- Testing iOS Devices API -----")
-- iOS Devices API test
testAPI("get", "/iosDevices")

print("\n----- Testing Linked Devices API -----")
-- Linked Devices API test
testAPI("get", "/linkedDevices/v1/devices")

print("\n----- Testing Limits API -----")
-- Limits API test
local limits = testAPI("get", "/limits")

print("\n----- Testing Sprinkler API -----")
-- Sprinkler API tests
local a = testAPI("get", "/panels/sprinklers/v1/state")
testAPI("get", "/panels/sprinklers/v1/devices")
testAPI("get", "/panels/sprinklers/v1/programs")
testAPI("get", "/panels/sprinklers/v1/zones")
testAPI("get", "/panels/sprinklers/v1/schedules")
testAPI("get", "/panels/sprinklers/v1/history")
-- Create a schedule (post example)
-- testAPI("post", "/panels/sprinklers/v1/schedules", {
--   name = "Test Schedule",
--   active = true,
--   zones = {1, 2},
--   startTime = "19:00:00",
--   durationInMinutes = 30,
--   weekDays = {1, 3, 5}
-- })
-- -- Start/stop manual watering
-- testAPI("post", "/panels/sprinklers/v1/manual/start", {
--   zones = {1},
--   durationInMinutes = 5
-- })
testAPI("post", "/panels/sprinklers/v1/manual/stop", {})
-- Get water usage statistics
testAPI("get", "/panels/sprinklers/v1/statistics/water-usage")

-- print("\n----- Testing Humidity API -----")
-- -- Humidity API tests
-- local hum = testAPI("get", "/panels/humidity")

-- testAPI("get", "/panels/humidity/current")

print("\n----- Testing Climate API -----")
-- Climate API tests
testAPI("get", "/climate/v1/installations")
testAPI("get", "/climate/v1/devices")
testAPI("get", "/climate/v1/zones")
testAPI("get", "/climate/v1/thermostats")
testAPI("get", "/climate/v1/schedule")
testAPI("get", "/climate/v1/history?deviceId=1&period=week")
testAPI("get", "/climate/v1/settings")
testAPI("get", "/climate/v1/statistics/energy")
testAPI("get", "/climate/v1/statistics/temperature")
-- Set climate mode for zone
testAPI("post", "/climate/v1/zones/1/mode", {
  mode = "heat", -- heat, cool, auto, off
  setpoint = 21.5
})
-- Set climate schedule
testAPI("post", "/climate/v1/zones/1/schedule", {
  name = "Workday Schedule",
  active = true,
  periods = {
    { 
      startTime = "06:30:00", 
      temperature = 21.0, 
      mode = "heat" 
    },
    { 
      startTime = "22:00:00", 
      temperature = 18.0, 
      mode = "heat" 
    }
  },
  weekDays = {1, 2, 3, 4, 5}
})
-- Set vacation mode
testAPI("post", "/climate/v1/vacation", {
  enabled = true,
  startDate = "2025-05-20",
  endDate = "2025-05-27",
  temperature = 16.5,
  mode = "heat"
})

print("\n----- Testing Panel Service API -----")
-- Panel Service API test
--testAPI("get", "/panelService")

print("\n----- Testing User Activity API -----")
-- User Activity API test
testAPI("get", "/userActivity")

print("\n----- Testing VoIP API -----")
-- VoIP API test
--testAPI("get", "/voip")

print("\n----- Testing Additional Interfaces API -----")
-- Additional Interfaces API test
testAPI("get", "/additionalInterfaces")

print("\n----- Testing Fibaro FTI API -----")
-- Fibaro FTI API test
testAPI("get", "/fti")

print("\n----- Testing Gateway Connection API -----")
-- Gateway Connection API test
--testAPI("get", "/gatewayConnection")

print("\n----- Testing Network Discovery API -----")
-- Network Discovery API test
testAPI("post", "/networkDiscovery/arp",{})

print("\n----- Testing RGB Programs API -----")
-- RGB Programs API test
testAPI("get", "/RGBPrograms")

print("\n----- Testing ZWave API -----")
-- ZWave API tests
testAPI("get", "/zwaveSettings")

print("\nAPI tests completed")

