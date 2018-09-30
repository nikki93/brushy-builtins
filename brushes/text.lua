local brush = {}

brush.settingsShape = {
    color = { type = 'color' },
    text = { type = 'text', default = 'no text' },
    size = {
        type = 'number',
        default = 10,
        style = 'slider',
        min = 0,
        max = 120,
    },
}

local moonshine = require 'https://raw.githubusercontent.com/nikki93/moonshine/9e04869e3ceaa76c42a69c52a954ea7f6af0469c/init.lua'
local effect = moonshine(moonshine.effects.glow)
effect.glow.min_luma = 0

local fonts = {}

function brush.paint(x, y, dx, dy)
    effect(function()
        if brush.settings.color then
            local color = brush.settings.color
            love.graphics.setColor(color.r, color.g, color.b, color.a or 1)
        else
            love.graphics.setColor(math.random(), math.random(), math.random())
        end

        -- Set font, generating if we don't have it cached
        local size = brush.settings.size
        if not fonts[size] then
            fonts[size] = love.graphics.newFont(size)
        end
        love.graphics.setFont(fonts[size])

        -- Draw centered around the touch
        local width = fonts[size]:getWidth(brush.settings.text)
        local height = fonts[size]:getHeight(brush.settings.text)
        love.graphics.print(brush.settings.text, x, y, 0, 1, 1, 0.5 * width, 0.5 * height)
    end)
end

return brush
