#!/usr/bin/env node
/*
 * Record the WikiMusic showcase.
 *
 * The choreography is deliberately short: the front page, the songs list and
 * its controls, one rich song page (prose, tablature, chords, click track),
 * an artist and a genre page, and the same pages in dark mode.  It walks only
 * the happy path, and it fails rather than record a broken picture or a page
 * error: the GIF is the project's shop window, so a take that is not clean is
 * not worth encoding.
 *
 * Run it through `run.sh`, which starts the demo instance, Xvfb and Chrome
 * and then encodes the capture.  With DRY=1 it takes screenshots instead of
 * recording, which is the quick way to check a change to the choreography.
 */
const { chromium } = require('playwright-core');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const OUT = process.env.OUT || path.join(__dirname, 'out');
const SHOWCASE = process.env.SHOWCASE || path.join(OUT, 'showcase.json');
const DRY = process.env.DRY === '1';
const SHOTS = process.env.SHOTS === '1';
const CHECK = path.join(OUT, 'check');
const CAPTURE = path.join(OUT, 'capture.mkv');
const WIDTH = Number(process.env.WIDTH || 1440);
const HEIGHT = Number(process.env.HEIGHT || 900);

const showcase = JSON.parse(fs.readFileSync(SHOWCASE, 'utf8'));
const BASE = (process.env.BASE || showcase.base || 'http://localhost:50051')
  .replace(/\/$/, '');
const SONG = showcase.song.path;
const ARTIST = showcase.artist.path;
const GENRE = showcase.genre.path;
const SEARCH = showcase.search;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const T0 = Date.now();
const log = (...args) => console.log(
  ((Date.now() - T0) / 1000).toFixed(1).padStart(5), ...args);

// Everything the page asked for that did not arrive, and every uncaught
// error.  A favicon is allowed to be absent; a picture is not.
const problems = [];
const benign = /\/favicon\.ico$/;

function recordProblem(kind, detail) {
  if (benign.test(detail)) return;
  problems.push(`${kind}: ${detail}`);
}

const CURSOR = () => {
  const css = `
    #wm-demo-cursor {
      position: fixed !important; left: 0; top: 0;
      width: 21px; height: 21px; margin: -10.5px 0 0 -10.5px;
      border-radius: 9999px;
      border: 2px solid rgba(20,20,20,.85);
      background: rgba(255,255,255,.72);
      box-shadow: 0 2px 9px rgba(0,0,0,.35);
      z-index: 2147483647; pointer-events: none;
      transform: translate(var(--x, 0), var(--y, 0));
      transition: width 90ms, height 90ms, margin 90ms, background 90ms;
      box-sizing: border-box;
    }
    #wm-demo-cursor.down {
      width: 13px; height: 13px; margin: -6.5px 0 0 -6.5px;
      background: rgba(255,255,255,.95);
    }
    #wm-demo-cursor.on-dark {
      border-color: rgba(255,255,255,.92);
      background: rgba(25,25,25,.45);
    }
    #wm-demo-cursor.on-dark.down { background: rgba(255,255,255,.85); }
  `;
  const ensure = () => {
    if (document.getElementById('wm-demo-cursor')) return;
    const style = document.createElement('style');
    style.textContent = css;
    document.head.appendChild(style);
    const cursor = document.createElement('div');
    cursor.id = 'wm-demo-cursor';
    document.documentElement.appendChild(cursor);
    const move = (event) => {
      cursor.style.setProperty('--x', event.clientX + 'px');
      cursor.style.setProperty('--y', event.clientY + 'px');
      const theme = document.documentElement.getAttribute('data-theme');
      const dark = theme === 'dark'
        || (theme === null
            && window.matchMedia('(prefers-color-scheme: dark)').matches);
      cursor.classList.toggle('on-dark', !!dark);
    };
    window.addEventListener('mousemove', move, true);
    window.addEventListener('mousedown',
      () => cursor.classList.add('down'), true);
    window.addEventListener('mouseup',
      () => cursor.classList.remove('down'), true);
  };
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', ensure);
  } else {
    ensure();
  }
};

let browser;
let ffmpeg = null;
let stopped = false;

async function stopCapture() {
  if (!ffmpeg || stopped) return;
  stopped = true;
  log('stop capture');
  ffmpeg.kill('SIGINT');
  await new Promise((resolve) => ffmpeg.once('exit', resolve));
}

async function main() {
  fs.mkdirSync(CHECK, { recursive: true });

  browser = await chromium.connectOverCDP(
    `http://127.0.0.1:${process.env.CDP_PORT || 9222}`);
  const context = browser.contexts()[0];
  const page = context.pages()[0] || await context.newPage();
  await page.setViewportSize({ width: WIDTH, height: HEIGHT });

  page.on('requestfailed', (request) => {
    const failure = request.failure()?.errorText || '';
    // A document the next click superseded is cancelled, not missing.  An
    // aborted picture, script or stylesheet is still a problem.
    if (failure.includes('ERR_ABORTED') && request.resourceType() === 'document') {
      return;
    }
    recordProblem('request failed', `${failure} ${request.url()}`);
  });
  page.on('response', (response) => {
    if (response.status() >= 400) {
      recordProblem('HTTP ' + response.status(), response.url());
    }
  });
  page.on('pageerror', (error) => recordProblem('page error', String(error)));

  await context.addInitScript(CURSOR);
  await page.goto(BASE + '/', { waitUntil: 'load' });
  await page.evaluate(() => localStorage.setItem('data-theme', 'light'));
  await page.reload({ waitUntil: 'load' });
  await page.waitForTimeout(1200);
  await page.evaluate(CURSOR);
  await page.mouse.move(WIDTH * 0.57, HEIGHT * 0.52);
  await page.waitForTimeout(600);

  const theme = await page.evaluate(
    () => document.documentElement.getAttribute('data-theme'));
  if (theme !== 'light') throw new Error(`expected light mode, got ${theme}`);
  await assertHealthy(page, 'front page');

  let mouse = { x: WIDTH * 0.57, y: HEIGHT * 0.52 };

  async function glide(x, y, duration = 120) {
    const steps = Math.max(4, Math.round(duration / 30));
    const from = { ...mouse };
    for (let i = 1; i <= steps; i++) {
      const t = i / steps;
      const ease = t < 0.5
        ? 2 * t * t
        : 1 - Math.pow(-2 * t + 2, 2) / 2;
      await page.mouse.move(from.x + (x - from.x) * ease,
                            from.y + (y - from.y) * ease);
      await sleep(duration / steps);
    }
    mouse = { x, y };
  }

  async function center(locator) {
    const box = await locator.boundingBox();
    if (!box) throw new Error('no bounding box for ' + locator);
    return { x: box.x + box.width / 2, y: box.y + box.height / 2 };
  }

  async function clickOn(locator, { settle = 100, press = 75 } = {}) {
    const point = await center(locator);
    if (point.y < 4 || point.y > HEIGHT - 40) {
      throw new Error(`click target out of view at ${Math.round(point.x)},`
        + `${Math.round(point.y)}: ${locator}`);
    }
    await glide(point.x, point.y, 150);
    await sleep(settle);
    await page.mouse.down();
    await sleep(press);
    await page.mouse.up();
    await sleep(100);
  }

  async function moveAway() {
    await glide(WIDTH * 0.5, HEIGHT * 0.47, 90);
  }

  async function scrollTo(top, wait = 900) {
    await page.evaluate((y) => window.scrollTo(
      { left: 0, top: y, behavior: 'smooth' }), top);
    await sleep(wait);
    await page.evaluate(() => {
      if (scrollX !== 0) window.scrollTo(0, scrollY);
    });
  }

  async function scrollToLocator(locator, offset = 220, wait = 900) {
    const y = await locator.evaluate(
      (element) => element.getBoundingClientRect().top + window.scrollY);
    await scrollTo(Math.max(0, y - offset), wait);
  }

  async function shot(name) {
    if (!DRY || !SHOTS) return;
    await page.screenshot({ path: path.join(CHECK, name + '.png') });
  }

  async function waitUrl(pattern) {
    await page.waitForURL(pattern, { timeout: 20000 });
    await page.waitForLoadState('load', { timeout: 20000 }).catch(() => {});
    await page.evaluate(() => {
      if (scrollX !== 0) window.scrollTo(0, scrollY);
    });
    await sleep(150);
  }

  // A picture that failed to load has completed with no intrinsic size.  A
  // lazy picture that has not been reached yet has not completed, and is not
  // broken; the pages the recording visits scroll their pictures into view.
  async function assertHealthy(target, where) {
    const broken = await target.evaluate(() => [...document.images]
      .filter((image) => image.complete && image.naturalWidth === 0)
      .map((image) => image.currentSrc || image.src));
    if (broken.length) {
      throw new Error(`${where}: ${broken.length} broken image(s):\n  `
        + broken.join('\n  '));
    }
  }

  if (!DRY) {
    ffmpeg = spawn('ffmpeg', [
      '-y', '-loglevel', 'error',
      '-f', 'x11grab', '-draw_mouse', '0',
      '-video_size', `${WIDTH}x${HEIGHT}`,
      '-framerate', process.env.CAPTURE_FPS || '15',
      '-i', process.env.X11_DISPLAY || ':99.0',
      '-c:v', 'ffv1', '-level', '3', '-g', '1', '-pix_fmt', 'bgr0',
      CAPTURE,
    ], { stdio: ['ignore', 'ignore', 'inherit'] });
    await sleep(900);
  }

  log('home');
  await sleep(800);
  await scrollTo(840, 1600);
  await shot('01-home-shelf');
  await scrollTo(0, 650);
  await shot('02-home-top');

  log('songs list');
  await clickOn(page.locator('a[href="/songs"]').first());
  await waitUrl(/\/songs/);
  await sleep(750);
  await shot('03-songs');
  await assertHealthy(page, 'songs list');

  log('sort');
  const sort = page.locator('#sort-select');
  const sortBox = await center(sort);
  await glide(sortBox.x, sortBox.y, 150);
  await sleep(300);
  await page.selectOption('#sort-select', { label: 'Views - Descending' });
  await waitUrl(/sort=views-desc/);
  await sleep(650);
  await moveAway();
  await shot('04-songs-sorted');

  // Large tiles: the covers are the point, and at medium the grid reads as a
  // wall of small postage stamps once the GIF is scaled into the README.
  log('tile size large');
  await clickOn(page.locator('a[aria-label="Large tiles"]'));
  await waitUrl(/grid-size=large/);
  await sleep(900);
  await moveAway();
  await shot('05-songs-large');
  await assertHealthy(page, 'songs list, large tiles');

  log('search');
  const search = page.locator('input[name="search"]').first();
  await clickOn(search);
  await page.keyboard.type(SEARCH, { delay: 140 });
  await sleep(300);
  await clickOn(
    page.locator('form:has(input[name="search"]) button[type="submit"]').first());
  await waitUrl(new RegExp('search=' + encodeURIComponent(SEARCH)));
  await sleep(600);
  await shot('06-search-results');
  await assertHealthy(page, 'search results');
  if (!(await page.locator(`a[href="${SONG}"]`).count())) {
    throw new Error(`search for ${JSON.stringify(SEARCH)} does not offer `
      + SONG + '; pass another term with --search');
  }

  log('song page');
  await clickOn(page.locator(`a[href="${SONG}"]`).first());
  await waitUrl(new RegExp(SONG.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  await sleep(950);
  await shot('07-song-top');
  await assertHealthy(page, 'song page');

  log('description');
  await scrollTo(700, 850);
  await shot('08-song-description');

  log('metronome');
  const metronome = page.locator('[id^="metronome-"][id$="-toggle"]').first();
  if (!(await metronome.count())) throw new Error('song page has no click track');
  await scrollToLocator(metronome, 380, 700);
  await clickOn(metronome);
  await sleep(1650);
  await moveAway();
  await shot('09-metronome');

  log('chords');
  const highlight = page.locator('button:has-text("highlight chords")').first();
  if (!(await highlight.count())) {
    throw new Error('song page has no chord guide');
  }
  await scrollToLocator(highlight, 300, 700);
  await sleep(300);
  await clickOn(highlight);
  await sleep(950);
  await shot('10-chords');

  log('auto-scroll');
  await clickOn(page.locator('#start-autoscroll'));
  await sleep(1700);
  // Scrolling upward is how the page's own auto-scroller is stopped, and its
  // interval checks once a second, so give it that second before going home.
  await page.evaluate(
    () => window.scrollBy({ top: -500, behavior: 'smooth' }));
  await sleep(1050);
  await scrollTo(0, 750);
  await moveAway();
  await shot('11-back-to-top');

  log('artist');
  await clickOn(page.locator(`a[href="${ARTIST}"]`).first());
  await waitUrl(new RegExp(ARTIST.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  await sleep(950);
  await shot('12-artist-top');
  await assertHealthy(page, 'artist page');
  const next = page.locator('button', { hasText: '→' }).first();
  if (await next.count()) {
    await clickOn(next);
    await sleep(950);
    await moveAway();
  }
  await shot('13-artist-carousel');
  await scrollTo(760, 850);
  await shot('14-artist-description');
  await scrollTo(1180, 800);
  await shot('15-artist-songs');

  log('genres');
  await clickOn(page.locator('a[href="/genres"]').first());
  await waitUrl(/\/genres$/);
  await sleep(750);
  await shot('16-genres');
  await assertHealthy(page, 'genres list');
  const genreTile = page.locator(`a[href="${GENRE}"]`).first();
  await scrollToLocator(genreTile, 300, 600);
  await clickOn(genreTile);
  await waitUrl(new RegExp(GENRE.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  await sleep(950);
  await shot('17-genre-top');
  await assertHealthy(page, 'genre page');
  await scrollTo(700, 850);
  await shot('18-genre-description');
  await scrollTo(1500, 850);
  await shot('19-genre-songs');

  log('dark');
  await clickOn(page.locator('button[onclick="hygguileToggleDarkTheme()"]'));
  await sleep(950);
  const dark = await page.evaluate(
    () => document.documentElement.getAttribute('data-theme'));
  if (dark !== 'dark') throw new Error(`dark mode did not turn on (${dark})`);
  await moveAway();
  await shot('20-genre-dark');
  await assertHealthy(page, 'genre page, dark');
  await clickOn(page.locator(`a[href="${SONG}"]`).first());
  await waitUrl(new RegExp(SONG.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  await sleep(950);
  await shot('21-song-dark');
  await assertHealthy(page, 'song page, dark');
  const metronomeDark = page.locator(
    '[id^="metronome-"][id$="-toggle"]').first();
  await scrollToLocator(metronomeDark, 380, 600);
  await clickOn(metronomeDark);
  await sleep(1750);
  await moveAway();
  await shot('22-song-dark-metronome');
  await scrollToLocator(highlight, 300, 600);
  await sleep(250);
  await clickOn(highlight);
  await sleep(950);
  await shot('23-song-dark-chords');
  await scrollToLocator(page.locator('#ascii-content-container'), 120, 600);
  await sleep(1000);
  await moveAway();
  await shot('24-song-dark-tab');
  await sleep(1200);
}

main()
  .then(async () => {
    await stopCapture();
    if (problems.length) {
      console.error(`\n${problems.length} page problem(s) during the take:`);
      for (const problem of problems) console.error('  ' + problem);
      process.exitCode = 1;
    } else {
      log('done');
    }
    if (browser) await browser.close().catch(() => {});
  })
  .catch(async (error) => {
    console.error('\nrecording failed:', error.message);
    await stopCapture().catch(() => {});
    if (browser) await browser.close().catch(() => {});
    process.exit(1);
  });
