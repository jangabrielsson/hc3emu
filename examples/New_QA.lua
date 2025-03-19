-- Generated with Cursor...
_DEVELOP=true
if require and not QuickApp then require("hc3emu") end

-- A basic QuickApp example
-- This QuickApp demonstrates basic structure and functionality
--%%speed=72
--%%silent=true

local version = "0.1"

function QuickApp:onInit()
    -- Set up initial device properties
    self:updateProperty("manufacturer", "My Company")
    self:updateProperty("model", "MyQuickApp v" .. version)
    
    -- Create a main interface
    self:updateView("button1", "text", "Click me!")
    
    -- Set up midnight timer
    self:setupMidnightTimer()
    
    self:debug("MyQuickApp initialization complete")
end

-- Handler for button click
function QuickApp:buttonClicked()
    self:debug("Button clicked!")
    self:updateView("button1", "text", "Clicked!")
end

-- Calculate seconds until next midnight
function QuickApp:getSecondsToMidnight()
    local currentTime = os.date("*t")
    return ((23 - currentTime.hour) * 3600) + 
           ((59 - currentTime.min) * 60) + 
           (60 - currentTime.sec)
end

-- Setup timer to run at midnight
function QuickApp:setupMidnightTimer()
    local secondsToMidnight = self:getSecondsToMidnight()
    
    -- Schedule first run
    self:debug("Scheduling midnight timer, first run in " .. secondsToMidnight .. " seconds")
    setTimeout(function()
        self:onMidnight()
        -- Setup next run by recalculating time to next midnight
        self:setupMidnightTimer()
    end, secondsToMidnight * 1000)
end

-- Midnight handler - add your midnight tasks here
function QuickApp:onMidnight()
    self:debug("Midnight timer triggered at: " .. os.date("%Y-%m-%d %H:%M:%S"))
    -- Add your midnight tasks here
end
