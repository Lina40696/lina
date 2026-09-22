extends Control
# ЭКРАН НАСТРОЕК: язык, громкость и переназначение клавиш. Открывается из главного меню.
# Всё собирается кодом. Каждое изменение сразу применяется и сохраняется.

signal closed

const UiStyle := preload("res://scripts/ui_style.gd")

# Строки управления: [группа, имя привязки (см. inputs.gd), подпись]
const ROWS := [
	["Движение (оба героя)", "move_left", "Влево"],
	["Движение (оба героя)", "move_right", "Вправо"],
	["Движение (оба героя)", "jump", "Прыжок"],
	["Лев", "throw", "Бросить трос"],
	["Лев", "release", "Отпустить трос"],
	["Лев", "dash", "Рывок"],
	["Мира", "light", "Фонарь"],
	["Мира", "swap", "Обмен с Львом"],
	["Общее", "switch_hero", "Сменить героя"],
	["Общее", "interact", "Взаимодействие (заговорить, рычаг)"],
]

var _texts: Array = []            # пары [узел, ключ перевода]: чтобы менять язык на лету
var _key_buttons: Dictionary = {} # имя привязки -> кнопка с названием клавиши
var _listening: String = ""       # для какого действия сейчас ждём нажатие клавиши
var _lang_codes: Array = []
var _lang_option: OptionButton
var _volume_slider: HSlider
var _volume_label: Label
var _reset_button: Button
var _back_button: Button
var _blip: AudioStreamPlayer
var _dragging: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Settings.language_changed.connect(func(_l: String) -> void:
		_lang_option.select(_lang_codes.find(Settings.language))
		_apply_texts())
	_apply_texts()


func open() -> void:
	visible = true
	_listening = ""
	_lang_option.select(_lang_codes.find(Settings.language))
	_volume_slider.set_value_no_signal(Settings.volume)
	_update_volume_label()
	_apply_texts()
	_lang_option.grab_focus()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.10, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var title := _label("Настройки", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	root.add_child(title)

	# --- Язык
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 16)
	var lang_label := _label("Язык", 22)
	lang_label.custom_minimum_size = Vector2(180, 0)
	lang_row.add_child(lang_label)
	_lang_option = OptionButton.new()
	_lang_option.custom_minimum_size = Vector2(240, 40)
	for code in Settings.LANGUAGES:
		_lang_codes.append(code)
		_lang_option.add_item(Settings.LANGUAGES[code])
	_lang_option.select(_lang_codes.find(Settings.language))
	UiStyle.style_button(_lang_option)
	_lang_option.item_selected.connect(func(i: int) -> void: Settings.set_language(_lang_codes[i]))
	lang_row.add_child(_lang_option)
	root.add_child(lang_row)

	# --- Громкость
	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 16)
	var vol_label := _label("Громкость", 22)
	vol_label.custom_minimum_size = Vector2(180, 0)
	vol_row.add_child(vol_label)
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.01
	_volume_slider.value = Settings.volume
	_volume_slider.custom_minimum_size = Vector2(320, 32)
	_volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume_slider.value_changed.connect(_on_volume_changed)
	_volume_slider.drag_started.connect(func() -> void: _dragging = true)
	_volume_slider.drag_ended.connect(func(_changed: bool) -> void:
		_dragging = false
		_play_blip())
	vol_row.add_child(_volume_slider)
	_volume_label = Label.new()
	_volume_label.custom_minimum_size = Vector2(70, 0)
	_volume_label.add_theme_font_size_override("font_size", 22)
	vol_row.add_child(_volume_label)
	root.add_child(vol_row)
	_update_volume_label()

	# --- Управление
	var controls_title := _label("Управление", 26)
	controls_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	root.add_child(controls_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	var grid: GridContainer = null
	var last_group := ""
	for row in ROWS:
		if row[0] != last_group:
			last_group = row[0]
			var heading := _label(row[0], 20)
			heading.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
			content.add_child(heading)
			grid = GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 24)
			grid.add_theme_constant_override("v_separation", 6)
			content.add_child(grid)
		var name_label := _label(row[2], 20)
		name_label.custom_minimum_size = Vector2(300, 0)
		grid.add_child(name_label)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(240, 38)
		UiStyle.style_button(btn)
		btn.pressed.connect(_start_listen.bind(row[1]))
		grid.add_child(btn)
		_key_buttons[row[1]] = btn

	for note_key in ["Стрелки и Пробел тоже работают для движения и прыжка.", "Рисование: ЛКМ рисует внутри рамки, ПКМ стирает (мышь не переназначается)."]:
		var note := _label(note_key, 16)
		note.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(700, 0)
		content.add_child(note)

	# --- Кнопки внизу
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	_reset_button = Button.new()
	_reset_button.custom_minimum_size = Vector2(260, 46)
	UiStyle.style_button(_reset_button)
	_reset_button.pressed.connect(func() -> void:
		_listening = ""
		Inputs.reset_bindings()
		_refresh_keys())
	_texts.append([_reset_button, "Сбросить управление"])
	bottom.add_child(_reset_button)
	_back_button = Button.new()
	_back_button.custom_minimum_size = Vector2(200, 46)
	UiStyle.style_button(_back_button)
	_back_button.pressed.connect(func() -> void: closed.emit())
	_texts.append([_back_button, "Назад"])
	bottom.add_child(_back_button)
	root.add_child(bottom)

	_blip = AudioStreamPlayer.new()
	_blip.stream = _make_blip()
	add_child(_blip)


func _label(key: String, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	_texts.append([l, key])
	return l


func _apply_texts() -> void:
	for pair in _texts:
		pair[0].text = tr(pair[1])
	_refresh_keys()


func _refresh_keys() -> void:
	for name in _key_buttons:
		_key_buttons[name].text = tr("Нажми клавишу… (Esc: отмена)") if name == _listening else Inputs.key_name(name)


func _start_listen(binding: String) -> void:
	_listening = binding
	_refresh_keys()


# Пока ждём клавишу, перехватываем нажатие до остального интерфейса.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _listening != "":
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			var keycode: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if keycode != KEY_ESCAPE:
				Inputs.rebind(_listening, keycode)
			_listening = ""
			_refresh_keys()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _on_volume_changed(value: float) -> void:
	Settings.set_volume(value)
	_update_volume_label()
	if not _dragging:
		_play_blip()


func _update_volume_label() -> void:
	_volume_label.text = "%d%%" % int(round(_volume_slider.value * 100.0))


func _play_blip() -> void:
	if _blip:
		_blip.play()


# Короткий «бип», чтобы сразу слышать, какая громкость. Собираем звук кодом, без файлов.
func _make_blip() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.14)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(rate)
		var fade := 1.0 - float(i) / float(count)
		var sample := int(sin(TAU * 523.25 * t) * 0.45 * fade * 32767.0)
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
