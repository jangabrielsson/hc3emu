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
    local success = code < maxCode
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
local room = testAPI("post", "/rooms", {name = "Test Room", sectionID = 219, icon = "room"})
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
testAPI("get", "/sections/1")
-- Create new section
testAPI("post", "/sections", {name = "Test Section", icon = "section"})
-- Modify section
testAPI("put", "/sections/1", {name = "Modified Section"})
-- Delete section
-- testAPI("delete", "/sections/1") -- Be careful with this one!

print("\n----- Testing Weather API -----")
-- Weather API tests
testAPI("get", "/weather")

print("\n----- Testing Energy API -----")
-- Energy API tests
testAPI("get", "/energy/devices")
testAPI("get", "/energy/consumption/summary?period=Yearly")
testAPI("get", "/energy/consumption/metrics")
testAPI("get", "/energy/consumption/detail")
testAPI("get", "/energy/consumption/room/219/detail")

print("\n----- Testing Scenes API -----")
-- Scenes API tests
testAPI("get", "/scenes")
-- Get a specific scene (assumes scene ID 1 exists)
testAPI("get", "/scenes/1")
-- Call scene action
testAPI("post", "/scenes/1/action/start", {})
-- Call scene action with arguments
testAPI("post", "/scenes/1/action/start", {args = {"test"}})
-- Call scene action with delay
testAPI("post", "/scenes/1/action/start", {delay = 10})
-- Get scene conditions
testAPI("get", "/scenes/1/conditions")
-- Create new scene
-- testAPI("post", "/scenes", {name = "Test Scene", type = "lua", mode = "automatic"})

print("\n----- Testing Users API -----")
-- Users API tests
testAPI("get", "/users")
-- Get a specific user (assumes user ID 1 exists)
testAPI("get", "/users/1")
-- Modify user
-- testAPI("put", "/users/1", {name = "Modified User"})

print("\n----- Testing Variables API -----")
-- Global Variables API tests
testAPI("get", "/globalVariables")
-- Get specific variable
testAPI("get", "/globalVariables/test")
-- Create or modify variable
testAPI("put", "/globalVariables/test", {value = "test value"})
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
testAPI("get", "/settings/general")
testAPI("get", "/settings/backup")
testAPI("get", "/settings/diagnose")

print("\n----- Testing Home API -----")
-- Home API test
testAPI("get", "/home")

print("\n----- Testing System Status API -----")
-- System Status API test
testAPI("get", "/systemStatus")

print("\n----- Testing Icons API -----")
-- Icons API test
testAPI("get", "/icons")

print("\n----- Testing Login Status API -----")
-- Login Status API test
testAPI("get", "/loginStatus")

print("\n----- Testing Notifications API -----")
-- Notifications API tests
testAPI("get", "/notificationCenter")
testAPI("get", "/notificationCenter/markAsRead/all")

print("\n----- Testing Plugins API -----")
-- Plugins API tests
testAPI("get", "/plugins")
-- Get plugin variables
testAPI("get", "/plugins/1/variables")
-- Get specific plugin variable
testAPI("get", "/plugins/1/variables/test")
-- Update plugin property
testAPI("post", "/plugins/updateProperty", {deviceId = 1, propertyName = "value", value = true})

print("\n----- Testing QuickApp API -----")
-- QuickApp API tests
testAPI("get", "/quickApp/devices")
-- Get QuickApp files
testAPI("get", "/quickApp/1/files")
-- Get specific QuickApp file
testAPI("get", "/quickApp/1/files/main")

print("\n----- Testing Profiles API -----")
-- Profiles API tests
testAPI("get", "/profiles")
-- Get specific profile
testAPI("get", "/profiles/1")

print("\n----- Testing Consumption API -----")
-- Consumption API test
testAPI("get", "/consumption")

print("\n----- Testing Categories API -----")
-- Categories API test
testAPI("get", "/categories")

print("\n----- Testing Debug Messages API -----")
-- Debug Messages API test
testAPI("get", "/debugMessages")

print("\n----- Testing Favorite Colors API -----")
-- Favorite Colors API tests
testAPI("get", "/favoriteColors")
testAPI("get", "/favoriteColorsV2")

print("\n----- Testing iOS Devices API -----")
-- iOS Devices API test
testAPI("get", "/iosDevices")

print("\n----- Testing Linked Devices API -----")
-- Linked Devices API test
testAPI("get", "/linkedDevices")

print("\n----- Testing Limits API -----")
-- Limits API test
testAPI("get", "/limits")

print("\n----- Testing Panel Service API -----")
-- Panel Service API test
testAPI("get", "/panelService")

print("\n----- Testing User Activity API -----")
-- User Activity API test
testAPI("get", "/userActivity")

print("\n----- Testing VoIP API -----")
-- VoIP API test
testAPI("get", "/voip")

print("\n----- Testing Additional Interfaces API -----")
-- Additional Interfaces API test
testAPI("get", "/additionalInterfaces")

print("\n----- Testing Fibaro FTI API -----")
-- Fibaro FTI API test
testAPI("get", "/fti")

print("\n----- Testing Gateway Connection API -----")
-- Gateway Connection API test
testAPI("get", "/gatewayConnection")

print("\n----- Testing Network Discovery API -----")
-- Network Discovery API test
testAPI("get", "/networkDiscovery")

print("\n----- Testing RGB Programs API -----")
-- RGB Programs API test
testAPI("get", "/RGBPrograms")

print("\n----- Testing ZWave API -----")
-- ZWave API tests
testAPI("get", "/zwave")
testAPI("get", "/getZwaveEngine")

print("\n----- Testing Home.Assistant API -----")
-- Home.Assistant API test - This may not exist in your system
testAPI("get", "/home/assistant", nil, 404) -- Expected code is 404 if not available

print("\n----- Testing Health Check API -----")
-- Health Check API test
testAPI("get", "/healthCheck", nil, 404) -- Expected code is 404 if not available

print("\nAPI tests completed")

