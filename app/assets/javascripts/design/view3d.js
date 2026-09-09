// Design Center — 3D view (Phase 3). Builds a Three.js scene from floor-plan JSON
// (see app/models/design/floor_plan.rb for the data shape). Plan x → x, plan y → z, up → y.
// Levels stack by position; roofs are generated over each level's footprint minus the
// footprint of the level above. Mounted by app/views/design/floor_plans/view3d.html.erb.
(function () {
  "use strict";

  var WALL_H = 9, FLOOR_T = 1, DOOR_H = 6.67, SILL = 3, HEAD = 6.67, OVERHANG = 1.5, TILE = 4; // TILE = texture tile size in ft
  var C = { interior: "#f4f3ee", slab: "#b9b6ad", ground: "#c9d3bf", door: "#8a5a2b", garage: "#dcd8cf", glass: "#9ccbe8", frame: "#ffffff" };
  var EXTERIORS = { stucco: { label: "Stucco (cream)", kind: "stucco", color: "#e6dcc6" }, white: { label: "White", kind: "stucco", color: "#f3f1ea" }, gray: { label: "Warm gray", kind: "stucco", color: "#b9b3a6" }, siding: { label: "Wood siding", kind: "siding", color: "#c9b48f" }, brick: { label: "Brick", kind: "brick", color: "#9a5a44" } };
  var ROOF_COLORS = { asphalt: { label: "Asphalt shingle", kind: "shingle", color: "#5a5b5e" }, brown: { label: "Brown shingle", kind: "shingle", color: "#6b5040" }, tile: { label: "Terracotta tile", kind: "tile", color: "#b5623f" }, metal: { label: "Standing-seam metal", kind: "metal", color: "#6d7a86" } };
  var FLOORS = { wood: { label: "Wood", kind: "wood", color: "#c9a878" }, tile: { label: "Tile", kind: "tilefloor", color: "#cfcac0" }, concrete: { label: "Concrete", kind: "concrete", color: "#b4b1aa" } };
  var ROOF_STYLES = [["hip6", "Hip 6:12"], ["hip4", "Hip 4:12"], ["hip8", "Hip 8:12"], ["gable6", "Gable 6:12"], ["gable4", "Gable 4:12"], ["gable8", "Gable 8:12"], ["flat", "Flat"], ["none", "No roof"]];
  var DEFAULTS = { roof: "hip6", exterior: "stucco", roofColor: "asphalt", floor: "wood" };
  var FIX = {
    stairs: { h: WALL_H, c: 0xc8b18a }, toilet: { h: 1.4, c: 0xfafafa }, sink: { h: 3, c: 0xfafafa }, tub: { h: 1.8, c: 0xfafafa }, shower: { h: 0.3, c: 0xe8eef2 },
    range: { h: 3, c: 0x8b9096 }, fridge: { h: 6, c: 0xb8bcc2 }, dishwasher: { h: 2.9, c: 0xb8bcc2 }, washer: { h: 3, c: 0xe9e9e9 }, water_heater: { h: 5, c: 0xcfcfcf },
    counter: { h: 3, c: 0xd8cfc0 }, island: { h: 3, c: 0xd8cfc0 }, bed: { h: 2, c: 0x9fb4c7 }, bed_king: { h: 2, c: 0x9fb4c7 }, sofa: { h: 2.5, c: 0x8c8f9a },
    table: { h: 2.5, c: 0xa77b4d }, desk: { h: 2.5, c: 0xa77b4d }, car: { h: 4.7, c: 0x6b7f99 }, box: { h: 3, c: 0xbfbfbf }
  };

  function rng(seed) { return function () { seed |= 0; seed = seed + 0x6D2B79F5 | 0; var t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

  // Procedural textures drawn on a canvas; one tile = TILE ft, UVs are in feet.
  function makeTexture(kind, color) {
    var size = 256, ppf = size / TILE, cv = document.createElement("canvas"); cv.width = cv.height = size;
    var g = cv.getContext("2d"), rnd = rng(7), x, y, r;
    var shade = function (a, dark) { g.fillStyle = (dark ? "rgba(0,0,0," : "rgba(255,255,255,") + a + ")"; };
    g.fillStyle = color; g.fillRect(0, 0, size, size);
    switch (kind) {
      case "stucco": for (var i = 0; i < 5000; i++) { shade(0.05, rnd() < 0.5); g.fillRect(rnd() * size, rnd() * size, 1.5, 1.5); } break;
      case "siding": var lap = ppf * 0.667; for (y = 0; y < size; y += lap) { var gr = g.createLinearGradient(0, y, 0, y + lap); gr.addColorStop(0, "rgba(255,255,255,0.12)"); gr.addColorStop(1, "rgba(0,0,0,0.10)"); g.fillStyle = gr; g.fillRect(0, y, size, lap); shade(0.28, true); g.fillRect(0, y + lap - 2, size, 2); } break;
      case "brick": var bh = ppf * 0.222, bw = ppf * 0.667; g.fillStyle = "#cfc6b8"; g.fillRect(0, 0, size, size); r = 0;
        for (y = 0; y < size; y += bh, r++) { var off = r % 2 ? bw / 2 : 0; for (x = -bw; x < size + bw; x += bw) { g.fillStyle = color; g.fillRect(x + off + 1.5, y + 1.5, bw - 3, bh - 3); shade(rnd() * 0.18, rnd() < 0.5); g.fillRect(x + off + 1.5, y + 1.5, bw - 3, bh - 3); } } break;
      case "shingle": var rh = ppf * 0.5, tw = ppf; r = 0;
        for (y = 0; y < size; y += rh, r++) { var o2 = r % 2 ? tw / 2 : 0; for (x = -tw; x < size + tw; x += tw) { shade(rnd() * 0.10, rnd() < 0.5); g.fillRect(x + o2, y, tw, rh); shade(0.18, true); g.fillRect(x + o2, y, 1.5, rh); } shade(0.35, true); g.fillRect(0, y, size, 2); } break;
      case "tile": var tw2 = ppf * 0.75; for (x = 0; x < size; x += tw2) { var g2 = g.createLinearGradient(x, 0, x + tw2, 0); g2.addColorStop(0, "rgba(0,0,0,0.28)"); g2.addColorStop(0.5, "rgba(255,255,255,0.14)"); g2.addColorStop(1, "rgba(0,0,0,0.28)"); g.fillStyle = g2; g.fillRect(x, 0, tw2, size); } for (y = 0; y < size; y += ppf * 1.2) { shade(0.18, true); g.fillRect(0, y, size, 2); } break;
      case "metal": var sw = ppf * 1.333; for (x = 0; x < size; x += sw) { shade(0.28, true); g.fillRect(x, 0, 2, size); shade(0.14, false); g.fillRect(x + 2, 0, 2, size); } break;
      case "wood": var pw = ppf * 0.5; for (y = 0; y < size; y += pw) { x = -rnd() * ppf * 3; while (x < size) { var len = ppf * (2 + rnd() * 3); shade(rnd() * 0.14, rnd() < 0.6); g.fillRect(x, y, len, pw); shade(0.3, true); g.fillRect(x, y, 1.5, pw); x += len; } shade(0.22, true); g.fillRect(0, y, size, 1); } break;
      case "tilefloor": shade(0.2, true); for (x = 0; x <= size; x += ppf) g.fillRect(x - 1, 0, 2, size); for (y = 0; y <= size; y += ppf) g.fillRect(0, y - 1, size, 2); break;
      case "concrete": for (var j = 0; j < 7000; j++) { shade(0.06, rnd() < 0.5); g.fillRect(rnd() * size, rnd() * size, 2, 2); } break;
    }
    var t = new THREE.CanvasTexture(cv); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(1 / TILE, 1 / TILE); t.anisotropy = 4; t.encoding = THREE.sRGBEncoding;
    return t;
  }

  // BoxGeometry UVs run 0..1 per face; rescale them to feet (plus an offset so split wall pieces line up).
  function scaleBoxUV(geo, w, h, d, uOff, vOff) {
    var uv = geo.attributes.uv, dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]];
    for (var f = 0; f < 6; f++) for (var i = 0; i < 4; i++) { var k = f * 4 + i; uv.setXY(k, uv.getX(k) * dims[f][0] + (uOff || 0), uv.getY(k) * dims[f][1] + (vOff || 0)); }
    uv.needsUpdate = true;
  }

  function View(root, opts) {
    this.root = root; this.opts = opts; this.levels = opts.levels || [];
    this.settings = Object.assign({}, DEFAULTS, opts.settings || {});
    if (!EXTERIORS[this.settings.exterior]) this.settings.exterior = DEFAULTS.exterior;
    if (!ROOF_COLORS[this.settings.roofColor]) this.settings.roofColor = DEFAULTS.roofColor;
    if (!FLOORS[this.settings.floor]) this.settings.floor = DEFAULTS.floor;
    this.visible = {}; this.levels.forEach(function (l) { this.visible[l.id] = true; }, this);
    this.materials = {};
    this.setupScene(); this.buildUI(); this.rebuild(); this.resetView(); this.animate();
  }
  var P = View.prototype;

  P.mat = function (color, extra) {
    var key = "c" + color + JSON.stringify(extra || {});
    if (!this.materials[key]) this.materials[key] = new THREE.MeshStandardMaterial(Object.assign({ color: color, roughness: 0.85, metalness: 0.02 }, extra || {}));
    return this.materials[key];
  };
  P.texMat = function (spec, extra) {
    var key = "t" + spec.kind + spec.color;
    if (!this.materials[key]) this.materials[key] = new THREE.MeshStandardMaterial(Object.assign({ map: makeTexture(spec.kind, spec.color), roughness: 0.9, metalness: 0.02 }, extra || {}));
    return this.materials[key];
  };

  P.setupScene = function () {
    var w = this.root.clientWidth, h = this.root.clientHeight;
    this.renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.setSize(w, h); this.renderer.shadowMap.enabled = true; this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.outputEncoding = THREE.sRGBEncoding;
    this.root.appendChild(this.renderer.domElement);

    this.scene = new THREE.Scene(); this.scene.background = new THREE.Color(0xdfe7ee);
    this.scene.fog = new THREE.Fog(0xdfe7ee, 400, 900);
    this.camera = new THREE.PerspectiveCamera(45, w / h, 0.5, 2000);
    this.controls = new THREE.OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true; this.controls.dampingFactor = 0.08; this.controls.maxPolarAngle = Math.PI / 2 - 0.02;

    this.scene.add(new THREE.HemisphereLight(0xffffff, 0x8a9a7a, 0.55));
    var sun = new THREE.DirectionalLight(0xfff2dd, 1.15); sun.position.set(80, 120, 60); sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048); sun.shadow.camera.near = 10; sun.shadow.camera.far = 400;
    sun.shadow.camera.left = sun.shadow.camera.bottom = -120; sun.shadow.camera.right = sun.shadow.camera.top = 120; sun.shadow.bias = -0.0005;
    this.scene.add(sun); this.sun = sun;

    var ground = new THREE.Mesh(new THREE.PlaneGeometry(2000, 2000), this.mat(C.ground, { roughness: 1 }));
    ground.rotation.x = -Math.PI / 2; ground.position.y = -FLOOR_T - 0.01; ground.receiveShadow = true; this.scene.add(ground);

    this.model = new THREE.Group(); this.scene.add(this.model);
    var self = this;
    if (window.ResizeObserver) new ResizeObserver(function () { self.resize(); }).observe(this.root); else window.addEventListener("resize", function () { self.resize(); });
  };

  P.resize = function () {
    var w = this.root.clientWidth, h = this.root.clientHeight; if (!w || !h) return;
    this.camera.aspect = w / h; this.camera.updateProjectionMatrix(); this.renderer.setSize(w, h);
  };

  P.buildUI = function () {
    var ui = this.opts.ui, self = this;
    this.levels.forEach(function (l) {
      var lab = document.createElement("label"); lab.className = "form-check form-check-inline small mb-0";
      lab.innerHTML = '<input class="form-check-input" type="checkbox" checked> <span>' + (l.name + (l.level ? " · " + l.level : "")).replace(/[<>&]/g, "") + "</span>";
      lab.querySelector("input").addEventListener("change", function (e) { self.visible[l.id] = e.target.checked; self.rebuild(); });
      ui.levels.appendChild(lab);
    });
    ui.reset.addEventListener("click", function () { self.resetView(); });
    ui.render.addEventListener("click", function () { self.saveRendering(); });
    this.status = ui.status;
    var fill = function (sel, key, options) {
      if (!sel) return;
      options.forEach(function (o) { var el = document.createElement("option"); el.value = o[0]; el.textContent = o[1]; sel.appendChild(el); });
      sel.value = self.settings[key];
      sel.addEventListener("change", function () { self.settings[key] = sel.value; self.rebuild(); self.saveSettings(); });
    };
    var pairs = function (obj) { return Object.keys(obj).map(function (k) { return [k, obj[k].label]; }); };
    fill(ui.roof, "roof", ROOF_STYLES); fill(ui.exterior, "exterior", pairs(EXTERIORS)); fill(ui.roofColor, "roofColor", pairs(ROOF_COLORS)); fill(ui.floor, "floor", pairs(FLOORS));
  };

  P.saveSettings = function () {
    if (!this.opts.settingsUrl) return;
    var self = this;
    fetch(this.opts.settingsUrl, { method: "PATCH", credentials: "same-origin", headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": this.opts.csrf }, body: JSON.stringify({ design_concept: { render_settings: this.settings } }) })
      .then(function (r) { if (!r.ok) throw 0; self.status.textContent = "Style saved"; }).catch(function () { self.status.textContent = "Could not save style"; });
  };

  // ------------------------------------------------------------ geometry
  P.rebuild = function () {
    while (this.model.children.length) this.model.remove(this.model.children[0]);
    var self = this, any = false, bbox = { minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity };
    this.extMat = this.texMat(EXTERIORS[this.settings.exterior]);
    this.floorMat = this.texMat(FLOORS[this.settings.floor], { roughness: 0.7 });
    this.roofMat = this.texMat(ROOF_COLORS[this.settings.roofColor], { side: THREE.DoubleSide });
    var footprints = [];

    this.levels.forEach(function (l, i) {
      if (!self.visible[l.id]) { footprints.push(null); return; }
      var base = i * (WALL_H + FLOOR_T), d = l.data || {};
      var walls = d.walls || [], rooms = d.rooms || [], openings = d.openings || [], fixtures = d.fixtures || [];
      var ext = walls.filter(function (w) { return w.type === "exterior"; }), src = ext.length ? ext : walls;
      var fx0 = Infinity, fy0 = Infinity, fx1 = -Infinity, fy1 = -Infinity;
      src.concat(rooms.map(function (r) { return { x1: r.x, y1: r.y, x2: r.x + r.w, y2: r.y + r.h }; })).forEach(function (w) { fx0 = Math.min(fx0, w.x1, w.x2); fx1 = Math.max(fx1, w.x1, w.x2); fy0 = Math.min(fy0, w.y1, w.y2); fy1 = Math.max(fy1, w.y1, w.y2); });
      if (!isFinite(fx0)) { footprints.push(null); return; }
      any = true; bbox.minX = Math.min(bbox.minX, fx0); bbox.maxX = Math.max(bbox.maxX, fx1); bbox.minY = Math.min(bbox.minY, fy0); bbox.maxY = Math.max(bbox.maxY, fy1);
      footprints.push({ x0: fx0, x1: fx1, z0: fy0, z1: fy1, base: base });

      self.box(fx1 - fx0 + 0.5, FLOOR_T, fy1 - fy0 + 0.5, (fx0 + fx1) / 2, base - FLOOR_T / 2, (fy0 + fy1) / 2, self.mat(C.slab), false, true);
      rooms.forEach(function (r) { self.box(r.w, 0.06, r.h, r.x + r.w / 2, base + 0.03, r.y + r.h / 2, self.floorMat, false, true, 0, r.x, r.y); });
      walls.forEach(function (w) { self.wall(w, openings.filter(function (o) { return o.wall === w.id; }), base); });
      fixtures.forEach(function (f) { self.fixture(f, base); });
    });

    // roofs: each level's footprint minus the footprint of the next visible level above it
    if (this.settings.roof !== "none") footprints.forEach(function (fp, i) {
      if (!fp) return;
      var above = null; for (var j = i + 1; j < footprints.length; j++) if (footprints[j]) { above = footprints[j]; break; }
      var rects = above ? self.subtract(fp, above) : [fp];
      rects.forEach(function (r) { if (r.x1 - r.x0 >= 4 && r.z1 - r.z0 >= 4) self.roof(r, fp.base + WALL_H); });
    });

    this.bbox = any ? bbox : { minX: 0, minY: 0, maxX: 40, maxY: 30 };
    this.levelsShown = footprints.filter(Boolean).length;
    var empty = this.root.querySelector(".v3-empty");
    if (!any) { if (!empty) { empty = document.createElement("div"); empty.className = "v3-empty"; empty.textContent = "Nothing to show yet — draw some walls or rooms in the editor first."; this.root.appendChild(empty); } }
    else if (empty) empty.remove();
  };

  P.subtract = function (a, b) {  // axis-aligned rectangle difference → up to 4 rectangles
    var ix0 = Math.max(a.x0, b.x0), ix1 = Math.min(a.x1, b.x1), iz0 = Math.max(a.z0, b.z0), iz1 = Math.min(a.z1, b.z1);
    if (ix1 - ix0 < 1 || iz1 - iz0 < 1) return [a];
    var out = [];
    if (ix0 - a.x0 >= 1) out.push({ x0: a.x0, x1: ix0, z0: a.z0, z1: a.z1 });
    if (a.x1 - ix1 >= 1) out.push({ x0: ix1, x1: a.x1, z0: a.z0, z1: a.z1 });
    if (iz0 - a.z0 >= 1) out.push({ x0: ix0, x1: ix1, z0: a.z0, z1: iz0 });
    if (a.z1 - iz1 >= 1) out.push({ x0: ix0, x1: ix1, z0: iz1, z1: a.z1 });
    return out;
  };

  P.box = function (w, h, d, x, y, z, material, castShadow, receiveShadow, rotY, uOff, vOff) {
    var geo = new THREE.BoxGeometry(w, h, d); scaleBoxUV(geo, w, h, d, uOff, vOff);
    var m = new THREE.Mesh(geo, material);
    m.position.set(x, y, z); if (rotY) m.rotation.y = rotY;
    m.castShadow = castShadow !== false; m.receiveShadow = receiveShadow !== false;
    this.model.add(m); return m;
  };

  // A wall becomes solid pieces between openings, headers above doors, sill/head pieces plus glass for windows, and white trim.
  P.wall = function (w, ops, base) {
    var dx = w.x2 - w.x1, dz = w.y2 - w.y1, len = Math.hypot(dx, dz); if (len < 0.01) return;
    var t = w.thickness || (w.type === "interior" ? 0.375 : 0.5), ang = -Math.atan2(dz, dx), ux = dx / len, uz = dz / len;
    var material = w.type === "interior" ? this.mat(C.interior) : this.extMat, self = this, frame = this.mat(C.frame, { roughness: 0.5 });
    var piece = function (a, b, y0, y1, mat, thick, extendEnds) {
      if (b - a <= 0.001 || y1 - y0 <= 0.001) return;
      var ea = extendEnds && a <= 0.001 ? t / 2 : 0, eb = extendEnds && b >= len - 0.001 ? t / 2 : 0;
      var L = (b - a) + ea + eb, mid = (a + b) / 2 + (eb - ea) / 2;
      self.box(L, y1 - y0, thick || t, w.x1 + ux * mid, base + (y0 + y1) / 2, w.y1 + uz * mid, mat || material, true, true, ang, a - ea, y0);
    };
    ops = ops.slice().sort(function (a, b) { return a.pos - b.pos; });
    var cursor = 0;
    ops.forEach(function (o) {
      var half = o.width / 2, a = Math.max(cursor, Math.min(o.pos, len - half) - half), b = Math.min(len, a + o.width);
      piece(cursor, a, 0, WALL_H, null, null, true);
      if (o.type === "door") {
        var kind = o.kind || (w.type === "interior" ? "interior" : "exterior"), dh = Math.min(WALL_H - 0.3, o.height || (kind === "garage" ? 7 : DOOR_H));
        piece(a, b, dh, WALL_H, null, null, false);
        if (kind === "garage") {
          piece(a + 0.05, b - 0.05, 0, dh - 0.02, self.mat(C.garage, { roughness: 0.7 }), 0.2, false);
          var panels = Math.max(3, Math.round(dh / 1.75)); for (var pi = 1; pi < panels; pi++) piece(a + 0.05, b - 0.05, dh * pi / panels - 0.02, dh * pi / panels + 0.02, self.mat("#b9b4a9"), 0.24, false);
        } else {
          piece(a + 0.05, b - 0.05, 0, dh - 0.02, self.mat(C.door, { roughness: 0.6 }), 0.15, false);
        }
        piece(a, b, dh, dh + 0.12, frame, t + 0.1, false);
        piece(a - 0.06, a + 0.06, 0, dh + 0.12, frame, t + 0.1, false); piece(b - 0.06, b + 0.06, 0, dh + 0.12, frame, t + 0.1, false);
      } else {
        var sill = o.sill != null ? +o.sill : SILL, head = Math.min(WALL_H - 0.3, sill + (o.height ? +o.height : HEAD - SILL));
        piece(a, b, 0, sill, null, null, false);
        piece(a, b, head, WALL_H, null, null, false);
        piece(a, b, sill, head, self.mat(C.glass, { transparent: true, opacity: 0.45, roughness: 0.1, metalness: 0.3 }), 0.08, false);
        piece(a - 0.06, b + 0.06, sill - 0.12, sill, frame, t + 0.14, false); piece(a - 0.06, b + 0.06, head, head + 0.12, frame, t + 0.1, false);
        piece(a - 0.06, a + 0.06, sill, head, frame, t + 0.1, false); piece(b - 0.06, b + 0.06, sill, head, frame, t + 0.1, false);
      }
      cursor = b;
    });
    piece(cursor, len, 0, WALL_H, null, null, true);
  };

  // Roof over one rectangle at eave height y0. Hip / gable / flat with overhang and a soffit closing the underside.
  P.roof = function (r, y0) {
    var style = this.settings.roof, pitch = { hip4: 4, hip6: 6, hip8: 8, gable4: 4, gable6: 6, gable8: 8 }[style] || 6;
    var x0 = r.x0 - OVERHANG, x1 = r.x1 + OVERHANG, z0 = r.z0 - OVERHANG, z1 = r.z1 + OVERHANG, W = x1 - x0, D = z1 - z0, cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
    this.box(W, 0.3, D, cx, y0 - 0.15, cz, this.mat(C.interior), false, true);  // soffit / ceiling
    if (style === "flat") { this.box(W, 0.5, D, cx, y0 + 0.25, cz, this.roofMat, true, true); return; }
    var pos = [], uv = [], tri = function (a, b, c) { [a, b, c].forEach(function (p) { pos.push(p[0], p[1], p[2]); uv.push(p[0] + p[2] * 0.0, p[1] * 1.2 + p[2]); }); };
    var quad = function (a, b, c, d) { tri(a, b, c); tri(a, c, d); };
    var alongX = W >= D, half = (alongX ? D : W) / 2, h = pitch / 12 * half, yr = y0 + h;
    var hip = style.indexOf("hip") === 0, ridgeIn = hip ? half : 0;
    var A, B; // ridge endpoints
    if (alongX) { A = [x0 + ridgeIn, yr, cz]; B = [x1 - ridgeIn, yr, cz]; }
    else { A = [cx, yr, z0 + ridgeIn]; B = [cx, yr, z1 - ridgeIn]; }
    var c00 = [x0, y0, z0], c10 = [x1, y0, z0], c11 = [x1, y0, z1], c01 = [x0, y0, z1];
    if (alongX) {
      quad(c01, c11, B, A);          // south slope
      quad(c10, c00, A, B);          // north slope
      if (hip) { tri(c00, c01, A); tri(c11, c10, B); }
      else { var g = this.extMat; this.gableEnd([[r.x0, y0, r.z0], [r.x0, y0, r.z1], [r.x0, yr, cz]], g); this.gableEnd([[r.x1, y0, r.z1], [r.x1, y0, r.z0], [r.x1, yr, cz]], g); }
    } else {
      quad(c00, c01, B, A);          // west slope
      quad(c11, c10, A, B);          // east slope
      if (hip) { tri(c10, c00, A); tri(c01, c11, B); }
      else { var g2 = this.extMat; this.gableEnd([[r.x1, y0, r.z0], [r.x0, y0, r.z0], [cx, yr, r.z0]], g2); this.gableEnd([[r.x0, y0, r.z1], [r.x1, y0, r.z1], [cx, yr, r.z1]], g2); }
    }
    var geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3)); geo.setAttribute("uv", new THREE.Float32BufferAttribute(uv, 2)); geo.computeVertexNormals();
    var mesh = new THREE.Mesh(geo, this.roofMat); mesh.castShadow = mesh.receiveShadow = true; this.model.add(mesh);
  };
  P.gableEnd = function (tri, material) {
    var geo = new THREE.BufferGeometry(), pos = [], uv = [];
    tri.forEach(function (p) { pos.push(p[0], p[1], p[2]); uv.push(p[0] + p[2], p[1]); });
    geo.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3)); geo.setAttribute("uv", new THREE.Float32BufferAttribute(uv, 2)); geo.computeVertexNormals();
    var m = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ map: material.map, roughness: 0.9, side: THREE.DoubleSide })); m.castShadow = m.receiveShadow = true; this.model.add(m);
  };

  P.fixture = function (f, base) {
    var spec = FIX[f.kind] || FIX.box, cx = f.x + f.w / 2, cz = f.y + f.h / 2, rot = -(f.rot || 0) * Math.PI / 180;
    var lw = (f.rot % 180) ? f.h : f.w, lh = (f.rot % 180) ? f.w : f.h;   // local (unrotated) footprint
    if (f.kind === "stairs") {
      var tread = 0.9167, n = Math.max(2, Math.floor(lh / tread)), rise = WALL_H / n, g = new THREE.Group();
      for (var i = 0; i < n; i++) {
        var m = new THREE.Mesh(new THREE.BoxGeometry(lw, rise * (i + 1), tread), this.mat(spec.c));
        m.position.set(0, rise * (i + 1) / 2, -lh / 2 + tread * (i + 0.5)); m.castShadow = m.receiveShadow = true; g.add(m);
      }
      g.position.set(cx, base, cz); g.rotation.y = rot; this.model.add(g); return;
    }
    var h = spec.h, mesh;
    if (f.kind === "water_heater") mesh = new THREE.Mesh(new THREE.CylinderGeometry(Math.min(lw, lh) / 2, Math.min(lw, lh) / 2, h, 24), this.mat(spec.c));
    else if (f.kind === "toilet" || f.kind === "tub" || f.kind === "sofa" || f.kind === "bed" || f.kind === "bed_king" || f.kind === "car") {
      mesh = new THREE.Group();
      var b1 = new THREE.Mesh(new THREE.BoxGeometry(lw, h, lh), this.mat(spec.c)); b1.castShadow = b1.receiveShadow = true; mesh.add(b1);
      if (f.kind === "toilet") { var tank = new THREE.Mesh(new THREE.BoxGeometry(lw, 1.2, lh * 0.3), this.mat(spec.c)); tank.position.set(0, h / 2 + 0.6, -lh * 0.35); tank.castShadow = true; mesh.add(tank); }
      if (f.kind === "sofa" || f.kind === "bed" || f.kind === "bed_king") { var back = new THREE.Mesh(new THREE.BoxGeometry(lw, f.kind === "sofa" ? 1 : 1.5, lh * 0.15), this.mat(spec.c)); back.position.set(0, h / 2 + (f.kind === "sofa" ? 0.5 : 0.75), -lh * 0.425); back.castShadow = true; mesh.add(back); }
      if (f.kind === "car") { var cab = new THREE.Mesh(new THREE.BoxGeometry(lw * 0.85, 1.6, lh * 0.45), this.mat(0x2f3d55, { roughness: 0.3, metalness: 0.4 })); cab.position.set(0, h / 2 + 0.8, -lh * 0.05); cab.castShadow = true; mesh.add(cab); }
      mesh.position.set(cx, base + h / 2, cz); mesh.rotation.y = rot; this.model.add(mesh); return;
    } else mesh = new THREE.Mesh(new THREE.BoxGeometry(lw, h, lh), this.mat(spec.c, f.kind === "fridge" || f.kind === "range" ? { roughness: 0.35, metalness: 0.5 } : {}));
    mesh.position.set(cx, base + h / 2, cz); mesh.rotation.y = rot; mesh.castShadow = mesh.receiveShadow = true; this.model.add(mesh);
  };

  // ------------------------------------------------------------ camera / loop
  P.resetView = function () {
    var b = this.bbox, cx = (b.minX + b.maxX) / 2, cz = (b.minY + b.maxY) / 2, size = Math.max(b.maxX - b.minX, b.maxY - b.minY, 20);
    var top = (this.levelsShown || 1) * (WALL_H + FLOOR_T);
    this.controls.target.set(cx, top / 2.5, cz);
    this.camera.position.set(cx + size * 0.95, top / 2 + size * 0.7, cz + size * 1.15);
    this.controls.update();
    this.sun.target.position.set(cx, 0, cz); this.sun.target.updateMatrixWorld();
  };
  P.animate = function () {
    var self = this;
    (function loop() { requestAnimationFrame(loop); self.controls.update(); self.renderer.render(self.scene, self.camera); })();
  };

  // ------------------------------------------------------------ rendering still
  P.saveRendering = function () {
    var self = this, r = this.renderer, w = this.root.clientWidth, h = this.root.clientHeight, prevRatio = r.getPixelRatio();
    this.status.textContent = "Rendering…";
    var scale = Math.min(3, Math.floor(3000 / Math.max(w, h)) || 1);
    r.setPixelRatio(scale); r.render(this.scene, this.camera);
    var url = r.domElement.toDataURL("image/jpeg", 0.92);
    r.setPixelRatio(prevRatio); r.setSize(w, h);
    fetch(this.opts.renderUrl, { method: "POST", credentials: "same-origin", headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": this.opts.csrf }, body: JSON.stringify({ image: url }) })
      .then(function (res) { return res.json(); })
      .then(function (j) {
        if (j.ok) self.status.innerHTML = 'Saved to images · <a href="' + j.url + '">open</a>';
        else self.status.textContent = "Could not save: " + (j.errors || []).join(", ");
      })
      .catch(function () { self.status.textContent = "Could not save (offline?)"; });
  };

  window.DesignView3D = { mount: function (root, opts) { return new View(root, opts); } };
})();
