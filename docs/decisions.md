# Forzacraft architecture decisions

Forzacraft is a Forza Horizon-style racing modpack for Minecraft 1.20.1 (Forge), set in a fictional Vietnam.
This file records the decisions every later change builds on. Reference sizes are in [scale.md](scale.md).

## Platform

- One mod, modid `forzacraft`, Java package `vn.forzacraft`.
- Forge `1.20.1-47.4.28` (recommended build at project start), official Mojang mappings, Mixin 0.8.5.
- The only third-party mods in the pack are Oculus (shaders), Embeddium (rendering performance) and
  Distant Horizons (LOD terrain). Forzacraft never depends on them; it stays compatible by using the standard
  entity render pipeline and the vanilla chunk generator API. Build properties `-PcompatServer` (DH) and
  `-PcompatClient` (DH + Embeddium + Oculus) put them on the dev runtime classpath for testing.
- Multiplayer targets: LAN (integrated server) and dedicated server.

## Physics

- The vehicle simulation lives in `vn.forzacraft.physics` and imports nothing from Minecraft, so it is unit-tested
  with JUnit. The entity layer adapts it to the world through the `GroundQuery` interface.
- Model: rigid body with 4 ray-cast wheels, spring/damper suspension, simplified Pacejka tyres with combined slip,
  per-surface grip (asphalt, dirt, grass, sand, snow, ice, water), engine torque curve, automatic gearbox with
  reverse, FWD/RWD/AWD drivetrains, weight transfer and handbrake drift. Four substeps per 20 Hz tick.
- Handling target is "semi-realistic" like the original game: real masses, power and grip numbers, with assists
  (automatic gearbox, stability, generous steering) instead of a full simulator.

## Netcode

- The driving client simulates its own car (the vanilla boat pattern, `isControlledByLocalInstance`) and sends its
  state to the server (`C2SVehicleState`). The server sanity-checks speed (at most 1.2 × the spec top speed) and
  position jumps, then broadcasts (`S2CVehicleState`). Cars without a driver and server-driven cars (bots, police,
  GameTests) are simulated on the server.
- Car-vs-car collisions and damage are resolved on the server.

## Rendering

- Models are authored in Blockbench in the GeckoLib/Bedrock `geo.json` format (16 px = 1 block).
- The mod ships its own small `geo.json` loader and renderer (bone hierarchy, pivots, rotations, UVs). Wheels spin
  and steer from code; body roll/pitch come from the suspension state. It renders through
  `RenderType.entityCutoutNoCull`, the standard entity pipeline that Oculus shaders handle.
- This works whatever the answer to Q1 (library mods). Switching to GeckoLib is DEFERRED (Q1) and not planned.

## Language and naming

- Every UI string is a translation key. Vietnamese text lives in `assets/forzacraft/lang/vi_vn.json` and the same
  file is copied to `en_us.json`, so clients with an English locale also see Vietnamese.
- All car, place and race names are fictional. No real brands or logos. Cars are modelled on real vehicle classes
  and real dimensions.

## Scale

- Player and cars: 1 block = 1 m. The player is 1.8 blocks tall; a sedan is 4.5 × 1.8 × 1.45 blocks.
- Environment: ×2 horizontally and vertically relative to real life. A lane is 7 blocks (3.5 m × 2), a storey is
  6 blocks, trees are twice their real size.
- Why ×2: a real 3.5 m lane at 1 block = 1 m is too narrow for 12-car races with semi-realistic handling and
  Minecraft's coarse terrain; widening only the roads would make houses, trees and terraces look like toys next to
  them, so the whole environment is scaled to keep real-life proportions between road and scenery.
- Refinements, both kept small and justified:
  1. Things the player uses on foot keep walkable size: door openings are at least 3 blocks high and 2 wide
     (not 4+), stair steps are 1 block, seats and railings are player-sized. Otherwise walking around after
     leaving the car would mean climbing 2-block steps and reaching for door handles above the head.
  2. Terrain relief is stylised. Real ×2 heights would need about 6 km of vertical space for the snowy peaks;
     a Minecraft dimension cannot hold that. Peaks reach about y 560 in a 704-block-tall dimension.
- The ×2 factor itself is not reverted by these refinements.

## Prebuilt map: production and distribution

- No world data is stored in git. A map is a small JSON definition in the repository
  (`data/forzacraft/forzacraft_maps/<id>.json`): seed, radius, zone layout, towns, landmarks, waterfalls and route
  specs.
- The mod's deterministic chunk generator (codec `forzacraft:map`) turns the definition into terrain, roads,
  scenery and structures on demand, identically on every machine. A server only needs the mod jar.
- Each map is its own dimension (`forzacraft:<map_id>`), so adding maps means adding JSON files.
- The road network and race routes are planned deterministically from the definition at server start and cached
  under `<world>/forzacraft/`.
- Optional pre-generation (`fc map pregen`) exists for server performance. Shipping pre-generated region files as a
  release artifact is DEFERRED (Q2), together with the modpack export format.

## Map radius

- The first map's radius defaults to 12 000 blocks: 12 km of driving at the car scale of 1 block = 1 m. It is a
  single value in the map JSON.
- Q3 asks whether "12 km" should instead be measured in ×2-scaled scenery (24 000 blocks). Until answered the
  default stays 12 000.

## Dimension height

- Map dimensions use the custom dimension type `forzacraft:map_tall`: `min_y = -64`, `height = 704` (top y 639),
  sea level 63.

## Camera

- On foot, the vanilla F5 cycle is unchanged.
- In a car, the vanilla perspective key cycles the mod modes Hành động (chase) → Cổ điển (classic) →
  Trong xe (in-car) → Điện ảnh (cinematic). Implemented with a mixin on `net.minecraft.client.Camera#setup`;
  the maths is pure Java (`CameraMath`) and unit-tested.

## Explosions and damage

- Car explosions use `Level.ExplosionInteraction.NONE`: entities take damage, blocks are never destroyed.
- Cars collide physically, take damage and explode when damage exceeds their limit.

## Verification

Every phase ends with the DONE CHECK (`bash tools/ci/done-check.sh`): `./gradlew build` on JDK 17,
`./gradlew runGameTestServer`, and a headless dedicated-server smoke test that runs `fc selftest`.
