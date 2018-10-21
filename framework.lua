local framework = {}


local cjson = require 'cjson'
local uuid = require 'uuid'


uuid.randomseed(10000 * require('socket').gettime())


-- `love.graphics.stacked([arg], foo)` calls `foo` between `love.graphics.push([arg])` and
-- `love.graphics.pop()` while being resilient to errors
function love.graphics.stacked(...)
    local arg, func
    if select('#', ...) == 1 then
        func = select(1, ...)
    else
        arg = select(1, ...)
        func = select(2, ...)
    end
    love.graphics.push(arg)

    local succeeded, err = pcall(func)

    love.graphics.pop()

    if not succeeded then
        error(err, 0)
    end
end


-- Map of `brush.name` -> `brush`
brushes = {}

-- Name of selected brush
local selectedBrushName


-- Send `.settingsShape`s of everything to JS
local function sendSettingsShapes()
    local settingsShapes = {}
    for name, brush in pairs(brushes) do
        settingsShapes[name] = brush.settingsShape
    end
    love.thread.getChannel('SETTINGS_SHAPES'):clear()
    love.thread.getChannel('SETTINGS_SHAPES'):push(cjson.encode(settingsShapes))
end

-- Check for new setting values sent from JS
local function checkSettings()
    while true do -- Loop through all messages in 'SETTING_VALUE' `Channel`
        local json = love.thread.getChannel('SETTING_VALUE'):pop()
        if json == nil then break end
        local decoded = cjson.decode(json)

        local brush = brushes[decoded.brushName]
        if decoded.value == cjson.null then -- `null`? Just clear.
            brush.settings[decoded.settingName] = nil
        else -- Else handle based on type
            if brush.settingsShape[decoded.settingName].type == 'image' then
                brush.settings[decoded.settingName] = love.graphics.newImage(decoded.value.uri);
            elseif brush.settingsShape[decoded.settingName].type == 'text' then
                brush.settings[decoded.settingName] = decoded.value
            elseif brush.settingsShape[decoded.settingName].type == 'number' then
                brush.settings[decoded.settingName] = decoded.value
            elseif brush.settingsShape[decoded.settingName].type == 'color' then
                brush.settings[decoded.settingName] = decoded.value
            end
        end
    end
end


-- Default layer, start with black
layer = love.graphics.newCanvas()
layer:renderTo(function()
    love.graphics.clear(0, 0, 0, 1)
end)


-- Copy `ImageData` into a `Canvas` -- useful for restoring a `Canvas` from `:newImageData()`
-- obtained before
local function renderImageDataToCanvas(imageData, canvas)
    local image = love.graphics.newImage(imageData)
    canvas:renderTo(function()
        love.graphics.stacked('all', function()
            love.graphics.clear(0, 0, 0, 1)
            local cw, ch = canvas:getDimensions()
            local iw, ih = image:getDimensions()
            love.graphics.scale(cw / iw, ch / ih)
            love.graphics.setBlendMode('alpha', 'premultiplied')
            love.graphics.draw(image, 0, 0)
        end)
    end)
end


-- Undo / redo state
local undos = {} -- Sequence of undo states with oldest first, current state last
local redos = {} -- Sequence of redo states with next to redo last, most 'future' first

-- Add to the undo history
local function pushUndo()
    local state = {}

    -- Save the `layer`
    state.layerImageData = layer:newImageData()

    -- Push to history and limit it to 150 elements
    table.insert(undos, state)
    while #undos > 150 do
        table.remove(undos, 1)
    end

    -- Clear the redo 'future'
    if #redos > 0 then
        redos = {}
        love.thread.getChannel('REDO_UNAVAILABLE'):push('')
        collectgarbage()
    end
end

-- Load the current state in the undo history
local function loadUndo()
    local state = undos[#undos]

    -- Load the `layer`
    renderImageDataToCanvas(state.layerImageData, layer)
end

-- Step back in the undo history
local function undo()
    if #undos > 1 then
        -- Swap from `undos` to `redos`
        table.insert(redos, table.remove(undos))
        loadUndo()
    end
    love.thread.getChannel('REDO_AVAILABLE'):push('')
end

-- Step forward in the redo 'future'
local function redo()
    if #redos > 0 then
        -- Swap from `redos` to `undos`
        table.insert(undos, table.remove(redos))
        loadUndo()
    end
    if #redos == 0 then
        love.thread.getChannel('REDO_UNAVAILABLE'):push('')
    end
end

-- Undo or redo if JS tells us we should do either
local function checkUndoRedo()
    local shouldUndo = love.thread.getChannel('UNDO'):pop()
    if shouldUndo then undo() end
    local shouldRedo = love.thread.getChannel('REDO'):pop()
    if shouldRedo then redo() end
end


-- Save state to the 'SAVED_STATE' `Channel` to load later
local function saveState()
    local state = {}

    -- Save `layer`
    state.layerImageData = layer:newImageData()

    -- Save `undos` and `redos`
    state.undos = undos
    state.redos = redos

    -- Push to `Channel` --
    local channel = love.thread.getChannel('SAVED_STATE')
    channel:clear()
    channel:push(state)
end

-- Load state from the 'SAVED_STATE' `Channel`
local function loadState()
    local channel = love.thread.getChannel('SAVED_STATE')
    local state = channel:pop()
    if not state then return end
    channel:clear()

    -- Load `layer`
    renderImageDataToCanvas(state.layerImageData, layer)

    -- Load `undos` and `redos`
    undos = state.undos
    redos = state.redos
end

-- Handle things to do when JS tells us we're reloading -- for now just saves state
local function checkReload()
    local channel = love.thread.getChannel('RELOAD')
    local message = channel:pop()
    if message then
        channel:clear()
        saveState()
    end
end


-- Save a screenshot and return the URL
local function writeScreenshot()
    local filename = 'screenshot-' .. uuid.new() .. '.png'
    layer:newImageData():encode('png', filename)
    love.thread.getChannel('SCREENSHOT_SAVED'):push(
        love.filesystem.getSaveDirectory() .. '/' .. filename)
end

-- Take a screenshot if JS tells us we should
local function checkScreenshot()
    local channel = love.thread.getChannel('SCREENSHOT_REQUESTED')
    local message = channel:pop()
    if message then
        writeScreenshot()
    end
end


-- Select a brush if JS tells us we should
local function checkSelectBrush()
    local channel = love.thread.getChannel('SELECT_BRUSH')
    local message = channel:pop()
    if message and brushes[message] then
        selectedBrushName = message
    end
end


-- Load the code brush if JS tells us we should
local function checkLoadCodeBrush()
    local channel = love.thread.getChannel('LOAD_CODE_BRUSH')
    local message = channel:pop()
    channel:clear()
    if message then
        framework.loadBrushes { code = require(message) }
    end
end


-- Actual top-level `love.` callbacks

function love.load()
    loadState()
end

function love.update(dt)
    checkLoadCodeBrush()

    checkSettings()

    checkReload()

    checkUndoRedo()

    checkScreenshot()

    checkSelectBrush()

    local selectedBrush = brushes[selectedBrushName]
    if selectedBrush and selectedBrush.update then
        selectedBrush.update(dt)
    end
end

function love.draw()
    love.graphics.stacked('all', function()
        love.graphics.setBlendMode('alpha', 'premultiplied')
        love.graphics.draw(layer)
    end)

    love.graphics.print('fps: ' .. love.timer.getFPS(), 20, 20)
end

function love.mousereleased()
    pushUndo()
end

function love.mousemoved(x, y, dx, dy)
    local selectedBrush = brushes[selectedBrushName]
    if selectedBrush and selectedBrush.paint then
        layer:renderTo(function()
            love.graphics.stacked('all', function()
                selectedBrush.paint(x, y, dx, dy)
            end)
        end)
    end
end


-- Load brushes given a map of brush name -> brush object (usually `require`'d from somewhere)
function framework.loadBrushes(map)
    for name, brush in pairs(map) do
        if type(name) ~= 'string' then
            name = brush.id
        end
        assert(type(name) == 'string', "need name for brush")

        brush.name = name
        brush.settings = {}
        brush.settingsShape = brush.settingsShape or {}
        brushes[name] = brush
    end
    sendSettingsShapes()
end


-- First undo state!
pushUndo()


return framework
