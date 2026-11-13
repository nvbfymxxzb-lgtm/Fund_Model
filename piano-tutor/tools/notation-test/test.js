// Checks the notation page in a real browser: every note the app expects must be found in the drawing.
// Run: node tools/notation-test/test.js <folder of exported xml> [screenshot folder]
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
(async () => {
  const xmlDir = process.argv[2];
  const shots = process.argv[3];
  const page = path.resolve(__dirname, '../../App/PianoTutor/Resources/notation/notation.html');
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 1180, height: 560 }, deviceScaleFactor: 1 });
  const p = await ctx.newPage();
  const errors = [];
  p.on('pageerror', e => errors.push(String(e)));
  await p.goto('file://' + page);
  let failed = 0;
  for (const f of fs.readdirSync(xmlDir).filter(f => f.endsWith('.musicxml')).sort()) {
    const id = f.replace('.musicxml', '');
    const xml = fs.readFileSync(path.join(xmlDir, f), 'utf8');
    const keys = JSON.parse(fs.readFileSync(path.join(xmlDir, id + '.keys.json'), 'utf8'));
    const info = await p.evaluate(([xml]) => window.notation.load(xml, 1.0), [xml]);
    const missing = await p.evaluate(([keys]) => window.notation.hasKeys(keys), [keys]);
    const ok = info.type === 'loaded' && missing.length === 0;
    if (!ok) failed++;
    console.log(`${ok ? 'ok  ' : 'FAIL'} ${id}: ${info.measures} measures, ${keys.length} expected notes, ${missing.length} not found ${missing.slice(0, 5).join(' ')} ${info.message || ''}`);
    if (shots) {
      await p.evaluate(([keys]) => { window.notation.setRange(0, 3); window.notation.mark(keys.slice(0, 6), 'correct'); window.notation.mark(keys.slice(6, 8), 'wrong'); window.notation.setCurrent(keys.slice(8, 11), false); }, [keys]);
      await p.screenshot({ path: path.join(shots, id + '.png') });
    }
  }
  if (errors.length) { console.log('page errors:', errors.slice(0, 3)); failed++; }
  await browser.close();
  process.exit(failed ? 1 : 0);
})();
