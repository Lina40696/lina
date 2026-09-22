@tool
extends Area2D
# ПЕРСОНАЖ ДЛЯ РАЗГОВОРА (или табличка с текстом). Position = точка, где он стоит.
#
# Когда герой (или оба, смотри поле Who) подходит близко, над головой появляется значок «…».
# Нажми E — откроется окно с текстом (Lines, по одной фразе за раз). Ctrl+Enter в поле Lines
# в Inspector добавляет новую строку — так получается диалог из нескольких реплик.
# Пока открыт диалог, герои стоят на месте.

enum Who { BOTH, LEV, MIRA }

@export var lines: PackedStringArray = ["..."]           # реплики по одной за раз
@export var speaker_name: String = ""                    # имя над текстом, можно оставить пустым
@export var who: Who = Who.BOTH                           # кто может заговорить с этим персонажем
@export var radius: float = 60.0                          # на каком расстоянии срабатывает подсказка
@export var repeatable: bool = true                       # false = можно поговорить только один раз
@export var color: Color = Color(0.8, 0.6, 0.9)            # цвет силуэта-заготовки

var used: bool = false
var _in_range: bool = false
var _dialogue: Node = null

var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("npcs")
	collision_layer = 0
	collision_mask = 6           # замечает слои обоих героев (2 и 4), фильтр по Who — в коде
	_update_shape()
	if not Engine.is_editor_hint():
		_dialogue = get_tree().get_first_node_in_group("dialogue_ui")
	set_process(not Engine.is_editor_hint())
	queue_redraw()


func _update_shape() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	var circle := CircleShape2D.new()
	circle.radius = radius
	_shape.shape = circle


func _process(_delta: float) -> void:
	_in_range = _hero_in_range()
	if _in_range and (repeatable or not used) and Input.is_action_just_pressed("interact"):
		if _dialogue != null and _dialogue.say(lines, tr(speaker_name) if speaker_name != "" else ""):
			used = true
	queue_redraw()


func _hero_in_range() -> bool:
	for body in get_overlapping_bodies():
		if who == Who.LEV and not body.is_in_group("lev"):
			continue
		if who == Who.MIRA and not body.is_in_group("mira"):
			continue
		if body.is_in_group("lev") or body.is_in_group("mira"):
			return true
	return false


# Временная картинка: силуэт-«кегля» + подсказка над головой, когда герой рядом.
func _draw() -> void:
	draw_circle(Vector2(0, -34), 12.0, color)                                   # голова
	draw_rect(Rect2(-10, -22, 20, 34), color, true)                              # тело
	if not Engine.is_editor_hint() and _in_range and (repeatable or not used):
		var bob := 4.0 * sin(Time.get_ticks_msec() * 0.006)
		var pos := Vector2(0, -60 + bob)
		draw_circle(pos, 11.0, Color(1, 1, 1, 0.9))
		var font := ThemeDB.fallback_font
		draw_string(font, pos + Vector2(-4, 5), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.1, 0.1))
	elif Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.08))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.4), 1.0)
