// Design Center — 3D view (Phase 3). Builds a Three.js scene from floor-plan JSON
// (see app/models/design/floor_plan.rb for the data shape). Plan x → x, plan y → z, up → y.
// Levels stack by position. Mounted by app/views/design/floor_plans/view3d.html.erb.
(function () {
  "use strict";

  var WALL_H = 9, FLOOR_T = 1, DOOR_H = 6.67, SILL = 3, HEAD = 6.67;
  var COLORS = { exterior: 0xe6dcc6, interior: 0xf4f3ee, floor: 0xd9c4a3, slab: 0xb9b6ad, ground: 0xc9d3bf, door: 0x8a5a2b, glass: 0x9ccbe8, frame: 0xffffff };
  // fixture heights (ft) and colors
  var FIX = {
    stairs: { h: WALL_H, c: 0xc8b18a }, toilet: { h: 1.4, c: 0xfafafa }, sink: { h: 3, c: 0xfafafa }, tub: { h: 1.8, c: 0xfafafa }, shower: { h: 0.3, c: 0xe8eef2 },
    range: { h: 3, c: 0x8b9096 }, fridge: { h: 6, c: 0xb8bcc2 }, dishwasher: { h: 2.9, c: 0xb8bcc2 }, washer: { h: 3, c: 0xe9e9e9 }, water_heater: { h: 5, c: 0xcfcfcf },
    counter: { h: 3, c: 0xd8cfc0 }, island: { h: 3, c: 0xd8cfc0 }, bed: { h: 2, c: 0x9fb4c7 }, bed_king: { h: 2, c: 0x9fb4c7 }, sofa: { h: 2.5, c: 0x8c8f9a },
    table: { h: 2.5, c: 0xa77b4d }, desk: { h: 2.5, c: 0xa77b4d }, car: { h: 4.7, c: 0x6b7f99 }, box: { h: 3, c: 0xbfbfbf }
  };

  function View(root, opts) {
    this.root = root; this.opts = opts; this.levels = opts.levels || [];
    this.visible = {}; this.levels.forEach(function (l) { this.visible[l.id] = true; }, this);
    this.materials = {};
    this.setupScene(); this.buildUI(); this.rebuild(); this.resetView(); this.animate();
  }
  var P = View.prototype;

  P.mat = function (color, extra) {
    var key = color + JSON.stringify(extra || {});
    if (!this.materials[key]) this.materials[key] = new THREE.MeshStandardMaterial(Object.assign({ color: color, roughness: 0.85, metalness: 0.02 }, extra || {}));
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

    var ground = new THREE.Mesh(new THREE.PlaneGeometry(2000, 2000), this.mat(COLORS.ground, { roughness: 1 }));
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
      var id = "v3-lvl-" + l.id, lab = document.createElement("label"); lab.className = "form-check form-check-inline small mb-0";
      lab.innerHTML = '<input class="form-check-input" type="checkbox" checked id="' + id + '"> <span>' + (l.name + (l.level ? " · " + l.level : "")).replace(/[<>&]/g, "") + "</span>";
      lab.querySelector("input").addEventListener("change", function (e) { self.visible[l.id] = e.target.checked; self.rebuild(); });
      ui.levels.appendChild(lab);
    });
    ui.reset.addEventListener("click", function () { self.resetView(); });
    ui.render.addEventListener("click", function () { self.saveRendering(); });
    this.status = ui.status;
  };

  // ------------------------------------------------------------ geometry
  P.rebuild = function () {
    while (this.model.children.length) this.model.remove(this.model.children[0]);
    var self = this, shown = this.levels.filter(function (l) { return self.visible[l.id]; });
    var bbox = { minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity }, any = false;
    this.levels.forEach(function (l, i) {
      if (!self.visible[l.id]) return;
      var base = i * (WALL_H + FLOOR_T), d = l.data || {};
      var walls = d.walls || [], rooms = d.rooms || [], openings = d.openings || [], fixtures = d.fixtures || [];
      var ext = walls.filter(function (w) { return w.type === "exterior"; }), src = ext.length ? ext : walls;
      src.forEach(function (w) { [[w.x1, w.y1], [w.x2, w.y2]].forEach(function (p) { bbox.minX = Math.min(bbox.minX, p[0]); bbox.maxX = Math.max(bbox.maxX, p[0]); bbox.minY = Math.min(bbox.minY, p[1]); bbox.maxY = Math.max(bbox.maxY, p[1]); any = true; }); });
      rooms.forEach(function (r) { bbox.minX = Math.min(bbox.minX, r.x); bbox.maxX = Math.max(bbox.maxX, r.x + r.w); bbox.minY = Math.min(bbox.minY, r.y); bbox.maxY = Math.max(bbox.maxY, r.y + r.h); any = true; });

      // floor slab under the level footprint + room floors
      var fx0 = Infinity, fy0 = Infinity, fx1 = -Infinity, fy1 = -Infinity;
      src.concat(rooms.map(function (r) { return { x1: r.x, y1: r.y, x2: r.x + r.w, y2: r.y + r.h }; })).forEach(function (w) { fx0 = Math.min(fx0, w.x1, w.x2); fx1 = Math.max(fx1, w.x1, w.x2); fy0 = Math.min(fy0, w.y1, w.y2); fy1 = Math.max(fy1, w.y1, w.y2); });
      if (isFinite(fx0)) self.box(fx1 - fx0 + 0.5, FLOOR_T, fy1 - fy0 + 0.5, (fx0 + fx1) / 2, base - FLOOR_T / 2, (fy0 + fy1) / 2, self.mat(COLORS.slab), false, true);
      rooms.forEach(function (r) { self.box(r.w, 0.06, r.h, r.x + r.w / 2, base + 0.03, r.y + r.h / 2, self.mat(COLORS.floor, { roughness: 0.7 }), false, true); });

      walls.forEach(function (w) { self.wall(w, openings.filter(function (o) { return o.wall === w.id; }), base); });
      fixtures.forEach(function (f) { self.fixture(f, base); });
    });
    this.bbox = any ? bbox : { minX: 0, minY: 0, maxX: 40, maxY: 30 };
    this.levelsShown = shown.length;
    var empty = this.root.querySelector(".v3-empty");
    if (!any) { if (!empty) { empty = document.createElement("div"); empty.className = "v3-empty"; empty.textContent = "Nothing to show yet — draw some walls or rooms in the editor first."; this.root.appendChild(empty); } }
    else if (empty) empty.remove();
  };

  P.box = function (w, h, d, x, y, z, material, castShadow, receiveShadow, rotY) {
    var m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
    m.position.set(x, y, z); if (rotY) m.rotation.y = rotY;
    m.castShadow = castShadow !== false; m.receiveShadow = receiveShadow !== false;
    this.model.add(m); return m;
  };

  // A wall becomes solid pieces between openings, headers above doors, and sill/head pieces plus glass for windows.
  P.wall = function (w, ops, base) {
    var dx = w.x2 - w.x1, dz = w.y2 - w.y1, len = Math.hypot(dx, dz); if (len < 0.01) return;
    var t = w.thickness || (w.type === "interior" ? 0.375 : 0.5), ang = -Math.atan2(dz, dx), ux = dx / len, uz = dz / len;
    var material = this.mat(w.type === "interior" ? COLORS.interior : COLORS.exterior), self = this;
    var piece = function (a, b, y0, y1, mat, thick, extendEnds) {
      if (b - a <= 0.001 || y1 - y0 <= 0.001) return;
      var ea = extendEnds && a <= 0.001 ? t / 2 : 0, eb = extendEnds && b >= len - 0.001 ? t / 2 : 0;
      var L = (b - a) + ea + eb, mid = (a + b) / 2 + (eb - ea) / 2;
      self.box(L, y1 - y0, thick || t, w.x1 + ux * mid, base + (y0 + y1) / 2, w.y1 + uz * mid, mat || material, true, true, ang);
    };
    ops = ops.slice().sort(function (a, b) { return a.pos - b.pos; });
    var cursor = 0;
    ops.forEach(function (o) {
      var half = o.width / 2, a = Math.max(cursor, Math.min(o.pos, len - half) - half), b = Math.min(len, a + o.width);
      piece(cursor, a, 0, WALL_H, null, null, true);
      if (o.type === "door") {
        piece(a, b, DOOR_H, WALL_H, null, null, false);
        piece(a + 0.05, b - 0.05, 0, DOOR_H - 0.02, self.mat(COLORS.door, { roughness: 0.6 }), 0.15, false);
      } else {
        piece(a, b, 0, SILL, null, null, false);
        piece(a, b, HEAD, WALL_H, null, null, false);
        piece(a, b, SILL, HEAD, self.mat(COLORS.glass, { transparent: true, opacity: 0.45, roughness: 0.1, metalness: 0.3 }), 0.08, false);
        piece(a, b, SILL - 0.1, SILL, self.mat(COLORS.frame), t + 0.1, false);
      }
      cursor = b;
    });
    piece(cursor, len, 0, WALL_H, null, null, true);
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
