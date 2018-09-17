-- This file should return a table with a bunch of properties defining the brush. We define a
-- variable `brush` for this table, set properties in it, then return it at the bottom.
local brush = {}

-- `brush.settingsShape` defines shape of the settings the brush takes. The app automatically shows
-- controls to let the user edit these settings. The values set by the user are available as
-- `brush.settings.<settingName>`.
brush.settingsShape = {
    -- Let's define a setting called `radius`. We'll use this setting in `brush.paint` below.
    radius = {
        -- This is a number setting with a default value of 10.
        type = 'number',
        default = 10,

        -- Style this setting's user control as a slider with a minimum value of 0 and a maximum
        -- value of 40.
        style = 'slider',
        min = 0,
        max = 40,
    },

    -- Here's how you could define an image setting. It's initial value is `nil`. When set, it's
    -- value is a `Image` object (see https://love2d.org/wiki/Image). You can draw this with
    -- `love.graphics.draw` for example. Note that the image is usually pretty large so you may want
    -- to draw it with scaling.
    --
    --   myImageSetting = { type = 'image' },

    -- Here's an example text setting. It's value is just a string when set.
    --
    --   myTextSetting = { type = 'text', default = 'default text' },

    -- Here's an example color setting. When set, it's a table `c` with `c.r`, `c.g`, `c.b` and
    -- `c.a` being numbers giving the red, blue, green and alpha components of the color. You can
    -- use this in `love.graphics.setColor` for example. This one is red by default.
    --
    --   myColorSetting = { type = 'text', default = { r = 1, g = 0, b = 0, a = 1 } }
}

-- The app calls the `brush.paint` function when the user paints a brush stroke. `x`, `y` gives the
-- end point of the brush stroke, and `x - dx`, `y - dy` give the start point (`dx, `dy` are the
-- delta motion).
function brush.paint(x, y, dx, dy)
    -- You can use any functions from `love.graphics` here. See:
    -- https://love2d.org/wiki/love.graphics

    -- This example draws circle outlines with a radius given by the `radius` setting, and a random
    -- color.
    love.graphics.setColor(math.random(), math.random(), math.random())
    love.graphics.ellipse('line', x, y, brush.settings.radius, brush.settings.radius)

    -- Here's how you could use the image and color settings above.
    --
    --   local color = brush.settings.myColorSetting
    --   love.graphics.setColor(color.r, color.g, color.b, color.a)
    --   local image = brush.settings.myImageSetting
    --   if image then
    --       -- Scale it down and draw it centered around `x`, `y`.
    --       local w, h = image:getDimensions()
    --       local scale = love.graphics.getWidth() / w
    --       love.graphics.draw(image, x, y, 0, scale, scale, 0.5 * w, 0.5 * h)
    --   end
end

return brush