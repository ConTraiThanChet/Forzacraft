#!/usr/bin/env node
// Run JavaScript inside the running Blockbench window via Chrome DevTools Protocol.
// Usage:
//   node tools/bb/bbexec.mjs script.js        # run a file
//   node tools/bb/bbexec.mjs -e "code"        # run inline code
//   node tools/bb/bbexec.mjs --screenshot out.png
// The code runs in Blockbench's renderer, with the full Blockbench API
// (Project, Cube, Group, Texture, Codecs, Canvas, newProject, ...).
// The value of the last expression is printed as JSON. Promises are awaited.
import fs from 'node:fs';

const PORT = process.env.BB_DEVTOOLS_PORT || 9222;
const args = process.argv.slice(2);
if (!args.length) {
  console.error('usage: bbexec.mjs <file.js> | -e "<code>" | --screenshot <out.png>');
  process.exit(2);
}

const targets = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
const page = targets.find(t => t.type === 'page' && t.url.includes('index.html'));
if (!page) { console.error('Blockbench page not found. Is it running? (tools/setup/start-art-tools.sh)'); process.exit(1); }

const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
let nextId = 1; const pending = new Map();
ws.onmessage = ev => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
};
const send = (method, params = {}) => new Promise(res => {
  const id = nextId++; pending.set(id, res); ws.send(JSON.stringify({ id, method, params }));
});

let exitCode = 0;
if (args[0] === '--screenshot') {
  const r = await send('Page.captureScreenshot', { format: 'png' });
  fs.writeFileSync(args[1], Buffer.from(r.result.data, 'base64'));
  console.log(args[1]);
} else {
  const code = args[0] === '-e' ? args[1] : fs.readFileSync(args[0], 'utf8');
  const wrapped = `(async () => { ${code.includes('return') ? code : 'return (' + code + '\n)'} })()`;
  const r = await send('Runtime.evaluate', { expression: wrapped, awaitPromise: true, returnByValue: true, timeout: 600000 });
  if (r.result?.exceptionDetails) {
    console.error(r.result.exceptionDetails.exception?.description || JSON.stringify(r.result.exceptionDetails));
    exitCode = 1;
  } else {
    const value = r.result?.result?.value ?? null;
    // Node's fs is not reachable from the renderer, so scripts return
    // { __files: { "/abs/path": "text content" | {base64: "..."} }, ...rest }
    // and this runner writes them to disk.
    if (value && typeof value === 'object' && value.__files) {
      for (const [p, c] of Object.entries(value.__files)) {
        fs.mkdirSync(p.substring(0, p.lastIndexOf('/')) || '.', { recursive: true });
        fs.writeFileSync(p, typeof c === 'string' ? c : Buffer.from(c.base64, 'base64'));
        console.error('wrote ' + p);
      }
      delete value.__files;
    }
    console.log(JSON.stringify(value, null, 2));
  }
}
ws.close();
process.exit(exitCode);
