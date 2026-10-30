// Electron main: one transparent, always-on-top, click-through window over the display
// that holds the terminal. Plays the intro once, then quits. Esc (or the Skip button) skips.
// While it plays, the Terminal window's bounds are polled so the overlay follows when it is moved or resized.
const { app, BrowserWindow, screen, globalShortcut, ipcMain } = require('electron');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const { pathToFileURL } = require('url');

if (!app.requestSingleInstanceLock()) { app.quit(); }

const userDir = path.join(app.getPath('home'), '.whiteboard');
function readJSON(p) { try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return null; } }

// macOS build: no Dock icon / menu bar while the overlay plays
if (process.platform === 'darwin') {
  try { app.setActivationPolicy('accessory'); } catch {}
  try { app.dock && app.dock.hide(); } catch {}
}

// everything after --wt is a command (executable + args) that opens the real Claude tab
// once the terminal is fully painted over (on macOS: ~/.whiteboard/open-tab.sh <dir> [claude args])
const wtIdx = process.argv.indexOf('--wt');
const wtArgs = wtIdx >= 0 ? process.argv.slice(wtIdx + 1) : [];
let launched = false;
function launchTab() {
  if (launched || !wtArgs.length) return;
  launched = true;
  try {
    const child = spawn(wtArgs[0], wtArgs.slice(1), { detached: true, stdio: 'ignore' });
    child.on('error', (e) => console.error('[intro] could not open the tab:', e.message));
    child.unref();
  } catch (e) { console.error('[intro] could not open the tab:', e.message); }
}
// macOS: the real window is opened only after the overlay has finished and quit (see will-quit), never while it is still on screen
ipcMain.on('covered', () => {});
ipcMain.on('ready', () => {});
ipcMain.handle('get-snapshot', () => null);   // no frozen-picture cover on macOS (it would need the Screen Recording permission)

let win = null;
let curBounds = null;
let poller = null;
function skip() {
  try { if (win && !win.isDestroyed()) win.hide(); } catch {}   // the overlay disappears at once
  launchTab();
  app.quit();
}
ipcMain.on('skip', skip);
// the skip button is the only part of the overlay that takes the mouse
ipcMain.on('clickable', (_e, on) => { if (win && !win.isDestroyed()) win.setIgnoreMouseEvents(!on, { forward: true }); });

// ---- follow the Terminal window (moved / resized while the intro plays) ----
function pushRect(r, term) {
  if (!win || win.isDestroyed()) return;
  const display = screen.getDisplayMatching({ x: Math.round(r.x), y: Math.round(r.y), width: Math.round(r.width), height: Math.round(r.height) });
  const b = display.bounds;
  if (!curBounds || b.x !== curBounds.x || b.y !== curBounds.y || b.width !== curBounds.width || b.height !== curBounds.height) {
    curBounds = b;
    win.setBounds({ x: b.x, y: b.y, width: b.width, height: b.height });
  }
  win.webContents.send('rect', { rect: { x: r.x - b.x, y: r.y - b.y, w: r.width, h: r.height }, stage: { w: b.width, h: b.height }, term });
}
// lines of "x1,y1,x2,y2|rows|cols" (window bounds in points, then the tab's live grid)
let lineBuf = '';
function feedLines(chunk) {
  lineBuf += chunk;
  let i;
  while ((i = lineBuf.indexOf('\n')) >= 0) {
    const [bounds, rows, cols] = lineBuf.slice(0, i).trim().split('|');
    lineBuf = lineBuf.slice(i + 1);
    const n = (bounds || '').split(',').map(Number);
    if (n.length !== 4 || !n.every(Number.isFinite)) continue;
    const w = n[2] - n[0], h = n[3] - n[1];
    if (w < 200 || h < 150) continue;
    const term = (+rows > 0 && +cols > 0) ? { rows: +rows, cols: +cols } : undefined;
    pushRect({ x: n[0], y: n[1], width: w, height: h }, term);
  }
}
function startFollow(winId) {
  if (!/^\d+$/.test(winId || '')) return;
  // 100 ms * 250 = 25 s, longer than the intro can ever run, so the loop can never outlive it
  const script = [
    'tell application "Terminal"',
    '  repeat 250 times',
    '    try',
    `      set b to bounds of window id ${winId}`,
    `      set t to selected tab of window id ${winId}`,
    '      log ((item 1 of b) as text) & "," & ((item 2 of b) as text) & "," & ((item 3 of b) as text) & "," & ((item 4 of b) as text) & "|" & ((number of rows of t) as text) & "|" & ((number of columns of t) as text)',
    '    on error',
    '      exit repeat',
    '    end try',
    '    delay 0.1',
    '  end repeat',
    'end tell',
  ].join('\n');
  try {
    poller = spawn('/usr/bin/osascript', ['-e', script], { stdio: ['ignore', 'ignore', 'pipe'] });   // `log` writes to stderr
    poller.stderr.setEncoding('utf8');
    let last = '';
    poller.stderr.on('data', (d) => { if (d !== last) { last = d; feedLines(d); } });
    poller.on('error', (e) => console.error('[intro] window follower failed:', e.message));
  } catch (e) { console.error('[intro] window follower failed:', e.message); }
}

function arg(name) {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : null;
}

app.whenReady().then(() => {
  const config = Object.assign({}, readJSON(path.join(__dirname, 'config.json')), readJSON(path.join(userDir, 'intro-config.json')));
  config.platform = process.platform;
  // --freeze=<seconds>: debug aid, pauses the animation at that moment (Esc closes) so it can be compared with the real window
  const freeze = parseFloat(arg('freeze'));
  if (freeze > 0) config.freeze = freeze;
  // --term=<json>: the user's real terminal (rows, cols, font, size, title bar), measured by the shell function
  try { const term = arg('term'); if (term) config.term = JSON.parse(term); } catch {}

  // character art: the user's own pictures in ~/.whiteboard/characters win.
  // One picture is enough: every missing expression reuses it (motion is procedural).
  const ownDir = path.join(userDir, 'characters');
  const own = {};
  for (const k of ['surprised', 'focused', 'happy', 'wink']) {
    const p = path.join(ownDir, `${k}.png`);
    if (fs.existsSync(p)) own[k] = p;
  }
  let ownAny = own.happy || own.focused || own.surprised || own.wink;
  if (!ownAny && fs.existsSync(ownDir)) {
    const pics = fs.readdirSync(ownDir).filter((f) => /\.(png|webp|gif)$/i.test(f)).sort();
    if (pics.length) ownAny = path.join(ownDir, pics[0]);
  }
  const assets = {};
  for (const k of ['surprised', 'focused', 'happy', 'wink']) {
    const bundled = path.join(__dirname, 'characters', `${k}.png`);
    const pick = own[k] || ownAny || (fs.existsSync(bundled) ? bundled : null);
    if (pick) assets[k] = pathToFileURL(pick).href;
  }

  // terminal rect: physical pixels from PowerShell (--rect=x,y,w,h); --demo = fake rect
  let phys;
  const raw = arg('rect');
  if (raw) {
    const [x, y, w, h] = raw.split(',').map(Number);
    phys = { x, y, width: w, height: h };
  } else {
    const wa = screen.getPrimaryDisplay().workArea;
    phys = { x: wa.x + wa.width * 0.2, y: wa.y + wa.height * 0.18, width: wa.width * 0.6, height: wa.height * 0.64 };
  }
  const dip = (process.platform === 'win32' && raw) ? screen.screenToDipRect(null, phys) : phys;
  const display = screen.getDisplayMatching({ x: Math.round(dip.x), y: Math.round(dip.y), width: Math.round(dip.width), height: Math.round(dip.height) });
  const b = display.bounds;
  curBounds = b;

  win = new BrowserWindow({
    x: b.x, y: b.y, width: b.width, height: b.height,
    transparent: true, frame: false, resizable: false, movable: false, minimizable: false, maximizable: false,
    alwaysOnTop: true, skipTaskbar: true, focusable: false, hasShadow: false, show: false,
    enableLargerThanScreen: true,   // macOS: otherwise the window is pushed below the menu bar and the whole drawing shifts down by its height
    backgroundColor: '#00000000',
    webPreferences: { contextIsolation: true, sandbox: true, backgroundThrottling: false, preload: path.join(__dirname, 'preload.js') },
  });
  win.setBounds({ x: b.x, y: b.y, width: b.width, height: b.height });   // exact placement, menu bar included
  win.setAlwaysOnTop(true, 'screen-saver');
  if (process.platform === 'darwin') win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  win.setIgnoreMouseEvents(true, { forward: true });
  const rect = { x: dip.x - b.x, y: dip.y - b.y, w: dip.width, h: dip.height };
  win.loadFile(path.join(__dirname, 'index.html'), {
    query: { rect: JSON.stringify(rect), config: JSON.stringify(config), assets: JSON.stringify(assets) },
  });
  win.once('ready-to-show', () => win.showInactive());
  if (process.env.INTRO_DEBUG) {
    win.webContents.on('console-message', (_e, level, msg) => console.log('[renderer]', level, msg));
    win.webContents.on('did-fail-load', (_e, code, desc) => console.log('[load-fail]', code, desc));
  }

  globalShortcut.register('Escape', skip);
  startFollow(arg('winid'));
  if (process.env.INTRO_DEBUG) { process.stdin.setEncoding('utf8'); process.stdin.on('data', feedLines); }   // debug: feed "x1,y1,x2,y2|rows|cols" lines by hand
  if (freeze > 0) setTimeout(launchTab, 3000);   // debug: open the real window early so the frozen overlay sits right over it
  if (!(freeze > 0)) setTimeout(() => { launchTab(); app.quit(); }, 20000); // safety net (not while frozen for debugging)
});

app.on('window-all-closed', () => app.quit());
app.on('will-quit', () => { launchTab(); globalShortcut.unregisterAll(); try { if (poller) poller.kill(); } catch {} });
