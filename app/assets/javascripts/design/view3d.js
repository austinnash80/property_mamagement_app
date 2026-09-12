// Design Center — 3D view (Phase 3). Builds a Three.js scene from floor-plan JSON
// (see app/models/design/floor_plan.rb for the data shape). Plan x → x, plan y → z, up → y.
// Levels stack by position; roofs are generated over each level's footprint minus the
// footprint of the level above. Mounted by app/views/design/floor_plans/view3d.html.erb.
(function () {
  "use strict";

  var WALL_H = 9, FLOOR_T = 1, DOOR_H = 6.67, SILL = 3, HEAD = 6.67, OVERHANG = 1.5, TILE = 4; // TILE = texture tile size in ft
  // entry doors dark taupe and garage doors cream, like the reference renderings; trim white
  var C = { interior: "#f4f3ee", slab: "#b9b6ad", ground: "#c9d3bf", door: "#6f6656", garage: "#e6dfd0", glass: "#9ccbe8", frame: "#ffffff" };
  var EXTERIORS = { stucco: { label: "Stucco (cream)", kind: "stucco", color: "#e6dcc6" }, white: { label: "White", kind: "stucco", color: "#f3f1ea" }, gray: { label: "Warm gray", kind: "stucco", color: "#b9b3a6" }, siding: { label: "Wood siding", kind: "siding", color: "#c9b48f" }, brick: { label: "Brick", kind: "brick", color: "#9a5a44" } };
  var ROOF_COLORS = { asphalt: { label: "Asphalt shingle", kind: "shingle", color: "#5a5b5e" }, brown: { label: "Brown shingle", kind: "shingle", color: "#6b5040" }, tile: { label: "Terracotta tile", kind: "tile", color: "#b5623f" }, metal: { label: "Standing-seam metal", kind: "metal", color: "#6d7a86" } };
  var FLOORS = { wood: { label: "Wood", kind: "wood", color: "#c9a878" }, tile: { label: "Tile", kind: "tilefloor", color: "#cfcac0" }, concrete: { label: "Concrete", kind: "concrete", color: "#b4b1aa" } };
  var ROOF_STYLES = [["hip6", "Hip 6:12"], ["hip4", "Hip 4:12"], ["hip8", "Hip 8:12"], ["gable6", "Gable 6:12"], ["gable4", "Gable 4:12"], ["gable8", "Gable 8:12"], ["flat", "Flat"], ["none", "No roof"]];
  var DEFAULTS = { roof: "hip6", exterior: "stucco", roofColor: "asphalt", floor: "wood", exteriorHex: "", roofHex: "" };
  var HEX = /^#[0-9a-f]{6}$/i;
  // h = height, z0 = bottom elevation, top = countertop slab, cab = cabinet colour
  var CAB = 0xd8cfc0, TOP = 0x8f8f89, APPL = 0xb8bcc2;
  var FIX = {
    stairs: { h: WALL_H, c: 0xc8b18a }, toilet: { h: 1.4, c: 0xfafafa }, tub: { h: 1.8, c: 0xfafafa }, shower: { h: 0.3, c: 0xe8eef2 },
    sink: { h: 3, c: CAB, top: true, basin: true }, dbl_sink: { h: 3, c: CAB, top: true, basin: true }, vanity: { h: 2.75, c: 0xe8e2d8, top: true, basin: true },
    counter: { h: 3, c: CAB, top: true }, island: { h: 3, c: CAB, top: true }, island_seat: { h: 3, c: CAB, top: true, overhang: 1.2 },
    upper: { h: 2.5, z0: 4.5, c: CAB }, hood: { h: 1, z0: 5.2, c: 0xa9adb3, metal: true }, microwave: { h: 1.25, z0: 4.5, c: 0x4a4d52, metal: true },
    range: { h: 3, c: 0x8b9096, metal: true }, range36: { h: 3, c: 0x8b9096, metal: true }, cooktop: { h: 3.1, c: 0x2b2d31, metal: true, thin: true },
    wall_oven: { h: 7, c: 0x5a5e64, metal: true }, fridge: { h: 6, c: APPL, metal: true }, dishwasher: { h: 2.9, c: APPL, metal: true }, pantry: { h: 7, c: CAB },
    column: { h: 8.5, hgt: 8.5, c: 0xf2efe8 }, chimney: { h: 22, hgt: 22, c: 0x8a5a44 }, utility: { h: 6.5, c: 0xd9d9d9, metal: true }, dresser: { h: 2.7, c: 0x8a6a4b }, stool: { h: 2.5, c: 0x5a4632, shape: "stool" }, chair: { h: 3, c: 0x6b5a48, shape: "chair" }, table: { h: 2.5, c: 0xa77b4d }, round_table: { h: 2.5, c: 0xa77b4d, shape: "round" },
    washer: { h: 3, c: 0xe9e9e9 }, water_heater: { h: 5, c: 0xcfcfcf },
    bed: { h: 2, c: 0x9fb4c7 }, bed_king: { h: 2, c: 0x9fb4c7 }, sofa: { h: 2.5, c: 0x8c8f9a }, desk: { h: 2.5, c: 0xa77b4d }, car: { h: 4.7, c: 0x6b7f99 }, box: { h: 3, c: 0xbfbfbf }
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
      case "stone": {   // ledgestone veneer: irregular courses of tan / grey / brown blocks with mortar joints
        g.fillStyle = "#c9c1b3"; g.fillRect(0, 0, size, size);
        var pal = ["#b9a688", "#a89478", "#c4b394", "#9c8f7c", "#b1a08a", "#8f8271", "#cbbba0"], yy = 0;
        while (yy < size) { var ch = ppf * (0.35 + rnd() * 0.45), xx = -rnd() * ppf; while (xx < size) { var bw2 = ppf * (0.6 + rnd() * 1.6); g.fillStyle = pal[Math.floor(rnd() * pal.length)]; g.fillRect(xx + 1.5, yy + 1.5, bw2 - 3, ch - 3); shade(rnd() * 0.12, rnd() < 0.5); g.fillRect(xx + 1.5, yy + 1.5, bw2 - 3, ch - 3); xx += bw2; } yy += ch; }
        break; }
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
    if (!HEX.test(this.settings.exteriorHex || "")) this.settings.exteriorHex = "";
    if (!HEX.test(this.settings.roofHex || "")) this.settings.roofHex = "";
    this.visible = {}; this.levels.forEach(function (l) { this.visible[l.id] = true; }, this);
    this.materials = {};
    this.setupScene(); this.buildUI(); this.rebuild(); this.resetView(); this.animate();
  }
  var P = View.prototype;

  P.mat = function (color, extra) {
    var key = "c" + color + JSON.stringify(extra || {});
    if (!this.materials[key]) this.materials[key] = new THREE.MeshStandardMaterial(Object.assign({ color: color, roughness: 0.85, metalness: 0.02, envMapIntensity: 0.35 }, extra || {}));
    return this.materials[key];
  };
  P.texMat = function (spec, extra) {
    var key = "t" + spec.kind + spec.color;
    if (!this.materials[key]) this.materials[key] = new THREE.MeshStandardMaterial(Object.assign({ map: makeTexture(spec.kind, spec.color), roughness: 0.9, metalness: 0.02, envMapIntensity: 0.35 }, extra || {}));
    return this.materials[key];
  };

  P.setupScene = function () {
    var w = this.root.clientWidth, h = this.root.clientHeight;
    this.renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.setSize(w, h); this.renderer.shadowMap.enabled = true; this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.outputEncoding = THREE.sRGBEncoding;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping; this.renderer.toneMappingExposure = 0.95;
    this.root.appendChild(this.renderer.domElement);

    this.scene = new THREE.Scene(); this.scene.background = new THREE.Color(0xe3e9ee);
    this.scene.fog = new THREE.Fog(0xe3e9ee, 500, 1200);
    // sky: gradient dome (deep blue overhead fading to a hazy horizon)
    var sky = new THREE.Mesh(new THREE.SphereGeometry(1000, 32, 16), new THREE.ShaderMaterial({
      side: THREE.BackSide, depthWrite: false, fog: false,
      uniforms: { top: { value: new THREE.Color(0x5f97d1) }, mid: { value: new THREE.Color(0xbcd5ec) }, bottom: { value: new THREE.Color(0xe9eef2) } },
      vertexShader: "varying vec3 vP; void main(){ vP = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }",
      fragmentShader: "uniform vec3 top; uniform vec3 mid; uniform vec3 bottom; varying vec3 vP; void main(){ float h = clamp(vP.y, 0.0, 1.0); vec3 c = h < 0.15 ? mix(bottom, mid, h / 0.15) : mix(mid, top, (h - 0.15) / 0.85); gl_FragColor = vec4(c, 1.0); }"
    }));
    this.scene.add(sky);
    // soft image-based ambient light so materials pick up reflections and shading
    if (THREE.RoomEnvironment && THREE.PMREMGenerator) {
      try { var pmrem = new THREE.PMREMGenerator(this.renderer); this.scene.environment = pmrem.fromScene(new THREE.RoomEnvironment(), 0.04).texture; pmrem.dispose(); } catch (_) {}
    }
    this.camera = new THREE.PerspectiveCamera(45, w / h, 0.5, 2000);
    this.controls = new THREE.OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true; this.controls.dampingFactor = 0.08; this.controls.maxPolarAngle = Math.PI / 2 - 0.02;

    this.scene.add(new THREE.HemisphereLight(0xdfe9f5, 0x8a9a7a, this.scene.environment ? 0.3 : 0.55));
    var sun = new THREE.DirectionalLight(0xfff1dc, this.scene.environment ? 1.2 : 1.15); sun.position.set(80, 120, 60); sun.castShadow = true;
    sun.shadow.mapSize.set(4096, 4096); sun.shadow.camera.near = 10; sun.shadow.camera.far = 400; sun.shadow.radius = 4;
    sun.shadow.camera.left = sun.shadow.camera.bottom = -120; sun.shadow.camera.right = sun.shadow.camera.top = 120; sun.shadow.bias = -0.0004; sun.shadow.normalBias = 0.02;
    this.scene.add(sun); this.sun = sun;

    var ground = new THREE.Mesh(new THREE.PlaneGeometry(2000, 2000), this.mat(C.ground, { roughness: 1, envMapIntensity: 0.2 }));
    ground.rotation.x = -Math.PI / 2; ground.position.y = -FLOOR_T - 0.01; ground.receiveShadow = true; this.scene.add(ground);

    this.model = new THREE.Group(); this.scene.add(this.model);
    this.setupPost(w, h);
    var self = this;
    if (window.ResizeObserver) new ResizeObserver(function () { self.resize(); }).observe(this.root); else window.addEventListener("resize", function () { self.resize(); });
  };

  // Ambient occlusion (contact shading in corners and under eaves) via a post-processing chain.
  // Falls back to a plain render when the optional Three.js example scripts are unavailable.
  P.setupPost = function (w, h) {
    this.composer = null;
    if (!(THREE.EffectComposer && THREE.RenderPass && THREE.SSAOPass && THREE.ShaderPass && THREE.GammaCorrectionShader)) return;
    try {
      var composer = new THREE.EffectComposer(this.renderer);
      composer.addPass(new THREE.RenderPass(this.scene, this.camera));
      var ssao = new THREE.SSAOPass(this.scene, this.camera, w, h);
      ssao.kernelRadius = 1.6; ssao.minDistance = 0.0008; ssao.maxDistance = 0.03;
      composer.addPass(ssao);
      composer.addPass(new THREE.ShaderPass(THREE.GammaCorrectionShader));   // the composer bypasses the renderer's sRGB output
      this.composer = composer; this.ssao = ssao;
    } catch (e) { this.composer = null; }
  };
  P.draw = function () { if (this.composer) this.composer.render(); else this.renderer.render(this.scene, this.camera); };

  P.resize = function () {
    var w = this.root.clientWidth, h = this.root.clientHeight; if (!w || !h) return;
    this.camera.aspect = w / h; this.camera.updateProjectionMatrix(); this.renderer.setSize(w, h);
    if (this.composer) { this.composer.setSize(w, h); this.ssao.setSize(w, h); }
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
    if (ui.roofs) { this.showRoofs = ui.roofs.checked; ui.roofs.addEventListener("change", function () { self.showRoofs = ui.roofs.checked; if (self.roofGroup) self.roofGroup.visible = self.showRoofs; }); }
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
    // colour swatches: a custom colour rides on top of the chosen preset; picking a new preset clears it
    var swatch = function (input, hexKey, presetKey, table) {
      if (!input) return;
      var sync = function () { input.value = self.settings[hexKey] || table[self.settings[presetKey]].color; };
      sync(); self["sync_" + hexKey] = sync;
      var t; input.addEventListener("input", function () { self.settings[hexKey] = input.value; clearTimeout(t); t = setTimeout(function () { self.rebuild(); }, 80); });
      input.addEventListener("change", function () { self.settings[hexKey] = input.value; self.rebuild(); self.saveSettings(); });
      var sel = presetKey === "exterior" ? ui.exterior : ui.roofColor;
      if (sel) sel.addEventListener("change", function () { self.settings[hexKey] = ""; sync(); self.rebuild(); });
    };
    swatch(ui.exteriorHex, "exteriorHex", "exterior", EXTERIORS); swatch(ui.roofHex, "roofHex", "roofColor", ROOF_COLORS);
  };

  P.applySettings = function (incoming) {
    var self = this, ui = this.opts.ui;
    ["roof", "exterior", "roofColor", "floor"].forEach(function (k) { if (incoming[k] != null) { self.settings[k] = incoming[k]; if (ui[k]) ui[k].value = incoming[k]; } });
    ["exteriorHex", "roofHex"].forEach(function (k) { if (incoming[k] != null) self.settings[k] = HEX.test(incoming[k]) ? incoming[k] : ""; });
    if (this.sync_exteriorHex) this.sync_exteriorHex(); if (this.sync_roofHex) this.sync_roofHex();
    this.rebuild();
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
    var extSpec = Object.assign({}, EXTERIORS[this.settings.exterior]), roofSpec = Object.assign({}, ROOF_COLORS[this.settings.roofColor]);
    if (HEX.test(this.settings.exteriorHex || "")) extSpec.color = this.settings.exteriorHex;
    if (HEX.test(this.settings.roofHex || "")) roofSpec.color = this.settings.roofHex;
    this.extMat = this.texMat(extSpec);
    this.floorMat = this.texMat(FLOORS[this.settings.floor], { roughness: 0.7 });
    this.roofMat = this.texMat(roofSpec, { side: THREE.DoubleSide });
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
      footprints.push({ x0: fx0, x1: fx1, z0: fy0, z1: fy1, base: base, drawn: d.roofs || [] });

      self.box(fx1 - fx0 + 0.5, FLOOR_T, fy1 - fy0 + 0.5, (fx0 + fx1) / 2, base - FLOOR_T / 2, (fy0 + fy1) / 2, self.mat(C.slab), false, true);
      rooms.forEach(function (r) { self.floor(r, base); });
      walls.forEach(function (w) { self.wall(w, openings.filter(function (o) { return o.wall === w.id; }), base); });
      fixtures.forEach(function (f) { self.fixture(f, base); });
      (d.decks || []).forEach(function (dk) { self.deck(dk, base); });
    });

    // roofs: sections drawn with the Roof tool win; otherwise each level's footprint minus the level above.
    // Everything roof-related goes into one group so the "Roofs" checkbox can hide it without rebuilding.
    var roofGroup = new THREE.Group(); roofGroup.name = "roofs"; this.model.add(roofGroup); var mainModel = this.model; this.model = roofGroup;
    footprints.forEach(function (fp, i) {
      if (!fp) return;
      if (fp.drawn.length) { fp.drawn.forEach(function (rf) { self.roof({ x0: rf.x, x1: rf.x + rf.w, z0: rf.y, z1: rf.y + rf.h }, fp.base + (+rf.eave || WALL_H), rf); }); return; }
      if (self.settings.roof === "none") return;
      var above = null; for (var j = i + 1; j < footprints.length; j++) if (footprints[j]) { above = footprints[j]; break; }
      var rects = above ? self.subtract(fp, above) : [fp];
      rects.forEach(function (r) { if (r.x1 - r.x0 >= 4 && r.z1 - r.z0 >= 4) self.roof(r, fp.base + WALL_H); });
    });
    this.model = mainModel; this.roofGroup = roofGroup; roofGroup.visible = this.showRoofs !== false;

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

  // Room floor: polygon (r.pts) or rectangle, as a flat shape just above the slab. UVs are in feet.
  P.floor = function (r, base) {
    var pts = r.pts && r.pts.length >= 3 ? r.pts : [[r.x, r.y], [r.x + r.w, r.y], [r.x + r.w, r.y + r.h], [r.x, r.y + r.h]];
    var shape = new THREE.Shape(pts.map(function (p) { return new THREE.Vector2(p[0], -p[1]); }));
    var geo = new THREE.ShapeGeometry(shape), uv = geo.attributes.uv, pos = geo.attributes.position;
    for (var i = 0; i < uv.count; i++) uv.setXY(i, pos.getX(i), pos.getY(i));
    var m = new THREE.Mesh(geo, this.floorMat); m.rotation.x = -Math.PI / 2; m.position.y = base + 0.06; m.receiveShadow = true; this.model.add(m);
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
    var nx = -uz, nz = ux;   // wall normal (for offsetting sliding-door panes off the centre line)
    var piece = function (a, b, y0, y1, mat, thick, extendEnds, off) {
      if (b - a <= 0.001 || y1 - y0 <= 0.001) return;
      var ea = extendEnds && a <= 0.001 ? t / 2 : 0, eb = extendEnds && b >= len - 0.001 ? t / 2 : 0;
      var L = (b - a) + ea + eb, mid = (a + b) / 2 + (eb - ea) / 2, o = off || 0;
      self.box(L, y1 - y0, thick || t, w.x1 + ux * mid + nx * o, base + (y0 + y1) / 2, w.y1 + uz * mid + nz * o, mat || material, true, true, ang, a - ea, y0);
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
        } else if (kind === "sliding") {
          var glass = self.mat(C.glass, { transparent: true, opacity: 0.45, roughness: 0.1, metalness: 0.3 }), mid2 = (a + b) / 2, sd = (o.swing || 1) * t / 4;
          piece(a, mid2 + 0.05, 0.1, dh - 0.1, glass, 0.08, false, sd); piece(mid2 - 0.05, b, 0.1, dh - 0.1, glass, 0.08, false, -sd);
          [a, mid2, b].forEach(function (x) { piece(x - 0.08, x + 0.08, 0, dh, frame, t + 0.1, false); });   // stiles
          piece(a, b, 0, 0.1, frame, t + 0.1, false);   // track
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
        // window grids: lites about 1.5 ft square, bars just proud of the glass on both sides
        var cols = Math.max(1, Math.round((b - a) / 1.5)), rows = Math.max(1, Math.round((head - sill) / 1.5)), gi;
        for (gi = 1; gi < cols; gi++) { var gx = a + (b - a) * gi / cols; piece(gx - 0.03, gx + 0.03, sill, head, frame, 0.14, false); }
        for (gi = 1; gi < rows; gi++) { var gy = sill + (head - sill) * gi / rows; piece(a, b, gy - 0.03, gy + 0.03, frame, 0.14, false); }
      }
      cursor = b;
    });
    piece(cursor, len, 0, WALL_H, null, null, true);
  };

  // ---------------------------------------------------------------- roofs
  // Convex polygon face from world points [[x,y,z],...]; planar UVs in feet so the shingle texture stays consistent.
  P.face = function (pts, material) {
    if (pts.length < 3) return;
    var pos = [], uv = [];
    for (var i = 1; i < pts.length - 1; i++) [pts[0], pts[i], pts[i + 1]].forEach(function (p) { pos.push(p[0], p[1], p[2]); uv.push(p[0] + p[2] * 0.37, p[1] * 1.2 + p[2]); });
    var geo = new THREE.BufferGeometry(); geo.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3)); geo.setAttribute("uv", new THREE.Float32BufferAttribute(uv, 2)); geo.computeVertexNormals();
    var m = new THREE.Mesh(geo, material); m.castShadow = m.receiveShadow = true; this.model.add(m); return m;
  };
  P.roofMaterialFor = function (rf) {
    var key = rf && rf.color;
    if (!key) return this.roofMat;
    var spec = ROOF_COLORS[key] ? Object.assign({}, ROOF_COLORS[key]) : Object.assign({}, ROOF_COLORS[this.settings.roofColor], /^#/.test(key) ? { color: key } : {});
    return this.texMat(spec, { side: THREE.DoubleSide });
  };
  P.wallMat = function () { return new THREE.MeshStandardMaterial({ map: this.extMat.map, roughness: 0.9, side: THREE.DoubleSide }); };

  // Roof over rectangle r {x0,x1,z0,z1} with eave height y0. rf = section drawn with the Roof tool
  // (style, pitch, pitchB, shift, ridge, endA/endB, overhang, rake, ridgeH, color, high, dormers); absent for automatic roofs.
  P.roof = function (r, y0, rf) {
    var o = rf || {}, style, pitch;
    if (rf) { style = o.style || "hip"; pitch = +o.pitch || 6; }
    else { var key = this.settings.roof; style = key.indexOf("gable") === 0 ? "gable" : key === "flat" ? "flat" : "hip"; pitch = { hip4: 4, hip6: 6, hip8: 8, gable4: 4, gable6: 6, gable8: 8 }[key] || 6; }
    var oe = o.overhang != null ? +o.overhang : OVERHANG, rk = o.rake != null ? +o.rake : Math.min(oe, 1), mat = this.roofMaterialFor(rf), wallMat = this.wallMat(), self = this;
    var W = r.x1 - r.x0, D = r.z1 - r.z0;
    // soffit / ceiling over the whole extended footprint
    this.box(W + 2 * oe, 0.3, D + 2 * oe, (r.x0 + r.x1) / 2, y0 - 0.15, (r.z0 + r.z1) / 2, this.mat(C.interior), false, true);
    if (style === "flat") { this.box(W + 2 * oe, 0.5, D + 2 * oe, (r.x0 + r.x1) / 2, y0 + 0.25, (r.z0 + r.z1) / 2, mat, true, true); this.fascia(r, y0, oe, [1, 1, 1, 1]); return; }
    if (style === "shed") { this.shedRoof(r.x0 - oe, r.x1 + oe, r.z0 - oe, r.z1 + oe, y0, pitch, o.high || "n", r, mat, wallMat); this.fascia(r, y0, oe, [1, 1, 1, 1]); return; }
    if (style === "mansard") return this.mansardRoof(r, y0, pitch, oe, mat, rf);

    // ridged styles in (u along ridge, v across) coordinates
    var alongX = o.ridge === "x" ? true : o.ridge === "y" ? false : W >= D;
    var U0 = alongX ? r.x0 : r.z0, U1 = alongX ? r.x1 : r.z1, V0 = alongX ? r.z0 : r.x0, V1 = alongX ? r.z1 : r.x1;
    var P = function (u, v, y) { return alongX ? [u, y, v] : [v, y, u]; };
    var gableStyle = style === "gable" || style === "gambrel";
    var eA = style === "gambrel" ? "gable" : (o.endA || (gableStyle ? "gable" : "hip")), eB = style === "gambrel" ? "gable" : (o.endB || (gableStyle ? "gable" : "hip"));
    var xU0 = U0 - (eA === "gable" ? rk : oe), xU1 = U1 + (eB === "gable" ? rk : oe), xV0 = V0 - oe, xV1 = V1 + oe, span = xV1 - xV0;
    var pA = pitch, pB = +o.pitchB || 0, dA = pB ? span * pB / (pA + pB) : span * Math.min(0.85, Math.max(0.15, 0.5 + (+o.shift || 0)));
    var h = o.ridgeH ? Math.max(0.5, +o.ridgeH - (o.eave ? +o.eave : WALL_H)) : pA / 12 * dA;
    var vr = xV0 + dA, yr = y0 + h;
    var setback = function (e) { return e === "gable" ? 0 : e === "dutch" ? dA * 0.5 : dA; };
    var sbA = setback(eA), sbB = setback(eB), uRA = xU0 + sbA, uRB = xU1 - sbB;

    if (style === "gambrel") {
      // two-pitch sides: steep lower slope to a break, then the given (upper) pitch to the ridge; gable ends
      var bA = dA * 0.35, bB = (span - dA) * 0.35, ybA = y0 + Math.min(h * 0.62, 30 / 12 * bA), ybB = y0 + Math.min(h * 0.62, 30 / 12 * bB);
      this.face([P(xU0, xV0, y0), P(xU1, xV0, y0), P(xU1, xV0 + bA, ybA), P(xU0, xV0 + bA, ybA)], mat);
      this.face([P(xU0, xV0 + bA, ybA), P(xU1, xV0 + bA, ybA), P(xU1, vr, yr), P(xU0, vr, yr)], mat);
      this.face([P(xU1, xV1, y0), P(xU0, xV1, y0), P(xU0, xV1 - bB, ybB), P(xU1, xV1 - bB, ybB)], mat);
      this.face([P(xU1, xV1 - bB, ybB), P(xU0, xV1 - bB, ybB), P(xU0, vr, yr), P(xU1, vr, yr)], mat);
      [U0, U1].forEach(function (u) { self.face([P(u, V0, y0), P(u, V0 + bA - oe, ybA), P(u, vr, yr), P(u, V1 - bB + oe, ybB), P(u, V1, y0)], wallMat); });
      this.fascia(r, y0, oe, alongX ? [1, 1, 0, 0] : [0, 0, 1, 1]);
      this.dormers(rf, { P: P, xV0: xV0, xV1: xV1, V0: V0, V1: V1, U0: U0, y0: y0, dA: dA, span: span, h: h, vr: vr, uRA: uRA, uRB: uRB, alongX: alongX }, mat, wallMat);
      return;
    }

    // slope A (eave at xV0) and slope B (eave at xV1) as polygons; ends trim them
    var slopeA = [P(xU0, xV0, y0), P(xU1, xV0, y0)], slopeB = [P(xU1, xV1, y0), P(xU0, xV1, y0)];
    var endPts = function (e, atStart) {
      // returns [pointsForSlopeA (from ridge toward eave A), pointsForSlopeB (from eave B toward ridge)] and builds the end face
      var uE = atStart ? xU0 : xU1, uR = atStart ? uRA : uRB, sgn = atStart ? 1 : -1;
      if (e === "gable") {
        self.face(atStart ? [P(U0, V0, y0), P(U0, vr, yr), P(U0, V1, y0)] : [P(U1, V1, y0), P(U1, vr, yr), P(U1, V0, y0)], wallMat);
        return { a: [P(uE, vr, yr)], b: [P(uE, vr, yr)] };
      }
      if (e === "hip") {
        self.face(atStart ? [P(uE, xV0, y0), P(uR, vr, yr), P(uE, xV1, y0)] : [P(uE, xV1, y0), P(uR, vr, yr), P(uE, xV0, y0)], mat);
        return { a: [P(uR, vr, yr)], b: [P(uR, vr, yr)] };
      }
      // dutch gable: hip face truncated at half height, vertical gablet above, slopes run to the gablet plane
      var uG = uE + sgn * dA * 0.5, vA = xV0 + (vr - xV0) * 0.5, vB = xV1 - (xV1 - vr) * 0.5, yG = y0 + h * 0.5;
      self.face(atStart ? [P(uE, xV0, y0), P(uG, vA, yG), P(uG, vB, yG), P(uE, xV1, y0)] : [P(uE, xV1, y0), P(uG, vB, yG), P(uG, vA, yG), P(uE, xV0, y0)], mat);
      self.face([P(uG, vA, yG), P(uG, vr, yr), P(uG, vB, yG)], wallMat);
      return { a: [P(uG, vr, yr), P(uG, vA, yG)], b: [P(uG, vB, yG), P(uG, vr, yr)] };
    };
    var endB = endPts(eB, false), endA = endPts(eA, true);
    // slope A: eave A0 → eave A1 → end B points (toward ridge) → ridge → end A points (back toward eave)
    slopeA = slopeA.concat(endB.a.slice().reverse().length === 1 ? endB.a : [endB.a[1], endB.a[0]]).concat(endA.a);
    slopeB = slopeB.concat(endA.b.length === 1 ? endA.b : [endA.b[1], endA.b[0]]).concat(endB.b.length === 1 ? endB.b : [endB.b[0], endB.b[1]]);
    this.face(slopeA, mat); this.face(slopeB, mat);
    this.fascia(r, y0, oe, alongX ? [1, 1, eA !== "gable" ? 1 : 0, eB !== "gable" ? 1 : 0] : [eA !== "gable" ? 1 : 0, eB !== "gable" ? 1 : 0, 1, 1]);
    this.dormers(rf, { P: P, xV0: xV0, xV1: xV1, V0: V0, V1: V1, U0: U0, y0: y0, dA: dA, span: span, h: h, vr: vr, uRA: uRA, uRB: uRB, alongX: alongX }, mat, wallMat);
  };

  // Fascia boards along the eaves: sides = [north(z0), south(z1), west(x0), east(x1)] flags.
  P.fascia = function (r, y0, oe, sides) {
    var f = this.mat(C.frame, { roughness: 0.55 }), W = r.x1 - r.x0 + 2 * oe, D = r.z1 - r.z0 + 2 * oe, cx = (r.x0 + r.x1) / 2, cz = (r.z0 + r.z1) / 2, y = y0 - 0.1;
    if (sides[0]) this.box(W, 0.55, 0.12, cx, y, r.z0 - oe, f, true, true);
    if (sides[1]) this.box(W, 0.55, 0.12, cx, y, r.z1 + oe, f, true, true);
    if (sides[2]) this.box(0.12, 0.55, D, r.x0 - oe, y, cz, f, true, true);
    if (sides[3]) this.box(0.12, 0.55, D, r.x1 + oe, y, cz, f, true, true);
  };

  P.mansardRoof = function (r, y0, pitch, oe, mat, rf) {
    var x0 = r.x0 - oe, x1 = r.x1 + oe, z0 = r.z0 - oe, z1 = r.z1 + oe, ins = Math.min(x1 - x0, z1 - z0) * 0.2, h = Math.max(pitch, 12) / 12 * ins, yt = y0 + h;
    var lo = [[x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1]], hi = [[x0 + ins, yt, z0 + ins], [x1 - ins, yt, z0 + ins], [x1 - ins, yt, z1 - ins], [x0 + ins, yt, z1 - ins]];
    for (var i = 0; i < 4; i++) { var j = (i + 1) % 4; this.face([lo[i], lo[j], hi[j], hi[i]], mat); }
    this.face([hi[3], hi[2], hi[1], hi[0]], mat);
    this.fascia(r, y0, oe, [1, 1, 1, 1]);
  };

  // Single-slope roof: the high edge sits on the side named by `high`; the two side walls are closed with the exterior material.
  P.shedRoof = function (x0, x1, z0, z1, y0, pitch, high, r, mat, wallMat) {
    var span = (high === "n" || high === "s") ? (z1 - z0) : (x1 - x0), h = pitch / 12 * span, yh = y0 + h;
    var hi = function (x, z) { return (high === "n" && z === z0) || (high === "s" && z === z1) || (high === "w" && x === x0) || (high === "e" && x === x1); };
    var P4 = [[x0, z0], [x1, z0], [x1, z1], [x0, z1]].map(function (p) { return [p[0], hi(p[0], p[1]) ? yh : y0, p[1]]; });
    this.face([P4[0], P4[3], P4[2], P4[1]], mat);
    var self = this, q = function (a, b, c, d) { self.face([a, b, c, d], wallMat); };
    if (high === "n" || high === "s") {
      var zh = high === "n" ? r.z0 : r.z1, zl = high === "n" ? r.z1 : r.z0;
      q([r.x0, y0, zl], [r.x0, y0, zh], [r.x0, yh, zh], [r.x0, y0 + 0.01, zl]); q([r.x1, y0, zh], [r.x1, y0, zl], [r.x1, y0 + 0.01, zl], [r.x1, yh, zh]);
      q([r.x0, y0, zh], [r.x1, y0, zh], [r.x1, yh, zh], [r.x0, yh, zh]);
    } else {
      var xh = high === "w" ? r.x0 : r.x1, xl = high === "w" ? r.x1 : r.x0;
      q([xl, y0, r.z0], [xh, y0, r.z0], [xh, yh, r.z0], [xl, y0 + 0.01, r.z0]); q([xh, y0, r.z1], [xl, y0, r.z1], [xl, y0 + 0.01, r.z1], [xh, yh, r.z1]);
      q([xh, y0, r.z0], [xh, y0, r.z1], [xh, yh, r.z1], [xh, yh, r.z0]);
    }
  };

  // Dormers on slope a (eave at xV0) or b (eave at xV1). g carries the roof's frame: P(u,v,y), extents, ridge (vr, h).
  P.dormers = function (rf, g, mat, wallMat) {
    var list = rf && rf.dormers; if (!list || !list.length) return;
    var self = this, glass = this.mat(C.glass, { transparent: true, opacity: 0.5, roughness: 0.1, metalness: 0.3 }), frame = this.mat(C.frame, { roughness: 0.5 });
    list.forEach(function (dm) {
      var sideA = dm.side === "a", d = sideA ? g.dA : g.span - g.dA, slope = g.h / d;                 // rise per ft toward the ridge
      var xVe = sideA ? g.xV0 : g.xV1, dir = sideA ? 1 : -1;                                          // eave v and direction toward ridge
      var vAt = function (t) { return xVe + dir * t; }, yAt = function (t) { return g.y0 + slope * t; };
      var oe = (sideA ? g.V0 - g.xV0 : g.xV1 - g.V1), tf = Math.max(0.5, (+dm.setback || 2.5) + oe), w = +dm.w || 6, wallH = +dm.wall || 4.5, pd = +dm.pitch || 8;
      var u = g.U0 + (+dm.pos || 0), yfB = yAt(tf), yf = yfB + wallH;                                 // dormer front: bottom on the roof, top of its wall
      if (yf >= g.y0 + g.h - 0.3) yf = g.y0 + g.h - 0.3;
      var te = (yf - g.y0) / slope;                                                                   // where the roof reaches the dormer's wall height
      var uL = u - w / 2, uR = u + w / 2, Pp = g.P;
      if (dm.type === "shed") {
        var sd = pd / 12; if (sd >= slope) sd = slope * 0.6;
        var tb = tf + (yf - yfB) / (slope - sd), yb = yAt(tb);
        self.face([Pp(uL, vAt(tf), yfB), Pp(uR, vAt(tf), yfB), Pp(uR, vAt(tf), yf), Pp(uL, vAt(tf), yf)], wallMat);            // front
        self.face([Pp(uL, vAt(tf), yfB), Pp(uL, vAt(tf), yf), Pp(uL, vAt(tb), yb)], wallMat);                                   // sides
        self.face([Pp(uR, vAt(tb), yb), Pp(uR, vAt(tf), yf), Pp(uR, vAt(tf), yfB)], wallMat);
        self.face([Pp(uL, vAt(tf - 0.5), yf - sd * 0.5), Pp(uR, vAt(tf - 0.5), yf - sd * 0.5), Pp(uR, vAt(tb), yb), Pp(uL, vAt(tb), yb)], mat);   // roof with a little overhang
      } else {
        var yrD = yf + pd / 12 * (w / 2), tbG = Math.min(d * 0.98, (yrD - g.y0) / slope), ybG = yAt(tbG);
        if (te > tbG) te = tbG;
        self.face([Pp(uL, vAt(tf), yfB), Pp(uR, vAt(tf), yfB), Pp(uR, vAt(tf), yf), Pp(u, vAt(tf), yrD), Pp(uL, vAt(tf), yf)], wallMat);   // front with gable
        self.face([Pp(uL, vAt(tf), yfB), Pp(uL, vAt(tf), yf), Pp(uL, vAt(te), yf)], wallMat);                                              // sides
        self.face([Pp(uR, vAt(te), yf), Pp(uR, vAt(tf), yf), Pp(uR, vAt(tf), yfB)], wallMat);
        self.face([Pp(uL - 0.4, vAt(tf - 0.5), yf - pd / 12 * 0.4), Pp(uL - 0.4, vAt(te), yf - pd / 12 * 0.4), Pp(u, vAt(tbG), ybG), Pp(u, vAt(tf - 0.5), yrD)], mat);   // roof slopes
        self.face([Pp(u, vAt(tf - 0.5), yrD), Pp(u, vAt(tbG), ybG), Pp(uR + 0.4, vAt(te), yf - pd / 12 * 0.4), Pp(uR + 0.4, vAt(tf - 0.5), yf - pd / 12 * 0.4)], mat);
      }
      // window in the front wall
      var ww = Math.min(w * 0.6, 4), wh = Math.min(wallH * 0.6, 3), vf = vAt(tf) + dir * -0.06, y1w = yfB + (wallH - wh) / 2, y2w = y1w + wh;
      self.face([Pp(u - ww / 2, vf, y1w), Pp(u + ww / 2, vf, y1w), Pp(u + ww / 2, vf, y2w), Pp(u - ww / 2, vf, y2w)], glass);
      var vfr = vAt(tf) + dir * -0.1;
      [[u - ww / 2 - 0.1, u - ww / 2], [u + ww / 2, u + ww / 2 + 0.1]].forEach(function (b) { self.face([Pp(b[0], vfr, y1w - 0.1), Pp(b[1], vfr, y1w - 0.1), Pp(b[1], vfr, y2w + 0.1), Pp(b[0], vfr, y2w + 0.1)], frame); });
      [[y1w - 0.1, y1w], [y2w, y2w + 0.1]].forEach(function (b) { self.face([Pp(u - ww / 2, vfr, b[0]), Pp(u + ww / 2, vfr, b[0]), Pp(u + ww / 2, vfr, b[1]), Pp(u - ww / 2, vfr, b[1])], frame); });
    });
  };

  // ---------------------------------------------------------------- decks
  var DECK_COLORS = { wood: "#b98a5a", comp_gray: "#8f8a82", comp_brown: "#7a5a44", concrete: "#b4b1aa" };
  P.deck = function (dk, base) {
    var x0 = dk.x, x1 = dk.x + dk.w, z0 = dk.y, z1 = dk.y + dk.h, hgt = +dk.height || 0, top = base + hgt, self = this;
    var deckMat = this.texMat({ kind: dk.material === "concrete" ? "concrete" : "wood", color: DECK_COLORS[dk.material] || DECK_COLORS.wood }, { roughness: 0.8 });
    var railMat = this.mat(dk.material === "wood" ? "#f2efe8" : "#3a3d42", { roughness: 0.6 }), postMat = this.mat("#6b5a48");
    var thick = dk.material === "concrete" ? Math.max(0.35, hgt) : 0.5;
    this.box(dk.w, thick, dk.h, (x0 + x1) / 2, top - thick / 2, (z0 + z1) / 2, deckMat, true, true, 0, x0, z0);
    if (hgt > 1 && dk.material !== "concrete") {   // support posts at corners and every 8 ft
      var px = [], pz = [], nx = Math.max(1, Math.ceil(dk.w / 8)), nz = Math.max(1, Math.ceil(dk.h / 8));
      for (var i = 0; i <= nx; i++) px.push(x0 + 0.25 + (dk.w - 0.5) * i / nx); for (var j = 0; j <= nz; j++) pz.push(z0 + 0.25 + (dk.h - 0.5) * j / nz);
      px.forEach(function (x) { pz.forEach(function (z) { if (x === px[0] || x === px[px.length - 1] || z === pz[0] || z === pz[pz.length - 1]) self.box(0.45, top - thick - base, 0.45, x, base + (top - thick - base) / 2, z, postMat, true, true); }); });
    }
    var rails = dk.rails || {}, stairs = dk.stairs && dk.stairs !== "none" ? dk.stairs : null, sw = +dk.stairW || 4, cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
    var rail = function (ax, az, bx, bz, gapAt) {   // top rail, bottom rail, posts every 6 ft, balusters every 0.45 ft; gapAt = [center, width] to leave an opening for stairs
      var L = Math.hypot(bx - ax, bz - az), ux = (bx - ax) / L, uz = (bz - az) / L, ang = -Math.atan2(bz - az, bx - ax);
      var segs = gapAt ? [[0, Math.max(0, gapAt[0] - gapAt[1] / 2)], [Math.min(L, gapAt[0] + gapAt[1] / 2), L]] : [[0, L]];
      segs.forEach(function (sg) {
        var a = sg[0], b = sg[1]; if (b - a < 0.3) return;
        var mid = (a + b) / 2, len = b - a;
        self.box(len, 0.15, 0.3, ax + ux * mid, top + 3.0, az + uz * mid, railMat, true, true, ang);
        self.box(len, 0.12, 0.12, ax + ux * mid, top + 0.35, az + uz * mid, railMat, true, true, ang);
        var nP = Math.max(1, Math.round(len / 6)); for (var k = 0; k <= nP; k++) { var t = a + len * k / nP; self.box(0.3, 3.1, 0.3, ax + ux * t, top + 1.55, az + uz * t, railMat, true, true, ang); }
        for (var t2 = a + 0.4; t2 < b; t2 += 0.45) self.box(0.08, 2.5, 0.08, ax + ux * t2, top + 1.65, az + uz * t2, railMat, false, false, ang);
      });
    };
    if (rails.n) rail(x0, z0, x1, z0, stairs === "n" ? [cx - x0, sw] : null);
    if (rails.s) rail(x0, z1, x1, z1, stairs === "s" ? [cx - x0, sw] : null);
    if (rails.w) rail(x0, z0, x0, z1, stairs === "w" ? [cz - z0, sw] : null);
    if (rails.e) rail(x1, z0, x1, z1, stairs === "e" ? [cz - z0, sw] : null);
    if (stairs && hgt > 0.3) {   // stairs down to the level's floor, 7" rises, 11" treads
      var n = Math.ceil(hgt / 0.6), rise = hgt / n, tread = 0.9167;
      for (var k2 = 0; k2 < n; k2++) {
        var ytop = top - rise * (k2 + 1), hh = ytop - base; if (hh <= 0) continue;
        var off = tread * (k2 + 0.5);
        if (stairs === "s") self.box(sw, hh, tread, cx, base + hh / 2, z1 + off, deckMat, true, true);
        else if (stairs === "n") self.box(sw, hh, tread, cx, base + hh / 2, z0 - off, deckMat, true, true);
        else if (stairs === "e") self.box(tread, hh, sw, x1 + off, base + hh / 2, cz, deckMat, true, true);
        else self.box(tread, hh, sw, x0 - off, base + hh / 2, cz, deckMat, true, true);
      }
    }
  };

  P.fixture = function (f, base) {
    var spec = FIX[f.kind] || FIX.box, cx = f.x + f.w / 2, cz = f.y + f.h / 2, rot = -(f.rot || 0) * Math.PI / 180;
    var lw = (f.rot % 180) ? f.h : f.w, lh = (f.rot % 180) ? f.w : f.h;   // local (unrotated) footprint
    if (f.kind === "stairs") {
      var tread = 0.9167, n = Math.max(2, Math.floor(lh / tread)), rise = WALL_H / n, g = new THREE.Group();
      for (var i = 0; i < n; i++) {
        var m = new THREE.Mesh(new THREE.BoxGeometry(lw, rise * (i + 1), tread), this.mat(spec.c));
        // the flight always rises toward the fixture's far end; UP/DN only changes the plan arrow's meaning
        m.position.set(0, rise * (i + 1) / 2, -lh / 2 + tread * (i + 0.5)); m.castShadow = m.receiveShadow = true; g.add(m);
      }
      g.position.set(cx, base, cz); g.rotation.y = rot; this.model.add(g); return;
    }
    var h = (+f.hgt && !spec.top && f.kind !== "column" && f.kind !== "chimney") ? +f.hgt : spec.h, mesh, z0 = spec.z0 || 0, self = this;
    var metal = spec.metal ? { roughness: 0.35, metalness: 0.5 } : {};
    if (f.kind === "chimney") {   // brick chimney from this floor up to hgt, with a cap
      var chH = +f.hgt || spec.hgt || 22, ch = new THREE.Mesh(new THREE.BoxGeometry(lw, chH, lh), this.texMat({ kind: "brick", color: "#8a5a44" })); ch.position.set(cx, base + chH / 2, cz); ch.rotation.y = rot; ch.castShadow = ch.receiveShadow = true; this.model.add(ch);
      var capC = new THREE.Mesh(new THREE.BoxGeometry(lw + 0.3, 0.3, lh + 0.3), this.mat("#8f8f89")); capC.position.set(cx, base + chH + 0.15, cz); capC.rotation.y = rot; capC.castShadow = true; this.model.add(capC);
      return;
    }
    if (f.kind === "column") {   // craftsman porch column: stone pier, white cap, tapered white shaft, top block
      var gc = new THREE.Group(), tot = +f.hgt || spec.hgt || 8.5, pierH = Math.min(3.2, tot * 0.4), side = Math.min(lw, lh);
      var pier = new THREE.Mesh(new THREE.BoxGeometry(lw, pierH, lh), this.texMat({ kind: "stone", color: "#b3a48c" })); pier.position.y = pierH / 2; pier.castShadow = pier.receiveShadow = true; gc.add(pier);
      var cap = new THREE.Mesh(new THREE.BoxGeometry(lw + 0.25, 0.25, lh + 0.25), this.mat("#f2efe8", { roughness: 0.6 })); cap.position.y = pierH + 0.125; cap.castShadow = true; gc.add(cap);
      var shaftH = Math.max(0.5, tot - pierH - 0.25 - 0.3), shaft = new THREE.Mesh(new THREE.CylinderGeometry(side * 0.28, side * 0.36, shaftH, 4), this.mat("#f4f1ea", { roughness: 0.6 })); shaft.rotation.y = Math.PI / 4; shaft.position.y = pierH + 0.25 + shaftH / 2; shaft.castShadow = true; gc.add(shaft);
      var head = new THREE.Mesh(new THREE.BoxGeometry(side * 0.9, 0.3, side * 0.9), this.mat("#f2efe8", { roughness: 0.6 })); head.position.y = tot - 0.15; head.castShadow = true; gc.add(head);
      gc.position.set(cx, base, cz); gc.rotation.y = rot; this.model.add(gc); return;
    }
    if (spec.top) {   // cabinets with a countertop slab (sink/vanity get a basin cut-out look)
      var g2 = new THREE.Group(), cabH = h - 0.12;
      var cab = new THREE.Mesh(new THREE.BoxGeometry(lw, cabH, lh), this.mat(spec.c)); cab.position.y = cabH / 2; cab.castShadow = cab.receiveShadow = true; g2.add(cab);
      var ov = spec.overhang || 0, slab = new THREE.Mesh(new THREE.BoxGeometry(lw + 0.1, 0.12, lh + 0.1 + ov), this.mat(TOP, { roughness: 0.35 })); slab.position.set(0, cabH + 0.06, ov / 2); slab.castShadow = slab.receiveShadow = true; g2.add(slab);
      if (spec.basin) { var bowls = f.kind === "dbl_sink" ? [-lw * 0.24, lw * 0.24] : [0]; bowls.forEach(function (bx) { var bowl = new THREE.Mesh(new THREE.BoxGeometry(f.kind === "dbl_sink" ? lw * 0.4 : lw * 0.7, 0.05, lh * 0.6), self.mat(0xe5e7ea, { roughness: 0.3, metalness: 0.4 })); bowl.position.set(bx, cabH + 0.13, 0); g2.add(bowl); }); }
      g2.position.set(cx, base, cz); g2.rotation.y = rot; this.model.add(g2); return;
    }
    if (spec.shape === "stool" || spec.shape === "round") {
      var g3 = new THREE.Group(), rTop = Math.min(lw, lh) / 2, seatH = spec.shape === "stool" ? 0.15 : 0.15;
      var top = new THREE.Mesh(new THREE.CylinderGeometry(rTop, rTop, seatH, 28), this.mat(spec.c)); top.position.y = h - seatH / 2; top.castShadow = top.receiveShadow = true; g3.add(top);
      var post = new THREE.Mesh(new THREE.CylinderGeometry(spec.shape === "stool" ? 0.08 : 0.25, spec.shape === "stool" ? 0.08 : 0.35, h - seatH, 16), this.mat(0x4a4d52, { metalness: 0.4, roughness: 0.4 })); post.position.y = (h - seatH) / 2; post.castShadow = true; g3.add(post);
      var foot = new THREE.Mesh(new THREE.CylinderGeometry(rTop * 0.7, rTop * 0.7, 0.05, 20), this.mat(0x4a4d52)); foot.position.y = 0.025; g3.add(foot);
      g3.position.set(cx, base, cz); g3.rotation.y = rot; this.model.add(g3); return;
    }
    if (spec.shape === "chair") {
      var g4 = new THREE.Group(), seat = new THREE.Mesh(new THREE.BoxGeometry(lw, 0.15, lh), this.mat(spec.c)); seat.position.y = 1.5; seat.castShadow = true; g4.add(seat);
      var back = new THREE.Mesh(new THREE.BoxGeometry(lw, 1.5, 0.12), this.mat(spec.c)); back.position.set(0, 2.25, -lh / 2 + 0.06); back.castShadow = true; g4.add(back);
      [[-1, -1], [1, -1], [-1, 1], [1, 1]].forEach(function (c2) { var leg = new THREE.Mesh(new THREE.BoxGeometry(0.1, 1.45, 0.1), self.mat(spec.c)); leg.position.set(c2[0] * (lw / 2 - 0.08), 0.72, c2[1] * (lh / 2 - 0.08)); g4.add(leg); });
      g4.position.set(cx, base, cz); g4.rotation.y = rot; this.model.add(g4); return;
    }
    if (spec.thin) { mesh = new THREE.Mesh(new THREE.BoxGeometry(lw, 0.1, lh), this.mat(spec.c, metal)); mesh.position.set(cx, base + h - 0.05, cz); mesh.rotation.y = rot; mesh.castShadow = mesh.receiveShadow = true; this.model.add(mesh); return; }
    if (f.kind === "water_heater") mesh = new THREE.Mesh(new THREE.CylinderGeometry(Math.min(lw, lh) / 2, Math.min(lw, lh) / 2, h, 24), this.mat(spec.c));
    else if (f.kind === "toilet" || f.kind === "tub" || f.kind === "sofa" || f.kind === "bed" || f.kind === "bed_king" || f.kind === "car") {
      mesh = new THREE.Group();
      var b1 = new THREE.Mesh(new THREE.BoxGeometry(lw, h, lh), this.mat(spec.c)); b1.castShadow = b1.receiveShadow = true; mesh.add(b1);
      if (f.kind === "toilet") { var tank = new THREE.Mesh(new THREE.BoxGeometry(lw, 1.2, lh * 0.3), this.mat(spec.c)); tank.position.set(0, h / 2 + 0.6, -lh * 0.35); tank.castShadow = true; mesh.add(tank); }
      if (f.kind === "sofa" || f.kind === "bed" || f.kind === "bed_king") { var back = new THREE.Mesh(new THREE.BoxGeometry(lw, f.kind === "sofa" ? 1 : 1.5, lh * 0.15), this.mat(spec.c)); back.position.set(0, h / 2 + (f.kind === "sofa" ? 0.5 : 0.75), -lh * 0.425); back.castShadow = true; mesh.add(back); }
      if (f.kind === "car") { var cab = new THREE.Mesh(new THREE.BoxGeometry(lw * 0.85, 1.6, lh * 0.45), this.mat(0x2f3d55, { roughness: 0.3, metalness: 0.4 })); cab.position.set(0, h / 2 + 0.8, -lh * 0.05); cab.castShadow = true; mesh.add(cab); }
      mesh.position.set(cx, base + h / 2, cz); mesh.rotation.y = rot; this.model.add(mesh); return;
    } else mesh = new THREE.Mesh(new THREE.BoxGeometry(lw, h, lh), this.mat(spec.c, metal));
    mesh.position.set(cx, base + z0 + h / 2, cz); mesh.rotation.y = rot; mesh.castShadow = mesh.receiveShadow = true; this.model.add(mesh);
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
    (function loop() { requestAnimationFrame(loop); self.controls.update(); self.draw(); })();
  };

  // ------------------------------------------------------------ rendering still
  P.saveRendering = function () {
    var self = this, r = this.renderer, w = this.root.clientWidth, h = this.root.clientHeight, prevRatio = r.getPixelRatio();
    this.status.textContent = "Rendering…";
    var scale = Math.min(3, Math.floor(3000 / Math.max(w, h)) || 1);
    r.setPixelRatio(scale); r.setSize(w, h);
    if (this.composer) { this.composer.setPixelRatio(scale); this.composer.setSize(w, h); this.ssao.setSize(w * scale, h * scale); }
    this.draw();
    var url = r.domElement.toDataURL("image/jpeg", 0.92);
    r.setPixelRatio(prevRatio); r.setSize(w, h);
    if (this.composer) { this.composer.setPixelRatio(prevRatio); this.composer.setSize(w, h); this.ssao.setSize(w, h); }
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
