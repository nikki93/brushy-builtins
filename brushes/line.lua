local brush = {}

brush.settingsShape = {
    color = { type = 'color' },
    width = {
        type = 'number',
        default = 10,
        style = 'slider',
        min = 0,
        max = 50,
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
        if brush.settings.width then
            love.graphics.setLineWidth(brush.settings.width)
        end
        love.graphics.line(x - dx, y - dy, x, y)
    end)
end

return brush
