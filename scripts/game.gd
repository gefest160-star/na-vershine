extends Node
## Ядро: состояние, мир, камера, погода, взаимодействие, переходы между локациями.

const SAVE_PATH := "user://save.json"
const PITCH_DEFAULT := 0.47

## Погода и настроение по главам: от ясного дня к грозе и мёртвой ночи.
const WEATHER := {
	1: {"sky": 0x9fcdea, "amb": 0xfff0dc, "amb_e": 0.62, "sun": 0xffe2b0, "sun_e": 2.4, "fog": 0xcfe0ec, "fog_d": 0.003,
		"vol": 0.004, "rain": 0.0, "bolt": 0.0, "wind": 0.0, "sat": 1.1, "con": 1.02, "bri": 1.0, "bulb": 0xffd9a0, "bulb_e": 1.0, "lit": 0.0},
	2: {"sky": 0x79858f, "amb": 0xc4ccd6, "amb_e": 0.5, "sun": 0xb9c2cc, "sun_e": 0.75, "fog": 0x7f8b96, "fog_d": 0.009,
		"vol": 0.012, "rain": 0.35, "bolt": 0.0, "wind": 0.12, "sat": 0.85, "con": 1.04, "bri": 0.98, "bulb": 0xffcf94, "bulb_e": 0.9, "lit": 0.25},
	3: {"sky": 0x2c3440, "amb": 0x8a98b0, "amb_e": 0.52, "sun": 0x7d8eb0, "sun_e": 0.32, "fog": 0x2a323d, "fog_d": 0.016,
		"vol": 0.02, "rain": 0.8, "bolt": 0.55, "wind": 0.35, "sat": 0.62, "con": 1.1, "bri": 0.96, "bulb": 0xe6dcc8, "bulb_e": 0.75, "lit": 0.4},
	4: {"sky": 0x10151d, "amb": 0x6a7a98, "amb_e": 0.46, "sun": 0x5a6aa0, "sun_e": 0.16, "fog": 0x11161f, "fog_d": 0.024,
		"vol": 0.028, "rain": 1.0, "bolt": 1.0, "wind": 0.7, "sat": 0.4, "con": 1.16, "bri": 0.95, "bulb": 0xd6d6e6, "bulb_e": 0.6, "lit": 0.3},
	5: {"sky": 0x070910, "amb": 0x7c86a0, "amb_e": 0.44, "sun": 0x6878a8, "sun_e": 0.18, "fog": 0x090b12, "fog_d": 0.014,
		"vol": 0.012, "rain": 0.0, "bolt": 0.0, "wind": 0.1, "sat": 0.16, "con": 1.2, "bri": 0.97, "bulb": 0xffe6c0, "bulb_e": 0.9, "lit": 0.55},
}

var chapter: int = 1
var stage: int = 0
var flags: Dictionary = {}
var entered: Dictionary = {}
var busy: bool = true
var paused: bool = false
var started: bool = false
var autoplay: bool = false
var auto_choice: int = 0
var shot_mode: bool = false
var menu_mode: bool = false      # за главным меню медленно плывёт камера по пентхаусу
var demo: bool = false           # самопрохождение в реальном времени (для просмотра сцен)
var _frame_t: float = 0.0
var _frame_n: int = 0
var _clock: float = 0.0
var args: Dictionary = {}

var world: Node3D
var env: Environment
var camera: Camera3D
var sun: DirectionalLight3D
var bolt: DirectionalLight3D
var rain: GPUParticles3D
var rain_col: GPUParticlesCollisionBox3D
var player: Player
var level: Level
var marker: Node3D

var cam_yaw: float = 0.0
var cam_pitch: float = PITCH_DEFAULT
var cam_dist: float = 8.0
var focus: Variant = null
var shake_amt: float = 0.0
var _ct: Vector3 = Vector3.ZERO
var _cy: float = 0.0
var _cp: float = PITCH_DEFAULT
var _cd: float = 8.0
var _near: Dictionary = {}
var _drag: bool = false
var _bolt_t: float = 6.0
var _siren_t: float = 20.0
var _saved_chapter: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var s: String = a.trim_prefix("--")
		var kv := s.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_load_save()


func W() -> Dictionary:
	return WEATHER[chapter]


func log_line(s: String) -> void:
	print(s)


func wait(t: float) -> void:
	if autoplay:
		await get_tree().process_frame
		return
	await get_tree().create_timer(t, false).timeout


# ---------- Запуск ----------

func boot() -> void:
	_build_world()
	# обычный запуск — на весь экран; отладочные режимы остаются в окне
	var windowed := false
	for k in ["shot", "demo", "autoplay", "reach", "bot", "quit_after", "window", "restart_test"]:
		if args.has(k):
			windowed = true
	if not windowed and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if args.has("bot"):
		AudioServer.set_bus_mute(0, true)
		Engine.time_scale = float(args.get("speed", "3"))
	if args.has("mute"):
		AudioServer.set_bus_mute(0, true)
	if args.has("press_new"):
		get_tree().create_timer(2.0).timeout.connect(func(): UI.btn_new.pressed.emit())
	if args.has("snap"):
		get_tree().create_timer(float(args.get("snap_at", "5"))).timeout.connect(func():
			get_viewport().get_texture().get_image().save_png(args["snap"]))
	if args.has("restart_test"):
		get_tree().create_timer(3.0).timeout.connect(func(): new_game())
	if args.has("quit_after"):
		get_tree().create_timer(float(args["quit_after"])).timeout.connect(func(): get_tree().quit())
	if args.has("autoplay"):
		autoplay = true
		auto_choice = int(args.get("choice", "0"))
		Engine.time_scale = 6.0
		Au.voice_on = false
		AudioServer.set_bus_mute(0, true)
		UI.hide_menu()
		started = true
		_autoplay()
		return
	if args.has("reach"):
		shot_mode = true
		AudioServer.set_bus_mute(0, true)
		UI.hide_menu()
		_reach_test()
		return
	if args.has("demo"):
		demo = true
		shot_mode = true
		auto_choice = int(args.get("choice", "0"))
		Au.voice_on = false
		AudioServer.set_bus_mute(0, true)
		UI.hide_menu()
		started = true
		_autoplay()
		return
	if args.has("shot"):
		shot_mode = true
		AudioServer.set_bus_mute(0, true)
		UI.hide_menu()
		_shot()
		return
	if args.has("ch"):
		UI.hide_menu()
		started = true
		start_chapter(int(args["ch"]), int(args.get("stage", "0")))
		return
	_menu_backdrop()


## Главное меню поверх живой сцены.
func _menu_backdrop() -> void:
	menu_mode = true
	chapter = 2
	stage = 1
	busy = true
	load_level("penthouse")
	player.visible = false
	UI.set_objective("")
	UI.set_chapter("")
	UI.location("")
	focus_on(Vector3(0.5, 1.7, -1.0), 10.5, 0.24, 0.55)
	_snap_camera()
	UI.fade_rect.color.a = 0.0
	UI.show_menu("start", _saved_chapter > 1, ("Глава %d" % _saved_chapter) if _saved_chapter > 1 else "")
	Au.music("menu", 0.8)


func _leave_menu() -> void:
	menu_mode = false
	player.visible = true
	focus = null


func new_game() -> void:
	if started:
		# посреди игры сценарные корутины ещё ждут ввода — чище всего перезапустить процесс
		_saved_chapter = 1
		save_settings()
		var eng: Array = []
		if not OS.has_feature("template"):
			# запуск из исходников: движку нужно заново указать папку проекта
			eng.append("--path")
			eng.append(ProjectSettings.globalize_path("res://"))
		for a in OS.get_cmdline_args():
			if a == "--":
				break
			if a == "--windowed":
				eng.append(a)
		eng.append("--")
		for a in OS.get_cmdline_user_args():
			if not (a.begins_with("--ch=") or a.begins_with("--stage=") or a.begins_with("--restart_test")):
				eng.append(a)
		eng.append("--ch=1")
		OS.set_restart_on_exit(true, PackedStringArray(eng))
		get_tree().quit()
		return
	Story.finished = false
	Story.guilt = 0
	flags.clear()
	_leave_menu()
	UI.hide_menu()
	get_tree().paused = false
	paused = false
	started = true
	Au.sfx("blip")
	start_chapter(1)


func continue_game() -> void:
	Story.finished = false
	_leave_menu()
	UI.hide_menu()
	started = true
	Au.sfx("blip")
	start_chapter(maxi(1, _saved_chapter))


## Финал сыгран: сохранение сбрасывается, возвращаемся в меню.
func finish_game() -> void:
	_saved_chapter = 0
	save_settings()
	started = false
	busy = true
	if level != null:
		world.remove_child(level)
		level.queue_free()
		level = null
	if not autoplay and not args.has("bot"):
		_menu_backdrop()


func resume() -> void:
	paused = false
	get_tree().paused = false
	UI.hide_menu()


func _build_world() -> void:
	world = Node3D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	var we := WorldEnvironment.new()
	env = Environment.new()
	we.environment = env
	world.add_child(we)
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.fog_enabled = true
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_ambient_inject = 0.1
	env.adjustment_enabled = true

	camera = Camera3D.new()
	camera.fov = 46.0
	camera.near = 0.15
	camera.far = 400.0
	world.add_child(camera)
	camera.current = true

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_bias = 0.04
	sun.shadow_blur = 1.4
	sun.light_volumetric_fog_energy = 1.6
	world.add_child(sun)

	bolt = DirectionalLight3D.new()
	bolt.light_color = Color(0.78, 0.85, 1.0)
	bolt.light_energy = 0.0
	bolt.shadow_enabled = true
	bolt.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	bolt.directional_shadow_max_distance = 60.0
	bolt.light_volumetric_fog_energy = 2.5
	bolt.basis = Basis.looking_at(Vector3(-0.3, -0.6, 0.75).normalized())
	world.add_child(bolt)

	# дождь
	rain = GPUParticles3D.new()
	rain.amount = 14000
	rain.lifetime = 1.3
	rain.preprocess = 1.3
	rain.local_coords = false
	rain.visibility_aabb = AABB(Vector3(-40, -50, -40), Vector3(80, 70, 80))
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(26, 0.5, 26)
	pm.direction = Vector3(0.1, -1.0, 0.04)
	pm.spread = 1.5
	pm.initial_velocity_min = 22.0
	pm.initial_velocity_max = 27.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	rain.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.022, 0.75)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.72, 0.8, 0.95, 0.32)
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	rm.billboard_keep_scale = true
	rm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	rm.distance_fade_min_distance = 3.5
	rm.distance_fade_max_distance = 9.0
	qm.material = rm
	rain.draw_pass_1 = qm
	rain.emitting = false
	world.add_child(rain)
	rain_col = GPUParticlesCollisionBox3D.new()
	world.add_child(rain_col)

	player = Player.new()
	world.add_child(player)

	# маркер цели
	marker = Node3D.new()
	world.add_child(marker)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(1.0, 0.8, 0.4)
	mm.emission_enabled = true
	mm.emission = Color(1.0, 0.75, 0.3)
	mm.emission_energy_multiplier = 2.0
	var dm := B.ball(marker, 0.15, Vector3.ZERO, 0, 4, 1, {"mat": mm, "noshadow": true})
	dm.scale = Vector3(1.0, 1.5, 1.0)
	marker.visible = false


# ---------- Локации ----------

func load_level(id: String) -> void:
	if level != null:
		world.remove_child(level)
		level.queue_free()
		level = null
	_near = {}
	UI.set_prompt("")
	B.light_mul = [1.0, 1.0, 1.3, 1.8, 2.3, 2.3][chapter]
	level = Levels.build(id)
	world.add_child(level)
	_apply_env()
	player.teleport(level.spawn, level.spawn_rot)
	cam_yaw = level.cam_yaw
	cam_dist = level.cam_dist
	cam_pitch = PITCH_DEFAULT
	focus = null
	Story.setup_level(level)
	for hm in level.npcs.values():
		(hm as Human).watch = player
	_snap_camera()
	refresh_objective()
	if not shot_mode:
		UI.location(Story.title(id))
	var wd: Dictionary = W()
	Au.set_scene(level.ambience, wd.rain, not level.outdoor, wd.wind)
	Au.music(Story.music_for(id))


func _apply_env() -> void:
	var wd: Dictionary = W()
	var ls: float = level.light_scale
	env.background_color = B.C(wd.sky).lerp(Color.BLACK, 1.0 - ls) if ls < 1.0 else B.C(wd.sky)
	env.ambient_light_color = B.C(wd.amb)
	env.ambient_light_energy = wd.amb_e * lerpf(0.55, 1.0, ls)
	env.fog_light_color = B.C(wd.fog).lerp(Color.BLACK, (1.0 - ls) * 0.7)
	env.fog_density = wd.fog_d
	env.volumetric_fog_density = wd.vol
	env.volumetric_fog_albedo = B.C(wd.fog).lerp(Color.WHITE, 0.4)
	env.adjustment_saturation = wd.sat
	env.adjustment_contrast = wd.con
	env.adjustment_brightness = wd.bri
	sun.light_color = B.C(wd.sun)
	sun.light_energy = wd.sun_e * ls
	sun.basis = Basis.looking_at(Vector3(0.42, -0.72, 0.62).normalized())
	bolt.light_energy = 0.0
	player.aura.light_energy = [0.0, 0.0, 0.25, 0.5, 0.75, 0.45][chapter] * (1.6 if ls < 0.5 else 1.0)
	rain.emitting = wd.rain > 0.02
	rain.amount_ratio = clampf(wd.rain, 0.05, 1.0)
	if level.outdoor:
		rain_col.size = Vector3(0.1, 0.1, 0.1)
		rain_col.position = Vector3(0, -500, 0)
	else:
		rain_col.size = Vector3(level.w + 0.5, level.h + 40.0, level.d + 0.5)
		rain_col.position = Vector3(0, level.h / 2.0 + 19.0, 0)


## Смена главы: титульная карточка, новая погода, новая стартовая локация.
func start_chapter(n: int, p_stage: int = 0) -> void:
	busy = true
	chapter = n
	stage = p_stage
	entered.clear()
	_saved_chapter = n
	save_settings()
	UI.hide_dialog()
	UI.cine(false)
	UI.set_objective("")
	await UI.fade(true, 0.6)
	player.restyle(n)
	var ch: Dictionary = Story.chapters[n]
	UI.set_chapter("Глава %d  ·  %s" % [n, ch.name])
	Au.music(Story.music_for(Story.stage_def().scene))
	await UI.card("Глава %d" % n, ch.name, 2.6)
	load_level(Story.stage_def().scene)
	await wait(0.4)
	await UI.fade(false, 1.6)
	await Story.on_enter()
	UI.hide_dialog()
	UI.cine(false)
	focus = null
	busy = false
	refresh_objective()


## Переход через дверь.
func travel(dest: String) -> void:
	busy = true
	Au.sfx("door")
	await UI.fade(true, 0.55)
	UI.hide_dialog()
	load_level(dest)
	await wait(0.3)
	await UI.fade(false, 0.9)
	await Story.on_enter()


func refresh_objective() -> void:
	UI.set_objective(Story.objective_text())


# ---------- Камера ----------

func focus_on(pos: Vector3, dist: float, pitch: float = 0.3, yaw: Variant = null) -> void:
	focus = {"pos": pos, "dist": dist, "pitch": pitch, "yaw": yaw}


func focus_two(a: Vector3, b: Vector3) -> void:
	var line := b - a
	var ang := atan2(line.x, line.z)
	var y1 := ang + PI / 2.0
	var y2 := ang - PI / 2.0
	var yaw := y1 if absf(angle_difference(cam_yaw, y1)) < absf(angle_difference(cam_yaw, y2)) else y2
	# не строго сбоку — чуть из-за плеча героя
	yaw = lerp_angle(yaw, cam_yaw, 0.25)
	focus = {"pos": (a + b) / 2.0 + Vector3(0, 1.3, 0), "dist": maxf(4.4, line.length() * 1.5 + 2.8), "pitch": 0.2, "yaw": yaw}


func focus_clear() -> void:
	focus = null


func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)


func _cam_goal() -> Array:
	var target := player.global_position + Vector3(0, 1.25, 0)
	var dist := cam_dist
	var pitch := cam_pitch
	var yaw := cam_yaw
	if focus == null and level != null and not level.outdoor:
		# держим комнату в кадре: камера не уезжает за героем к самой стене
		var mx := maxf(0.0, level.w / 2.0 - 4.2)
		var mz := maxf(0.0, level.d / 2.0 - 2.8)
		var cl := Vector3(clampf(target.x, -mx, mx), target.y, clampf(target.z, -mz, mz))
		target = target.lerp(cl, 0.8)
	if focus != null:
		target = focus.pos
		dist = focus.dist
		pitch = focus.pitch
		if focus.yaw != null:
			yaw = focus.yaw
	return [target, dist, pitch, yaw]


func _snap_camera() -> void:
	var g := _cam_goal()
	_ct = g[0]
	_cd = g[1]
	_cp = g[2]
	_cy = g[3]
	_place_camera()


func _place_camera() -> void:
	var off := Vector3(sin(_cy) * cos(_cp), sin(_cp), cos(_cy) * cos(_cp)) * _cd
	var sh := Vector3.ZERO
	if shake_amt > 0.001:
		sh = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake_amt * 0.25
	camera.global_position = _ct + off + sh
	camera.look_at(_ct + sh * 0.5, Vector3.UP)


func _update_camera(delta: float) -> void:
	var g := _cam_goal()
	var k := 1.0 - exp(-delta * (3.2 if focus != null else 7.0))
	_ct = _ct.lerp(g[0], k)
	_cd = lerpf(_cd, g[1], k)
	_cp = lerpf(_cp, g[2], k)
	_cy = lerp_angle(_cy, g[3], k)
	shake_amt = move_toward(shake_amt, 0.0, delta * 1.6)
	_place_camera()


# ---------- Цикл ----------

func _process(delta: float) -> void:
	if demo and args.has("frames"):
		_clock += delta
		_frame_t -= delta
		if _clock >= float(args.get("from", "0")) and _frame_t <= 0.0:
			_frame_t = float(args.get("every", "1.0"))
			var img := get_viewport().get_texture().get_image()
			img.resize(800, 450, Image.INTERPOLATE_BILINEAR)
			img.save_png("%s/f%03d.png" % [args["frames"], _frame_n])
			_frame_n += 1
		if _clock >= float(args.get("until", "30")):
			get_tree().quit()
	if args.has("bot") and Story.finished and not started:
		print("BOT DONE")
		get_tree().quit()
		return
	if world == null or level == null or paused:
		return
	if args.has("bot"):
		_bot(delta)
	if menu_mode and focus != null:
		focus.yaw = float(focus.yaw) + delta * 0.035
	if not busy:
		var turn := float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
		cam_yaw += turn * delta * 1.8
	_update_camera(delta)
	rain.global_position = Vector3(camera.global_position.x, camera.global_position.y + 15.0, camera.global_position.z)
	_update_rain_mask()
	_update_marker(delta)
	_update_near()
	_update_weather(delta)


## Дождя нет ни в комнате, ни между камерой и комнатой — только за окнами и по сторонам.
func _update_rain_mask() -> void:
	if level.outdoor:
		return
	var cp := camera.global_position
	var x0 := minf(-level.w / 2.0 - 0.3, cp.x - 2.0)
	var x1 := maxf(level.w / 2.0 + 0.3, cp.x + 2.0)
	var z0 := minf(-level.d / 2.0 - 0.3, cp.z - 2.0)
	var z1 := maxf(level.d / 2.0 + 0.3, cp.z + 2.0)
	rain_col.size = Vector3(x1 - x0, level.h + 40.0, z1 - z0)
	rain_col.position = Vector3((x0 + x1) / 2.0, level.h / 2.0 + 19.0, (z0 + z1) / 2.0)


func _update_near() -> void:
	if busy:
		if not _near.is_empty():
			_near = {}
			UI.set_prompt("")
		return
	var best: Dictionary = {}
	var best_d := 1e9
	var pp := player.global_position
	for it in level.inter:
		var ip := level.inter_pos(it)
		var dd := Vector2(ip.x - pp.x, ip.z - pp.z).length()
		if dd < it.r and dd < best_d:
			best_d = dd
			best = it
	if best.is_empty():
		if not _near.is_empty():
			_near = {}
			UI.set_prompt("")
	elif _near.is_empty() or _near.id != best.id:
		_near = best
		UI.set_prompt(level.inter_label(best))


func _update_marker(delta: float) -> void:
	var it := Story.target_inter()
	if it.is_empty() or busy:
		marker.visible = false
		return
	marker.visible = true
	var p := level.inter_pos(it)
	marker.global_position = Vector3(p.x, float(it.y) + sin(level.t * 2.4) * 0.09, p.z)
	marker.rotation.y += delta * 2.0


func _update_weather(delta: float) -> void:
	var wd: Dictionary = W()
	if wd.bolt > 0.0 and started:
		_bolt_t -= delta
		if _bolt_t <= 0.0:
			_bolt_t = randf_range(5.0, 15.0) / float(wd.bolt)
			strike()
	if chapter >= 2 and chapter <= 4 and started and not level.outdoor:
		_siren_t -= delta
		if _siren_t <= 0.0:
			_siren_t = randf_range(35.0, 80.0)
			Au.sfx("siren", -16.0)


## Молния: вспышка света сквозь окна и гром с задержкой.
func strike(strength: float = 1.0) -> void:
	bolt.basis = Basis.looking_at(Vector3(randf_range(-0.2, 0.55), -0.62, 0.72).normalized())
	var tw := create_tween()
	tw.tween_property(bolt, "light_energy", 5.5 * strength, 0.04)
	tw.tween_property(bolt, "light_energy", 0.7, 0.09)
	tw.tween_property(bolt, "light_energy", 4.0 * strength, 0.05)
	tw.tween_property(bolt, "light_energy", 0.0, 0.55)
	var tw2 := create_tween()
	tw2.tween_property(env, "background_energy_multiplier", 5.0, 0.04)
	tw2.tween_property(env, "background_energy_multiplier", 1.0, 0.6)
	UI.flash(0.1 * strength, 0.45)
	if not autoplay:
		get_tree().create_timer(randf_range(0.25, 1.5), false).timeout.connect(func(): Au.sfx("thunder", -1.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).physical_keycode
		if k == KEY_F11:
			var m := DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if m == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif k == KEY_ESCAPE and started and not Story.finished:
			if paused:
				resume()
			else:
				paused = true
				get_tree().paused = true
				UI.show_menu("pause")
		elif k == KEY_E and not busy and not paused and not _near.is_empty():
			interact(_near)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist - 0.5, 4.0, 12.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist + 0.5, 4.0, 12.0)
	elif event is InputEventMouseMotion and _drag and not busy and not paused:
		var mm := event as InputEventMouseMotion
		cam_yaw -= mm.relative.x * 0.006
		cam_pitch = clampf(cam_pitch + mm.relative.y * 0.004, 0.15, 1.2)


## Взаимодействие с точкой: камера, сценарий, возврат управления.
func interact(it: Dictionary) -> void:
	busy = true
	UI.set_prompt("")
	_near = {}
	var lv := level
	var p := lv.inter_pos(it)
	var iid: String = it.id
	player.face_pos(p)
	var npc: Variant = it.get("npc")
	if npc != null and is_instance_valid(npc):
		var hm := npc as Human
		if hm.pose != "sit" and hm.pose != "fish":
			hm.face_pos(player.global_position)
		focus_two(player.global_position, hm.global_position)
	elif iid != "exit":
		focus_on((player.global_position + p) / 2.0 + Vector3(0, 1.15, 0), 5.6, 0.36)
	UI.cine(true)
	if iid != "exit":
		Au.sfx("blip", -6.0)
	await Story.interact(lv.id, iid)
	if Story.finished:
		return
	UI.hide_dialog()
	UI.cine(false)
	focus = null
	if is_instance_valid(lv) and npc != null and is_instance_valid(npc):
		var hm2 := npc as Human
		if hm2.pose != "sit" and hm2.pose != "fish":
			hm2.face_angle(hm2.home_rot)
	busy = false
	refresh_objective()


# ---------- Сохранение ----------

func save_settings() -> void:
	if autoplay or shot_mode:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"chapter": _saved_chapter, "voice": Au.voice_on, "music": Au.vol_music, "sfx": Au.vol_sfx, "vvol": Au.vol_voice}))


func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		_saved_chapter = int(data.get("chapter", 0))
		Au.voice_on = bool(data.get("voice", true))
		Au.vol_music = float(data.get("music", 0.45))
		Au.vol_sfx = float(data.get("sfx", 0.8))
		Au.vol_voice = float(data.get("vvol", 1.0))
		Au._apply_volumes()


# ---------- Отладка: скриншоты и автопрохождение ----------

func _shot() -> void:
	chapter = int(args.get("ch", "1"))
	stage = int(args.get("stage", "0"))
	player.restyle(chapter)
	UI.fade_rect.color.a = 0.0
	started = true
	load_level(args["shot"])
	if args.has("yaw"):
		cam_yaw = deg_to_rad(float(args["yaw"]))
	if args.has("pitch"):
		cam_pitch = deg_to_rad(float(args["pitch"]))
	if args.has("dist"):
		cam_dist = float(args["dist"])
	if args.has("px"):
		player.teleport(Vector3(float(args["px"]), 0, float(args.get("pz", "0"))), float(args.get("prot", "3.14")))
	_snap_camera()
	if args.has("bolt"):
		bolt.light_energy = float(args["bolt"])
	busy = args.has("nohud")
	if args.has("say"):
		UI.cine(true)
		UI.say("patron", "Закон — инструмент. Как нож. Одни режут им хлеб, другие — горло. Важно лишь, в чьих он руках.")
	if args.has("choose"):
		UI.cine(true)
		UI.say("think", "Плотный конверт, запечатанный красным сургучом. Ни имени, ни адреса.")
		UI.choose(["Убрать в карман, не разглядывая.", "Посмотреть на просвет."])
	if args.has("menu"):
		_saved_chapter = 3
		_menu_backdrop()
	await get_tree().create_timer(float(args.get("wait", "1.6"))).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(args.get("out", "user://shot.png"))
	print("SHOT saved: ", args.get("out", "user://shot.png"))
	get_tree().quit()


func _autoplay() -> void:
	chapter = int(args.get("ch", "1"))
	await start_chapter(chapter, int(args.get("stage", "0")))
	var guard := 0
	while not Story.finished and guard < 400:
		guard += 1
		var st: Dictionary = Story.stage_def()
		log_line("--- гл.%d эт.%d  [%s -> %s]  %s" % [chapter, stage, st.scene, st.target, st.obj])
		var ch0 := chapter
		var st0 := stage
		var was_target: bool = st.scene == level.id
		var it: Dictionary = level.find_inter(st.target) if was_target else level.find_inter("exit")
		if it.is_empty():
			log_line("!!! нет точки взаимодействия '%s' в '%s'" % [st.target, level.id])
			break
		# попутно дёргаем все второстепенные точки — проверка «флейвора»
		if args.has("flavor"):
			for other in level.inter.duplicate():
				if other.id != it.id and other.id != "exit" and is_instance_valid(level):
					await interact(other)
		var p := level.inter_pos(it)
		player.teleport(p + Vector3(0.6, 0, 0.6), 0.0)
		await get_tree().process_frame
		await interact(it)
		await get_tree().process_frame
		if ch0 == chapter and st0 == stage and was_target and not Story.finished:
			log_line("!!! этап не продвинулся")
			break
	log_line("AUTOPLAY DONE finished=%s guard=%d" % [str(Story.finished), guard])
	get_tree().quit()


## Проверка проходимости: до каждой точки взаимодействия можно дойти от входа.
func _reach_test() -> void:
	var combos := [[1, "restaurant", 0], [1, "restaurant", 1], [1, "restaurant", 4], [1, "apartment", 2], [1, "station", 3],
		[2, "apartment", 0], [2, "penthouse", 1], [2, "gromov", 2], [2, "shop", 3],
		[3, "apartment", 0], [3, "tower", 1], [3, "reiner", 2], [3, "reiner", 3],
		[4, "apartment", 0], [4, "mansion", 1], [4, "pier", 2], [5, "apartment", 0], [5, "mansion", 1], [5, "cabinet", 3]]
	var bad := 0
	for c in combos:
		chapter = c[0]
		stage = c[2]
		load_level(c[1])
		await get_tree().physics_frame
		await get_tree().physics_frame
		var space := world.get_world_3d().direct_space_state
		var shape := CapsuleShape3D.new()
		shape.radius = 0.3
		shape.height = 1.7
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.exclude = [player.get_rid()]
		var cell := 0.2
		var hx: float = (level.w / 2.0 + 1.0) if not level.outdoor else 4.0
		var hz: float = (level.d / 2.0 + 1.0) if not level.outdoor else 18.0
		var start := Vector2i(roundi(player.global_position.x / cell), roundi(player.global_position.z / cell))
		var seen := {start: true}
		var queue: Array = [start]
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_back()
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: Vector2i = cur + dd
				if seen.has(nx):
					continue
				var wx := float(nx.x) * cell
				var wz := float(nx.y) * cell
				if absf(wx) > hx or absf(wz) > hz:
					continue
				q.transform = Transform3D(Basis(), Vector3(wx, 0.92, wz))
				if not space.intersect_shape(q, 1).is_empty():
					continue
				seen[nx] = true
				queue.append(nx)
		var line := "гл.%d %-10s эт.%d: клеток %d" % [chapter, c[1], stage, seen.size()]
		for it in level.inter:
			var ip := level.inter_pos(it)
			var best := 1e9
			for k in seen:
				var dd2 := Vector2(float(k.x) * cell - ip.x, float(k.y) * cell - ip.z).length()
				if dd2 < best:
					best = dd2
			if best > float(it.r) - 0.25:
				bad += 1
				line += "\n    !!! НЕ ДОЙТИ: %s (ближе %.2f м нельзя, радиус %.2f)" % [it.id, best, it.r]
		print(line)
	print("REACH DONE, проблем: %d" % bad)
	get_tree().quit()

# ---------- Бот: проходит игру настоящими нажатиями клавиш (проверка управления) ----------

var _bot_t: float = 0.0
var _bot_keys: Dictionary = {}
var _bot_last: Vector3 = Vector3.ZERO
var _bot_stuck_t: float = 0.0
var _bot_side_t: float = 0.0
var _bot_side: float = 1.0
var _bot_stage: String = ""
var _bot_clock: float = 0.0


func _bot_key(code: int, down: bool) -> void:
	if _bot_keys.get(code, false) == down:
		return
	_bot_keys[code] = down
	var ev := InputEventKey.new()
	ev.physical_keycode = code as Key
	ev.keycode = code as Key
	ev.pressed = down
	Input.parse_input_event(ev)


func _bot_tap(code: int) -> void:
	_bot_key(code, true)
	_bot_key(code, false)


func _bot_release() -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_bot_key(k, false)


func _bot(delta: float) -> void:
	_bot_clock += delta / Engine.time_scale
	var tag := "%d:%d:%s" % [chapter, stage, level.id]
	if tag != _bot_stage:
		_bot_stage = tag
		print("BOT %6.1fs  гл.%d эт.%d  %s  -> %s" % [_bot_clock, chapter, stage, level.id, Story.objective_text()])
	if Story.finished:
		_bot_release()
		if not started:
			print("BOT DONE за %.1f c" % _bot_clock)
			get_tree().quit()
		return
	if _bot_clock > float(args.get("limit", "900")):
		print("BOT TIMEOUT на этапе ", tag)
		get_tree().quit()
		return
	_bot_t -= delta
	if UI.dialog.visible:
		_bot_release()
		if _bot_t <= 0.0:
			_bot_t = 0.12
			_bot_tap(KEY_1 if UI.choosing else KEY_SPACE)
		return
	if busy:
		_bot_release()
		return
	var it := Story.target_inter()
	if it.is_empty():
		return
	var ip := level.inter_pos(it)
	var to := Vector3(ip.x - player.global_position.x, 0, ip.z - player.global_position.z)
	if not _near.is_empty() and _near.id == it.id:
		_bot_release()
		if _bot_t <= 0.0:
			_bot_t = 0.3
			_bot_tap(KEY_E)
		return
	var dir := to.normalized()
	# застряли — обходим препятствие боком
	_bot_stuck_t += delta
	if _bot_stuck_t > 0.8:
		_bot_stuck_t = 0.0
		if player.global_position.distance_to(_bot_last) < 0.35:
			_bot_side_t = 1.1
			_bot_side = -_bot_side if randf() < 0.5 else _bot_side
		_bot_last = player.global_position
	if _bot_side_t > 0.0:
		_bot_side_t -= delta
		dir = Vector3(-dir.z, 0, dir.x) * _bot_side + dir * 0.15
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var f := dir.dot(fwd)
	var r := dir.dot(right)
	_bot_key(KEY_W, f > 0.3)
	_bot_key(KEY_S, f < -0.3)
	_bot_key(KEY_D, r > 0.3)
	_bot_key(KEY_A, r < -0.3)