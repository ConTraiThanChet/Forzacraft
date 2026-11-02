---
inclusion: always
---

# Art tools in this sandbox (Blockbench + Aseprite, no MCP)

Root filesystem and `/root` are read-only; `/tmp` is private per shell command.
Everything lives in `/projects/sandbox/.tools` (outside the repo, never commit it).
Always `. /projects/sandbox/.tools/env.sh` first (sets PATH, LD_LIBRARY_PATH, DISPLAY=:99,
HOME, GRADLE_USER_HOME, JAVA_HOME=JDK 17 for Forge 1.20.1).
If `.tools` is missing (fresh sandbox), run `tools/setup/install-art-tools.sh` (Aseprite build ≈ 20-40 min).

## Long-running processes
Start them with the workspace MCP `proc_start` (shell `nohup`/`&` children are killed when the command ends):
1. Xvfb: `proc_start {name:"xvfb", command:"bash /projects/sandbox/Forzacraft/tools/setup/run-xvfb.sh"}`
2. Blockbench: `proc_start {name:"blockbench", command:"bash /projects/sandbox/Forzacraft/tools/setup/run-blockbench.sh", ready_regex:"DevTools listening"}`
Check `proc_status` first and reuse running ones. Stop with `proc_stop`; `pkill` from bash cannot see them.

## Blockbench (v5.2.2, GeckoLib plugin installed)
Driven through Chrome DevTools: `node tools/bb/bbexec.mjs <script.js>` or `-e "<code>"`.
The script runs in Blockbench's renderer with the full API (`newProject(Formats.geckolib_model)`,
`Group`, `Cube`, `Texture`, `Codecs.*.compile()`, `Animator`, `Canvas`).
- Last expression / `return` value is printed as JSON; promises are awaited.
- No Node `fs` in the renderer. To write files return `{ __files: { "/abs/path": "text" | {base64} } }`.
  For textures use `texture.getBase64()` / canvas `toDataURL()` and pass the base64 part.
- Visual check: `node tools/bb/bbexec.mjs --screenshot /path/out.png`, then view the PNG.
- Example: `tools/bb/examples/smoke-test.js`.

## Aseprite (CLI only)
`aseprite -b --script-param key=value --script file.lua`; see `tools/aseprite/README.md`.
Self-compiled build: personal use only, never commit the binary.
