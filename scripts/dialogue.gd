extends CanvasLayer
# ОКНО ДИАЛОГА. Одно на всю комнату (level.gd создаёт его сам, как hud.gd).
# Объекты для разговора (npc.gd) вызывают say(строки, имя), а это окно показывает
# текст по одной строке и ждёт нажатия клавиши «взаимодействие» (E), чтобы листать дальше.
#
# Пока идёт диалог, герои не могут двигаться (чтобы не убежать посреди фразы).

signal finished

var active: bool = false

var _lines: PackedStringArray = []
var _index: int = 0
var _speaker: String = ""
var _panel: Control
var _lev: Node = null
var _mira: Node = null
var _lev_was_enabled: bool = true
var _mira_was_enabled: bool = true


func _ready() -> void:
	add_to_group("dialogue_ui")
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_on_draw)
	add_child(_panel)


# lines: список строк (каждая — одна фраза). speaker: имя, которое покажется над текстом (можно "").
# Возвращает false и ничего не делает, если диалог уже идёт (подожди finished).
func say(lines: PackedStringArray, speaker: String = "") -> bool:
	if active or lines.is_empty():
		return false
	_lines = lines
	_index = 0
	_speaker = speaker
	active = true
	_lock_heroes(true)
	_panel.queue_redraw()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		active = false
		_lock_heroes(false)
		finished.emit()
	_panel.queue_redraw()


func _lock_heroes(lock: bool) -> void:
	if lock:
		_lev = get_tree().get_first_node_in_group("lev")
		_mira = get_tree().get_first_node_in_group("mira")
		if _lev:
			_lev_was_enabled = _lev.input_enabled
			_lev.input_enabled = false
			_lev.velocity.x = 0.0
		if _mira:
			_mira_was_enabled = _mira.input_enabled
			_mira.input_enabled = false
			_mira.velocity.x = 0.0
	else:
		if _lev:
			_lev.input_enabled = _lev_was_enabled
		if _mira:
			_mira.input_enabled = _mira_was_enabled


func _on_draw() -> void:
	if not active:
		return
	var font := ThemeDB.fallback_font
	var screen := get_viewport().get_visible_rect().size
	var box_h := 110.0
	var box := Rect2(40, screen.y - box_h - 30, screen.x - 80, box_h)

	_panel.draw_rect(box, Color(0.06, 0.05, 0.08, 0.88), true)
	_panel.draw_rect(box, Color(1, 1, 1, 0.25), false, 2.0)

	var text_pos := box.position + Vector2(20, 32)
	if _speaker != "":
		_panel.draw_string(font, box.position + Vector2(20, 22), _speaker,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.85, 0.4))
		text_pos.y += 14

	var line: String = _lines[_index] if _index < _lines.size() else ""
	_panel.draw_string(font, text_pos, line, HORIZONTAL_ALIGNMENT_LEFT,
		box.size.x - 40, 16, Color(1, 1, 1, 0.95))

	var hint := tr("%s: дальше") % Inputs.key_name("interact")
	_panel.draw_string(font, box.position + box.size - Vector2(150, 14), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.5))
