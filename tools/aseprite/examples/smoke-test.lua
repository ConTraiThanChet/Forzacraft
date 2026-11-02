-- Smoke test: 16x16 rice-paddy-like texture with simple noise, saved as PNG.
-- aseprite -b --script-param out=/path/out.png --script smoke-test.lua
local out = app.params.out or "smoke.png"
local spr = Sprite(16, 16, ColorMode.RGB)
local img = spr.cels[1].image
math.randomseed(7)
for y = 0, 15 do
  for x = 0, 15 do
    local g = 140 + math.random(0, 40)
    if y % 4 == 0 then g = g - 40 end -- furrow lines
    img:drawPixel(x, y, app.pixelColor.rgba(70, g, 40, 255))
  end
end
spr:saveAs(out)
print("saved " .. out)
