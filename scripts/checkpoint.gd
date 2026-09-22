@tool
extends Node2D
# КОНТРОЛЬНАЯ ТОЧКА: когда оба героя правее неё (по x) и стоят на земле, после «Антракта»
# они возвращаются сюда. Position = где встанет Мира (центр героя). Лев встаёт правее на lev_offset.
# В редакторе видны две точки: голубая (Мира) и оранжевая (Лев).

@export var lev_offset: Vector2 = Vector2(60, 0):
	set(value):
		lev_offset = value
		queue_redraw()


func _ready() -> void:
	add_to_group("checkpoints")
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_line(Vector2(0, -300), Vector2(0, 300), Color(1, 1, 1, 0.25), 2.0)
	draw_circle(Vector2.ZERO, 7.0, Color(0.6, 0.8, 1.0))
	draw_circle(lev_offset, 7.0, Color(1.0, 0.6, 0.5))
