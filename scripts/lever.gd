@tool
extends Area2D
# РЫЧАГ: объект для взаимодействия (не для разговора). Герой подходит и жмёт E —
# рычаг включает/выключает другой кубик (например, платформу-«ворота»): она то появляется
# и держит вес, то исчезает и сквозь неё можно пройти.
#
# Как связать: поставь рычаг рядом с платформой (или любым другим кубиком), выбери рычаг,
# в Inspector найди поле Target (Assign…) и укажи ту платформу.

enum Who { BOTH, LEV, MIRA }

@export var target_path: NodePath                         # кубик, который рычаг включает/выключает
@export var who: Who = Who.BOTH                             # кто может пользоваться рычагом
@export var radius: float = 50.0                            # дальность действия
@export var start_on: bool = true                            # состояние цели в начале уровня
@export var one_shot: bool = false                           # true = сработает только один раз, дальше не трогать
@export var message_on: String = "Открыто"
@export var message_off: String = "Закрыто"
@export var color: Color = Color(0.75, 0.75, 0.8)

var on: bool = true
var used: bool = false
var _in_range: bool = false
var _target: Node = null
var _hud: Node = null


func _ready() -> void:
	add_to_group("levers")
	collision_layer = 0
	collision_mask = 6            # замечает слои обоих героев (2 и 4), фильтр по Who — в коде
	_update_shape()
	on = start_on
	if not Engine.is_editor_hint():
		_target = get_node_or_null(target_path)
		_hud = get_tree().get_first_node_in_group("hud")
		_apply()
	set_process(not Engine.is_editor_hint())
	queue_redraw()


func _update_shape() -> void:
	if not is_inside_tree():
		return
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		shape = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		add_child(shape)
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle


func _process(_delta: float) -> void:
	_in_range = _hero_in_range()
	if _in_range and not (one_shot and used) and Input.is_action_just_pressed("interact"):
		on = not on
		used = true
		_apply()
		if _hud != null:
			_hud.show_message(tr(message_on) if on else tr(message_off), 1.2)
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


# Включает/выключает цель: прячет и отключает её столкновение, если Target — физический кубик.
func _apply() -> void:
	if _target == null:
		return
	_target.visible = on
	var shape := _target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.set_deferred("disabled", not on)
	elif _target is CollisionObject2D:
		_target.set_deferred("monitoring", on)


# Временная картинка: столбик с рукоятью, поворачивается по состоянию on/off.
func _draw() -> void:
	draw_rect(Rect2(-4, -20, 8, 26), Color(0.4, 0.38, 0.42), true)
	var angle := -0.6 if on else 0.6
	var tip := Vector2(0, -20) + Vector2.UP.rotated(angle) * 22.0
	draw_line(Vector2(0, -20), tip, color, 4.0)
	draw_circle(tip, 5.0, color)
	if not Engine.is_editor_hint() and _in_range and not (one_shot and used):
		var bob := 4.0 * sin(Time.get_ticks_msec() * 0.006)
		var pos := Vector2(0, -56 + bob)
		draw_circle(pos, 11.0, Color(1, 1, 1, 0.9))
		var font := ThemeDB.fallback_font
		draw_string(font, pos + Vector2(-4, 5), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.1, 0.1))
	elif Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.3), 1.0)
