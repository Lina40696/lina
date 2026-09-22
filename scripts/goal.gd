@tool
extends Area2D
# ЗОНА ВЫХОДА: комната пройдена, когда ОБА героя стоят внутри.
# Position = левый верхний угол зоны, размер меняется в Inspector (поле Size).
#
# ПЕРЕХОД МЕЖДУ УРОВНЯМИ: если заполнить поле Next Level (внизу в Inspector), то вместо
# простой надписи комната загрузит указанный файл уровня — экран притемнится и откроется
# следующая комната. Если поле пустое, зона работает как раньше: просто «Комната пройдена».
# В новой комнате герои появятся на её собственных SpawnLev/SpawnMira — отдельно ставить
# ничего не нужно.

@export var size: Vector2 = Vector2(120, 140):
	set(value):
		size = value
		_update()
@export_file("*.tscn") var next_level: String = ""    # путь к следующему уровню, например res://scenes/levels/komnata_2.tscn
@export var message: String = ""                       # свой текст вместо «Комната пройдена» (необязательно)

var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("goals")
	collision_layer = 0
	collision_mask = 6          # замечает слои обоих героев (2 и 4)
	_update()


func _update() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
	queue_redraw()


func _draw() -> void:
	# Зелёная = обычный выход (конец показа). Золотая = ведёт на следующий уровень.
	var tint := Color(1.0, 0.85, 0.4) if next_level != "" else Color(0.4, 1.0, 0.6)
	draw_rect(Rect2(Vector2.ZERO, size), Color(tint.r, tint.g, tint.b, 0.10), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(tint.r, tint.g, tint.b, 0.7), false, 2.0)
