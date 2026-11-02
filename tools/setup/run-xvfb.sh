#!/usr/bin/env bash
# Foreground Xvfb on :99. Start it with the workspace MCP proc_start (not nohup/&,
# the sandboxed shell kills background children when the command ends).
. /projects/sandbox/.tools/env.sh
cd "$TOOLS/xvfb-run"
exec "$TOOLS/bin/Xvfb" :99 -screen 0 1920x1080x24 -nolisten tcp -xkbdir "$TOOLS/xvfb-run/xkb"
