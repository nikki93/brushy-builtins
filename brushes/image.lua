local brush = {}

brush.settingsShape = {
    image = { type = 'image' },
    color = { type = 'color' },
    scale = {
        type = 'number',
        default = 1,
        style = 'slider',
        min = 0,
        max = 2,
    },
}

local moonshine = require 'https://raw.githubusercontent.com/nikki93/moonshine/9e04869e3ceaa76c42a69c52a954ea7f6af0469c/init.lua'
local effect = moonshine(moonshine.effects.glow)
effect.glow.min_luma = 0

function brush.paint(x, y, dx, dy)
    effect(function()
        if brush.settings.color then
            local color = brush.settings.color
            love.graphics.setColor(color.r, color.g, color.b, color.a or 1)
        else
            love.graphics.setColor(math.random(), math.random(), math.random())
        end
        local image = brush.settings.image
        if image then
            -- Scale to fit to screen
            local w, h = image:getDimensions()
            local scale = love.graphics.getWidth() / w
            if brush.settings.scale then
                scale = brush.settings.scale * scale
            end
            love.graphics.draw(image, x, y, 0, scale, scale, 0.5 * w, 0.5 * h)
        else
            love.graphics.print('no image', x, y)
        end
    end)
end

return brush
