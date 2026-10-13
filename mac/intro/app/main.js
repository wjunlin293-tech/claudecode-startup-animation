// Electron main: one transparent, always-on-top, click-through window over the display
// that holds the terminal. Plays the intro once, then quits. Esc skips.
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

function arg(name) {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : null;
}

app.whenReady().then(() => {
  const config = Object.assign({}, readJSON(path.join(__dirname, 'config.json')), readJSON(path.join(userDir, 'intro-config.json')));
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

  const win = new BrowserWindow({
    x: b.x, y: b.y, width: b.width, height: b.height,
    transparent: true, frame: false, resizable: false, movable: false, minimizable: false, maximizable: false,
    alwaysOnTop: true, skipTaskbar: true, focusable: false, hasShadow: false, show: false,
    backgroundColor: '#00000000',
    webPreferences: { contextIsolation: true, sandbox: true, backgroundThrottling: false, preload: path.join(__dirname, 'preload.js') },
  });
  win.setAlwaysOnTop(true, 'screen-saver');
  if (process.platform === 'darwin') win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  win.setIgnoreMouseEvents(true);
  const rect = { x: dip.x - b.x, y: dip.y - b.y, w: dip.width, h: dip.height };
  win.loadFile(path.join(__dirname, 'index.html'), {
    query: { rect: JSON.stringify(rect), config: JSON.stringify(config), assets: JSON.stringify(assets) },
  });
  win.once('ready-to-show', () => win.showInactive());
  if (process.env.INTRO_DEBUG) {
    win.webContents.on('console-message', (_e, level, msg) => console.log('[renderer]', level, msg));
    win.webContents.on('did-fail-load', (_e, code, desc) => console.log('[load-fail]', code, desc));
  }

  globalShortcut.register('Escape', () => { launchTab(); app.quit(); });
  if (!(freeze > 0)) setTimeout(() => { launchTab(); app.quit(); }, 20000); // safety net (not while frozen for debugging)
});

app.on('window-all-closed', () => app.quit());
app.on('will-quit', () => { launchTab(); globalShortcut.unregisterAll(); });
