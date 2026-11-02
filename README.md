# Forzacraft

Forza Horizon-style racing modpack for Minecraft 1.20.1 (Forge 47.4.28), set in a fictional Vietnam.
Design decisions: [docs/decisions.md](docs/decisions.md). Sizes: [docs/scale.md](docs/scale.md).

## Build and test

Requires JDK 17. In this sandbox, first run
`. /projects/sandbox/.tools/env.sh && export PATH=$JAVA_HOME/bin:$PATH`.

| Command | What it does |
|---|---|
| `./gradlew build --no-daemon` | compile, unit tests, mod jar in `build/libs/` |
| `./gradlew test --no-daemon` | JUnit tests (physics, camera maths, model loader) |
| `./gradlew runGameTestServer --no-daemon` | run every `forzacraft` GameTest on a headless server |
| `bash tools/ci/server-smoke.sh` | boot a dedicated server, run `fc selftest`, check the log |
| `COMPAT=server bash tools/ci/server-smoke.sh` | same, with Distant Horizons on the classpath |
| `bash tools/ci/done-check.sh` | build + GameTests + server smoke (phase DONE CHECK) |
| `./gradlew runClient -PcompatClient` | dev client with Distant Horizons, Embeddium and Oculus |

## Art

Blockbench scripts in `art/blockbench/` build the models (`node tools/bb/bbexec.mjs <script.js>`);
Aseprite Lua scripts in `art/aseprite/` paint the textures. See `.kiro/steering/art-tools.md`.
