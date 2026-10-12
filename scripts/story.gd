extends Node
## Сюжет: главы, этапы, реплики и постановочные сцены.
## ВАЖНО: реплики в say/think/me пишутся одной строкой-литералом — по ним tools/gen_voice.py строит озвучку.

const TITLES := {
	"apartment": "Моя квартира",
	"restaurant": "Ресторан «Золотой фазан»",
	"station": "Северный вокзал",
	"penthouse": "Квартира Патрона",
	"gromov": "Контора Громова",
	"shop": "Типография Семёнова",
	"tower": "Офис Патрона. Сорок второй этаж",
	"reiner": "Фонд Рейнера",
	"mansion": "Особняк Патрона",
	"pier": "Старая пристань",
	"cabinet": "Кабинет",
}

var chapters: Dictionary = {}
var finished: bool = false
var guilt: int = 0


func _ready() -> void:
	chapters = {
		1: {"name": "Шанс", "stages": [
			{"scene": "restaurant", "target": "waiter", "obj": "Подозвать официанта", "enter": _c1_intro, "act": _c1_waiter, "noexit": true},
			{"scene": "restaurant", "target": "thug1", "obj": "Вмешаться", "act": _c1_fight, "noexit": true},
			{"scene": "apartment", "target": "bed", "obj": "Вернуться домой и дождаться утра", "act": _c1_sleep},
			{"scene": "station", "target": "locker13", "obj": "Северный вокзал: забрать конверт из ячейки № 13", "enter": _c1_station, "act": _c1_locker},
			{"scene": "restaurant", "target": "patron", "obj": "Отнести конверт Патрону в ресторан", "act": _c1_deliver},
			{"scene": "apartment", "target": "bed", "obj": "Вернуться домой", "act": _c1_end},
		]},
		2: {"name": "Грязная работа", "stages": [
			{"scene": "apartment", "target": "phone", "obj": "Ответить на звонок", "enter": _c2_intro, "act": _c2_phone},
			{"scene": "penthouse", "target": "patron", "obj": "Приехать к Патрону", "enter": _c2_penthouse, "act": _c2_brief},
			{"scene": "gromov", "target": "drawer", "obj": "Контора Громова: подбросить папку в стол", "enter": _c2_gromov, "act": _c2_drawer},
			{"scene": "shop", "target": "semyonov", "obj": "Типография: получить подпись Семёнова", "enter": _c2_shop, "act": _c2_semyonov},
			{"scene": "penthouse", "target": "patron", "obj": "Вернуться к Патрону", "act": _c2_report},
			{"scene": "apartment", "target": "bed", "obj": "Вернуться домой", "act": _c2_end},
		]},
		3: {"name": "У всего есть цена", "stages": [
			{"scene": "apartment", "target": "table", "obj": "Прочесть записку", "enter": _c3_intro, "act": _c3_note},
			{"scene": "tower", "target": "patron", "obj": "Явиться в офис Патрона", "enter": _c3_tower, "act": _c3_brief},
			{"scene": "reiner", "target": "reiner", "obj": "Фонд Рейнера: попасть в кабинет", "enter": _c3_reiner, "act": _c3_talk},
			{"scene": "reiner", "target": "safe", "obj": "Подложить бумаги в сейф", "act": _c3_safe, "noexit": true},
			{"scene": "tower", "target": "patron", "obj": "Доложить Патрону", "act": _c3_report},
			{"scene": "apartment", "target": "bed", "obj": "Вернуться домой", "act": _c3_end},
		]},
		4: {"name": "Пустой трон", "stages": [
			{"scene": "apartment", "target": "table", "obj": "Прочесть записку", "enter": _c4_intro, "act": _c4_note},
			{"scene": "mansion", "target": "patron", "obj": "Приехать в особняк", "enter": _c4_mansion, "act": _c4_brief},
			{"scene": "pier", "target": "marc", "obj": "Старая пристань: найти Марка", "enter": _c4_pier, "act": _c4_marc},
			{"scene": "mansion", "target": "patron", "obj": "Вернуться в особняк", "act": _c4_report},
			{"scene": "apartment", "target": "bed", "obj": "Вернуться домой", "act": _c4_end},
		]},
		5: {"name": "На вершине", "stages": [
			{"scene": "apartment", "target": "table", "obj": "Прочесть приглашение", "enter": _c5_intro, "act": _c5_invite},
			{"scene": "mansion", "target": "patron", "obj": "Приехать на приём", "enter": _c5_mansion, "act": _c5_patron},
			{"scene": "mansion", "target": "cabinet_door", "obj": "Войти в кабинет", "act": _c5_door},
			{"scene": "cabinet", "target": "table", "obj": "Подойти к столу", "enter": _c5_cabinet, "act": _c5_final, "noexit": true},
		]},
	}


# ---------- Служебное ----------

func say(spk: String, text: String) -> void:
	await UI.say(spk, text)


func think(text: String) -> void:
	await UI.say("think", text)


func me(text: String) -> void:
	await UI.say("me", text)


func choose(opts: Array) -> int:
	return await UI.choose(opts)


func stage_def() -> Dictionary:
	var st: Array = chapters[Game.chapter].stages
	return st[clampi(Game.stage, 0, st.size() - 1)]


func npc(id: String) -> Human:
	return Game.level.npcs.get(id) as Human


func title(scene: String) -> String:
	if scene == "apartment" and Game.chapter == 5:
		return "Новая квартира"
	return TITLES.get(scene, scene)


func music_for(scene: String) -> String:
	match Game.chapter:
		1:
			return "ch1_restaurant" if scene == "restaurant" else "ch1"
		2:
			return "ch2"
		3:
			return "ch3"
		4:
			return "ch4"
		_:
			if scene == "mansion":
				return "ch5_party"
			if scene == "cabinet":
				return ""
			return "ch5"


func objective_text() -> String:
	if finished:
		return ""
	return stage_def().obj


func target_inter() -> Dictionary:
	if Game.level == null or finished:
		return {}
	var st := stage_def()
	if st.scene == Game.level.id:
		return Game.level.find_inter(st.target)
	return Game.level.find_inter("exit")


func _exit_dest() -> String:
	var st := stage_def()
	var here: String = Game.level.id
	if st.scene != here:
		return st.scene
	if here == "apartment" or st.get("noexit", false):
		return ""
	return "apartment"


func exit_label() -> String:
	var d := _exit_dest()
	if d == "":
		return "Дверь"
	if d == "apartment":
		return "Уйти домой"
	return "Выйти  →  " + title(d)


func table_label() -> String:
	match Game.chapter:
		3, 4:
			return "Записка на столе"
		5:
			return "Приглашение"
	return "Стол"


func advance() -> void:
	Game.stage += 1
	Game.refresh_objective()


func end_chapter() -> void:
	await Game.start_chapter(Game.chapter + 1)


func on_enter() -> void:
	var st := stage_def()
	if st.scene != Game.level.id or not st.has("enter"):
		return
	var key := "%d:%d" % [Game.chapter, Game.stage]
	if Game.entered.has(key):
		return
	Game.entered[key] = true
	UI.cine(true)
	await (st.enter as Callable).call()
	UI.hide_dialog()
	UI.cine(false)
	Game.focus_clear()


func interact(scene: String, iid: String) -> void:
	var st := stage_def()
	if iid == "exit":
		await _use_exit()
		return
	if st.scene == scene and st.target == iid:
		await (st.act as Callable).call()
		return
	await _flavor(scene, iid)


func _use_exit() -> void:
	var d := _exit_dest()
	if d == "":
		var st := stage_def()
		if Game.level.id == "apartment":
			await think("Рано. Сначала нужно закончить здесь.")
		elif Game.chapter == 1:
			await think("Уйти сейчас? Нет. Не сейчас.")
		else:
			await think("Я не могу уйти. Не сейчас.")
		return
	await Game.travel(d)


## Расстановка в локации в зависимости от этапа.
func setup_level(lv: Level) -> void:
	var ch: int = Game.chapter
	var sg: int = Game.stage
	Game.player.human.show_gun(false)
	Game.player.human.pose = "stand"
	match lv.id:
		"restaurant":
			if sg == 0:
				Game.player.teleport(Vector3(-2.4, 0, 3.3), -2.2)
			elif sg == 1:
				_spawn_thugs(lv, true)
				var p := lv.npcs["patron"] as Human
				p.pose = "stand"
				p.position = Vector3(5.3, 0, -0.5)
				p.lean_extra = 0.3
				Game.player.teleport(Vector3(-2.4, 0, 3.3), -2.2)
			else:
				var p2 := lv.npcs["patron"] as Human
				p2.position = Vector3(5.3, 0, -4.1)
				p2.rotation.y = 0.0
				p2.home_rot = 0.0
				lv.find_inter("patron")["label"] = "Патрон"
		"apartment":
			if ch == 2 and sg == 0:
				Au.ring(true)
		"reiner":
			if sg >= 3:
				lv.remove_npc("reiner")
		"mansion":
			if ch == 4 and sg >= 3 and lv.has_meta("gun_prop"):
				(lv.get_meta("gun_prop") as Node3D).visible = false
		"pier":
			if sg >= 3:
				lv.remove_npc("marc")


func _spawn_thugs(lv: Level, in_place: bool) -> void:
	var t1 := Human.new(Levels.thug_style(1))
	var t2 := Human.new(Levels.thug_style(2))
	lv.add_npc("thug1", t1, Vector3(4.2, 0, -0.4) if in_place else Vector3(8.2, 0, 4.4), PI / 2.0 if in_place else -PI / 2.0, "Громила", 2.3)
	lv.add_npc("thug2", t2, Vector3(6.5, 0, -0.4) if in_place else Vector3(8.2, 0, 3.4), -PI / 2.0, "", 2.0)
	if in_place:
		t1.pose = "fight"
		t2.pose = "fight"


# =====================================================================
# ГЛАВА 1 — ШАНС
# =====================================================================

func _c1_intro() -> void:
	Game.focus_on(Vector3(-3.0, 1.2, 2.9), 6.5, 0.3)
	await think("Ресторан «Золотой фазан». Три года без выходных — и вот я впервые трачу на обед недельную получку.")
	await think("Здесь всё сияет. Хрусталь, скатерти, улыбки. На меня никто не смотрит. Я здесь — что-то вроде мебели.")
	await think("Говорят, тут обедают люди, которые решают чужие судьбы. Может быть, сегодня что-то изменится.")


func _c1_waiter() -> void:
	await say("waiter", "Добрый день. Вы уже выбрали?")
	var c: int = await choose(["Что-нибудь попроще.", "То же, что подают господину у окна."])
	if c == 0:
		await me("Что-нибудь... попроще.")
		await say("waiter", "Разумеется. У нас всё просто. Для тех, кто привык.")
		await think("Он сказал это без злобы. Это хуже всего.")
	else:
		await me("То же, что подают тому господину у окна.")
		await say("waiter", "Это блюдо, сэр, обычно не заказывают. Его приносят.")
		await think("Я всё равно киваю. Хотя бы раз в жизни.")
	UI.hide_dialog()
	await Game.wait(0.6)
	# --- скандал ---
	var lv := Game.level
	Au.music("")
	Au.sfx("glass")
	Game.shake(0.5)
	await think("Грохот. Звон стекла. Рояль обрывается на полуноте.")
	_spawn_thugs(lv, false)
	var t1 := npc("thug1")
	var t2 := npc("thug2")
	var patron := npc("patron")
	Game.focus_on(Vector3(5.6, 1.2, 0.2), 10.5, 0.44, 0.15)
	_walk_chain(t2, [Vector3(7.5, 0, 0.6), Vector3(6.5, 0, -0.4)], 3.9)
	await _walk_chain(t1, [Vector3(6.9, 0, 0.9), Vector3(4.2, 0, -0.4)], 3.9)
	t1.face_pos(Vector3(5.3, 0, -0.5))
	t2.face_pos(Vector3(5.3, 0, -0.5))
	await say("thug", "Вот ты где, старик. Думал, мы забудем?")
	patron.pose = "stand"
	await patron.walk_to(Vector3(5.3, 0, -0.5), 1.5)
	patron.face_pos(t1.position)
	await say("patron", "Господа. Здесь люди обедают. Давайте не будем портить им аппетит.")
	t1.pose = "fight"
	t2.pose = "fight"
	await say("thug2", "Аппетит мы тебе сейчас сами испортим.")
	Au.sfx("punch")
	Game.shake(0.35)
	patron.lean_extra = 0.3
	await think("Весь зал смотрит в тарелки. Официант исчез. Никто не встаёт.")
	await think("Я тоже мог бы смотреть в тарелку. Это ведь проще всего.")
	advance()


func _walk_chain(hm: Human, pts: Array, spd: float) -> void:
	for p in pts:
		if not is_instance_valid(hm):
			return
		await hm.walk_to(p, spd)


func _c1_fight() -> void:
	var lv := Game.level
	var t1 := npc("thug1")
	var t2 := npc("thug2")
	var patron := npc("patron")
	var c: int = await choose(["Встать между ними.", "Отвернуться. Это не моё дело."])
	if c == 1:
		await think("Я отворачиваюсь. Смотрю в окно. Считаю до трёх.")
		await think("Нет. Не в этот раз.")
	await me("Эй. Отпустите его.")
	await say("thug", "А ты ещё кто такой? Сядь, пока цел.")
	await me("Он вдвое старше вас. Отпустите.")
	await say("thug", "Ну, сам напросился.")
	UI.hide_dialog()
	Game.player.human.pose = "fight"
	for i in 3:
		Au.sfx("punch")
		Game.shake(0.6)
		UI.flash(0.3, 0.2)
		await Game.wait(0.36)
	await UI.fade(true, 0.2)
	Au.sfx("punch")
	await Game.wait(0.45)
	Au.sfx("glass")
	await Game.wait(0.7)
	t1.pose = "slump"
	t1.lean_extra = 0.35
	t2.pose = "stand"
	patron.lean_extra = 0.0
	Game.player.human.pose = "stand"
	await UI.fade(false, 0.5)
	await say("thug2", "Уходим! Он бешеный!")
	UI.hide_dialog()
	_walk_chain(t2, [Vector3(7.5, 0, 0.8), Vector3(8.4, 0, 4.4)], 5.2)
	await _walk_chain(t1, [Vector3(6.9, 0, 0.9), Vector3(8.4, 0, 4.2)], 4.6)
	lv.remove_npc("thug1")
	lv.remove_npc("thug2")
	Au.sfx("door")
	await think("Костяшки саднят. Я не помню, как это случилось. Помню только, что встал.")
	patron.face_pos(Game.player.global_position)
	Game.focus_two(Game.player.global_position, patron.global_position)
	await say("patron", "Браво. Я давно не видел, чтобы кто-то встал, когда весь зал сидит.")
	await me("Я просто не мог на это смотреть.")
	await say("patron", "Могли. Все могут. Вон их сколько — и все прекрасно смогли.")
	await say("patron", "Как вас зовут?")
	await me("Это неважно. Я никто.")
	await say("patron", "С этого начинают все, кто чего-то стоит. Меня называют Патроном.")
	await say("patron", "Я не люблю оставаться в долгу. А наверху — там, куда вы смотрите снизу вверх, — всегда нужны люди, которым можно доверять.")
	c = await choose(["Мне ничего не нужно.", "Что от меня потребуется?"])
	if c == 0:
		await me("Мне ничего не нужно.")
		await say("patron", "Так говорят те, кому нужно больше всех.")
		await think("Он прав. Мне нужно. Ещё как нужно.")
	else:
		await me("Что от меня потребуется?")
		await say("patron", "Вот это честный вопрос. Мне нравятся честные вопросы.")
	await say("patron", "Пустяк. Северный вокзал, камера хранения, ячейка тринадцать. Там лежит конверт. Принесите его мне сюда. И не вскрывайте.")
	Au.sfx("keys")
	await say("patron", "Вот ключ. Завтра, к полудню. Справитесь — поговорим о том, как вам подняться.")
	await think("Он говорит «подняться» так, будто наверх ведёт обычная лестница.")
	await think("Ключ тёплый. В груди тоже тепло. Кажется, это называется надеждой.")
	Au.music(music_for("restaurant"))
	lv.find_inter("patron")["label"] = "Патрон"
	advance()


func _c1_sleep() -> void:
	await think("Потолок в жёлтых разводах. Сегодня он почти красивый.")
	await think("Завтра всё изменится. Я повторяю это, пока не засыпаю.")
	UI.hide_dialog()
	await UI.fade(true, 1.2)
	await UI.card("", "Утро", 1.0)
	advance()
	await UI.fade(false, 1.2)


func _c1_station() -> void:
	await think("Северный вокзал. Гулкий зал, запах угля и чужих дорог.")
	await think("Солнце режет пыль на ровные полосы. Хороший день, чтобы начать новую жизнь.")


func _c1_locker() -> void:
	var lv := Game.level
	await think("Ключ входит легко. Слишком легко — будто замок смазывали вчера.")
	Au.sfx("locker")
	var hinge := lv.get_meta("locker13") as Node3D
	(lv.get_meta("envelope") as Node3D).visible = true
	var tw := create_tween()
	tw.tween_property(hinge, "rotation:y", 1.7, 0.7).set_trans(Tween.TRANS_SINE)
	await Game.wait(0.8)
	await think("Плотный конверт, запечатанный красным сургучом. Ни имени, ни адреса.")
	var c: int = await choose(["Убрать в карман, не разглядывая.", "Посмотреть на просвет."])
	if c == 1:
		await think("Ничего не видно. Только тяжесть — как у чужого секрета.")
		await think("Сургуч цел. Хорошо. Пусть так и останется.")
	else:
		await think("Чужие дела — чужие. Моё дело — донести.")
	Au.sfx("paper")
	(lv.get_meta("envelope") as Node3D).visible = false
	await think("Я прячу конверт под куртку. Сердце стучит так, будто я его украл.")
	advance()


func _c1_deliver() -> void:
	await say("patron", "Вы пунктуальны. Это редкое качество — и недешёвое.")
	await me("Вот. Я не вскрывал.")
	Au.sfx("paper")
	await say("patron", "Я знаю. Иначе мы бы с вами сейчас не разговаривали.")
	await think("Он убирает конверт во внутренний карман, не взглянув. Как убирают носовой платок.")
	await me("Вы говорили — мы обсудим, как мне...")
	await say("patron", "Подняться. Я помню. Но по ступеням не прыгают — по ним идут. Я позвоню.")
	await think("Ни спасибо, ни рукопожатия. И всё же я выхожу отсюда другим человеком.")
	advance()


func _c1_end() -> void:
	await think("Первый день новой жизни. Я лежу и улыбаюсь в темноту, как мальчишка.")
	await think("Телефон молчит. Но он зазвонит. Теперь — зазвонит.")
	await end_chapter()


# =====================================================================
# ГЛАВА 2 — ГРЯЗНАЯ РАБОТА
# =====================================================================

func _c2_intro() -> void:
	await think("Утро. Серое, мокрое. Дождь стучит по подоконнику, как пальцы по столу.")
	await think("Звонит телефон. Впервые за год — мне.")


func _c2_phone() -> void:
	Au.ring(false)
	Au.sfx("locker", -6.0)
	await say("phone", "Доброе утро. Вы нужны мне сегодня. Адрес на карточке. Жду через час.")
	await me("Да. Я буду.")
	await say("phone", "И наденьте что-нибудь менее заметное.")
	await think("Гудки. Я смотрю на свою единственную куртку.")
	advance()


func _c2_penthouse() -> void:
	await think("Стекло от пола до потолка. Город под ногами — как макет на чужом столе.")
	await think("Отсюда люди выглядят точками. Наверное, к этому быстро привыкаешь.")


func _c2_brief() -> void:
	await say("patron", "Проходите, не стойте в дверях. Вы здесь не гость — вы работаете.")
	await say("patron", "У меня есть партнёр. Громов. Двадцать лет мы строили дело вместе. Теперь он решил, что справится один.")
	await me("Что от меня нужно?")
	await say("patron", "Папка с бумагами. Положить в ящик его стола. Завтра ею заинтересуются люди, которым положено интересоваться.")
	var c: int = await choose(["Это законно?", "А если меня увидят?"])
	if c == 0:
		await me("Это законно?")
		await say("patron", "Закон — инструмент. Как нож. Одни режут им хлеб, другие — горло. Важно лишь, в чьих он руках.")
	else:
		await me("А если меня увидят?")
		await say("patron", "После восьми там никого. Сторож пьёт чай в подвале и слушает радио. Я плачу ему за любовь к музыке.")
	await say("patron", "И второе. Типография Семёнова на Мельничной. Старик должен подписать вот это. Он знает, что должен.")
	await me("А если он откажется?")
	await say("patron", "Он не откажется. Вы умеете убеждать — я видел это в ресторане.")
	Au.sfx("paper")
	await think("Папка лёгкая. Договор — один лист. Странно, что такие вещи почти ничего не весят.")
	advance()


func _c2_gromov() -> void:
	await think("Контора Громова. Темно. На столе забыли погасить зелёную лампу.")
	await think("Пахнет табаком и старой бумагой. Обычная жизнь обычного человека.")


func _c2_drawer() -> void:
	var c: int = await choose(["Положить папку и уйти.", "Сначала заглянуть в папку."])
	if c == 1:
		Au.sfx("paper")
		await think("Счета. Расписки. Подпись Громова — на каждом листе.")
		await think("Бумага пахнет свежей краской. Этим документам не больше двух дней.")
		await think("Громов ничего этого не подписывал.")
		guilt += 1
	Au.sfx("locker")
	await think("Ящик закрывается с тихим щелчком. Как крышка.")
	await think("Вот и всё. Десять секунд. Я думал, будет труднее.")
	advance()


func _c2_shop() -> void:
	await think("Типография. Станок стучит, как большое уставшее сердце.")
	await think("Старик в фартуке даже не поднимает головы.")


func _c2_semyonov() -> void:
	var lv := Game.level
	var sem := npc("semyonov")
	await say("semyonov", "Закрыто. Приходите завтра.")
	await me("Я от Патрона.")
	await say("semyonov", "Я его не звал.")
	await me("Он просил передать вот это. Нужна ваша подпись.")
	await say("semyonov", "Тридцать лет. Тридцать лет я кормил этим станком семью. Вы хоть знаете, что в этой бумаге?")
	var c: int = await choose(["Просто подпишите. Так будет проще.", "Мне жаль. Но выбора у вас нет.", "Подписывайте. Или придут другие."])
	if c == 0:
		await me("Просто подпишите. Так будет проще для всех.")
		await say("semyonov", "Проще. Да. Вам — проще.")
	elif c == 1:
		await me("Мне жаль. Правда. Но выбора у вас нет.")
		await say("semyonov", "Жаль ему. Ты себя пожалей, сынок.")
	else:
		await me("Подписывайте. Или вместо меня придут другие. Они разговаривать не станут.")
		await say("semyonov", "Вот оно что. А ты, значит, добрый.")
		guilt += 1
	await say("semyonov", "У тебя руки рабочего человека. Я такие узнаю. Как же ты к нему попал?")
	await think("Я не отвечаю. Мне нечего ответить.")
	sem.pose = "write"
	Au.sfx("pen")
	await think("Перо скребёт по бумаге. Каждая буква его фамилии — как гвоздь.")
	sem.pose = "stand"
	Au.sfx("paper")
	await say("semyonov", "На. И передай ему: пусть подавится.")
	lv.updaters.clear()
	var wd: Dictionary = Game.W()
	Au.set_scene("quiet", wd.rain, true, wd.wind)
	await think("Станок за моей спиной останавливается. В тишине слышно только дождь.")
	advance()


func _c2_report() -> void:
	await say("patron", "Громов и Семёнов. За один вечер. Вы быстро учитесь.")
	Au.sfx("paper")
	await say("patron", "Это вам. Больше, чем вы зарабатывали за полгода.")
	await think("Деньги тяжелее, чем я думал. Или это я стал легче.")
	await me("Что будет с Громовым?")
	await say("patron", "То, что бывает с людьми, у которых в столе находят такие бумаги.")
	await me("А со стариком?")
	await say("patron", "Он свободен. Теперь ему не о чем беспокоиться. Совсем не о чем.")
	await me("Вы говорили — мы обсудим, как мне подняться.")
	await say("patron", "Сначала привыкните к высоте. От неё с непривычки кружится голова.")
	advance()


func _c2_end() -> void:
	await think("Я принёс домой деньги и тишину. Тишина громче.")
	await think("Лампа горит тусклее, чем вчера. Или мне кажется.")
	await think("Он не подавится, старик. Такие не давятся.")
	await end_chapter()


# =====================================================================
# ГЛАВА 3 — У ВСЕГО ЕСТЬ ЦЕНА
# =====================================================================

func _c3_intro() -> void:
	await think("Дождь идёт третью неделю. Я перестал включать свет — в темноте комната выглядит честнее.")
	await think("На столе — записка. Её подсунули под дверь, пока я спал.")


func _c3_note() -> void:
	Au.sfx("paper")
	await think("«Завтра. Мой офис. Сорок второй этаж. Работа для человека, который не задаёт вопросов».")
	await think("Вместо подписи — одна буква. Ему достаточно одной буквы.")
	advance()


func _c3_tower() -> void:
	await think("Сорок второй этаж. Молнии освещают кабинет, как вспышки фотографа.")
	await think("На стене — карта города. В неё воткнуты красные флажки. Много флажков.")


func _c3_brief() -> void:
	await say("patron", "Рейнер. Слышали это имя?")
	await me("Он строит приют. Для детей с Верфи.")
	await say("patron", "Приют, больницу, школу. Благотворитель. Ненавижу благотворителей — они скупают совесть оптом и сбивают цену.")
	await say("patron", "Приют стоит на земле, которая нужна мне. Рейнер землю не продаст. Значит, Рейнер должен перестать ею владеть.")
	await me("Что нужно сделать?")
	await say("patron", "Вот счета. По ним выходит, что фонд годами переводил деньги самому себе. Положите их в его сейф. Утром придёт проверка.")
	var c: int = await choose(["Но там же дети.", "Он это заслужил?"])
	if c == 0:
		await me("Но там же дети.")
		await say("patron", "Дети вырастут. И половина придёт работать ко мне. Я даю людям будущее, а не суп.")
	else:
		await me("Он это заслужил?")
		await say("patron", "Заслужил? Странное слово. Его придумали те, кому ничего не досталось.")
	await say("patron", "Сейф не заперт. Он никогда его не запирает. Говорит — от своих прятать нечего.")
	Au.sfx("paper")
	await think("Папка такая же лёгкая, как первая. Я начинаю ненавидеть лёгкие вещи.")
	advance()


func _c3_reiner() -> void:
	await think("Тёплый свет. Пахнет чаем и клеем. На стене — детские рисунки: дом с трубой, солнце с лучами-палочками.")
	await think("Он ещё здесь. Этого не должно было быть.")


func _c3_talk() -> void:
	var lv := Game.level
	var rn := npc("reiner")
	await say("reiner", "О! Вы ко мне? В такой-то ливень. Проходите, проходите.")
	await me("Я... из банка. Сверка документов. Простите, что так поздно.")
	await say("reiner", "Какое поздно, я всё равно сижу над сметой. Новый корпус, сорок коек. К сентябрю успеем, если не подведут с кровлей.")
	await say("reiner", "Да вы же промокли до нитки. Садитесь. Я принесу чаю — у нас хороший, с чабрецом.")
	var c: int = await choose(["Спасибо.", "Не стоит беспокоиться."])
	if c == 0:
		await me("Спасибо.")
	else:
		await me("Не стоит беспокоиться.")
		await say("reiner", "Беспокоиться — моя работа. Сидите.")
	UI.hide_dialog()
	rn.pose = "stand"
	Game.focus_on(Vector3(1.5, 1.2, -0.5), 8.0, 0.45)
	await _walk_chain(rn, [Vector3(1.3, 0, -2.25), Vector3(1.7, 0, 0.2), Vector3(4.3, 0, 2.3)], 2.3)
	Au.sfx("door")
	rn.visible = false
	lv.remove_inter("reiner")
	Game.focus_clear()
	await think("Он выходит. Просто выходит и оставляет меня одного. С незапертым сейфом.")
	advance()


func _c3_safe() -> void:
	var lv := Game.level
	var rn := npc("reiner")
	var c: int = await choose(["Положить бумаги в сейф.", "Забрать бумаги и уйти."])
	if c == 1:
		await think("Я стою. Бумаги жгут руку. Можно ведь просто уйти.")
		await think("А потом? Патрон ничего не забывает. А мне некуда возвращаться — разве что за тот столик, где меня не замечали.")
	else:
		await think("Руки делают всё сами. Быстро. Аккуратно. Я стал хорошо это уметь.")
		guilt += 1
	Au.sfx("locker")
	await think("Между папками — детский рисунок. Человечек держит за руки пятерых поменьше. Печатными буквами: «дядя Рейнер».")
	Au.sfx("paper")
	await think("Я кладу счета поверх рисунка и закрываю дверцу.")
	UI.hide_dialog()
	Au.sfx("door")
	if rn != null and is_instance_valid(rn):
		rn.visible = true
		rn.position = Vector3(4.3, 0, 2.3)
		rn.watch = Game.player
		Game.focus_on(Vector3(3.0, 1.2, -0.5), 7.5, 0.4)
		await rn.walk_to(Vector3(3.0, 0, -1.2), 2.0)
		rn.face_pos(Game.player.global_position)
		Game.player.face_pos(rn.global_position)
		Game.focus_two(Game.player.global_position, rn.global_position)
	await say("reiner", "Вот, горячий. Осторожно, не обожгитесь. А вы... вы уже уходите?")
	await me("Да. Я всё проверил. Всё в порядке.")
	await say("reiner", "Ну и славно. Приходите в сентябре — мы открываем двери. Дети будут петь.")
	await think("Он смотрит мне вслед. Я чувствую это спиной. Я не оборачиваюсь.")
	advance()


func _c3_report() -> void:
	await say("patron", "Утром у него были гости. К обеду — наручники. К вечеру фонд опечатают.")
	await think("Он говорит по телефону и со мной одновременно. Я для него — одно из двух дел.")
	await me("А приют?")
	await say("patron", "Какой приют? Там будет порт. Люди получат работу. В газетах напишут, что я спас район.")
	await me("Вы обещали, что мы поговорим.")
	await say("patron", "Разумеется. Ещё пара дел — и поговорим.")
	Game.strike(1.2)
	await think("«Ещё пара дел». Он говорит это в третий раз. Теми же словами. С той же улыбкой.")
	await think("Он никогда не собирался. Я понимаю это так ясно, будто в комнате включили свет.")
	advance()


func _c3_end() -> void:
	await think("В сентябре дети должны были петь.")
	await think("Я лежу в одежде. Мне кажется, если её снять — под ней никого не окажется.")
	await end_chapter()


# =====================================================================
# ГЛАВА 4 — ПУСТОЙ ТРОН
# =====================================================================

func _c4_intro() -> void:
	await think("Гроза не кончается. В комнате почти ничего не осталось. Я не помню, продал я это или просто перестал замечать.")
	await think("На столе — ещё одна записка.")


func _c4_note() -> void:
	Au.sfx("paper")
	await think("«Особняк. Сегодня. Последнее дело — и вы наверху».")
	await think("Наверху. Раньше от этого слова теплело в груди.")
	advance()


func _c4_mansion() -> void:
	await think("Особняк на холме. Дождь бьёт в окна так, что за стеклом нет ничего. Только отражение огня.")


func _c4_brief() -> void:
	var lv := Game.level
	await say("patron", "Последнее дело. После него — клуб «Вершина». Приглашение уже печатают. С золотым обрезом.")
	await me("Кто?")
	await say("patron", "Марк Вольский. Когда-то он делал для меня то же, что и вы. Потом стал сентиментален. Теперь он слишком много помнит.")
	await say("patron", "Он на старой пристани. Седьмой причал. Он всегда там, когда дождь.")
	await me("Что я должен сделать?")
	await say("patron", "Избавьте меня от него.")
	Game.strike(1.3)
	await think("На столике у камина лежит пистолет. Он лежал там с самого начала. Я просто не хотел его видеть.")
	var c: int = await choose(["Я не убийца.", "Молча взять пистолет."])
	if c == 0:
		await me("Я не убийца.")
		await say("patron", "Пока нет. Но вы и курьером не были. И взломщиком. Человек — существо гибкое.")
	else:
		await think("Я молчу. Он кивает — так кивают официанту, который правильно понял заказ.")
		guilt += 1
	Au.sfx("bolt", -8.0)
	if lv.has_meta("gun_prop"):
		(lv.get_meta("gun_prop") as Node3D).visible = false
	await think("Он тяжёлый и холодный. Первая тяжёлая вещь, которую дал мне Патрон.")
	advance()


func _c4_pier() -> void:
	await think("Седьмой причал. Доски скользкие, вода чёрная. Город на том берегу — как чужая жизнь за стеклом.")
	await think("В конце пристани кто-то сидит. С удочкой. В такую погоду.")


func _c4_marc() -> void:
	var lv := Game.level
	var marc := npc("marc")
	var pl := Game.player
	await say("marc", "Подходи, не стой. Я не стреляю. Давно уже не стреляю.")
	await me("Вы Марк?")
	await say("marc", "Был. Теперь — рыбак. Хотя рыбы здесь нет с тех пор, как он построил завод выше по течению.")
	await say("marc", "Я знаю, зачем ты пришёл. Он дал тебе пистолет. Мне он дал точно такой же. Двенадцать лет назад.")
	await me("Что?")
	await say("marc", "«Золотой фазан». Солнечный день. Двое громил пристают к седому господину. Весь зал молчит — и только один дурак встаёт.")
	Game.shake(0.12)
	await think("Доски уходят из-под ног.")
	await me("Драка... была подстроена?")
	await say("marc", "Два безработных актёра и бутылка вина. Он так ищет людей. Тех, кто встанет. Таких вести легче всего — они ведь уверены, что хорошие.")
	await think("Тот день. То солнце. То тепло в груди. Всё это стоило ему бутылки вина.")
	await say("marc", "Нет никакой вершины, парень. Есть тот, кто стоит чуть выше и держит тебя за ворот. А над ним — тот, кто держит его. И так без конца.")
	await say("marc", "Ну. Решай. Не выстрелишь ты — он пришлёт следующего. Следующий разговаривать не станет.")
	pl.human.show_gun(true)
	pl.human.pose = "aim"
	Au.sfx("bolt", -4.0)
	Game.focus_on((pl.global_position + marc.global_position) / 2.0 + Vector3(0, 1.3, 0), 4.6, 0.12)
	var c: int = await choose(["Выстрелить.", "Опустить пистолет."])
	UI.hide_dialog()
	if c == 0:
		Game.flags["shot"] = true
		guilt += 2
		await Game.wait(0.5)
		UI.fade_rect.color.a = 1.0
		Au.sfx("gunshot")
		Game.strike(1.5)
		await Game.wait(2.2)
		await think("Выстрел. Гром. Что-то тяжёлое падает в воду.")
		await think("Руки не дрожали. Вот что страшнее всего.")
	else:
		pl.human.pose = "stand"
		await say("marc", "Так я и думал. Ты ещё не до конца его.")
		await say("marc", "Дай сюда. И иди. Скажи ему — сделано. Он не станет проверять. Он никогда не проверяет.")
		UI.hide_dialog()
		await UI.fade(true, 1.2)
		await think("Я отдаю пистолет и иду к берегу. Не оборачиваюсь.")
		UI.hide_dialog()
		await Game.wait(1.0)
		Au.sfx("gunshot", -5.0)
		await Game.wait(2.0)
		await think("За спиной — выстрел. Один. Потом только дождь.")
		await think("Я так и не обернулся. Вот что страшнее всего.")
	UI.hide_dialog()
	pl.human.show_gun(false)
	pl.human.pose = "stand"
	lv.remove_npc("marc")
	pl.teleport(Vector3(0, 0, -9.5), 0.0)
	Game.focus_on(Vector3(0, 0.8, -13.2), 6.0, 0.3, 0.3)
	await Game.wait(0.4)
	await UI.fade(false, 2.0)
	await think("На краю пристани остались фонарь и удочка.")
	advance()


func _c4_report() -> void:
	await say("patron", "Сделано?")
	await me("Сделано.")
	await say("patron", "Я не сомневался. Вот, держите. Вы это заслужили.")
	Au.sfx("paper")
	await think("Плотный картон, золотой обрез. Клуб «Вершина», приём в субботу. Моё имя напечатано без ошибок.")
	await say("patron", "Знаете, Марк тоже был хорош. Но ему всё казалось, что он лучше меня. А вам ведь так не кажется?")
	var c: int = await choose(["Нет.", "Промолчать."])
	if c == 0:
		await me("Нет.")
		await say("patron", "Вот поэтому вы и наверху.")
	else:
		await think("Я молчу.")
		await say("patron", "Молчание. Самый дорогой товар в этом городе. Вы научились.")
	await think("Я получил всё, чего хотел. Стою у камина, в руках приглашение — и не чувствую ничего. Совсем ничего.")
	advance()


func _c4_end() -> void:
	await think("Я кладу приглашение на голый матрас. Это единственная красивая вещь в комнате.")
	await think("Говорят, наверху не слышно, как идёт дождь.")
	await end_chapter()


# =====================================================================
# ГЛАВА 5 — НА ВЕРШИНЕ
# =====================================================================

func _c5_intro() -> void:
	await think("Новая квартира. Он прислал ключи с курьером. Мрамор, стекло, рояль, на котором некому играть.")
	await think("Дождь кончился. Город внизу тихий и чистый. Как после уборки.")


func _c5_invite() -> void:
	Au.sfx("paper")
	await think("«Клуб „Вершина“ имеет честь принять вас в число своих членов. Сегодня. Маска обязательна лишь для тех, кому ещё есть что скрывать».")
	await think("Смокинг сидит безупречно. Его шили по меркам, которых я никому не давал.")
	advance()


func _c5_mansion() -> void:
	await think("Музыка. Свет. Сотня человек — и ни одного лица. Только белые маски.")
	await think("Они расступаются передо мной. Вежливо. Как перед своим.")


func _c5_patron() -> void:
	await say("patron", "А вот и вы. Добро пожаловать наверх.")
	await me("Они все в масках.")
	await say("patron", "Привычка. Здесь не принято смотреть друг другу в лицо. Вы это оцените.")
	await say("patron", "Вот она, вершина, мой мальчик. Вы столько сюда шли. Ну, как вам здешний воздух?")
	var c: int = await choose(["Здесь нечем дышать.", "Я ничего не чувствую."])
	if c == 0:
		await me("Здесь нечем дышать.")
		await say("patron", "Привыкнете. Все привыкают.")
	else:
		await me("Я ничего не чувствую.")
		await say("patron", "Значит, вы наконец один из нас.")
	await say("patron", "В кабинете вас ждут. Небольшая формальность — совет хочет вас принять. Идите. Дверь слева.")
	advance()


func _c5_door() -> void:
	await think("Дверь кабинета. Тяжёлая, тёмная. За спиной стихает музыка.")
	advance()
	await Game.travel("cabinet")


func _c5_cabinet() -> void:
	Au.silence_all()
	await think("Тихо. После зала — так тихо, что слышно собственное сердце.")
	await say("voices", "Мы принимаем вас.")
	await think("Голоса за дверью. Много голосов. Они говорят хором, без выражения.")
	await think("Дверь за моей спиной закрылась. Я не слышал, как.")


func _c5_final() -> void:
	var lv := Game.level
	Game.focus_on(Vector3(0.0, 0.95, -1.0), 3.4, 0.5, 0.0)
	await think("На столе под лампой — три предмета. Папироса. Зажигалка. Пистолет.")
	await think("Я знаю, что это за формальность. Знаю, для чего здесь каждая из этих вещей.")
	await think("Семёнов. Громов. Рейнер и его сентябрь. Марк. И тот человек в ресторане, который однажды встал.")
	await say("voices", "Мы принимаем вас.")
	await think("Я беру папиросу. Потом зажигалку. Потом — пистолет.")
	await think("И долго смотрю на них.")
	UI.hide_dialog()
	finished = true
	Game.refresh_objective()
	Game.focus_on(Vector3(0.0, 0.9, -1.0), 2.2, 0.62, 0.0)
	await Game.wait(3.2)
	await UI.fade(true, 2.6)
	Au.silence_all(true)
	await Game.wait(1.6)
	Au.sfx("lighter", 2.0)
	await Game.wait(2.8)
	Au.sfx("bolt", 3.0)
	await Game.wait(4.0)
	await UI.card("На вершине", "Конец", 4.0)
	Au.music("credits", 0.9)
	await UI.card("", "Он закурил — или нет.\nЭтого не знает никто. Даже те, кто его принял.", 5.0)
	await UI.card("", "Музыка: Kevin MacLeod (incompetech.com)\nлицензия Creative Commons BY 4.0\n\nЗвуки: Joseph Sardin, BigSoundBank.com", 5.0)
	await UI.card("Спасибо за игру", "", 3.0)
	Game.finish_game()


# =====================================================================
# Второстепенные взаимодействия
# =====================================================================

func _flavor(scene: String, iid: String) -> void:
	var ch: int = Game.chapter
	match scene + "/" + iid:
		"apartment/bed":
			match ch:
				1:
					await think("Скрипучая, продавленная. Зато своя.")
				2:
					await think("Сейчас не до сна.")
				3:
					await think("Я давно не сплю. Просто лежу и слушаю дождь.")
				4:
					await think("Голый матрас. Простыни куда-то делись. Как и всё остальное.")
				_:
					await think("Слишком широкая для одного. Я сплю на краю.")
		"apartment/phone":
			match ch:
				1:
					await think("Телефон. Он звонит раз в месяц — когда ошибаются номером.")
				2:
					await think("Чёрная трубка. Раньше она молчала. Теперь я вздрагиваю от каждого звука.")
				3:
					await think("Он больше не звонит. Он присылает записки. Так остаётся меньше следов.")
				4:
					await think("Провод перерезан. Не помню, чтобы я это делал.")
				_:
					await think("Новый аппарат. В записной книжке — ни одного номера, по которому хотелось бы позвонить.")
		"apartment/window":
			match ch:
				1:
					await think("Город блестит на солнце. Где-то там, наверху, живут по-другому.")
				2:
					await think("Дождь рисует на стекле реки. Все они текут вниз.")
				3:
					await think("Молния. На секунду весь город — фотография, на которой нет людей.")
				4:
					await think("За стеклом ничего нет. Только вода и чужие фары.")
				_:
					await think("Огни до самого горизонта. Город красив, пока не знаешь, из чего он сделан.")
		"apartment/mirror":
			match ch:
				1:
					await think("Обычный человек в поношенной куртке. Сегодня он почти улыбается.")
				2:
					await think("Тени под глазами. Раньше я их не замечал.")
				3:
					await think("Лицо знакомое. Человека — не узнаю.")
				4:
					await think("Я ищу в нём того, кто встал из-за столика в ресторане. Его там нет.")
				_:
					await think("Смокинг сидит безупречно. Человек в нём — никак.")
		"apartment/photo":
			match ch:
				1:
					await think("Мама на моём выпускном. Она бы сказала: только не лезь туда, где тебе не рады.")
				2:
					await think("Мама смотрит с фотографии. Я отвожу глаза первым.")
				_:
					await think("Рамка повёрнута к стене. Не помню, когда я это сделал.")
		"apartment/table":
			match ch:
				1:
					await think("Стол на двоих. Второй стул — на случай, если кто-нибудь придёт.")
				2:
					await think("Счета. Я могу оплатить их все разом. Странно, что от этого не легче.")
				3, 4:
					await think("Записка. Я уже знаю её наизусть.")
				_:
					await think("Приглашение с золотым обрезом. Оно весит не больше, чем конверт с вокзала.")
		"restaurant/menu":
			await think("Стейк стоит как моя неделя. Вино — как месяц. Воду, кажется, подают бесплатно.")
		"restaurant/window":
			await think("За стеклом — солнце и люди, которые идут мимо. Я всю жизнь был по ту сторону.")
		"restaurant/bar":
			await think("Бутылки на полках блестят, как ордена. Бармен протирает бокал и смотрит сквозь меня.")
		"restaurant/lady":
			await say("lady", "Вы что-то хотели? Нет? Тогда не загораживайте, пожалуйста, свет.")
		"restaurant/gent":
			if Game.stage >= 2:
				await think("Он смотрит в газету. Он не поднял головы даже во время драки.")
			else:
				await think("Старик читает биржевые сводки. Губы шевелятся, как на молитве.")
		"restaurant/waiter":
			if Game.stage >= 2:
				await say("waiter", "Ваш обед за счёт заведения, сэр. Распоряжение того господина.")
			else:
				await say("waiter", "Одну минуту, сэр.")
		"restaurant/patron":
			if Game.stage == 0:
				await think("Седой господин за столиком у окна. Сидит спиной к залу. Так сидят те, кому нечего бояться.")
			elif Game.stage == 1:
				await think("Ему заламывают руку. Он даже не кричит.")
			else:
				await say("patron", "Ячейка тринадцать, Северный вокзал. Не заставляйте меня повторять дважды.")
		"restaurant/thug1":
			await think("От него пахнет дешёвым вином.")
		"station/clerk":
			await say("clerk", "Ячейки — вон там, у стены. Ключ свой? Ну и идите. Мне за разговоры не платят.")
		"station/traveler":
			await say("traveler", "Поезд на юг отменили. Третий день. Говорят, наверху решают.")
			await think("Здесь всё время что-то решают наверху.")
		"station/lockers":
			await think("Сотни чужих тайн за одинаковыми дверцами. Мне нужна только одна.")
		"station/locker13":
			await think("Ячейка тринадцать. Пустая.")
		"station/window":
			if ch == 1:
				await think("Свет падает сверху, как в церкви. Только молятся здесь расписанию.")
			else:
				await think("Стёкла под потолком залиты дождём.")
		"penthouse/bar":
			await think("Коньяк старше меня. На этикетке — год, когда отец ещё был жив.")
		"penthouse/window":
			await think("Отсюда не видно ни моей улицы, ни типографии. Сверху всё одинаково серое.")
		"penthouse/patron":
			await say("patron", "Вы ещё здесь? Работа сама себя не сделает.")
		"gromov/photo":
			await think("Двое молодых мужчин на крыльце, в обнимку. Один — Громов. Второго я узнаю не сразу: у Патрона тогда были тёмные волосы.")
		"gromov/window":
			await think("Во дворе темно. Только дождь в свете фонаря.")
		"gromov/drawer":
			await think("Дело сделано. Нечего здесь больше трогать.")
		"shop/press":
			if Game.stage > 3:
				await think("Станок стоит. Краска на валах ещё не высохла.")
			else:
				await think("Сегодняшний тираж — афиши детского праздника. Буквы ровные, одна к одной.")
		"shop/semyonov":
			await think("Он на меня не смотрит. Смотрит на станок.")
		"tower/map":
			await think("Красные флажки: типография на Мельничной, контора на Литейной, приют на Верфи.")
			await think("Три из них поставил я. Интересно, кто воткнул остальные.")
		"tower/window":
			await think("С сорок второго этажа дождь идёт не сверху, а мимо.")
		"tower/patron":
			await say("patron", "Утром придёт проверка. Не опаздывайте к вечеру.")
		"reiner/drawings":
			await think("Дом. Собака. Очень большое солнце. На одном рисунке — человек в очках, выше дома.")
		"reiner/model":
			await think("Макет из картона. Новый корпус, сорок коек. На крыше — флажок, вырезанный из фантика.")
		"reiner/safe":
			await think("Сейф приоткрыт. Он и правда его не запирает.")
		"reiner/reiner":
			await say("reiner", "Сейчас-сейчас. Только допишу строчку.")
		"mansion/portrait":
			if ch == 5:
				await think("Портрет хозяина. Художник написал глаза последними — и, кажется, не дописал.")
			else:
				await think("Портрет хозяина над камином. На нём он моложе. Улыбка та же.")
		"mansion/window":
			if ch == 5:
				await think("Гроза ушла. В чёрном стекле — только отражения масок.")
			else:
				await think("Молнии. В каждой вспышке сад — как негатив.")
		"mansion/cabinet_door":
			await think("Заперто. Из-под двери не пробивается ни полоски света.")
		"mansion/patron":
			if ch == 5:
				await say("patron", "Идите, идите. Вас ждут.")
			else:
				await say("patron", "Седьмой причал. И не тяните.")
		"mansion/guest_m":
			await say("guest_m", "Новенький? А, тот самый. Про вас говорят, что вы очень исполнительны.")
			await say("guest_m", "Шампанского? Сегодня оно за счёт одного детского фонда. Шутка. Почти.")
		"mansion/guest_f":
			await say("guest_f", "Не снимайте лица, дорогой. Здесь это считается дурным тоном.")
			await think("Она смеётся. Маска при этом не двигается.")
		"cabinet/door":
			await think("Ручка не поворачивается. Меня приняли. А значит — не выпустят.")
		_:
			await think("Ничего особенного.")
