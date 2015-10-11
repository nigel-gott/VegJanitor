-- Vegetable Macro for Tale 7 by thejanitor.
--
-- Thanks to veggies.lua for the build button locations

dofile("common.inc")


WARNING=[[
THIS IS A BETA MACRO YOU ARE USING AT YOUR OWN RISK
You must be in the fully zoomed in top down F8 F8 F8 view, Alt+L to lock the camere once there.
In User Options -> Interface Options -> Menu You must DISABLE: "Right-Click Pins/Unpins a Menu"
You Must ENABLE: "Right-Click opens a Menu as Pinned"
You Must ENABLE: "Use the chat area instead of popups for many messages"
In Options -> One-Click and Related -> You must DISABLE: "Plant all crops where you stand"
In Options -> Video -> You must set: Shadow Quality and Time of Day lighting to the lowest possible.
Do not move once the macro is running and you must be standing on a tile with water available to refill.
Do not stand directly on or within planting distance of actual animated water.
POINT YOUR CHARACTER WEST OR BAD THINGS MIGHT HAPPEN THIS IS A WIERD MACRO OKAY

]]

DEBUG=false

-- These are the times in seconds it waits before watering a plant for a given stage.
-- For example, plant A is planted at time 0. At time 2.8 seconds the macro queues up plant A to be watered, it then
-- sleeps 0.2 seconds until FIRST_STAGE_WAIT time has passed before watering that plant an moving on.

-- If you encounter problems where plants are dieing at various stages it is ethier because these values are too low
-- causing a plant to be watered 3+ times in a single stage before it grows. Or it is because they are too high and
-- a plant is not recieving its water in time before regressing a stage.
-- Finally if in the final harvest stage you get getting messages about running out of water then probably it is trying
-- to harvest before it is ready and trying to rewater a plants 3rd stage. Increase the harvest wait to hopefully fix this.

-- TODO: Scale these based on global (and ideally local) teppy time.
FIRST_STAGE_WAIT = 4
SECOND_STAGE_WAIT = 24
THIRD_STAGE_WAIT = 34
HARVEST_STAGE_WAIT = 52

STAGE_WAITS = { FIRST_STAGE_WAIT, SECOND_STAGE_WAIT, THIRD_STAGE_WAIT, HARVEST_STAGE_WAIT }

-- How long to wait for the characters animations to stop at the end of each planting run. If this is too low
-- then instead of clicking a newly placed plant the macro will hit your character. So if you see at the start of a new
-- cycle the character menu being opened by the macro increase this value.
END_OF_RUN_WAIT = 0

-- We don't click inside this circle around the centre of the screen.
PLAYER_MODEL_RADIUS = 60

-- Minimum number of pixels to find in a row which have changed after placing a plant to decide to click that point.
-- If the search is not finding a plants window or possibly even clicking the character even when no animations are running
-- something has probably gone wrong with this and the corrosponding code.
MIN_ROW_LENGTH = 4
-- Controls the size of each search box. The larger this is the slower the search phase which can break everything.
SEARCH_BOX_SCALE = 1/10

MAX_PLANTS=12

RED = 0xFF2020ff
BLACK = 0x000000ff
WHITE = 0xFFFFFFff


-- Used to control the plant window placement and tiling.
WINDOW_HEIGHT=80
WINDOW_WIDTH=220
WINDOW_OFFSET_X=150
WINDOW_OFFSET_Y=150

function doit()
    while true do
        local config = getUserParams()
        makeReadOnly(config)
        askForWindowAndSetupGlobals(config)
        gatherVeggies(config)
    end
end

function askForWindowAndSetupGlobals(config)
    local min_jugs = config.num_waterings * config.num_plants * 3
    local min_seeds = config.num_plants + 8
    local one = 'You will need ' .. min_jugs .. ' jugs of water and at minimum ' .. min_seeds .. ' seeds \n'
    local two = '\n Press Shift over ATITD window to continue.'
    askForWindow(one .. two)
    setupGlobals()
end

function setupGlobals()
    NORTH   = Vector:new{0,-1}
    SOUTH   = Vector:new{0,1}
    WEST    = Vector:new{-1,0}
    EAST    = Vector:new{1,0}
    NORTH_WEST = NORTH + WEST
    NORTH_EAST = NORTH + EAST
    SOUTH_WEST = SOUTH + WEST
    SOUTH_EAST = SOUTH + EAST
    DOUBLE_SOUTH = SOUTH * 2
    DOUBLE_NORTH = NORTH * 2
    DOUBLE_WEST = WEST * 2
    DOUBLE_EAST = EAST * 2

    MOVE_BTNS = {}
    PLANT_LOCATIONS = {next=1}
    PlantLocation:new{direction_vector=NORTH_EAST, move_btn=Vector:new{75, 62}}
    PlantLocation:new{direction_vector=NORTH_WEST, move_btn=Vector:new{45,60}}
    PlantLocation:new{direction_vector=SOUTH_EAST, move_btn=Vector:new{75, 91}}
    PlantLocation:new{direction_vector=SOUTH_WEST, move_btn=Vector:new{45, 87}}
    PlantLocation:new{direction_vector=NORTH, move_btn=Vector:new{59, 51}}
    PlantLocation:new{direction_vector=SOUTH ,move_btn=Vector:new{60, 98}}
    PlantLocation:new{direction_vector=EAST ,move_btn=Vector:new{84, 74}}
    PlantLocation:new{direction_vector=WEST ,move_btn=Vector:new{37, 75}}
    PlantLocation:new{direction_vector=NORTH, num_move_steps=2}
    PlantLocation:new{direction_vector=WEST, num_move_steps=2}
    PlantLocation:new{direction_vector=EAST, num_move_steps=2}
    PlantLocation:new{direction_vector=SOUTH, num_move_steps=2}
    makeReadOnly(PLANT_LOCATIONS)

    local mid = getScreenMiddle()
    ANIMATION_BOX = makeBox(mid.x - 60, mid.y - 50, 105, 85)
    ARM_BOX = makeBox(mid.x - 90, mid.y - 20, 80, 25)
    BUILD_BTN = Vector:new{31, 135}
end

PlantLocation={}
function PlantLocation:new(o)
    if o.num_move_steps then
        o.move_btn = PLANT_LOCATIONS[o.direction_vector].move_btn
        o.direction_vector = o.direction_vector * o.num_move_steps
    else
        o.num_move_steps = 1
    end
    PLANT_LOCATIONS[o.direction_vector] = o
    PLANT_LOCATIONS[PLANT_LOCATIONS.next] = o
    PLANT_LOCATIONS.next = PLANT_LOCATIONS.next + 1
    o.box = makeSearchBox(o.direction_vector)
    return newObject(PlantLocation, o, true)
end

function PlantLocation:move()
    for step=1,self.num_move_steps do
        click(self.move_btn)
    end
end

function gatherVeggies(config)
    local plants = Plants:new{num_plants=config.num_plants }
    first_run = true

    drawWater()
    for _=1,config.num_runs do
        local start = lsGetTimer()

        checkBreak()
        lsSleep(3000)

        plants:iterate(Plant.plant, config.seed_name)
        for round=1,4 do
            plants:iterate(Plant.water, {stage_wait=STAGE_WAITS[round], num_waterings=config.num_waterings})
            checkBreak()
        end

        drawWater()
        checkBreak()
        lsSleep(click_delay*2)

        plants:iterate(Plant.close)

        local stop = lsGetTimer() + END_OF_RUN_WAIT
        local total = math.floor((3600 / ((stop - start)/1000)) * config.num_plants * 3)
        lsSleep(END_OF_RUN_WAIT)
        first_run = false
    end
end

-- Simple container object which constructs N plants and allows iteration over them.
Plants={}
function Plants:new(o)
    for index=1,o.num_plants do
        local location = PLANT_LOCATIONS[index]
        self[index] = Plant:new{index=index, location=location}
    end
    return newObject(self,o,true)
end

function Plants:iterate(func, args)
    for index=1,self.num_plants do
        func(self[index], args)
    end
end

Plant = {}
function Plant:new(o)
    o.window_pos = indexToWindowPos(o.index)
    return newObject(self,o)
end

function Plant:plant(seed_name)
    -- Take of a snapshot of the area in which we are guessing the plant will be placed before we actually create
    -- and place it.
    local beforePlantPixels
    if not self.saved_plant_location then
        beforePlantPixels = getBoxPixels(self.location.box)
    end

    clickPlantButton(seed_name)
    self.location:move()
    local spot = getWaitSpotAt(BUILD_BTN)
    click(BUILD_BTN)
    self.plant_time = lsGetTimer()
    waitForChange(spot, click_delay*2)

    if not self.saved_plant_location then
        for _=1,SEARCH_RETRYS do
            if self:searchForPlant(beforePlantPixels) then
                break
            end
            lsSleep(tick_delay)
        end
    end

    self:openBedWindow()
end

function Plant:searchForPlant(beforePlantPixels)
    local found = false
    findChangedRow(self.location.box, beforePlantPixels,
        function (location)
            self.saved_plant_location = location
            found = true
        end
    )
    return found
end

function Plant:openBedWindow()
    if not self.saved_plant_location then
        lsPrintln("No Saved location for plant " .. self.index)
        return
    end

    -- Wierd hacky thing, move the mouse to where the window will be and then safeClick the plant which causes
    -- the window to open instantly at the desired location and not where we clicked the plant.
    -- TODO: problably do something different as this is the only thing that takes mouse control from the user.
    for _=1, SEARCH_RETRYS do
        moveMouse(self.window_pos)
        local spot = getWaitSpotAt(self.window_pos + {5,5})
        click(self.saved_plant_location ,1)
        self.window_open = waitForChange(spot, click_delay*2)

        if self.window_open then
            break
        end
        lsSleep(tick_delay)
    end
end

-- For a given plants index sleep until time_seconds has passed for that plant since it was planted.
function Plant:sleepUntil(time_seconds)
    local sleepTime = time_seconds*1000 - (lsGetTimer() - self.plant_time);
    if sleepTime > 0 then
        sleepWithStatus(sleepTime, "Sleeping for " .. sleepTime)
    end
end

function Plant:clickWindow(offset)
    if self.window_open then
        click(self.window_pos + offset)
    end
end

function Plant:water(args)
    if not self.window_open then
        lsPrintln("Trying to water plant " .. i .. " which has no window open")
        return
    end

    checkBreak()
    self:sleepUntil(args.stage_wait)

    checkBreak()
    self:clickWindow{5,-20}
    for _=1, args.num_waterings do
        self:clickWindow{5,-20}
        self:clickWindow{50,13}
        checkBreak()
    end
end

function Plant:close()
    if cabbage then
        self:clickWindow{182,-12}
    else
        self:clickWindow{166,-12}
    end
end

-- Create a table of direction string -> box. Each box is where we will search the plant placed for that given direction
-- string.
-- Full of janky hardcoded values.
-- TODO: Make debuging this easier, figure out pixel scaling for different resolutions, get rid of magic numbers.
function makeSearchBox(direction)
    local xyWindowSize = srGetWindowSize()
    local search_size = math.floor(xyWindowSize[0] * SEARCH_BOX_SCALE)
    local mid = getScreenMiddle()
    local offset_mid = mid - {search_size / 3, search_size / 3 }

    local top_left = offset_mid + direction*40 - Vector:new{20,20 }

    local box = makeBox(top_left.x,top_left.y, search_size, search_size)
    box.search_from_bottom = dir_string == WEST or dir_string == DOUBLE_WEST or NORTH_EAST
    return box
end

function getScreenMiddle()
    local xyWindowSize = srGetWindowSize()
    return Vector:new{math.floor(xyWindowSize[0]/2), math.floor(xyWindowSize[1]/2)}
end

-- Tiling method from Cinganjehoi's original bash script. Tried out the automato common ones but they are slow
-- and broke sometimes? This is super simple and its not the end of the world if it breaks a little during a run.
function indexToWindowPos(index)
    local columns = getNumberWindowColumns()
    local x = WINDOW_WIDTH*((index-1) % columns) + WINDOW_OFFSET_X
    local y = WINDOW_HEIGHT*math.floor((index-1) / columns) + WINDOW_OFFSET_Y
    return Vector:new{x, y}
end

function getNumberWindowColumns()
    local xyWindowSize = srGetWindowSize()
    local width = xyWindowSize[0] * 0.6
    return math.floor(width / WINDOW_WIDTH);
end

function clickPlantButton(seed_name)
    local plantButton = findText(seed_name)
    if plantButton then
        local spot = getWaitSpotAt(Vector:new{0,0})
        clickText(plantButton, 1)
        waitForChange(spot,click_delay*2)
    else
        error("Text " .. seed_name .. " Not found.")
    end
end

function getBoxPixels(box)
    local pixels = {}
    iterateBoxPixels(box,
        function(x,y,pixel)
            pixels[y][x] = pixel
        end,
        function(y)
            pixels[y] = {}
        end
    )
    return pixels
end

-- Finds a row of pixels which have changed in the current ReadScreen buffer compared to a given 2d array of pixels.
function findChangedRow(box, pixels, func)
    local mismatchesInRow = 0
    if DEBUG then
        srSetMousePos(box.left, box.top)
        sleepWithStatus(2000, "TOP LEFT")
        srSetMousePos(box.right, box.bottom)
        sleepWithStatus(2000, "BOT RIGHT")
    end
    iterateBoxPixels(box,
        function(x,y,pixel)
            if pixels[y][x] ~= pixel then
                mismatchesInRow = mismatchesInRow + 1
                return mismatchesInRow > MIN_ROW_LENGTH and applyIfAllowed(x,y,box,pixels,func)
            else
                mismatchesInRow = 0
                return false
            end
        end
    )
end

function applyIfAllowed(x,y,box,pixels,func)
    local middle_x = x - math.floor(MIN_ROW_LENGTH / 2)
    local actual_y = box.top + y
    local row_middle = box.left + middle_x
    if allowedToClick(row_middle, actual_y) then
        local up_pixel = srReadPixelFromBuffer(row_middle, actual_y - 1)
        local down_pixel = srReadPixelFromBuffer(row_middle, actual_y + 1)
        if y-1 >=0 and y+1 <= box.height then
            local old_up_pixel = pixels[y-1][middle_x]
            local old_down_pixel = pixels[y+1][middle_x]
            if old_up_pixel ~= up_pixel and old_down_pixel ~= down_pixel then
                func(Vector:new{row_middle, actual_y})
                return true
            end
        end
    end
    return false
end

function allowedToClick(x,y)
    return distanceCentre(Vector:new{x,y}) > PLAYER_MODEL_RADIUS and not inside(x,y,ANIMATION_BOX) and not inside(x,y,ARM_BOX)
end

function inside(x,y,box)
    return (x >= box.left and x <= box.right) and (y >= box.top and y <= box.bottom)
end

function distanceCentre(vector)
    local mid = getScreenMiddle()
    local delta = vector - mid

    local dx = math.pow(delta.x,2)
    local dy = math.pow(delta.y,2)

    return math.sqrt(dx + dy)
end

function iterateBoxPixels(box, xy_func, y_func)
    srReadScreen()

    local search_from_bottom = box.search_from_bottom
    local start = search_from_bottom and box.height or 0
    local stop = search_from_bottom and 0 or box.height
    local inc = search_from_bottom and -1 or 1

    for y=start,stop,inc do
        if y_func then y_func(y) end
        for x=0, box.width do
            local pixel = srReadPixelFromBuffer(box.left + x, box.top + y)
            if xy_func(x,y,pixel) then
                return
            end
        end
        checkBreak()
    end
end


-- Used to place gui elements sucessively.
current_y = 0
-- How far off the left hand side to place gui elements.
X_PADDING = 5

function getUserParams()
    local is_done = false
    local got_user_params = false
    local config = {}
    while not is_done do
        current_y = 10

        if not got_user_params then
            local max_plants       = MAX_PLANTS
            config.seed_name       = drawEditBox("seed_name", "What is the name of the seed?", "Tears of Sinai", false)
            config.num_plants      = drawNumberEditBox("num_plants", "How many to plant per run? Max " .. max_plants, 13)
            config.num_waterings   = drawNumberEditBox("num_waterings", "How many waters per stage?", 2)
            config.num_runs        = drawNumberEditBox("num_runs", "How many runs? ", 20)
            config.click_delay     = drawNumberEditBox("click_delay", "What should the click delay be? ", 50)
            config.cabbage         = lsCheckBox(X_PADDING, current_y, 10, WHITE, "Cabbage?", cabbage)
            got_user_params = true
            for k,v in pairs(config) do
                got_user_params = got_user_params and v
            end
            got_user_params = got_user_params and drawBottomButton(lsScreenX - 5, "Next step")
        else
            drawWrappedText(WARNING, RED, X_PADDING, current_y)

            is_done = drawBottomButton(lsScreenX - 5, "Start Script")
        end

        if drawBottomButton(110, "Exit Script") then
            error "Script exited by user"
        end

        lsDoFrame()
        lsSleep(10)
    end

    config.num_plants = limitMaxPlants(config.num_plants)
    click_delay = config.click_delay
    return config
end

function limitMaxPlants(user_supplied_max_num)
    return math.min(12, user_supplied_max_num)
end

function drawNumberEditBox(key, text, default)
    return drawEditBox(key, text, default, true)
end

function drawEditBox(key, text, default, validateNumber)
    drawTextUsingCurrent(text, WHITE)
    local width = validateNumber and 50 or 200
    local height = 30
    local done, result = lsEditBox(key, X_PADDING, current_y, 0, width, height, 1.0, 1.0, BLACK, default)
    if validateNumber then
        result = tonumber(result)
    elseif result == "" then
        result = false
    end
    if not result then
        local error = validateNumber and "Please enter a valid number!" or "Enter text!"
        drawText(error, RED, X_PADDING + width + 5, current_y + 5)
        result = false
    end
    current_y = current_y + 35
    return result
end

function drawTextUsingCurrent(text, colour)
    drawText(text, colour, X_PADDING, current_y)
    current_y = current_y + 20
end
function drawText(text, colour, x, y)
    lsPrint(x, y, 10, 0.7, 0.7, colour, text)
end

function drawWrappedText(text, colour, x, y)
    lsPrintWrapped(x, y, 10, lsScreenX-10, 0.6, 0.6, colour, text)
end

function drawBottomButton(xOffset, text)
    return lsButtonText(lsScreenX - xOffset, lsScreenY - 30, z, 100, WHITE, text)
end

-- Simple immutable vector class
Vector={}
function Vector:new(o)
    o.x = o.x or o[1]
    o.y = o.y or o[2]
    return newObject(self, o, true)
end

function Vector:__add(vector)
    local x,y = Vector.getXY(vector)
    return Vector:new{self.x + x, self.y + y}
end

function Vector:__sub(vector)
    local x,y = Vector.getXY(vector)
    return Vector:new{self.x - x, self.y - y}
end

function Vector:__div(divisor)
    return Vector:new{self.x / divisor, self.y / divisor}
end

function Vector:__mul(multiplicand)
    return Vector:new{self.x * multiplicand, self.y * multiplicand}
end

function Vector.getXY(vector)
    return vector.x or vector[1], vector.y or vector[2]
end

function Vector:length()
    return math.sqrt(self.x^2 + self.y^2)
end

function Vector:normalize()
    return self / self:length()
end

function Vector:__tostring()
    return "(" .. self.x .. ", " .. self.y .. ")"
end



function click(vector, right_click)
    srClickMouseNoMove(vector.x, vector.y, right_click)
    lsSleep(click_delay)
end

function moveMouse(vector)
    srSetMousePos(vector.x, vector.y)
    lsSleep(click_delay)
end

function getWaitSpotAt(vector)
    return getWaitSpot(vector.x, vector.y)
end

-- Helper function used in an objects constructor to setup its metatable correctly allowing for basic inheritence.
function newObject(class, o, read_only)
    o = o or {}
    setmetatable(o, class)
    class.__index = class
    if read_only then
        makeReadOnly(o)
    end
    return o
end

function makeReadOnly(table)
    local mt = getmetatable(table)
    if not mt then
        mt = {}
        if not table then print(debug.traceback()) end
        setmetatable(table,mt)
    end
    mt.__newindex = function(t,k,v)
        error("Attempt to update a read-only table", 2)
    end
end
