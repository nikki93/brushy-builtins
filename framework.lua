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


-- Override `print` to tee to JS
local oldPrint = print
function print(...)
    oldPrint(...)
    love.thread.getChannel('LOG'):push(cjson.encode({ ... }))
end

-- Override `portal.onError` to tee to JS
function portal.onError(err)
    love.thread.getChannel('ERROR'):push(cjson.encode({ error = err }))
end


-- Map of `brush.name` -> `brush`
local brushes = {}

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


-- Save state to the 'SAVED_STATE' `Channel` to load later
local function saveState()
    local state = {}

    -- Save the `layer`
    state.layerImageData = layer:newImageData()

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

    -- Load the `layer`
    renderImageDataToCanvas(state.layerImageData, layer)
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


-- Undo history
local undoPoints = {}

-- Save to the history
local function saveUndoPoint()
    local undoPoint = {}

    -- Save the `layer`
    undoPoint.layerImageData = layer:newImageData()

    -- Push to history and limit it to 150 elements
    table.insert(undoPoints, undoPoint)
    while #undoPoints > 150 do
        table.remove(undoPoints, 1)
    end
end

-- Step back in undo history
local function undo()
    if #undoPoints > 0 then
        local undoPoint = table.remove(undoPoints)

        -- Load the `layer`
        renderImageDataToCanvas(undoPoint.layerImageData, layer)

        -- Now might be a good time to GC
        collectgarbage()
    end
end

-- Undo if JS tells us we should
local function checkUndo()
    local channel = love.thread.getChannel('UNDO')
    local message = channel:pop()
    if message then
        channel:clear()
        undo()
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


-- Actual top-level `love.` callbacks

function love.load()
    loadState()
end

function love.update(dt)
    checkSettings()

    checkReload()

    checkUndo()

    checkScreenshot()

    checkSelectBrush()
end

function love.draw()
    love.graphics.stacked('all', function()
        love.graphics.setBlendMode('alpha', 'premultiplied')
        love.graphics.draw(layer)
    end)

    love.graphics.print('fps: ' .. love.timer.getFPS(), 20, 20)
end

local mouseReleasedSinceLastUndo = true

function love.mousereleased()
    mouseReleasedSinceLastUndo = true
end

function love.mousemoved(x, y, dx, dy)
    local selectedBrush = brushes[selectedBrushName]
    if selectedBrush and selectedBrush.paint then
        if mouseReleasedSinceLastUndo then
            saveUndoPoint()
            mouseReleasedSinceLastUndo = false
        end

        layer:renderTo(function()
            love.graphics.stacked('all', function()
                selectedBrush.paint(x, y, dx, dy)
            end)
        end)
    end
end


-- Exported functions

local framework = {}

function framework.loadBrushes(map)
    for name, brush in pairs(map) do
        if type(name) ~= 'string' then
            name = brush.id
        end
        assert(type(name) == 'string', "need name for brush")
        assert(not brushes[name], "brush with name '" .. name .. "' already exists")

        brush.name = name
        brush.settings = {}
        brush.settingsShape = brush.settingsShape or {}
        brushes[name] = brush
    end
    sendSettingsShapes()
end

return framework
