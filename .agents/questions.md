# Open questions for the user

Answer in `.agents/inbox.md` (append-only).

## Q1 — Library mods (status: open, deferred)
Beyond Oculus, Embeddium and Distant Horizons, may the modpack use library mods (e.g. GeckoLib for animated car models), or must everything be self-contained in our own mod?

## Q2 — Distribution format (status: open, deferred)
How should the modpack be distributed: CurseForge pack, Modrinth pack (.mrpack), or a plain zip?

## Q3 — Map radius: driving distance or scaled scenery? (status: open; default in use, value adjustable)
Players and cars are real size (1 block ≈ 1 m) while scenery is scaled ×2. The first map uses a radius of 12 000 blocks (12 km of driving at car scale). Should "radius 12 km" instead mean 12 km of ×2-scaled scenery, i.e. 24 000 blocks (4× the area, much longer generation)? The radius is one value in the map JSON, so either answer is cheap to apply.
