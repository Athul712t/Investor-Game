import { chromium } from 'playwright';
import fs from 'node:fs';
const html = `<body style="margin:0;background:transparent"><div id="i" style="width:512px;height:512px;border-radius:112px;
background:radial-gradient(circle at 30% 20%,#2b3a7a 0%,#151B36 55%,#0B1022 100%);position:relative;overflow:hidden">
<svg width="512" height="512" viewBox="0 0 512 512" style="position:absolute">
<defs><linearGradient id="g" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#2EE6A6"/><stop offset="1" stop-color="#4CC9F0"/></linearGradient></defs>
<rect x="96" y="300" width="64" height="116" rx="18" fill="#8B7CFF"/>
<rect x="192" y="244" width="64" height="172" rx="18" fill="#4CC9F0"/>
<rect x="288" y="180" width="64" height="236" rx="18" fill="#2EE6A6"/>
<path d="M92 250 L196 176 L262 214 L400 104" fill="none" stroke="url(#g)" stroke-width="30" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M330 96 L412 92 L408 174" fill="none" stroke="#4CC9F0" stroke-width="30" stroke-linecap="round" stroke-linejoin="round"/>
<circle cx="392" cy="360" r="62" fill="#FFC857"/><circle cx="392" cy="360" r="44" fill="none" stroke="#C98F1A" stroke-width="8"/>
<text x="392" y="384" font-family="Arial" font-weight="900" font-size="64" text-anchor="middle" fill="#8A5F00">₹</text>
</svg></div></body>`;
const b = await chromium.launch();
const sizes = { mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 };
for (const [d, px] of Object.entries(sizes)) {
  const p = await b.newPage({ viewport: { width: 512, height: 512 }, deviceScaleFactor: px / 512 });
  await p.setContent(html);
  await (await p.$('#i')).screenshot({ path: `android/app/src/main/res/mipmap-${d}/ic_launcher.png`, omitBackground: true });
  await p.close();
}
for (const [name, px] of [['web/icons/Icon-192.png', 192], ['web/icons/Icon-512.png', 512], ['web/icons/Icon-maskable-192.png', 192], ['web/icons/Icon-maskable-512.png', 512], ['web/favicon.png', 32], ['docs/icon.png', 256]]) {
  const p = await b.newPage({ viewport: { width: 512, height: 512 }, deviceScaleFactor: px / 512 });
  await p.setContent(html);
  await (await p.$('#i')).screenshot({ path: name, omitBackground: true });
  await p.close();
}
await b.close();
