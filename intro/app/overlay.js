// Renderer: read the terminal rect + settings handed over by main.js, then play once.
// While it plays, main.js keeps sending the terminal's current rect: a move only shifts the drawing,
// a resize rebuilds the (deterministic) timeline for the new size and seeks back to the same moment.
(function () {
  const q = new URLSearchParams(location.search);
  let rect0 = JSON.parse(q.get('rect'));
  const cfg = JSON.parse(q.get('config') || '{}');
  const assets = JSON.parse(q.get('assets') || '{}');
  const stageEl = document.getElementById('stage');
  const bridge = window.intro || {};
  // stay in real time: if a frame is slow, drop frames instead of stretching the animation
  if (window.gsap) window.gsap.ticker.lagSmoothing(0);
  let frames = 0; if (window.gsap) window.gsap.ticker.add(() => { frames++; });

  let snapshot = null;   // { url, color }: frozen picture of the terminal, so the real tab can start early underneath
  let cur = null;        // { tl, holder, rect, stage, termKey }
  const t0 = performance.now();
  const termKey = () => JSON.stringify(cfg.term || {});

  function mount(rect, stage, at) {
    const holder = document.createElement('div');
    holder.style.cssText = `position:absolute;left:0;top:0;width:${stage.w}px;height:${stage.h}px`;
    stageEl.appendChild(holder);
    let cover = null;
    if (snapshot) {
      cover = document.createElement('div');
      // anchored top-left at its original size: after a resize the extra area is the plain terminal colour
      cover.style.cssText = `position:absolute;left:${rect.x}px;top:${rect.y}px;width:${rect.w}px;height:${rect.h}px;` +
        `background:${snapshot.color} url(${snapshot.url}) no-repeat 0 0 / ${snapshot.w}px ${snapshot.h}px;overflow:hidden`;
      holder.appendChild(cover);
    }
    const tl = window.ClaudeIntro.build({ root: holder, rect, stage, assets, config: cfg });
    // the terminal is completely painted over -> the frozen picture is no longer needed
    if (cover) tl.set(cover, { opacity: 0 }, (tl.covered || 6.55) + 0.15);
    // (without early launch) open the real Claude Code tab underneath now
    tl.call(() => { if (bridge.covered) bridge.covered(); }, null, tl.covered || 6.55);
    tl.timeScale(cfg.speed || 1);
    tl.eventCallback('onComplete', finish);
    if (cfg.freeze > 0) tl.call(() => tl.pause(), null, cfg.freeze); // debug: hold this frame until Esc
    if (at > 0) tl.play(at, false); else tl.play(0);
    return { tl, holder, rect, stage, termKey: termKey() };
  }

  let finished = false;
  function finish() {
    if (finished) return; finished = true;
    const s = (performance.now() - t0) / 1000;
    console.log('[intro] done in ' + s.toFixed(1) + 's, avg fps ' + (frames / s).toFixed(0));
    window.close();
  }

  // ---- follow the real window: move = shift, resize = rebuild at the same moment ----
  let pending = null, raf = 0, lastBuild = 0;
  function rebuild(rect, stage) {
    const at = cur.tl.time(), paused = cur.tl.paused();
    cur.tl.kill();
    cur.holder.remove();
    cur = mount(rect, stage, at);
    if (paused) cur.tl.pause();
    if (bridge.setClickable) bridge.setClickable(false);   // the old skip hover state died with the old layout
    place();
  }
  function apply() {
    raf = 0;
    if (!pending || !cur || finished) return;
    const p = pending;
    if (p.term) cfg.term = Object.assign({}, cfg.term, p.term);   // macOS: live rows / cols
    const sameStage = p.stage.w === cur.stage.w && p.stage.h === cur.stage.h;
    const sameSize = Math.abs(p.rect.w - cur.rect.w) < 0.5 && Math.abs(p.rect.h - cur.rect.h) < 0.5;
    if (sameStage && sameSize && termKey() === cur.termKey) {
      cur.holder.style.transform = `translate(${p.rect.x - cur.rect.x}px,${p.rect.y - cur.rect.y}px)`;
      curRect = p.rect; pending = null; place(); return;
    }
    if (performance.now() - lastBuild < 90) { raf = requestAnimationFrame(apply); return; }   // at most ~10 rebuilds a second while dragging
    pending = null; lastBuild = performance.now(); curRect = p.rect;
    rebuild(p.rect, p.stage);
  }
  let curRect = rect0;
  if (bridge.onRect) bridge.onRect((p) => { pending = p; if (!raf) raf = requestAnimationFrame(apply); });

  // ---- skip button (top right of the terminal; Esc works too) ----
  const skipBtn = document.createElement('div');
  skipBtn.textContent = '跳过 Skip · Esc';
  skipBtn.style.cssText = "position:absolute;z-index:10;height:22px;line-height:22px;padding:0 11px;border-radius:12px;" +
    "background:rgba(34,34,34,.78);color:#ECEEEB;border:1px solid rgba(255,255,255,.28);font:12px/22px 'Courier Prime',ui-monospace,monospace;" +
    "cursor:pointer;user-select:none;white-space:nowrap";
  stageEl.appendChild(skipBtn);
  skipBtn.addEventListener('mouseenter', () => { if (bridge.setClickable) bridge.setClickable(true); });
  skipBtn.addEventListener('mouseleave', () => { if (bridge.setClickable) bridge.setClickable(false); });
  skipBtn.addEventListener('click', () => { if (bridge.skip) bridge.skip(); });
  function place() {
    // Windows keeps its min/max/close buttons at the top right; macOS keeps them on the left
    const right = cfg.platform === 'darwin' ? 14 : 150;
    skipBtn.style.top = (curRect.y + 5) + 'px';
    skipBtn.style.left = Math.max(curRect.x + 8, curRect.x + curRect.w - right - skipBtn.offsetWidth) + 'px';
  }

  const loadSnapshot = async () => {
    if (!bridge.getSnapshot) return;
    try {
      const url = await bridge.getSnapshot();
      if (!url) return;
      const im = new Image();
      await new Promise((ok, no) => { im.onload = ok; im.onerror = no; im.src = url; });
      // the terminal's own background colour, sampled next to the bottom-right corner
      let color = '#0c0c0c';
      try {
        const cv = document.createElement('canvas'); cv.width = im.naturalWidth; cv.height = im.naturalHeight;
        const cx = cv.getContext('2d'); cx.drawImage(im, 0, 0);
        const d = cx.getImageData(Math.max(0, im.naturalWidth - 6), Math.max(0, im.naturalHeight - 6), 1, 1).data;
        color = `rgb(${d[0]},${d[1]},${d[2]})`;
      } catch {}
      snapshot = { url, color, w: rect0.w, h: rect0.h };
    } catch (e) { snapshot = null; }
  };

  const go = async () => {
    await loadSnapshot();
    cur = mount(rect0, { w: window.innerWidth, h: window.innerHeight }, 0);
    place();
    if (bridge.ready) bridge.ready(!!snapshot);   // main shows the window / opens the real tab only once the cover is up
    if (q.get('debug')) window.__intro = { get cur() { return cur; }, get pending() { return pending; } };
  };
  const fontsReady = document.fonts ? document.fonts.ready : Promise.resolve();
  Promise.race([fontsReady, new Promise((r) => setTimeout(r, 300))]).then(go);
})();
