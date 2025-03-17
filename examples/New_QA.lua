

-- Generated with Cursor...
if require and not QuickApp then require("hc3emu") end

-- A basic QuickApp example
-- This QuickApp demonstrates basic structure and functionality
--%%speed=72

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

-- Setup timer to run at midnight
function QuickApp:setupMidnightTimer()
    local currentTime = os.date("*t")
    -- Calculate time until next midnight
    local secondsToMidnight = ((23 - currentTime.hour) * 3600) + 
                             ((59 - currentTime.min) * 60) + 
                             (60 - currentTime.sec)
    
    -- Schedule first run
    self:debug("Scheduling midnight timer, first run in " .. secondsToMidnight .. " seconds")
    fibaro.setTimeout(secondsToMidnight * 1000, function()
        self:onMidnight()
        -- Setup next run (24 hours = 86400 seconds)
        self:setupDailyTimer()
    end)
end

-- Setup the recurring daily timer
function QuickApp:setupDailyTimer()
    fibaro.setInterval(86400 * 1000, function()
        self:onMidnight()
    end)
end

-- Midnight handler - add your midnight tasks here
function QuickApp:onMidnight()
    self:debug("Midnight timer triggered at: " .. os.date("%Y-%m-%d %H:%M:%S"))
    -- Add your midnight tasks here
end
