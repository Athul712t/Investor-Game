// Visual check: serves build/web and saves phone-size screenshots.
// Usage: flutter build web --no-web-resources-cdn && node tool/shot.mjs <out-dir> [route] [x,y taps...]
// Example: node tool/shot.mjs /tmp/shots /#/play/runner 195,560 wait:1500 195,400
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const [out = 'shots', route = '/', ...steps] = process.argv.slice(2);
const root = 'build/web';
const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.ttf': 'font/ttf', '.otf': 'font/otf', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  let f = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) f = path.join(root, 'index.html');
  res.writeHead(200, { 'content-type': types[path.extname(f)] ?? 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
}).listen(0);
const port = server.address().port;

fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 });
page.on('pageerror', (e) => console.log('PAGE ERROR', e.message));
page.on('console', (m) => m.type() === 'error' && console.log('CONSOLE', m.text()));
await page.goto(`http://localhost:${port}${route}`);
await page.waitForTimeout(4000);
let n = 0;
const snap = async () => page.screenshot({ path: path.join(out, `${String(n++).padStart(2, '0')}.png`) });
await snap();
for (const s of steps) {
  if (s.startsWith('wait:')) await page.waitForTimeout(+s.slice(5));
  else if (s.startsWith('swipe:')) {
    const [x1, y1, x2, y2] = s.slice(6).split(',').map(Number);
    await page.mouse.move(x1, y1); await page.mouse.down(); await page.mouse.move(x2, y2, { steps: 6 }); await page.mouse.up();
    await page.waitForTimeout(500);
  } else {
    const [x, y] = s.split(',').map(Number);
    await page.mouse.click(x, y);
    await page.waitForTimeout(700);
  }
  await snap();
}
await browser.close();
server.close();
console.log(`saved ${n} screenshots to ${out}`);
