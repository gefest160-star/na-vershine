extends CanvasLayer
## Весь интерфейс собирается кодом: HUD, диалоги, затемнения, титры, меню.

signal advanced
signal chosen(idx: int)

const GOLD := Color(0.91, 0.75, 0.44)
const SPEAKERS := {
	"me": {"name": "Я", "color": Color(0.62, 0.77, 1.0)},
	"think": {"name": "", "italic": true},
	"narr": {"name": "", "italic": true, "center": true},
	"patron": {"name": "Патрон", "color": Color(0.91, 0.75, 0.44)},
	"phone": {"name": "Патрон — по телефону", "color": Color(0.91, 0.75, 0.44)},
	"voices": {"name": "Голоса за дверью", "color": Color(0.91, 0.75, 0.44)},
	"waiter": {"name": "Официант", "color": Color(0.81, 0.85, 0.86)},
	"thug": {"name": "Громила", "color": Color(0.9, 0.45, 0.45)},
	"thug2": {"name": "Второй", "color": Color(0.9, 0.45, 0.45)},
	"clerk": {"name": "Кладовщик", "color": Color(0.77, 0.72, 0.6)},
	"traveler": {"name": "Пассажир", "color": Color(0.77, 0.72, 0.6)},
	"semyonov": {"name": "Семёнов", "color": Color(0.74, 0.67, 0.64)},
	"reiner": {"name": "Рейнер", "color": Color(0.65, 0.84, 0.65)},
	"marc": {"name": "Марк", "color": Color(0.69, 0.75, 0.77)},
	"lady": {"name": "Дама", "color": Color(0.9, 0.7, 0.75)},
	"guest_m": {"name": "Гость в маске", "color": Color(0.82, 0.77, 0.91)},
	"guest_f": {"name": "Гостья в маске", "color": Color(0.82, 0.77, 0.91)},
}

var serif: SystemFont
var serif_i: SystemFont
var sans: SystemFont
var hud: Control
var obj_panel: PanelContainer
var obj_label: Label
var chapter_tag: Label
var prompt: PanelContainer
var prompt_label: Label
var loc_label: Label
var keys_hint: Label
var bar_t: ColorRect
var bar_b: ColorRect
var dialog: PanelContainer
var d_name: Label
var d_text: Label
var d_choices: VBoxContainer
var d_hint: Label
var fade_rect: ColorRect
var card_box: VBoxContainer
var card_t: Label
var card_s: Label
var flash_rect: ColorRect
var menu: Control
var btn_continue: Button
var btn_new: Button
var btn_resume: Button
var btn_voice: Button
var menu_sub: Label
var menu_bg: ColorRect

var typing: bool = false
var choosing: bool = false
var _cps: float = 45.0
var _vis: float = 0.0
var _bar: float = 0.0
var _bar_target: float = 0.0
var _loc_t: float = 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "DejaVu Serif", "serif"])
	serif_i = SystemFont.new()
	serif_i.font_names = serif.font_names
	serif_i.font_italic = true
	sans = SystemFont.new()
	sans.font_names = PackedStringArray(["Segoe UI", "Arial", "DejaVu Sans", "sans-serif"])
	_build()


func _lbl(text: String, size: int, col: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font != null else sans)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel_style(bg: Color, border: Color, top: int = 0, left: int = 0, all: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_top = maxi(top, all)
	sb.border_width_left = maxi(left, all)
	sb.border_width_right = all
	sb.border_width_bottom = all
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	return sb


func _full(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build() -> void:
	# виньетка и зерно
	var vg := ColorRect.new()
	_full(vg)
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.62;
uniform float grain = 0.05;
void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.32, 0.86, length(uv * vec2(1.0, 0.92)));
	float n = fract(sin(dot(UV * 917.0 + vec2(TIME * 13.0, TIME * 7.0), vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(0.0, 0.0, 0.0, clamp(v * strength + (n - 0.5) * grain, 0.0, 1.0));
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vg.material = sm
	add_child(vg)

	flash_rect = ColorRect.new()
	_full(flash_rect)
	flash_rect.color = Color(0.87, 0.91, 1.0, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

	bar_t = ColorRect.new()
	bar_t.color = Color.BLACK
	bar_t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_t.anchor_right = 1.0
	add_child(bar_t)
	bar_b = ColorRect.new()
	bar_b.color = Color.BLACK
	bar_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_b.anchor_right = 1.0
	bar_b.anchor_top = 1.0
	bar_b.anchor_bottom = 1.0
	add_child(bar_b)

	# HUD
	hud = Control.new()
	_full(hud)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	obj_panel = PanelContainer.new()
	obj_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.04, 0.055, 0.6), GOLD, 0, 3))
	obj_panel.position = Vector2(26, 22)
	obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(obj_panel)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 0)
	obj_panel.add_child(ov)
	ov.add_child(_lbl("Ц Е Л Ь", 11, GOLD))
	obj_label = _lbl("", 18, Color(0.93, 0.91, 0.86))
	obj_label.custom_minimum_size = Vector2(220, 0)
	ov.add_child(obj_label)

	chapter_tag = _lbl("", 14, Color(0.81, 0.78, 0.7, 0.75))
	chapter_tag.anchor_left = 1.0
	chapter_tag.anchor_right = 1.0
	chapter_tag.offset_left = -520
	chapter_tag.offset_right = -26
	chapter_tag.offset_top = 22
	chapter_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(chapter_tag)

	loc_label = _lbl("", 30, Color(0.93, 0.91, 0.86), serif_i)
	loc_label.anchor_right = 1.0
	loc_label.offset_top = 96
	loc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loc_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	loc_label.add_theme_constant_override("shadow_offset_y", 2)
	loc_label.modulate.a = 0.0
	hud.add_child(loc_label)

	prompt = PanelContainer.new()
	prompt.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.04, 0.055, 0.78), Color(GOLD, 0.6), 0, 0, 1))
	prompt.anchor_left = 0.5
	prompt.anchor_right = 0.5
	prompt.anchor_top = 1.0
	prompt.anchor_bottom = 1.0
	prompt.offset_top = -190
	prompt.offset_bottom = -150
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.visible = false
	hud.add_child(prompt)
	prompt_label = _lbl("", 19, Color(0.95, 0.93, 0.88))
	prompt.add_child(prompt_label)

	keys_hint = _lbl("WASD — ходить   ·   Shift — бежать   ·   мышь / ← → — камера   ·   E — действие   ·   Esc — меню", 13, Color(0.6, 0.58, 0.52, 0.8))
	keys_hint.anchor_right = 1.0
	keys_hint.anchor_top = 1.0
	keys_hint.anchor_bottom = 1.0
	keys_hint.offset_top = -30
	keys_hint.offset_bottom = -8
	keys_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(keys_hint)

	# диалог
	dialog = PanelContainer.new()
	var ds := _panel_style(Color(0.035, 0.035, 0.05, 0.92), GOLD, 2)
	ds.border_width_left = 0
	ds.content_margin_left = 30
	ds.content_margin_right = 30
	ds.content_margin_top = 16
	ds.content_margin_bottom = 20
	dialog.add_theme_stylebox_override("panel", ds)
	dialog.anchor_left = 0.5
	dialog.anchor_right = 0.5
	dialog.anchor_top = 1.0
	dialog.anchor_bottom = 1.0
	dialog.offset_left = -500
	dialog.offset_right = 500
	dialog.offset_top = -250
	dialog.offset_bottom = -92
	dialog.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dialog.visible = false
	add_child(dialog)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	dialog.add_child(dv)
	d_name = _lbl("", 15, GOLD)
	dv.add_child(d_name)
	d_text = _lbl("", 25, Color(0.93, 0.91, 0.86), serif)
	d_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_text.custom_minimum_size = Vector2(940, 78)
	d_text.add_theme_constant_override("line_spacing", 5)
	dv.add_child(d_text)
	d_choices = VBoxContainer.new()
	d_choices.add_theme_constant_override("separation", 7)
	dv.add_child(d_choices)
	d_hint = _lbl("Пробел / клик — дальше", 12, Color(0.55, 0.53, 0.47))
	d_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dv.add_child(d_hint)

	# затемнение и титры
	fade_rect = ColorRect.new()
	_full(fade_rect)
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	card_box = VBoxContainer.new()
	_full(card_box)
	card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	card_box.add_theme_constant_override("separation", 18)
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_box.modulate.a = 0.0
	add_child(card_box)
	card_t = _lbl("", 62, Color(0.93, 0.91, 0.86), serif)
	card_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_box.add_child(card_t)
	card_s = _lbl("", 28, Color(0.66, 0.63, 0.57), serif_i)
	card_s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_box.add_child(card_s)

	# реплики должны читаться и поверх чёрного экрана
	move_child(dialog, get_child_count() - 1)
	_build_menu()


func _menu_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 52)
	b.add_theme_font_override("font", serif)
	b.add_theme_font_size_override("font_size", 23)
	b.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86))
	b.add_theme_color_override("font_hover_color", GOLD)
	var n := _panel_style(Color(0, 0, 0, 0.25), Color(GOLD, 0.5), 0, 0, 1)
	var hv := _panel_style(Color(GOLD, 0.14), GOLD, 0, 0, 1)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	return b


func _slider_row(parent: Control, title: String, value: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var l := _lbl(title, 17, Color(0.72, 0.7, 0.64))
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(190, 24)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(cb)
	row.add_child(s)
	parent.add_child(row)


func _build_menu() -> void:
	menu = Control.new()
	_full(menu)
	add_child(menu)
	menu_bg = ColorRect.new()
	_full(menu_bg)
	menu_bg.color = Color(0.02, 0.025, 0.04, 0.9)
	menu.add_child(menu_bg)
	var vb := VBoxContainer.new()
	_full(vb)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 11)
	menu.add_child(vb)
	var title := _lbl("Н А   В Е Р Ш И Н Е", 78, Color(0.93, 0.91, 0.86), serif)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	menu_sub = _lbl("История человека, который хотел подняться наверх.", 22, Color(0.6, 0.58, 0.52), serif_i)
	menu_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(menu_sub)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 26)
	vb.add_child(sp)
	btn_resume = _menu_button("Вернуться в игру")
	btn_continue = _menu_button("Продолжить")
	btn_new = _menu_button("Новая игра")
	var btn_quit := _menu_button("Выход")
	for b in [btn_resume, btn_continue, btn_new, btn_quit]:
		var c := CenterContainer.new()
		c.add_child(b)
		vb.add_child(c)
	btn_resume.pressed.connect(func(): Game.resume())
	btn_continue.pressed.connect(func(): Game.continue_game())
	btn_new.pressed.connect(func(): Game.new_game())
	btn_quit.pressed.connect(func(): get_tree().quit())
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 16)
	vb.add_child(sp2)
	var vrow := HBoxContainer.new()
	vrow.alignment = BoxContainer.ALIGNMENT_CENTER
	vrow.add_theme_constant_override("separation", 16)
	var vl := _lbl("Озвучка реплик", 17, Color(0.72, 0.7, 0.64))
	vl.custom_minimum_size = Vector2(150, 0)
	vrow.add_child(vl)
	btn_voice = _menu_button("включена")
	btn_voice.custom_minimum_size = Vector2(190, 34)
	btn_voice.add_theme_font_size_override("font_size", 17)
	btn_voice.pressed.connect(func():
		Au.voice_on = not Au.voice_on
		btn_voice.text = "включена" if Au.voice_on else "выключена"
		Game.save_settings())
	vrow.add_child(btn_voice)
	vb.add_child(vrow)
	_slider_row(vb, "Голоса", Au.vol_voice, func(v): Au.set_volume("voice", v))
	_slider_row(vb, "Музыка", Au.vol_music, func(v): Au.set_volume("music", v))
	_slider_row(vb, "Звуки", Au.vol_sfx, func(v): Au.set_volume("sfx", v))
	var sp3 := Control.new()
	sp3.custom_minimum_size = Vector2(0, 14)
	vb.add_child(sp3)
	var help := _lbl("WASD — ходить   ·   Shift — бежать   ·   мышь (зажать и тянуть) или ← → — камера   ·   колёсико — приближение\nE — действовать и говорить   ·   Пробел — следующая реплика   ·   1–3 — выбор ответа   ·   F11 — полный экран", 15, Color(0.55, 0.53, 0.47))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(help)


func show_menu(mode: String, has_save: bool = false, save_label: String = "") -> void:
	menu.visible = true
	menu_bg.color.a = 0.62 if mode == "start" else 0.86
	btn_resume.get_parent().visible = mode == "pause"
	btn_continue.get_parent().visible = mode == "start" and has_save
	btn_continue.text = "Продолжить" if save_label == "" else "Продолжить — " + save_label
	btn_new.text = "Новая игра" if mode == "start" else "Начать заново"
	btn_voice.text = "включена" if Au.voice_on else "выключена"


func hide_menu() -> void:
	menu.visible = false


func _process(delta: float) -> void:
	if typing:
		_vis += _cps * delta
		d_text.visible_characters = int(_vis)
		if int(_vis) >= d_text.text.length():
			d_text.visible_characters = -1
			typing = false
	_bar = lerpf(_bar, _bar_target, minf(1.0, delta * 6.0))
	var vh := get_viewport().get_visible_rect().size.y
	bar_t.offset_bottom = _bar * vh * 0.075
	bar_b.offset_top = -_bar * vh * 0.075
	var show_hud := 1.0 - _bar_target
	obj_panel.modulate.a = lerpf(obj_panel.modulate.a, show_hud if obj_label.text != "" else 0.0, minf(1.0, delta * 6.0))
	keys_hint.modulate.a = obj_panel.modulate.a
	if _loc_t > 0.0:
		_loc_t -= delta
		loc_label.modulate.a = clampf(minf(_loc_t, 4.0 - _loc_t) * 1.2, 0.0, 1.0)
	else:
		loc_label.modulate.a = 0.0


func _input(event: InputEvent) -> void:
	if menu.visible or not dialog.visible:
		return
	if choosing:
		if event is InputEventKey and event.pressed and not event.echo:
			var k: int = (event as InputEventKey).physical_keycode
			var idx := -1
			if k >= KEY_1 and k <= KEY_9:
				idx = k - KEY_1
			elif k >= KEY_KP_1 and k <= KEY_KP_9:
				idx = k - KEY_KP_1
			if idx >= 0 and idx < d_choices.get_child_count():
				get_viewport().set_input_as_handled()
				_pick(idx)
		return
	var go := false
	if event is InputEventKey and event.pressed and not event.echo:
		var k2: int = (event as InputEventKey).physical_keycode
		go = k2 == KEY_SPACE or k2 == KEY_ENTER or k2 == KEY_KP_ENTER or k2 == KEY_E
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		go = true
	if go:
		get_viewport().set_input_as_handled()
		if typing:
			typing = false
			d_text.visible_characters = -1
		else:
			advanced.emit()


## Показать реплику и дождаться нажатия.
func say(spk: String, text: String) -> void:
	var s: Dictionary = SPEAKERS.get(spk, {"name": spk})
	if Game.autoplay:
		Game.log_line("    [%s] %s" % [spk, text])
		if spk != "narr" and not Au.has_voice(spk, text):
			Game.log_line("    !!! НЕТ ОЗВУЧКИ: [%s] %s" % [spk, text])
		await get_tree().process_frame
		return
	dialog.visible = true
	choosing = false
	_clear_choices()
	d_hint.visible = true
	d_name.text = s.get("name", "")
	d_name.visible = d_name.text != ""
	d_name.add_theme_color_override("font_color", s.get("color", GOLD))
	var italic: bool = s.get("italic", false)
	d_text.add_theme_font_override("font", serif_i if italic else serif)
	d_text.add_theme_color_override("font_color", Color(0.77, 0.8, 0.85) if italic else Color(0.93, 0.91, 0.86))
	d_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if s.get("center", false) else HORIZONTAL_ALIGNMENT_LEFT
	d_text.text = text
	d_text.visible_characters = 0
	_vis = 0.0
	var dur: float = Au.voice(spk, text)
	_cps = clampf(float(text.length()) / dur * 1.25, 28.0, 80.0) if dur > 0.2 else 46.0
	typing = true
	if Game.demo:
		await get_tree().create_timer(clampf(float(text.length()) * 0.016, 0.7, 1.5)).timeout
		return
	await advanced
	Au.voice_stop()


## Показать варианты, вернуть индекс выбранного.
func choose(opts: Array) -> int:
	if Game.autoplay:
		var pick: int = clampi(Game.auto_choice, 0, opts.size() - 1)
		Game.log_line("    <выбор> %s" % str(opts[pick]))
		await get_tree().process_frame
		return pick
	dialog.visible = true
	_clear_choices()
	choosing = true
	typing = false
	d_text.visible_characters = -1
	d_hint.visible = false
	for i in opts.size():
		var b := Button.new()
		b.text = "%d.   %s" % [i + 1, str(opts[i])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", serif)
		b.add_theme_font_size_override("font_size", 21)
		b.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86))
		b.add_theme_color_override("font_hover_color", GOLD)
		b.add_theme_stylebox_override("normal", _panel_style(Color(1, 1, 1, 0.045), Color(GOLD, 0.4), 0, 0, 1))
		b.add_theme_stylebox_override("hover", _panel_style(Color(GOLD, 0.16), GOLD, 0, 0, 1))
		b.add_theme_stylebox_override("pressed", _panel_style(Color(GOLD, 0.16), GOLD, 0, 0, 1))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pick.bind(i))
		d_choices.add_child(b)
	if Game.demo:
		await get_tree().create_timer(0.9).timeout
		choosing = false
		_clear_choices()
		return clampi(Game.auto_choice, 0, opts.size() - 1)
	var res: int = await chosen
	choosing = false
	_clear_choices()
	return res


func _pick(i: int) -> void:
	if not choosing:
		return
	Au.sfx("blip")
	chosen.emit(i)


func _clear_choices() -> void:
	for c in d_choices.get_children():
		d_choices.remove_child(c)
		c.queue_free()


func hide_dialog() -> void:
	dialog.visible = false
	typing = false
	choosing = false
	_clear_choices()


func cine(on: bool) -> void:
	_bar_target = 1.0 if on else 0.0


func set_objective(text: String) -> void:
	obj_label.text = text
	obj_panel.reset_size()


func set_chapter(text: String) -> void:
	chapter_tag.text = text


func set_prompt(text: String) -> void:
	if text == "":
		prompt.visible = false
		return
	prompt_label.text = "[ E ]   " + text
	prompt.visible = true
	prompt.reset_size()


func location(title: String) -> void:
	loc_label.text = title
	_loc_t = 4.0 if title != "" else 0.0


func fade(to_black: bool, dur: float = 0.8) -> void:
	if Game.autoplay:
		fade_rect.color.a = 1.0 if to_black else 0.0
		return
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0 if to_black else 0.0, dur)
	await tw.finished


## Титульная карточка на чёрном фоне.
func card(title: String, sub: String, hold: float = 3.0) -> void:
	if Game.autoplay:
		Game.log_line("=== %s — %s" % [title, sub])
		return
	card_t.text = title
	card_s.text = sub
	card_s.visible = sub != ""
	var tw := create_tween()
	tw.tween_property(card_box, "modulate:a", 1.0, 1.2)
	tw.tween_interval(hold)
	tw.tween_property(card_box, "modulate:a", 0.0, 1.2)
	await tw.finished


func flash(amount: float = 0.5, dur: float = 0.35) -> void:
	flash_rect.color.a = amount
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, dur)
