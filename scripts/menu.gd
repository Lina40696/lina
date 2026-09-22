extends Control
# ГЛАВНОЕ МЕНЮ: название игры, кнопки «Играть», «Настройки», «Выход».
# Открывается при запуске. «Играть» загружает игровую комнату.

const SettingsScreen := preload("res://scripts/settings_screen.gd")
const GAME_SCENE := "res://scenes/main.tscn"
const UiStyle := preload("res://scripts/ui_style.gd")

var _menu_box: Control
var _title: Label
var _subtitle: Label
var _play: Button
var _settings_button: Button
var _quit: Button
var _settings: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.10, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_menu_box = center

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 84)
	_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	box.add_child(spacer)

	_play = _make_button(box, _on_play)
	_settings_button = _make_button(box, _on_settings)
	_quit = _make_button(box, _on_quit)

	_settings = SettingsScreen.new()
	_settings.visible = false
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)

	Settings.language_changed.connect(func(_l: String) -> void: _apply_texts())
	_apply_texts()
	_play.grab_focus()


func _make_button(parent: Control, callback: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 58)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(callback)
	UiStyle.style_button(b)
	parent.add_child(b)
	return b


func _apply_texts() -> void:
	_title.text = tr("АНТРАКТ")
	_subtitle.text = tr("Атмосферный кооперативный паззл-платформер")
	_play.text = tr("Играть")
	_settings_button.text = tr("Настройки")
	_quit.text = tr("Выход")


func _on_play() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings() -> void:
	_menu_box.visible = false
	_settings.open()


func _on_settings_closed() -> void:
	_settings.visible = false
	_menu_box.visible = true
	_settings_button.grab_focus()


func _on_quit() -> void:
	get_tree().quit()
