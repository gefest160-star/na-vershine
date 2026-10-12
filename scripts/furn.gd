class_name F
extends RefCounted
## Мебель и реквизит из примитивов. Локальная +Z — «лицо» предмета.


static func node(parent: Node, x: float, z: float, rot: float = 0.0, y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(x, y, z)
	n.rotation.y = rot
	parent.add_child(n)
	return n


static func fcol(lv: Level, x: float, z: float, w: float, d: float, h: float, rot: float = 0.0) -> void:
	if absf(sin(rot)) > 0.5:
		var tmp := w
		w = d
		d = tmp
	B.col(lv, Vector3(x, h / 2.0, z), Vector3(w, h, d))


static func table(lv: Level, x: float, z: float, rot: float = 0.0, o: Dictionary = {}) -> Node3D:
	var w: float = o.get("w", 1.4)
	var d: float = o.get("d", 0.85)
	var h: float = o.get("h", 0.76)
	var hex: int = o.get("color", 0x6b4a2f)
	var n := node(lv, x, z, rot)
	if o.get("glass", false):
		B.box(n, Vector3(w, 0.04, d), Vector3(0, h - 0.02, 0), 0, {"mat": B.glass_mat(0xbfdcea, 0.3)})
	else:
		B.box(n, Vector3(w, 0.07, d), Vector3(0, h - 0.035, 0), hex, {"rough": o.get("rough", 0.7)})
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B.box(n, Vector3(0.08, h - 0.07, 0.08), Vector3(sx * (w / 2.0 - 0.1), (h - 0.07) / 2.0, sz * (d / 2.0 - 0.1)), o.get("legs", hex))
	if o.get("solid", true):
		fcol(lv, x, z, w, d, h, rot)
	return n


static func round_table(lv: Level, x: float, z: float, o: Dictionary = {}) -> Node3D:
	var r: float = o.get("r", 0.65)
	var h: float = 0.76
	var n := node(lv, x, z)
	B.cyl(n, 0.07, 0.07, h, Vector3(0, h / 2.0, 0), 0x2a2522, 6)
	B.cyl(n, 0.3, 0.34, 0.05, Vector3(0, 0.025, 0), 0x2a2522, 8)
	B.cyl(n, r, r, 0.05, Vector3(0, h, 0), o.get("cloth", 0xf1ece0), 10, {"rough": 0.95})
	B.cyl(n, r + 0.01, r + 0.12, 0.32, Vector3(0, h - 0.16, 0), o.get("cloth", 0xf1ece0), 10, {"rough": 0.95})
	fcol(lv, x, z, r * 1.5, r * 1.5, h)
	return n


static func chair(lv: Node, x: float, z: float, rot: float = 0.0, o: Dictionary = {}) -> Node3D:
	var hex: int = o.get("color", 0x5a3d28)
	var seat: int = o.get("seat", hex)
	var n := node(lv, x, z, rot)
	B.box(n, Vector3(0.46, 0.06, 0.46), Vector3(0, 0.45, 0), seat)
	B.box(n, Vector3(0.46, 0.55, 0.06), Vector3(0, 0.76, -0.21), hex)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			B.box(n, Vector3(0.05, 0.42, 0.05), Vector3(sx * 0.19, 0.21, sz * 0.19), hex)
	return n


static func stool(lv: Node, x: float, z: float, hex: int = 0x3a2a22) -> void:
	var n := node(lv, x, z)
	B.cyl(n, 0.04, 0.04, 0.72, Vector3(0, 0.36, 0), 0x777777, 6, {"metal": 0.8, "rough": 0.4})
	B.cyl(n, 0.2, 0.2, 0.07, Vector3(0, 0.75, 0), hex, 8)
	B.cyl(n, 0.2, 0.22, 0.03, Vector3(0, 0.015, 0), 0x777777, 8, {"metal": 0.8, "rough": 0.4})


static func bed(lv: Level, x: float, z: float, rot: float = 0.0, o: Dictionary = {}) -> Node3D:
	var w: float = o.get("w", 1.5)
	var n := node(lv, x, z, rot)
	var frame: int = o.get("frame", 0x4a3424)
	B.box(n, Vector3(w, 0.3, 2.1), Vector3(0, 0.15, 0), frame)
	B.box(n, Vector3(w, 0.95, 0.1), Vector3(0, 0.475, -1.05), frame)
	B.box(n, Vector3(w - 0.08, 0.2, 2.0), Vector3(0, 0.4, 0), o.get("mattress", 0xe6dfd0))
	if not o.get("bare", false):
		B.box(n, Vector3(0.55, 0.12, 0.36), Vector3(-w * 0.22 if w > 1.7 else 0.0, 0.56, -0.74), o.get("pillow", 0xf4f0e6))
		if w > 1.7:
			B.box(n, Vector3(0.55, 0.12, 0.36), Vector3(w * 0.22, 0.56, -0.74), o.get("pillow", 0xf4f0e6))
		var bl := B.box(n, Vector3(w - 0.04, 0.09, 1.3), Vector3(0, 0.53, 0.33), o.get("blanket", 0xb5613f))
		if o.get("messy", false):
			bl.rotation = Vector3(0.03, 0.22, 0.04)
			bl.position += Vector3(0.12, 0.02, 0.1)
	fcol(lv, x, z, w, 2.1, 0.7, rot)
	return n


static func sofa(lv: Level, x: float, z: float, rot: float = 0.0, o: Dictionary = {}) -> Node3D:
	var w: float = o.get("w", 2.2)
	var hex: int = o.get("color", 0x3d2b24)
	var n := node(lv, x, z, rot)
	B.box(n, Vector3(w, 0.32, 0.9), Vector3(0, 0.24, 0), hex, {"rough": 0.6})
	B.box(n, Vector3(w, 0.62, 0.22), Vector3(0, 0.62, -0.34), hex, {"rough": 0.6})
	B.box(n, Vector3(0.2, 0.5, 0.9), Vector3(-w / 2.0 + 0.1, 0.46, 0), hex, {"rough": 0.6})
	B.box(n, Vector3(0.2, 0.5, 0.9), Vector3(w / 2.0 - 0.1, 0.46, 0), hex, {"rough": 0.6})
	var cush: int = o.get("cushion", hex)
	var cn := maxi(1, int(round((w - 0.4) / 0.85)))
	var cw := (w - 0.44) / float(cn)
	for i in cn:
		B.box(n, Vector3(cw - 0.04, 0.12, 0.64), Vector3(-w / 2.0 + 0.22 + cw * (float(i) + 0.5), 0.46, 0.1), cush, {"rough": 0.65})
	for sx in [-1.0, 1.0]:
		B.box(n, Vector3(0.08, 0.08, 0.8), Vector3(sx * (w / 2.0 - 0.12), 0.04, 0), 0x1a1614)
	fcol(lv, x, z, w, 0.9, 0.8, rot)
	return n


static func wardrobe(lv: Level, x: float, z: float, rot: float = 0.0, o: Dictionary = {}) -> Node3D:
	var w: float = o.get("w", 1.3)
	var h: float = o.get("h", 2.1)
	var hex: int = o.get("color", 0x553a28)
	var n := node(lv, x, z, rot)
	B.box(n, Vector3(w, h, 0.6), Vector3(0, h / 2.0, 0), hex)
	var door: int = o.get("door", 0x62442f)
	B.box(n, Vector3(w / 2.0 - 0.05, h - 0.2, 0.03), Vector3(-w / 4.0, h / 2.0, 0.305), door)
	B.box(n, Vector3(w / 2.0 - 0.05, h - 0.2, 0.03), Vector3(w / 4.0, h / 2.0, 0.305), door)
	B.box(n, Vector3(0.03, 0.14, 0.03), Vector3(-0.06, h / 2.0, 0.33), 0xc9a45a, {"metal": 0.8, "rough": 0.3})
	B.box(n, Vector3(0.03, 0.14, 0.03), Vector3(0.06, h / 2.0, 0.33), 0xc9a45a, {"metal": 0.8, "rough": 0.3})
	fcol(lv, x, z, w, 0.6, h, rot)
	return n


static func bookcase(lv: Level, x: float, z: float, rot: float = 0.0, o: Dictionary = {}) -> Node3D:
	var w: float = o.get("w", 1.6)
	var h: float = o.get("h", 2.2)
	var hex: int = o.get("color", 0x3d2a1e)
	var fill: float = o.get("fill", 0.85)
	var n := node(lv, x, z, rot)
	B.box(n, Vector3(w, h, 0.04), Vector3(0, h / 2.0, -0.16), hex)
	B.box(n, Vector3(0.05, h, 0.36), Vector3(-w / 2.0 + 0.025, h / 2.0, 0), hex)
	B.box(n, Vector3(0.05, h, 0.36), Vector3(w / 2.0 - 0.025, h / 2.0, 0), hex)
	var rows := int(h / 0.42)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x * 131.0 + z * 977.0 + w * 13.0) + 7
	var palette: Array = o.get("books", [0x7a2e2e, 0x2e4a6a, 0x3f5c3a, 0x8a6a2e, 0x4a3a5a, 0x2a2a2a, 0x9a8a70])
	for r in rows + 1:
		var y := 0.03 + float(r) * (h - 0.06) / float(rows)
		B.box(n, Vector3(w - 0.1, 0.04, 0.34), Vector3(0, y, 0), hex)
		if r == rows:
			break
		var cx := -w / 2.0 + 0.1
		while cx < w / 2.0 - 0.16:
			var bw := rng.randf_range(0.04, 0.09)
			var bh := rng.randf_range(0.22, 0.34)
			if rng.randf() < fill:
				var bk := B.box(n, Vector3(bw, bh, 0.22), Vector3(cx + bw / 2.0, y + 0.02 + bh / 2.0, 0.0), palette[rng.randi() % palette.size()])
				if rng.randf() < 0.08:
					bk.rotation.z = 0.25
			else:
				cx += rng.randf_range(0.05, 0.25)
			cx += bw + 0.005
	fcol(lv, x, z, w, 0.4, h, rot)
	return n


static func desk(lv: Level, x: float, z: float, rot: float = 0.0, o: Dictionary = {}) -> Node3D:
	var w: float = o.get("w", 1.8)
	var d: float = o.get("d", 0.85)
	var hex: int = o.get("color", 0x4a3020)
	var n := node(lv, x, z, rot)
	B.box(n, Vector3(w, 0.07, d), Vector3(0, 0.76, 0), hex, {"rough": 0.55})
	for sx in [-1.0, 1.0]:
		B.box(n, Vector3(0.46, 0.72, d - 0.1), Vector3(sx * (w / 2.0 - 0.26), 0.36, 0), hex)
		for i in 3:
			B.box(n, Vector3(0.4, 0.19, 0.02), Vector3(sx * (w / 2.0 - 0.26), 0.13 + float(i) * 0.23, -(d - 0.1) / 2.0 - 0.01), o.get("drawer", 0x5a3c28))
			B.box(n, Vector3(0.1, 0.025, 0.03), Vector3(sx * (w / 2.0 - 0.26), 0.13 + float(i) * 0.23, -(d - 0.1) / 2.0 - 0.03), 0xc9a45a, {"metal": 0.8, "rough": 0.3})
	B.box(n, Vector3(w - 0.9, 0.5, 0.04), Vector3(0, 0.48, d / 2.0 - 0.1), hex)
	fcol(lv, x, z, w, d, 0.8, rot)
	return n


static func counter(lv: Level, x: float, z: float, rot: float = 0.0, o: Dictionary = {}) -> Node3D:
	var w: float = o.get("w", 2.4)
	var d: float = o.get("d", 0.62)
	var h: float = o.get("h", 0.9)
	var n := node(lv, x, z, rot)
	B.box(n, Vector3(w, h - 0.05, d), Vector3(0, (h - 0.05) / 2.0, 0), o.get("color", 0x6a6258))
	B.box(n, Vector3(w + 0.04, 0.05, d + 0.04), Vector3(0, h - 0.025, 0), o.get("top", 0x2c2a28), {"rough": 0.4})
	var cn := maxi(1, int(w / 0.6))
	for i in cn:
		var cx := -w / 2.0 + w * (float(i) + 0.5) / float(cn)
		B.box(n, Vector3(w / float(cn) - 0.06, h - 0.2, 0.02), Vector3(cx, (h - 0.05) / 2.0, d / 2.0 + 0.005), o.get("door", 0x7a7166))
		B.box(n, Vector3(0.03, 0.12, 0.03), Vector3(cx + w / float(cn) / 2.0 - 0.1, h - 0.28, d / 2.0 + 0.03), 0xbbbbbb, {"metal": 0.8, "rough": 0.3})
	fcol(lv, x, z, w, d, h, rot)
	return n


## Торшер. Возвращает OmniLight3D.
static func floor_lamp(lv: Level, x: float, z: float, o: Dictionary = {}) -> OmniLight3D:
	var hex: int = o.get("color", 0xffd9a0)
	var e: float = o.get("energy", 1.2)
	var n := node(lv, x, z)
	B.cyl(n, 0.16, 0.19, 0.04, Vector3(0, 0.02, 0), 0x2a2622, 8, {"metal": 0.6, "rough": 0.4})
	B.cyl(n, 0.02, 0.02, 1.5, Vector3(0, 0.77, 0), 0x2a2622, 6, {"metal": 0.6, "rough": 0.4})
	var gm := B.glow_mat(hex, 1.2 + e)
	B.cyl(n, 0.15, 0.27, 0.32, Vector3(0, 1.62, 0), hex, 8, {"mat": gm})
	var l := B.omni(n, Vector3(0, 1.55, 0), hex, e, o.get("range", 7.0), o.get("shadow", false))
	if o.get("flicker", 0.0) > 0.0:
		lv.add_flicker(l, o.get("flicker"), gm)
	return l


## Настольная лампа на parent (в его локальных координатах).
static func table_lamp(lv: Level, parent: Node, pos: Vector3, o: Dictionary = {}) -> OmniLight3D:
	var hex: int = o.get("color", 0xffd9a0)
	var shade: int = o.get("shade", hex)
	var e: float = o.get("energy", 0.8)
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	B.cyl(n, 0.08, 0.1, 0.03, Vector3(0, 0.015, 0), 0xb08d4a, 8, {"metal": 0.7, "rough": 0.35})
	B.cyl(n, 0.015, 0.015, 0.28, Vector3(0, 0.16, 0), 0xb08d4a, 6, {"metal": 0.7, "rough": 0.35})
	var gm := B.glow_mat(shade, 1.0 + e)
	B.cyl(n, 0.09, 0.16, 0.16, Vector3(0, 0.36, 0), shade, 8, {"mat": gm})
	var l := B.omni(n, Vector3(0, 0.3, 0), hex, e, o.get("range", 5.0), o.get("shadow", false))
	if o.get("flicker", 0.0) > 0.0:
		lv.add_flicker(l, o.get("flicker"), gm)
	return l


## Подвесной светильник от потолка.
static func pendant(lv: Level, x: float, z: float, y: float, o: Dictionary = {}) -> OmniLight3D:
	var hex: int = o.get("color", 0xffd9a0)
	var e: float = o.get("energy", 1.4)
	var n := node(lv, x, z)
	B.box(n, Vector3(0.02, lv.h - y, 0.02), Vector3(0, (lv.h + y) / 2.0, 0), 0x1a1816, {"noshadow": true})
	B.cyl(n, 0.08, 0.3, 0.2, Vector3(0, y + 0.08, 0), o.get("shade", 0x2a2622), 8, {"noshadow": true})
	var gm := B.glow_mat(hex, 1.5 + e)
	B.ball(n, 0.08, Vector3(0, y - 0.03, 0), hex, 6, 3, {"mat": gm, "noshadow": true})
	var l := B.omni(n, Vector3(0, y - 0.15, 0), hex, e, o.get("range", 9.0), o.get("shadow", true))
	if o.get("flicker", 0.0) > 0.0:
		lv.add_flicker(l, o.get("flicker"), gm)
	return l


static func chandelier(lv: Level, x: float, z: float, y: float, o: Dictionary = {}) -> OmniLight3D:
	var hex: int = o.get("color", 0xffe2b0)
	var e: float = o.get("energy", 2.4)
	var r: float = o.get("r", 0.8)
	var gold := 0xc9a45a
	var n := node(lv, x, z)
	B.box(n, Vector3(0.03, lv.h - y, 0.03), Vector3(0, (lv.h + y) / 2.0, 0), gold, {"metal": 0.8, "rough": 0.3, "noshadow": true})
	B.cyl(n, 0.1, 0.22, 0.3, Vector3(0, y + 0.1, 0), gold, 8, {"metal": 0.8, "rough": 0.3, "noshadow": true})
	B.cyl(n, r, r, 0.04, Vector3(0, y - 0.1, 0), gold, 10, {"metal": 0.8, "rough": 0.3, "noshadow": true})
	var gm := B.glow_mat(hex, 2.0 + e)
	var cnt: int = o.get("bulbs", 8)
	for i in cnt:
		var a := TAU * float(i) / float(cnt)
		B.cyl(n, 0.025, 0.03, 0.14, Vector3(cos(a) * r, y, sin(a) * r), 0xf4efe0, 6, {"noshadow": true})
		B.ball(n, 0.05, Vector3(cos(a) * r, y + 0.1, sin(a) * r), hex, 6, 3, {"mat": gm, "noshadow": true})
	var l := B.omni(n, Vector3(0, y - 0.3, 0), hex, e, o.get("range", 14.0), true)
	if o.get("flicker", 0.0) > 0.0:
		lv.add_flicker(l, o.get("flicker"), gm)
	return l


static func plant(lv: Level, x: float, z: float, o: Dictionary = {}) -> void:
	var state: int = o.get("state", 0)   # 0 живое, 1 вянет, 2 мёртвое
	var n := node(lv, x, z)
	B.cyl(n, 0.24, 0.17, 0.36, Vector3(0, 0.18, 0), o.get("pot", 0x9a5a3c), 8)
	B.cyl(n, 0.21, 0.21, 0.03, Vector3(0, 0.36, 0), 0x2a1e16, 8)
	var leaf: int = [0x3f7a3a, 0x7a7a3a, 0x5a4630][state]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x * 31.0 + z * 17.0) + 3
	var cnt: int = [7, 5, 3][state]
	for i in cnt:
		var a := TAU * float(i) / float(cnt) + rng.randf() * 0.5
		var tilt := rng.randf_range(0.25, 0.6) + float(state) * 0.35
		var ln := rng.randf_range(0.5, 0.95) - float(state) * 0.12
		var lf := Node3D.new()
		lf.position = Vector3(0, 0.38, 0)
		lf.rotation = Vector3(0, a, 0)
		n.add_child(lf)
		var st := Node3D.new()
		st.rotation.x = tilt
		lf.add_child(st)
		B.cyl(st, 0.0, 0.09, ln, Vector3(0, ln / 2.0, 0), leaf, 4)
	fcol(lv, x, z, 0.4, 0.4, 0.8)


static func rug(parent: Node, x: float, z: float, w: float, d: float, hex: int, border: int = -1) -> void:
	if border >= 0:
		B.box(parent, Vector3(w, 0.016, d), Vector3(x, 0.008, z), border, {"noshadow": true, "rough": 1.0})
		B.box(parent, Vector3(w - 0.3, 0.02, d - 0.3), Vector3(x, 0.01, z), hex, {"noshadow": true, "rough": 1.0})
	else:
		B.box(parent, Vector3(w, 0.02, d), Vector3(x, 0.01, z), hex, {"noshadow": true, "rough": 1.0})


## Картина на стене: рама и «абстрактный» холст из цветных блоков.
static func painting(lv: Level, side: String, u: float, v: float, w: float, h: float, cols: Array, frame: int = 0x7a5a2e) -> void:
	var p: Node3D = lv.walls[side]
	B.box(p, B.wall_size(side, w + 0.12, h + 0.12, 0.05), B.wall_pos(lv, side, u, v, 0.025), frame, {"rough": 0.5, "metal": 0.3})
	B.box(p, B.wall_size(side, w, h, 0.02), B.wall_pos(lv, side, u, v, 0.055), cols[0])
	if cols.size() > 1:
		B.box(p, B.wall_size(side, w * 0.45, h * 0.5, 0.012), B.wall_pos(lv, side, u - w * 0.16, v + h * 0.1, 0.068), cols[1])
	if cols.size() > 2:
		B.box(p, B.wall_size(side, w * 0.3, h * 0.3, 0.012), B.wall_pos(lv, side, u + w * 0.2, v - h * 0.18, 0.07), cols[2])
	if cols.size() > 3:
		B.box(p, B.wall_size(side, w * 0.8, h * 0.06, 0.012), B.wall_pos(lv, side, u, v - h * 0.36, 0.072), cols[3])


static func mirror(lv: Level, side: String, u: float, v: float, w: float, h: float) -> void:
	var p: Node3D = lv.walls[side]
	B.box(p, B.wall_size(side, w + 0.1, h + 0.1, 0.05), B.wall_pos(lv, side, u, v, 0.025), 0x3a2a1e)
	B.box(p, B.wall_size(side, w, h, 0.02), B.wall_pos(lv, side, u, v, 0.055), 0xaebfca, {"rough": 0.08, "metal": 0.95})


static func curtains(lv: Level, side: String, u: float, w: float, y0: float, y1: float, hex: int) -> void:
	var p: Node3D = lv.walls[side]
	var ht := y1 - y0 + 0.3
	for sx in [-1.0, 1.0]:
		for i in 3:
			B.box(p, B.wall_size(side, 0.14, ht, 0.1), B.wall_pos(lv, side, u + sx * (w / 2.0 + 0.05 + float(i) * 0.13), y0 + ht / 2.0 - 0.1, 0.08 + float(i % 2) * 0.03), hex, {"rough": 1.0})
	B.box(p, B.wall_size(side, w + 1.0, 0.06, 0.08), B.wall_pos(lv, side, u, y1 + 0.2, 0.08), 0x2a2622)


static func blinds(lv: Level, side: String, u: float, w: float, y0: float, y1: float, hex: int = 0xcfc8b8) -> void:
	var p: Node3D = lv.walls[side]
	var n := int((y1 - y0) / 0.14)
	for i in n:
		var sl := B.box(p, B.wall_size(side, w - 0.06, 0.012, 0.09), B.wall_pos(lv, side, u, y0 + 0.07 + float(i) * 0.14, 0.02), hex)
		if B._horiz(side):
			sl.rotation.x = 0.5
		else:
			sl.rotation.z = 0.5


## Дверь на стене. Возвращает точку перед дверью (внутри комнаты).
static func door(lv: Level, side: String, u: float, o: Dictionary = {}) -> Vector3:
	var p: Node3D = lv.walls[side]
	var hex: int = o.get("color", 0x4a3020)
	var w: float = o.get("w", 1.05)
	var h: float = o.get("h", 2.25)
	B.box(p, B.wall_size(side, w + 0.2, h + 0.1, 0.08), B.wall_pos(lv, side, u, (h + 0.1) / 2.0, 0.02), o.get("frame", 0x2a1e16))
	B.box(p, B.wall_size(side, w, h, 0.06), B.wall_pos(lv, side, u, h / 2.0, 0.07), hex, {"rough": 0.6})
	B.box(p, B.wall_size(side, w - 0.3, h * 0.36, 0.02), B.wall_pos(lv, side, u, h * 0.72, 0.105), o.get("panel", hex - 0x0a0806 if hex > 0x101010 else hex), {"rough": 0.6})
	B.box(p, B.wall_size(side, w - 0.3, h * 0.36, 0.02), B.wall_pos(lv, side, u, h * 0.27, 0.105), o.get("panel", hex - 0x0a0806 if hex > 0x101010 else hex), {"rough": 0.6})
	B.ball(p, 0.045, B.wall_pos(lv, side, u + w / 2.0 - 0.14, 1.05, 0.14), 0xc9a45a, 6, 3, {"metal": 0.9, "rough": 0.25})
	return B.wall_pos(lv, side, u, 0.0, 0.85)


static func fireplace(lv: Level, side: String, u: float, o: Dictionary = {}) -> void:
	var p: Node3D = lv.walls[side]
	var stone: int = o.get("color", 0x4a4640)
	var w: float = o.get("w", 2.4)
	var h: float = o.get("h", 1.5)
	B.box(p, B.wall_size(side, 0.4, h, 0.6), B.wall_pos(lv, side, u - w / 2.0 + 0.2, h / 2.0, 0.3), stone)
	B.box(p, B.wall_size(side, 0.4, h, 0.6), B.wall_pos(lv, side, u + w / 2.0 - 0.2, h / 2.0, 0.3), stone)
	B.box(p, B.wall_size(side, w + 0.3, 0.22, 0.75), B.wall_pos(lv, side, u, h + 0.11, 0.37), o.get("mantel", 0x2a1e16))
	B.box(p, B.wall_size(side, w - 0.8, h, 0.08), B.wall_pos(lv, side, u, h / 2.0, 0.04), 0x0c0a09)
	B.box(p, B.wall_size(side, w + 0.2, 0.08, 0.9), B.wall_pos(lv, side, u, 0.04, 0.45), stone)
	B.box(p, B.wall_size(side, w, lv.h - h - 0.22, 0.3), B.wall_pos(lv, side, u, (lv.h + h + 0.22) / 2.0, 0.15), o.get("chimney", stone))
	var pos := B.wall_pos(lv, side, u, 0.0, 0.3)
	B.col(lv, Vector3(pos.x, 1.0, pos.z), B.wall_size(side, w + 0.2, 2.0, 0.9))
	if o.get("lit", true):
		var gm := B.glow_mat(0xff7a2a, 3.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 5:
			var fl := B.cyl(p, 0.0, 0.11, rng.randf_range(0.3, 0.6), B.wall_pos(lv, side, u + rng.randf_range(-0.4, 0.4), 0.35, 0.3 + rng.randf_range(-0.08, 0.08)), 0xff7a2a, 4, {"mat": gm, "noshadow": true})
			fl.set_meta("flame", rng.randf() * 10.0)
			lv.updaters.append(func(_dt): fl.scale.y = 0.75 + 0.35 * sin(lv.t * 9.0 + float(fl.get_meta("flame"))))
		B.box(p, B.wall_size(side, 0.9, 0.12, 0.14), B.wall_pos(lv, side, u, 0.14, 0.3), 0x1a100a)
		var l := B.omni(p, B.wall_pos(lv, side, u, 0.6, 0.8), 0xff8a3a, o.get("energy", 2.2), 9.0, true)
		lv.add_flicker(l, 0.35, gm)


static func column(lv: Level, x: float, z: float, hex: int = 0xd8d2c4, r: float = 0.3) -> void:
	var n := node(lv, x, z)
	B.box(n, Vector3(r * 2.6, 0.3, r * 2.6), Vector3(0, 0.15, 0), hex)
	B.cyl(n, r, r * 1.1, lv.h - 0.6, Vector3(0, lv.h / 2.0, 0), hex, 10)
	B.box(n, Vector3(r * 2.6, 0.3, r * 2.6), Vector3(0, lv.h - 0.15, 0), hex)
	fcol(lv, x, z, r * 2.2, r * 2.2, lv.h)


static func bottle(parent: Node, pos: Vector3, hex: int = 0x2f5a3a, lying: bool = false) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	B.cyl(n, 0.04, 0.04, 0.2, Vector3(0, 0.1, 0), hex, 6, {"rough": 0.2})
	B.cyl(n, 0.015, 0.035, 0.1, Vector3(0, 0.25, 0), hex, 6, {"rough": 0.2})
	if lying:
		n.rotation = Vector3(0, randf() * TAU, PI / 2.0)
		n.position.y += 0.04
	return n


static func glass(parent: Node, pos: Vector3) -> void:
	B.cyl(parent, 0.035, 0.025, 0.1, pos + Vector3(0, 0.05, 0), 0, 6, {"mat": B.glass_mat(0xdfeef5, 0.35), "noshadow": true})


static func plate(parent: Node, pos: Vector3) -> void:
	B.cyl(parent, 0.14, 0.1, 0.025, pos + Vector3(0, 0.012, 0), 0xf7f4ec, 10, {"rough": 0.3})


static func papers(parent: Node, pos: Vector3, n: int = 4, spread: float = 0.3, seed_v: int = 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in n:
		var p := B.box(parent, Vector3(0.21, 0.004, 0.3), pos + Vector3(rng.randf_range(-spread, spread), 0.003 + float(i) * 0.004, rng.randf_range(-spread, spread)), 0xe9e4d6, {"noshadow": true})
		p.rotation.y = rng.randf() * TAU


static func envelope(parent: Node, pos: Vector3, hex: int = 0xd9c9a0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	B.box(n, Vector3(0.26, 0.012, 0.17), Vector3.ZERO, hex)
	B.cyl(n, 0.022, 0.022, 0.006, Vector3(0, 0.009, 0), 0x9a1f1f, 8)
	return n


static func phone(parent: Node, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	B.box(n, Vector3(0.22, 0.08, 0.18), Vector3(0, 0.04, 0), 0x151515, {"rough": 0.35})
	B.cyl(n, 0.06, 0.06, 0.012, Vector3(0, 0.086, 0.02), 0xd8d2c4, 10)
	B.box(n, Vector3(0.26, 0.05, 0.06), Vector3(0, 0.13, -0.04), 0x151515, {"rough": 0.35})
	B.box(n, Vector3(0.06, 0.05, 0.05), Vector3(-0.1, 0.1, -0.04), 0x151515, {"rough": 0.35})
	B.box(n, Vector3(0.06, 0.05, 0.05), Vector3(0.1, 0.1, -0.04), 0x151515, {"rough": 0.35})
	return n


static func pistol(parent: Node, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	B.box(n, Vector3(0.24, 0.04, 0.045), Vector3(0.02, 0.022, 0), 0x1b1b1f, {"rough": 0.35, "metal": 0.8})
	B.box(n, Vector3(0.09, 0.04, 0.13), Vector3(-0.06, 0.022, 0.08), 0x2a1c14, {"rough": 0.6})
	return n


static func crate(lv: Level, x: float, z: float, s: float = 0.7, hex: int = 0x6a4f34, rot: float = 0.0) -> Node3D:
	var n := node(lv, x, z, rot)
	B.box(n, Vector3(s, s, s), Vector3(0, s / 2.0, 0), hex)
	B.box(n, Vector3(s + 0.03, 0.07, s + 0.03), Vector3(0, s - 0.035, 0), hex - 0x101008)
	B.box(n, Vector3(s + 0.03, 0.07, s + 0.03), Vector3(0, 0.035, 0), hex - 0x101008)
	fcol(lv, x, z, s, s, s)
	return n


static func bench(lv: Level, x: float, z: float, rot: float = 0.0, w: float = 2.6, hex: int = 0x5a3d28) -> void:
	var n := node(lv, x, z, rot)
	B.box(n, Vector3(w, 0.07, 0.5), Vector3(0, 0.45, 0), hex)
	B.box(n, Vector3(w, 0.5, 0.07), Vector3(0, 0.78, -0.24), hex)
	for sx in [-1.0, 0.0, 1.0]:
		B.box(n, Vector3(0.07, 0.45, 0.5), Vector3(sx * (w / 2.0 - 0.06), 0.225, 0), 0x2a2622)
	fcol(lv, x, z, w, 0.55, 0.9, rot)


## Рояль — знак дорогого интерьера.
static func piano(lv: Level, x: float, z: float, rot: float = 0.0) -> void:
	var n := node(lv, x, z, rot)
	var blk := 0x0e0e10
	B.box(n, Vector3(1.5, 0.28, 1.9), Vector3(0, 0.86, 0), blk, {"rough": 0.15, "metal": 0.3})
	var lid := B.box(n, Vector3(1.5, 0.04, 1.7), Vector3(-0.3, 1.32, 0.1), blk, {"rough": 0.15, "metal": 0.3})
	lid.rotation.z = -0.5
	B.box(n, Vector3(1.3, 0.05, 0.26), Vector3(0, 0.74, -1.05), 0xf2efe6, {"rough": 0.3})
	B.box(n, Vector3(1.5, 0.12, 0.3), Vector3(0, 0.66, -1.05), blk, {"rough": 0.15})
	for p in [Vector3(-0.6, 0.36, -0.8), Vector3(0.6, 0.36, -0.8), Vector3(0, 0.36, 0.8)]:
		B.box(n, Vector3(0.1, 0.72, 0.1), p, blk)
	B.box(n, Vector3(0.7, 0.07, 0.36), Vector3(0, 0.46, -1.6), 0x2a1616)
	B.box(n, Vector3(0.08, 0.46, 0.3), Vector3(-0.3, 0.23, -1.6), blk)
	B.box(n, Vector3(0.08, 0.46, 0.3), Vector3(0.3, 0.23, -1.6), blk)
	fcol(lv, x, z, 1.6, 2.3, 1.0, rot)


static func candle(lv: Level, parent: Node, pos: Vector3, lit: bool = true) -> void:
	B.cyl(parent, 0.02, 0.02, 0.2, pos + Vector3(0, 0.1, 0), 0xf2efe6, 6)
	if lit:
		B.ball(parent, 0.03, pos + Vector3(0, 0.24, 0), 0xffc060, 4, 2, {"mat": B.glow_mat(0xffc060, 4.0), "noshadow": true})
