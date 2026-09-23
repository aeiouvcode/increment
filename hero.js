// Depth-parallax hero: an illustrated station interior split into depth layers,
// rendered with three.js. Falls back to a flat composite on low-end or no-WebGL devices.
import * as THREE from './three.module.min.js';

const P = { wall: '#1f3b39', wall2: '#274a47', seam: 'rgba(210,235,228,0.10)', teal: '#3f7d74', mint: '#8fc3b4',
  amber: '#f0b25a', warm: '#ffcf8a', space: '#060b0e' };

function cv(w, h, draw) { const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d'), w, h); return c; }
function rnd(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296); }

// Layer 0: Earth and space as seen through the porthole
function earthLayer(t = 0) {
  return cv(1024, 1024, (g, w, h) => {
    g.fillStyle = P.space; g.fillRect(0, 0, w, h);
    const r = rnd(4);
    for (let i = 0; i < 160; i++) { g.fillStyle = `rgba(255,255,255,${r() * 0.5})`; g.fillRect(r() * w, r() * h * 0.45, 1.4, 1.4); }
    const R = w * 1.6, cx = w * 0.5, cy = h * 0.42 + R;
    const eg = g.createRadialGradient(cx, cy - R * 0.2, R * 0.6, cx, cy, R);
    eg.addColorStop(0, '#1f4d6a'); eg.addColorStop(0.92, '#2f6c8c'); eg.addColorStop(1, '#6fb2cf');
    g.fillStyle = eg; g.beginPath(); g.arc(cx, cy, R, 0, Math.PI * 2); g.fill();
    g.save(); g.beginPath(); g.arc(cx, cy, R, 0, Math.PI * 2); g.clip();
    for (let i = 0; i < 9; i++) { // irregular coastlines, flattened by the oblique view
      const cx0 = r() * w, cy0 = h * 0.5 + r() * h * 0.5, base = 50 + r() * 110;
      g.fillStyle = r() > 0.5 ? 'rgba(112,124,86,0.8)' : 'rgba(160,142,104,0.75)';
      g.beginPath();
      for (let k = 0; k <= 40; k++) { const a = k / 40 * Math.PI * 2; const rr = base * (0.6 + 0.4 * Math.sin(a * 3 + i) * Math.cos(a * 5 + i * 2) + 0.25 * r());
        const x = cx0 + Math.cos(a) * rr * 1.5, y = cy0 + Math.sin(a) * rr * 0.42; k ? g.lineTo(x, y) : g.moveTo(x, y); }
      g.closePath(); g.fill();
    }
    for (let i = 0; i < 260; i++) { // cloud streaks, flattened by the oblique view
      const y = h * 0.44 + Math.pow(r(), 1.4) * h * 0.56, depth = (y - h * 0.44) / (h * 0.56);
      const x = r() * w, s = (6 + r() * 26) * (0.5 + depth);
      g.fillStyle = `rgba(245,247,244,${0.12 + r() * 0.3})`;
      g.beginPath(); g.ellipse(x, y, s * 2.6, s * 0.28 * (0.4 + depth), -0.05, 0, Math.PI * 2); g.fill();
    }
    const sh = g.createLinearGradient(0, 0, w, 0); sh.addColorStop(0, 'rgba(6,11,14,0.55)'); sh.addColorStop(0.35, 'rgba(6,11,14,0)'); g.fillStyle = sh; g.fillRect(0, h * 0.4, w, h);
    g.restore();
    g.strokeStyle = 'rgba(140,200,240,0.9)'; g.lineWidth = 5; g.beginPath(); g.arc(cx, cy, R + 3, 0, Math.PI * 2); g.stroke();
    g.strokeStyle = 'rgba(120,190,240,0.25)'; g.lineWidth = 26; g.beginPath(); g.arc(cx, cy, R + 14, 0, Math.PI * 2); g.stroke();
  });
}

// Layer 1: back wall with a big porthole cut out
function wallLayer() {
  return cv(1024, 1024, (g, w, h) => {
    const bg = g.createLinearGradient(0, 0, 0, h); bg.addColorStop(0, P.wall2); bg.addColorStop(1, P.wall);
    g.fillStyle = bg; g.fillRect(0, 0, w, h);
    g.strokeStyle = P.seam; g.lineWidth = 2;
    for (let x = 0; x <= w; x += 128) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, h); g.stroke(); }
    for (let y = 96; y < h; y += 210) { g.beginPath(); g.moveTo(0, y); g.lineTo(w, y); g.stroke(); }
    const cx = w * 0.5, cy = h * 0.46, r = w * 0.27;
    g.fillStyle = '#16302e'; g.beginPath(); g.arc(cx, cy, r + 46, 0, Math.PI * 2); g.fill();
    g.strokeStyle = 'rgba(200,230,222,0.18)'; g.lineWidth = 3; g.beginPath(); g.arc(cx, cy, r + 46, 0, Math.PI * 2); g.stroke();
    for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2; g.fillStyle = 'rgba(210,235,228,0.35)';
      g.beginPath(); g.arc(cx + Math.cos(a) * (r + 26), cy + Math.sin(a) * (r + 26), 4, 0, Math.PI * 2); g.fill(); }
    g.globalCompositeOperation = 'destination-out'; g.beginPath(); g.arc(cx, cy, r, 0, Math.PI * 2); g.fill();
    g.globalCompositeOperation = 'source-over';
    g.strokeStyle = 'rgba(255,255,255,0.08)'; g.lineWidth = 8; g.beginPath(); g.arc(cx, cy, r * 0.86, -2.6, -1.9); g.stroke();
  });
}

// Layer 2: side consoles with warm indicator lights
function consoleLayer() {
  return cv(1024, 1024, (g, w, h) => {
    const r = rnd(11);
    for (const side of [0, 1]) {
      const x0 = side ? 572 : 268, w0 = 184, y0 = h * 0.60;
      g.fillStyle = '#2d504c'; g.fillRect(x0, y0, w0, h - y0);
      g.strokeStyle = 'rgba(210,235,228,0.16)'; g.lineWidth = 2; g.strokeRect(x0 + 12, y0 + 12, w0 - 24, 64);
      g.fillStyle = '#12211f'; g.fillRect(x0 + 20, y0 + 20, w0 - 40, 48);
      for (let i = 0; i < 4; i++) { g.fillStyle = `rgba(143,195,180,${0.35 + r() * 0.4})`; g.fillRect(x0 + 28, y0 + 28 + i * 10, 30 + r() * 80, 2); }
      for (let i = 0; i < 10; i++) {
        const x = x0 + 26 + (i % 5) * 32, y = y0 + 104 + Math.floor(i / 5) * 26;
        const on = r() > 0.3; g.fillStyle = on ? P.amber : 'rgba(240,178,90,0.18)';
        g.beginPath(); g.arc(x, y, 4.5, 0, Math.PI * 2); g.fill();
        if (on) { const rg = g.createRadialGradient(x, y, 0, x, y, 18); rg.addColorStop(0, 'rgba(255,190,110,0.35)'); rg.addColorStop(1, 'rgba(255,190,110,0)'); g.fillStyle = rg; g.fillRect(x - 18, y - 18, 36, 36); }
      }
    }
  });
}

// Layer 3: foreground hatch edge, a cable, a floating pen
function frontLayer() {
  return cv(1024, 1024, (g, w, h) => {
    g.fillStyle = '#10201e'; g.beginPath(); g.rect(0, 0, w, h); g.ellipse(w * 0.5, h * 0.52, w * 0.56, h * 0.6, 0, 0, Math.PI * 2, true); g.fill();
    g.strokeStyle = 'rgba(200,230,222,0.14)'; g.lineWidth = 4; g.beginPath(); g.ellipse(w * 0.5, h * 0.52, w * 0.56, h * 0.6, 0, 0, Math.PI * 2); g.stroke();
    g.strokeStyle = '#0b1716'; g.lineWidth = 12; g.beginPath(); g.moveTo(-10, h * 0.12); g.bezierCurveTo(w * 0.25, h * 0.2, w * 0.2, h * 0.02, w * 0.46, -10); g.stroke();
    g.save(); g.translate(w * 0.72, h * 0.3); g.rotate(-0.5);
    g.fillStyle = '#0d1a19'; g.fillRect(-60, -7, 120, 14); g.fillStyle = P.amber; g.fillRect(50, -7, 14, 14); g.restore();
  });
}

function tex(c) { const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4; return t; }

function lowEnd() {
  const n = navigator.hardwareConcurrency || 4, m = navigator.deviceMemory || 4;
  return n <= 2 || m <= 2 || matchMedia('(prefers-reduced-motion: reduce)').matches;
}

function webgl() { try { const c = document.createElement('canvas'); return !!(c.getContext('webgl2') || c.getContext('webgl')); } catch { return false; } }

export function staticHero(el) {
  const c = document.createElement('canvas'); const d = Math.min(2, devicePixelRatio || 1);
  const W = el.clientWidth, H = el.clientHeight; c.width = W * d; c.height = H * d; c.style.cssText = 'width:100%;height:100%;display:block';
  const g = c.getContext('2d'); const s = Math.max(c.width, c.height);
  for (const L of [earthLayer(), wallLayer(), consoleLayer(), frontLayer()]) g.drawImage(L, (c.width - s) / 2, (c.height - s) / 2, s, s);
  el.appendChild(c); el.dataset.mode = 'static'; return { mode: 'static' };
}

export function mountHero(el, opts = {}) {
  if (opts.force !== 'webgl' && (opts.force === 'static' || !webgl() || lowEnd())) return staticHero(el);
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
  renderer.setPixelRatio(Math.min(2, devicePixelRatio || 1));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  el.appendChild(renderer.domElement); renderer.domElement.style.cssText = 'width:100%;height:100%;display:block';
  const scene = new THREE.Scene(); scene.background = new THREE.Color(P.space);
  const cam = new THREE.PerspectiveCamera(40, 1, 0.1, 50); cam.position.set(0, 0, 6);
  const layers = [[earthLayer(), -6, 1.0], [wallLayer(), -2.6, 1.0], [consoleLayer(), -1.3, 1.0], [frontLayer(), 0.2, 1.0]];
  const planes = layers.map(([c, z]) => {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({ map: tex(c), transparent: true, depthWrite: false }));
    m.position.z = z; scene.add(m); return m;
  });
  const earthTex = planes[0].material.map; earthTex.wrapS = THREE.RepeatWrapping;
  // warm console glow and drifting dust
  const glow = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({ map: tex(cv(256, 256, (g) => {
    const rg = g.createRadialGradient(128, 128, 0, 128, 128, 128); rg.addColorStop(0, 'rgba(255,190,110,0.16)'); rg.addColorStop(1, 'rgba(255,190,110,0)'); g.fillStyle = rg; g.fillRect(0, 0, 256, 256); })),
    transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
  glow.position.set(0, -0.9, -1.2); scene.add(glow);
  const N = 140, pos = new Float32Array(N * 3), r = rnd(7);
  for (let i = 0; i < N; i++) { pos[i * 3] = (r() - 0.5) * 4; pos[i * 3 + 1] = (r() - 0.5) * 3; pos[i * 3 + 2] = -2 + r() * 2.5; }
  const dg = new THREE.BufferGeometry(); dg.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const dust = new THREE.Points(dg, new THREE.PointsMaterial({ color: 0xd8efe7, size: 0.012, transparent: true, opacity: 0.55, depthWrite: false }));
  scene.add(dust);

  function fit() {
    const W = el.clientWidth, H = el.clientHeight; renderer.setSize(W, H, false); cam.aspect = W / H; cam.updateProjectionMatrix();
    const span = (z) => { const d = cam.position.z - z; const hh = 2 * d * Math.tan(THREE.MathUtils.degToRad(cam.fov / 2)); return Math.max(hh, hh * cam.aspect) * 1.18; };
    planes.forEach((p) => { const s = span(p.position.z); p.scale.set(s, s, 1); });
    glow.scale.setScalar(span(-1.2) * 0.45);
  }
  fit(); addEventListener('resize', fit);
  const aim = { x: 0, y: 0 }, cur = { x: 0, y: 0 };
  el.addEventListener('pointermove', (e) => { const b = el.getBoundingClientRect(); aim.x = ((e.clientX - b.left) / b.width - 0.5) * 2; aim.y = ((e.clientY - b.top) / b.height - 0.5) * 2; });
  const onTilt = (e) => { if (e.gamma == null) return; aim.x = Math.max(-1, Math.min(1, e.gamma / 25)); aim.y = Math.max(-1, Math.min(1, (e.beta - 45) / 25)); };
  const askTilt = () => { const D = window.DeviceOrientationEvent; if (D && typeof D.requestPermission === 'function') D.requestPermission().then((s) => s === 'granted' && addEventListener('deviceorientation', onTilt)).catch(() => {}); else addEventListener('deviceorientation', onTilt); };
  el.addEventListener('pointerdown', askTilt, { once: true }); if (!(window.DeviceOrientationEvent && DeviceOrientationEvent.requestPermission)) askTilt();
  let t0 = performance.now(), slow = 0, running = true;
  function frame(now) {
    if (!running) return;
    const dt = Math.min(0.05, (now - t0) / 1000); t0 = now;
    if (dt > 0.034) { slow++; if (slow > 90) { running = false; renderer.domElement.remove(); staticHero(el); return; } } else slow = Math.max(0, slow - 1);
    cur.x += (aim.x - cur.x) * Math.min(1, dt * 3); cur.y += (aim.y - cur.y) * Math.min(1, dt * 3);
    const tt = now / 1000;
    cam.position.x = cur.x * 0.32 + Math.sin(tt * 0.21) * 0.05; cam.position.y = -cur.y * 0.22 + Math.cos(tt * 0.17) * 0.04; cam.lookAt(0, 0, -2);
    earthTex.offset.x = tt * 0.004;
    glow.material.opacity = 0.7 + 0.3 * Math.sin(tt * 1.3);
    dust.rotation.z = tt * 0.01; dust.position.y = Math.sin(tt * 0.3) * 0.05;
    renderer.render(scene, cam); requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame); el.dataset.mode = 'webgl';
  return { mode: 'webgl', stop() { running = false; } };
}
