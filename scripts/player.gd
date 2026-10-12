class_name Player
extends CharacterBody3D
## Игрок: движение относительно камеры, шаги, сценарные перемещения.

signal arrived

const WALK := 3.0
const RUN := 5.4

var human: Human
var aura: OmniLight3D            # мягкая подсветка героя в тёмных сценах
var _dist: float = 0.0
var _target: Variant = null
var _tspeed: float = 2.4


## Внешность героя меняется от главы к главе.
static func look(ch: int) -> Dictionary:
	match ch:
		1:
			return {"shirt": 0xd8d2c4, "coat": 0x7d93ab, "pants": 0x3d4654, "hair": 0x4a3524, "shoes": 0x3a2a20}
		2:
			return {"shirt": 0xc8c2b6, "coat": 0x5f7186, "pants": 0x363d49, "hair": 0x4a3524, "shoes": 0x2a2018}
		3:
			return {"shirt": 0x9a968e, "coat": 0x454b57, "long_coat": true, "pants": 0x2c313a, "hair": 0x4a3524}
		4:
			return {"shirt": 0x77746e, "coat": 0x2b2e36, "long_coat": true, "pants": 0x202329, "hair": 0x4a3524, "hat": 0x1e2026}
		_:
			return {"shirt": 0xf2efe6, "coat": 0x101114, "pants": 0x101114, "hair": 0x4a3524, "tie": 0x0a0a0a, "shoes": 0x050505}


func _init() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.86
	add_child(cs)
	human = Human.new(look(1))
	add_child(human)
	aura = OmniLight3D.new()
	aura.position = Vector3(0, 2.5, 0.3)
	aura.omni_range = 4.5
	aura.omni_attenuation = 1.2
	aura.light_color = Color(0.85, 0.9, 1.0)
	aura.light_energy = 0.0
	aura.light_volumetric_fog_energy = 0.0
	add_child(aura)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING


func restyle(ch: int) -> void:
	human.restyle(look(ch))


func teleport(pos: Vector3, rot: float) -> void:
	_target = null
	global_position = Vector3(pos.x, 0.0, pos.z)
	human.rotation.y = rot
	human._face = null
	velocity = Vector3.ZERO


func face_pos(p: Vector3) -> void:
	var to := p - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		human._face = atan2(to.x, to.z)


## Сценарное перемещение (без коллизий).
func walk_to(target: Vector3, spd: float = 2.4) -> void:
	_target = Vector3(target.x, 0.0, target.z)
	_tspeed = spd
	human._face = null
	await arrived


func _physics_process(delta: float) -> void:
	if _target != null:
		var to: Vector3 = (_target as Vector3) - global_position
		to.y = 0.0
		var dl := to.length()
		if dl < 0.08:
			_target = null
			arrived.emit()
		else:
			global_position += to / dl * minf(dl, _tspeed * delta)
			human.rotation.y = lerp_angle(human.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 10.0))
			human.speed_now = _tspeed
			_steps(_tspeed * delta)
		return
	var dir := Vector3.ZERO
	if not Game.busy and not Game.paused and Game.started:
		var f := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
		var r := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		var yaw: float = Game.cam_yaw
		dir = Vector3(-sin(yaw), 0, -cos(yaw)) * f + Vector3(cos(yaw), 0, -sin(yaw)) * r
		if dir.length() > 0.01:
			dir = dir.normalized()
	var spd := RUN if Input.is_physical_key_pressed(KEY_SHIFT) else WALK
	velocity = dir * spd
	if dir != Vector3.ZERO:
		human._face = null
		move_and_slide()
		global_position.y = 0.0
		human.rotation.y = lerp_angle(human.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 12.0))
		var real := get_real_velocity().length()
		human.speed_now = maxf(real, 0.6)
		_steps(real * delta)


func _steps(moved: float) -> void:
	_dist += moved
	if _dist > 0.78:
		_dist = 0.0
		Au.sfx("step", -9.0, randf_range(0.9, 1.12))
