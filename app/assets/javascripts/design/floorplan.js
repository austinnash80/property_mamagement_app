// Design Center — floor plan editor (Phase 2).
// Vanilla JS on a <canvas>. All geometry is in feet; the view maps feet to
// pixels with a scale + offset. Mounted by app/views/design/floor_plans/show.html.erb:
//   FloorPlanEditor.mount(rootElement, { data, widthFt, depthFt, saveUrl, csrf, name })
(function () {
  "use strict";

  var WALL_TYPES = { exterior: 0.5, interior: 0.375 };  // thickness in ft (6", 4.5")
  var OPENING_WIDTH = { door: 3, window: 4 };
  // Door kinds (default width / height in ft) and window defaults. Heights matter in the 3D view.
  var DOOR_KINDS = { exterior: { label: "Exterior door", w: 3, h: 6.67 }, interior: { label: "Interior door", w: 2.667, h: 6.67 }, garage: { label: "Garage door", w: 9, h: 7 }, sliding: { label: "Sliding door", w: 6, h: 6.67 } };
  var WINDOW_DEF = { w: 4, sill: 3, h: 3.67 };
  // Roof sections: axis-aligned rectangles with their own style; the 3D view builds these instead of the automatic roof.
  var ROOF_KINDS = [["hip", "Hip"], ["gable", "Gable"], ["shed", "Shed (single slope)"], ["flat", "Flat"]];
  var PITCHES = [2, 3, 4, 5, 6, 7, 8, 9, 10, 12];
  var RIDGES = [["auto", "Auto (along the long side)"], ["x", "Left ↔ right"], ["y", "Front ↔ back"]];
  var HIGH_SIDES = [["n", "Back (top of plan)"], ["s", "Front (bottom)"], ["w", "Left"], ["e", "Right"]];
  var ROOF_DEF = { style: "hip", pitch: 6, ridge: "auto", overhang: 1.5, eave: 9, high: "n" };
  function doorKind(o, w) { return o.kind || (w && w.type === "interior" ? "interior" : "exterior"); }
  // Fixture catalog: default footprint in ft (w across, h deep). Glyphs are drawn in drawFixture.
  // g = group shown in the picker. "above" items sit above counter height and draw dashed in plan.
  var FIXTURES = {
    counter:     { g: "Kitchen", label: "Base cabinets & counter", w: 8, h: 2 },
    upper:       { g: "Kitchen", label: "Upper cabinets", w: 8, h: 1, above: true },
    island:      { g: "Kitchen", label: "Island", w: 6, h: 3 },
    island_seat: { g: "Kitchen", label: "Island with seating overhang", w: 7, h: 3.5 },
    sink:        { g: "Kitchen", label: "Kitchen sink", w: 2.5, h: 1.75 },
    dbl_sink:    { g: "Kitchen", label: "Double sink", w: 3, h: 1.75 },
    range:       { g: "Kitchen", label: "Range 30\"", w: 2.5, h: 2.17 },
    range36:     { g: "Kitchen", label: "Range 36\"", w: 3, h: 2.17 },
    cooktop:     { g: "Kitchen", label: "Cooktop (in counter)", w: 2.5, h: 1.75 },
    wall_oven:   { g: "Kitchen", label: "Wall oven tower", w: 2.5, h: 2 },
    hood:        { g: "Kitchen", label: "Range hood", w: 3, h: 1.5, above: true },
    microwave:   { g: "Kitchen", label: "Microwave (built-in)", w: 2.5, h: 1.5, above: true },
    fridge:      { g: "Kitchen", label: "Refrigerator", w: 3, h: 2.5 },
    dishwasher:  { g: "Kitchen", label: "Dishwasher", w: 2, h: 2 },
    pantry:      { g: "Kitchen", label: "Pantry cabinet", w: 3, h: 2 },
    stool:       { g: "Kitchen", label: "Bar stool", w: 1.25, h: 1.25 },
    table:       { g: "Kitchen", label: "Dining table", w: 6, h: 3.5 },
    round_table: { g: "Kitchen", label: "Round table", w: 4, h: 4 },
    chair:       { g: "Kitchen", label: "Chair", w: 1.5, h: 1.5 },
    toilet:      { g: "Bath", label: "Toilet", w: 1.5, h: 2.5 },
    vanity:      { g: "Bath", label: "Vanity", w: 3, h: 1.75 },
    tub:         { g: "Bath", label: "Bathtub", w: 5, h: 2.5 },
    shower:      { g: "Bath", label: "Shower", w: 3, h: 3 },
    washer:      { g: "Laundry & utility", label: "Washer / dryer", w: 2.25, h: 2.25 },
    water_heater:{ g: "Laundry & utility", label: "Water heater", w: 2, h: 2 },
    bed:         { g: "Living & bedroom", label: "Bed (queen)", w: 5, h: 6.67 },
    bed_king:    { g: "Living & bedroom", label: "Bed (king)", w: 6.33, h: 6.67 },
    sofa:        { g: "Living & bedroom", label: "Sofa", w: 7, h: 3 },
    desk:        { g: "Living & bedroom", label: "Desk", w: 5, h: 2.5 },
    stairs:      { g: "Other", label: "Stairs", w: 3, h: 12 },
    car:         { g: "Other", label: "Car", w: 6.5, h: 16 },
    box:         { g: "Other", label: "Box (anything)", w: 3, h: 3 }
  };
  var FIXTURE_GROUPS = ["Kitchen", "Bath", "Laundry & utility", "Living & bedroom", "Other"];
  function fixtureOptions(selected) {
    return FIXTURE_GROUPS.map(function (g) {
      var items = Object.keys(FIXTURES).filter(function (k) { return FIXTURES[k].g === g; });
      return '<optgroup label="' + g + '">' + items.map(function (k) { return '<option value="' + k + '"' + (selected === k ? " selected" : "") + '>' + FIXTURES[k].label + '</option>'; }).join("") + '</optgroup>';
    }).join("");
  }
  var HANDLE = 6;                                         // px
  var SNAPS = [[1 / 12, '1"'], [0.25, '3"'], [0.5, '6"'], [1, "1'"]];
  var C = {
    bg: "#ffffff", gridMinor: "#f0f2f5", gridMajor: "#dde2e8", boundary: "#9aa3ad",
    wall: "#2b2f36", sel: "#0d6efd", selFill: "rgba(13,110,253,.12)", room: "rgba(255,214,102,.22)",
    roomText: "#4b4f57", door: "#8a5a2b", win: "#2f7fd6", label: "#1f2a37", dim: "#0d6efd", draft: "#e0742a", guide: "#6b7280", roof: "#8b5e3c", roofFill: "rgba(139,94,60,.10)", fix: "#4b5563", under: "#93a0b4", string: "#3a3f47"
  };

  function uid() { return Math.random().toString(36).slice(2, 10); }
  function clamp(v, a, b) { return Math.min(b, Math.max(a, v)); }
  function ftIn(ft) {
    var sign = ft < 0 ? "-" : "", inches = Math.round(Math.abs(ft) * 12), f = Math.floor(inches / 12);
    inches -= f * 12;
    return sign + f + "'" + (inches ? "-" + inches + '"' : "");
  }
  function sqft(a) { return Math.round(a).toLocaleString() + " sq ft"; }
  function normalize(d) {
    d = d && typeof d === "object" ? d : {};
    var n = { version: 1, grid: +d.grid || 0.5, walls: d.walls || [], rooms: d.rooms || [], openings: d.openings || [], labels: d.labels || [], fixtures: d.fixtures || [], guides: d.guides || [], roofs: d.roofs || [] };
    n.rooms.forEach(roomSync);
    return n;
  }
  function seg(w) {
    var dx = w.x2 - w.x1, dy = w.y2 - w.y1, len = Math.hypot(dx, dy) || 1e-9;
    return { len: len, ux: dx / len, uy: dy / len, nx: -dy / len, ny: dx / len };
  }
  function project(p, w) {  // point onto wall: {pos (ft from start), d (perp distance), x, y, len}
    var s = seg(w), pos = clamp((p.x - w.x1) * s.ux + (p.y - w.y1) * s.uy, 0, s.len);
    var x = w.x1 + s.ux * pos, y = w.y1 + s.uy * pos;
    return { pos: pos, d: Math.hypot(p.x - x, p.y - y), x: x, y: y, len: s.len };
  }
  // Rooms are polygons: r.pts = [[x,y],...] in ft; x/y/w/h is kept in sync as the bounding box.
  function roomPts(r) { if (!r.pts || r.pts.length < 3) r.pts = [[r.x, r.y], [r.x + r.w, r.y], [r.x + r.w, r.y + r.h], [r.x, r.y + r.h]]; return r.pts; }
  function roomSync(r) {
    var pts = roomPts(r), x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    pts.forEach(function (p) { x0 = Math.min(x0, p[0]); x1 = Math.max(x1, p[0]); y0 = Math.min(y0, p[1]); y1 = Math.max(y1, p[1]); });
    r.x = x0; r.y = y0; r.w = x1 - x0; r.h = y1 - y0; return r;
  }
  function rectPts(r) { return [[r.x, r.y], [r.x + r.w, r.y], [r.x + r.w, r.y + r.h], [r.x, r.y + r.h]]; }
  function roomArea(r) { var p = roomPts(r), a = 0; for (var i = 0, n = p.length; i < n; i++) { var j = (i + 1) % n; a += p[i][0] * p[j][1] - p[j][0] * p[i][1]; } return Math.abs(a) / 2; }
  function roomIsRect(r) {
    var p = roomPts(r); if (p.length !== 4) return false;
    for (var i = 0; i < 4; i++) { var a = p[i], b = p[(i + 1) % 4]; if (Math.abs(a[0] - b[0]) > 1e-6 && Math.abs(a[1] - b[1]) > 1e-6) return false; }
    return true;
  }
  function roomCentroid(r) {
    var p = roomPts(r), a = 0, cx = 0, cy = 0;
    for (var i = 0, n = p.length; i < n; i++) { var j = (i + 1) % n, f = p[i][0] * p[j][1] - p[j][0] * p[i][1]; a += f; cx += (p[i][0] + p[j][0]) * f; cy += (p[i][1] + p[j][1]) * f; }
    if (Math.abs(a) < 1e-9) return { x: r.x + r.w / 2, y: r.y + r.h / 2 };
    return { x: cx / (3 * a), y: cy / (3 * a) };
  }
  function pointInPoly(pt, pts) {
    var inside = false;
    for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      var xi = pts[i][0], yi = pts[i][1], xj = pts[j][0], yj = pts[j][1];
      if ((yi > pt.y) !== (yj > pt.y) && pt.x < (xj - xi) * (pt.y - yi) / (yj - yi) + xi) inside = !inside;
    }
    return inside;
  }
  function translateRoom(r, dx, dy) { r.pts = roomPts(r).map(function (p) { return [p[0] + dx, p[1] + dy]; }); roomSync(r); }
  // Douglas–Peucker simplification (tolerance in ft) for polygons traced from the wall raster.
  function simplify(pts, tol) {
    if (pts.length < 4) return pts;
    var keep = new Array(pts.length).fill(false), dist = function (p, a, b) { var dx = b[0] - a[0], dy = b[1] - a[1], L2 = dx * dx + dy * dy || 1e-9, t = clamp(((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L2, 0, 1); return Math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy); };
    var rec = function (i, j) { var maxD = 0, k = -1; for (var m = i + 1; m < j; m++) { var d = dist(pts[m], pts[i], pts[j]); if (d > maxD) { maxD = d; k = m; } } if (maxD > tol) { keep[k] = true; rec(i, k); rec(k, j); } };
    // anchor on the two farthest-apart vertices so the closed ring simplifies cleanly
    var far = 0, fi = 0; for (var i = 1; i < pts.length; i++) { var d = Math.hypot(pts[i][0] - pts[0][0], pts[i][1] - pts[0][1]); if (d > far) { far = d; fi = i; } }
    keep[0] = keep[fi] = true; rec(0, fi); rec(fi, pts.length - 1); keep[pts.length - 1] = true;
    var out = pts.filter(function (_, i) { return keep[i]; });
    if (out.length > 1 && out[0][0] === out[out.length - 1][0] && out[0][1] === out[out.length - 1][1]) out.pop();
    return out;
  }

  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function download(name, href) { var a = document.createElement("a"); a.href = href; a.download = name; document.body.appendChild(a); a.click(); a.remove(); }

  var TEMPLATE =
    '<div class="fp-toolbar">' +
    '  <div class="btn-group btn-group-sm fp-tools" role="group">' +
    '    <button class="btn btn-outline-secondary" data-tool="select" title="Select / move (V)">Select</button>' +
    '    <button class="btn btn-outline-secondary" data-tool="wall" title="Draw walls (W). Click to start, click for each corner, Esc/Enter to finish. Diagonals: Angles dropdown or hold Shift.">Wall</button>' +
    '    <button class="btn btn-outline-secondary" data-tool="room" title="Drag a room rectangle (R)">Room</button>' +
    '    <button class="btn btn-outline-secondary" data-tool="door" title="Click a wall to place a door (D)">Door</button>' +
    '    <button class="btn btn-outline-secondary" data-tool="window" title="Click a wall to place a window (N)">Window</button>' +
    '    <button class="btn btn-outline-secondary" data-tool="label" title="Click to place text (T)">Label</button>' +
    '    <button class="btn btn-outline-secondary" data-tool="fixture" title="Place stairs, plumbing, appliances, furniture (X)">Fixture</button>' +
    '    <button class="btn btn-outline-secondary" data-tool="line" title="Guide line (L): a thin dashed reference line that shows its length, e.g. a setback. Not shown in 3D.">Line</button>' +
    '    <button class="btn btn-outline-secondary" data-tool="roof" title="Roof section (O): drag a rectangle over the area a roof covers, then set hip/gable/shed, pitch and overhang. Replaces the automatic roof in 3D.">Roof</button>' +
    '  </div>' +
    '  <select class="form-select form-select-sm w-auto fp-kind d-none" title="Which fixture to place"></select>' +
    '  <select class="form-select form-select-sm w-auto fp-doorkind d-none" title="Which kind of door to place"><option value="auto">Door: match wall</option><option value="exterior">Exterior door</option><option value="interior">Interior door</option><option value="garage">Garage door</option><option value="sliding">Sliding door</option></select>' +
    '  <div class="btn-group btn-group-sm" role="group">' +
    '    <button class="btn btn-outline-secondary" data-act="undo" title="Undo (Ctrl+Z)">Undo</button>' +
    '    <button class="btn btn-outline-secondary" data-act="redo" title="Redo (Ctrl+Shift+Z)">Redo</button>' +
    '  </div>' +
    '  <div class="btn-group btn-group-sm" role="group">' +
    '    <button class="btn btn-outline-secondary" data-act="zoomOut" title="Zoom out (-)">−</button>' +
    '    <button class="btn btn-outline-secondary" data-act="fit" title="Fit plan (F)">Fit</button>' +
    '    <button class="btn btn-outline-secondary" data-act="zoomIn" title="Zoom in (+)">+</button>' +
    '    <button class="btn btn-outline-secondary" data-act="grid" title="Toggle grid (G)">Grid</button>' +
    '    <button class="btn btn-outline-secondary" data-act="dims" title="Exterior dimension strings">Dimensions</button>' +
    '  </div>' +
    '  <label class="small text-nowrap ms-1 fp-underlay-wrap d-none">Show level below <select class="form-select form-select-sm d-inline-block w-auto fp-underlay"></select> <button class="btn btn-outline-secondary btn-sm d-none fp-copy" data-act="copyUnderlay" title="Copy the exterior walls of that level into this plan">Copy outline</button></label>' +
    '  <label class="small text-nowrap ms-1">Snap <select class="form-select form-select-sm d-inline-block w-auto fp-snap"></select></label>' +
    '  <label class="small text-nowrap ms-1" title="How walls and lines are constrained while drawing or dragging an end. Hold Shift for any angle at any time.">Angles <select class="form-select form-select-sm d-inline-block w-auto fp-angle"><option value="ortho">90° only</option><option value="45">45° steps</option><option value="free">Any</option></select></label>' +
    '  <span class="small fp-zoom text-muted ms-1"></span>' +
    '  <div class="ms-auto d-flex align-items-center gap-2">' +
    '    <span class="small fp-status text-muted"></span>' +
    '    <button class="btn btn-outline-secondary btn-sm" data-act="pdf" title="Download a to-scale PDF sheet">PDF</button>' +
    '    <button class="btn btn-outline-secondary btn-sm" data-act="png" title="Download a PNG of the plan">PNG</button>' +
    '    <button class="btn btn-outline-secondary btn-sm" data-act="json" title="Download the plan data as JSON">JSON</button>' +
    '    <label class="btn btn-outline-secondary btn-sm mb-0" title="Load plan data from a JSON export">Import<input type="file" accept="application/json,.json" class="fp-import d-none"></label>' +
    '    <button class="btn btn-primary btn-sm" data-act="save" title="Save (Ctrl+S)">Save</button>' +
    '  </div>' +
    '</div>' +
    '<div class="fp-body">' +
    '  <div class="fp-canvas-wrap"><canvas class="fp-canvas"></canvas><div class="fp-hint small"></div></div>' +
    '  <aside class="fp-panel"><div class="fp-props"></div><div class="fp-summary"></div>' +
    '    <div class="fp-help small text-muted"><strong>Shortcuts</strong><br>V W R D N T X L O tools · Esc finish/deselect · Del delete · arrows nudge<br>Ctrl+Z / Ctrl+Shift+Z undo/redo · Ctrl+S save · wheel zoom · drag empty space to pan<br>Right-drag, two-finger drag or Shift+drag to box-select · Shift+click adds · double-click a wall selects its whole run · Ctrl+A all · Angles dropdown or Shift = diagonals</div>' +
    '  </aside>' +
    '</div>';

  function Editor(root, opts) {
    this.root = root; this.opts = opts;
    this.data = normalize(opts.data);
    this.widthFt = +opts.widthFt || 60; this.depthFt = +opts.depthFt || 40;
    this.tool = "select"; this.sel = null; this.selSet = []; this.space = false; this.touches = {}; this.hover = null; this.draft = null; this.drag = null;
    this.view = { scale: 12, x: 0, y: 0 };
    this.history = []; this.future = []; this.dirty = false; this.saving = false;
    this.showGrid = true; this.dimStrings = false; this.shift = false;
    this.mouse = null;
    this.build(); this.bind();
    this.resize(); this.fit(); this.updatePanel(); this.setStatus(opts.name ? "Ready" : "");
  }

  var P = Editor.prototype;

  // Selection: `sel` is the primary item (drives the side panel); `selSet` holds every selected
  // item (marquee, Shift+click, double-click a wall for its connected run).
  P.setSel = function (v) { this.sel = v || null; this.selSet = v ? [v] : []; };
  P.isSelected = function (type, id) { return this.selSet.some(function (x) { return x.type === type && x.id === id; }); };
  P.multi = function () { return this.selSet.length > 1; };
  P.toggleSel = function (hit) {
    if (this.isSelected(hit.type, hit.id)) { this.selSet = this.selSet.filter(function (x) { return !(x.type === hit.type && x.id === hit.id); }); }
    else this.selSet = this.selSet.concat([hit]);
    this.sel = this.selSet.length ? this.selSet[this.selSet.length - 1] : null;
  };
  // Walls joined end-to-end (shared corners) starting from one wall.
  P.connectedWalls = function (id) {
    var walls = this.data.walls, out = {}, stack = [id], same = function (a, b) { return Math.abs(a[0] - b[0]) < 1e-6 && Math.abs(a[1] - b[1]) < 1e-6; };
    while (stack.length) {
      var cur = stack.pop(); if (out[cur]) continue; out[cur] = true;
      var w = this.find("wall", cur); if (!w) continue;
      var ends = [[w.x1, w.y1], [w.x2, w.y2]];
      walls.forEach(function (o) { if (out[o.id]) return; if (ends.some(function (e) { return same(e, [o.x1, o.y1]) || same(e, [o.x2, o.y2]); })) stack.push(o.id); });
    }
    return Object.keys(out).map(function (k) { return { type: "wall", id: k }; });
  };
  P.translateEl = function (type, el, dx, dy) {
    if (type === "wall" || type === "guide") { el.x1 += dx; el.x2 += dx; el.y1 += dy; el.y2 += dy; }
    else if (type === "room") translateRoom(el, dx, dy);
    else if (type === "label" || type === "fixture" || type === "roof") { el.x += dx; el.y += dy; }
  };
  P.anchorOf = function (type, el) { return type === "wall" || type === "guide" ? { x: el.x1, y: el.y1 } : { x: el.x, y: el.y }; };

  // ---------------------------------------------------------------- setup
  P.build = function () {
    this.root.innerHTML = TEMPLATE;
    this.canvas = this.root.querySelector(".fp-canvas");
    this.ctx = this.canvas.getContext("2d");
    this.wrap = this.root.querySelector(".fp-canvas-wrap");
    this.props = this.root.querySelector(".fp-props");
    this.summary = this.root.querySelector(".fp-summary");
    this.statusEl = this.root.querySelector(".fp-status");
    this.hintEl = this.root.querySelector(".fp-hint");
    this.zoomEl = this.root.querySelector(".fp-zoom");
    var snap = this.root.querySelector(".fp-snap"), self = this;
    SNAPS.forEach(function (s) { var o = document.createElement("option"); o.value = s[0]; o.textContent = s[1]; if (Math.abs(s[0] - self.data.grid) < 1e-6) o.selected = true; snap.appendChild(o); });
    snap.addEventListener("change", function () { self.data.grid = +snap.value; self.markDirty(); self.render(); });
    var ang = this.root.querySelector(".fp-angle");
    try { this.angleMode = localStorage.getItem("fp-angle") || "ortho"; } catch (_) { this.angleMode = "ortho"; }
    ang.value = this.angleMode;
    ang.addEventListener("change", function () { self.angleMode = ang.value; try { localStorage.setItem("fp-angle", ang.value); } catch (_) {} self.render(); });
    this.kindSel = this.root.querySelector(".fp-kind");
    this.doorKindSel = this.root.querySelector(".fp-doorkind");
    this.kindSel.innerHTML = fixtureOptions("counter");
    var uw = this.root.querySelector(".fp-underlay-wrap"), us = this.root.querySelector(".fp-underlay"), sibs = this.opts.siblings || [];
    if (sibs.length) {
      uw.classList.remove("d-none");
      var none = document.createElement("option"); none.value = ""; none.textContent = "none"; us.appendChild(none);
      sibs.forEach(function (p) { var o = document.createElement("option"); o.value = p.id; o.textContent = p.name + (p.level ? " · " + p.level : ""); us.appendChild(o); });
      try { this.underlayId = localStorage.getItem("fp-underlay-" + this.opts.id) || ""; } catch (_) { this.underlayId = ""; }
      if (this.underlayId && !sibs.some(function (p) { return String(p.id) === String(self.underlayId); })) this.underlayId = "";   // remembered level was deleted
      if (this.opts.below && sibs.some(function (p) { return String(p.id) === String(self.opts.below); })) {   // just created via "Add level above"
        this.underlayId = String(this.opts.below); try { localStorage.setItem("fp-underlay-" + this.opts.id, this.underlayId); } catch (_) {}
      }
      us.value = this.underlayId;
      this.root.querySelector(".fp-copy").classList.toggle("d-none", !this.underlayId);
      us.addEventListener("change", function () { self.underlayId = us.value; try { localStorage.setItem("fp-underlay-" + self.opts.id, us.value); } catch (_) {} self.root.querySelector(".fp-copy").classList.toggle("d-none", !us.value); self.render(); });
    }
    this.setTool("select");
  };

  P.bind = function () {
    var self = this, c = this.canvas;
    this.root.querySelectorAll("[data-tool]").forEach(function (b) { b.addEventListener("click", function () { self.setTool(b.dataset.tool); }); });
    this.root.querySelectorAll("[data-act]").forEach(function (b) { b.addEventListener("click", function () { self.act(b.dataset.act); }); });
    this.root.querySelector(".fp-import").addEventListener("change", function (e) { self.importJSON(e.target.files[0]); e.target.value = ""; });

    c.addEventListener("pointerdown", function (e) { self.onDown(e); });
    c.addEventListener("pointermove", function (e) { self.onMove(e); });
    c.addEventListener("pointerup", function (e) { self.onUp(e); });
    c.addEventListener("dblclick", function (e) {
      e.preventDefault();
      if (self.roomDraft) return self.closeRoomDraft();
      if (self.draft) return self.finishWall();
      if (self.tool !== "select") return;
      var q = self.pt(e), wp = self.toWorld(q.x, q.y), hit = self.hitTest(wp);
      if (hit && hit.type === "wall") { self.selSet = self.connectedWalls(hit.id); self.sel = hit; self.render(); self.updatePanel(); return; }
      if (hit && (hit.type === "label" || hit.type === "room")) { self.setSel(hit); self.updatePanel(); self.inlineEdit(hit.type, self.find(hit.type, hit.id)); }
      else if (!self.roomAt(wp)) self.roomFromArea(wp);
    });
    c.addEventListener("contextmenu", function (e) { e.preventDefault(); });
    c.addEventListener("pointercancel", function (e) { delete self.touches[e.pointerId]; if (self.drag && self.drag.touch) self.drag = null; self.render(); });
    c.addEventListener("wheel", function (e) { e.preventDefault(); var q = self.pt(e); self.zoomAt(Math.exp(-e.deltaY * 0.0015), q.x, q.y); }, { passive: false });
    c.addEventListener("pointerleave", function () { self.mouse = null; self.hover = null; self.render(); });

    document.addEventListener("keydown", function (e) { self.onKey(e); });
    document.addEventListener("keyup", function (e) { if (e.key === "Shift") { self.shift = false; self.render(); } if (e.key === " ") { self.space = false; self.canvas.style.cursor = self.tool === "select" ? "default" : "crosshair"; } });
    window.addEventListener("beforeunload", function (e) { if (self.dirty) { e.preventDefault(); e.returnValue = ""; } });
    if (window.ResizeObserver) new ResizeObserver(function () { self.resize(); }).observe(this.wrap);
    else window.addEventListener("resize", function () { self.resize(); });
  };

  P.resize = function () {
    var dpr = window.devicePixelRatio || 1, w = this.wrap.clientWidth, h = this.wrap.clientHeight;
    if (!w || !h) return;
    this.canvas.width = Math.round(w * dpr); this.canvas.height = Math.round(h * dpr);
    this.canvas.style.width = w + "px"; this.canvas.style.height = h + "px";
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    this.cw = w; this.ch = h;
    this.render();
  };

  // ---------------------------------------------------------------- view
  P.toScreen = function (x, y) { return { x: x * this.view.scale + this.view.x, y: y * this.view.scale + this.view.y }; };
  P.toWorld = function (sx, sy) { return { x: (sx - this.view.x) / this.view.scale, y: (sy - this.view.y) / this.view.scale }; };
  P.fit = function () {
    if (!this.cw) return;
    var pad = this.dimStrings ? 110 : 60, s = Math.min((this.cw - pad) / this.widthFt, (this.ch - pad) / this.depthFt);
    this.view.scale = clamp(s, 1, 200);
    this.view.x = (this.cw - this.widthFt * this.view.scale) / 2;
    this.view.y = (this.ch - this.depthFt * this.view.scale) / 2;
    this.render();
  };
  P.zoomAt = function (factor, sx, sy) {
    var before = this.toWorld(sx, sy), ns = clamp(this.view.scale * factor, 1, 200);
    this.view.scale = ns;
    this.view.x = sx - before.x * ns; this.view.y = sy - before.y * ns;
    this.render();
  };

  // ---------------------------------------------------------------- snapping
  P.snapVal = function (v) { var g = this.data.grid; return Math.round(v / g) * g; };
  P.snapPoint = function (p, excludeWallId) {
    var tol = 10 / this.view.scale, best = null, bd = tol;
    this.data.walls.concat(this.data.guides).forEach(function (w) {
      if (w.id === excludeWallId) return;
      [{ x: w.x1, y: w.y1 }, { x: w.x2, y: w.y2 }].forEach(function (e) { var d = Math.hypot(e.x - p.x, e.y - p.y); if (d < bd) { bd = d; best = e; } });
    });
    var u = this.underlay();
    if (u) u.walls.forEach(function (w) {
      [{ x: w.x1, y: w.y1 }, { x: w.x2, y: w.y2 }].forEach(function (e) { var d = Math.hypot(e.x - p.x, e.y - p.y); if (d < bd) { bd = d; best = e; } });
    });
    if (best) return { x: best.x, y: best.y, snapped: "endpoint" };
    return { x: this.snapVal(p.x), y: this.snapVal(p.y), snapped: "grid" };
  };
  // Constrain a segment end according to the Angles setting: 90° only, 45° steps, or any.
  // Shift always allows any angle. 45° diagonals keep both ends on the grid.
  P.ortho = function (from, to) {
    if (this.shift || this.angleMode === "free") return to;
    var dx = to.x - from.x, dy = to.y - from.y;
    if (this.angleMode === "45") {
      var k = Math.round(Math.atan2(dy, dx) / (Math.PI / 4));
      if (k % 2 !== 0) { var L = this.snapVal((Math.abs(dx) + Math.abs(dy)) / 2); return { x: from.x + Math.sign(dx) * L, y: from.y + Math.sign(dy) * L }; }
    }
    return Math.abs(dx) >= Math.abs(dy) ? { x: to.x, y: from.y } : { x: from.x, y: to.y };
  };

  // ---------------------------------------------------------------- lookup / hit testing
  P.find = function (type, id) { var list = this.listFor(type); for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]; return null; };
  P.listFor = function (type) { return type === "wall" ? this.data.walls : type === "room" ? this.data.rooms : type === "opening" ? this.data.openings : type === "fixture" ? this.data.fixtures : type === "guide" ? this.data.guides : type === "roof" ? this.data.roofs : this.data.labels; };
  P.underlay = function () {
    if (!this.underlayId) return null;
    var sib = (this.opts.siblings || []).filter(function (p) { return String(p.id) === String(this.underlayId); }, this)[0];
    return sib ? normalize(sib.data) : null;
  };
  P.wallOf = function (o) { return this.find("wall", o.wall); };
  P.selected = function () { return this.sel ? this.find(this.sel.type, this.sel.id) : null; };

  P.nearestWall = function (p, tolPx) {
    var tol = (tolPx || 8) / this.view.scale, best = null, bd = Infinity, self = this;
    this.data.walls.forEach(function (w) {
      var pr = project(p, w), t = (w.thickness || WALL_TYPES[w.type] || 0.5) / 2 + tol;
      if (pr.d <= t && pr.d < bd) { bd = pr.d; best = { wall: w, pr: pr }; }
    });
    return best;
  };

  P.hitTest = function (p) {
    var self = this, s = this.view.scale, i, r;
    // openings
    for (i = 0; i < this.data.openings.length; i++) {
      var o = this.data.openings[i], w = this.wallOf(o); if (!w) continue;
      var c = this.openingCenter(o, w), pr = project(p, w);
      if (Math.abs(pr.pos - c.pos) <= o.width / 2 + 2 / s && pr.d <= (w.thickness || 0.5) / 2 + 6 / s) return { type: "opening", id: o.id };
    }
    // labels
    for (i = this.data.labels.length - 1; i >= 0; i--) {
      var l = this.data.labels[i], box = this.labelBox(l);
      if (p.x >= box.x && p.x <= box.x + box.w && p.y >= box.y && p.y <= box.y + box.h) return { type: "label", id: l.id };
    }
    for (i = this.data.guides.length - 1; i >= 0; i--) {
      if (project(p, this.data.guides[i]).d <= 6 / s) return { type: "guide", id: this.data.guides[i].id };
    }
    var nw = this.nearestWall(p);
    if (nw) return { type: "wall", id: nw.wall.id };
    for (i = this.data.fixtures.length - 1; i >= 0; i--) {
      r = this.data.fixtures[i];
      if (p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h) return { type: "fixture", id: r.id };
    }
    for (i = this.data.rooms.length - 1; i >= 0; i--) {
      r = this.data.rooms[i];
      if (pointInPoly(p, roomPts(r))) return { type: "room", id: r.id };
    }
    for (i = this.data.roofs.length - 1; i >= 0; i--) {
      r = this.data.roofs[i];
      if (p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h) return { type: "roof", id: r.id };
    }
    return null;
  };

  P.handles = function () {  // screen-space handles for the selection
    var el = this.selected(); if (!el || this.multi()) return [];
    var self = this;
    if (this.sel.type === "wall" || this.sel.type === "guide") return [{ k: "p1", w: { x: el.x1, y: el.y1 } }, { k: "p2", w: { x: el.x2, y: el.y2 } }].map(function (h) { h.s = self.toScreen(h.w.x, h.w.y); return h; });
    if (this.sel.type === "room" && !roomIsRect(el)) return roomPts(el).map(function (p, i) { return { k: "v" + i, w: { x: p[0], y: p[1] }, s: self.toScreen(p[0], p[1]) }; });
    if (this.sel.type === "room" || this.sel.type === "fixture" || this.sel.type === "roof") return [["nw", el.x, el.y], ["ne", el.x + el.w, el.y], ["se", el.x + el.w, el.y + el.h], ["sw", el.x, el.y + el.h]].map(function (h) { return { k: h[0], w: { x: h[1], y: h[2] }, s: self.toScreen(h[1], h[2]) }; });
    return [];
  };
  P.hitHandle = function (sx, sy) {
    var hs = this.handles();
    for (var i = 0; i < hs.length; i++) if (Math.abs(hs[i].s.x - sx) <= HANDLE + 2 && Math.abs(hs[i].s.y - sy) <= HANDLE + 2) return hs[i];
    return null;
  };

  P.openingCenter = function (o, w) {
    var s = seg(w), pos = clamp(o.pos, o.width / 2, Math.max(o.width / 2, s.len - o.width / 2));
    return { pos: pos, x: w.x1 + s.ux * pos, y: w.y1 + s.uy * pos, s: s };
  };
  P.labelBox = function (l) {
    var px = this.labelPx(l), ctx = this.ctx; ctx.font = px + "px system-ui, sans-serif";
    var wpx = ctx.measureText(l.text || " ").width, s = this.view.scale;
    return { x: l.x - (wpx / 2 + 4) / s, y: l.y - (px / 2 + 3) / s, w: (wpx + 8) / s, h: (px + 6) / s };
  };
  P.labelPx = function (l) { return clamp((l.size || 1) * this.view.scale, 9, 72); };

  // ---------------------------------------------------------------- history / mutation
  P.commit = function (fn, keepMulti) {
    var before = JSON.stringify(this.data), keep = keepMulti ? this.selSet.slice() : null;
    fn.call(this);
    if (keep) { this.selSet = keep; this.sel = keep[0] || null; }
    var after = JSON.stringify(this.data);
    if (after !== before) { this.history.push(before); if (this.history.length > 100) this.history.shift(); this.future = []; this.markDirty(); }
    this.render(); this.updatePanel();
  };
  P.undo = function () { if (!this.history.length) return; this.future.push(JSON.stringify(this.data)); this.data = normalize(JSON.parse(this.history.pop())); this.setSel(null); this.markDirty(); this.render(); this.updatePanel(); };
  P.redo = function () { if (!this.future.length) return; this.history.push(JSON.stringify(this.data)); this.data = normalize(JSON.parse(this.future.pop())); this.setSel(null); this.markDirty(); this.render(); this.updatePanel(); };
  P.markDirty = function () {
    this.dirty = true; this.setStatus("Unsaved changes");
    var self = this; clearTimeout(this.autosave); this.autosave = setTimeout(function () { if (self.dirty) self.save(true); }, 8000);
  };
  P.setStatus = function (t) { this.statusEl.textContent = t; };
  P.hint = function (t) { this.hintEl.textContent = t || ""; };

  P.deleteSelected = function () {
    var items = this.selSet.slice(); if (!items.length) return;
    this.commit(function () {
      var self = this;
      items.forEach(function (sel) {
        if (sel.type === "wall") { self.data.walls = self.data.walls.filter(function (w) { return w.id !== sel.id; }); self.data.openings = self.data.openings.filter(function (o) { return o.wall !== sel.id; }); }
        else { var list = self.listFor(sel.type), i = list.findIndex(function (e) { return e.id === sel.id; }); if (i >= 0) list.splice(i, 1); }
      });
      self.setSel(null);
    });
  };
  P.nudge = function (dx, dy) {
    var el = this.selected(); if (!el) return;
    if (this.multi()) { var items = this.selSet, self = this; return this.commit(function () { items.forEach(function (x) { var e = self.find(x.type, x.id); if (e && x.type !== "opening") self.translateEl(x.type, e, dx, dy); }); }, true); }
    var type = this.sel.type;
    this.commit(function () {
      if (type === "wall" || type === "guide") { el.x1 += dx; el.x2 += dx; el.y1 += dy; el.y2 += dy; }
      else if (type === "opening") { var w = this.wallOf(el); if (w) { var s = seg(w); el.pos = clamp(el.pos + dx * s.ux + dy * s.uy, el.width / 2, s.len - el.width / 2); } }
      else if (type === "room") translateRoom(el, dx, dy);
      else { el.x += dx; el.y += dy; }
    });
  };

  // ---------------------------------------------------------------- tools
  P.setTool = function (t) {
    this.tool = t; this.draft = null; this.roomDraft = null; this.hover = null;
    this.root.querySelectorAll("[data-tool]").forEach(function (b) { b.classList.toggle("active", b.dataset.tool === t); });
    this.canvas.style.cursor = t === "select" ? "default" : "crosshair";
    this.hint({ select: "", wall: "Click to start a wall, click at each corner, Esc or Enter to finish. Use the Angles dropdown (or hold Shift) for diagonals.", room: "Drag a rectangle, or click corner by corner for any shape (click the first point again to close). Tip: double-click inside walls in Select to make a room automatically.", door: "Click a wall to place a door.", window: "Click a wall to place a window.", label: "Click to place text, then type. Double-click any label later to change it.", fixture: "Pick a fixture in the dropdown, then click to place it. Rotate it from the side panel.", line: "Click to start a guide line, click to end it (keeps going; Esc or Enter to stop). Shows its length; not part of the building.", roof: "Drag a rectangle over the area one roof section covers (it can extend past the walls). Use several for L-shapes or porches. Style, pitch and overhang are in the side panel." }[t]);
    this.kindSel.classList.toggle("d-none", t !== "fixture");
    this.doorKindSel.classList.toggle("d-none", t !== "door");
    this.render();
  };
  P.act = function (a) {
    switch (a) {
      case "undo": return this.undo();
      case "redo": return this.redo();
      case "zoomIn": return this.zoomAt(1.25, this.cw / 2, this.ch / 2);
      case "zoomOut": return this.zoomAt(0.8, this.cw / 2, this.ch / 2);
      case "fit": return this.fit();
      case "grid": this.showGrid = !this.showGrid; return this.render();
      case "dims": this.dimStrings = !this.dimStrings; this.root.querySelector('[data-act="dims"]').classList.toggle("active", this.dimStrings); return this.render();
      case "pdf": return this.exportPDF();
      case "copyUnderlay": return this.copyUnderlay();
      case "save": return this.save(false);
      case "png": return this.exportPNG();
      case "json": return download((this.opts.name || "floor-plan").replace(/[^\w-]+/g, "_") + ".json", "data:application/json;charset=utf-8," + encodeURIComponent(JSON.stringify(this.data, null, 2)));
    }
  };

  P.finishWall = function () { this.draft = null; if (this.roomDraft) { this.roomDraft = null; this.setTool(this.tool); } this.render(); };
  P.closeRoomDraft = function () {
    var pts = this.roomDraft && this.roomDraft.pts; this.roomDraft = null; this.setTool("room");
    if (!pts || pts.length < 3) return this.render();
    var id = uid(), n = this.data.rooms.length + 1;
    this.commit(function () { this.data.rooms.push(roomSync({ id: id, name: "Room " + n, pts: pts })); this.setSel({ type: "room", id: id }); });
    this.focusProp("name");
  };

  // canvas-relative pointer position (clientX-based; offsetX is unreliable for synthetic events)
  P.pt = function (e) { var r = this.canvas.getBoundingClientRect(); return { x: e.clientX - r.left, y: e.clientY - r.top }; };
  P.capture = function (e) { try { this.canvas.setPointerCapture(e.pointerId); } catch (_) { /* synthetic events have no active pointer */ } };
  P.onDown = function (e) {
    var m = this.pt(e);
    var p = this.toWorld(m.x, m.y), self = this;
    if (e.pointerType === "touch") {
      this.touches[e.pointerId] = p;
      var ids = Object.keys(this.touches);
      if (ids.length === 2) {   // two-finger hold + drag = box select (from the midpoint)
        var t1 = this.touches[ids[0]], t2 = this.touches[ids[1]], mid = { x: (t1.x + t2.x) / 2, y: (t1.y + t2.y) / 2 };
        this.drag = { kind: "marquee", start: mid, cur: mid, add: false, keep: [], touch: true, moved: false }; this.capture(e); this.render(); return;
      }
    }
    if (e.button === 2) {       // right-button drag = box select; a plain right-click still finishes drawing / returns to Select
      this.capture(e); this.downAt = { x: m.x, y: m.y };
      this.drag = { kind: "marquee", start: p, cur: p, add: e.shiftKey, keep: e.shiftKey ? this.selSet.slice() : [], right: true }; return;
    }
    if (e.button === 1 || (e.button === 0 && (e.altKey || this.space))) { this.drag = { kind: "pan", sx: m.x, sy: m.y, vx: this.view.x, vy: this.view.y }; this.capture(e); return; }
    if (e.button !== 0) return;
    this.capture(e);
    this.downAt = { x: m.x, y: m.y };

    if (this.tool === "select") {
      var h = this.hitHandle(m.x, m.y);
      if (h) { this.drag = { kind: "handle", h: h, el: this.selected(), before: JSON.stringify(this.data), orig: JSON.parse(JSON.stringify(this.selected())) }; return; }
      var hit = this.hitTest(p);
      if (hit && e.shiftKey) { this.toggleSel(hit); this.render(); this.updatePanel(); return; }
      if (hit && this.multi() && this.isSelected(hit.type, hit.id)) {
        var self2 = this, items = this.selSet.map(function (x) { var el2 = self2.find(x.type, x.id); return el2 ? { type: x.type, el: el2, orig: JSON.parse(JSON.stringify(el2)) } : null; }).filter(Boolean);
        this.drag = { kind: "moveMulti", items: items, start: p, before: JSON.stringify(this.data), moved: false };
        return;
      }
      this.setSel(hit);
      if (hit) {
        var el = this.selected();
        this.drag = { kind: "move", el: el, type: hit.type, start: p, orig: JSON.parse(JSON.stringify(el)), before: JSON.stringify(this.data), moved: false };
      } else if (e.shiftKey) {
        this.drag = { kind: "marquee", start: p, cur: p, add: true, keep: this.selSet.slice() };
      } else {
        this.drag = { kind: "pan", sx: m.x, sy: m.y, vx: this.view.x, vy: this.view.y };   // drag empty space to move around
      }
      this.render(); this.updatePanel();
      return;
    }
    if (this.tool === "room") {
      if (this.roomDraft) return;           // clicking out a polygon; handled on pointerup
      var sp = this.snapPoint(p);
      this.drag = { kind: "room", start: sp, cur: sp };
      return;
    }
    if (this.tool === "roof") { var rsp = this.snapPoint(p); this.drag = { kind: "roof", start: rsp, cur: rsp }; return; }
    // wall / door / window / label act on click (pointerup)
  };

  P.onMove = function (e) {
    var m = this.pt(e);
    var p = this.toWorld(m.x, m.y);
    this.mouse = p; this.shift = e.shiftKey;
    var d = this.drag;
    if (d) {
      if (d.kind === "pan") { this.view.x = d.vx + m.x - d.sx; this.view.y = d.vy + m.y - d.sy; return this.render(); }
      if (d.kind === "marquee") {
        if (d.touch) { this.touches[e.pointerId] = p; var tk = Object.keys(this.touches); if (tk.length >= 2) { var a1 = this.touches[tk[0]], a2 = this.touches[tk[1]]; d.cur = { x: (a1.x + a2.x) / 2, y: (a1.y + a2.y) / 2 }; } }
        else d.cur = p;
        if (Math.hypot(d.cur.x - d.start.x, d.cur.y - d.start.y) * this.view.scale > 4) d.moved = true;
        return this.render();
      }
      if (d.kind === "moveMulti") return this.dragMulti(d, p);
      if (d.kind === "room" || d.kind === "roof") { d.cur = this.snapPoint(p); return this.render(); }
      if (d.kind === "move") return this.dragMove(d, p);
      if (d.kind === "handle") return this.dragHandle(d, p);
    }
    if (this.tool === "room" && this.roomDraft) { var rl = this.roomDraft.pts[this.roomDraft.pts.length - 1]; this.roomDraft.cur = this.ortho({ x: rl[0], y: rl[1] }, this.snapPoint(p)); }
    if ((this.tool === "wall" || this.tool === "line") && this.draft) { var sp = this.snapPoint(p); this.draft.cur = this.ortho(this.draft.start, sp); this.draft.cur.snapped = sp.snapped; }
    if (this.tool === "door" || this.tool === "window") { var nw = this.nearestWall(p, 12); this.hover = nw ? nw.wall.id : null; }
    this.hoverRoom = this.draft ? null : this.roomAt(p);
    this.hoverArea = (!this.hoverRoom && !this.draft && this.tool === "select") ? this.enclosedAt(p) : null;
    this.render();
  };

  // Area enclosed by walls around point p (no Room rectangle needed). Walls are rasterised
  // onto a 3" grid and the space around p is flood-filled; a fill that escapes to the edge
  // of the drawing area is open, not a room. Returns { x, y, w, h, area } in ft or null.
  P.enclosedAt = function (p) {
    var cell = 0.25, pad = 1, W = this.widthFt, H = this.depthFt, nx = Math.ceil((W + 2 * pad) / cell), ny = Math.ceil((H + 2 * pad) / cell), ox = -pad, oy = -pad;
    var key = JSON.stringify(this.data.walls) + "|" + W + "x" + H;
    if (this._rasterKey !== key) {
      var ras = new Uint8Array(nx * ny);
      this.data.walls.forEach(function (w) {
        var t = Math.max(w.thickness || WALL_TYPES[w.type] || 0.5, 0.375) / 2 + cell * 0.36;
        var x0 = Math.max(0, Math.floor((Math.min(w.x1, w.x2) - t - ox) / cell)), x1 = Math.min(nx - 1, Math.ceil((Math.max(w.x1, w.x2) + t - ox) / cell));
        var y0 = Math.max(0, Math.floor((Math.min(w.y1, w.y2) - t - oy) / cell)), y1 = Math.min(ny - 1, Math.ceil((Math.max(w.y1, w.y2) + t - oy) / cell));
        for (var y = y0; y <= y1; y++) for (var x = x0; x <= x1; x++) {
          if (project({ x: ox + (x + 0.5) * cell, y: oy + (y + 0.5) * cell }, w).d <= t) ras[y * nx + x] = 1;
        }
      });
      this._raster = ras; this._rasterKey = key; this._region = null;
    }
    var cx = Math.floor((p.x - ox) / cell), cy = Math.floor((p.y - oy) / cell);
    if (cx < 0 || cy < 0 || cx >= nx || cy >= ny) return null;
    var start = cy * nx + cx, ras2 = this._raster;
    if (ras2[start]) return null;
    if (this._region && this._region.seen[start]) return this._region.open ? null : this._region;
    var seen = new Uint8Array(nx * ny), stack = [start], count = 0, minx = cx, maxx = cx, miny = cy, maxy = cy, open = false;
    while (stack.length) {
      var i = stack.pop(); if (seen[i]) continue; seen[i] = 1; if (ras2[i]) continue;
      var x = i % nx, y = (i - x) / nx;
      if (x === 0 || y === 0 || x === nx - 1 || y === ny - 1) open = true;
      count++; if (x < minx) minx = x; if (x > maxx) maxx = x; if (y < miny) miny = y; if (y > maxy) maxy = y;
      if (x > 0) stack.push(i - 1); if (x < nx - 1) stack.push(i + 1); if (y > 0) stack.push(i - nx); if (y < ny - 1) stack.push(i + nx);
    }
    var fill = new Uint8Array(nx * ny); for (var q = 0; q < seen.length; q++) if (seen[q] && !ras2[q]) fill[q] = 1;
    var region = { seen: seen, fill: fill, nx: nx, ny: ny, cell: cell, ox: ox, oy: oy, open: open, area: count * cell * cell, x: ox + minx * cell, y: oy + miny * cell, w: (maxx - minx + 1) * cell, h: (maxy - miny + 1) * cell };
    this._region = region;
    return open ? null : region;
  };

  // In-place text editor for a label's text or a room's name (double-click, or a freshly placed label).
  P.inlineEdit = function (type, el) {
    if (this.inline) this.inline.remove();
    var self = this, isRoom = type === "room", rcn = isRoom ? roomCentroid(el) : null, at = isRoom ? this.toScreen(rcn.x, rcn.y) : this.toScreen(el.x, el.y);
    var inp = document.createElement("input"); inp.className = "form-control form-control-sm fp-inline"; inp.value = isRoom ? (el.name || "") : (el.text || "");
    inp.style.left = clamp(at.x - 90, 4, this.cw - 184) + "px"; inp.style.top = clamp(at.y - 16, 4, this.ch - 36) + "px";
    this.wrap.appendChild(inp); this.inline = inp; inp.focus(); inp.select();
    var done = function (save) {
      if (self.inline !== inp) return;
      var v = inp.value; self.inline = null; inp.remove();
      if (save) self.commit(function () { if (isRoom) el.name = v; else el.text = v; }); else self.render();
    };
    inp.addEventListener("keydown", function (e) { e.stopPropagation(); if (e.key === "Enter") done(true); else if (e.key === "Escape") done(false); });
    inp.addEventListener("blur", function () { done(true); });
  };

  // Double-click inside an enclosed area (Select tool) turns it into a Room.
  P.roomFromArea = function (p) {
    var a = this.enclosedAt(p); if (!a) return false;
    var pts = this.regionPolygon(a), id = uid(), n = this.data.rooms.length + 1;
    this.commit(function () { this.data.rooms.push(roomSync({ id: id, name: "Room " + n, pts: pts })); this.setSel({ type: "room", id: id }); });
    this.hoverArea = null; this.focusProp("name");
    return true;
  };
  // Outer boundary of a filled raster region → simplified polygon in ft (diagonal walls become diagonal edges).
  P.regionPolygon = function (a) {
    var nx = a.nx, ny = a.ny, f = a.fill, edges = {}, key = function (x, y) { return x + "," + y; }, isF = function (x, y) { return x >= 0 && y >= 0 && x < nx && y < ny && f[y * nx + x]; };
    for (var y = 0; y < ny; y++) for (var x = 0; x < nx; x++) {
      if (!f[y * nx + x]) continue;
      if (!isF(x, y - 1)) edges[key(x, y)] = [x + 1, y];
      if (!isF(x + 1, y)) edges[key(x + 1, y)] = [x + 1, y + 1];
      if (!isF(x, y + 1)) edges[key(x + 1, y + 1)] = [x, y + 1];
      if (!isF(x - 1, y)) edges[key(x, y + 1)] = [x, y];
    }
    var best = null, bestArea = 0, used = {};
    Object.keys(edges).forEach(function (start) {
      if (used[start]) return;
      var loop = [], cur = start, guard = 0;
      while (cur && !used[cur] && guard++ < 200000) { used[cur] = true; var pt = cur.split(",").map(Number); loop.push(pt); var nxt = edges[cur]; cur = nxt ? key(nxt[0], nxt[1]) : null; }
      var ar = 0; for (var i = 0; i < loop.length; i++) { var j = (i + 1) % loop.length; ar += loop[i][0] * loop[j][1] - loop[j][0] * loop[i][1]; }
      if (Math.abs(ar) > bestArea) { bestArea = Math.abs(ar); best = loop; }
    });
    if (!best) return rectPts(a);
    // drop collinear points, then straighten the 3" staircase along diagonal walls
    var pts = best.filter(function (p, i) { var q = best[(i + best.length - 1) % best.length], r = best[(i + 1) % best.length]; return !((q[0] === p[0] && p[0] === r[0]) || (q[1] === p[1] && p[1] === r[1])); });
    pts = simplify(pts.map(function (p) { return [a.ox + p[0] * a.cell, a.oy + p[1] * a.cell]; }), a.cell * 1.2);   // to feet first; tolerance is in feet
    return pts.length >= 3 ? pts : rectPts(a);
  };
  P.roomAt = function (p) {
    for (var i = this.data.rooms.length - 1; i >= 0; i--) { var r = this.data.rooms[i]; if (pointInPoly(p, roomPts(r))) return r.id; }
    return null;
  };

  P.dragMove = function (d, p) {
    var raw = { x: p.x - d.start.x, y: p.y - d.start.y }, o = d.orig, el = d.el;
    if (Math.hypot(raw.x, raw.y) * this.view.scale < 3 && !d.moved) return;
    d.moved = true;
    if (d.type === "wall" || d.type === "guide") {
      var a = this.snapPoint({ x: o.x1 + raw.x, y: o.y1 + raw.y }, el.id), dx = a.x - o.x1, dy = a.y - o.y1;
      el.x1 = o.x1 + dx; el.y1 = o.y1 + dy; el.x2 = o.x2 + dx; el.y2 = o.y2 + dy;
    } else if (d.type === "room") {
      var nxr = this.snapVal(o.x + raw.x), nyr = this.snapVal(o.y + raw.y); el.pts = o.pts; translateRoom(el, nxr - o.x, nyr - o.y);
    } else if (d.type === "label" || d.type === "fixture" || d.type === "roof") {
      el.x = this.snapVal(o.x + raw.x); el.y = this.snapVal(o.y + raw.y);
    } else if (d.type === "opening") {
      var w = this.wallOf(el); if (w) { var pr = project(p, w); el.pos = this.snapVal(clamp(pr.pos, el.width / 2, pr.len - el.width / 2)); }
    }
    this.render(); this.updatePanel(true);
  };

  P.dragMulti = function (d, p) {
    var raw = { x: p.x - d.start.x, y: p.y - d.start.y };
    if (Math.hypot(raw.x, raw.y) * this.view.scale < 3 && !d.moved) return;
    d.moved = true;
    var a = this.anchorOf(d.items[0].type, d.items[0].orig), dx = this.snapVal(a.x + raw.x) - a.x, dy = this.snapVal(a.y + raw.y) - a.y, self = this;
    d.items.forEach(function (it) {
      Object.keys(it.orig).forEach(function (k) { it.el[k] = JSON.parse(JSON.stringify(it.orig[k])); });   // reset, then translate
      self.translateEl(it.type, it.el, dx, dy);
    });
    this.render(); this.updatePanel(true);
  };

  P.dragHandle = function (d, p) {
    var el = d.el, o = d.orig, k = d.h.k;
    if (this.sel.type === "wall") {
      var sp = this.snapPoint(p, el.id), fixed = k === "p1" ? { x: o.x2, y: o.y2 } : { x: o.x1, y: o.y1 };
      var np = this.shift ? sp : this.ortho(fixed, sp), oldPt = k === "p1" ? { x: o.x1, y: o.y1 } : { x: o.x2, y: o.y2 };
      // move every wall endpoint that shared this corner
      this.data.walls.forEach(function (w) {
        if (Math.abs(w.x1 - oldPt.x) < 1e-6 && Math.abs(w.y1 - oldPt.y) < 1e-6) { w.x1 = np.x; w.y1 = np.y; }
        if (Math.abs(w.x2 - oldPt.x) < 1e-6 && Math.abs(w.y2 - oldPt.y) < 1e-6) { w.x2 = np.x; w.y2 = np.y; }
      });
      if (k === "p1") { el.x1 = np.x; el.y1 = np.y; } else { el.x2 = np.x; el.y2 = np.y; }
    } else if (this.sel.type === "guide") {
      var gp = this.snapPoint(p, el.id), gfixed = k === "p1" ? { x: o.x2, y: o.y2 } : { x: o.x1, y: o.y1 }, gnp = this.shift ? gp : this.ortho(gfixed, gp);
      if (k === "p1") { el.x1 = gnp.x; el.y1 = gnp.y; } else { el.x2 = gnp.x; el.y2 = gnp.y; }
    } else if (this.sel.type === "room" && k.charAt(0) === "v") {
      var vi = +k.slice(1), vp = this.snapPoint(p); el.pts = roomPts(el).slice(); el.pts[vi] = [vp.x, vp.y]; roomSync(el);
    } else if (this.sel.type === "room" || this.sel.type === "fixture" || this.sel.type === "roof") {
      var x1 = o.x, y1 = o.y, x2 = o.x + o.w, y2 = o.y + o.h, sx = this.snapVal(p.x), sy = this.snapVal(p.y);
      if (k.indexOf("w") >= 0) x1 = sx; if (k.indexOf("e") >= 0) x2 = sx; if (k.indexOf("n") >= 0) y1 = sy; if (k.indexOf("s") >= 0) y2 = sy;
      el.x = Math.min(x1, x2); el.y = Math.min(y1, y2); el.w = Math.max(this.data.grid, Math.abs(x2 - x1)); el.h = Math.max(this.data.grid, Math.abs(y2 - y1));
      if (this.sel.type === "room") el.pts = rectPts(el);
    }
    this.render(); this.updatePanel(true);
  };

  P.onUp = function (e) {
    var m = this.pt(e);
    var p = this.toWorld(m.x, m.y), d = this.drag, self = this;
    var isClick = this.downAt && Math.hypot(m.x - this.downAt.x, m.y - this.downAt.y) < 4;
    this.drag = null;
    if (e.pointerType === "touch") {
      delete this.touches[e.pointerId];
      if (d && d.kind === "marquee" && d.touch) { if (Object.keys(this.touches).length >= 1) { this.drag = d; return; } }   // wait for both fingers to lift
    }
    if (d && d.kind === "marquee") {
      var mx0 = Math.min(d.start.x, d.cur.x), mx1 = Math.max(d.start.x, d.cur.x), my0 = Math.min(d.start.y, d.cur.y), my1 = Math.max(d.start.y, d.cur.y), inside = function (x, y) { return x >= mx0 && x <= mx1 && y >= my0 && y <= my1; };
      var moved = d.touch ? d.moved : !isClick;
      if (!moved && d.right) { if (this.draft || this.roomDraft) this.finishWall(); else this.setTool("select"); return; }   // plain right-click
      if (moved) {
        var picked = [];
        this.data.walls.forEach(function (w) { if (inside(w.x1, w.y1) && inside(w.x2, w.y2)) picked.push({ type: "wall", id: w.id }); });
        this.data.guides.forEach(function (g) { if (inside(g.x1, g.y1) && inside(g.x2, g.y2)) picked.push({ type: "guide", id: g.id }); });
        this.data.rooms.forEach(function (r) { if (inside(r.x, r.y) && inside(r.x + r.w, r.y + r.h)) picked.push({ type: "room", id: r.id }); });
        this.data.fixtures.forEach(function (f) { if (inside(f.x, f.y) && inside(f.x + f.w, f.y + f.h)) picked.push({ type: "fixture", id: f.id }); });
        this.data.roofs.forEach(function (f) { if (inside(f.x, f.y) && inside(f.x + f.w, f.y + f.h)) picked.push({ type: "roof", id: f.id }); });
        this.data.labels.forEach(function (l) { if (inside(l.x, l.y)) picked.push({ type: "label", id: l.id }); });
        var set = d.keep.slice(); picked.forEach(function (x) { if (!set.some(function (y) { return y.type === x.type && y.id === x.id; })) set.push(x); });
        this.selSet = set; this.sel = set.length ? set[0] : null;
      }
      this.render(); this.updatePanel(); return;
    }
    if (d && (d.kind === "move" || d.kind === "handle" || d.kind === "moveMulti")) {
      var after = JSON.stringify(this.data);
      if (after !== d.before) { this.history.push(d.before); this.future = []; this.markDirty(); }
      this.render(); this.updatePanel(); return;
    }
    if (d && d.kind === "roof") {
      var ra = d.start, rb = d.cur, rx = Math.min(ra.x, rb.x), ry = Math.min(ra.y, rb.y), rw = Math.abs(rb.x - ra.x), rh = Math.abs(rb.y - ra.y);
      if (rw >= 2 && rh >= 2) {
        var rid = uid(), def = Object.assign({}, ROOF_DEF, this.lastRoof || {});
        this.commit(function () { this.data.roofs.push(Object.assign({ id: rid, x: rx, y: ry, w: rw, h: rh }, def)); this.setSel({ type: "roof", id: rid }); });
      } else this.render();
      return;
    }
    if (this.tool === "room" && this.roomDraft && isClick && e.button === 0) {
      var rp0 = this.snapPoint(p), first0 = this.roomDraft.pts[0], last0 = this.roomDraft.pts[this.roomDraft.pts.length - 1], np0 = this.ortho({ x: last0[0], y: last0[1] }, rp0);
      if (this.roomDraft.pts.length >= 3 && Math.hypot(np0.x - first0[0], np0.y - first0[1]) * this.view.scale < 10) return this.closeRoomDraft();
      if (Math.hypot(np0.x - last0[0], np0.y - last0[1]) >= this.data.grid / 2) this.roomDraft.pts.push([np0.x, np0.y]);
      return this.render();
    }
    if (d && d.kind === "room") {
      var a = d.start, b = d.cur, x = Math.min(a.x, b.x), y = Math.min(a.y, b.y), w = Math.abs(b.x - a.x), h = Math.abs(b.y - a.y);
      if (w >= this.data.grid && h >= this.data.grid) {
        var id = uid(), n = this.data.rooms.length + 1;
        this.commit(function () { this.data.rooms.push(roomSync({ id: id, name: "Room " + n, pts: rectPts({ x: x, y: y, w: w, h: h }) })); this.setSel({ type: "room", id: id }); });
        this.focusProp("name");
        return;
      }
      if (!isClick) return this.render();
      // a plain click starts (or extends) a polygon room
      var rp = this.snapPoint(p);
      if (!this.roomDraft) { this.roomDraft = { pts: [[rp.x, rp.y]], cur: rp }; this.hint("Click each corner of the room. Click the first point again, press Enter, or double-click to close. Esc cancels."); return this.render(); }
      var first = this.roomDraft.pts[0], last = this.roomDraft.pts[this.roomDraft.pts.length - 1], np = this.ortho({ x: last[0], y: last[1] }, rp);
      if (this.roomDraft.pts.length >= 3 && Math.hypot(np.x - first[0], np.y - first[1]) * this.view.scale < 10) return this.closeRoomDraft();
      if (Math.hypot(np.x - last[0], np.y - last[1]) >= this.data.grid / 2) this.roomDraft.pts.push([np.x, np.y]);
      return this.render();
    }
    if (d && d.kind === "pan") return;
    if (!isClick || e.button !== 0) return;

    if (this.tool === "wall" || this.tool === "line") {
      var sp = this.snapPoint(p), isLine = this.tool === "line";
      if (!this.draft) { this.draft = { start: sp, cur: sp }; return this.render(); }
      var end = this.ortho(this.draft.start, sp), st = this.draft.start;
      if (Math.hypot(end.x - st.x, end.y - st.y) >= this.data.grid / 2) {
        var type = this.lastWallType || "exterior", wid = uid();
        this.commit(function () {
          if (isLine) this.data.guides.push({ id: wid, x1: st.x, y1: st.y, x2: end.x, y2: end.y, label: "" });
          else this.data.walls.push({ id: wid, x1: st.x, y1: st.y, x2: end.x, y2: end.y, type: type, thickness: WALL_TYPES[type] });
        });
        this.draft = { start: end, cur: end };
      }
      return this.render();
    }
    if (this.tool === "door" || this.tool === "window") {
      var nw = this.nearestWall(p, 12); if (!nw) return;
      var otype = this.tool, oid = uid(), op = { id: oid, type: otype, wall: nw.wall.id, swing: 1, hinge: 0 };
      if (otype === "door") { var dk = this.doorKindSel.value === "auto" ? doorKind({}, nw.wall) : this.doorKindSel.value; op.kind = dk; op.width = DOOR_KINDS[dk].w; op.height = DOOR_KINDS[dk].h; }
      else { op.width = WINDOW_DEF.w; op.sill = WINDOW_DEF.sill; op.height = WINDOW_DEF.h; }
      op.pos = this.snapVal(clamp(nw.pr.pos, op.width / 2, Math.max(op.width / 2, nw.pr.len - op.width / 2)));
      this.commit(function () { this.data.openings.push(op); this.setSel({ type: "opening", id: oid }); });
      return;
    }
    if (this.tool === "fixture") {
      var kind = this.kindSel.value || "box", spec = FIXTURES[kind], fp = this.snapPoint(p), fid = uid();
      this.commit(function () { this.data.fixtures.push({ id: fid, kind: kind, x: fp.x, y: fp.y, w: spec.w, h: spec.h, rot: 0, dir: kind === "stairs" ? "up" : undefined, label: kind === "stairs" ? "UP" : "" }); this.setSel({ type: "fixture", id: fid }); });
      return;
    }
    if (this.tool === "label") {
      var sp2 = this.snapPoint(p), lid = uid();
      this.commit(function () { this.data.labels.push({ id: lid, text: "Label", x: sp2.x, y: sp2.y, size: 1 }); this.setSel({ type: "label", id: lid }); });
      this.inlineEdit("label", this.find("label", lid));
    }
  };

  P.onKey = function (e) {
    var tag = (e.target.tagName || "").toLowerCase();
    if (tag === "input" || tag === "textarea" || tag === "select") { if (e.key === "Escape") e.target.blur(); return; }
    var mod = e.ctrlKey || e.metaKey;
    if (e.key === "Shift") { this.shift = true; this.render(); }
    if (mod && e.key.toLowerCase() === "z") { e.preventDefault(); return e.shiftKey ? this.redo() : this.undo(); }
    if (mod && e.key.toLowerCase() === "y") { e.preventDefault(); return this.redo(); }
    if (mod && e.key.toLowerCase() === "s") { e.preventDefault(); return this.save(false); }
    if (mod && e.key.toLowerCase() === "a") { e.preventDefault(); var all = []; ["wall", "guide", "room", "fixture", "roof", "label"].forEach(function (t) { this.listFor(t).forEach(function (x) { all.push({ type: t, id: x.id }); }); }, this); this.selSet = all; this.sel = all[0] || null; this.setTool("select"); this.updatePanel(); return; }
    if (mod) return;
    var g = this.data.grid;
    switch (e.key) {
      case "Escape": if (this.draft || this.roomDraft) this.finishWall(); else if (this.tool !== "select") this.setTool("select"); else { this.setSel(null); this.render(); this.updatePanel(); } break;
      case " ": e.preventDefault(); this.space = true; this.canvas.style.cursor = "grab"; break;
      case "Enter": if (this.roomDraft) this.closeRoomDraft(); else if (this.draft) this.finishWall(); break;
      case "Delete": case "Backspace": e.preventDefault(); this.deleteSelected(); break;
      case "ArrowLeft": e.preventDefault(); this.nudge(-g, 0); break;
      case "ArrowRight": e.preventDefault(); this.nudge(g, 0); break;
      case "ArrowUp": e.preventDefault(); this.nudge(0, -g); break;
      case "ArrowDown": e.preventDefault(); this.nudge(0, g); break;
      case "v": case "V": this.setTool("select"); break;
      case "w": case "W": this.setTool("wall"); break;
      case "r": case "R": this.setTool("room"); break;
      case "d": case "D": this.setTool("door"); break;
      case "n": case "N": this.setTool("window"); break;
      case "t": case "T": this.setTool("label"); break;
      case "x": case "X": this.setTool("fixture"); break;
      case "l": case "L": this.setTool("line"); break;
      case "o": case "O": this.setTool("roof"); break;
      case "g": case "G": this.act("grid"); break;
      case "f": case "F": this.fit(); break;
      case "+": case "=": this.act("zoomIn"); break;
      case "-": case "_": this.act("zoomOut"); break;
    }
  };

  // ---------------------------------------------------------------- side panel
  P.focusProp = function (name) { var i = this.props.querySelector('[data-prop="' + name + '"]'); if (i) { i.focus(); i.select && i.select(); } };

  P.updatePanel = function (light) {
    var el = this.selected(), self = this, html = "";
    if (this.multi()) {
      var counts = {}; this.selSet.forEach(function (x) { counts[x.type] = (counts[x.type] || 0) + 1; });
      var parts = Object.keys(counts).map(function (t) { return counts[t] + " " + (t === "guide" ? "line" : t) + (counts[t] === 1 ? "" : "s"); });
      html = '<h6>' + this.selSet.length + ' items selected</h6><div class="small text-muted mb-2">' + parts.join(", ") + '. Drag any of them to move all; arrow keys nudge; Delete removes all.</div>' +
        (counts.wall ? '<div class="fp-field"><label>Set wall type</label><select class="form-select form-select-sm" data-multi="walltype"><option value="">— keep as is —</option><option value="exterior">Exterior (6")</option><option value="interior">Interior (4½")</option></select></div>' : "") +
        '<button class="btn btn-outline-danger btn-sm mt-1" data-btn="deleteAll">Delete all</button>';
      this.props.innerHTML = html; this.propsFor = "multi";
      var wt = this.props.querySelector('[data-multi="walltype"]');
      if (wt) wt.addEventListener("change", function () { var v = wt.value; if (!v) return; self.commit(function () { self.selSet.forEach(function (x) { var w = x.type === "wall" && self.find("wall", x.id); if (w) { w.type = v; w.thickness = WALL_TYPES[v]; } }); }, true); });
      this.props.querySelector('[data-btn="deleteAll"]').addEventListener("click", function () { self.deleteSelected(); });
      this.renderSummary(); return;
    }
    if (light && this.propsFor === (el && el.id)) { this.refreshPropValues(el); this.renderSummary(); return; }
    this.propsFor = el && el.id;
    var f = function (label, name, value, attrs) { return '<div class="fp-field"><label>' + label + '</label><input class="form-control form-control-sm" data-prop="' + name + '" value="' + esc(value) + '" ' + (attrs || "") + '></div>'; };
    if (!el) {
      html = '<h6>Plan</h6><div class="small text-muted mb-2">' + esc(this.opts.name || "") + ' · ' + ftIn(this.widthFt) + ' × ' + ftIn(this.depthFt) + ' drawing area</div>' +
        '<div class="small">Nothing selected. Pick a tool above, or click an element to edit it here. Double-click a label or room to rename it in place.</div>' +
        (this.opts.settingsUrl ? '<div class="small mt-2"><a href="' + this.opts.settingsUrl + '">Change the lot / drawing size</a> (Settings).</div>' : "");
    } else if (this.sel.type === "wall") {
      var s = seg(el);
      html = '<h6>Wall</h6>' +
        '<div class="fp-field"><label>Type</label><select class="form-select form-select-sm" data-prop="type"><option value="exterior"' + (el.type === "exterior" ? " selected" : "") + '>Exterior (6")</option><option value="interior"' + (el.type === "interior" ? " selected" : "") + '>Interior (4½")</option></select></div>' +
        f("Thickness (in)", "thickness_in", Math.round((el.thickness || WALL_TYPES[el.type]) * 12 * 10) / 10, 'type="number" step="0.5" min="1"') +
        f("Length", "length", ftIn(s.len), 'readonly') +
        f("Start X, Y (ft)", "p1", el.x1 + ", " + el.y1, 'title="x, y in feet"') +
        f("End X, Y (ft)", "p2", el.x2 + ", " + el.y2, 'title="x, y in feet"');
    } else if (this.sel.type === "room") {
      var isRect = roomIsRect(el);
      html = '<h6>Room</h6>' + f("Name", "name", el.name) +
        (isRect ? '<div class="fp-row">' + f("Width (ft)", "w", el.w, 'type="number" step="0.5" min="0.5"') + f("Depth (ft)", "h", el.h, 'type="number" step="0.5" min="0.5"') + '</div>'
                : f("Shape", "shape", roomPts(el).length + " corners · " + ftIn(el.w) + " × " + ftIn(el.h) + " overall", "readonly") + '<div class="small text-muted mb-2">Drag a corner handle to reshape.</div>') +
        '<div class="fp-row">' + f("X (ft)", "x", el.x, 'type="number" step="0.5"') + f("Y (ft)", "y", el.y, 'type="number" step="0.5"') + '</div>' +
        f("Area", "area", sqft(roomArea(el)), "readonly");
    } else if (this.sel.type === "opening") {
      var isDoor = el.type === "door", dkNow = isDoor ? doorKind(el, this.wallOf(el)) : null;
      html = '<h6>' + (isDoor ? "Door" : "Window") + '</h6>' +
        '<div class="fp-field"><label>Type</label><select class="form-select form-select-sm" data-prop="type"><option value="door"' + (isDoor ? " selected" : "") + '>Door</option><option value="window"' + (!isDoor ? " selected" : "") + '>Window</option></select></div>' +
        (isDoor ? '<div class="fp-field"><label>Door type</label><select class="form-select form-select-sm" data-prop="kind">' + Object.keys(DOOR_KINDS).map(function (k) { return '<option value="' + k + '"' + (dkNow === k ? " selected" : "") + '>' + DOOR_KINDS[k].label + '</option>'; }).join("") + '</select></div>' : "") +
        '<div class="fp-row">' + f("Width (ft)", "width", el.width, 'type="number" step="0.25" min="1"') + f("Height (ft)", "height", el.height != null ? el.height : (isDoor ? DOOR_KINDS[dkNow].h : WINDOW_DEF.h), 'type="number" step="0.25" min="0.5"') + '</div>' +
        (!isDoor ? f("Sill height (ft)", "sill", el.sill != null ? el.sill : WINDOW_DEF.sill, 'type="number" step="0.25" min="0"') : "") +
        f("Position from wall start (ft)", "pos", Math.round(el.pos * 100) / 100, 'type="number" step="0.25"') +
        (isDoor ? '<div class="d-flex gap-1 mb-2"><button class="btn btn-outline-secondary btn-sm" data-btn="swing">' + ({ garage: "Flip inside", sliding: "Flip sides" }[dkNow] || "Flip swing") + '</button>' + (dkNow !== "garage" ? '<button class="btn btn-outline-secondary btn-sm" data-btn="hinge">' + (dkNow === "sliding" ? "Swap panels" : "Flip hinge") + '</button>' : "") + '</div>' : "");
    } else if (this.sel.type === "fixture") {
      var kinds = fixtureOptions(el.kind);
      html = '<h6>Fixture</h6>' +
        '<div class="fp-field"><label>Kind</label><select class="form-select form-select-sm" data-prop="kind">' + kinds + '</select></div>' +
        '<div class="fp-row">' + f("Width (ft)", "w", el.w, 'type="number" step="0.25" min="0.25"') + f("Depth (ft)", "h", el.h, 'type="number" step="0.25" min="0.25"') + '</div>' +
        (el.kind === "stairs" ? '<div class="fp-field"><label>Direction</label><select class="form-select form-select-sm" data-prop="dir"><option value="up"' + (el.dir !== "down" ? " selected" : "") + '>Up (arrow points to the top step)</option><option value="down"' + (el.dir === "down" ? " selected" : "") + '>Down</option></select></div>' : "") +
        f("Label", "label", el.label || "", 'placeholder="optional text, e.g. UP or DN"') +
        '<div class="d-flex gap-1 mb-2"><button class="btn btn-outline-secondary btn-sm" data-btn="rotate">Rotate 90°</button></div>';
    } else if (this.sel.type === "roof") {
      var opt = function (list, cur) { return list.map(function (o) { return '<option value="' + o[0] + '"' + (String(cur) === String(o[0]) ? " selected" : "") + '>' + o[1] + '</option>'; }).join(""); };
      html = '<h6>Roof section</h6><div class="small text-muted mb-2">Built in 3D in place of the automatic roof for this level.</div>' +
        '<div class="fp-field"><label>Style</label><select class="form-select form-select-sm" data-prop="style">' + opt(ROOF_KINDS, el.style) + '</select></div>' +
        (el.style !== "flat" ? '<div class="fp-field"><label>Pitch (rise per 12")</label><select class="form-select form-select-sm" data-prop="pitch">' + opt(PITCHES.map(function (p) { return [p, p + ":12"]; }), el.pitch) + '</select></div>' : "") +
        (el.style === "hip" || el.style === "gable" ? '<div class="fp-field"><label>Ridge runs</label><select class="form-select form-select-sm" data-prop="ridge">' + opt(RIDGES, el.ridge || "auto") + '</select></div>' : "") +
        (el.style === "shed" ? '<div class="fp-field"><label>High side</label><select class="form-select form-select-sm" data-prop="high">' + opt(HIGH_SIDES, el.high || "n") + '</select></div>' : "") +
        '<div class="fp-row">' + f("Overhang (ft)", "overhang", el.overhang != null ? el.overhang : 1.5, 'type="number" step="0.25" min="0"') + f("Eave height (ft)", "eave", el.eave || 9, 'type="number" step="0.5" min="1"') + '</div>' +
        '<div class="fp-row">' + f("Width (ft)", "w", el.w, 'type="number" step="0.5" min="2"') + f("Depth (ft)", "h", el.h, 'type="number" step="0.5" min="2"') + '</div>' +
        '<div class="fp-row">' + f("X (ft)", "x", el.x, 'type="number" step="0.5"') + f("Y (ft)", "y", el.y, 'type="number" step="0.5"') + '</div>';
    } else if (this.sel.type === "guide") {
      html = '<h6>Guide line</h6><div class="small text-muted mb-2">Reference only; not shown in 3D.</div>' +
        f("Label", "label", el.label || "", 'placeholder="e.g. 5\' side yard setback"') +
        f("Length", "length", ftIn(seg(el).len), "readonly") +
        f("Start X, Y (ft)", "p1", el.x1 + ", " + el.y1) + f("End X, Y (ft)", "p2", el.x2 + ", " + el.y2);
    } else if (this.sel.type === "label") {
      html = '<h6>Label</h6>' + f("Text", "text", el.text) + f("Size (ft)", "size", el.size || 1, 'type="number" step="0.25" min="0.25"');
    }
    if (el) html += '<button class="btn btn-outline-danger btn-sm mt-1" data-btn="delete">Delete</button>';
    this.props.innerHTML = html;

    this.props.querySelectorAll("[data-prop]").forEach(function (inp) {
      var name = inp.dataset.prop;
      if (inp.hasAttribute("readonly")) return;
      var apply = function (live) {
        var cur = self.selected(); if (!cur) return;
        var v = inp.value, run = function () {
          if (name === "type" && self.sel.type === "wall") { cur.type = v; cur.thickness = WALL_TYPES[v]; self.lastWallType = v; }
          else if (name === "thickness_in") cur.thickness = Math.max(1, +v || 6) / 12;
          else if (name === "p1" || name === "p2") { var m = v.split(/[ ,]+/).map(Number); if (m.length >= 2 && m.every(isFinite)) { if (name === "p1") { cur.x1 = m[0]; cur.y1 = m[1]; } else { cur.x2 = m[0]; cur.y2 = m[1]; } } }
          else if (name === "type") {
            cur.type = v;
            if (self.sel.type === "opening") {
              if (v === "window") { delete cur.kind; cur.width = WINDOW_DEF.w; cur.sill = WINDOW_DEF.sill; cur.height = WINDOW_DEF.h; }
              else { var dk2 = doorKind({}, self.wallOf(cur)); cur.kind = dk2; cur.width = DOOR_KINDS[dk2].w; cur.height = DOOR_KINDS[dk2].h; delete cur.sill; }
            }
          }
          else if (name === "kind") {
            cur.kind = v;
            if (self.sel.type === "opening" && DOOR_KINDS[v]) { cur.width = DOOR_KINDS[v].w; cur.height = DOOR_KINDS[v].h; }
            if (self.sel.type === "fixture") { if (v === "stairs") { cur.dir = cur.dir || "up"; if (!cur.label) cur.label = "UP"; } else if (/^(UP|DN)$/.test(cur.label || "")) cur.label = ""; }
          }
          else if (name === "label") cur.label = v;
          else if (name === "style" || name === "ridge" || name === "high") { cur[name] = v; self.lastRoof = Object.assign({}, self.lastRoof || {}, { style: cur.style, pitch: cur.pitch, ridge: cur.ridge, overhang: cur.overhang, eave: cur.eave, high: cur.high }); }
          else if (name === "pitch") { cur.pitch = +v || 6; self.lastRoof = Object.assign({}, self.lastRoof || {}, { pitch: cur.pitch }); }
          else if (name === "overhang" || name === "eave") { var ov = +v; if (isFinite(ov) && ov >= 0) { cur[name] = ov; self.lastRoof = Object.assign({}, self.lastRoof || {}); self.lastRoof[name] = ov; } }
          else if (name === "dir") { cur.dir = v; if (!cur.label || /^(UP|DN|DOWN)$/i.test(cur.label)) cur.label = v === "down" ? "DN" : "UP"; }
          else if (name === "name" || name === "text") cur[name] = v;
          else if (name === "pos") { var w = self.wallOf(cur); if (w) cur.pos = clamp(+v || 0, cur.width / 2, seg(w).len - cur.width / 2); }
          else if (["w", "h", "x", "y", "width", "size", "height", "sill"].indexOf(name) >= 0) {
            var n = +v; if (!isFinite(n) || !(name === "x" || name === "y" || name === "sill" || n > 0)) return;
            if (self.sel.type === "room") { if (name === "x" || name === "y") translateRoom(cur, name === "x" ? n - cur.x : 0, name === "y" ? n - cur.y : 0); else { cur[name] = n; cur.pts = rectPts(cur); roomSync(cur); } }
            else cur[name] = n;
          }
        };
        if (live) { run(); self.render(); } else self.commit(run);
      };
      inp.addEventListener("input", function () { if (name === "name" || name === "text" || name === "label") { self.liveBefore = self.liveBefore || JSON.stringify(self.data); apply(true); } });
      inp.addEventListener("change", function () {
        if (self.liveBefore) { var b = self.liveBefore; self.liveBefore = null; apply(true); if (JSON.stringify(self.data) !== b) { self.history.push(b); self.future = []; self.markDirty(); } self.updatePanel(); }
        else apply(false);
      });
      inp.addEventListener("keydown", function (e) { if (e.key === "Enter") inp.blur(); });
    });
    this.props.querySelectorAll("[data-btn]").forEach(function (b) {
      b.addEventListener("click", function () {
        var cur = self.selected(); if (!cur) return;
        if (b.dataset.btn === "delete") return self.deleteSelected();
        self.commit(function () {
          if (b.dataset.btn === "swing") cur.swing = -(cur.swing || 1);
          else if (b.dataset.btn === "hinge") cur.hinge = cur.hinge ? 0 : 1;
          else if (b.dataset.btn === "rotate") { var cx = cur.x + cur.w / 2, cy = cur.y + cur.h / 2, w = cur.w; cur.w = cur.h; cur.h = w; cur.x = self.snapVal(cx - cur.w / 2); cur.y = self.snapVal(cy - cur.h / 2); cur.rot = ((cur.rot || 0) + 90) % 360; }
        });
      });
    });
    this.renderSummary();
  };

  P.refreshPropValues = function (el) {
    if (!el) return;
    var set = function (name, v) { var i = this.props.querySelector('[data-prop="' + name + '"]'); if (i && document.activeElement !== i) i.value = v; }.bind(this);
    if (this.sel.type === "wall" || this.sel.type === "guide") { set("length", ftIn(seg(el).len)); set("p1", el.x1 + ", " + el.y1); set("p2", el.x2 + ", " + el.y2); }
    if (this.sel.type === "room") { set("w", el.w); set("h", el.h); set("x", el.x); set("y", el.y); set("area", sqft(roomArea(el))); set("shape", roomPts(el).length + " corners · " + ftIn(el.w) + " × " + ftIn(el.h) + " overall"); }
    if (this.sel.type === "fixture" || this.sel.type === "roof") { set("w", el.w); set("h", el.h); set("x", el.x); set("y", el.y); }
    if (this.sel.type === "opening") set("pos", Math.round(el.pos * 100) / 100);
  };

  P.renderSummary = function () {
    var d = this.data, self = this, total = 0, rows = d.rooms.map(function (r) {
      var a = roomArea(r); total += a;
      return '<tr data-room="' + r.id + '" class="' + (self.sel && self.sel.id === r.id ? "table-active" : "") + '"><td>' + esc(r.name) + '</td><td class="text-muted text-nowrap">' + (roomIsRect(r) ? ftIn(r.w) + " × " + ftIn(r.h) : roomPts(r).length + "-sided") + '</td><td class="text-end text-nowrap">' + Math.round(a).toLocaleString() + '</td></tr>';
    }).join("");
    var doors = d.openings.filter(function (o) { return o.type === "door"; }).length, wins = d.openings.length - doors;
    var extLen = 0; d.walls.forEach(function (w) { if (w.type === "exterior") extLen += seg(w).len; });
    this.summary.innerHTML = '<h6 class="mt-3">Summary</h6>' +
      '<div class="small text-muted mb-1">' + d.walls.length + ' walls (' + ftIn(extLen) + ' exterior) · ' + doors + ' doors · ' + wins + ' windows · ' + d.fixtures.length + ' fixtures' + (d.roofs.length ? ' · ' + d.roofs.length + ' roof section' + (d.roofs.length === 1 ? '' : 's') : '') + '</div>' +
      (d.rooms.length ? '<table class="table table-sm small mb-1"><tbody>' + rows + '</tbody><tfoot><tr><th colspan="2">Total</th><th class="text-end">' + Math.round(total).toLocaleString() + ' sq ft</th></tr></tfoot></table>' : '<div class="small text-muted">No rooms yet.</div>');
    this.summary.querySelectorAll("[data-room]").forEach(function (tr) { tr.style.cursor = "pointer"; tr.addEventListener("click", function () { self.setSel({ type: "room", id: tr.dataset.room }); self.render(); self.updatePanel(); }); });
  };

  // ---------------------------------------------------------------- rendering
  P.render = function () {
    var self = this;
    if (this.raf) return;
    this.raf = requestAnimationFrame(function () { self.raf = null; self.draw(self.ctx, self.cw, self.ch, self.view, { grid: self.showGrid, ui: true }); self.zoomEl.textContent = Math.round(self.view.scale * 100) / 100 + " px/ft"; });
  };

  P.draw = function (ctx, cw, ch, view, o) {
    var self = this, s = view.scale, d = this.data;
    var S = function (x, y) { return { x: x * s + view.x, y: y * s + view.y }; };
    ctx.save();
    ctx.fillStyle = C.bg; ctx.fillRect(0, 0, cw, ch);

    // grid
    if (o.grid) {
      var minor = d.grid, major = s >= 10 ? 1 : s >= 3 ? 5 : 10;
      var x0 = Math.floor(-view.x / s), x1 = Math.ceil((cw - view.x) / s), y0 = Math.floor(-view.y / s), y1 = Math.ceil((ch - view.y) / s);
      if (minor * s >= 6) { ctx.strokeStyle = C.gridMinor; ctx.lineWidth = 1; ctx.beginPath(); for (var gx = Math.floor(x0 / minor) * minor; gx <= x1; gx += minor) { var px = Math.round(S(gx, 0).x) + .5; ctx.moveTo(px, 0); ctx.lineTo(px, ch); } for (var gy = Math.floor(y0 / minor) * minor; gy <= y1; gy += minor) { var py = Math.round(S(0, gy).y) + .5; ctx.moveTo(0, py); ctx.lineTo(cw, py); } ctx.stroke(); }
      ctx.strokeStyle = C.gridMajor; ctx.beginPath(); for (var mx = Math.floor(x0 / major) * major; mx <= x1; mx += major) { var mpx = Math.round(S(mx, 0).x) + .5; ctx.moveTo(mpx, 0); ctx.lineTo(mpx, ch); } for (var my = Math.floor(y0 / major) * major; my <= y1; my += major) { var mpy = Math.round(S(0, my).y) + .5; ctx.moveTo(0, mpy); ctx.lineTo(cw, mpy); } ctx.stroke();
    }
    // drawing-area boundary
    var b0 = S(0, 0), b1 = S(this.widthFt, this.depthFt);
    ctx.setLineDash([6, 4]); ctx.strokeStyle = C.boundary; ctx.lineWidth = 1; ctx.strokeRect(b0.x + .5, b0.y + .5, b1.x - b0.x, b1.y - b0.y); ctx.setLineDash([]);

    if (o.ui) this.drawUnderlay(ctx, S, s);

    // rooms
    d.rooms.forEach(function (r) {
      var pts = roomPts(r), p = S(r.x, r.y), w = r.w * s, h = r.h * s, selected = o.ui && self.isSelected("room", r.id), rect = roomIsRect(r);
      ctx.beginPath(); pts.forEach(function (q, i) { var sq = S(q[0], q[1]); if (i) ctx.lineTo(sq.x, sq.y); else ctx.moveTo(sq.x, sq.y); }); ctx.closePath();
      ctx.fillStyle = selected ? C.selFill : C.room; ctx.fill();
      if (selected) { ctx.strokeStyle = C.sel; ctx.lineWidth = 1.5; ctx.stroke(); }
      ctx.fillStyle = C.roomText; ctx.textAlign = "center"; ctx.textBaseline = "middle";
      var fs = clamp(s * 0.9, 9, 15), c = S(roomCentroid(r).x, roomCentroid(r).y);
      if (w > 30 && h > 16) {
        ctx.font = "600 " + fs + "px system-ui, sans-serif"; ctx.fillText(self.fitText(ctx, r.name, w - 8), c.x, c.y - (h > 40 ? fs * 0.7 : 0));
        if (h > 40) { ctx.font = (fs - 2) + "px system-ui, sans-serif"; if (rect) ctx.fillText(ftIn(r.w) + " × " + ftIn(r.h), c.x, c.y + fs * 0.5); ctx.fillText(sqft(roomArea(r)), c.x, c.y + fs * (rect ? 1.6 : 0.5)); }
      }
      if (selected && o.ui && rect) { self.dimText(ctx, S(r.x, r.y), S(r.x + r.w, r.y), ftIn(r.w), -1); self.dimText(ctx, S(r.x, r.y), S(r.x, r.y + r.h), ftIn(r.h), 1); }
    });

    // walls
    ctx.lineCap = "square"; ctx.lineJoin = "miter";
    d.walls.forEach(function (w) {
      var a = S(w.x1, w.y1), b = S(w.x2, w.y2), t = (w.thickness || WALL_TYPES[w.type] || 0.5) * s;
      var selected = o.ui && self.isSelected("wall", w.id), hovered = o.ui && self.hover === w.id;
      ctx.strokeStyle = selected ? C.sel : hovered ? C.draft : C.wall; ctx.lineWidth = Math.max(t, 1.5);
      ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
    });
    // openings (cut into walls)
    d.openings.forEach(function (op) {
      var w = self.wallOf(op); if (!w) return;
      var c = self.openingCenter(op, w), sg = c.s, t = (w.thickness || 0.5) * s, half = op.width / 2;
      var A = S(c.x - sg.ux * half, c.y - sg.uy * half), B = S(c.x + sg.ux * half, c.y + sg.uy * half);
      ctx.strokeStyle = C.bg; ctx.lineWidth = t + 2; ctx.lineCap = "butt"; ctx.beginPath(); ctx.moveTo(A.x, A.y); ctx.lineTo(B.x, B.y); ctx.stroke();
      var selected = o.ui && self.sel && self.sel.id === op.id;
      if (op.type === "door" && doorKind(op, w) === "garage") {
        // sectional garage door: panel line across the opening + dashed track showing where it retracts
        var gdir = op.swing || 1, depth = Math.min(op.width, 7) * s;
        ctx.strokeStyle = selected ? C.sel : C.door; ctx.lineWidth = 2.5; ctx.beginPath(); ctx.moveTo(A.x, A.y); ctx.lineTo(B.x, B.y); ctx.stroke();
        ctx.lineWidth = 1; ctx.setLineDash([4, 3]);
        ctx.beginPath(); ctx.moveTo(A.x, A.y); ctx.lineTo(A.x + sg.nx * gdir * depth, A.y + sg.ny * gdir * depth); ctx.lineTo(B.x + sg.nx * gdir * depth, B.y + sg.ny * gdir * depth); ctx.lineTo(B.x, B.y); ctx.stroke(); ctx.setLineDash([]);
        ctx.strokeStyle = C.wall; [A, B].forEach(function (j) { ctx.beginPath(); ctx.moveTo(j.x - sg.nx * t / 2, j.y - sg.ny * t / 2); ctx.lineTo(j.x + sg.nx * t / 2, j.y + sg.ny * t / 2); ctx.stroke(); });
      } else if (op.type === "door" && doorKind(op, w) === "sliding") {
        // two overlapping panels: fixed on one side of the wall centre line, sliding on the other (arrow shows travel)
        var M = { x: (A.x + B.x) / 2, y: (A.y + B.y) / 2 }, sd = op.swing || 1, ox = sg.nx * sd * t / 4, oy = sg.ny * sd * t / 4;
        var fixedA = op.hinge ? M : A, fixedB = op.hinge ? B : M, slideA = op.hinge ? A : M, slideB = op.hinge ? M : B;
        ctx.strokeStyle = selected ? C.sel : C.win; ctx.lineWidth = 2.5;
        ctx.beginPath(); ctx.moveTo(fixedA.x + ox, fixedA.y + oy); ctx.lineTo(fixedB.x + ox, fixedB.y + oy); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(slideA.x - ox, slideA.y - oy); ctx.lineTo(slideB.x - ox, slideB.y - oy); ctx.stroke();
        var ah = 5, ax = (slideA.x + slideB.x) / 2 - ox, ay = (slideA.y + slideB.y) / 2 - oy, tdir = op.hinge ? -1 : 1, off2 = sd * -1;
        ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(ax - sg.ux * tdir * 14 + sg.nx * off2 * 0, ay - sg.uy * tdir * 14); ctx.stroke();
        var tipx = ax - sg.ux * tdir * 14, tipy = ay - sg.uy * tdir * 14;
        ctx.beginPath(); ctx.moveTo(tipx, tipy); ctx.lineTo(tipx + sg.ux * tdir * ah - sg.nx * ah / 2, tipy + sg.uy * tdir * ah - sg.ny * ah / 2); ctx.lineTo(tipx + sg.ux * tdir * ah + sg.nx * ah / 2, tipy + sg.uy * tdir * ah + sg.ny * ah / 2); ctx.closePath(); ctx.fillStyle = ctx.strokeStyle; ctx.fill();
        ctx.strokeStyle = C.wall; [A, B].forEach(function (j) { ctx.beginPath(); ctx.moveTo(j.x - sg.nx * t / 2, j.y - sg.ny * t / 2); ctx.lineTo(j.x + sg.nx * t / 2, j.y + sg.ny * t / 2); ctx.stroke(); });
      } else if (op.type === "door") {
        var hinge = op.hinge ? B : A, other = op.hinge ? A : B, dir = (op.swing || 1) * (op.hinge ? -1 : 1);
        var leaf = { x: hinge.x + sg.nx * dir * op.width * s, y: hinge.y + sg.ny * dir * op.width * s };
        ctx.strokeStyle = selected ? C.sel : C.door; ctx.lineWidth = doorKind(op, w) === "interior" ? 1.5 : 2.5; ctx.beginPath(); ctx.moveTo(hinge.x, hinge.y); ctx.lineTo(leaf.x, leaf.y); ctx.stroke();
        var a0 = Math.atan2(other.y - hinge.y, other.x - hinge.x), a1 = Math.atan2(leaf.y - hinge.y, leaf.x - hinge.x);
        ctx.lineWidth = 1; ctx.setLineDash([3, 3]); ctx.beginPath(); ctx.arc(hinge.x, hinge.y, op.width * s, a0, a1, dir * (op.hinge ? -1 : 1) < 0); ctx.stroke(); ctx.setLineDash([]);
        // jambs
        ctx.strokeStyle = C.wall; ctx.lineWidth = 1; [A, B].forEach(function (j) { ctx.beginPath(); ctx.moveTo(j.x - sg.nx * t / 2, j.y - sg.ny * t / 2); ctx.lineTo(j.x + sg.nx * t / 2, j.y + sg.ny * t / 2); ctx.stroke(); });
      } else {
        ctx.strokeStyle = selected ? C.sel : C.win; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(A.x, A.y); ctx.lineTo(B.x, B.y); ctx.stroke();
        ctx.lineWidth = 1; ctx.strokeStyle = C.wall;
        ctx.beginPath(); ctx.moveTo(A.x - sg.nx * t / 2, A.y - sg.ny * t / 2); ctx.lineTo(B.x - sg.nx * t / 2, B.y - sg.ny * t / 2); ctx.moveTo(A.x + sg.nx * t / 2, A.y + sg.ny * t / 2); ctx.lineTo(B.x + sg.nx * t / 2, B.y + sg.ny * t / 2); ctx.stroke();
        [A, B].forEach(function (j) { ctx.beginPath(); ctx.moveTo(j.x - sg.nx * t / 2, j.y - sg.ny * t / 2); ctx.lineTo(j.x + sg.nx * t / 2, j.y + sg.ny * t / 2); ctx.stroke(); });
      }
      if (selected) { var cc = S(c.x, c.y); ctx.fillStyle = C.sel; ctx.beginPath(); ctx.arc(cc.x, cc.y, 4, 0, Math.PI * 2); ctx.fill(); }
    });
    ctx.lineCap = "square";

    // roof sections: translucent outline with ridge / hip lines (drawn over the plan, under labels)
    d.roofs.forEach(function (rf) { self.drawRoofPlan(ctx, rf, S, s, o.ui && self.isSelected("roof", rf.id)); });

    // guide lines (reference only)
    d.guides.forEach(function (gl) {
      var a = S(gl.x1, gl.y1), b = S(gl.x2, gl.y2), selected = o.ui && self.isSelected("guide", gl.id);
      ctx.save(); ctx.setLineDash([6, 4]); ctx.strokeStyle = selected ? C.sel : C.guide; ctx.lineWidth = selected ? 1.5 : 1;
      ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke(); ctx.setLineDash([]);
      [a, b].forEach(function (e) { ctx.beginPath(); ctx.arc(e.x, e.y, 2, 0, Math.PI * 2); ctx.fillStyle = selected ? C.sel : C.guide; ctx.fill(); });
      ctx.restore();
      var text = ftIn(seg(gl).len); if (gl.label) text = gl.label + " · " + text;
      self.dimText(ctx, a, b, text, 1, 4, selected ? C.sel : C.guide);
    });

    // fixtures
    d.fixtures.forEach(function (fx) { self.drawFixture(ctx, fx, S, s, o.ui && self.isSelected("fixture", fx.id)); });

    // selected wall length + exterior dimension strings
    d.walls.forEach(function (w) {
      if (o.ui && self.sel && self.sel.id === w.id) self.dimText(ctx, S(w.x1, w.y1), S(w.x2, w.y2), ftIn(seg(w).len), -1, (w.thickness || 0.5) * s / 2 + 4);
    });
    if ((o.ui && this.dimStrings) || o.strings) this.drawDimStrings(ctx, S, s);

    // labels
    d.labels.forEach(function (l) {
      var p = S(l.x, l.y), px = clamp((l.size || 1) * s, 9, 72), selected = o.ui && self.isSelected("label", l.id);
      ctx.font = px + "px system-ui, sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
      if (selected) { var bw = ctx.measureText(l.text || " ").width; ctx.strokeStyle = C.sel; ctx.lineWidth = 1; ctx.strokeRect(p.x - bw / 2 - 4, p.y - px / 2 - 3, bw + 8, px + 6); }
      ctx.fillStyle = C.label; ctx.fillText(l.text || "", p.x, p.y);
    });

    if (o.ui) {
      // wall draft
      if ((this.tool === "wall" || this.tool === "line") && this.draft) {
        var st = S(this.draft.start.x, this.draft.start.y), isLineDraft = this.tool === "line";
        ctx.fillStyle = C.draft; ctx.beginPath(); ctx.arc(st.x, st.y, 4, 0, Math.PI * 2); ctx.fill();
        if (this.draft.cur) {
          var cu = S(this.draft.cur.x, this.draft.cur.y), thick = isLineDraft ? 1.5 : WALL_TYPES[this.lastWallType || "exterior"] * s;
          if (isLineDraft) ctx.setLineDash([6, 4]);
          ctx.strokeStyle = "rgba(224,116,42,.7)"; ctx.lineWidth = Math.max(thick, 1.5); ctx.beginPath(); ctx.moveTo(st.x, st.y); ctx.lineTo(cu.x, cu.y); ctx.stroke(); ctx.setLineDash([]);
          var L = Math.hypot(this.draft.cur.x - this.draft.start.x, this.draft.cur.y - this.draft.start.y);
          if (L > 0) this.dimText(ctx, st, cu, ftIn(L), -1, thick / 2 + 4, C.draft);
          if (this.draft.cur.snapped === "endpoint") { ctx.strokeStyle = C.draft; ctx.lineWidth = 1.5; ctx.strokeRect(cu.x - 6, cu.y - 6, 12, 12); }
        }
      }
      // polygon room draft
      if (this.roomDraft) {
        var rd = this.roomDraft.pts, rc0 = S(rd[0][0], rd[0][1]);
        ctx.strokeStyle = C.sel; ctx.fillStyle = C.selFill; ctx.lineWidth = 1.5; ctx.beginPath();
        rd.forEach(function (q, i) { var sq = S(q[0], q[1]); if (i) ctx.lineTo(sq.x, sq.y); else ctx.moveTo(sq.x, sq.y); });
        if (this.roomDraft.cur) { var rcu = S(this.roomDraft.cur.x, this.roomDraft.cur.y); ctx.lineTo(rcu.x, rcu.y); }
        ctx.closePath(); ctx.fill(); ctx.stroke();
        rd.forEach(function (q) { var sq = S(q[0], q[1]); ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(sq.x, sq.y, 3.5, 0, Math.PI * 2); ctx.fill(); ctx.stroke(); });
        if (rd.length >= 3) { ctx.strokeStyle = C.draft; ctx.beginPath(); ctx.arc(rc0.x, rc0.y, 7, 0, Math.PI * 2); ctx.stroke(); }
      }
      // marquee
      if (this.drag && this.drag.kind === "marquee") {
        var ma = S(this.drag.start.x, this.drag.start.y), mb = S(this.drag.cur.x, this.drag.cur.y);
        ctx.fillStyle = "rgba(13,110,253,.08)"; ctx.fillRect(ma.x, ma.y, mb.x - ma.x, mb.y - ma.y);
        ctx.strokeStyle = C.sel; ctx.lineWidth = 1; ctx.setLineDash([4, 3]); ctx.strokeRect(ma.x, ma.y, mb.x - ma.x, mb.y - ma.y); ctx.setLineDash([]);
      }
      // roof draft
      if (this.drag && this.drag.kind === "roof") {
        var ra2 = S(this.drag.start.x, this.drag.start.y), rb2 = S(this.drag.cur.x, this.drag.cur.y);
        ctx.fillStyle = C.roofFill; ctx.fillRect(ra2.x, ra2.y, rb2.x - ra2.x, rb2.y - ra2.y); ctx.strokeStyle = C.roof; ctx.lineWidth = 1.2; ctx.strokeRect(ra2.x, ra2.y, rb2.x - ra2.x, rb2.y - ra2.y);
        var rw2 = Math.abs(this.drag.cur.x - this.drag.start.x), rh2 = Math.abs(this.drag.cur.y - this.drag.start.y);
        ctx.fillStyle = C.roof; ctx.font = "12px system-ui, sans-serif"; ctx.textAlign = "left"; ctx.textBaseline = "bottom"; ctx.fillText("Roof " + ftIn(rw2) + " × " + ftIn(rh2), Math.min(ra2.x, rb2.x) + 4, Math.min(ra2.y, rb2.y) - 4);
      }
      // room draft
      if (this.drag && this.drag.kind === "room") {
        var a = S(this.drag.start.x, this.drag.start.y), bb = S(this.drag.cur.x, this.drag.cur.y);
        ctx.fillStyle = C.selFill; ctx.fillRect(a.x, a.y, bb.x - a.x, bb.y - a.y); ctx.strokeStyle = C.sel; ctx.lineWidth = 1; ctx.strokeRect(a.x, a.y, bb.x - a.x, bb.y - a.y);
        var rw = Math.abs(this.drag.cur.x - this.drag.start.x), rh = Math.abs(this.drag.cur.y - this.drag.start.y);
        ctx.fillStyle = C.sel; ctx.font = "12px system-ui, sans-serif"; ctx.textAlign = "left"; ctx.textBaseline = "bottom"; ctx.fillText(ftIn(rw) + " × " + ftIn(rh) + " · " + sqft(rw * rh), Math.min(a.x, bb.x) + 4, Math.min(a.y, bb.y) - 4);
      }
      // hover snap cursor for placement tools
      if (this.mouse && !this.drag && (this.tool === "wall" || this.tool === "line" || this.tool === "room" || this.tool === "roof" || this.tool === "label")) {
        var sp = this.snapPoint(this.mouse), sc = S(sp.x, sp.y);
        ctx.strokeStyle = C.draft; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(sc.x - 6, sc.y); ctx.lineTo(sc.x + 6, sc.y); ctx.moveTo(sc.x, sc.y - 6); ctx.lineTo(sc.x, sc.y + 6); ctx.stroke();
      }
      // hover tooltip: a Room's name, size and area — or any wall-enclosed area
      var hr = this.hoverRoom && this.mouse ? this.find("room", this.hoverRoom) : null, ha = !hr && this.hoverArea && this.mouse ? this.hoverArea : null;
      if ((hr || ha) && !this.drag) {
        var box = hr || ha, hp = S(box.x, box.y);
        ctx.strokeStyle = C.sel; ctx.lineWidth = 1; ctx.setLineDash([4, 3]);
        if (hr) { ctx.beginPath(); roomPts(hr).forEach(function (q, i) { var sq = S(q[0], q[1]); if (i) ctx.lineTo(sq.x, sq.y); else ctx.moveTo(sq.x, sq.y); }); ctx.closePath(); ctx.stroke(); }
        else ctx.strokeRect(hp.x, hp.y, box.w * s, box.h * s);
        ctx.setLineDash([]);
        var lines = hr ? [hr.name || "Room", (roomIsRect(hr) ? ftIn(hr.w) + " × " + ftIn(hr.h) + "  ·  " : "") + sqft(roomArea(hr))]
                       : ["Enclosed area", ftIn(ha.w) + " × " + ftIn(ha.h) + " inside walls  ·  " + sqft(ha.area), "Double-click to make it a room"];
        this.tooltip(ctx, S(this.mouse.x, this.mouse.y), lines, cw);
      }
      // handles
      this.handles().forEach(function (h) { ctx.fillStyle = "#fff"; ctx.strokeStyle = C.sel; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.rect(h.s.x - HANDLE / 2, h.s.y - HANDLE / 2, HANDLE, HANDLE); ctx.fill(); ctx.stroke(); });
      // origin + scale note
      ctx.fillStyle = "#9aa3ad"; ctx.font = "11px system-ui, sans-serif"; ctx.textAlign = "left"; ctx.textBaseline = "bottom";
      ctx.fillText("Grid " + ftIn(d.grid) + " · drawing area " + ftIn(this.widthFt) + " × " + ftIn(this.depthFt), 8, ch - 6);
    }
    ctx.restore();
  };

  P.drawUnderlay = function (ctx, S, s) {
    var u = this.underlay(); if (!u) return;
    ctx.save(); ctx.globalAlpha = 0.45; ctx.lineCap = "square";
    ctx.setLineDash([4, 3]); ctx.strokeStyle = C.under; ctx.lineWidth = 1;
    u.rooms.forEach(function (r) { var p = S(r.x, r.y); ctx.strokeRect(p.x, p.y, r.w * s, r.h * s); });
    ctx.setLineDash([]);
    u.walls.forEach(function (w) { var a = S(w.x1, w.y1), b = S(w.x2, w.y2); ctx.lineWidth = Math.max((w.thickness || 0.5) * s, 1); ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke(); });
    ctx.restore();
  };
  P.copyUnderlay = function () {
    var u = this.underlay(); if (!u) return;
    var ext = u.walls.filter(function (w) { return w.type === "exterior"; }); if (!ext.length) return alert("That level has no exterior walls to copy.");
    this.commit(function () { var self = this; ext.forEach(function (w) { var c = JSON.parse(JSON.stringify(w)); c.id = uid(); self.data.walls.push(c); }); });
  };

  P.drawFixture = function (ctx, f, S, s, selected) {
    var p = S(f.x, f.y), w = f.w * s, h = f.h * s, rot = f.rot || 0;
    ctx.save(); ctx.translate(p.x + w / 2, p.y + h / 2); ctx.rotate(rot * Math.PI / 180);
    var lw = (rot % 180) ? h : w, lh = (rot % 180) ? w : h, x0 = -lw / 2, y0 = -lh / 2;
    ctx.strokeStyle = selected ? C.sel : C.fix; ctx.fillStyle = "rgba(255,255,255,.9)"; ctx.lineWidth = selected ? 1.6 : 1.1;
    var rr = function (x, y, ww, hh, r) { r = Math.min(r, ww / 2, hh / 2); ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + ww, y, x + ww, y + hh, r); ctx.arcTo(x + ww, y + hh, x, y + hh, r); ctx.arcTo(x, y + hh, x, y, r); ctx.arcTo(x, y, x + ww, y, r); ctx.closePath(); };
    var ell = function (cx, cy, rx, ry) { ctx.beginPath(); ctx.ellipse(cx, cy, Math.max(rx, .5), Math.max(ry, .5), 0, 0, Math.PI * 2); ctx.stroke(); };
    var line = function (a, b, c, d) { ctx.beginPath(); ctx.moveTo(a, b); ctx.lineTo(c, d); ctx.stroke(); };
    var spec2 = FIXTURES[f.kind] || {}, round = { tub: 6, car: 8, sofa: 4, sink: 3, dbl_sink: 3, vanity: 2, water_heater: lw / 2, washer: 2, stool: lw / 2, round_table: lw / 2 }[f.kind] || 0;
    if (spec2.above) ctx.setLineDash([4, 3]);   // above counter height: dashed, like uppers on a real plan
    rr(x0, y0, lw, lh, round); ctx.fill(); ctx.stroke(); ctx.setLineDash([]);
    switch (f.kind) {
      case "stairs": {
        var tread = 0.9167 * s, n = Math.floor(lh / tread), down = f.dir === "down";
        for (var i = 1; i < n; i++) line(x0, y0 + i * tread, x0 + lw, y0 + i * tread);
        ctx.lineWidth = 1.4; line(0, y0 + 6, 0, y0 + lh - 6);
        var tipY = down ? y0 + 4 : y0 + lh - 4, backY = down ? y0 + 11 : y0 + lh - 11;
        ctx.beginPath(); ctx.moveTo(0, tipY); ctx.lineTo(-4, backY); ctx.lineTo(4, backY); ctx.closePath(); ctx.fillStyle = ctx.strokeStyle; ctx.fill();
        break; }
      case "toilet": ctx.fillStyle = "#fff"; ctx.fillRect(x0, y0, lw, lh * .32); ctx.strokeRect(x0, y0, lw, lh * .32); ell(0, y0 + lh * .64, lw * .36, lh * .3); break;
      case "sink": case "vanity": ell(0, 0, lw * .34, lh * .3); ctx.beginPath(); ctx.arc(0, y0 + 4, 1.5, 0, 7); ctx.fill(); break;
      case "dbl_sink": ell(-lw * .24, 0, lw * .2, lh * .3); ell(lw * .24, 0, lw * .2, lh * .3); ctx.beginPath(); ctx.arc(0, y0 + 4, 1.5, 0, 7); ctx.fill(); break;
      case "range36": case "cooktop": [[-.25, -.25], [.25, -.25], [-.25, .25], [.25, .25]].forEach(function (b) { ell(b[0] * lw, b[1] * lh, Math.min(lw, lh) * .14, Math.min(lw, lh) * .14); }); break;
      case "wall_oven": ctx.strokeRect(x0 + 3, y0 + 3, lw - 6, lh - 6); line(x0 + 3, 0, x0 + lw - 3, 0); break;
      case "hood": line(x0, y0, x0 + lw, y0 + lh); line(x0 + lw, y0, x0, y0 + lh); break;
      case "microwave": ctx.strokeRect(x0 + 3, y0 + 3, lw * .7 - 3, lh - 6); break;
      case "pantry": line(x0, y0, x0 + lw, y0 + lh); line(x0 + lw, y0, x0, y0 + lh); break;
      case "upper": break;
      case "island_seat": ctx.setLineDash([3, 3]); line(x0, y0 + lh - 1.2 * s, x0 + lw, y0 + lh - 1.2 * s); ctx.setLineDash([]); break;
      case "stool": ell(0, 0, lw * .28, lh * .28); break;
      case "round_table": ell(0, 0, lw * .38, lh * .38); break;
      case "chair": ctx.strokeRect(x0 + 2, y0 + 2, lw - 4, lh * .25); break;
      case "tub": rr(x0 + 5, y0 + 5, lw - 10, lh - 10, 8); ctx.stroke(); ctx.beginPath(); ctx.arc(x0 + lw * .15, 0, 2, 0, 7); ctx.stroke(); break;
      case "shower": ctx.globalAlpha = .5; line(x0, y0, x0 + lw, y0 + lh); line(x0 + lw, y0, x0, y0 + lh); ctx.globalAlpha = 1; ctx.beginPath(); ctx.arc(0, 0, 2.5, 0, 7); ctx.stroke(); break;
      case "range": [[-.25, -.25], [.25, -.25], [-.25, .25], [.25, .25]].forEach(function (b) { ell(b[0] * lw, b[1] * lh, Math.min(lw, lh) * .14, Math.min(lw, lh) * .14); }); break;
      case "fridge": line(0, y0, 0, y0 + lh); line(x0 + lw * .1, y0 + lh - 3, x0 + lw * .4, y0 + lh - 3); line(x0 + lw * .6, y0 + lh - 3, x0 + lw * .9, y0 + lh - 3); break;
      case "dishwasher": line(x0, y0 + lh - 4, x0 + lw, y0 + lh - 4); break;
      case "washer": ell(0, 0, Math.min(lw, lh) * .32, Math.min(lw, lh) * .32); break;
      case "water_heater": ctx.beginPath(); ctx.arc(0, 0, 1.5, 0, 7); ctx.fill(); break;
      case "island": ctx.lineWidth = 1.8; ctx.strokeRect(x0, y0, lw, lh); break;
      case "counter": break;
      case "bed": case "bed_king": ctx.strokeRect(x0 + 4, y0 + 4, lw / 2 - 6, lh * .16); ctx.strokeRect(x0 + lw / 2 + 2, y0 + 4, lw / 2 - 6, lh * .16); line(x0, y0 + lh * .28, x0 + lw, y0 + lh * .28); break;
      case "sofa": ctx.strokeRect(x0, y0, lw, lh * .3); ctx.strokeRect(x0, y0, lw * .1, lh); ctx.strokeRect(x0 + lw * .9, y0, lw * .1, lh); break;
      case "table": rr(x0 + 4, y0 + 4, lw - 8, lh - 8, 2); ctx.stroke(); break;
      case "desk": line(x0 + lw * .35, y0 + lh - 4, x0 + lw * .65, y0 + lh - 4); break;
      case "car": line(x0 + 4, y0 + lh * .3, x0 + lw - 4, y0 + lh * .3); line(x0 + 4, y0 + lh * .72, x0 + lw - 4, y0 + lh * .72); break;
    }
    if (f.label) {
      var fs = clamp(Math.min(lw, lh) * .35, 8, 13);
      ctx.fillStyle = selected ? C.sel : C.fix; ctx.font = "600 " + fs + "px system-ui, sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
      ctx.fillText(this.fitText(ctx, f.label, lw - 4), 0, f.kind === "stairs" ? (f.dir === "down" ? y0 + 16 : y0 + lh - 16) : 0);
    }
    ctx.restore();
  };

  // Exterior dimension strings: one run of segment lengths plus an overall, along the top and the left.
  P.drawDimStrings = function (ctx, S, s) {
    var ext = this.data.walls.filter(function (w) { return w.type === "exterior"; });
    if (ext.length < 2) return;
    var uniq = function (arr) { arr = arr.map(function (v) { return Math.round(v * 16) / 16; }).sort(function (a, b) { return a - b; }); return arr.filter(function (v, i) { return i === 0 || v - arr[i - 1] > 1e-6; }); };
    var xs = [], ys = [];
    ext.forEach(function (w) { xs.push(w.x1, w.x2); ys.push(w.y1, w.y2); });
    xs = uniq(xs); ys = uniq(ys);
    var minX = xs[0], maxX = xs[xs.length - 1], minY = ys[0], maxY = ys[ys.length - 1];
    var top = S(0, minY).y - 22, top2 = top - 20, left = S(minX, 0).x - 22, left2 = left - 20;
    ctx.save(); ctx.strokeStyle = C.string; ctx.fillStyle = C.string; ctx.lineWidth = 1; ctx.font = "10px system-ui, sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
    var self = this;
    var run = function (vals, horiz, line) {
      var pts = vals.map(function (v) { return horiz ? S(v, 0).x : S(0, v).y; });
      var a = pts[0], b = pts[pts.length - 1];
      ctx.beginPath(); if (horiz) { ctx.moveTo(a, line); ctx.lineTo(b, line); } else { ctx.moveTo(line, a); ctx.lineTo(line, b); } ctx.stroke();
      pts.forEach(function (pt) { ctx.beginPath(); if (horiz) { ctx.moveTo(pt - 3, line + 3); ctx.lineTo(pt + 3, line - 3); } else { ctx.moveTo(line - 3, pt + 3); ctx.lineTo(line + 3, pt - 3); } ctx.stroke(); });
      for (var i = 1; i < vals.length; i++) {
        var txt = ftIn(vals[i] - vals[i - 1]), mid = (pts[i] + pts[i - 1]) / 2, gap = Math.abs(pts[i] - pts[i - 1]), tw = ctx.measureText(txt).width;
        if (gap < tw + 6) continue;
        ctx.save(); if (horiz) ctx.translate(mid, line - 7); else { ctx.translate(line - 7, mid); ctx.rotate(-Math.PI / 2); }
        ctx.fillStyle = "rgba(255,255,255,.85)"; ctx.fillRect(-tw / 2 - 2, -6, tw + 4, 12); ctx.fillStyle = C.string; ctx.fillText(txt, 0, 0); ctx.restore();
      }
    };
    run(xs, true, top); run([minX, maxX], true, top2);
    run(ys, false, left); run([minY, maxY], false, left2);
    ctx.restore();
  };

  // To-scale PDF on letter landscape with a title block. jsPDF is loaded on first use.
  P.exportPDF = function () {
    var self = this;
    var go = function () {
      var jsPDF = window.jspdf && window.jspdf.jsPDF;
      if (!jsPDF) return alert("The PDF library could not be loaded (offline?). Use PNG instead.");
      var pageW = 11, pageH = 8.5, m = 0.5, tb = 0.85, availW = pageW - 2 * m, availH = pageH - 2 * m - tb - 0.1;
      var padFt = 3, W = self.widthFt + padFt * 2, H = self.depthFt + padFt * 2;
      var scales = [[1 / 4, '1/4" = 1\'-0"'], [3 / 16, '3/16" = 1\'-0"'], [1 / 8, '1/8" = 1\'-0"'], [3 / 32, '3/32" = 1\'-0"'], [1 / 16, '1/16" = 1\'-0"'], [1 / 32, '1/32" = 1\'-0"']];
      var pick = scales.filter(function (sc) { return W * sc[0] <= availW && H * sc[0] <= availH; })[0] || scales[scales.length - 1];
      var inPerFt = pick[0], pxPerFt = inPerFt * 150;
      var url = self.snapshot(pxPerFt, padFt * pxPerFt, { strings: true, jpeg: true });
      var imgW = W * inPerFt, imgH = H * inPerFt;
      var doc = new jsPDF({ orientation: "landscape", unit: "in", format: "letter" });
      doc.addImage(url, "JPEG", m + (availW - imgW) / 2, m + (availH - imgH) / 2, imgW, imgH);
      var y = pageH - m - tb, total = 0; self.data.rooms.forEach(function (r) { total += r.w * r.h; });
      doc.setLineWidth(0.012); doc.rect(m, y, availW, tb); doc.line(m + 5.2, y, m + 5.2, y + tb); doc.line(m + 7.4, y, m + 7.4, y + tb);
      doc.setFont("helvetica", "bold"); doc.setFontSize(15); doc.text(self.opts.name || "Floor plan", m + 0.15, y + 0.38);
      doc.setFont("helvetica", "normal"); doc.setFontSize(9.5); doc.text([self.opts.concept || "", self.opts.level || ""].filter(Boolean).join("  ·  "), m + 0.15, y + 0.62);
      doc.setFontSize(8); doc.text("SCALE", m + 5.35, y + 0.25); doc.text("AREA", m + 5.35, y + 0.55); doc.text("DATE", m + 7.55, y + 0.25); doc.text("SHEET", m + 7.55, y + 0.55);
      doc.setFontSize(10); doc.text(pick[1], m + 5.95, y + 0.25); doc.text(Math.round(total).toLocaleString() + " sq ft", m + 5.95, y + 0.55);
      doc.text(new Date().toLocaleDateString(), m + 8.15, y + 0.25); doc.text("A-1", m + 8.15, y + 0.55);
      doc.setFontSize(7); doc.setTextColor(120); doc.text("CONCEPTUAL FLOOR PLAN — NOT FOR CONSTRUCTION", m + availW - 0.15, y + 0.75, { align: "right" }); doc.setTextColor(0);
      doc.save((self.opts.name || "floor-plan").replace(/[^\w-]+/g, "_") + ".pdf");
    };
    if (window.jspdf) return go();
    self.setStatus("Loading PDF library…");
    var sc = document.createElement("script"); sc.src = "https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js";
    sc.onload = function () { self.setStatus(self.dirty ? "Unsaved changes" : "Ready"); go(); };
    sc.onerror = function () { self.setStatus("Ready"); alert("The PDF library could not be loaded (offline?). Use PNG instead."); };
    document.head.appendChild(sc);
  };

  P.tooltip = function (ctx, at, lines, cw) {
    var fonts = ["600 12px system-ui, sans-serif", "12px system-ui, sans-serif", "11px system-ui, sans-serif"], tw = 0;
    lines.forEach(function (l, i) { ctx.font = fonts[Math.min(i, 2)]; tw = Math.max(tw, ctx.measureText(l).width); });
    tw += 16; var th = 10 + lines.length * 15, tx = Math.min(at.x + 14, cw - tw - 4), ty = Math.max(at.y - th - 6, 4);
    ctx.fillStyle = "rgba(31,42,55,.92)"; ctx.beginPath(); ctx.rect(tx, ty, tw, th); ctx.fill();
    ctx.textAlign = "left"; ctx.textBaseline = "middle";
    lines.forEach(function (l, i) { ctx.fillStyle = i === 2 ? "#c9d1dc" : "#fff"; ctx.font = fonts[Math.min(i, 2)]; ctx.fillText(l, tx + 8, ty + 12 + i * 15); });
  };

  P.drawRoofPlan = function (ctx, rf, S, s, selected) {
    var o = rf.overhang != null ? rf.overhang : 1.5, x0 = rf.x - o, x1 = rf.x + rf.w + o, y0 = rf.y - o, y1 = rf.y + rf.h + o;
    var A = S(x0, y0), B = S(x1, y1), W = B.x - A.x, H = B.y - A.y, col = selected ? C.sel : C.roof;
    ctx.save();
    ctx.fillStyle = selected ? C.selFill : C.roofFill; ctx.fillRect(A.x, A.y, W, H);
    ctx.strokeStyle = col; ctx.lineWidth = selected ? 1.6 : 1.1; ctx.strokeRect(A.x, A.y, W, H);
    ctx.setLineDash([3, 3]); ctx.lineWidth = 1; var I = S(rf.x, rf.y), J = S(rf.x + rf.w, rf.y + rf.h); ctx.strokeRect(I.x, I.y, J.x - I.x, J.y - I.y); ctx.setLineDash([]);   // the covered area (without overhang)
    ctx.lineWidth = 1.2;
    var alongX = rf.ridge === "x" || (rf.ridge !== "y" && W >= H), cx = (A.x + B.x) / 2, cy = (A.y + B.y) / 2;
    var line = function (a, b, c, d2) { ctx.beginPath(); ctx.moveTo(a, b); ctx.lineTo(c, d2); ctx.stroke(); };
    if (rf.style === "hip") {
      var half = Math.min(W, H) / 2;
      if (alongX) { line(A.x + half, cy, B.x - half, cy); line(A.x, A.y, A.x + half, cy); line(A.x, B.y, A.x + half, cy); line(B.x, A.y, B.x - half, cy); line(B.x, B.y, B.x - half, cy); }
      else { line(cx, A.y + half, cx, B.y - half); line(A.x, A.y, cx, A.y + half); line(B.x, A.y, cx, A.y + half); line(A.x, B.y, cx, B.y - half); line(B.x, B.y, cx, B.y - half); }
    } else if (rf.style === "gable") {
      if (alongX) line(A.x, cy, B.x, cy); else line(cx, A.y, cx, B.y);
    } else if (rf.style === "shed") {
      var hs = rf.high || "n", from = { n: [cx, A.y + 8], s: [cx, B.y - 8], w: [A.x + 8, cy], e: [B.x - 8, cy] }[hs], to = { n: [cx, B.y - 8], s: [cx, A.y + 8], w: [B.x - 8, cy], e: [A.x + 8, cy] }[hs];
      line(from[0], from[1], to[0], to[1]);
      var ang = Math.atan2(to[1] - from[1], to[0] - from[0]); ctx.beginPath(); ctx.moveTo(to[0], to[1]); ctx.lineTo(to[0] - 7 * Math.cos(ang - 0.4), to[1] - 7 * Math.sin(ang - 0.4)); ctx.lineTo(to[0] - 7 * Math.cos(ang + 0.4), to[1] - 7 * Math.sin(ang + 0.4)); ctx.closePath(); ctx.fillStyle = col; ctx.fill();
    }
    if (W > 60 && H > 24) {
      var tag = (ROOF_KINDS.filter(function (k) { return k[0] === rf.style; })[0] || [rf.style, rf.style])[1].replace(/ \(.*\)/, "") + (rf.style !== "flat" ? " " + (rf.pitch || 6) + ":12" : "");
      ctx.font = "10px system-ui, sans-serif"; ctx.textAlign = "left"; ctx.textBaseline = "top"; var tw = ctx.measureText(tag).width;
      ctx.fillStyle = "rgba(255,255,255,.8)"; ctx.fillRect(A.x + 4, A.y + 4, tw + 6, 14); ctx.fillStyle = col; ctx.fillText(tag, A.x + 7, A.y + 6);
    }
    ctx.restore();
  };

  P.fitText = function (ctx, text, maxW) {
    text = String(text || ""); if (ctx.measureText(text).width <= maxW) return text;
    while (text.length > 1 && ctx.measureText(text + "…").width > maxW) text = text.slice(0, -1);
    return text + "…";
  };
  // dimension text offset to one side of segment a→b (side = ±1), in screen px
  P.dimText = function (ctx, a, b, text, side, gap, color) {
    var dx = b.x - a.x, dy = b.y - a.y, L = Math.hypot(dx, dy) || 1, nx = -dy / L, ny = dx / L, off = (gap || 8) + 7;
    var mx = (a.x + b.x) / 2 + nx * side * off, my = (a.y + b.y) / 2 + ny * side * off, ang = Math.atan2(dy, dx);
    if (ang > Math.PI / 2 || ang < -Math.PI / 2) ang += Math.PI;
    ctx.save(); ctx.translate(mx, my); ctx.rotate(ang);
    ctx.font = "11px system-ui, sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
    var w = ctx.measureText(text).width; ctx.fillStyle = "rgba(255,255,255,.85)"; ctx.fillRect(-w / 2 - 3, -8, w + 6, 16);
    ctx.fillStyle = color || C.dim; ctx.fillText(text, 0, 0); ctx.restore();
  };

  // Offscreen render (thumbnail / PNG export). Returns a data URL.
  P.snapshot = function (pxPerFt, pad, xo) {
    xo = xo || {};
    var w = Math.ceil(this.widthFt * pxPerFt + pad * 2), h = Math.ceil(this.depthFt * pxPerFt + pad * 2);
    var cv = document.createElement("canvas"); cv.width = w; cv.height = h;
    var ctx = cv.getContext("2d"), savedSel = this.sel, savedCtx = this.ctx;
    this.setSel(null); this.ctx = ctx;
    this.draw(ctx, w, h, { scale: pxPerFt, x: pad, y: pad }, { grid: false, ui: false, strings: !!xo.strings });
    this.setSel(savedSel); this.ctx = savedCtx;
    return xo.jpeg ? cv.toDataURL("image/jpeg", 0.85) : cv.toDataURL("image/png");
  };
  P.exportPNG = function () {
    var px = clamp(Math.floor(2400 / Math.max(this.widthFt, this.depthFt)), 8, 40);
    download((this.opts.name || "floor-plan").replace(/[^\w-]+/g, "_") + ".png", this.snapshot(px, 60, { strings: true }));
  };
  P.importJSON = function (file) {
    if (!file) return; var self = this, rd = new FileReader();
    rd.onload = function () {
      try { var parsed = JSON.parse(rd.result); if (!parsed || typeof parsed !== "object") throw new Error("not an object"); }
      catch (e) { alert("That file is not a floor plan JSON export."); return; }
      if (!confirm("Replace the current drawing with the imported plan? (Undo is available.)")) return;
      self.commit(function () { self.data = normalize(parsed); self.setSel(null); });
    };
    rd.readAsText(file);
  };

  // ---------------------------------------------------------------- save
  P.save = function (auto) {
    var self = this; if (this.saving) return;
    this.saving = true; this.setStatus(auto ? "Autosaving…" : "Saving…");
    var thumbPx = clamp(Math.floor(640 / Math.max(this.widthFt, this.depthFt)), 2, 20);
    var body = { design_floor_plan: { data: this.data, thumbnail_data: this.snapshot(thumbPx, 12, {}) } };
    fetch(this.opts.saveUrl, { method: "PATCH", credentials: "same-origin", headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": this.opts.csrf }, body: JSON.stringify(body) })
      .then(function (r) { return r.json().then(function (j) { return { ok: r.ok && j.ok, j: j }; }); })
      .then(function (res) {
        self.saving = false;
        if (res.ok) { self.dirty = false; self.setStatus("Saved " + res.j.saved_at); }
        else { self.setStatus("Save failed: " + ((res.j && res.j.errors) || []).join(", ")); }
      })
      .catch(function (e) { self.saving = false; self.setStatus("Save failed (offline?)"); });
  };

  window.FloorPlanEditor = { mount: function (root, opts) { return new Editor(root, opts); } };
})();
