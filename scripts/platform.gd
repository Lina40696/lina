@tool
extends StaticBody2D
# ПЛАТФОРМА: по ней ходят герои. Прямоугольник, размер меняется в Inspector (поле Size).
#
# ВАЖНО: позиция платформы (Position) это её ЛЕВЫЙ ВЕРХНИЙ угол.
# Значит, Position.y = высота верхней грани, по которой ходят. Ось Y идёт ВНИЗ.

@export var size: Vector2 = Vector2(200, 40):
	set(value):
		size = value
		_update()
@export var color: Color = Color(0.45, 0.4, 0.37):
	set(value):
		color = value
		queue_redraw()

var _shape: CollisionShape2D


func _ready() -> void:
	_update()


func _update() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	var rect := RectangleShape2D.new()       # у каждой платформы своя форма, поэтому размеры не путаются
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
	queue_redraw()


# Временная картинка: цветной прямоугольник. Позже заменишь на свой спрайт или плитки.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color, true)
