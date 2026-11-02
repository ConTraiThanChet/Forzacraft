# Implementation Plan: Forzacraft (Forza Horizon-style Forge 1.20.1 modpack, fictional Vietnam)

Repo `/projects/sandbox/Forzacraft`, branch `main`, no worktree. After EVERY completed item below:
`git add <files> && git commit -m "<conventional msg>" && git push origin main` (never force-push).
Every shell command starts with `. /projects/sandbox/.tools/env.sh && export PATH=$JAVA_HOME/bin:$PATH`
(the `java` shim on PATH is JDK 25; Forge 1.20.1 needs JDK 17 from `$JAVA_HOME`).
Writer steps read `.agents/inbox.md` at the start of every turn. Open points go to `.agents/questions.md`
(send_message severity `info`), the dependent item is marked `DEFERRED (Qn)`, and work continues. Never pause.

Phase order is the user-approved one. Every phase ends with the **DONE CHECK** (item P.x "DONE CHECK"):
1. `./gradlew build --no-daemon` passes with JDK 17.
2. `./gradlew runGameTestServer --no-daemon` exits 0 (all `forzacraft` GameTests pass).
3. `bash tools/ci/server-smoke.sh` boots a headless dedicated server with the mod, runs `fc selftest`, stops, and finds no `ERROR`/`Exception` lines in `run/logs/latest.log`.
4. Every asset added in the phase has a Blockbench screenshot in `art/screenshots/` that the agent viewed.
5. Phase features are demonstrated by GameTests / JUnit / server-side commands, with evidence written into the FEAT `findings`.
(Optional, last phase only: client visual check under Xvfb if software OpenGL works.)

## Architecture decisions taken in this plan (documented in `docs/decisions.md`, item 1.2)

- **One mod**, modid `forzacraft`, package `vn.forzacraft`, Forge `1.20.1-47.4.28` (current recommended), official mappings, Mixins enabled.
- **Physics core is pure Java** (`vn.forzacraft.physics`, no Minecraft imports) so it is JUnit-testable; the entity layer adapts it to the world.
- **Netcode:** the driving client simulates its own car (vanilla boat pattern, `isControlledByLocalInstance`) and sends state to the server, which sanity-checks speed/position and broadcasts; bots and police are simulated on the server. Car-vs-car collisions and damage are resolved on the server. Works for LAN and dedicated server.
- **Rendering is self-contained:** models are authored in Blockbench in the GeckoLib/Bedrock `geo.json` format, but the mod ships its own small `geo.json` loader + renderer (bone hierarchy, pivots, rotations, UVs; wheels spin/steer from code). This works whatever the answer to Q1 (library mods); switching to GeckoLib later is `DEFERRED (Q1)` and not planned.
- **Language:** every UI string is a translation key; Vietnamese text lives in `vi_vn.json` and is copied into `en_us.json` so English-locale clients also see Vietnamese.
- **Scale:** player and cars are 1 block = 1 m (player 1.8 blocks, sedan 4.5×1.8×1.45). The environment is scaled ×2 horizontally and vertically relative to real life (lane 7 blocks, storey 6 blocks, trees ×2). Refinement (justified in the doc): things the player physically uses on foot (door openings ≥ 3 blocks high, stair steps, seats, railings) stay at walkable size so walking around still works; and terrain relief is stylised (snowy peaks ≈ y 560, not real ×2 heights) because a dimension cannot hold 6 km of height. The ×2 factor is not reverted.
- **Prebuilt map production/distribution:** no world data in git. A map is a small JSON definition in the repo (`data/forzacraft/forzacraft_maps/<id>.json`: seed, radius, zone layout, towns, landmarks, waterfalls, route specs). The mod's own deterministic chunk generator (`forzacraft:map` codec) turns it into terrain, roads, scenery and structures on demand, identically on every machine, so a server only needs the mod jar. Each map is its own dimension (`forzacraft:<map_id>`), so more maps = more JSON files. Road network and race routes are planned deterministically from the definition at server start and cached under `<world>/forzacraft/`. Optional pre-generation (`fc map pregen`) exists for server performance; shipping pre-generated region files as a release artifact is `DEFERRED (Q2)`.
- **Map radius** defaults to 12 000 blocks (12 km at the player/car scale of 1 block = 1 m), a single value in the map JSON; Q3 asks the user whether 12 km should instead be measured in scaled-scenery terms (24 000 blocks).
- **Camera:** on foot, vanilla F5 is unchanged. In a car, the vanilla perspective key cycles the mod modes Hành động (chase) → Cổ điển (classic) → Trong xe (in-car) → Điện ảnh (cinematic), implemented with a `Camera.setup` mixin.
- **Explosions** use `Level.ExplosionInteraction.NONE`: entities take damage, blocks are never destroyed.
- **Height:** map dimensions use a custom dimension type `min_y = -64`, `height = 704` (top y 639), sea level 63.

## Phase 1: core driving + camera, one drivable car

- [x] 1.1 Scaffold the Forge MDK project.
      Download `https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-47.4.28/forge-1.20.1-47.4.28-mdk.zip`, copy its Gradle wrapper, `build.gradle`, `settings.gradle`, `gradle.properties`, set `mod_id=forzacraft`, `mod_name=Forzacraft`, `mod_group_id=vn.forzacraft`, `mapping_channel=official`, license `All Rights Reserved`; add Mixin (MixinGradle + `forzacraft.mixins.json`), JUnit 5 for `test`, `forge.enabledGameTestNamespaces=forzacraft` in all runs; main class `vn.forzacraft.Forzacraft` with `@Mod`. Add `.gitignore` (build/, run/, .gradle/, out/, *.log, logs/). Add property-gated compat deps from the Modrinth maven (`https://api.modrinth.com/maven`): `-PcompatServer` adds Distant Horizons 3.3.3-1.20.1 (`fg.deobf`), `-PcompatClient` adds DH + Embeddium 0.3.31+mc1.20.1 + Oculus 1.20.1-1.8.0.
      Files: build.gradle, settings.gradle, gradle.properties, gradlew, gradlew.bat, gradle/wrapper/*, .gitignore, src/main/java/vn/forzacraft/Forzacraft.java, src/main/resources/META-INF/mods.toml, src/main/resources/pack.mcmeta, src/main/resources/forzacraft.mixins.json
      Verify: `./gradlew build --no-daemon` succeeds (first run decompiles, allow ~15 min).

- [x] 1.2 Write `docs/decisions.md` with every decision in the section above (scale with numbers and justification for the refinement, map production/distribution, netcode, renderer vs Q1, language, camera, explosion rule, dimension height, radius vs Q3), plus `docs/scale.md` with the reference table (player 1.8; hatchback 3.9×1.7×1.5; sedan 4.5×1.8×1.45; coupe 4.4×1.9×1.3; pickup 5.3×1.9×1.8; lane 7; 2-lane road 14 + 2×2 shoulder; highway 4 lanes 28 + median 4; dirt track 8–10; storey 6; door opening 3×2; palm 40–56 tall; rice terrace step 2–4 high). Q3 is already registered in `.agents/questions.md` by the planner. Update README with build/test commands.
      Files: docs/decisions.md, docs/scale.md, README.md, .agents/questions.md
      Verify: docs render as markdown; `./gradlew build --no-daemon` still passes.

- [ ] 1.3 Create the verification tooling.
      `tools/ci/server-smoke.sh`: writes `run/eula.txt` (`eula=true`), launches `./gradlew runServer --no-daemon --args=nogui` with stdin from a FIFO, waits up to 15 min for `Done (`, sends `fc selftest` then `stop`, exits non-zero if `run/logs/latest.log` has `ERROR` or `Exception` lines or `selftest` did not print `FORZACRAFT SELFTEST OK`. `tools/ci/done-check.sh` runs build, `runGameTestServer`, server-smoke in order. `tools/gen/make_platform_nbt.py` (stdlib gzip + hand-written NBT writer) generates GameTest structure templates (`data/forzacraft/structures/gametest/platform_64.nbt`: 64×4×64, stone floor; `track_oval.nbt` is generated in 3.x). Register the `fc` root command with `selftest` (prints `FORZACRAFT SELFTEST OK` after checking registries load) and one trivial GameTest.
      Files: tools/ci/server-smoke.sh, tools/ci/done-check.sh, tools/gen/make_platform_nbt.py, src/main/java/vn/forzacraft/command/FcCommand.java, src/main/java/vn/forzacraft/gametest/SmokeGameTests.java, src/main/resources/data/forzacraft/structures/gametest/platform_64.nbt
      Verify: `bash tools/ci/done-check.sh` exits 0.

- [ ] 1.4 Implement the pure-Java physics core with JUnit tests.
      `VehicleSpec` (mass, dimensions, wheelbase, track, CoG height, engine torque curve, redline, gear ratios, final drive, drivetrain FWD/RWD/AWD, brake torque, steering lock, suspension stiffness/damping/travel, tyre grip and per-surface multipliers), `VehicleInput` (throttle, brake, steer, handbrake), `VehicleState` (pos, yaw/pitch/roll quaternion, linear/angular velocity, wheel spin, suspension compression, rpm, gear), `GroundQuery` interface (ray → hit distance, normal, `Surface` enum ASPHALT/DIRT/GRASS/SAND/SNOW/ICE/WATER), `TyreModel` (simplified Pacejka with combined slip), `Drivetrain` (auto gearbox with shift points, reverse), `VehicleSim.step(state, input, spec, ground, dt)` with 4 substeps per tick, weight transfer and handbrake drift. JUnit: flat-ground 0–100 km/h time within spec range, top speed plateau, braking distance, steady-state cornering does not exceed grip, grass slower than asphalt, car comes to rest on slope with brake, no NaN over 10 000 random steps.
      Files: src/main/java/vn/forzacraft/physics/*.java, src/test/java/vn/forzacraft/physics/VehicleSimTest.java
      Verify: `./gradlew test --no-daemon` passes.

- [ ] 1.5 Hatchback model and texture (car 1, fictional name "Sao Mai", modeled on a compact hatchback, 3.9×1.7×1.5 m).
      Blockbench script builds the model in `Formats.geckolib_model` with 16 px = 1 block, bones `body`, `cabin`, `wheel_fl/fr/rl/rr` (pivot at hub), `steering_wheel`, `seat_driver` locator; exports `.bbmodel` source and `geo.json`; screenshots front-3/4, side, top next to a 1.8-block player reference cube. Aseprite Lua script paints a 256×256 texture (paint, glass, lights, tyres, interior) and exports PNG.
      Files: art/blockbench/cars/sao_mai.js, art/blockbench/cars/sao_mai.bbmodel, art/aseprite/cars/sao_mai.lua, src/main/resources/assets/forzacraft/geo/vehicle/sao_mai.geo.json, src/main/resources/assets/forzacraft/textures/entity/vehicle/sao_mai.png, art/screenshots/sao_mai_*.png
      Verify: `node tools/bb/bbexec.mjs --screenshot art/screenshots/sao_mai_side.png` then view each PNG; car length/height vs player cube matches docs/scale.md.

- [ ] 1.6 Vehicle entity, ownership, enter/exit, input and sync (depends on 1.4).
      `VehicleEntity extends Entity` holding `VehicleState` + spec id; `WorldGroundQuery` adapts `GroundQuery` to block collision shapes and maps blocks to `Surface` via tag files `data/forzacraft/tags/blocks/surface_*.json`; right-click to enter (driver seat; extra seats as passengers), vanilla sneak to exit beside the car, walking around afterwards is vanilla. Client keybind handling (W/S/A/D/Space while driving, R "Đặt lại xe" flips the car upright), `SimpleChannel` packets `C2SVehicleState`, `S2CVehicleState`, server sanity check (max speed × 1.2, max teleport distance). Spawn via `fc xe spawn <id>` (op) for now. `VehicleSpecRegistry` loads specs from `data/forzacraft/forzacraft_vehicles/*.json`. HUD: speed km/h, gear, rpm bar with Vietnamese labels. Lang keys in `vi_vn.json` copied to `en_us.json`.
      Files: src/main/java/vn/forzacraft/vehicle/*.java, src/main/java/vn/forzacraft/network/*.java, src/main/java/vn/forzacraft/client/input/*.java, src/main/java/vn/forzacraft/client/hud/VehicleHud.java, src/main/resources/data/forzacraft/forzacraft_vehicles/sao_mai.json, src/main/resources/data/forzacraft/tags/blocks/surface_*.json, src/main/resources/assets/forzacraft/lang/vi_vn.json, src/main/resources/assets/forzacraft/lang/en_us.json
      Verify: GameTests on `platform_64`: spawned car settles on the floor without falling through; server-driven input (test helper calls the sim with throttle=1) moves the car forward > 20 blocks in 5 s; player mounts and dismounts. `./gradlew runGameTestServer --no-daemon` passes.

- [ ] 1.7 Geo model loader + vehicle renderer (depends on 1.5, 1.6).
      `GeoModelLoader` parses `assets/forzacraft/geo/**/*.geo.json` on resource reload into baked bone trees; `VehicleRenderer` renders with `RenderType.entityCutoutNoCull` (Oculus-compatible standard entity pipeline), spins wheels from wheel angular speed, steers front wheels, applies body roll/pitch from suspension. JUnit test parses `sao_mai.geo.json` and checks bone names and bounding size 3.9×1.5×1.7 ±0.1.
      Files: src/main/java/vn/forzacraft/client/model/*.java, src/main/java/vn/forzacraft/client/render/VehicleRenderer.java, src/test/java/vn/forzacraft/client/model/GeoModelLoaderTest.java
      Verify: `./gradlew test --no-daemon` passes; `./gradlew build --no-daemon` passes.

- [ ] 1.8 Mod camera modes (depends on 1.6).
      `CameraMode` enum HANH_DONG/CO_DIEN/TRONG_XE/DIEN_ANH; `CameraController` computes position/rotation: chase = spring-damped follow with speed-based FOV, classic = rigid behind/above, in-car = driver eye locator from geo model, cinematic = auto-cycling trackside/orbit/low-front shots every 6 s. `CameraMixin` on `net.minecraft.client.Camera#setup` overrides position/rotation while the local player drives; vanilla perspective key is intercepted while driving to cycle modes (toast with Vietnamese name); on foot vanilla behaviour unchanged. Pure math in `vn.forzacraft.client.camera.CameraMath` with JUnit tests (spring converges, no jump > 2 blocks/tick at 200 km/h).
      Files: src/main/java/vn/forzacraft/client/camera/*.java, src/main/java/vn/forzacraft/mixin/client/CameraMixin.java, src/main/resources/forzacraft.mixins.json, src/test/java/vn/forzacraft/client/camera/CameraMathTest.java
      Verify: `./gradlew test build --no-daemon` passes; server-smoke shows mixin config applied without errors.

- [ ] 1.9 Phase 1 DONE CHECK. Also run `./gradlew runServer -PcompatServer` once via server-smoke (`COMPAT=server bash tools/ci/server-smoke.sh`) to prove DH coexists. Record evidence in FEAT-001 findings.
      Verify: `bash tools/ci/done-check.sh` exits 0; `COMPAT=server bash tools/ci/server-smoke.sh` exits 0.

## Phase 2: the 4 cars, shop and money (depends on Phase 1)

- [ ] 2.1 Models, textures, specs for cars 2–4: "Rồng Vàng" (mid-size sedan 4.5×1.8×1.45, RWD), "Bão Lửa GT" (sports coupe 4.4×1.9×1.3, RWD), "Trâu Rừng 4x4" (pickup/off-roader 5.3×1.9×1.8, AWD, high suspension, better dirt grip). Same Blockbench/Aseprite script pattern as 1.5 (no real brands, badges or trademark shapes).
      Files: art/blockbench/cars/{rong_vang,bao_lua_gt,trau_rung}.js|.bbmodel, art/aseprite/cars/*.lua, assets/forzacraft/geo/vehicle/*.geo.json, assets/forzacraft/textures/entity/vehicle/*.png, data/forzacraft/forzacraft_vehicles/*.json, art/screenshots/*
      Verify: screenshots viewed, each beside the player reference; JUnit `GeoModelLoaderTest` extended for all 4 sizes; JUnit spec tests: coupe fastest 0–100, pickup best dirt grip.

- [ ] 2.2 Player profile + economy (server-side `SavedData` `forzacraft_profiles` on the overworld keyed by UUID: balance in "đ", unlocked car ids, selected car). Car prices in the vehicle JSON (`price`: Sao Mai 0 and unlocked by default; Rồng Vàng 25 000; Bão Lửa GT 60 000; Trâu Rừng 4x4 120 000). `EconomyService.purchase` validates server-side (enough money, not owned). Op commands `fc tien xem|them|dat <player> <amount>`.
      Files: src/main/java/vn/forzacraft/economy/*.java, command additions in FcCommand.java
      Verify: GameTests: new profile owns only Sao Mai with 0 đ; purchase with too little money fails and balance unchanged; purchase with enough succeeds and unlocks; double purchase rejected; data survives save/load (serialize→deserialize round trip).

- [ ] 2.3 Garage/shop screen (key G "Ga-ra"): lists 4 cars with name, real-type class, stats bars, price/lock state; buttons "Mua" (buy) and "Lái" (spawn selected car near the player, despawning that player's previous car). C2S packets validated server-side; replace the op-only `fc xe spawn` for normal players. All text Vietnamese.
      Files: src/main/java/vn/forzacraft/client/screen/GarageScreen.java, src/main/java/vn/forzacraft/network/*, lang files
      Verify: GameTests drive the server handlers directly (spawn locked car rejected, spawn owned car creates exactly one entity owned by the player).

- [ ] 2.4 Phase 2 DONE CHECK; evidence in FEAT-002 findings.

## Phase 3: Racing mode with bots (depends on Phase 2)

- [ ] 3.1 Race data model: `RaceDefinition` JSON (`data/forzacraft/forzacraft_races/*.json`: id, display name, mode RACING/DIRT/WANTED, dimension, laps or point-to-point, ordered checkpoints {pos, width, heading}, grid slots ≥ 12, reward table) + `RaceRoute` racing-line spline through checkpoints. `tools/gen/make_platform_nbt.py` gains `track_oval.nbt`; `fc duongthu` (op) builds a flat asphalt test oval (14-wide, ~400 m lap) in the current dimension and registers race `duong_thu_oval`.
      Files: src/main/java/vn/forzacraft/race/*.java, data/forzacraft/forzacraft_races/duong_thu_oval.json, tools/gen/make_platform_nbt.py
      Verify: JUnit for checkpoint pass detection (segment–gate crossing) and spline arc-length; build passes.

- [ ] 3.2 `RaceSession` lifecycle on the server: lobby (race start marker entity "Điểm xuất phát" or `fc dua tham-gia <race>`), 30 s join window, fill with bots up to max(12, players), grid placement, 3-2-1 countdown with inputs frozen, checkpoint/lap tracking, wrong-way + respawn to last checkpoint, positions, finish, results screen, rewards paid into economy (1st 10 000 … participation 1 000 đ), cleanup of bot cars. Network: race HUD (position x/12, lap, time, next checkpoint marker).
      Files: src/main/java/vn/forzacraft/race/*.java, src/main/java/vn/forzacraft/client/hud/RaceHud.java, network packets, lang files
      Verify: GameTest: one fake player + 11 bots created; race ends; results ordered; reward credited.

- [ ] 3.3 `BotDriver` on the server: follows the racing line with look-ahead pure-pursuit steering, curvature-based target speed, PID throttle/brake, lane offset for overtaking, simple avoidance of cars ahead, skill parameter (0.85–1.0 of ideal speed) for spread; uses the same `VehicleSim`. Car-vs-car collision: OBB SAT + impulse in `vn.forzacraft.physics.Collision` (JUnit), applied on the server to all race cars.
      Files: src/main/java/vn/forzacraft/ai/*.java, src/main/java/vn/forzacraft/physics/Collision.java, src/test/java/vn/forzacraft/physics/CollisionTest.java
      Verify: GameTest: 12 bots complete 2 laps of `track_oval` within a time limit, none stuck > 10 s; JUnit collision conserves momentum within 5% and separates overlap.

- [ ] 3.4 Phase 3 DONE CHECK; evidence in FEAT-003 findings.

## Phase 4: the 12 km-radius map and race routes (depends on Phase 3)

- [ ] 4.1 Map system: `MapDefinition` codec + reload listener for `data/forzacraft/forzacraft_maps/*.json`; dimension type `forzacraft:map_tall` (min_y −64, height 704); per map a `dimension/<id>.json` level stem using chunk generator codec `forzacraft:map` with biome source `forzacraft:map_zones`; world border at radius; `fc map tp <id>` and `fc map list`. Custom biomes (`data/forzacraft/worldgen/biome/*.json`): dong_que (countryside), thanh_pho (city), canh_dong (paddy fields), rung (forest), thac_nuoc (waterfall valley), nui_tuyet (snowy mountains), ruong_bac_thang (rice terraces), bai_bien (blue beach), bien (sea), with matching grass/water/sky colours.
      Files: src/main/java/vn/forzacraft/world/map/*.java, data/forzacraft/dimension_type/map_tall.json, data/forzacraft/worldgen/biome/*.json
      Verify: GameTest/serverside: map registry lists the test map; build passes.

- [ ] 4.2 Terrain generator `ForzaChunkGenerator`: deterministic heightfield from map seed + zone layout (Voronoi zones blended over 256 blocks, each zone a height profile: flat paddies y 64–68, rolling countryside, forest hills, terraces as quantised contour steps 2–4 high on slopes, snowy massif to ~y 560 with snow line y 380, cliffs + plunge pools for waterfalls, beach shelf + turquoise shallows); implements `fillFromNoise`, `buildSurface`, `getBaseHeight`, `getBaseColumn` (needed by DH/structures); no caves. JUnit on the pure heightfield sampler: same seed → same heights; continuity across chunk borders; heights inside dimension bounds.
      Files: src/main/java/vn/forzacraft/world/gen/*.java, src/test/java/vn/forzacraft/world/gen/HeightfieldTest.java
      Verify: `./gradlew test`; server-smoke with `fc map tp xu_rong` generates spawn chunks without errors.

- [ ] 4.3 Road network: `RoadPlanner` connects towns/landmarks from the map JSON by A* on a 32-block grid with slope/water/zone costs, builds smoothed splines with a road class (highway 28+4, main road 14+2×2, rural 10, dirt 8–10), grades terrain along roads (cut/fill, max grade 8%, bridges over water, tunnels avoided by routing), rasterised during chunk gen (asphalt with lane markings, dirt tracks with coarse dirt/path). Cached to `<world>/forzacraft/<map>/roads.dat`. City zone: grid streets.
      Files: src/main/java/vn/forzacraft/world/road/*.java, src/test/java/vn/forzacraft/world/road/RoadPlannerTest.java
      Verify: JUnit: network connected, every town reachable, grade ≤ 8%; deterministic for same seed.

- [ ] 4.4 First map definition `xu_rong` ("Xứ Rồng", radius 12 000 per Q3 default) with fictional regions inspired by Vietnam: a coastal city, delta paddies, northern rice terraces, a snowy massif, karst/forest belt with waterfalls, turquoise beaches and islets, countryside villages. Scenery placement (Phase-4 level, vanilla blocks + generated ×2 trees): palms, bamboo groves, banana groves, tropical broadleaf, pine on mountains, rice paddies (custom `lua` crop block in water with simple model), fences, rocks, flowers; city blocks as procedural ×2-scale buildings from block palettes (tube houses, apartments) until Phase 6 adds models. Anti-sparseness rule enforced by `fc map stats`: every 128×128 land cell has ≥ 40 scenery features and no road km passes > 400 blocks of featureless terrain; `fc map preview` writes a top-down PNG (zones, roads, heights) to `run/forzacraft/preview_xu_rong.png`.
      Files: data/forzacraft/forzacraft_maps/xu_rong.json, data/forzacraft/dimension/xu_rong.json, src/main/java/vn/forzacraft/world/scenery/*.java, src/main/java/vn/forzacraft/block/*.java
      Verify: `fc map preview` + `fc map stats` from server-smoke; view the preview PNG; stats pass.

- [ ] 4.5 Race routes on the map: route specs in the map JSON (sequence of towns/landmarks + mode + laps) resolved through the road network into `RaceDefinition`s at map load; at least 8 Racing routes and 3 Dirt routes spread over all regions (each route crosses ≥ 3 zone types); start markers spawned at route starts; `fc dua list`.
      Files: src/main/java/vn/forzacraft/race/MapRouteResolver.java, xu_rong.json
      Verify: GameTest/serverside: every route resolves, checkpoints lie on road surface, length within 3–15 km.

- [ ] 4.6 Performance + DH: `fc map pregen <radius>` (throttled, resumable) and confirm `COMPAT=server` server-smoke with DH generating LODs from the custom generator. Pre-generated distribution artifact: `DEFERRED (Q2)`.
      Verify: Phase 4 DONE CHECK + `COMPAT=server bash tools/ci/server-smoke.sh`; evidence in FEAT-004 findings.

## Phase 5: Dirt Racing, Wanted Racing, damage and explosions (depends on Phase 4)

- [ ] 5.1 Damage model: per-car health (in vehicle JSON), damage from collision impulse above threshold (car–car, car–wall, fall), visual damage stages (smoke particles at 50%, fire at 20%), performance loss (engine power ×0.7 below 30%), explosion at 0 via `level.explode(..., Level.ExplosionInteraction.NONE)`, occupants ejected and damaged, wreck respawn rules in races (respawn at last checkpoint after 5 s). Repair via garage spawn.
      Files: src/main/java/vn/forzacraft/vehicle/damage/*.java
      Verify: GameTest: high-speed wall crash damages; repeated crashes explode; every block in a 7×7×7 box around the explosion is unchanged afterwards; nearby entity damaged.

- [ ] 5.2 Dirt Racing: mode DIRT uses dirt routes from 4.5, surface multipliers favour AWD, dirt particle trails; reward table.
      Verify: GameTest: 12-car dirt race on a dirt test strip completes.

- [ ] 5.3 Wanted Racing (Need for Speed-style): police car model/texture "Cảnh Sát Xứ Rồng" (fictional livery on the sedan body) with light bar; ≥ 12 racers plus police bots; heat level 1–5 raises police count/aggression (pursuit AI = intercept + ram + roadblocks from level 3); bust meter fills when a racer is slow/boxed near police, busted = eliminated; finishing escapes; HUD heat stars and bust bar (Vietnamese).
      Files: src/main/java/vn/forzacraft/mode/wanted/*.java, src/main/java/vn/forzacraft/ai/PoliceDriver.java, art + assets for police car
      Verify: GameTest: police spawn and pursue; a stopped racer is busted within N s; heat rises over time; screenshot of police car viewed.

- [ ] 5.4 Phase 5 DONE CHECK; evidence in FEAT-005 findings.

## Phase 6: Vietnamese scenery models (depends on Phase 4; independent of Phase 5)

- [ ] 6.1 Plant models (Blockbench java_block format, ×2 scale, Aseprite textures): bamboo cluster, banana plant, coconut palm parts, lotus + lotus leaves, water hyacinth, rice stages, areca palm, bougainvillea, frangipani; registered as blocks with tags for surface/scenery.
- [ ] 6.2 Asian/Vietnamese objects and decorations: red lanterns, temple incense burner, stone lion, wayside shrine, conical hat rack, fruit stall, market umbrella, motorbike prop (fictional), plastic stools, electricity poles with wires, road signs in Vietnamese, wooden boats, fishing nets.
- [ ] 6.3 Houses and structures as NBT templates built from these blocks: tube house variants, French-colonial villa, stilt house, communal house (đình), pagoda with tiered roof, beach bar, rural house with tiled roof, petrol station (fictional brand); doors/stairs at walkable size per docs/scale.md.
- [ ] 6.4 Integrate into the map generator placement tables per zone (replaces Phase-4 block-palette buildings), regenerate preview + stats.
      Files (6.1–6.4): art/blockbench/scenery/**, art/aseprite/scenery/**, assets/forzacraft/models/block/**, assets/forzacraft/textures/block/**, assets/forzacraft/blockstates/**, src/main/java/vn/forzacraft/block/**, data/forzacraft/structures/scenery/**, src/main/java/vn/forzacraft/world/scenery/*
      Verify: screenshots for every model viewed; GameTest places each block and each structure template; `fc map stats` still passes; Phase 6 DONE CHECK; evidence in FEAT-006 findings.

## Phase 7: generated freeroam mode (depends on Phases 4 and 6)

- [ ] 7.1 Dimension `forzacraft:tu_do` ("Tự do ngẫu nhiên") using the same generator with a `ProceduralLayout` instead of a fixed map: infinite zones from seeded noise over 4096-block cells, roads planned per 2048-block region with deterministic edge connection points so they join across regions, scenery tables from Phase 6, no race markers; seed from world seed + `fc tudo moi` to roll a new seed.
      Files: src/main/java/vn/forzacraft/world/procedural/*.java, data/forzacraft/dimension/tu_do.json
      Verify: JUnit: roads continuous across region borders; same seed deterministic; `fc map stats` on sampled regions passes the anti-sparseness rule.
- [ ] 7.2 Mode entry: main menu-free entry via `fc tudo` and a "Chế độ" screen (modes: Tự do bản đồ, Tự do ngẫu nhiên, Đua xe, Đua địa hình, Đua truy nã).
- [ ] 7.3 Pack export: `DEFERRED (Q2)`. Optional client visual check under Xvfb with `-PcompatClient` if software OpenGL works.
- [ ] 7.4 Phase 7 DONE CHECK; evidence in FEAT-007 findings.

## Deferred items
- Using GeckoLib (or any library mod) instead of the built-in geo renderer: DEFERRED (Q1).
- Modpack export format and any pre-generated world artifact: DEFERRED (Q2).
- Map radius 12 000 vs 24 000 blocks: default 12 000, one JSON value; final value per Q3.

## Digest

Greenfield repo: today it contains only README.md (`# Forzacraft`), tools/ (bb/bbexec.mjs, setup scripts, aseprite README + smoke tests), .kiro/steering/art-tools.md, .agents/{inbox.md,questions.md (Q1, Q2)}. No Gradle project, no tests, no .gitignore. Commits: 2cb4945 initial, fe24ddc tools, f24e979 agent artifacts; `main` tracks origin through the Kiro GitHub gateway.

Verified in this sandbox:
- `. /projects/sandbox/.tools/env.sh` sets `JAVA_HOME=/root/.local/share/mise/installs/java/17.0.2` (17.0.2), but plain `java` on PATH is the mise shim = JDK 25 → prepend `$JAVA_HOME/bin`. System `gradle` is 8.14.6; use the MDK's `./gradlew` instead.
- Forge promotions: 1.20.1 recommended = latest = 47.4.28; MDK zip URL returns 200.
- Modrinth API + maven reachable: Distant Horizons `3.3.3-1.20.1` (forge+fabric), Embeddium `0.3.31+mc1.20.1`, Oculus `1.20.1-1.8.0`.
- python3 3.11, node 22, 8 cores, 30 GB RAM, 86 GB free.
- Blockbench is scripted via `node tools/bb/bbexec.mjs <script.js>`; files are written by returning `{__files:{path:text}}`; screenshot with `--screenshot out.png`. Xvfb/Blockbench must be started with workspace MCP `proc_start` (names `xvfb`, `blockbench`) per art-tools.md. Aseprite: `aseprite -b --script-param k=v --script file.lua`.
- Build/test commands (to exist after 1.1/1.3): `./gradlew build`, `./gradlew test`, `./gradlew runGameTestServer`, `bash tools/ci/server-smoke.sh`, `bash tools/ci/done-check.sh`. None pass today because no project exists.
