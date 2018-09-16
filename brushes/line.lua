local brush = {}

brush.settingsShape = {
    width = {
        type = 'number',
        default = 10,
        style = 'slider',
        min = 0,
        max = 50,
    },
}

function brush.paint(x, y, dx, dy)
    if brush.settings.width then
        love.graphics.setLineWidth(brush.settings.width)
    end
    love.graphics.line(x - dx, y - dy, x, y)
end

return brush