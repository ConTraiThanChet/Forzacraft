# Aseprite (headless CLI)

Binary: `/projects/sandbox/.tools/bin/aseprite` (self-built, CLI only, Lua scripting on).
EULA: personal use only. Never commit or redistribute the binary; commit only `.aseprite` sources, Lua scripts and exported PNGs.

```bash
. /projects/sandbox/.tools/env.sh
# Run a Lua script with parameters (read them via app.params.name)
aseprite -b --script-param out=assets/tex/rice.png --script tools/aseprite/examples/smoke-test.lua
# Export an .aseprite file to PNG / sprite sheet
aseprite -b src/textures/car_body.aseprite --save-as out/car_body.png
aseprite -b anim.aseprite --sheet out/anim.png --data out/anim.json --format json-array
```

Lua API reference: https://www.aseprite.org/api/ (Sprite, Image, app.useTool, Palette, Color).
Pixel work is done with `Image:drawPixel(x, y, color)` or `app.useTool{...}`; save with `sprite:saveAs(path)`.
