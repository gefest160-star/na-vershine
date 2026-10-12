class_name Levels
extends RefCounted
## Сборка всех локаций кодом. Вид локации зависит от главы (Game.chapter).


static func build(id: String) -> Level:
	match id:
		"apartment":
			return apartment()
		"restaurant":
			return restaurant()
		"station":
			return station()
		"penthouse":
			return penthouse()
		"gromov":
			return gromov()
		"shop":
			return shop()
		"tower":
			return tower()
		"reiner":
			return reiner()
		"mansion":
			return mansion()
		"pier":
			return pier()
		"cabinet":
			return cabinet()
	push_error("Неизвестная локация: " + id)
	return apartment()


# ---------- Общие помощники ----------

static func _planks(hex: int, w: float, rough: float = 0.8) -> Material:
	return B.tex_mat(B.tex_planks(hex), Vector2(w / 4.0, 1.0), rough)


static func _checker(a: int, b: int, w: float, d: float, tile: float = 1.0, rough: float = 0.45) -> Material:
	return B.tex_mat(B.tex_checker(a, b), Vector2(w / (2.0 * tile), d / (2.0 * tile)), rough)


static func patron_style() -> Dictionary:
	var ch: int = Game.chapter
	var suit: int = [0, 0xe6dcc2, 0xa2a4a8, 0x3c3d44, 0x141416, 0x0c0c0e][ch]
	var tie: int = [0, 0xb8862e, 0x6a2a2a, 0x7a1f1f, 0x9a1414, 0xf2efe6][ch]
	return {"skin": 0xcfa184, "hair": 0xcfcfcf, "shirt": 0xf2efe6, "coat": suit, "pants": suit, "tie": tie, "shoes": 0x0a0a0a, "scale": 1.04}


static func thug_style(n: int) -> Dictionary:
	if n == 1:
		return {"skin": 0xc98f6c, "shirt": 0x3a3a3a, "coat": 0x5a4a32, "pants": 0x2a2a2e, "cap": 0x33302a, "hair": 0x1a1410, "scale": 1.1}
	return {"skin": 0xd4a078, "shirt": 0x4a2a2a, "coat": 0x3a4a3a, "pants": 0x2a2620, "hair": 0x6a4a2a, "beard": 0x6a4a2a, "scale": 1.06}


static func _seat(lv: Level, id: String, cfg: Dictionary, x: float, z: float, rot: float, label: String = "", chair_o: Dictionary = {}) -> Human:
	F.chair(lv, x, z, rot, chair_o)
	var hm := Human.new(cfg)
	hm.pose = "sit"
	lv.add_npc(id, hm, Vector3(x, 0, z), rot, label, 1.9, false)
	return hm


static func _exit(lv: Level, side: String, u: float, o: Dictionary = {}) -> void:
	var dp := F.door(lv, side, u, o)
	lv.add_inter("exit", Story.exit_label, dp, 1.6, 2.75)
	var inward := -B._sign(side) * 0.35
	if B._horiz(side):
		lv.spawn = dp + Vector3(0, 0, inward)
		lv.spawn_rot = 0.0 if side == "back" else PI
	else:
		lv.spawn = dp + Vector3(inward, 0, 0)
		lv.spawn_rot = PI / 2.0 if side == "left" else -PI / 2.0


## Город за окнами: дома с окнами, чем позже глава — тем темнее и тем больше огней.
static func city(lv: Level, elev: float, o: Dictionary = {}) -> void:
	var ch: int = Game.chapter
	var wd: Dictionary = Game.W()
	var day := ch == 1
	var wall_c: int = 0xb8b0a2 if day else (0x59606a if ch == 2 else 0x1b1f26)
	var win_d: int = 0x5c6b78 if day else 0x12161c
	var lit: float = wd.lit * lerpf(1.6, 1.0, lv.light_scale)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + absi(lv.id.hash()) % 1000
	var mats: Array = []
	for i in 5:
		var tx: Array = B.tex_facade(ch * 100 + i, lit, wall_c, win_d, 0xffd08a)
		var m := StandardMaterial3D.new()
		m.albedo_texture = tx[0]
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		m.roughness = 0.9
		if lit > 0.0:
			m.emission_enabled = true
			m.emission = Color.BLACK
			m.emission_texture = tx[1]
			m.emission_energy_multiplier = 2.2
		mats.append(m)
	var root := Node3D.new()
	lv.add_child(root)
	var z0: float = o.get("z0", -lv.d / 2.0 - 16.0)
	var count: int = o.get("count", 44)
	var depth: float = o.get("depth", 62.0)
	for i in count:
		var bw := rng.randf_range(5.0, 11.0)
		var bd := rng.randf_range(5.0, 10.0)
		var bh := rng.randf_range(10.0, 44.0) * float(o.get("hmul", 1.0))
		var x := rng.randf_range(-78.0, 78.0)
		var z := z0 - rng.randf_range(0.0, depth)
		var m2: StandardMaterial3D = (mats[i % 5] as StandardMaterial3D).duplicate()
		m2.uv1_scale = Vector3(3.0 * maxf(1.0, round(bw / 8.0)), 2.0 * maxf(1.0, round(bh / 14.0)), 1.0)
		B.box(root, Vector3(bw, bh + 4.0, bd), Vector3(x, (bh - 4.0) / 2.0 - elev, z), 0, {"mat": m2, "noshadow": true})
	if o.get("ground", true):
		B.box(root, Vector3(500, 0.4, 500), Vector3(0, -elev - 0.62, 0), 0x34373c if day else 0x121417, {"noshadow": true, "rough": 0.35 if not day else 0.9})


# ---------- Квартира героя (хаб) ----------

static func apartment() -> Level:
	var ch: int = Game.chapter
	if ch >= 5:
		return _apartment_lux()
	var wd: Dictionary = Game.W()
	var lv := Level.new("apartment", 9.0, 8.0, 3.4)
	lv.cam_dist = 8.0
	var wall_c: int = [0, 0xd9c8a3, 0xb3a58b, 0x7f786d, 0x57534e][ch]
	var floor_c: int = [0, 0x9a6b42, 0x83603f, 0x604b39, 0x463b31][ch]
	B.shell(lv, wall_c, _planks(floor_c, 9.0), {"win_back": [{"x": 0.6, "w": 4.2, "y0": 1.0, "y1": 2.75, "cross": true}], "trim": 0x3a2c22})
	city(lv, 12.0)
	_exit(lv, "right", 2.6)
	if ch <= 3:
		F.curtains(lv, "back", 0.6, 4.2, 1.0, 2.75, [0, 0xb5613f, 0x8a5a48, 0x4f4a48][ch])

	# кровать и тумба с телефоном
	F.bed(lv, -3.4, -2.8, 0.0, {"blanket": [0, 0xb5613f, 0x8f5a44, 0x55504c, 0][ch], "bare": ch == 4, "messy": ch >= 2,
		"mattress": 0xe6dfd0 if ch < 4 else 0x9a9486})
	lv.add_inter("bed", "Кровать", Vector3(-2.75, 0, -2.5), 1.5, 1.5)
	var dresser := F.table(lv, -1.75, -3.6, 0.0, {"w": 1.1, "d": 0.5, "h": 0.62, "color": 0x5a3d28})
	F.phone(dresser, Vector3(0.3, 0.62, 0.0))
	lv.add_inter("phone", "Телефон", Vector3(-1.45, 0, -3.5), 1.5, 1.35)
	if ch <= 2:
		F.table_lamp(lv, dresser, Vector3(-0.35, 0.62, 0), {"color": wd.bulb, "energy": 0.9 * wd.bulb_e, "range": 4.5})
	lv.add_inter("window", "Окно", Vector3(1.4, 0, -3.6), 1.4, 3.0)

	# шкаф, зеркало
	if ch <= 3:
		F.wardrobe(lv, -4.15, 0.2, PI / 2.0)
	F.mirror(lv, "left", 2.2, 1.45, 0.6, 1.3)
	lv.add_inter("mirror", "Зеркало", Vector3(-4.2, 0, 2.2), 1.5, 2.4)

	# стол
	var tb := F.table(lv, 1.5, 0.6, 0.0, {"w": 1.3, "d": 0.85, "color": 0x6b4a2f})
	lv.add_inter("table", Story.table_label, Vector3(1.5, 0, 0.6), 1.7, 1.5)
	if ch <= 3:
		F.chair(lv, 1.5, -0.25, 0.0)
	if ch <= 2:
		F.chair(lv, 1.5, 1.45, PI)
	if ch == 4:
		var fallen := F.chair(lv, 0.1, 1.9, 0.7)
		fallen.rotation.x = PI / 2.0
		fallen.position.y = 0.24

	# кухонный угол, фотография
	var cn := F.counter(lv, 4.15, -1.7, -PI / 2.0, {"w": 2.6})
	B.box(cn, Vector3(0.5, 0.03, 0.4), Vector3(-0.7, 0.92, 0), 0x1a1a1c)
	B.cyl(cn, 0.1, 0.12, 0.2, Vector3(-0.7, 1.03, 0), 0x8a8a90, 8, {"metal": 0.8, "rough": 0.3})
	B.cyl(cn, 0.12, 0.1, 0.14, Vector3(0.6, 0.97, 0.05), 0xb9b2a4, 8)
	if ch <= 3:
		F.painting(lv, "right", -1.7, 1.75, 0.3, 0.38, [0xd8c9a8, 0x6a5a4a, 0x8a3a3a], 0x2a2018)
		lv.add_inter("photo", "Фотография", Vector3(3.9, 0, -1.7), 1.35, 2.3)
	F.bookcase(lv, 3.55, -3.78, 0.0, {"w": 1.2, "h": 1.9, "fill": [0, 0.9, 0.75, 0.4, 0.1][ch]})

	# свет
	var pe: float = [0.0, 1.5, 1.0, 0.8, 1.2][ch]
	if ch >= 3:
		B.omni(lv, Vector3(0.6, 2.0, -3.0), 0x8fa6d0, 0.8 if ch == 3 else 1.0, 9.0)
	F.pendant(lv, 0.2, 0.4, 2.5, {"color": wd.bulb, "energy": pe, "range": 9.0, "flicker": [0.0, 0.0, 0.0, 0.12, 0.6][ch]})
	if ch <= 2:
		F.floor_lamp(lv, -3.9, 1.1, {"color": wd.bulb, "energy": 1.0 * wd.bulb_e, "range": 5.5})
	elif ch == 3:
		F.floor_lamp(lv, -3.9, 1.1, {"color": 0x3a3632, "energy": 0.0})

	# уют, который уходит
	if ch <= 3:
		F.rug(lv, 0.1, 0.9, 3.4, 2.3, [0, 0x9b3d2e, 0x7d4034, 0x4a403c][ch], [0, 0x5a2018, 0x4a2a22, 0x2e2826][ch])
		F.plant(lv, -3.9, 3.4, {"state": ch - 1})
	match ch:
		1:
			F.plate(tb, Vector3(-0.2, 0.76, 0.05))
			F.glass(tb, Vector3(0.15, 0.76, -0.1))
			B.cyl(tb, 0.05, 0.07, 0.16, Vector3(0.42, 0.84, 0.2), 0x4a7a9a, 8)
			B.ball(tb, 0.08, Vector3(0.42, 0.98, 0.2), 0xd8a03a, 6, 3)
			F.painting(lv, "left", -1.9, 1.9, 0.9, 0.6, [0x9fc4d8, 0xe8d8a0, 0x5a8a5a], 0x6a4a2a)
		2:
			F.papers(tb, Vector3(0, 0.76, 0), 5, 0.3, 3)
			B.cyl(tb, 0.045, 0.04, 0.09, Vector3(0.4, 0.8, -0.2), 0xe6dfd0, 8)
			F.papers(lv, Vector3(-0.8, 0.02, 1.9), 3, 0.5, 5)
			F.painting(lv, "left", -1.9, 1.9, 0.9, 0.6, [0x8fa8b4, 0xc8bc94, 0x5a705a], 0x6a4a2a)
		3:
			F.bottle(tb, Vector3(-0.35, 0.76, 0.1))
			F.bottle(tb, Vector3(-0.15, 0.76, -0.2), 0x5a3a1e)
			F.bottle(tb, Vector3(0.45, 0.76, 0.25), 0x2f5a3a, true)
			F.glass(tb, Vector3(0.0, 0.76, 0.2))
			F.envelope(tb, Vector3(0.25, 0.775, -0.1), 0xe9e4d6)
			B.box(lv, Vector3(1.7, 0.012, 1.1), Vector3(-1.2, 0.006, 2.2), 0x33291f, {"noshadow": true, "rough": 0.15})
			F.painting(lv, "left", -1.9, 1.9, 0.9, 0.6, [0x4a5258, 0x3a3a3a], 0x3a2a1a)
		4:
			F.envelope(tb, Vector3(0.0, 0.775, 0.0), 0xe9e4d6)
			F.bottle(tb, Vector3(-0.4, 0.76, 0.2), 0x5a3a1e)
			for p in [Vector3(-1.5, 0, 1.2), Vector3(-0.3, 0, 2.6), Vector3(0.6, 0, -1.4), Vector3(2.6, 0, 2.0), Vector3(-2.2, 0, 0.1), Vector3(-2.4, 0, -1.2)]:
				F.bottle(lv, p, [0x2f5a3a, 0x5a3a1e][int(absf(p.x * 10.0)) % 2], true)
			F.papers(lv, Vector3(0, 0.02, 1.0), 12, 2.6, 9)
			B.box(lv, Vector3(2.2, 0.012, 1.5), Vector3(-1.0, 0.006, 2.0), 0x241d17, {"noshadow": true, "rough": 0.12})
			# трещины на стене
			for cr in [[-2.9, 2.2, 0.9, 0.5], [-2.5, 2.6, 0.6, -0.7], [3.3, 2.9, 0.7, 0.9], [3.6, 2.5, 0.5, -0.3]]:
				var c := B.box(lv.walls["back"], Vector3(cr[2], 0.025, 0.02), B.wall_pos(lv, "back", cr[0], cr[1], 0.01), 0x26221f, {"noshadow": true})
				c.rotation.z = cr[3]
	return lv


static func _apartment_lux() -> Level:
	var wd: Dictionary = Game.W()
	var lv := Level.new("apartment", 13.0, 10.0, 4.2)
	lv.cam_dist = 9.5
	B.shell(lv, 0x383a44, _checker(0xd6d2ca, 0xc2beb6, 13.0, 10.0, 1.0, 0.34), {"win_back": [{"x": 0.0, "w": 10.6, "y0": 0.25, "y1": 3.8, "mullions": 5}], "trim": 0x101114})
	city(lv, 60.0, {"hmul": 2.3})
	_exit(lv, "right", 3.4, {"color": 0x121316, "frame": 0xc9a45a})
	F.rug(lv, 0.2, 0.6, 5.2, 3.6, 0x2c2d34, 0x16171b)
	F.sofa(lv, 0.2, 1.7, PI, {"w": 3.2, "color": 0x141417, "cushion": 0x1c1c21})
	var gt := F.table(lv, 0.2, -0.1, 0.0, {"w": 1.6, "d": 0.8, "h": 0.45, "glass": true, "legs": 0xc9a45a})
	F.envelope(gt, Vector3(0, 0.46, 0), 0xe8c070)
	lv.add_inter("table", Story.table_label, Vector3(0.2, 0, -0.1), 1.7, 1.3)
	F.bed(lv, -4.9, -3.6, 0.0, {"w": 2.0, "frame": 0x121316, "blanket": 0x1b1c22, "pillow": 0xe9e6e0, "mattress": 0xdedad2})
	lv.add_inter("bed", "Кровать", Vector3(-3.7, 0, -3.3), 1.5, 1.5)
	F.wardrobe(lv, -6.15, 0.4, PI / 2.0, {"w": 2.2, "h": 2.6, "color": 0x101114, "door": 0x17181c})
	F.mirror(lv, "left", 2.9, 1.6, 1.0, 2.2)
	lv.add_inter("mirror", "Зеркало", Vector3(-6.2, 0, 2.9), 1.6, 3.1)
	var cons := F.table(lv, 6.1, -0.9, PI / 2.0, {"w": 1.4, "d": 0.45, "h": 0.85, "color": 0x121316, "legs": 0xc9a45a})
	F.phone(cons, Vector3(0.3, 0.85, 0))
	F.table_lamp(lv, cons, Vector3(-0.4, 0.85, 0), {"color": wd.bulb, "energy": 0.7, "range": 5.0})
	lv.add_inter("phone", "Телефон", Vector3(5.7, 0, -1.2), 1.4, 1.6)
	F.piano(lv, 3.9, -2.9, 0.4)
	lv.add_inter("window", "Окно", Vector3(-0.8, 0, -4.6), 1.5, 3.6)
	F.floor_lamp(lv, -2.6, 2.9, {"color": wd.bulb, "energy": 1.2, "range": 7.0})
	F.floor_lamp(lv, 5.8, 2.2, {"color": wd.bulb, "energy": 1.0, "range": 6.0})
	F.chandelier(lv, 0.2, 0.6, 3.3, {"color": 0xf2e6d0, "energy": 1.5, "r": 0.7, "bulbs": 6, "range": 12.0})
	F.painting(lv, "left", -2.3, 2.3, 2.4, 1.5, [0x0e0e10, 0x8a1c1c, 0xc9a45a], 0xc9a45a)
	# постамент с «искусством»
	B.box(lv, Vector3(0.5, 1.0, 0.5), Vector3(-2.6, 0.5, -3.9), 0x15161a)
	B.ball(lv, 0.24, Vector3(-2.6, 1.3, -3.9), 0xc9a45a, 5, 2, {"metal": 0.9, "rough": 0.25})
	F.fcol(lv, -2.6, -3.9, 0.5, 0.5, 1.4)
	return lv


# ---------- Ресторан «Золотой фазан» ----------

static func restaurant() -> Level:
	var wd: Dictionary = Game.W()
	var lv := Level.new("restaurant", 18.0, 13.0, 4.8)
	lv.ambience = "restaurant"
	lv.cam_dist = 9.5
	var wins: Array = []
	for x in [-5.6, 0.0, 5.6]:
		wins.append({"x": x, "w": 4.0, "y0": 0.7, "y1": 4.0, "mullions": 2, "cross": true})
	B.shell(lv, 0xd9c39a, _checker(0xe9e2d0, 0x2c2a2e, 18.0, 13.0, 1.0, 0.3), {"win_back": wins, "trim": 0x4a2f20, "trim_h": 0.7})
	city(lv, 0.0)
	for x in [-5.6, 0.0, 5.6]:
		F.curtains(lv, "back", x, 4.0, 0.7, 4.0, 0x7a1f24)
	_exit(lv, "right", 4.4, {"color": 0x3a2418, "w": 1.3, "h": 2.5})

	# бар
	var bar := F.counter(lv, -8.0, -2.4, PI / 2.0, {"w": 5.0, "d": 0.8, "h": 1.1, "color": 0x3a2418, "top": 0x1a1412, "door": 0x4a2f20})
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for sh in [1.5, 2.1, 2.7]:
		B.box(lv.walls["left"], B.wall_size("left", 4.6, 0.05, 0.3), B.wall_pos(lv, "left", -2.4, sh, 0.15), 0x2a1a10)
		for i in 14:
			F.bottle(lv.walls["left"], B.wall_pos(lv, "left", -4.5 + float(i) * 0.32, sh + 0.025, 0.15), [0x2f5a3a, 0x5a3a1e, 0x8a2a2a, 0xc9a45a, 0x2a3a5a][rng.randi() % 5])
	for z in [-4.0, -2.8, -1.6, -0.4]:
		F.stool(lv, -7.1, z)
	for i in 3:
		F.glass(bar, Vector3(-1.2 + float(i) * 0.9, 1.1, 0.1))
	var barman := Human.new({"shirt": 0xf2efe6, "apron": 0x16161a, "pants": 0x16161a, "hair": 0x1a1410, "tie": 0x16161a})
	lv.add_npc("barman", barman, Vector3(-8.65, 0, -2.4), PI / 2.0, "", 2.0, false)
	lv.add_inter("bar", "Бар", Vector3(-7.3, 0, -2.4), 1.5, 2.6)

	# столик героя
	var ht := F.round_table(lv, -3.6, 2.6)
	F.chair(lv, -3.6, 3.75, PI, {"color": 0x3a2418, "seat": 0x7a1f24})
	F.plate(ht, Vector3(0, 0.79, 0.25))
	F.glass(ht, Vector3(0.3, 0.79, 0.05))
	B.box(ht, Vector3(0.2, 0.012, 0.3), Vector3(-0.3, 0.795, 0.0), 0x4a1418)
	lv.add_inter("menu", "Меню", Vector3(-3.6, 0, 2.6), 1.5, 1.7)

	# гости
	var ch_o := {"color": 0x3a2418, "seat": 0x7a1f24}
	F.round_table(lv, -5.0, -2.4)
	_seat(lv, "lady", {"skin": 0xe6b89a, "dress": 0x8a1c2c, "hair": 0x2a1810, "long_hair": true, "sleeves": 0xe6b89a}, -5.0, -3.5, 0.0, "Дама за соседним столиком", ch_o)
	_seat(lv, "g1", {"shirt": 0xf2efe6, "coat": 0x2a2c34, "pants": 0x2a2c34, "hair": 0x5a4a3a, "tie": 0x1a1a1a}, -5.0, -1.3, PI, "", ch_o)
	F.round_table(lv, 0.3, -3.0)
	_seat(lv, "g2", {"shirt": 0xf2efe6, "coat": 0x4a3a2a, "pants": 0x3a2e22, "hair": 0x8a8a8a, "bald": true}, -0.85, -3.0, PI / 2.0, "", ch_o)
	_seat(lv, "g3", {"skin": 0xdcae8e, "dress": 0x2a4a5a, "hair": 0xc9a45a, "long_hair": true, "sleeves": 0xdcae8e}, 1.45, -3.0, -PI / 2.0, "", ch_o)
	F.round_table(lv, 0.8, 1.7)
	_seat(lv, "gent", {"shirt": 0xf2efe6, "coat": 0x55504a, "pants": 0x3a3632, "hair": 0xdcdcdc, "glasses": true, "tie": 0x4a2a2a}, 0.8, 0.6, 0.0, "Пожилой господин", ch_o)
	F.chair(lv, 0.8, 2.8, PI, ch_o)
	F.round_table(lv, 4.6, 2.2)
	F.chair(lv, 4.6, 1.1, 0.0, ch_o)
	F.chair(lv, 4.6, 3.3, PI, ch_o)
	for tpos in [Vector3(-5.0, 0.79, -2.4), Vector3(0.3, 0.79, -3.0), Vector3(0.8, 0.79, 1.7)]:
		var holder := F.node(lv, tpos.x, tpos.z)
		F.plate(holder, Vector3(0.0, 0.79, 0.3))
		F.plate(holder, Vector3(0.0, 0.79, -0.3))
		F.glass(holder, Vector3(0.25, 0.79, 0.1))
		F.bottle(holder, Vector3(-0.1, 0.79, 0.0), 0x2f5a3a)

	# столик Патрона
	var pt := F.round_table(lv, 5.3, -2.9, {"r": 0.75})
	F.chair(lv, 5.3, -4.1, 0.0, ch_o)
	F.chair(lv, 5.3, -1.7, PI, ch_o)
	F.bottle(pt, Vector3(0.2, 0.79, 0.0), 0x5a3a1e)
	F.glass(pt, Vector3(-0.1, 0.79, -0.2))
	F.plate(pt, Vector3(0.0, 0.79, 0.3))
	var patron := Human.new(patron_style())
	patron.pose = "sit"
	lv.add_npc("patron", patron, Vector3(5.3, 0, -1.7), PI, "Седой господин", 2.0, false)

	var waiter := Human.new({"shirt": 0xf2efe6, "apron": 0x16161a, "pants": 0x16161a, "hair": 0x2a1c14, "tie": 0x16161a})
	lv.add_npc("waiter", waiter, Vector3(-5.9, 0, 0.9), PI / 2.0, "Официант")

	F.piano(lv, -6.7, 4.6, PI * 0.75)
	F.plant(lv, 8.3, -5.8, {"pot": 0x2a2622})
	F.plant(lv, 8.3, 5.9, {"pot": 0x2a2622})
	F.plant(lv, -8.3, 5.9, {"pot": 0x2a2622})
	F.chandelier(lv, -4.2, 0.2, 3.7, {"color": wd.bulb, "energy": 1.9, "range": 13.0})
	F.chandelier(lv, 4.2, 0.2, 3.7, {"color": wd.bulb, "energy": 1.9, "range": 13.0})
	F.painting(lv, "right", -2.0, 2.5, 2.2, 1.3, [0x2a3a4a, 0xc9a45a, 0x8a2a2a, 0xe6dcc2], 0xc9a45a)
	F.painting(lv, "left", 3.2, 2.5, 1.8, 1.2, [0x4a2a2a, 0xe6dcc2, 0x2a4a3a], 0xc9a45a)
	lv.add_inter("window", "Окно", Vector3(0.0, 0, -6.0), 1.4, 4.3)
	return lv


# ---------- Северный вокзал ----------

static func station() -> Level:
	var wd: Dictionary = Game.W()
	var lv := Level.new("station", 16.0, 11.0, 5.6)
	lv.ambience = "station"
	lv.cam_dist = 9.5
	var wins: Array = []
	for x in [-5.0, 0.0, 5.0]:
		wins.append({"x": x, "w": 2.4, "y0": 1.8, "y1": 4.9, "mullions": 1, "cross": true})
	B.shell(lv, 0xb9ad94, _checker(0x9a968c, 0x7d7a72, 16.0, 11.0, 1.0, 0.4), {"win_back": wins, "trim": 0x4a4238, "trim_h": 0.9})
	city(lv, 0.0)
	_exit(lv, "left", 3.6, {"w": 1.4, "h": 2.6, "color": 0x4a3a28})

	# камеры хранения
	var lockers := F.node(lv, 0, 0)
	for r in 3:
		for c in 6:
			var num := r * 6 + c + 1
			var z := -3.2 + float(c) * 1.0
			var y := 2.75 - float(r) * 1.0
			B.box(lockers, Vector3(0.55, 0.96, 0.96), Vector3(7.72, y, z), 0x4a5560, {"metal": 0.5, "rough": 0.5})
			var hinge := Node3D.new()
			hinge.position = Vector3(7.44, y, z - 0.44)
			lockers.add_child(hinge)
			B.box(hinge, Vector3(0.03, 0.86, 0.86), Vector3(0, 0, 0.44), 0x5d6a76, {"metal": 0.5, "rough": 0.45})
			B.box(hinge, Vector3(0.03, 0.08, 0.04), Vector3(-0.02, -0.05, 0.78), 0xc9a45a, {"metal": 0.8, "rough": 0.3})
			B.label(hinge, str(num), Vector3(-0.02, 0.2, 0.44), -PI / 2.0, 64, 0xe6dfd0, 0.004)
			if num == 13:
				lv.set_meta("locker13", hinge)
				var envl := F.envelope(lockers, Vector3(7.7, y - 0.4, z), 0xd9c9a0)
				envl.visible = false
				lv.set_meta("envelope", envl)
	B.col(lv, Vector3(7.72, 1.7, -0.7), Vector3(0.6, 3.4, 6.2))
	B.label(lv.walls["right"], "КАМЕРЫ  ХРАНЕНИЯ", B.wall_pos(lv, "right", -0.7, 3.9, 0.05), -PI / 2.0, 96, 0x2a2622, 0.005)
	lv.add_inter("locker13", "Ячейка № 13", Vector3(7.0, 0, -3.2), 1.4, 1.6)
	lv.add_inter("lockers", "Ячейки", Vector3(7.0, 0, 0.3), 1.5, 3.6)

	# касса и кладовщик
	F.counter(lv, -5.2, -3.6, 0.0, {"w": 3.4, "d": 0.7, "h": 1.05, "color": 0x5a4a38, "top": 0x2a2018, "door": 0x6a5844})
	B.box(lv, Vector3(3.4, 1.3, 0.04), Vector3(-5.2, 1.75, -3.6), 0, {"mat": B.glass_mat(0xcfe0e8, 0.18), "noshadow": true})
	B.box(lv, Vector3(3.5, 0.3, 0.3), Vector3(-5.2, 2.55, -3.6), 0x4a3a28)
	B.label(lv, "КАССА", Vector3(-5.2, 2.56, -3.44), 0.0, 96, 0xe6dfd0, 0.004)
	var clerk := Human.new({"shirt": 0xd8d2c4, "coat": 0x2c3e5a, "pants": 0x22304a, "cap": 0x22304a, "hair": 0x6a6a6a, "beard": 0x8a8a8a})
	lv.add_npc("clerk", clerk, Vector3(-5.2, 0, -4.5), 0.0, "Кладовщик", 2.3, false)

	# скамьи и пассажир
	F.bench(lv, -0.5, 0.4, 0.0, 3.2)
	F.bench(lv, -0.5, 1.1, PI, 3.2)
	F.bench(lv, 3.2, 3.6, PI, 2.6)
	var trav := Human.new({"shirt": 0x8a8a7a, "coat": 0x5a4630, "long_coat": true, "pants": 0x3a3028, "hat": 0x3a3028, "hair": 0x3a2a1c})
	trav.pose = "sit"
	lv.add_npc("traveler", trav, Vector3(-1.2, 0, 0.42), 0.0, "Пассажир", 1.8, false)
	B.box(lv, Vector3(0.7, 0.5, 0.25), Vector3(-0.3, 0.25, -0.1), 0x6a3a22)
	B.box(lv, Vector3(0.5, 0.36, 0.2), Vector3(2.4, 0.18, 3.15), 0x3a4a3a)

	# часы и свет
	var clock := F.node(lv.walls["back"], 2.5, -5.42)
	clock.position.y = 4.3
	var dial := B.cyl(clock, 0.45, 0.45, 0.06, Vector3.ZERO, 0xf2efe6, 14)
	dial.rotation.x = PI / 2.0
	var rim := B.cyl(clock, 0.5, 0.5, 0.04, Vector3(0, 0, -0.02), 0x2a2622, 14)
	rim.rotation.x = PI / 2.0
	var hh := B.box(clock, Vector3(0.04, 0.26, 0.02), Vector3(0.06, 0.1, 0.05), 0x111111)
	hh.rotation.z = -0.5
	B.box(clock, Vector3(0.03, 0.38, 0.02), Vector3(0, 0.18, 0.05), 0x111111)
	for px in [-4.5, 0.0, 4.5]:
		F.pendant(lv, px, 1.0, 3.8, {"color": wd.bulb, "energy": 1.3, "range": 11.0, "shade": 0x3a4238})
	lv.add_inter("window", "Высокие окна", Vector3(0.0, 0, -5.0), 1.4, 5.1)
	return lv


# ---------- Квартира Патрона (глава 2) ----------

static func penthouse() -> Level:
	var wd: Dictionary = Game.W()
	var lv := Level.new("penthouse", 15.0, 10.0, 4.4)
	lv.cam_dist = 9.5
	B.shell(lv, 0x3a2c26, _planks(0x2c2420, 15.0, 0.35), {"win_back": [{"x": 0.0, "w": 13.4, "y0": 0.2, "y1": 4.0, "mullions": 6}], "trim": 0x1a1412})
	city(lv, 55.0, {"hmul": 2.0})
	_exit(lv, "left", 3.3, {"color": 0x241a14, "frame": 0xc9a45a, "w": 1.2, "h": 2.5})
	F.rug(lv, -1.3, 0.4, 5.6, 3.6, 0xd8cdb4, 0x8a7a5a)
	F.sofa(lv, -1.5, 1.5, PI, {"w": 3.0, "color": 0x4a2a20, "cushion": 0x5a3428})
	F.sofa(lv, 1.3, -0.1, -PI / 2.0, {"w": 1.1, "color": 0x4a2a20, "cushion": 0x5a3428})
	var ct := F.table(lv, -1.5, -0.2, 0.0, {"w": 1.5, "d": 0.8, "h": 0.42, "color": 0x1a1412, "rough": 0.25})
	F.bottle(ct, Vector3(0.3, 0.42, 0.0), 0x5a3a1e)
	F.glass(ct, Vector3(0.0, 0.42, 0.15))
	F.glass(ct, Vector3(-0.25, 0.42, -0.1))
	# бар у правой стены
	var bar := F.counter(lv, 6.9, -1.2, -PI / 2.0, {"w": 2.6, "d": 0.6, "h": 1.0, "color": 0x241a14, "top": 0x0e0c0b, "door": 0x33241c})
	for i in 5:
		F.bottle(bar, Vector3(-1.0 + float(i) * 0.5, 1.0, -0.05), [0x5a3a1e, 0xc9a45a, 0x2f5a3a, 0x8a2a2a, 0x2a3a5a][i])
	lv.add_inter("bar", "Бар", Vector3(6.2, 0, -1.2), 1.5, 2.2)
	F.fireplace(lv, "right", 2.4, {"color": 0x2a2624, "mantel": 0x0e0c0b, "energy": 1.6})
	F.painting(lv, "left", -1.5, 2.4, 2.6, 1.5, [0x1a1a1e, 0xc9a45a, 0x7a1f24], 0xc9a45a)
	F.painting(lv, "right", -3.4, 2.5, 1.2, 1.5, [0x2a3a4a, 0xe6dcc2], 0xc9a45a)
	# глобус и скульптура
	B.cyl(lv, 0.05, 0.22, 0.9, Vector3(4.6, 0.45, 2.9), 0x241a14, 8)
	B.ball(lv, 0.36, Vector3(4.6, 1.25, 2.9), 0x3a6a8a, 8, 5, {"rough": 0.4})
	F.fcol(lv, 4.6, 2.9, 0.6, 0.6, 1.6)
	F.plant(lv, -6.8, -3.9, {"pot": 0x1a1412})
	F.floor_lamp(lv, -3.6, 2.4, {"color": wd.bulb, "energy": 1.3, "range": 7.0})
	F.floor_lamp(lv, 6.6, -3.9, {"color": wd.bulb, "energy": 1.1, "range": 6.5})
	F.chandelier(lv, -1.0, 0.3, 3.5, {"color": wd.bulb, "energy": 1.3, "r": 0.7, "bulbs": 6})
	var patron := Human.new(patron_style())
	patron.pose = "behind"
	lv.add_npc("patron", patron, Vector3(2.6, 0, -3.9), PI, "Патрон")
	lv.add_inter("window", "Панорамное окно", Vector3(-3.0, 0, -4.6), 1.4, 4.2)
	return lv


# ---------- Контора Громова (глава 2, вечер) ----------

static func gromov() -> Level:
	var lv := Level.new("gromov", 9.0, 7.0, 3.4)
	lv.ambience = "office"
	lv.light_scale = 0.25
	lv.cam_dist = 7.5
	B.shell(lv, 0x5a5648, _planks(0x4a3a2c, 9.0), {"win_back": [{"x": 2.2, "w": 2.2, "y0": 1.0, "y1": 2.6, "cross": true}], "trim": 0x2a2018, "trim_h": 0.9})
	city(lv, 9.0)
	F.blinds(lv, "back", 2.2, 2.2, 1.0, 2.6)
	_exit(lv, "right", 2.3)
	var ds := F.desk(lv, -0.3, -1.3, 0.0, {"w": 2.0})
	F.chair(lv, -0.3, -2.2, 0.0, {"color": 0x2a1c14, "seat": 0x3a4a3a})
	F.table_lamp(lv, ds, Vector3(-0.65, 0.8, -0.1), {"shade": 0x2f8a4a, "color": 0xffe2b0, "energy": 1.5, "range": 6.0, "shadow": true})
	F.papers(ds, Vector3(0.2, 0.8, 0.0), 4, 0.25, 4)
	F.phone(ds, Vector3(0.7, 0.8, -0.1))
	lv.add_inter("drawer", "Ящик стола", Vector3(-0.3, 0, -1.3), 1.7, 1.6)
	F.bookcase(lv, -4.25, -1.2, PI / 2.0, {"w": 2.2, "h": 2.4})
	F.bookcase(lv, -2.6, -3.28, 0.0, {"w": 1.8, "h": 2.4, "fill": 0.7})
	# картотека
	for i in 2:
		var fx := 3.9
		var fz := -2.9 + float(i) * 0.75
		B.box(lv, Vector3(0.6, 1.4, 0.7), Vector3(fx, 0.7, fz), 0x55606a, {"metal": 0.5, "rough": 0.5})
		for j in 3:
			B.box(lv, Vector3(0.02, 0.36, 0.6), Vector3(fx - 0.31, 0.25 + float(j) * 0.45, fz), 0x66727c, {"metal": 0.5, "rough": 0.5})
	F.fcol(lv, 3.9, -2.5, 0.6, 1.5, 1.4)
	F.painting(lv, "right", 0.0, 1.8, 0.7, 0.5, [0xb8a888, 0x4a4a52, 0x2a2a30], 0x2a2018)
	lv.add_inter("photo", "Фотография на стене", Vector3(3.9, 0, 0.0), 1.4, 2.5)
	F.rug(lv, -0.3, 0.6, 3.6, 2.2, 0x4a2a24, 0x2a1814)
	# вешалка
	B.cyl(lv, 0.03, 0.03, 1.8, Vector3(-3.9, 0.9, 2.8), 0x2a1c14, 6)
	B.cyl(lv, 0.25, 0.25, 0.04, Vector3(-3.9, 0.02, 2.8), 0x2a1c14, 8)
	B.box(lv, Vector3(0.5, 0.04, 0.04), Vector3(-3.9, 1.75, 2.8), 0x2a1c14)
	lv.add_inter("window", "Окно", Vector3(2.2, 0, -3.0), 1.3, 3.0)
	return lv


# ---------- Типография Семёнова (глава 2) ----------

static func shop() -> Level:
	var wd: Dictionary = Game.W()
	var lv := Level.new("shop", 11.0, 8.0, 3.8)
	lv.ambience = "shop"
	lv.cam_dist = 8.5
	var wins: Array = [{"x": -3.2, "w": 1.6, "y0": 1.9, "y1": 3.1, "cross": true}, {"x": 3.2, "w": 1.6, "y0": 1.9, "y1": 3.1, "cross": true}]
	B.shell(lv, 0x8a8272, _planks(0x5a4a3a, 11.0), {"win_back": wins, "trim": 0x3a3228, "trim_h": 0.2})
	city(lv, 0.0)
	_exit(lv, "right", 2.7)
	# печатный станок
	var pr := F.node(lv, -3.3, -1.3)
	B.box(pr, Vector3(2.4, 0.9, 1.3), Vector3(0, 0.45, 0), 0x2f3a3a, {"metal": 0.6, "rough": 0.5})
	B.box(pr, Vector3(2.0, 0.5, 1.0), Vector3(0, 1.15, 0), 0x3a4646, {"metal": 0.6, "rough": 0.5})
	var roll := B.cyl(pr, 0.22, 0.22, 1.5, Vector3(0.3, 1.55, 0), 0x1a1a1c, 10, {"metal": 0.7, "rough": 0.3})
	roll.rotation.x = PI / 2.0
	var roll2 := B.cyl(pr, 0.14, 0.14, 1.5, Vector3(-0.3, 1.5, 0), 0x8a8a90, 10, {"metal": 0.8, "rough": 0.3})
	roll2.rotation.x = PI / 2.0
	var wheel := F.node(pr, 1.3, 0.0)
	wheel.position.y = 1.0
	var wm := B.cyl(wheel, 0.5, 0.5, 0.08, Vector3.ZERO, 0x1a1a1c, 12, {"metal": 0.7, "rough": 0.4})
	wm.rotation.z = PI / 2.0
	B.box(wheel, Vector3(0.1, 0.9, 0.08), Vector3.ZERO, 0x8a8a90, {"metal": 0.8})
	B.box(wheel, Vector3(0.1, 0.08, 0.9), Vector3.ZERO, 0x8a8a90, {"metal": 0.8})
	lv.updaters.append(func(dt):
		wheel.rotation.x += dt * 1.4
		roll.rotation.z += dt * 2.0)
	B.box(pr, Vector3(0.9, 0.04, 0.9), Vector3(-1.5, 0.95, 0), 0x6a5a48)
	F.papers(pr, Vector3(-1.5, 0.97, 0), 6, 0.08, 2)
	F.fcol(lv, -3.3, -1.3, 3.4, 1.4, 1.6)
	lv.add_inter("press", "Печатный станок", Vector3(-3.3, 0, -0.4), 1.5, 2.3)
	# прилавок
	var cn := F.counter(lv, 1.9, -0.6, 0.0, {"w": 2.8, "d": 0.7, "h": 1.0, "color": 0x5a4632, "top": 0x3a2c20, "door": 0x6a543c})
	for i in 3:
		B.box(cn, Vector3(0.36, 0.1 + float(i) * 0.05, 0.5), Vector3(-0.9 + float(i) * 0.45, 1.05 + float(i) * 0.025, 0), 0xe6dfd0)
	F.table_lamp(lv, cn, Vector3(1.05, 1.0, 0), {"shade": 0xc98a3a, "color": 0xffd9a0, "energy": 1.0, "range": 5.0})
	var sem := Human.new({"skin": 0xd8ac8c, "shirt": 0xb9b2a4, "apron": 0x3a3a3e, "pants": 0x3a342c, "hair": 0xe6e6e6, "bald": true, "glasses": true, "scale": 0.96})
	lv.add_npc("semyonov", sem, Vector3(1.9, 0, -1.6), 0.0, "Семёнов", 2.4, false)
	# стеллаж с краской и бумагой
	F.bookcase(lv, 4.2, -3.75, 0.0, {"w": 2.2, "h": 2.4, "color": 0x4a3c2c, "books": [0xe6dfd0, 0xd8d0be, 0x2a2a2e, 0x8a2a2a, 0x2a3a5a], "fill": 0.7})
	for p in [Vector3(-0.6, 0, -3.3), Vector3(0.2, 0, -3.3), Vector3(-0.2, 0, 2.9)]:
		B.box(lv, Vector3(0.6, 0.5, 0.45), p + Vector3(0, 0.25, 0), 0xe6dfd0)
		B.box(lv, Vector3(0.62, 0.04, 0.47), p + Vector3(0, 0.3, 0), 0x6a5a48)
	F.fcol(lv, -0.2, -3.3, 1.6, 0.5, 0.6)
	F.painting(lv, "left", 1.5, 2.1, 0.8, 1.1, [0xe6dfd0, 0x8a2a2a, 0x1a1a1c, 0x1a1a1c], 0x2a2018)
	F.painting(lv, "back", 0.0, 2.3, 1.0, 0.7, [0xd8d0be, 0x2a3a5a, 0x1a1a1c], 0x2a2018)
	B.label(lv.walls["back"], "ТИПОГРАФИЯ  СЕМЁНОВА  ·  с 1894", B.wall_pos(lv, "back", 0.0, 3.3, 0.03), 0.0, 72, 0x2a2420, 0.005)
	F.pendant(lv, -2.8, 0.6, 2.7, {"color": wd.bulb, "energy": 1.1, "range": 8.0, "shade": 0x3a4238})
	F.pendant(lv, 2.2, 0.8, 2.7, {"color": wd.bulb, "energy": 1.1, "range": 8.0, "shade": 0x3a4238})
	return lv


# ---------- Офис Патрона в башне (глава 3) ----------

static func tower() -> Level:
	var wd: Dictionary = Game.W()
	var lv := Level.new("tower", 14.0, 10.0, 4.6)
	lv.ambience = "office"
	lv.cam_dist = 9.5
	var wins: Array = [{"x": -3.4, "w": 6.2, "y0": 0.2, "y1": 4.2, "mullions": 3}, {"x": 3.4, "w": 6.2, "y0": 0.2, "y1": 4.2, "mullions": 3}]
	B.shell(lv, 0x2b2f38, _checker(0x1e1e24, 0x26262d, 14.0, 10.0, 1.0, 0.15), {"win_back": wins, "trim": 0x0e0f12})
	city(lv, 80.0, {"hmul": 2.7})
	_exit(lv, "left", 3.3, {"color": 0x15161a, "frame": 0x8a8a90, "w": 1.2, "h": 2.6})
	var ds := F.desk(lv, 0.0, -1.9, 0.0, {"w": 2.8, "d": 1.0, "color": 0x17130f, "drawer": 0x221c16})
	F.table_lamp(lv, ds, Vector3(-1.0, 0.8, -0.1), {"shade": 0xd8d8e0, "color": 0xe6ecff, "energy": 1.3, "range": 6.0, "shadow": true})
	F.phone(ds, Vector3(0.9, 0.8, -0.1))
	F.papers(ds, Vector3(0.0, 0.8, 0.05), 5, 0.3, 6)
	# кресло хозяина
	B.box(lv, Vector3(0.7, 0.14, 0.7), Vector3(0, 0.5, -3.1), 0x101012, {"rough": 0.4})
	B.box(lv, Vector3(0.7, 1.1, 0.14), Vector3(0, 1.05, -3.42), 0x101012, {"rough": 0.4})
	B.cyl(lv, 0.05, 0.3, 0.44, Vector3(0, 0.22, -3.1), 0x777780, 6, {"metal": 0.8})
	F.chair(lv, -0.9, -0.5, PI, {"color": 0x15161a, "seat": 0x2a2c34})
	F.chair(lv, 0.9, -0.5, PI, {"color": 0x15161a, "seat": 0x2a2c34})
	F.bookcase(lv, -6.75, -1.6, PI / 2.0, {"w": 2.6, "h": 3.0, "color": 0x15161a})
	F.bookcase(lv, -6.75, 1.2, PI / 2.0, {"w": 2.2, "h": 3.0, "color": 0x15161a, "fill": 0.7})
	# карта города с флажками
	F.painting(lv, "right", -1.0, 2.4, 3.2, 2.0, [0x39424e, 0x2a323c, 0x4a5562, 0x20262e], 0x8a8a90)
	for f in [[-1.8, 2.8], [-0.6, 2.2], [0.1, 2.9], [-1.2, 1.9]]:
		B.box(lv.walls["right"], Vector3(0.04, 0.08, 0.08), B.wall_pos(lv, "right", f[0], f[1], 0.1), 0xb01c1c, {"emit": 0.6})
	lv.add_inter("map", "Карта города", Vector3(6.3, 0, -1.0), 1.5, 3.7)
	F.sofa(lv, 4.6, 2.8, PI, {"w": 2.4, "color": 0x15161a, "cushion": 0x1e1f25})
	F.rug(lv, 0.0, 0.2, 5.0, 3.0, 0x30323a, 0x191a1f)
	F.floor_lamp(lv, 6.3, 3.9, {"color": 0xdfe6ff, "energy": 0.9, "range": 6.0})
	F.pendant(lv, 0.0, 0.5, 3.6, {"color": 0xdfe6ff, "energy": 0.9, "range": 10.0, "shade": 0x101012})
	var patron := Human.new(patron_style())
	patron.pose = "behind"
	lv.add_npc("patron", patron, Vector3(1.9, 0, -3.6), PI, "Патрон")
	lv.add_inter("window", "Окно", Vector3(-3.4, 0, -4.6), 1.4, 4.4)
	return lv


# ---------- Контора Рейнера (глава 3) ----------

static func reiner() -> Level:
	var lv := Level.new("reiner", 10.0, 7.5, 3.5)
	lv.light_scale = 0.4
	lv.cam_dist = 8.0
	B.shell(lv, 0xd4c7a4, _planks(0x8a6a48, 10.0), {"win_back": [{"x": -2.6, "w": 2.4, "y0": 1.0, "y1": 2.6, "cross": true}], "trim": 0x5a4630})
	city(lv, 6.0)
	F.curtains(lv, "back", -2.6, 2.4, 1.0, 2.6, 0x6a8a6a)
	_exit(lv, "right", 2.3, {"color": 0x6a4a30})
	var ds := F.desk(lv, -0.6, -1.3, 0.0, {"w": 2.0, "color": 0x6a4a30, "drawer": 0x7a5838})
	F.table_lamp(lv, ds, Vector3(-0.7, 0.8, -0.1), {"shade": 0xf2d8a0, "color": 0xffd9a0, "energy": 1.4, "range": 6.5, "shadow": true})
	F.papers(ds, Vector3(0.2, 0.8, 0.05), 6, 0.3, 8)
	B.box(ds, Vector3(0.16, 0.2, 0.02), Vector3(0.75, 0.9, -0.2), 0x6a4a30, {"rot": Vector3(-0.2, 0.3, 0)})
	var rn := Human.new({"skin": 0xdcae8e, "shirt": 0xe6dfd0, "coat": 0x6f8f6a, "pants": 0x4a4238, "hair": 0x7a5a3a, "bald": true, "glasses": true})
	F.chair(lv, -0.6, -2.25, 0.0, {"color": 0x5a3d28, "seat": 0x6a8a6a})
	rn.pose = "sit"
	lv.add_npc("reiner", rn, Vector3(-0.6, 0, -2.25), 0.0, "Рейнер", 2.5, false)
	# детские рисунки
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var cols := [0xf2c84a, 0xe86a4a, 0x6ab4e8, 0x7ac86a, 0xe88ac0, 0xf2efe6]
	for i in 7:
		var u := 0.6 + float(i % 4) * 0.75 + rng.randf_range(-0.08, 0.08)
		var v := 1.5 + float(i / 4) * 0.62 + rng.randf_range(-0.05, 0.05)
		var pg := B.box(lv.walls["back"], Vector3(0.5, 0.38, 0.01), B.wall_pos(lv, "back", u, v, 0.01), 0xf2efe6, {"noshadow": true})
		pg.rotation.z = rng.randf_range(-0.12, 0.12)
		var blot := B.box(lv.walls["back"], Vector3(0.22, 0.18, 0.012), B.wall_pos(lv, "back", u + rng.randf_range(-0.08, 0.08), v + rng.randf_range(-0.05, 0.05), 0.016), cols[rng.randi() % 5], {"noshadow": true})
		blot.rotation.z = pg.rotation.z
		B.box(lv.walls["back"], Vector3(0.1, 0.1, 0.012), B.wall_pos(lv, "back", u + 0.14, v + 0.1, 0.018), 0xf2c84a, {"noshadow": true})
	lv.add_inter("drawings", "Детские рисунки", Vector3(1.7, 0, -3.1), 1.4, 2.9)
	# сейф
	B.box(lv, Vector3(0.9, 1.2, 0.8), Vector3(4.3, 0.6, -3.1), 0x3a4048, {"metal": 0.7, "rough": 0.45})
	B.box(lv, Vector3(0.02, 1.0, 0.64), Vector3(3.84, 0.6, -3.1), 0x4a525c, {"metal": 0.7, "rough": 0.4})
	var dial := B.cyl(lv, 0.1, 0.1, 0.04, Vector3(3.81, 0.7, -3.1), 0xc9a45a, 10, {"metal": 0.9, "rough": 0.3})
	dial.rotation.z = PI / 2.0
	F.fcol(lv, 4.3, -3.1, 0.9, 0.8, 1.2)
	lv.add_inter("safe", "Сейф", Vector3(3.6, 0, -3.0), 1.5, 1.9)
	# макет приюта
	var mt := F.table(lv, -3.9, 1.0, PI / 2.0, {"w": 1.6, "d": 0.9, "h": 0.8, "color": 0x7a5838})
	B.box(mt, Vector3(1.3, 0.02, 0.7), Vector3(0, 0.81, 0), 0x7ab06a)
	B.box(mt, Vector3(0.6, 0.22, 0.3), Vector3(-0.15, 0.93, 0), 0xf2efe6)
	B.box(mt, Vector3(0.66, 0.06, 0.36), Vector3(-0.15, 1.07, 0), 0xc85a3a)
	B.box(mt, Vector3(0.25, 0.16, 0.25), Vector3(0.4, 0.9, 0.1), 0xf2efe6)
	B.box(mt, Vector3(0.3, 0.05, 0.3), Vector3(0.4, 1.0, 0.1), 0xc85a3a)
	for i in 4:
		B.cyl(mt, 0.0, 0.05, 0.14, Vector3(-0.5 + float(i) * 0.33, 0.89, -0.26), 0x3f7a3a, 5)
	lv.add_inter("model", "Макет", Vector3(-3.4, 0, 1.0), 1.5, 1.8)
	F.sofa(lv, 2.2, 2.9, PI, {"w": 2.0, "color": 0x7a6a4a, "cushion": 0x8a7a58})
	F.plant(lv, -4.4, -3.1, {"pot": 0xb86a4a})
	F.rug(lv, 0.0, 0.6, 3.8, 2.4, 0xa85a3a, 0x6a3a26)
	F.floor_lamp(lv, 4.3, 3.0, {"color": 0xffd9a0, "energy": 1.3, "range": 6.5})
	F.pendant(lv, 0.0, 0.4, 2.6, {"color": 0xffd9a0, "energy": 1.3, "range": 9.0, "shade": 0x8a6a48})
	return lv


# ---------- Особняк Патрона (главы 4 и 5) ----------

static func mansion() -> Level:
	var ch: int = Game.chapter
	var wd: Dictionary = Game.W()
	var lv := Level.new("mansion", 20.0, 14.0, 6.4)
	lv.ambience = "party" if ch == 5 else "mansion"
	lv.cam_dist = 10.5
	var wins: Array = [{"x": -6.5, "w": 3.4, "y0": 0.9, "y1": 5.4, "mullions": 2, "cross": true}, {"x": 6.5, "w": 3.4, "y0": 0.9, "y1": 5.4, "mullions": 2, "cross": true}]
	B.shell(lv, 0x23302b, _checker(0x1c1c20, 0xbfb8a8, 20.0, 14.0, 1.0, 0.5), {"win_back": wins, "trim": 0x1a120c, "trim_h": 1.1})
	city(lv, 4.0, {"count": 14, "hmul": 0.5})
	for x in [-6.5, 6.5]:
		F.curtains(lv, "back", x, 3.4, 0.9, 5.4, 0x5a1218)
	_exit(lv, "right", 4.6, {"color": 0x241812, "w": 1.5, "h": 2.9, "frame": 0xc9a45a})
	F.fireplace(lv, "back", 0.0, {"w": 3.2, "h": 1.9, "color": 0x3a3632, "mantel": 0x120c08, "energy": 2.4 if ch == 4 else 1.4})
	# портрет над камином
	B.box(lv.walls["back"], Vector3(1.5, 2.0, 0.06), Vector3(0, 3.6, -6.66), 0xc9a45a, {"metal": 0.5, "rough": 0.4})
	B.box(lv.walls["back"], Vector3(1.3, 1.8, 0.03), Vector3(0, 3.6, -6.62), 0x16130f)
	B.box(lv.walls["back"], Vector3(0.5, 0.7, 0.02), Vector3(0, 3.3, -6.6), 0x0c0c0e)
	B.ball(lv.walls["back"], 0.2, Vector3(0, 3.9, -6.58), 0xcfa184, 8, 4)
	B.ball(lv.walls["back"], 0.21, Vector3(0, 3.98, -6.6), 0xcfcfcf, 8, 3)
	lv.add_inter("portrait", "Портрет над камином", Vector3(-2.6, 0, -5.4), 1.4, 2.6)
	for cp in [Vector3(-7.2, 0, -1.4), Vector3(7.2, 0, -1.4), Vector3(-7.2, 0, 3.6), Vector3(7.2, 0, 3.6)]:
		F.column(lv, cp.x, cp.z, 0xcfc8b8, 0.36)
	F.rug(lv, 0.0, -1.6, 7.0, 6.0, 0x5a1218, 0x2a0a0e)
	F.sofa(lv, -3.2, -3.4, PI / 3.0, {"w": 1.2, "color": 0x3a1a16, "cushion": 0x4a221c})
	F.sofa(lv, 3.2, -3.4, -PI / 3.0, {"w": 1.2, "color": 0x3a1a16, "cushion": 0x4a221c})
	# дверь кабинета
	var cdp := F.door(lv, "left", -1.6, {"color": 0x1a100a, "w": 1.2, "h": 2.7, "frame": 0xc9a45a})
	lv.add_inter("cabinet_door", "Дверь кабинета", cdp, 1.6, 3.1)
	F.painting(lv, "left", 3.0, 3.0, 2.2, 2.6, [0x1a1a1e, 0x5a1218, 0xc9a45a], 0xc9a45a)
	F.painting(lv, "right", -1.0, 3.0, 2.6, 2.2, [0x15201c, 0xc9a45a, 0x3a1a16], 0xc9a45a)
	F.chandelier(lv, 0.0, 0.2, 4.6, {"color": wd.bulb, "energy": 3.2 if ch == 5 else 2.2, "r": 1.3, "bulbs": 12, "range": 22.0, "flicker": 0.25 if ch == 4 else 0.0})
	for sc in [["left", -4.6], ["left", 5.4], ["right", -4.0], ["right", 1.6], ["back", -3.6], ["back", 3.6]]:
		var sp := B.wall_pos(lv, sc[0], sc[1], 2.6, 0.12)
		B.box(lv.walls[sc[0]], B.wall_size(sc[0], 0.12, 0.3, 0.12), sp, 0xc9a45a, {"metal": 0.8, "rough": 0.3})
		B.ball(lv.walls[sc[0]], 0.09, sp + Vector3(0, 0.25, 0), wd.bulb, 6, 3, {"mat": B.glow_mat(wd.bulb, 3.0), "noshadow": true})
		B.omni(lv, B.wall_pos(lv, sc[0], sc[1], 2.9, 0.5), wd.bulb, 1.1 if ch == 5 else 0.75, 9.0)
	lv.add_inter("window", "Окно", Vector3(-6.5, 0, -6.2), 1.4, 5.8)
	var patron := Human.new(patron_style())
	patron.pose = "behind"
	if ch == 4:
		var st := F.table(lv, -1.5, -4.7, 0.0, {"w": 0.8, "d": 0.6, "h": 0.8, "color": 0x1a120c})
		var gp := F.pistol(st, Vector3(0, 0.8, 0), 0.4)
		lv.set_meta("gun_prop", gp)
		F.glass(st, Vector3(0.25, 0.8, 0.15))
		lv.add_npc("patron", patron, Vector3(1.2, 0, -4.9), 0.0, "Патрон")
		for i in 3:
			F.candle(lv, lv, Vector3(-1.2 + float(i) * 1.2, 2.12, -6.45))
	else:
		lv.add_npc("patron", patron, Vector3(0.0, 0, -2.0), 0.0, "Патрон")
		_party(lv)
	return lv


static func _party(lv: Level) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var suits := [0x0c0c0e, 0x141418, 0x1a1016, 0x10141a]
	var dresses := [0x5a1218, 0x0c0c0e, 0x2a2a34, 0x3a1a3a, 0xc9c2b4]
	var spots := [
		[-4.6, 0.6, 0.6], [-3.5, 1.0, -2.4], [-4.2, 2.0, 2.6],
		[4.0, 0.2, -0.8], [5.0, 1.1, 2.4], [3.6, 1.6, -2.9],
		[-1.6, 3.8, 0.3], [-0.5, 4.4, -2.8], [1.4, 3.6, 3.0], [-0.4, 2.6, 1.3],
		[-7.6, 5.0, 0.9], [7.0, -3.8, -1.8], [-6.0, -3.0, 1.2], [6.1, -4.6, 2.9],
	]
	for i in spots.size():
		var s: Array = spots[i]
		var fem := i % 2 == 1
		var cfg := {"mask": true, "hair": [0x1a1410, 0xcfcfcf, 0x5a4a3a, 0xc9a45a][rng.randi() % 4]}
		if fem:
			cfg["dress"] = dresses[rng.randi() % dresses.size()]
			cfg["long_hair"] = true
			cfg["sleeves"] = 0xdcae8e
		else:
			var su: int = suits[rng.randi() % suits.size()]
			cfg["coat"] = su
			cfg["pants"] = su
			cfg["shirt"] = 0xf2efe6
			cfg["tie"] = 0x0a0a0a
		var hm := Human.new(cfg)
		var id := "guest%d" % i
		var label := ""
		if i == 0:
			label = "Гость в маске"
		elif i == 3:
			label = "Гостья в маске"
		lv.add_npc(id, hm, Vector3(s[0], 0, s[1]), s[2], label, 1.9)
		if i == 0:
			lv.npcs["guest_m"] = hm
			lv.find_inter(id)["id"] = "guest_m"
		elif i == 3:
			lv.npcs["guest_f"] = hm
			lv.find_inter(id)["id"] = "guest_f"
	for tp in [Vector3(-5.6, 0, -4.2), Vector3(5.6, 0, -1.6)]:
		var t := F.round_table(lv, tp.x, tp.z, {"r": 0.6, "cloth": 0xf2efe6})
		for j in 5:
			F.glass(t, Vector3(cos(float(j) * 1.25) * 0.35, 0.79, sin(float(j) * 1.25) * 0.35))
		F.bottle(t, Vector3(0, 0.79, 0), 0x2f5a3a)
		F.candle(lv, t, Vector3(0.15, 0.79, 0.1))


# ---------- Старая пристань (глава 4) ----------

static func pier() -> Level:
	var lv := Level.new("pier", 60.0, 60.0, 8.0, true)
	lv.ambience = "pier"
	lv.cam_dist = 9.5
	lv.cam_yaw = 1.0
	lv.light_scale = 2.6
	# вода
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(260, 260)
	pm.subdivide_width = 90
	pm.subdivide_depth = 90
	water.mesh = pm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep : source_color = vec3(0.012, 0.03, 0.045);
void vertex() {
	VERTEX.y += sin(VERTEX.x * 0.55 + TIME * 1.3) * 0.16 + sin(VERTEX.z * 0.4 + TIME * 0.9) * 0.2 + sin((VERTEX.x + VERTEX.z) * 1.3 + TIME * 2.1) * 0.05;
}
void fragment() {
	ALBEDO = deep;
	ROUGHNESS = 0.12;
	METALLIC = 0.65;
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
}
"""
	var smat := ShaderMaterial.new()
	smat.shader = sh
	water.material_override = smat
	water.position = Vector3(0, -1.3, -40)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lv.add_child(water)
	# настил
	var deck := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(3.8, 0.25, 27.0)
	deck.mesh = dm
	deck.material_override = B.mat(0x3d3228, 0.55)
	deck.position = Vector3(0, -0.125, -1.5)
	lv.add_child(deck)
	for i in 34:
		B.box(lv, Vector3(3.8, 0.03, 0.04), Vector3(0, 0.005, -14.8 + float(i) * 0.8), 0x241c16, {"noshadow": true})
	B.col(lv, Vector3(0, -0.5, -1.5), Vector3(3.8, 1.0, 27.0))
	B.col(lv, Vector3(-2.1, 1.0, -1.5), Vector3(0.4, 3.0, 28.0))
	B.col(lv, Vector3(2.1, 1.0, -1.5), Vector3(0.4, 3.0, 28.0))
	B.col(lv, Vector3(0, 1.0, -15.2), Vector3(5.0, 3.0, 0.4))
	B.col(lv, Vector3(0, 1.0, 12.2), Vector3(5.0, 3.0, 0.4))
	for i in 8:
		var z := -14.0 + float(i) * 3.7
		for sx in [-1.0, 1.0]:
			B.cyl(lv, 0.13, 0.15, 3.4, Vector3(sx * 1.95, -0.7, z), 0x2a221b, 6)
		if i < 7:
			for sx in [-1.0, 1.0]:
				var rope := B.box(lv, Vector3(0.04, 0.04, 3.7), Vector3(sx * 1.95, 0.75, z + 1.85), 0x4a4034, {"noshadow": true})
	# фонари
	for lz in [8.5, -1.5, -11.5]:
		B.cyl(lv, 0.06, 0.08, 3.4, Vector3(-1.95, 1.7, lz), 0x1a1a1c, 6)
		B.box(lv, Vector3(0.7, 0.05, 0.05), Vector3(-1.6, 3.4, lz), 0x1a1a1c)
		var gm := B.glow_mat(0xffd08a, 4.0)
		B.box(lv, Vector3(0.22, 0.26, 0.22), Vector3(-1.25, 3.25, lz), 0xffd08a, {"mat": gm, "noshadow": true})
		var l := B.omni(lv, Vector3(-1.25, 3.0, lz), 0xffc87a, 1.5, 11.0, true)
		l.light_volumetric_fog_energy = 3.0
		if lz < 0.0:
			lv.add_flicker(l, 0.25 if lz > -5.0 else 0.6, gm)
	# берег
	B.box(lv, Vector3(60, 2.0, 16), Vector3(0, -1.0, 20.0), 0x1c1c1e, {"rough": 0.5})
	B.box(lv, Vector3(0.2, 3.4, 0.2), Vector3(-2.2, 1.7, 12.1), 0x2a221b)
	B.box(lv, Vector3(0.2, 3.4, 0.2), Vector3(2.2, 1.7, 12.1), 0x2a221b)
	B.box(lv, Vector3(4.8, 0.7, 0.14), Vector3(0, 3.3, 12.1), 0x2a221b)
	B.label(lv, "ПРИЧАЛ  № 7", Vector3(0, 3.3, 12.18), 0.0, 96, 0xb9b2a4, 0.006)
	lv.add_inter("exit", Story.exit_label, Vector3(0, 0, 11.3), 1.6, 2.6)
	lv.spawn = Vector3(0, 0, 10.2)
	lv.spawn_rot = PI
	F.crate(lv, 1.2, 8.2, 0.8, 0x4a3a28, 0.3)
	B.box(lv, Vector3(0.6, 0.6, 0.6), Vector3(1.2, 1.1, 8.2), 0x3a2e20, {"rot": Vector3(0, 0.8, 0)})
	F.crate(lv, -1.1, 2.6, 0.7, 0x4a3a28, 0.2)
	B.cyl(lv, 0.32, 0.32, 0.9, Vector3(1.3, 0.45, -5.5), 0x2a3a3a, 10, {"metal": 0.5, "rough": 0.5})
	F.fcol(lv, 1.3, -5.5, 0.6, 0.6, 0.9)
	# машина на берегу — фары в дождь
	var car := F.node(lv, 6.5, 15.5, -0.5)
	B.box(car, Vector3(1.8, 0.7, 4.2), Vector3(0, 0.75, 0), 0x0e0e12, {"rough": 0.25, "metal": 0.5})
	B.box(car, Vector3(1.6, 0.6, 2.0), Vector3(0, 1.35, -0.3), 0x0e0e12, {"rough": 0.25, "metal": 0.5})
	for sx in [-1.0, 1.0]:
		B.box(car, Vector3(0.3, 0.2, 0.06), Vector3(sx * 0.6, 0.85, -2.12), 0xfff0c0, {"mat": B.glow_mat(0xfff0c0, 6.0), "noshadow": true})
		for sz in [-1.3, 1.3]:
			var wh := B.cyl(car, 0.36, 0.36, 0.24, Vector3(sx * 0.9, 0.36, sz), 0x08080a, 10)
			wh.rotation.z = PI / 2.0
	var hl := B.spot(car, Vector3(0, 0.85, -2.2), Vector3(0, -0.12, -1), 0xfff0c0, 3.0, 30.0, 26.0, true)
	hl.light_volumetric_fog_energy = 4.0
	# лодка
	var boat := F.node(lv, -4.6, -8.5, 0.3)
	boat.position.y = -1.05
	B.box(boat, Vector3(1.4, 0.5, 3.6), Vector3(0, 0.2, 0), 0x3a2e24)
	B.box(boat, Vector3(1.1, 0.3, 3.2), Vector3(0, 0.42, 0), 0x241c16)
	lv.updaters.append(func(_dt):
		boat.position.y = -1.05 + sin(lv.t * 1.1) * 0.12
		boat.rotation.z = sin(lv.t * 0.8) * 0.06)
	# Марк на краю пристани
	F.crate(lv, 0.5, -13.6, 0.5, 0x4a3a28)
	var marc := Human.new({"skin": 0xc99a7a, "shirt": 0x6a6458, "coat": 0x4d4a40, "long_coat": true, "pants": 0x33312c, "hat": 0x2e2c28, "hair": 0x9a9a9a, "beard": 0x9a9a9a})
	marc.pose = "fish"
	lv.add_npc("marc", marc, Vector3(0.5, 0.05, -13.6), PI, "Человек на краю пристани", 2.6, false)
	var rod := B.cyl(marc, 0.012, 0.02, 3.2, Vector3(0.25, 1.5, 1.6), 0x2a221b, 5, {"noshadow": true})
	rod.rotation.x = 1.05
	var lantern := F.node(lv, -0.7, -13.9)
	B.box(lantern, Vector3(0.2, 0.3, 0.2), Vector3(0, 0.17, 0), 0xffb060, {"mat": B.glow_mat(0xffb060, 3.5), "noshadow": true})
	B.box(lantern, Vector3(0.24, 0.04, 0.24), Vector3(0, 0.34, 0), 0x1a1a1c)
	B.omni(lantern, Vector3(0, 0.4, 0), 0xffa858, 0.9, 6.0, true)
	# огни города за водой
	city(lv, 3.0, {"z0": -95.0, "depth": 30.0, "count": 34, "ground": false, "hmul": 0.8})
	return lv


# ---------- Кабинет (финал) ----------

static func cabinet() -> Level:
	var lv := Level.new("cabinet", 7.0, 6.0, 3.4)
	lv.ambience = "silence"
	lv.light_scale = 0.0
	lv.cam_dist = 6.5
	B.shell(lv, 0x2a1e18, _planks(0x1e1612, 7.0, 0.4), {"trim": 0x120c08, "trim_h": 1.0})
	var dp := F.door(lv, "right", 1.9, {"color": 0x1a100a, "frame": 0xc9a45a})
	lv.add_inter("door", "Дверь", dp, 1.4, 2.7)
	lv.spawn = dp + Vector3(-0.4, 0, 0)
	lv.spawn_rot = -PI / 2.0
	F.rug(lv, 0.0, 0.2, 4.2, 3.2, 0x4a1014, 0x24080a)
	var ds := F.desk(lv, 0.0, -1.2, 0.0, {"w": 2.2, "d": 0.95, "color": 0x1c120c, "drawer": 0x26180f})
	lv.set_meta("desk", ds)
	# три предмета
	var cig := B.cyl(ds, 0.012, 0.012, 0.16, Vector3(-0.42, 0.81, 0.18), 0xf2efe6, 6)
	cig.rotation = Vector3(0, 0.5, PI / 2.0)
	B.box(ds, Vector3(0.05, 0.075, 0.025), Vector3(-0.12, 0.835, 0.2), 0xc9a45a, {"metal": 0.9, "rough": 0.2})
	F.pistol(ds, Vector3(0.32, 0.8, 0.2), -0.5)
	lv.set_meta("cig", cig)
	F.chair(lv, 0.0, -2.2, 0.0, {"color": 0x1c120c, "seat": 0x4a1014})
	F.bookcase(lv, -3.25, -1.0, PI / 2.0, {"w": 2.8, "h": 2.9, "color": 0x1c120c})
	F.bookcase(lv, 3.25, -1.3, -PI / 2.0, {"w": 2.2, "h": 2.9, "color": 0x1c120c})
	F.painting(lv, "back", 0.0, 2.3, 1.1, 1.4, [0x0e0c0b, 0x3a1a16, 0xc9a45a], 0xc9a45a)
	# единственный свет — над столом
	B.box(lv, Vector3(0.02, 1.2, 0.02), Vector3(0, 2.8, -1.0), 0x0a0a0a, {"noshadow": true})
	B.cyl(lv, 0.1, 0.36, 0.22, Vector3(0, 2.15, -1.0), 0x16302a, 8, {"noshadow": true})
	var sl := B.spot(lv, Vector3(0, 2.1, -1.0), Vector3(0, -1, 0.02), 0xffe2b0, 4.2, 7.0, 48.0, true)
	sl.light_volumetric_fog_energy = 3.0
	B.omni(lv, Vector3(0, 2.4, 0.8), 0xffd9a0, 0.55, 8.0)
	lv.add_inter("table", "Стол", Vector3(0.0, 0, -0.9), 1.6, 1.7)
	return lv
