class_name Level
extends Node3D
## Локация, собранная кодом: стены, коллизии, точки взаимодействия, персонажи.

var id: String = ""
var w: float = 10.0
var d: float = 8.0
var h: float = 4.0
var outdoor: bool = false
var body: StaticBody3D
var inter: Array = []            # [{id, label, pos, node, r, y, npc}]
var npcs: Dictionary = {}        # id -> Human
var walls: Dictionary = {}       # side -> Node3D
var updaters: Array = []         # Callable(delta)
var flicker: Array = []          # [{light, base, mat, mbase, amt, seed}]
var spawn: Vector3 = Vector3.ZERO
var spawn_rot: float = PI
var cam_yaw: float = 0.0
var cam_dist: float = 8.0
var ambience: String = "quiet"
var light_scale: float = 1.0     # множитель дневного света (вечерние сцены)
var city_elev: float = 0.0
var t: float = 0.0
var _hidden: Dictionary = {}


func _init(p_id: String = "", p_w: float = 10.0, p_d: float = 8.0, p_h: float = 4.0, p_outdoor: bool = false) -> void:
	id = p_id
	w = p_w
	d = p_d
	h = p_h
	outdoor = p_outdoor
	body = StaticBody3D.new()
	add_child(body)
	for s in ["back", "front", "left", "right"]:
		var n := Node3D.new()
		n.name = "wall_" + s
		add_child(n)
		walls[s] = n
		_hidden[s] = false


func add_inter(p_id: String, label: Variant, pos: Vector3, r: float = 1.8, marker_y: float = 2.2, node: Node3D = null) -> Dictionary:
	var it := {"id": p_id, "label": label, "pos": pos, "node": node, "r": r, "y": marker_y, "npc": null}
	inter.append(it)
	return it


func add_npc(p_id: String, hm: Human, pos: Vector3, rot: float, label: String = "Поговорить", r: float = 2.0, solid: bool = true) -> Human:
	hm.position = pos
	hm.rotation.y = rot
	hm.home_rot = rot
	add_child(hm)
	npcs[p_id] = hm
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.32
		cap.height = 1.8
		cs.shape = cap
		cs.position.y = 0.9
		sb.add_child(cs)
		hm.add_child(sb)
	if label != "":
		var it := add_inter(p_id, label, pos, r, 2.35, hm)
		it["npc"] = hm
	return hm


func find_inter(p_id: String) -> Dictionary:
	for it in inter:
		if it.id == p_id:
			return it
	return {}


func remove_inter(p_id: String) -> void:
	for i in range(inter.size() - 1, -1, -1):
		if inter[i].id == p_id:
			inter.remove_at(i)


func remove_npc(p_id: String) -> void:
	if npcs.has(p_id):
		var hm: Human = npcs[p_id]
		npcs.erase(p_id)
		hm.queue_free()
	remove_inter(p_id)


func inter_pos(it: Dictionary) -> Vector3:
	var n: Variant = it.get("node")
	if n != null and is_instance_valid(n):
		return (n as Node3D).global_position
	return it.pos


func inter_label(it: Dictionary) -> String:
	var l: Variant = it.label
	if l is Callable:
		return str((l as Callable).call())
	return str(l)


func add_flicker(light: Light3D, amount: float, mat: StandardMaterial3D = null) -> void:
	flicker.append({"light": light, "base": light.light_energy, "mat": mat,
		"mbase": (mat.emission_energy_multiplier if mat != null else 0.0), "amt": amount, "seed": randf() * 100.0})


func _process(delta: float) -> void:
	t += delta
	for u in updaters:
		(u as Callable).call(delta)
	for f in flicker:
		var sd: float = f.seed
		var k: float = 1.0 - f.amt * (0.5 + 0.5 * sin(t * 13.0 + sd) * sin(t * 7.3 + sd * 2.0))
		if f.amt > 0.5 and sin(t * 1.7 + sd) > 0.93:
			k *= 0.15
		(f.light as Light3D).light_energy = f.base * k
		if f.mat != null:
			(f.mat as StandardMaterial3D).emission_energy_multiplier = f.mbase * k
	if outdoor:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	_set_wall("back", p.z < -d / 2.0 + 0.4)
	_set_wall("front", p.z > d / 2.0 - 0.4)
	_set_wall("left", p.x < -w / 2.0 + 0.4)
	_set_wall("right", p.x > w / 2.0 - 0.4)


## Стена между камерой и комнатой остаётся только в тенях — «кукольный домик».
func _set_wall(side: String, hide: bool) -> void:
	if _hidden[side] == hide:
		return
	_hidden[side] = hide
	_cut(walls[side], hide)


func _cut(n: Node, hide: bool) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			var g := c as GeometryInstance3D
			if not g.has_meta("cs0"):
				g.set_meta("cs0", g.cast_shadow)
			var orig: int = g.get_meta("cs0")
			if orig == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				g.visible = not hide
			else:
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if hide else orig
		elif c is Light3D:
			pass
		_cut(c, hide)
