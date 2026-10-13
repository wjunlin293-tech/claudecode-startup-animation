// Renderer: read the terminal rect + settings handed over by main.js, then play once.
(function () {
  const q = new URLSearchParams(location.search);
  const rect = JSON.parse(q.get('rect'));
  const cfg = JSON.parse(q.get('config') || '{}');
  const assets = JSON.parse(q.get('assets') || '{}');
  const stage = document.getElementById('stage');
  // stay in real time: if a frame is slow, drop frames instead of stretching the animation
  if (window.gsap) window.gsap.ticker.lagSmoothing(0);
  let frames = 0; if (window.gsap) window.gsap.ticker.add(() => { frames++; });
  const go = () => {
    const tl = window.ClaudeIntro.build({
      root: stage, rect, stage: { w: window.innerWidth, h: window.innerHeight }, assets, config: cfg,
    });
    // the terminal is completely painted over -> open the real Claude Code tab underneath
    tl.call(() => { if (window.intro) window.intro.covered(); }, null, tl.covered || 6.55);
    tl.timeScale(cfg.speed || 1);
    const t0 = performance.now();
    tl.eventCallback('onComplete', () => { console.log('[intro] done in ' + ((performance.now() - t0) / 1000).toFixed(1) + 's, avg fps ' + (frames / ((performance.now() - t0) / 1000)).toFixed(0)); window.close(); });
    tl.play(0);
  };
  const fontsReady = document.fonts ? document.fonts.ready : Promise.resolve();
  Promise.race([fontsReady, new Promise((r) => setTimeout(r, 300))]).then(go);
})();
