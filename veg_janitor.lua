-- Vegetable Macro for Tale 7 by thejanitor.
--
-- Thanks to veggies.lua for the build button locations

dofile("common.inc")


WARNING=[[ THIS IS A BETA MACRO YOU ARE USING AT YOUR OWN RISK
You must be in the fully zoomed in top down F8 F8 F8 view, Alt+L to lock the camere once there.
In User Options -> Interface Options -> Menu You must DISABLE: "Right-Click Pins/Unpins a Menu"
You Must ENABLE: "Right-Click opens a Menu as Pinned"
In Options -> One-Click and Related -> You must DISABLE: "Plant all crops where you stand"
In Options -> Video -> You must set: Shadow Quality and Time of Day lighting to the lowest possible.
Do not move once the macro is running and you must be standing on a tile with water available to refill.
Do not stand directly on or within planting distance of actual animated water.
]]

DEBUG=false
STAR_PATTERN=true

-- These are the times in seconds it waits before watering a plant for a given stage.
-- For example, plant A is planted at time 0. At time 2.8 seconds the macro queues up plant A to be watered, it then
-- sleeps 0.2 seconds until FIRST_STAGE_WAIT time has passed before watering that plant an moving on.

-- If you encounter problems where plants are dieing at various stages it is ethier because these values are too low
-- causing a plant to be watered 3+ times in a single stage before it grows. Or it is because they are too high and
-- a plant is not recieving its water in time before regressing a stage.
-- Finally if in the final harvest stage you get getting messages about running out of water then probably it is trying
-- to harvest before it is ready and trying to rewater a plants 3rd stage. Increase the harvest wait to hopefully fix this.

-- TODO: Scale these based on global (and ideally local) teppy time.
FIRST_STAGE_WAIT = 2
SECOND_STAGE_WAIT = 22
THIRD_STAGE_WAIT = 32
HARVEST_STAGE_WAIT = 52

STAGE_WAITS = { FIRST_STAGE_WAIT, SECOND_STAGE_WAIT, THIRD_STAGE_WAIT, HARVEST_STAGE_WAIT }

-- How long to wait for the characters animations to stop at the end of each planting run. If this is too low
-- then instead of clicking a newly placed plant the macro will hit your character. So if you see at the start of a new
-- cycle the character menu being opened by the macro increase this value.
END_OF_RUN_WAIT = 19000

-- Minimum number of pixels to find in a row which have changed after placing a plant to decide to click that point.
-- If the search is not finding a plants window or possibly even clicking the character even when no animations are running
-- something has probably gone wrong with this and the corrosponding code.
MIN_ROW_LENGTH = 4
-- Controls the size of each search box. The larger this is the slower the search phase which can break everything.
SEARCH_BOX_SCALE = 1/10

RED = 0xFF2020ff
BLACK = 0x000000ff
WHITE = 0xFFFFFFff

-- To simplify the parsing of direction strings we want each direction to be represnted by a single unique character.
NORTH_WEST      = "T"
NORTH           = "N"
NORTH_EAST      = "U"
WEST            = "W"
NO_DIRECTION    = "X"
EAST            = "E"
SOUTH_WEST      = "B"
SOUTH           = "S"
SOUTH_EAST      = "M"
-- Two direction characters represents two small steps in that direction. We only take double steps in the horizontal / verticle
-- directions as the diagonal directions cause the character to move when harvesting (which screws everything up).
DOUBLE_NORTH    = NORTH .. NORTH
DOUBLE_EAST     = EAST .. EAST
DOUBLE_SOUTH    = SOUTH .. SOUTH
DOUBLE_WEST     = WEST .. WEST

-- Lookup table to go from direction character to the corosponding button to move one step in that direction.
MovePlantButtons = {}
MovePlantButtons[NORTH_WEST] = makePoint(45, 60) -- NW
MovePlantButtons[NORTH_EAST] = makePoint(75, 62) -- NE
MovePlantButtons[SOUTH_WEST] = makePoint(45, 87) -- SW
MovePlantButtons[SOUTH_EAST] = makePoint(75, 91) -- SE
MovePlantButtons[NORTH]      = makePoint(59, 51)
MovePlantButtons[SOUTH]      = makePoint(60, 98)
MovePlantButtons[EAST]       = makePoint(84, 74)
MovePlantButtons[WEST]       = makePoint(37, 75)

BuildButton = makePoint(31, 135)

-- Directions in which to move each sucessive plant before building the plant.
-- NO_DIRECTION represents no move and building the plant on the player.
Directions = { SOUTH_WEST, SOUTH, DOUBLE_SOUTH , SOUTH_EAST, DOUBLE_WEST, WEST, EAST, DOUBLE_EAST,
    NORTH_WEST, NORTH, DOUBLE_NORTH, NORTH_EAST }

-- Vectors for each direction used to generate the boxes in which to search for the newly placed plant in a given
-- direction.
DirectionVectors = {}
DirectionVectors[NORTH_WEST]    = {-1, -1}
DirectionVectors[NORTH_EAST]    = {1, -1}
DirectionVectors[SOUTH_WEST]    = {-1, 1}
DirectionVectors[SOUTH_EAST]    = {1, 1}
DirectionVectors[NORTH]         = {0, -1}
DirectionVectors[SOUTH]         = {0, 1}
DirectionVectors[EAST]          = {1, 0}
DirectionVectors[WEST]          = {-1, 0}
DirectionVectors[DOUBLE_NORTH]  = {0, -2}
DirectionVectors[DOUBLE_SOUTH]  = {0, 2}
DirectionVectors[DOUBLE_EAST]   = {2, 0}
DirectionVectors[DOUBLE_WEST]   = {-2, 0}
DirectionVectors[NO_DIRECTION]  = {0, 0}


-- Used to control the plant window placement and tiling.
WINDOW_HEIGHT=80
WINDOW_WIDTH=200
WINDOW_OFFSET_X=150
WINDOW_OFFSET_Y=150

-- User params.
seed_name = "Tears of Sinai"
num_plants = 9
num_waterings = 2
num_runs = 1
click_delay = 50


-- Used to record the time each plant is planted so we can properly time each plants watering stages.
PlantTimes = {}
-- Save the click locations from the first run for each subsiquent run so we don't have to do the crazy search box
-- searching each time.
SavedPlantLocations = {}

function doit()
    while true do
        getUserParams()
        gatherVeggies()
    end
end

function gatherVeggies()
    local min_jugs = num_waterings * getMaxPlantIndex() * 3
    local one = 'You will need ' .. min_jugs .. ' jugs of water and at minimum ' .. (getMaxPlantIndex()+8) .. ' seeds \n'
    local two = '\n Press Shift over ATITD window to continue.'
    askForWindow(one .. two)

    local searchBoxes = makeSearchBoxes()

    for _=1,num_runs do
        local start = lsGetTimer()
        checkBreak()

        drawWater()
        lsSleep(3000)
        plantSeeds(searchBoxes)
        for round=1,4 do
            waterPlants(round)
            checkBreak()
        end
        drawWater()
        closePlantWindows()
        local stop = lsGetTimer() + END_OF_RUN_WAIT
        local total = math.floor((3600 / ((stop - start)/1000)) * getMaxPlantIndex() * 3)
        sleepWithStatus(END_OF_RUN_WAIT, "Running at " .. total .. " veggies per hour! Waiting for animations to finish...")
    end
end

function closePlantWindows()
    -- Do our own quick method of closing them
    for i=1,getMaxPlantIndex() do
        local x, y= indexToWindowPos(i)
        srClickMouseNoMove(x+166, y-12)

    end
    -- And to be completely sure use the common slower version to finish off.
    -- TODO: This is broken as heck for now and sometimes just stalls the entire script...
    -- local columns = getNumberWindowColumns()+1
    -- local rows = getNumberWindowRows()
    --closeAllWindows(0,0,WINDOW_WIDTH*columns, WINDOW_HEIGHT*rows)
end

function waterPlants(round)
    for i=1,getMaxPlantIndex() do
        waterPlant(i, round)
        checkBreak()
    end
end

function waterPlant(index, round)
    checkBreak()
    local wait = STAGE_WAITS[round]
    sleepUntil(index, wait)

    local x, y = indexToWindowPos(index)
    checkBreak()
    lsSleep(click_delay)
    for _=1, num_waterings do
        srClickMouseNoMove(x+5,y-20,false)
        lsSleep(click_delay)
        srClickMouseNoMove(x+25,y+13,false)
        lsSleep(click_delay)
        checkBreak()
    end
end


-- For a given plants index sleep until time_seconds has passed for that plant since it was planted.
function sleepUntil(index, time_seconds)
    local sleepTime = time_seconds*1000 - (lsGetTimer() - PlantTimes[index]);
    if sleepTime > 0 then
        sleepWithStatus(sleepTime, "Sleeping for " .. sleepTime)
    end
end

-- Create a table of direction string -> box. Each box is where we will search the plant placed for that given direction
-- string.
-- Full of janky hardcoded values.
-- TODO: Make debuging this easier, figure out pixel scaling for different resolutions, get rid of magic numbers.
function makeSearchBoxes()
    local search_boxes = {}

    local xyWindowSize = srGetWindowSize()
    local search_size = math.floor(xyWindowSize[0] * SEARCH_BOX_SCALE)
    local mid_x = math.floor(xyWindowSize[0] / 2) - search_size / 3;
    local mid_y = math.floor(xyWindowSize[1] / 2) - search_size / 3;

    for dir_string,dir_vector in pairs(DirectionVectors) do
        local x = mid_x + dir_vector[1] * 40 - 20
        local y = mid_y + dir_vector[2] * 40 - 20
        local box = makeBox(x,y, search_size, search_size)
        box.search_from_bottom = dir_string == WEST or dir_string == DOUBLE_WEST
        search_boxes[dir_string] = box
    end
    return search_boxes
end

function plantSeeds(search_boxes)
    local max_plants = getMaxPlantIndex()
    for i=1, max_plants do
        local direction = Directions[i]
        local search_box = search_boxes[direction]
        checkBreak()
        plantSeed(i, direction, search_box)
    end
end

function getMaxPlantIndex()
    return math.min(table.getn(Directions), num_plants)
end

-- The meat and bones of this macro.
function plantSeed(i, direction, search_box)
    -- Take of a snapshot of the area in which we are guessing the plant will be placed before we actually create
    -- and place it.
    local beforePlantPixels = getBoxPixels(search_box)
    clickPlantButton()
    movePlant(direction)
    safeClick(BuildButton[0], BuildButton[1])
    PlantTimes[i] = lsGetTimer()
    lsSleep(click_delay)

    if SavedPlantLocations[i] then
        openBedWindow(i)
    else
        lsSleep(click_delay)
        findChangedRow(search_box, beforePlantPixels,
            function (x,y)
                openBedWindow(i,x,y)
            end
        )
    end
end

function openBedWindow(i, x, y)
    if SavedPlantLocations[i] then
        x = SavedPlantLocations[i][1]
        y = SavedPlantLocations[i][2]
    else
        SavedPlantLocations[i] = {x,y}
    end

    local drag_x, drag_y = indexToWindowPos(i)
    -- Wierd hacky thing, move the mouse to where the window will be and then safeClick the plant which causes
    -- the window to open instantly at the desired location and not where we clicked the plant.
    -- TODO: problably do something different as this is the only thing that takes mouse control from the user.
    srSetMousePos(drag_x, drag_y)
    lsSleep(click_delay)
    safeClick(x,y,1)
    lsSleep(click_delay)
end


-- Tiling method from Cinganjehoi's original bash script. Tried out the automato common ones but they are slow
-- and broke sometimes? This is super simple and its not the end of the world if it breaks a little during a run.
function indexToWindowPos(index)
    local columns = getNumberWindowColumns()
    local x = WINDOW_WIDTH*((index-1) % columns) + WINDOW_OFFSET_X
    local y = WINDOW_HEIGHT*math.floor((index-1) / columns) + WINDOW_OFFSET_Y
    return x, y
end

function getNumberWindowColumns()
    local xyWindowSize = srGetWindowSize()
    local width = xyWindowSize[0] * 0.6
    return math.floor(width / WINDOW_WIDTH);
end
function getNumberWindowRows()
    local columns = getNumberWindowColumns()
    local max_plant = getMaxPlantIndex()
    local max_y = WINDOW_HEIGHT*math.floor(max_plant / columns) + WINDOW_OFFSET_Y
    return max_y
end

function clickPlantButton()
    local plantButton = findText(seed_name)
    if plantButton then
        clickText(plantButton, 1)
        lsSleep(click_delay)
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

function movePlant(direction)
    -- Direction is a string of characters each representing a move.
    for c in direction:gmatch"." do
        if c ~= NO_DIRECTION then
            local button = MovePlantButtons[c]
            safeClick(button[0], button[1])
            lsSleep(click_delay)
        end
    end
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
                if mismatchesInRow > MIN_ROW_LENGTH then
                    local middle_x = x - math.floor(MIN_ROW_LENGTH / 2)
                    local row_middle = box.left + middle_x
                    if STAR_PATTERN then
                        local up_pixel = srReadPixelFromBuffer(row_middle, box.top + y - 1)
                        local down_pixel = srReadPixelFromBuffer(row_middle, box.top + y + 1)
                        if y-1 >=0 and y+1 <= box.height then
                            local old_up = pixels[y-1][middle_x]
                            local old_down = pixels[y+1][middle_x]
                            if  old_up ~= up_pixel and old_down ~= down_pixel then
                                if distanceCentre(row_middle, box.top + y) > 40 then
                                    func(row_middle, box.top + y)
                                    return true
                                end
                            end
                        end
                    else
                        func(row_middle, box.top + y)
                        return true
                    end
                end
                return false
            end
            mismatchesInRow = 0
            return false
        end
    )
end

function distanceCentre(x,y)
    local xyWindowSize = srGetWindowSize()
    local mid_x = math.floor(xyWindowSize[0] / 2);
    local mid_y = math.floor(xyWindowSize[1] / 2);

    local dx = math.pow(x - mid_x,2)
    local dy = math.pow(y - mid_y,2)

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
    while not is_done do
        current_y = 10

        if not got_user_params then
            local max_plants = table.getn(Directions)
            seed_name       = drawEditBox("seed_name", "What is the name of the seed?", "Tears of Sinai", false)
            num_plants      = drawNumberEditBox("num_plants", "How many to plant per run? Max " .. max_plants, 13)
            num_waterings   = drawNumberEditBox("num_waterings", "How many waters per stage?", 2)
            num_runs        = drawNumberEditBox("num_runs", "How many runs? ", 20)
            click_delay     = drawNumberEditBox("click_delay", "What should the click delay be? ", 50)
            got_user_params = seed_name and num_plants and num_waterings and num_runs and click_delay and drawBottomButton(lsScreenX - 5, "Next step")
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
        result = nil
    end
    if result == nil then
        local error = validateNumber and "Please enter a valid number!" or "Enter text!"
        drawText(error, RED, X_PADDING + width + 5, current_y + 5)
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
    lsPrintWrapped(x, y, 10, lsScreenX-10, 0.65, 0.65, colour, text)
end

function drawBottomButton(xOffset, text)
    return lsButtonText(lsScreenX - xOffset, lsScreenY - 30, z, 100, WHITE, text)
end
