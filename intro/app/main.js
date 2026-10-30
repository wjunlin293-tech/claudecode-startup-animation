// Electron main: one transparent, always-on-top window over the display that holds the terminal.
// Plays the intro once, then quits. Esc (or the Skip button) skips.
//  - The real Claude Code tab is started EARLY, right after the overlay is up, hidden behind a frozen
//    picture of the terminal, so skipping lands in a tab that has already been booting.
//  - A small PowerShell poller reports the terminal's rect while the intro plays; the overlay follows
//    when the window is moved or resized.
const { app, BrowserWindow, screen, globalShortcut, ipcMain, desktopCapturer } = require('electron');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const { pathToFileURL } = require('url');

if (!app.requestSingleInstanceLock()) { app.quit(); }

const userDir = path.join(app.getPath('home'), '.whiteboard');
function readJSON(p) { try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return null; } }

// everything after --wt is handed to wt.exe once the real tab may open
const wtIdx = process.argv.indexOf('--wt');
const wtArgs = wtIdx >= 0 ? process.argv.slice(wtIdx + 1) : [];
let launched = false;
function launchTab() {
  if (launched || !wtArgs.length) return;
  launched = true;
  try {
    const child = spawn('wt.exe', wtArgs, { detached: true, stdio: 'ignore' });
    child.on('error', (e) => console.error('[intro] could not start wt.exe:', e.message));
    child.unref();
  } catch (e) { console.error('[intro] could not start wt.exe:', e.message); }
}

function arg(name) {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : null;
}

let win = null;
let snapshot = null;       // data URL of the terminal as it looked when `claude` was typed
let poller = null;
let curBounds = null;      // display the overlay window currently sits on

function skip() {
  try { if (win && !win.isDestroyed()) win.hide(); } catch {}   // the overlay disappears at once
  launchTab();                                                   // no-op when the tab is already booting
  app.quit();
}

// the renderer reports it has built the first frame; with a cover up the real tab can start underneath it
ipcMain.handle('get-snapshot', () => snapshot);
ipcMain.on('ready', (_e, hasCover) => {
  if (win && !win.isDestroyed() && !win.isVisible()) win.showInactive();
  if (hasCover) setTimeout(launchTab, 250);
});
// no cover (capture failed / switched off): fall back to opening the tab once the terminal is painted over
ipcMain.on('covered', launchTab);
ipcMain.on('skip', skip);
// the skip button is the only part of the overlay that takes the mouse
ipcMain.on('clickable', (_e, on) => { if (win && !win.isDestroyed()) win.setIgnoreMouseEvents(!on, { forward: true }); });

// ---- follow the terminal window ----
function toDip(phys) { return process.platform === 'win32' ? screen.screenToDipRect(null, phys) : phys; }
function pushRect(phys) {
  if (!win || win.isDestroyed()) return;
  const dip = toDip(phys);
  const display = screen.getDisplayMatching({ x: Math.round(dip.x), y: Math.round(dip.y), width: Math.round(dip.width), height: Math.round(dip.height) });
  const b = display.bounds;
  if (!curBounds || b.x !== curBounds.x || b.y !== curBounds.y || b.width !== curBounds.width || b.height !== curBounds.height) {
    curBounds = b;
    win.setBounds({ x: b.x, y: b.y, width: b.width, height: b.height });   // the terminal moved to another monitor
  }
  win.webContents.send('rect', { rect: { x: dip.x - b.x, y: dip.y - b.y, w: dip.width, h: dip.height }, stage: { w: b.width, h: b.height } });
}
// lines of "x,y,w,h" in physical pixels
let lineBuf = '';
function feedLines(chunk) {
  lineBuf += chunk;
  let i;
  while ((i = lineBuf.indexOf('\n')) >= 0) {
    const n = lineBuf.slice(0, i).trim().split(',').map(Number);
    lineBuf = lineBuf.slice(i + 1);
    if (n.length === 4 && n.every(Number.isFinite) && n[2] >= 200 && n[3] >= 150) pushRect({ x: n[0], y: n[1], width: n[2], height: n[3] });
  }
}
function startFollow(hwnd) {
  if (!/^\d+$/.test(hwnd || '')) return;
  const ps = [
    "$ErrorActionPreference = 'SilentlyContinue'",
    "Add-Type -TypeDefinition @'",
    'using System; using System.Runtime.InteropServices;',
    'public static class WbPoll {',
    '  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }',
    '  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();',
    '  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);',
    '  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);',
    '  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);',
    '  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int s);',
    '}',
    "'@",
    '[void][WbPoll]::SetProcessDPIAware()',
    `$h = [IntPtr][long]${hwnd}`,
    "$last = ''",
    '$n = 0',
    // 40 ms * 700 = 28 s, longer than the intro can ever run, so the poller can never outlive it
    'while ($n -lt 700 -and [WbPoll]::IsWindow($h)) {',
    '  $n++',
    '  if (-not [WbPoll]::IsIconic($h)) {',
    '    $r = New-Object WbPoll+RECT',
    '    if ([WbPoll]::DwmGetWindowAttribute($h, 9, [ref]$r, 16) -ne 0) { [void][WbPoll]::GetWindowRect($h, [ref]$r) }',
    "    $s = '{0},{1},{2},{3}' -f $r.Left, $r.Top, ($r.Right - $r.Left), ($r.Bottom - $r.Top)",
    '    if ($s -ne $last) { $last = $s; [Console]::Out.WriteLine($s); [Console]::Out.Flush() }',
    '  }',
    '  Start-Sleep -Milliseconds 40',
    '}',
  ].join('\n');
  try {
    poller = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', Buffer.from(ps, 'utf16le').toString('base64')],
      { stdio: ['ignore', 'pipe', 'ignore'], windowsHide: true });
    poller.stdout.setEncoding('utf8');
    poller.stdout.on('data', feedLines);
    poller.on('error', (e) => console.error('[intro] window follower failed:', e.message));
  } catch (e) { console.error('[intro] window follower failed:', e.message); }
}

// ---- frozen picture of the terminal (what the overlay shows while the real tab boots underneath) ----
async function captureCover(display, dip) {
  try {
    const sf = display.scaleFactor || 1, b = display.bounds;
    const size = { width: Math.round(b.width * sf), height: Math.round(b.height * sf) };
    const sources = await Promise.race([
      desktopCapturer.getSources({ types: ['screen'], thumbnailSize: size }),
      new Promise((r) => setTimeout(() => r(null), 2500)),
    ]);
    if (!sources || !sources.length) return null;
    const src = sources.find((s) => String(s.display_id) === String(display.id)) || (sources.length === 1 ? sources[0] : null);
    if (!src || src.thumbnail.isEmpty()) return null;
    const full = src.thumbnail.getSize(), ratio = full.width / b.width;
    const x = Math.max(0, Math.round((dip.x - b.x) * ratio)), y = Math.max(0, Math.round((dip.y - b.y) * ratio));
    const w = Math.min(full.width - x, Math.round(dip.width * ratio)), h = Math.min(full.height - y, Math.round(dip.height * ratio));
    if (w < 50 || h < 50) return null;
    return src.thumbnail.crop({ x, y, width: w, height: h }).toDataURL();
  } catch (e) { console.error('[intro] screen capture failed:', e.message); return null; }
}

app.whenReady().then(async () => {
  const config = Object.assign({}, readJSON(path.join(__dirname, 'config.json')), readJSON(path.join(userDir, 'intro-config.json')));
  config.platform = process.platform;

  globalShortcut.register('Escape', skip);
  setTimeout(() => { launchTab(); app.quit(); }, 20000); // safety net

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
    backgroundColor: '#00000000',
    webPreferences: { contextIsolation: true, sandbox: true, backgroundThrottling: false, preload: path.join(__dirname, 'preload.js') },
  });
  win.setAlwaysOnTop(true, 'screen-saver');
  win.setIgnoreMouseEvents(true, { forward: true });
  if (process.env.INTRO_DEBUG) {
    win.webContents.on('console-message', (_e, level, msg) => console.log('[renderer]', level, msg));
    win.webContents.on('did-fail-load', (_e, code, desc) => console.log('[load-fail]', code, desc));
    // debug: feed "x,y,w,h" lines (physical px) on stdin to move / resize the followed rect by hand
    process.stdin.setEncoding('utf8'); process.stdin.on('data', feedLines);
  }

  // grab the terminal BEFORE the overlay is shown, so the picture is of the real window
  if (config.earlyLaunch !== false && wtArgs.length && (process.platform === 'win32' || process.env.INTRO_DEBUG)) {
    snapshot = await captureCover(display, dip);
  }

  const rect = { x: dip.x - b.x, y: dip.y - b.y, w: dip.width, h: dip.height };
  win.loadFile(path.join(__dirname, 'index.html'), {
    query: { rect: JSON.stringify(rect), config: JSON.stringify(config), assets: JSON.stringify(assets), debug: process.env.INTRO_DEBUG ? '1' : '' },
  });
  // without a cover the old behaviour stays: show at once. With one, the renderer says when its first frame is up.
  win.once('ready-to-show', () => { if (!snapshot) win.showInactive(); });
  if (snapshot) setTimeout(() => { if (win && !win.isDestroyed() && !win.isVisible()) win.showInactive(); }, 2500);
  setTimeout(launchTab, 9000); // even if the renderer never reports, the tab still opens

  startFollow(arg('hwnd'));
});

app.on('window-all-closed', () => app.quit());
app.on('will-quit', () => { launchTab(); globalShortcut.unregisterAll(); try { if (poller) poller.kill(); } catch {} });
