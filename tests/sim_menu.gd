extends SceneTree
# Проверка меню и настроек: кнопки, язык, громкость, переназначение клавиш, сохранение, запуск игры.
var f := 0
var menu
var screen
var ok := true
var cyr := RegEx.new()

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		ok = false

func texts_of(node: Node, skip_options := true) -> Array:
	var out := []
	if node is Label or node is Button:
		if not (skip_options and node is OptionButton):
			out.append(node.text)
	for c in node.get_children():
		out.append_array(texts_of(c, skip_options))
	return out

func find_buttons(node: Node) -> Array:
	var out := []
	if node is Button and not (node is OptionButton):
		out.append(node)
	for c in node.get_children():
		out.append_array(find_buttons(c))
	return out

func key_event(kc: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = kc as Key
	ev.pressed = true
	return ev

func has_key(action: String, kc: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and e.physical_keycode == kc:
			return true
	return false

func _physics_process(_d: float) -> bool:
	f += 1
	var S = root.get_node("Settings")
	var I = root.get_node("Inputs")
	if f == 1:
		cyr.compile("[а-яА-ЯёЁ]")
		menu = load("res://scenes/menu.tscn").instantiate()
		root.add_child(menu)
		return false
	if f == 3:
		var t := texts_of(menu)
		check("Меню: есть название игры", "АНТРАКТ" in t)
		check("Меню: кнопки Играть, Настройки, Выход", "Играть" in t and "Настройки" in t and "Выход" in t)
		screen = menu._settings
		check("Настройки скрыты, пока не нажали кнопку", not screen.visible)
		menu._on_settings()
	if f == 5:
		check("Кнопка Настройки открывает экран настроек", screen.visible and not menu._menu_box.visible)
		check("В настройках есть строки управления для всех действий", screen._key_buttons.size() == I.DEFAULTS.size())
		check("Кнопки показывают клавиши (A для «Влево»)", screen._key_buttons["move_left"].text == "A")
	# ---- язык
	if f == 6:
		S.set_language("en")
	if f == 8:
		check("Язык: английский применён", TranslationServer.get_locale() == "en" and tr("Играть") == "Play")
		var all_texts := texts_of(menu)
		var bad := []
		for tx in all_texts:
			if cyr.search(tx):
				bad.append(tx)
		check("В английском режиме в меню и настройках нет русских надписей", bad.is_empty())
		if not bad.is_empty():
			print("   русские остатки: ", bad)
		check("Название меню по-английски", menu._title.text == "THE INTERMISSION")
		S.set_language("ru")
	if f == 10:
		check("Язык: русский возвращается", tr("Играть") == "Играть" and menu._play.text == "Играть")
	# ---- громкость
	if f == 11:
		S.set_volume(0.5)
	if f == 12:
		check("Громкость 50% = около -6 дБ", absf(AudioServer.get_bus_volume_db(0) - (-6.02)) < 0.2 and not AudioServer.is_bus_mute(0))
		screen._volume_slider.value = 0.25
	if f == 13:
		check("Ползунок меняет громкость", absf(S.volume - 0.25) < 0.001 and screen._volume_label.text == "25%")
		S.set_volume(0.0)
	if f == 14:
		check("Громкость 0 = выключен звук", AudioServer.is_bus_mute(0))
		S.set_volume(0.8)
	# ---- переназначение клавиш через интерфейс
	if f == 15:
		screen._start_listen("jump")
		check("Кнопка переходит в режим ожидания клавиши", screen._key_buttons["jump"].text.begins_with("Нажми"))
		screen._input(key_event(KEY_X))
	if f == 16:
		check("Прыжок теперь на X", I.bindings.jump == KEY_X and screen._key_buttons["jump"].text == "X")
		check("Оба героя прыгают по X", has_key("p1_jump", KEY_X) and has_key("p2_jump", KEY_X))
		check("Старая клавиша W больше не прыжок", not has_key("p1_jump", KEY_W))
		check("Запасные (Пробел, стрелка вверх) остались", has_key("p1_jump", KEY_SPACE) and has_key("p1_jump", KEY_UP))
		# конфликт: «Бросить трос» на G (там «Отпустить»): они меняются
		screen._start_listen("throw")
		screen._input(key_event(KEY_G))
	if f == 17:
		check("Конфликт: клавиши поменялись местами", I.bindings.throw == KEY_G and I.bindings.release == KEY_F)
		check("Действия Льва по новым клавишам", has_key("p1_throw", KEY_G) and has_key("p1_release", KEY_F))
		# Esc отменяет
		screen._start_listen("dash")
		screen._input(key_event(KEY_ESCAPE))
	if f == 18:
		check("Esc отменяет переназначение", I.bindings.dash == KEY_SHIFT and screen._listening == "")
		# сохранение
		var before: Dictionary = I.bindings.duplicate()
		S.saved_bindings = {}
		S.load_settings()
		check("Файл настроек сохранил клавиши", int(S.saved_bindings.get("jump", 0)) == KEY_X and int(S.saved_bindings.get("throw", 0)) == KEY_G)
		check("Файл настроек сохранил громкость и язык", absf(S.volume - 0.8) < 0.001 and S.language == "ru")
		# подсказки в игре берут новые клавиши
		var main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		main.set_meta("chk", true)
		root.set_meta("main", main)
	if f == 21:
		var main = root.get_meta("main")
		var t = main.hud.get_texts()
		check("Подсказка Льва показывает новые клавиши (X, G)", "X" in t.lev_help and "G" in t.lev_help and "F" in t.lev_help)
		S.set_language("en")
		var te = main.hud.get_texts()
		var bad2 := []
		for k in te:
			if cyr.search(str(te[k])):
				bad2.append(str(te[k]))
		check("В английском режиме в игровом интерфейсе нет русских надписей", bad2.is_empty())
		if not bad2.is_empty():
			print("   русские остатки: ", bad2)
		check("Сообщение о неудачном обмене переводится", tr("Обмен: Лев слишком далеко") == "Swap: Lev is too far away")
		S.set_language("ru")
		main.queue_free()
		# сброс
		screen._reset_button.pressed.emit()
	if f == 23:
		check("Сброс управления возвращает клавиши", I.bindings == I.DEFAULTS and has_key("p1_jump", KEY_W) and screen._key_buttons["jump"].text == "W")
		# закрытие настроек
		screen.closed.emit()
	if f == 24:
		check("Кнопка Назад возвращает в меню", not screen.visible and menu._menu_box.visible)
		# Играть
		menu._on_play()
	if f == 28:
		check("Кнопка Играть запускает игровую комнату", current_scene != null and current_scene.name == "Main")
		S.set_language("ru")
		S.set_volume(0.8)
		print(("ВСЕ ТЕСТЫ ПРОШЛИ" if ok else "ЕСТЬ ПРОВАЛЫ"))
		quit(0 if ok else 1)
	return false
