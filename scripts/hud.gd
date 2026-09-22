extends CanvasLayer
# Простой интерфейс: «Свет Миры», состояние троса Льва и обмена, подсказки, сообщения.
# Все надписи идут через tr() (перевод) и подсказки берут настоящие клавиши из Inputs.

var lev: Node = null
var mira: Node = null
var status_text: String = ""      # например, «Управляешь: Лев (Tab: переключить)»

var _message: String = ""
var _message_left: float = 0.0
var _panel: Control


func _ready() -> void:
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_on_draw)
	add_child(_panel)


func show_message(text: String, seconds: float = 2.0) -> void:
	_message = text
	_message_left = seconds


func _process(delta: float) -> void:
	_message_left = max(_message_left - delta, 0.0)
	_panel.queue_redraw()


# Все тексты интерфейса в одном месте (так их легко проверять тестами).
func get_texts() -> Dictionary:
	var t := {}
	t.rope = tr("Трос: свободен")
	if lev.anchor != null:
		t.rope = tr("Трос: на крюке") if lev.anchor.kind == 1 else tr("Трос: на опоре")
	t.dash = tr("Рывок: готов") if lev.dash_cooldown_left <= 0.0 else tr("Рывок: %.1f c") % lev.dash_cooldown_left
	t.light = tr("Свет Миры")
	t.swap = tr("Обмен: готов") if mira.swap_left <= 0.0 else tr("Обмен: %.1f c") % mira.swap_left
	t.esc = tr("Esc: меню")
	var k := func(b: String) -> String: return Inputs.key_name(b)
	t.lev_help = tr("Лев: %s/%s бег, %s прыжок (двойной, от стены), %s рывок, %s бросить трос, %s отпустить (на крюке: %s/%s раскачка)") % [
		k.call("move_left"), k.call("move_right"), k.call("jump"), k.call("dash"),
		k.call("throw"), k.call("release"), k.call("move_left"), k.call("move_right")]
	t.mira_help = tr("Мира: %s/%s бег, %s прыжок, %s фонарь, %s обмен с Львом; мышь: ЛКМ рисовать в рамке, ПКМ стереть") % [
		k.call("move_left"), k.call("move_right"), k.call("jump"), k.call("light"), k.call("swap")]
	t.status = status_text
	return t


func _on_draw() -> void:
	if lev == null or mira == null:
		return
	var font := ThemeDB.fallback_font
	var screen := get_viewport().get_visible_rect().size
	var t := get_texts()

	_panel.draw_string(font, Vector2(20, 34), t.rope, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.8, 1.0))
	_panel.draw_string(font, Vector2(20, 58), t.dash, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.75, 0.65))

	_bar(font, Vector2(screen.x - 220, 34), t.light, mira.light / mira.light_max, Color(1.0, 0.85, 0.4))
	_panel.draw_string(font, Vector2(screen.x - 220, 66), t.swap, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 1.0, 0.9))

	if t.status != "":
		_panel.draw_string(font, Vector2(0, 30), t.status, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16)

	_panel.draw_string(font, Vector2(20, screen.y - 44), t.lev_help,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
	_panel.draw_string(font, Vector2(20, screen.y - 22), t.mira_help,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
	_panel.draw_string(font, Vector2(0, screen.y - 22), t.esc,
		HORIZONTAL_ALIGNMENT_RIGHT, screen.x - 20, 14, Color(1, 1, 1, 0.45))

	if _message_left > 0.0:
		_panel.draw_string(font, Vector2(0, screen.y * 0.4), _message,
			HORIZONTAL_ALIGNMENT_CENTER, screen.x, 40)


func _bar(font: Font, pos: Vector2, label: String, ratio: float, color: Color) -> void:
	_panel.draw_string(font, pos + Vector2(0, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	_panel.draw_rect(Rect2(pos, Vector2(200, 10)), Color(0, 0, 0, 0.5))
	_panel.draw_rect(Rect2(pos, Vector2(200.0 * clamp(ratio, 0.0, 1.0), 10)), color)
