class_name Human
extends Node3D
## Low-poly человек из примитивов с процедурной анимацией. Лицом смотрит в локальную +Z.

signal arrived

const POSES := {
	# arm_l, arm_r, hip, knee, root_y, lean
	"stand": [0.04, 0.04, 0.0, 0.0, 0.0, 0.0],
	"sit": [-0.55, -0.55, -PI / 2.0, PI / 2.0, -0.32, 0.0],
	"behind": [0.32, 0.32, 0.0, 0.0, 0.0, -0.03],
	"aim": [0.04, -1.5, 0.0, 0.0, 0.0, 0.0],
	"fight": [-1.2, -1.45, 0.0, 0.0, 0.0, 0.18],
	"fish": [-0.95, -0.95, -PI / 2.0, PI / 2.0, -0.32, 0.22],
	"slump": [0.1, 0.1, 0.0, 0.0, 0.0, 0.3],
	"cower": [-2.3, -2.3, 0.0, 0.2, -0.05, 0.3],
	"write": [-0.25, -1.1, 0.0, 0.0, 0.0, 0.42],
}

var cfg: Dictionary = {}
var root: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var hip_l: Node3D
var hip_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var gun: Node3D
var pose: String = "stand"
var speed_now: float = 0.0
var phase: float = 0.0
var tt: float = 0.0
var home_rot: float = 0.0
var watch: Node3D = null         # на кого поворачивать голову
var lean_extra: float = 0.0
var _target: Variant = null
var _walk_speed: float = 2.2
var _face: Variant = null


func _init(p_cfg: Dictionary = {}) -> void:
	tt = randf() * 10.0
	restyle(p_cfg)


func restyle(p_cfg: Dictionary) -> void:
	cfg = {"skin": 0xd9a47c, "shirt": 0x4a5d73, "pants": 0x2b2f3a, "hair": 0x3a2a1c, "shoes": 0x15151a,
		"coat": -1, "tie": -1, "hat": -1, "cap": -1, "mask": false, "bald": false, "beard": -1,
		"apron": -1, "glasses": false, "long_hair": false, "dress": -1, "scale": 1.0, "sleeves": -1}
	for k in p_cfg:
		cfg[k] = p_cfg[k]
	if root != null:
		remove_child(root)
		root.queue_free()
	_build()


func _build() -> void:
	root = Node3D.new()
	add_child(root)
	var sc: float = cfg.scale
	scale = Vector3(sc, sc, sc) * 0.92
	var skin: int = cfg.skin
	var shirt: int = cfg.shirt
	var pants: int = cfg.pants
	var outer: int = cfg.coat if cfg.coat >= 0 else shirt
	var sleeve: int = cfg.sleeves if cfg.sleeves >= 0 else outer
	var dress: int = cfg.dress

	# таз и ноги
	B.box(root, Vector3(0.46, 0.2, 0.27), Vector3(0, 0.9, 0), pants if dress < 0 else dress)
	hip_l = _leg(-0.125, pants)
	hip_r = _leg(0.125, pants)
	if dress >= 0:
		B.cyl(root, 0.26, 0.42, 0.78, Vector3(0, 0.6, 0), dress, 8)

	# корпус
	torso = Node3D.new()
	torso.position = Vector3(0, 0.98, 0)
	root.add_child(torso)
	B.box(torso, Vector3(0.5, 0.58, 0.28), Vector3(0, 0.3, 0), shirt if dress < 0 else dress)
	if cfg.coat >= 0:
		B.box(torso, Vector3(0.56, 0.62, 0.33), Vector3(0, 0.3, -0.005), outer)
		B.box(torso, Vector3(0.14, 0.5, 0.02), Vector3(0, 0.32, 0.165), shirt)          # вырез пальто / пиджака
		if cfg.get("long_coat", false):
			B.box(root, Vector3(0.56, 0.5, 0.33), Vector3(0, 0.74, -0.005), outer)
	if cfg.tie >= 0:
		B.box(torso, Vector3(0.07, 0.36, 0.02), Vector3(0, 0.34, 0.178), cfg.tie)
	if cfg.apron >= 0:
		B.box(torso, Vector3(0.44, 0.5, 0.03), Vector3(0, 0.22, 0.155), cfg.apron)
		B.box(root, Vector3(0.44, 0.4, 0.03), Vector3(0, 0.76, 0.15), cfg.apron)
	B.box(torso, Vector3(0.16, 0.1, 0.16), Vector3(0, 0.62, 0), skin)                  # шея

	# голова
	head = Node3D.new()
	head.position = Vector3(0, 0.84, 0)
	torso.add_child(head)
	B.ball(head, 0.2, Vector3.ZERO, skin, 8, 5)
	if cfg.mask:
		B.box(head, Vector3(0.3, 0.2, 0.05), Vector3(0, 0.03, 0.17), 0xf2efe6, {"rough": 0.4})
		B.box(head, Vector3(0.07, 0.035, 0.02), Vector3(-0.075, 0.04, 0.2), 0x050505)
		B.box(head, Vector3(0.07, 0.035, 0.02), Vector3(0.075, 0.04, 0.2), 0x050505)
	else:
		B.box(head, Vector3(0.034, 0.04, 0.03), Vector3(-0.075, 0.03, 0.178), 0x15120f)
		B.box(head, Vector3(0.034, 0.04, 0.03), Vector3(0.075, 0.03, 0.178), 0x15120f)
		B.box(head, Vector3(0.05, 0.07, 0.05), Vector3(0, -0.02, 0.19), skin)            # нос
	if cfg.glasses:
		B.box(head, Vector3(0.3, 0.02, 0.02), Vector3(0, 0.04, 0.2), 0x111111)
		B.box(head, Vector3(0.1, 0.08, 0.015), Vector3(-0.078, 0.03, 0.2), 0, {"mat": B.glass_mat(0xcfe6ff, 0.35), "noshadow": true})
		B.box(head, Vector3(0.1, 0.08, 0.015), Vector3(0.078, 0.03, 0.2), 0, {"mat": B.glass_mat(0xcfe6ff, 0.35), "noshadow": true})
	if cfg.beard >= 0:
		B.box(head, Vector3(0.26, 0.14, 0.12), Vector3(0, -0.12, 0.1), cfg.beard)
	if not cfg.bald:
		var hair := B.ball(head, 0.215, Vector3(0, 0.055, -0.035), cfg.hair, 8, 4)
		hair.scale = Vector3(1.0, 0.82, 1.0)
		if cfg.long_hair:
			B.box(head, Vector3(0.36, 0.42, 0.14), Vector3(0, -0.14, -0.13), cfg.hair)
	else:
		var fringe := B.ball(head, 0.21, Vector3(0, 0.0, -0.05), cfg.hair, 8, 4)
		fringe.scale = Vector3(1.0, 0.55, 0.95)
	if cfg.hat >= 0:
		B.cyl(head, 0.34, 0.34, 0.025, Vector3(0, 0.135, 0), cfg.hat, 10)
		B.cyl(head, 0.17, 0.2, 0.17, Vector3(0, 0.225, 0), cfg.hat, 10)
	if cfg.cap >= 0:
		B.cyl(head, 0.2, 0.215, 0.1, Vector3(0, 0.17, 0), cfg.cap, 8)
		B.box(head, Vector3(0.26, 0.02, 0.16), Vector3(0, 0.13, 0.2), cfg.cap)

	# руки
	arm_l = _arm(-0.32, sleeve, skin)
	arm_r = _arm(0.32, sleeve, skin)

	# пистолет в правой руке (скрыт)
	gun = Node3D.new()
	gun.position = Vector3(0, -0.66, 0.02)
	arm_r.add_child(gun)
	B.box(gun, Vector3(0.045, 0.24, 0.09), Vector3(0, -0.1, 0.02), 0x1b1b1f, {"rough": 0.4, "metal": 0.7})
	B.box(gun, Vector3(0.04, 0.09, 0.14), Vector3(0, 0.0, -0.03), 0x151517, {"rough": 0.5, "metal": 0.5})
	gun.visible = false
	_apply_pose(1.0)


func _leg(x: float, pants: int) -> Node3D:
	var hip := Node3D.new()
	hip.position = Vector3(x, 0.88, 0)
	root.add_child(hip)
	B.box(hip, Vector3(0.2, 0.44, 0.22), Vector3(0, -0.22, 0), pants)
	var knee := Node3D.new()
	knee.position = Vector3(0, -0.44, 0)
	hip.add_child(knee)
	B.box(knee, Vector3(0.18, 0.4, 0.2), Vector3(0, -0.2, 0), pants)
	B.box(knee, Vector3(0.2, 0.09, 0.32), Vector3(0, -0.4, 0.05), cfg.shoes, {"rough": 0.5})
	if x < 0.0:
		knee_l = knee
	else:
		knee_r = knee
	return hip


func _arm(x: float, sleeve: int, skin: int) -> Node3D:
	var sh := Node3D.new()
	sh.position = Vector3(x, 0.54, 0)
	torso.add_child(sh)
	B.box(sh, Vector3(0.14, 0.58, 0.16), Vector3(0, -0.27, 0), sleeve)
	B.box(sh, Vector3(0.11, 0.12, 0.12), Vector3(0, -0.62, 0), skin)
	return sh


func _process(delta: float) -> void:
	tt += delta
	if _target != null:
		var to: Vector3 = (_target as Vector3) - position
		to.y = 0.0
		var dist := to.length()
		if dist < 0.07:
			_target = null
			arrived.emit()
		else:
			var step := minf(dist, _walk_speed * delta)
			position += to / dist * step
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, delta * 10.0))
			speed_now = _walk_speed
	elif _face != null:
		rotation.y = lerp_angle(rotation.y, float(_face), minf(1.0, delta * 7.0))

	if speed_now > 0.15:
		phase += delta * (3.6 + speed_now * 1.7)
		var amp := clampf(speed_now / 3.2, 0.45, 1.2)
		var s := sin(phase)
		hip_l.rotation.x = s * 0.7 * amp
		hip_r.rotation.x = -s * 0.7 * amp
		knee_l.rotation.x = maxf(0.0, -cos(phase)) * 0.95 * amp
		knee_r.rotation.x = maxf(0.0, cos(phase)) * 0.95 * amp
		arm_l.rotation.x = -s * 0.55 * amp
		arm_r.rotation.x = s * 0.55 * amp if not gun.visible else -0.2
		root.position.y = absf(cos(phase)) * 0.035 * amp
		torso.rotation.x = 0.06 * amp
	else:
		_apply_pose(minf(1.0, delta * 9.0))
		var br := sin(tt * 1.6) * 0.012
		torso.rotation.x += br
	speed_now = move_toward(speed_now, 0.0, delta * 30.0)

	# поворот головы к наблюдаемому
	var want := 0.0
	if watch != null and is_instance_valid(watch):
		var to_w := watch.global_position - global_position
		to_w.y = 0.0
		if to_w.length() < 6.0 and to_w.length() > 0.3:
			want = clampf(wrapf(atan2(to_w.x, to_w.z) - global_rotation.y, -PI, PI), -1.1, 1.1)
	head.rotation.y = lerp_angle(head.rotation.y, want, minf(1.0, delta * 4.0))


func _apply_pose(k: float) -> void:
	var p: Array = POSES.get(pose, POSES["stand"])
	arm_l.rotation.x = lerpf(arm_l.rotation.x, p[0], k)
	arm_r.rotation.x = lerpf(arm_r.rotation.x, p[1], k)
	hip_l.rotation.x = lerpf(hip_l.rotation.x, p[2], k)
	hip_r.rotation.x = lerpf(hip_r.rotation.x, p[2], k)
	knee_l.rotation.x = lerpf(knee_l.rotation.x, p[3], k)
	knee_r.rotation.x = lerpf(knee_r.rotation.x, p[3], k)
	root.position.y = lerpf(root.position.y, p[4], k)
	torso.rotation.x = lerpf(torso.rotation.x, p[5] + lean_extra, k)


## Идти к точке (корутина — можно await).
func walk_to(target: Vector3, spd: float = 2.2) -> void:
	_target = Vector3(target.x, position.y, target.z)
	_walk_speed = spd
	_face = null
	await arrived


func face_pos(p: Vector3) -> void:
	var to := p - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		_face = atan2(to.x, to.z)


func face_angle(a: float) -> void:
	_face = a


func snap_face(p: Vector3) -> void:
	var to := p - global_position
	rotation.y = atan2(to.x, to.z)
	_face = null


func show_gun(v: bool) -> void:
	gun.visible = v
