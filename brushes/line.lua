local brush = {}

--brush.settingsShape = {
--    width = {
--        type = 'number',
--        default = 10,
--        style = 'slider',
--        min = 0,
--        max = 50,
--    },
--}
--
--function brush.paint(x, y, dx, dy)
--    if brush.settings.width then
--        love.graphics.setLineWidth(brush.settings.width)
--    end
--    love.graphics.line(x - dx, y - dy, x, y)
--end

local moonshine = require 'https://raw.githubusercontent.com/nikki93/moonshine/9e04869e3ceaa76c42a69c52a954ea7f6af0469c/init.lua'
local effect = moonshine(moonshine.effects.glow)

effect.glow.min_luma = 0

local source = love.audio.newSource('https://raw.githubusercontent.com/nikki93/wat-do/8cb92bc647e4fcdb093bf3954f4382a1f934c0b3/jump.wav', 'static')

brush.settingsShape = {
    text = { type = 'text' },
    image = { type = 'image' },
    radius = { type = 'number', style = 'slider', min = 0, max = 1 },
    color = { type = 'color' },
}


function brush.paint(x, y, dx, dy)
    source:play()
    effect(function()
        if brush.settings.radius then
            love.graphics.setLineWidth(120 * brush.settings.radius)
        end
        if brush.settings.color then
            local color = brush.settings.color
            love.graphics.setColor(color.r, color.g, color.b, color.a or 1)
        else
            love.graphics.setColor(math.random(), math.random(), math.random())
        end
        love.graphics.line(x, y, x - dx, y - dy)

        if brush.settings.text then
            love.graphics.print(brush.settings.text, x, y)
        end

        local image = brush.settings.image
        if image then
            local w, h = image:getDimensions()
            local scale = love.graphics.getWidth() / w
            if brush.settings.radius and brush.settings.radius > 0 then
                scale = 2 * brush.settings.radius * scale
            end
            love.graphics.draw(image, x, y, 0, scale, scale, 0.5 * w, 0.5 * h)
        end
    end)
end

return brush