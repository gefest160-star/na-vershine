class_name B
extends RefCounted
## Статические помощники: материалы, примитивы с плоским шейдингом, стены с окнами.

const WALL_T := 0.2

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _tex: Dictionary = {}
## Множитель яркости ламп: в тёмных главах лампы светят сильнее, чтобы сцена читалась.
static var light_mul: float = 1.0


static func C(hex: int, a: float = 1.0) -> Color:
	return Color(((hex >> 16) & 0xFF) / 255.0, ((hex >> 8) & 0xFF) / 255.0, (hex & 0xFF) / 255.0, a)


static func mat(hex: int, rough: float = 0.9, emit: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var key := "%d|%.2f|%.2f|%.2f" % [hex, rough, emit, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = C(hex)
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = C(hex)
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


## Отдельный (некешируемый) светящийся материал — для ламп, которые мерцают.
static func glow_mat(hex: int, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = C(hex)
	m.emission_enabled = true
	m.emission = C(hex)
	m.emission_energy_multiplier = energy
	return m


static func glass_mat(hex: int = 0x9fc4d8, alpha: float = 0.14) -> StandardMaterial3D:
	var key := "glass%d|%.2f" % [hex, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = C(hex, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


## Материал с текстурой (пол в клетку, доски). scale — число повторов.
static func tex_mat(tex: Texture2D, scale: Vector2, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = Vector3(scale.x, scale.y, 1.0)
	m.roughness = rough
	m.metallic = metal
	return m


static func tex_checker(a: int, b: int) -> ImageTexture:
	var key := "chk%d|%d" % [a, b]
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, C(a))
	img.set_pixel(1, 1, C(a))
	img.set_pixel(1, 0, C(b))
	img.set_pixel(0, 1, C(b))
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


## Полосы-доски: n оттенков вокруг базового цвета.
static func tex_planks(hex: int, n: int = 16, variation: float = 0.07) -> ImageTexture:
	var key := "plk%d|%d" % [hex, n]
	if _tex.has(key):
		return _tex[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hex + n
	var img := Image.create(n, 1, false, Image.FORMAT_RGB8)
	var base := C(hex)
	for i in n:
		var k := 1.0 + rng.randf_range(-variation, variation)
		img.set_pixel(i, 0, Color(clampf(base.r * k, 0, 1), clampf(base.g * k, 0, 1), clampf(base.b * k, 0, 1)))
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


## Фасад дома: сетка окон, часть горит. Возвращает [albedo, emission].
static func tex_facade(seed_v: int, lit: float, wall: int, win_dark: int, win_lit: int) -> Array:
	var key := "fac%d|%.2f|%d" % [seed_v, lit, wall]
	if _tex.has(key):
		return _tex[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var cw := 4
	var chh := 5
	var nx := 8
	var ny := 12
	var img := Image.create(nx * cw, ny * chh, false, Image.FORMAT_RGB8)
	var em := Image.create(nx * cw, ny * chh, false, Image.FORMAT_RGB8)
	img.fill(C(wall))
	em.fill(Color.BLACK)
	for ix in nx:
		for iy in ny:
			var is_lit := rng.randf() < lit
			var col := C(win_lit) if is_lit else C(win_dark)
			for px in range(1, cw - 1):
				for py in range(1, chh - 2):
					img.set_pixel(ix * cw + px, iy * chh + py, col)
					if is_lit:
						em.set_pixel(ix * cw + px, iy * chh + py, C(win_lit))
	var res := [ImageTexture.create_from_image(img), ImageTexture.create_from_image(em)]
	_tex[key] = res
	return res


# ---------- Примитивы ----------

static func _inst(parent: Node, mesh: Mesh, pos: Vector3, hex: int, o: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if o.has("mat"):
		mi.material_override = o["mat"]
	else:
		mi.material_override = mat(hex, o.get("rough", 0.9), o.get("emit", 0.0), o.get("metal", 0.0))
	mi.position = pos
	if o.has("rot"):
		mi.rotation = o["rot"]
	if o.get("noshadow", false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func box(parent: Node, size: Vector3, pos: Vector3, hex: int, o: Dictionary = {}) -> MeshInstance3D:
	var key := "b%.3f,%.3f,%.3f" % [size.x, size.y, size.z]
	var mesh: Mesh = _meshes.get(key)
	if mesh == null:
		var bm := BoxMesh.new()
		bm.size = size
		mesh = bm
		_meshes[key] = mesh
	return _inst(parent, mesh, pos, hex, o)


## Гранёный цилиндр / усечённый конус.
static func cyl(parent: Node, r_top: float, r_bot: float, height: float, pos: Vector3, hex: int, sides: int = 8, o: Dictionary = {}) -> MeshInstance3D:
	var key := "c%.3f,%.3f,%.3f,%d" % [r_top, r_bot, height, sides]
	var mesh: Mesh = _meshes.get(key)
	if mesh == null:
		var cm := CylinderMesh.new()
		cm.top_radius = r_top
		cm.bottom_radius = r_bot
		cm.height = height
		cm.radial_segments = sides
		cm.rings = 1
		mesh = flat(cm)
		_meshes[key] = mesh
	return _inst(parent, mesh, pos, hex, o)


## Гранёная сфера (seg x rings). seg=4, rings=1 даёт октаэдр.
static func ball(parent: Node, r: float, pos: Vector3, hex: int, seg: int = 8, rings: int = 4, o: Dictionary = {}) -> MeshInstance3D:
	var key := "s%.3f,%d,%d" % [r, seg, rings]
	var mesh: Mesh = _meshes.get(key)
	if mesh == null:
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = seg
		sm.rings = rings
		mesh = flat(sm)
		_meshes[key] = mesh
	return _inst(parent, mesh, pos, hex, o)


## Пересобирает меш с нормалями по граням (low-poly вид).
static func flat(src: PrimitiveMesh) -> ArrayMesh:
	var arr := src.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	for i in range(0, idx.size(), 3):
		var a := verts[idx[i]]
		var b := verts[idx[i + 1]]
		var c := verts[idx[i + 2]]
		var n := (c - a).cross(b - a)
		if n.length_squared() < 1e-12:
			continue
		n = n.normalized()
		var avg := norms[idx[i]] + norms[idx[i + 1]] + norms[idx[i + 2]]
		if n.dot(avg) < 0.0:
			n = -n
		nv.append(a)
		nv.append(b)
		nv.append(c)
		nn.append(n)
		nn.append(n)
		nn.append(n)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = nv
	out[Mesh.ARRAY_NORMAL] = nn
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return am


static func col(lv: Level, center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center
	lv.body.add_child(cs)


static func omni(parent: Node, pos: Vector3, hex: int, energy: float, rng: float, shadow: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = C(hex)
	l.light_energy = energy * light_mul
	l.omni_range = rng
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadow
	l.light_volumetric_fog_energy = 0.6
	parent.add_child(l)
	return l


static func spot(parent: Node, pos: Vector3, dir: Vector3, hex: int, energy: float, rng: float, angle: float = 35.0, shadow: bool = true) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.position = pos
	var up := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD
	l.basis = Basis.looking_at(dir.normalized(), up)
	l.light_color = C(hex)
	l.light_energy = energy * light_mul
	l.spot_range = rng
	l.spot_angle = angle
	l.shadow_enabled = shadow
	l.light_volumetric_fog_energy = 1.5
	parent.add_child(l)
	return l


static func label(parent: Node, text: String, pos: Vector3, rot_y: float, px: int = 48, hex: int = 0xffffff, pixel: float = 0.005) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = px
	l.pixel_size = pixel
	l.modulate = C(hex)
	l.outline_size = 0
	l.position = pos
	l.rotation.y = rot_y
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(l)
	return l


# ---------- Стены ----------

static func _horiz(side: String) -> bool:
	return side == "back" or side == "front"


static func _sign(side: String) -> float:
	return -1.0 if (side == "back" or side == "left") else 1.0


## Точка на внутренней поверхности стены: u — вдоль стены (x для back/front, z для left/right), v — высота.
static func wall_pos(lv: Level, side: String, u: float, v: float, inset: float = 0.0) -> Vector3:
	var s := _sign(side)
	if _horiz(side):
		return Vector3(u, v, s * (lv.d / 2.0 - inset))
	return Vector3(s * (lv.w / 2.0 - inset), v, u)


static func wall_size(side: String, wd: float, ht: float, depth: float) -> Vector3:
	if _horiz(side):
		return Vector3(wd, ht, depth)
	return Vector3(depth, ht, wd)


## Поворот предмета, «смотрящего» из стены внутрь комнаты (локальная +Z — в комнату).
static func wall_rot(side: String) -> float:
	match side:
		"back":
			return 0.0
		"front":
			return PI
		"left":
			return PI / 2.0
		_:
			return -PI / 2.0


## Стена с проёмами. openings: [{x, w, y0, y1}] — x вдоль стены.
static func wall(lv: Level, side: String, hex: int, openings: Array = [], trim_hex: int = -1, trim_h: float = 0.12) -> void:
	var t := WALL_T
	var horiz := _horiz(side)
	var length: float = lv.w if horiz else lv.d
	var half := length / 2.0
	var parent: Node3D = lv.walls[side]
	var s := _sign(side)
	var off: float = s * ((lv.d if horiz else lv.w) / 2.0 + t / 2.0)
	var ext: float = t if horiz else 0.0
	var ops := openings.duplicate()
	ops.sort_custom(func(a, b): return a.x < b.x)
	var segs: Array = []
	var cur := -half - ext
	for op in ops:
		var a: float = op.x - op.w / 2.0
		var b: float = op.x + op.w / 2.0
		segs.append([cur, a, 0.0, lv.h])
		segs.append([a, b, 0.0, op.y0])
		segs.append([a, b, op.y1, lv.h])
		cur = b
		_window(lv, side, op)
	segs.append([cur, half + ext, 0.0, lv.h])
	for sg in segs:
		var du: float = sg[1] - sg[0]
		var dv: float = sg[3] - sg[2]
		if du < 0.01 or dv < 0.01:
			continue
		var uc: float = (sg[0] + sg[1]) / 2.0
		var vc: float = (sg[2] + sg[3]) / 2.0
		if horiz:
			box(parent, Vector3(du, dv, t), Vector3(uc, vc, off), hex)
		else:
			box(parent, Vector3(t, dv, du), Vector3(off, vc, uc), hex)
	if horiz:
		col(lv, Vector3(0, lv.h / 2.0, off), Vector3(length + 2.0 * t, lv.h, t))
	else:
		col(lv, Vector3(off, lv.h / 2.0, 0), Vector3(t, lv.h, length))
	# плинтус / панели
	if trim_hex >= 0:
		cur = -half
		for op in ops:
			var a2: float = op.x - op.w / 2.0
			var b2: float = op.x + op.w / 2.0
			var lim: float = minf(trim_h, op.y0)
			_trim(lv, side, cur, a2, trim_h, trim_hex)
			if lim > 0.02:
				_trim(lv, side, a2, b2, lim, trim_hex)
			cur = b2
		_trim(lv, side, cur, half, trim_h, trim_hex)


static func _trim(lv: Level, side: String, u0: float, u1: float, ht: float, hex: int) -> void:
	if u1 - u0 < 0.02:
		return
	box(lv.walls[side], wall_size(side, u1 - u0, ht, 0.05), wall_pos(lv, side, (u0 + u1) / 2.0, ht / 2.0, 0.025), hex)


static func _window(lv: Level, side: String, op: Dictionary) -> void:
	var parent: Node3D = lv.walls[side]
	var wd: float = op.w
	var ht: float = op.y1 - op.y0
	var yc: float = (op.y0 + op.y1) / 2.0
	var frame: int = op.get("frame", 0x2a2622)
	var mid := -WALL_T / 2.0   # середина толщины стены
	var gl := box(parent, wall_size(side, wd, ht, 0.03), wall_pos(lv, side, op.x, yc, mid), 0, {"mat": glass_mat(), "noshadow": true})
	gl.set_meta("cut_hide", true)
	var th := 0.07
	var dp := WALL_T + 0.06
	box(parent, wall_size(side, wd + th, th, dp), wall_pos(lv, side, op.x, op.y1, mid), frame)
	box(parent, wall_size(side, wd + 0.2, th, dp + 0.14), wall_pos(lv, side, op.x, op.y0, mid + 0.05), frame)
	box(parent, wall_size(side, th, ht, dp), wall_pos(lv, side, op.x - wd / 2.0, yc, mid), frame)
	box(parent, wall_size(side, th, ht, dp), wall_pos(lv, side, op.x + wd / 2.0, yc, mid), frame)
	var n: int = op.get("mullions", maxi(0, int(round(wd / 1.5)) - 1))
	for i in n:
		var u: float = op.x - wd / 2.0 + wd * float(i + 1) / float(n + 1)
		box(parent, wall_size(side, 0.05, ht, 0.08), wall_pos(lv, side, u, yc, mid), frame)
	if op.get("cross", false):
		box(parent, wall_size(side, wd, 0.05, 0.08), wall_pos(lv, side, op.x, yc, mid), frame)


## Пол, невидимый потолок (только тени) и четыре стены.
static func shell(lv: Level, wall_hex: int, floor_mat: Material, o: Dictionary = {}) -> void:
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(lv.w, lv.d)
	fl.mesh = pm
	fl.material_override = floor_mat
	lv.add_child(fl)
	box(lv, Vector3(lv.w + 0.4, 0.3, lv.d + 0.4), Vector3(0, -0.16, 0), o.get("base", 0x1a1816))
	var ceil := box(lv, Vector3(lv.w + 0.6, 0.2, lv.d + 0.6), Vector3(0, lv.h + 0.1, 0), 0x000000)
	ceil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var trim: int = o.get("trim", 0x2a2622)
	var th: float = o.get("trim_h", 0.12)
	for side in ["back", "front", "left", "right"]:
		wall(lv, side, o.get("wall_" + side, wall_hex), o.get("win_" + side, []), trim, th)
	col(lv, Vector3(0, -0.5, 0), Vector3(lv.w + 2.0, 1.0, lv.d + 2.0))
