extends Node
## Звук: музыка с плавной сменой, фоновые петли, эффекты, озвучка реплик.

const AMB := {
	"silence": {},
	"quiet": {"hum": 0.12},
	"restaurant": {"murmur": 0.55},
	"station": {"murmur": 0.28, "hum": 0.1},
	"office": {"hum": 0.22},
	"shop": {"press": 0.45},
	"mansion": {"fire": 0.5},
	"party": {"murmur": 0.5, "fire": 0.15},
	"pier": {"waves": 0.75},
}
## Выравнивание громкости: треки записаны с очень разным уровнем (дБ к общему знаменателю).
const MUSIC_GAIN := {"ch1": -8.4, "ch1_restaurant": -3.8, "ch2": 2.2, "ch3": 11.2, "ch4": -0.7, "ch5": 1.9,
	"ch5_party": -3.8, "credits": 19.0, "menu": 3.9}
const SFX_GAIN := {"paper": 6.0, "thunder": -5.0, "glass": -5.0, "keys": 3.0, "bolt": 3.0, "door": 2.0, "punch": 3.0}
const LOOP_KEYS := ["rain", "rain_heavy", "wind", "murmur", "hum", "press", "fire", "waves", "ring"]

var voice_on: bool = true
var vol_music: float = 0.45
var vol_sfx: float = 0.8
var vol_voice: float = 1.0

var _music: Array = []            # два плеера для кроссфейда
var _music_cur: int = 0
var _music_key: String = ""
var _music_gain: Array = [0.0, 0.0]
var _music_target: Array = [0.0, 0.0]
var _duck: float = 1.0
var _loops: Dictionary = {}
var _loop_target: Dictionary = {}
var _loop_gain: Dictionary = {}
var _voice: AudioStreamPlayer
var _pool: Array = []
var _pool_i: int = 0
var _variants: Dictionary = {}
var _rain_lp: AudioEffectLowPassFilter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus("Music", "Master")
	_bus("Sfx", "Master")
	_bus("Amb", "Sfx")
	var rain := _bus("Rain", "Amb")
	_rain_lp = AudioEffectLowPassFilter.new()
	_rain_lp.cutoff_hz = 1500.0
	AudioServer.add_bus_effect(rain, _rain_lp)
	_bus("Voice", "Master")
	var think := _bus("VoiceThink", "Voice")
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.55
	rv.damping = 0.6
	rv.wet = 0.16
	rv.dry = 0.95
	AudioServer.add_bus_effect(think, rv)
	var phone := _bus("VoicePhone", "Voice")
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 520.0
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 2600.0
	var ds := AudioEffectDistortion.new()
	ds.mode = AudioEffectDistortion.MODE_OVERDRIVE
	ds.drive = 0.32
	ds.post_gain = -3.0
	AudioServer.add_bus_effect(phone, hp)
	AudioServer.add_bus_effect(phone, lp)
	AudioServer.add_bus_effect(phone, ds)
	var door := _bus("VoiceDoor", "Voice")
	var lp2 := AudioEffectLowPassFilter.new()
	lp2.cutoff_hz = 900.0
	var rv2 := AudioEffectReverb.new()
	rv2.room_size = 0.8
	rv2.wet = 0.35
	rv2.dry = 0.7
	AudioServer.add_bus_effect(door, lp2)
	AudioServer.add_bus_effect(door, rv2)

	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_music.append(p)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	add_child(_voice)
	for i in 10:
		var sp := AudioStreamPlayer.new()
		sp.bus = "Sfx"
		add_child(sp)
		_pool.append(sp)
	for k in LOOP_KEYS:
		var st := _find("res://audio/sfx/" + k)
		if st == null:
			continue
		_make_loop(st)
		var lp_player := AudioStreamPlayer.new()
		lp_player.stream = st
		lp_player.bus = "Rain" if (k == "rain" or k == "rain_heavy" or k == "wind") else "Amb"
		lp_player.volume_db = -80.0
		add_child(lp_player)
		_loops[k] = lp_player
		_loop_target[k] = 0.0
		_loop_gain[k] = 0.0
	_apply_volumes()


func _bus(bus_name: String, send: String) -> int:
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, send)
	return i


func _find(base: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var p := "%s.%s" % [base, ext]
		if ResourceLoader.exists(p):
			return load(p) as AudioStream
	return null


func _make_loop(st: AudioStream) -> void:
	if st is AudioStreamWAV:
		var w := st as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * float(w.mix_rate))
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	elif st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(vol_music, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sfx"), linear_to_db(maxf(vol_sfx, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(maxf(vol_voice, 0.0001)))


func set_volume(kind: String, v: float) -> void:
	match kind:
		"music":
			vol_music = v
		"sfx":
			vol_sfx = v
		"voice":
			vol_voice = v
	_apply_volumes()
	Game.save_settings()


func _process(delta: float) -> void:
	# музыка приглушается, пока звучит голос
	var duck_t := 0.5 if _voice.playing else 1.0
	_duck = lerpf(_duck, duck_t, minf(1.0, delta * 3.0))
	for i in 2:
		_music_gain[i] = move_toward(_music_gain[i], _music_target[i], delta * 0.45 * maxf(1.0, maxf(_music_target[i], _music_gain[i])))
		var p: AudioStreamPlayer = _music[i]
		var g: float = _music_gain[i] * _duck
		p.volume_db = linear_to_db(maxf(g, 0.0001))
		if _music_gain[i] <= 0.0 and _music_target[i] <= 0.0 and p.playing:
			p.stop()
	for k in _loops:
		var lp: AudioStreamPlayer = _loops[k]
		_loop_gain[k] = move_toward(_loop_gain[k], _loop_target[k], delta * 0.8)
		var lg: float = _loop_gain[k]
		lp.volume_db = linear_to_db(maxf(lg, 0.0001))
		if lg > 0.0 and not lp.playing:
			lp.play()
		elif lg <= 0.0 and lp.playing:
			lp.stop()


## Сменить музыку (ключ = имя файла в audio/music без расширения). "" — тишина.
func music(key: String, gain: float = 1.0) -> void:
	if key == _music_key:
		_music_target[_music_cur] = gain * db_to_linear(float(MUSIC_GAIN.get(key, 0.0)))
		return
	_music_key = key
	_music_target[_music_cur] = 0.0
	if key == "":
		return
	var st := _find("res://audio/music/" + key)
	if st == null:
		return
	_make_loop(st)
	_music_cur = 1 - _music_cur
	var p: AudioStreamPlayer = _music[_music_cur]
	p.stream = st
	p.play()
	_music_gain[_music_cur] = 0.0
	_music_target[_music_cur] = gain * db_to_linear(float(MUSIC_GAIN.get(key, 0.0)))


func music_stop_now() -> void:
	_music_key = ""
	for i in 2:
		_music_target[i] = 0.0
		_music_gain[i] = 0.0
		(_music[i] as AudioStreamPlayer).stop()


## Фон сцены: набор петель + дождь.
func set_scene(amb: String, rain: float, indoor: bool, wind: float = 0.0) -> void:
	for k in _loop_target:
		if k != "ring":
			_loop_target[k] = 0.0
	var cfg: Dictionary = AMB.get(amb, {})
	for k in cfg:
		if _loop_target.has(k):
			_loop_target[k] = cfg[k]
	var mul := 0.55 if indoor else 1.0
	if rain > 0.02:
		if rain < 0.6:
			_set_loop("rain", (0.35 + rain * 0.6) * mul)
		else:
			_set_loop("rain", 0.3 * mul)
			_set_loop("rain_heavy", (0.35 + rain * 0.55) * mul)
	_set_loop("wind", wind * (0.5 if indoor else 0.9))
	_rain_lp.cutoff_hz = 1500.0 if indoor else 18000.0


func _set_loop(k: String, v: float) -> void:
	if _loop_target.has(k):
		_loop_target[k] = v


func silence_all(fade_fast: bool = false) -> void:
	for k in _loop_target:
		_loop_target[k] = 0.0
		if fade_fast:
			_loop_gain[k] = 0.0
	if fade_fast:
		music_stop_now()
	else:
		music("")


func ring(on: bool) -> void:
	_set_loop("ring", 0.8 if on else 0.0)
	if not on and _loop_gain.has("ring"):
		_loop_gain["ring"] = 0.0
	elif on and _loop_gain.has("ring"):
		_loop_gain["ring"] = 0.8


func sfx(sfx_name: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _variants.has(sfx_name):
		var list: Array = []
		var single := _find("res://audio/sfx/" + sfx_name)
		if single != null:
			list.append(single)
		for i in range(1, 7):
			var v := _find("res://audio/sfx/%s%d" % [sfx_name, i])
			if v != null:
				list.append(v)
		_variants[sfx_name] = list
	var arr: Array = _variants[sfx_name]
	if arr.is_empty():
		return
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = arr[randi() % arr.size()]
	p.volume_db = vol_db + float(SFX_GAIN.get(sfx_name, 0.0))
	p.pitch_scale = pitch
	p.play()


static func voice_id(spk: String, text: String) -> String:
	return (spk + "|" + text).md5_text().substr(0, 12)


## Проиграть озвучку реплики. Возвращает длительность в секундах (0 — файла нет).
func voice(spk: String, text: String) -> float:
	_voice.stop()
	if not voice_on or spk == "narr":
		return 0.0
	var st := _find("res://audio/voice/" + voice_id(spk, text))
	if st == null:
		return 0.0
	match spk:
		"think":
			_voice.bus = "VoiceThink"
		"phone":
			_voice.bus = "VoicePhone"
		"voices":
			_voice.bus = "VoiceDoor"
		_:
			_voice.bus = "Voice"
	_voice.stream = st
	_voice.play()
	return st.get_length()


func has_voice(spk: String, text: String) -> bool:
	return _find("res://audio/voice/" + voice_id(spk, text)) != null


func voice_stop() -> void:
	_voice.stop()
