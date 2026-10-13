/* Claude Code launch intro - storyboard C
 * A character pops out of the real terminal window, draws a heart, makes a face,
 * paints the terminal white with a marker and draws the Claude Code UI on it,
 * then fades out so the real (whiteboard-themed) Claude Code tab underneath takes over.
 *
 * ClaudeIntro.build({ root, rect, stage, assets, config }) -> paused gsap timeline (8 s)
 *   root   : element covering the whole stage (position: relative / absolute)
 *   rect   : terminal window in stage coordinates {x, y, w, h}
 *   stage  : {w, h}
 *   assets : { surprised, focused, happy, wink } image urls (character art)
 *   config : { codeOpacity, accent, board, ink, showHeart }
 * Deterministic: no Math.random / Date - safe for hyperframes seeking.
 */
(function (global) {
  'use strict';
  const SVGNS = 'http://www.w3.org/2000/svg';

  function rng(seed) { // mulberry32
    return function () {
      seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  function el(tag, attrs, parent) {
    const n = document.createElementNS(SVGNS, tag);
    for (const k in attrs) n.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(n);
    return n;
  }
  function drawable(path) { // prepare a path for draw-on
    path.setAttribute('pathLength', '1');
    path.style.strokeDasharray = '1';
    path.style.strokeDashoffset = '1';
    return path;
  }


  // ---- adapted from HyperFrames registry "hw-boil" (hand-drawn boil, pen-velocity ease) ----
  function hwHash(n, seed) { const x = Math.sin(n * 127.1 + (seed || 1) * 311.7) * 43758.5453; return (x - Math.floor(x)) * 2 - 1; }
  function onUpdate(tl, fn) {
    if (!tl.__hwRenders) { tl.__hwRenders = []; tl.eventCallback('onUpdate', () => { for (const f of tl.__hwRenders) f(); }); }
    tl.__hwRenders.push(fn); fn();
  }
  function boil(tl, els, opts) { // re-pose every N frames: seek-safe line boil
    const amp = opts.amp, rot = opts.rot, drop = opts.frameDrop || 3, seed = opts.seed || 1;
    onUpdate(tl, () => {
      const step = Math.floor((tl.time() * 30) / drop);
      els.forEach((e, i) => global.gsap.set(e, {
        x: hwHash(step * 3 + i * 97, seed) * amp, y: hwHash(step * 3 + 1 + i * 97, seed) * amp,
        rotation: hwHash(step * 3 + 2 + i * 97, seed) * rot, transformOrigin: '50% 50%' }));
    });
  }
  function penEase(pathEl, kCurve) { // a pen slows into curves, never stalls
    kCurve = kCurve || 10; const L = pathEl.getTotalLength(); if (L <= 0) return (t) => t;
    const PRE = 48, pts = []; for (let i = 0; i <= PRE; i++) pts.push(pathEl.getPointAtLength((L * i) / PRE));
    const curv = [0];
    for (let i = 1; i < PRE; i++) {
      const ax = pts[i].x - pts[i - 1].x, ay = pts[i].y - pts[i - 1].y, bx = pts[i + 1].x - pts[i].x, by = pts[i + 1].y - pts[i].y;
      const la = Math.hypot(ax, ay) || 1e-6, lb = Math.hypot(bx, by) || 1e-6;
      curv.push(Math.acos(Math.max(-1, Math.min(1, (ax * bx + ay * by) / (la * lb)))) / ((la + lb) / 2));
    }
    curv.push(0);
    const N = 60, times = [0]; let t = 0;
    for (let i = 1; i <= N; i++) { const u = ((i - 0.5) / N) * PRE, i0 = Math.floor(u), f = u - i0;
      const c = curv[Math.min(i0, PRE)] * (1 - f) + curv[Math.min(i0 + 1, PRE)] * f;
      t += (L / N) / Math.max(1 / (1 + kCurve * c * 14), 0.22); times.push(t); }
    for (let i = 0; i <= N; i++) times[i] /= t;
    return (p) => { if (p <= 0) return 0; if (p >= 1) return 1; let lo = 0, hi = N;
      while (hi - lo > 1) { const mid = (lo + hi) >> 1; if (times[mid] <= p) lo = mid; else hi = mid; }
      return (lo + (p - times[lo]) / ((times[hi] - times[lo]) || 1e-9)) / N; };
  }
  function wobblyRoundRect(x, y, w, h, r, seed, amt) { // hand-drawn rounded rectangle
    const pts = []; const per = (a, b) => a + hwHash(pts.length * 7.3, seed) * amt;
    const P = (px, py) => pts.push([per(px), per(py)]);
    P(x + r, y); P(x + w * 0.5, y); P(x + w - r, y); P(x + w, y + r); P(x + w, y + h * 0.5); P(x + w, y + h - r);
    P(x + w - r, y + h); P(x + w * 0.5, y + h); P(x + r, y + h); P(x, y + h - r); P(x, y + h * 0.5); P(x, y + r);
    let d = `M${pts[0][0].toFixed(1)} ${pts[0][1].toFixed(1)}`;
    const ctrl = [[x + w, y], [x + w, y + h], [x, y + h], [x, y]];
    for (let k = 0; k < 4; k++) {
      const a = pts[k * 3 + 1], b = pts[k * 3 + 2], c = pts[(k * 3 + 3) % 12];
      d += ` L${a[0].toFixed(1)} ${a[1].toFixed(1)} L${b[0].toFixed(1)} ${b[1].toFixed(1)} Q${ctrl[k][0]} ${ctrl[k][1]} ${c[0].toFixed(1)} ${c[1].toFixed(1)}`;
    }
    return d + ` L${(pts[0][0] + 6).toFixed(1)} ${(pts[0][1] + 1.5).toFixed(1)}`; // slight overshoot, like a real pen
  }

  const CODE = [
    "brush.sweep(row)", "ctx.fillStyle = '#ECEEEB'", "terminal.paint({ opacity: 1 })",
    "for (const row of rows) sweep(row)", "marker.pressure = 0.8", "wt.newTab('Claude Whiteboard')",
    "spawn('claude')", "await board.ready()", "theme.use('whiteboard')", "cursor.blink()",
  ];

  function build(opts) {
    const gsap = global.gsap;
    const root = opts.root, r = opts.rect, stage = opts.stage;
    const cfg = Object.assign({ codeOpacity: 0.28, accent: '#E5653C', board: '#ECEEEB', ink: '#222222', showHeart: true }, opts.config || {});
    const A = opts.assets || {};
    const R = rng(20261013);

    // ---------- geometry (all relative to the real terminal) ----------
    const TB = clamp(r.h * 0.07, 32, 42);               // tab bar height
    const c = { x: r.x, y: r.y + TB, w: r.w, h: r.h - TB };
    const S = clamp(Math.min(r.w, r.h) * 0.17, 64, 150); // character size
    const rowH = clamp(c.h / 6, 46, 110);
    const pad = rowH * 0.45;

    // ---------- layers ----------
    const svg = el('svg', { width: stage.w, height: stage.h, viewBox: `0 0 ${stage.w} ${stage.h}` });
    svg.style.cssText = 'position:absolute;left:0;top:0;overflow:visible;pointer-events:none';
    root.appendChild(svg);
    const defs = el('defs', {}, svg);
    const f = el('filter', { id: 'ci-marker', x: '-5%', y: '-5%', width: '110%', height: '110%' }, defs);
    el('feTurbulence', { type: 'fractalNoise', baseFrequency: '0.035', numOctaves: '2', seed: '7', result: 'n' }, f);
    el('feDisplacementMap', { in: 'SourceGraphic', in2: 'n', scale: '4' }, f);
    const clip = el('clipPath', { id: 'ci-term' }, defs);
    el('rect', { x: c.x, y: c.y, width: c.w, height: c.h, rx: 8 }, clip);
    const tclip = el('clipPath', { id: 'ci-text' }, defs);
    const tclipRect = el('rect', { x: 0, y: 0, width: 0, height: stage.h }, tclip);

    const art = el('g', { filter: 'url(#ci-marker)' }, svg);

    // 1. trace around the window
    const trace = drawable(el('rect', { x: r.x - 8, y: r.y - 8, width: r.w + 16, height: r.h + 16, rx: 12,
      fill: 'none', stroke: cfg.accent, 'stroke-width': 5, 'stroke-linecap': 'round' }, art));

    const body = el('g', { 'clip-path': 'url(#ci-term)' }, art);

    // 2. heart
    const hs = Math.min(c.w, c.h) * 0.32, hx = c.x + c.w / 2, hy = c.y + c.h * 0.46;
    const P = (u, v) => `${(hx + u * hs).toFixed(1)} ${(hy + v * hs).toFixed(1)}`;
    const heart = drawable(el('path', {
      d: `M${P(0, 0.75)} C${P(-0.85, 0.25)} ${P(-1, -0.45)} ${P(-0.5, -0.62)} C${P(-0.25, -0.7)} ${P(-0.03, -0.52)} ${P(0, -0.35)} C${P(0.03, -0.52)} ${P(0.25, -0.7)} ${P(0.5, -0.62)} C${P(1, -0.45)} ${P(0.85, 0.25)} ${P(0, 0.75)} Z`,
      fill: 'none', stroke: cfg.board, 'stroke-width': Math.max(10, hs * 0.07), 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }, body));

    // 3. paint sweeps (boustrophedon)
    let d = '', yy = c.y + pad, dir = 1, rows = [];
    d = `M${c.x + pad} ${yy}`;
    while (yy < c.y + c.h + rowH * 0.2) {
      rows.push(yy);
      d += ` H${dir > 0 ? c.x + c.w - pad : c.x + pad}`;
      const ny = yy + rowH;
      if (ny < c.y + c.h + rowH * 0.2) d += ` L${dir > 0 ? c.x + c.w - pad : c.x + pad} ${ny}`;
      yy = ny; dir *= -1;
    }
    const paint = drawable(el('path', { d, fill: 'none', stroke: cfg.board, 'stroke-width': rowH * 1.45, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }, body));
    const streak = drawable(el('path', { d, fill: 'none', stroke: '#D7DAD4', 'stroke-width': 3, transform: `translate(0 ${rowH * 0.32})` }, body));
    const fill = el('rect', { x: c.x, y: c.y, width: c.w, height: c.h, fill: cfg.board, opacity: 0 }, body);
    // the tab strip gets painted too, so the real tab opening underneath stays hidden until the hand-over
    const barFill = el('rect', { x: r.x, y: r.y, width: r.w, height: TB + 2, rx: 8, fill: '#DCDFDA', opacity: 0 }, art);

    // flowing data: lots of code that streams through the fresh white paint (dark ink is invisible on black,
    // so it only "appears" where the marker has already painted)
    const dataG = el('g', { 'clip-path': 'url(#ci-term)', opacity: 0 }, svg);
    const LH = 15, colW = 300;
    const nCols = Math.max(2, Math.ceil(c.w / colW));
    const nLines = Math.ceil(c.h / LH) + 2;
    const SNIP = CODE.concat([
      "0x7f3a 0x00e1 0xbeef 0x1c2d", "{ id: 42, ok: true, ms: 18 }", "stream.pipe(board)", "await fetch('/v1/messages')",
      "tokens += chunk.length", "01101100 01101111 01110110", "diff --git a/app.ts b/app.ts", "+ const board = new Whiteboard()",
      "ctx.save(); ctx.restore()", "emit('paint', { row, x, y })", "while (!done) step()", "SELECT * FROM ideas LIMIT 1",
      "sha256: 9f2c...e41b", "[████████░░] 82%", "pipeline: ingest -> think -> draw", "return { status: 'ready' }",
    ]);
    const cols = [];
    for (let k = 0; k < nCols; k++) {
      const g = el('g', {}, dataG);
      for (let rep = 0; rep < 2; rep++) {
        for (let i = 0; i < nLines; i++) {
          const t = el('text', { x: c.x + 14 + k * colW + R() * 30, y: c.y + (rep * nLines + i) * LH, 'font-size': 12,
            'font-family': "'Courier Prime', monospace", fill: cfg.ink, opacity: (0.45 + R() * 0.55).toFixed(2) }, g);
          t.textContent = SNIP[Math.floor(R() * SNIP.length)];
        }
      }
      cols.push({ g, speed: 26 + R() * 46, dir: k % 2 ? 1 : -1, span: nLines * LH });
    }
    // fast "packets" racing along the painted rows
    const packets = [];
    for (let i = 0; i < Math.max(6, rows.length * 2); i++) {
      const t = el('text', { x: 0, y: rows[i % rows.length] + (R() - 0.5) * rowH * 0.6, 'font-size': 13, 'font-weight': 700,
        'font-family': "'Courier Prime', monospace", fill: i % 3 ? cfg.ink : cfg.accent }, dataG);
      t.textContent = ['0x1F', '{ }', '=>', '01', 'ok', '::', '++', '<>'][i % 8];
      packets.push({ t, speed: 180 + R() * 260, off: R() * c.w });
    }

    // 4. welcome box + text
    const wx = c.x + 22, wy = c.y + 16, ww = Math.min(c.w - 44, 660), wh = clamp(c.h * 0.26, 96, 140), rr = 14;
    const welG = el('g', {}, svg);
    const wel = drawable(el('path', { d: wobblyRoundRect(wx, wy, ww, wh, rr, 11, Math.max(1.5, ww * 0.004)),
      fill: 'none', stroke: cfg.accent, 'stroke-width': 4, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }, welG));
    const fs = clamp(ww / 22, 15, 30);
    const tg = el('g', { 'clip-path': 'url(#ci-text)' }, svg);
    const star = el('text', { x: wx + 18, y: wy + fs + 16, 'font-size': fs, fill: cfg.accent, 'font-family': "'Permanent Marker', cursive" }, tg); star.textContent = '*';
    const title = el('text', { x: wx + 18 + fs * 0.9, y: wy + fs + 16, 'font-size': fs, fill: cfg.ink, 'font-family': "'Permanent Marker', cursive" }, tg);
    title.textContent = 'Welcome to Claude Code!';
    el('path', { d: `M${wx + 20} ${wy + fs + 44} H${wx + ww * 0.72} M${wx + 20} ${wy + fs + 70} H${wx + ww * 0.45}`, stroke: '#9A9E98', 'stroke-width': 7, 'stroke-linecap': 'round' }, tg);

    // 5. input box + status line
    const iy = c.y + c.h - clamp(c.h * 0.2, 70, 110);
    const inG = el('g', {}, svg);
    const input = drawable(el('path', { d: `M${c.x + 18} ${iy} H${c.x + c.w - 18} M${c.x + 18} ${iy + 42} H${c.x + c.w - 18}`,
      fill: 'none', stroke: cfg.ink, 'stroke-width': 3, 'stroke-linecap': 'round' }, inG));
    const prompt = el('text', { x: c.x + 24, y: iy + 30, 'font-size': 22, fill: cfg.accent, 'font-family': "'Permanent Marker', cursive", opacity: 0 }, inG); prompt.textContent = '>';
    const status = el('text', { x: c.x + 26, y: iy + 66, 'font-size': 13, fill: '#55594F', 'font-family': "'Courier Prime', monospace", opacity: 0 }, inG);
    status.textContent = '✎ whiteboard · ready';

    // 6. tab
    const tab = el('g', { opacity: 1 }, svg);
    const tabRect = el('rect', { x: r.x + 8, y: r.y + 5, width: 180, height: TB - 9, rx: 7, fill: cfg.accent }, tab);
    gsap.set(tabRect, { scaleX: 0, transformOrigin: '0% 50%' });
    const tabText = el('text', { x: r.x + 24, y: r.y + TB * 0.68, 'font-size': 16, fill: cfg.ink, 'font-family': "'Permanent Marker', cursive", opacity: 0 }, tab);
    tabText.textContent = 'Claude Code';

    // ---------- character (HTML so any png works) + the marker it holds ----------
    const ch = document.createElement('div');
    ch.style.cssText = `position:absolute;left:0;top:0;width:${S}px;height:${S}px;opacity:0;will-change:transform;pointer-events:none`;
    const img = document.createElement('img');
    img.style.cssText = 'width:100%;height:100%;object-fit:contain;transform-origin:50% 100%;display:block';
    ch.appendChild(img);
    const mkBubble = (txt) => { const b = document.createElement('div'); b.textContent = txt;
      b.style.cssText = `position:absolute;left:${S * 0.72}px;top:${-S * 0.32}px;font:700 ${S * 0.42}px 'Permanent Marker',cursive;color:${cfg.accent};opacity:0`;
      ch.appendChild(b); return b; };
    const bang = mkBubble('!'), love = mkBubble('♥');
    root.appendChild(ch);

    // the marker + a doodled arm, drawn in SVG on top so the pen tip sits exactly on the stroke
    const rigSvg = el('svg', { width: stage.w, height: stage.h, viewBox: `0 0 ${stage.w} ${stage.h}` });
    rigSvg.style.cssText = 'position:absolute;left:0;top:0;overflow:visible;pointer-events:none';
    root.appendChild(rigSvg);
    const rig = el('g', { opacity: 0 }, rigSvg);
    const arm = el('path', { fill: 'none', stroke: cfg.ink, 'stroke-width': Math.max(3, S * 0.035), 'stroke-linecap': 'round' }, rig);
    const hand = el('circle', { r: Math.max(4, S * 0.05), fill: cfg.board, stroke: cfg.ink, 'stroke-width': 2.5 }, rig);
    const PL = clamp(S * 0.78, 52, 110), PW = clamp(S * 0.16, 11, 22);
    const marker = el('g', {}, rig);                     // drawn pointing along +x, tip at (0,0)
    el('path', { d: `M0 0 L${PL * 0.16} ${-PW * 0.32} L${PL * 0.16} ${PW * 0.32} Z`, fill: cfg.ink }, marker);
    el('rect', { x: PL * 0.16, y: -PW / 2, width: PL * 0.66, height: PW, rx: PW * 0.3, fill: cfg.board, stroke: cfg.ink, 'stroke-width': 2.2 }, marker);
    el('rect', { x: PL * 0.6, y: -PW / 2, width: PL * 0.1, height: PW, fill: cfg.accent }, marker);
    const cap = el('rect', { x: PL * 0.82, y: -PW / 2 - 1, width: PL * 0.28, height: PW + 2, rx: PW * 0.35, fill: cfg.accent, stroke: cfg.ink, 'stroke-width': 2 }, marker);
    const flyCap = el('rect', { x: 0, y: 0, width: PL * 0.28, height: PW + 2, rx: PW * 0.35, fill: cfg.accent, stroke: cfg.ink, 'stroke-width': 2, opacity: 0 }, rigSvg);

    const exprs = {};
    ['surprised', 'focused', 'happy', 'wink'].forEach((k) => { if (A[k]) { const im = new Image(); im.src = A[k]; exprs[k] = A[k]; } });
    const setExpr = (k) => { img.src = exprs[k] || exprs.happy || ''; };
    setExpr('surprised');

    // place(x, y) = where the pen tip is. The character stands up-right of it, holding the marker.
    let rigScale = 1;
    function place(x, y) {
      const cx = x + S * 0.22, cy = y - S * 0.86;          // character top-left
      gsap.set(ch, { x: cx, y: cy });
      const hx = cx + S * 0.18, hy = cy + S * 0.62;         // its hand
      const ang = Math.atan2(y - hy, x - hx);
      const tipX = x, tipY = y;
      const back = { x: tipX - Math.cos(ang) * PL * 0.82 * rigScale, y: tipY - Math.sin(ang) * PL * 0.82 * rigScale };
      arm.setAttribute('d', `M${(cx + S * 0.34).toFixed(1)} ${(cy + S * 0.58).toFixed(1)} Q${((cx + S * 0.34 + back.x) / 2).toFixed(1)} ${((cy + S * 0.58 + back.y) / 2 + S * 0.08).toFixed(1)} ${back.x.toFixed(1)} ${back.y.toFixed(1)}`);
      hand.setAttribute('cx', back.x.toFixed(1)); hand.setAttribute('cy', back.y.toFixed(1));
      // marker points from the hand down to the tip: rotate so +x points AWAY from the tip
      marker.setAttribute('transform', `translate(${tipX.toFixed(1)} ${tipY.toFixed(1)}) rotate(${(ang * 180 / Math.PI + 180).toFixed(1)}) scale(${rigScale})`);
    }

    // ---------- timeline (about 11.8 s) ----------
    const T = {                                            // beat sheet
      trace: 0, pop: 0.7, grab: 1.8, heart: 2.5, face: 3.75, paint: 4.6, fill: 6.35, welcome: 6.6,
      write: 7.85, input: 9.0, tab: 9.85, out: 10.5, end: 11.8,
    };
    const tl = gsap.timeline({ paused: true, defaults: { immediateRender: false } });
    const EXPR = [[0, 'surprised'], [T.grab, 'focused'], [T.face, exprs.wink ? 'wink' : 'happy'], [T.paint - 0.1, 'focused'], [T.out, 'happy']];
    let curExpr = '';
    tl.to({ v: 0 }, { v: 1, duration: T.end, ease: 'none', onUpdate() {
      const t = tl.time(); let k = EXPR[0][1];
      for (const [at, name] of EXPR) if (t >= at) k = name;
      if (k !== curExpr) { curExpr = k; setExpr(k); }
    } }, 0);
    const followDraw = (path, at, dur, ease, extra, pen) => {
      const len = path.getTotalLength();
      const pe = pen ? penEase(path) : null;
      const o = { p: 0 };
      tl.to(o, { p: 1, duration: dur, ease: ease || 'none', onUpdate() {
        const q = pe ? pe(o.p) : o.p;
        path.style.strokeDashoffset = String(1 - q);
        if (extra) extra.forEach((e) => { e.style.strokeDashoffset = String(1 - q); });
        const pt = path.getPointAtLength(q * len);
        place(pt.x, pt.y);
      } }, at);
    };
    const jump = (at, fromX, fromY, toX, toY, dur, lift) => {
      const o = { t: 0 };
      tl.to(o, { t: 1, duration: dur, ease: 'power1.inOut', onUpdate() {
        const x = fromX + (toX - fromX) * o.t;
        const y = fromY + (toY - fromY) * o.t - Math.sin(Math.PI * o.t) * lift;
        place(x, y);
      } }, at);
      tl.fromTo(img, { scaleY: 0.82, scaleX: 1.1 }, { scaleY: 1.12, scaleX: 0.92, duration: 0.12, ease: 'power2.out' }, at);       // stretch on take-off
      tl.fromTo(img, { scaleY: 0.78, scaleX: 1.16 }, { scaleY: 1, scaleX: 1, duration: 0.3, ease: 'back.out(3)' }, at + dur);   // squash on landing
    };
    const lean = (at, dur) => {                            // focused: lean into the pen + little bob
      tl.to(img, { rotation: 6, duration: 0.2, ease: 'power1.out' }, at);
      tl.to(img, { y: -4, duration: 0.16, yoyo: true, repeat: Math.max(1, Math.round(dur / 0.32) * 2 - 1), ease: 'sine.inOut' }, at);
      tl.to(img, { rotation: 0, y: 0, duration: 0.15 }, at + dur);
    };

    // 01 trace the real window 0.0-0.7
    tl.to(trace.style, { strokeDashoffset: 0, duration: 0.65, ease: 'power1.inOut' }, T.trace);
    tl.to(trace, { opacity: 0, duration: 0.4 }, T.pop + 0.6);

    // 02 pop out 0.7-1.8: squash, stretch, "!", shiver, look around
    const popX = r.x + r.w * 0.74, popY = r.y + 2;
    tl.set(ch, { opacity: 1 }, T.pop);
    tl.to({ v: 0 }, { v: 1, duration: 0.45, ease: 'back.out(1.6)', onUpdate() { place(popX, popY + S * 0.7 * (1 - this.progress())); } }, T.pop);
    tl.fromTo(img, { scaleY: 0.2, scaleX: 1.35 }, { scaleY: 1, scaleX: 1, duration: 0.5, ease: 'back.out(2.5)', immediateRender: true }, T.pop);
    tl.fromTo(bang, { opacity: 0, scale: 0.4 }, { opacity: 1, scale: 1, duration: 0.22, ease: 'back.out(3)' }, T.pop + 0.3);
    tl.to(img, { x: 5, duration: 0.05, yoyo: true, repeat: 7, ease: 'none' }, T.pop + 0.35);
    tl.set(img, { x: 0 }, T.pop + 0.76);
    tl.to(bang, { opacity: 0, duration: 0.2 }, T.pop + 0.8);
    tl.to(img, { rotation: -8, duration: 0.18, yoyo: true, repeat: 1, ease: 'sine.inOut' }, T.pop + 0.82);   // looks around
    tl.to(img, { scaleY: 0.88, duration: 0.07, yoyo: true, repeat: 1 }, T.grab - 0.25);                     // blink

    // 03 grab the marker 1.8-2.5: jump to the heart start, the marker spins into the hand, cap pops off
    const h0 = heart.getPointAtLength(0);
    jump(T.grab, popX, popY, h0.x, h0.y, 0.42, S * 0.7);
    tl.to(rig, { opacity: 1, duration: 0.12 }, T.grab + 0.45);
    tl.fromTo({ s: 0 }, { s: 0 }, { s: 1, duration: 0.3, ease: 'back.out(2.2)', onUpdate() { rigScale = this.targets()[0].s; place(h0.x, h0.y); } }, T.grab + 0.45);
    tl.set(cap, { opacity: 0 }, T.grab + 0.6);
    tl.fromTo(flyCap, { opacity: 0, x: h0.x + PL * 0.6, y: h0.y - PL * 0.4, rotation: 0 },
      { opacity: 1, x: h0.x + PL * 1.6, y: h0.y - PL * 1.6, rotation: 220, duration: 0.35, ease: 'power2.out' }, T.grab + 0.6);
    tl.to(flyCap, { opacity: 0, duration: 0.15 }, T.grab + 0.85);

    // 04 heart 2.5-3.75 (pen slows in the curves)
    if (cfg.showHeart) followDraw(heart, T.heart, 1.2, 'none', null, true);
    lean(T.heart, 1.2);

    // 05 step back and make a face 3.75-4.6
    tl.to(rig, { opacity: 0.0, duration: 0.15 }, T.face);
    jump(T.face, h0.x, h0.y, h0.x + S * 0.6, h0.y + S * 0.15, 0.25, S * 0.25);
    tl.to(img, { rotation: -10, duration: 0.12, ease: 'sine.inOut' }, T.face + 0.3);
    tl.to(img, { rotation: 10, duration: 0.14, yoyo: true, repeat: 2, ease: 'sine.inOut' }, T.face + 0.42);
    tl.to(img, { rotation: 0, duration: 0.1 }, T.face + 0.82);
    tl.fromTo(love, { opacity: 0, scale: 0.4 }, { opacity: 1, scale: 1, duration: 0.22, ease: 'back.out(3)' }, T.face + 0.32);
    tl.to(love, { opacity: 0, y: -14, duration: 0.25 }, T.face + 0.7);

    // 06 paint 4.6-6.35 with lots of data flowing through the white
    const p0 = paint.getPointAtLength(0);
    jump(T.paint - 0.1, h0.x + S * 0.6, h0.y + S * 0.15, p0.x, p0.y, 0.25, S * 0.4);
    tl.to(rig, { opacity: 1, duration: 0.1 }, T.paint + 0.1);
    followDraw(paint, T.paint + 0.15, 1.7, 'power1.inOut', [streak]);
    lean(T.paint + 0.15, 1.7);
    tl.to(fill, { attr: { opacity: 1 }, duration: 0.2 }, T.fill);
    tl.to(barFill, { attr: { opacity: 1 }, duration: 0.2 }, T.fill);
    tl.to(dataG, { opacity: cfg.codeOpacity, duration: 0.5 }, T.paint + 0.2);
    tl.to(dataG, { opacity: cfg.codeOpacity * 0.55, duration: 0.6 }, T.write - 0.2);     // calmer while the text is written
    // 07 welcome box 6.6-7.85
    const w0 = wel.getPointAtLength(0);
    const pEnd = paint.getPointAtLength(paint.getTotalLength());
    jump(T.welcome - 0.25, pEnd.x, pEnd.y, w0.x, w0.y, 0.25, S * 0.3);
    followDraw(wel, T.welcome, 1.15, 'none', null, true);
    lean(T.welcome, 1.15);
    // 08 write 7.85-9.0
    tl.to(tclipRect, { attr: { width: wx + ww + 10 }, duration: 1.05, ease: 'power1.inOut' }, T.write);
    tl.to({ v: 0 }, { v: 1, duration: 1.05, ease: 'power1.inOut', onUpdate() {
      const q = this.progress();
      place(wx + 20 + (ww - 40) * q, wy + fs + 22 + Math.sin(q * 40) * 3);        // little scribble while writing
    } }, T.write);
    lean(T.write, 1.05);
    // 09 input + status 9.0-9.85, tab 9.85-10.5
    const i0 = input.getPointAtLength(0);
    jump(T.input - 0.15, wx + ww - 20, wy + fs + 22, i0.x, i0.y, 0.25, S * 0.4);
    followDraw(input, T.input + 0.12, 0.6, 'power1.inOut');
    tl.to([prompt, status], { attr: { opacity: 1 }, duration: 0.25 }, T.input + 0.7);
    jump(T.tab - 0.05, c.x + c.w - 18, iy + 42, r.x + 30, r.y + TB * 0.55, 0.35, S * 0.9);
    tl.to(tabRect, { scaleX: 1, duration: 0.3, ease: 'power2.out' }, T.tab + 0.3);
    tl.to({ v: 0 }, { v: 1, duration: 0.3, ease: 'power2.out', onUpdate() { place(r.x + 30 + 160 * this.progress(), r.y + TB * 0.55); } }, T.tab + 0.3);
    tl.to(tabText, { attr: { opacity: 1 }, duration: 0.15 }, T.tab + 0.5);
    // 10 hand-over 10.5-11.8: toss the marker, overlay fades, hop into the input box, wave, vanish
    tl.to(rig, { opacity: 0, duration: 0.25 }, T.out);
    tl.to(rigSvg, { y: -30, rotation: 8, duration: 0.25, ease: 'power2.out' }, T.out);
    tl.to([svg, dataG], { opacity: 0, duration: 0.9, ease: 'power1.in' }, T.out);
    jump(T.out + 0.05, r.x + 190, r.y + TB * 0.55, c.x + 70, iy + 34, 0.45, S * 0.8);
    tl.to(img, { rotation: -12, duration: 0.13, yoyo: true, repeat: 3, ease: 'sine.inOut' }, T.out + 0.6);
    tl.to(ch, { scale: 0.4, opacity: 0, duration: 0.45, ease: 'power2.in', transformOrigin: '30% 100%' }, T.end - 0.5);
    tl.set({}, {}, T.end);

    // data streams move on every frame (seek-safe: positions are a pure function of time)
    onUpdate(tl, () => {
      const t = tl.time();
      cols.forEach((col) => {
        const off = (t * col.speed) % col.span;
        col.g.setAttribute('transform', `translate(0 ${(col.dir < 0 ? -off : off - col.span).toFixed(1)})`);
      });
      packets.forEach((p) => {
        const x = c.x + ((p.off + t * p.speed) % (c.w + 80)) - 40;
        p.t.setAttribute('x', x.toFixed(1));
      });
    });
    // hand-drawn boil on everything that was drawn (calm pose, classic frame drop 3)
    boil(tl, [body, welG, tg, inG, tab], { amp: 1.4, rot: 0.25, frameDrop: 3, seed: 2 });
    tl.covered = T.fill + 0.2;                             // when the real tab may open underneath
    return tl;
  }

  global.ClaudeIntro = { build };
})(typeof window !== 'undefined' ? window : globalThis);
