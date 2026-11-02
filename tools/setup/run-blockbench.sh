#!/usr/bin/env bash
# Foreground Blockbench on Xvfb :99 with DevTools on 127.0.0.1:9222.
# Start with the workspace MCP proc_start, ready_regex "DevTools listening".
# WebGL works through SwiftShader (software); --disable-gpu breaks Blockbench.
. /projects/sandbox/.tools/env.sh
cd "$TOOLS/blockbench"
exec ./blockbench --no-sandbox --disable-dev-shm-usage \
  --use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader --ignore-gpu-blocklist \
  --remote-debugging-port=9222 --remote-allow-origins=*
