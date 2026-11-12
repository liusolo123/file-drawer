import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const TIMELINE = JSON.parse(
  fs.readFileSync(path.join(ROOT, 'src', 'timeline.json'), 'utf8')
);

async function openPage(browser) {
  const page = await browser.newPage({
    viewport: { width: 1920, height: 1080 },
    deviceScaleFactor: 1,
  });
  await page.goto('file://' + path.join(ROOT, 'src', 'scene.html'));
  await page.evaluate((tl) => {
    window.TIMELINE = tl;
    window.renderFrame(0);
  }, TIMELINE);
  await page.evaluate(() => document.fonts.ready);
  return page;
}

async function main() {
  const args = process.argv.slice(2);
  const launchOptions = process.env.CHROMIUM_PATH
    ? { executablePath: process.env.CHROMIUM_PATH }
    : {};
  const browser = await chromium.launch(launchOptions);
  const page = await openPage(browser);

  if (args[0] === '--at') {
    const t = parseFloat(args[1]);
    const out = path.resolve(ROOT, args[2] || `out/preview-${t}.png`);
    await page.evaluate((tt) => window.renderFrame(tt), t);
    await page.screenshot({ path: out });
    console.log('preview:', out);
    await browser.close();
    return;
  }

  const fps = 30;
  const frames = Math.ceil(TIMELINE.total * fps);
  const dir = path.join(ROOT, 'frames');
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });

  for (let i = 0; i < frames; i++) {
    await page.evaluate((t) => window.renderFrame(t), i / fps);
    await page.screenshot({
      path: path.join(dir, `frame_${String(i).padStart(5, '0')}.png`),
    });
    if (i % 90 === 0) console.log(`frame ${i}/${frames}`);
  }

  await browser.close();
  console.log(`rendered ${frames} frames`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
