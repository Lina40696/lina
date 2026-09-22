@tool
extends Area2D
# Сфера света. Собрать её может только Мира: она пополняет ей «Свет».
# Лев проходит сквозь сферу.

@export var amount: float = 25.0          # сколько света даёт
@export var respawn_time: float = 0.0     # через сколько секунд появится снова (0 = не появится)
@export var radius: float = 24.0

var collected: bool = false
var _light: PointLight2D


func _ready() -> void:
	add_to_group("light_orbs")
	collision_layer = 0
	collision_mask = 4       # замечает только слой Миры: Лев сферу физически не задевает
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	_light = PointLight2D.new()
	_light.texture = preload("res://scripts/light_util.gd").make_light_texture()
	_light.texture_scale = 0.35
	add_child(_light)
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(_delta: float) -> void:
	if not collected and not Engine.is_editor_hint():
		queue_redraw()


func _on_body_entered(body: Node) -> void:
	if collected or not body.is_in_group("mira"):
		return
	body.add_light(amount)
	_set_collected(true)
	if respawn_time > 0.0:
		await get_tree().create_timer(respawn_time).timeout
		if is_inside_tree():
			_set_collected(false)


func _set_collected(value: bool) -> void:
	collected = value
	visible = not value
	_light.enabled = not value
	set_deferred("monitoring", not value)


# Временная картинка: пульсирующая жёлтая сфера. Заменишь своим спрайтом.
func _draw() -> void:
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.006)
	draw_circle(Vector2.ZERO, 10.0 * pulse, Color(1.0, 0.9, 0.5))
	draw_arc(Vector2.ZERO, 15.0 * pulse, 0.0, TAU, 24, Color(1.0, 0.85, 0.4, 0.6), 2.0)
