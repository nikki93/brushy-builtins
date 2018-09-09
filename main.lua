require 'framework'


-- "mooonshine" is a shader FX library from the web
local moonshine = require 'https://raw.githubusercontent.com/nikki93/moonshine/master/init.lua'
local effect = moonshine(moonshine.effects.glow)

effect.glow.min_luma = 0


brush.settingsShape = {
    text = { type = 'text' },
    text2 = { type = 'text' },
    image = { type = 'image' },
    radius = { type = 'number', style = 'slider', min = 0, max = 30 },
}


function brush.paint(x, y, dx, dy)
    effect(function()
        if brush.settings.radius then
            love.graphics.setLineWidth(brush.settings.radius)
        end
        love.graphics.setColor(math.random(), math.random(), math.random())
        love.graphics.line(x, y, x - dx, y - dy)

        if brush.settings.text then
            love.graphics.print(brush.settings.text, x, y)
        end

        local image = brush.settings.image
        if image then
            local w, h = image:getDimensions()
            local scale = love.graphics.getWidth() / w
            love.graphics.draw(image, x, y, 0, scale, scale, 0.5 * w, 0.5 * h)
        end
    end)
end
