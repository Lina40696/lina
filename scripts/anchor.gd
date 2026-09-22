@tool
extends Node2D
# Точка, за которую Лев может зацепить трос. У неё есть тип (kind):
#
#   POST - опора: трос просто держит закреплённое (например, нарисованный мост)
#   HOOK - крюк над головой: за него можно ЗАЦЕПИТЬСЯ и раскачиваться

enum Kind { POST, HOOK }

@export var kind: Kind = Kind.POST:
	set(value):
		kind = value
		queue_redraw()

var attached: bool = false    # true, пока к якорю привязан трос Льва
var hinted: bool = false      # true, если Лев сейчас нацелен на этот якорь


func _ready() -> void:
	add_to_group("anchors")
	queue_redraw()


func set_attached(value: bool) -> void:
	attached = value
	queue_redraw()


func set_hinted(value: bool) -> void:
	hinted = value
	queue_redraw()


# Временные картинки. Позже заменишь своими спрайтами.
func _draw() -> void:
	var base := Color(0.35, 0.69, 1.0)
	if kind == Kind.HOOK:
		base = Color(0.85, 0.85, 0.9)
		draw_line(Vector2(0, -10), Vector2(0, -70), Color(0.6, 0.6, 0.65), 3.0)
	var color := base if attached else Color(base.r, base.g, base.b, 0.7)
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 24, color, 3.0)
	if hinted:
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 2.0)
