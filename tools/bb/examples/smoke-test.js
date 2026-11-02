// Smoke test: build a tiny Java block model, export it, return the JSON path.
newProject(Formats.java_block);
const g = new Group({ name: 'root', origin: [8, 0, 8] }).init();
new Cube({ name: 'base', from: [0, 0, 0], to: [16, 4, 16] }).addTo(g).init();
new Cube({ name: 'post', from: [6, 4, 6], to: [10, 16, 10] }).addTo(g).init();
Canvas.updateAll();
const out = '/projects/sandbox/.tools/home/bb-smoke.json';
// The renderer has no Node fs; return files and bbexec.mjs writes them.
return { __files: { [out]: Codecs.java_block.compile() }, cubes: Cube.all.length };
