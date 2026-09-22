@tool
extends Node2D
# КВАДРАТ ДЛЯ РИСОВАНИЯ. Мира может рисовать мышкой только внутри таких квадратов.
#
# - Пока Мира рядом (reach), рамка загорается.
# - Зажми левую кнопку мыши и веди линию внутри рамки: линия станет твёрдой, по ней можно ходить.
# - Правая кнопка мыши стирает все линии в квадрате.
# - Линия «нестабильна»: исчезает через life_time секунд. НО если Лев держит трос на
#   якоре, привязанном к этому квадрату (anchor_path), линия держится, пока трос натянут.
# - Всего в квадрате можно нарисовать max_ink пикселей длины.

@export var size: Vector2 = Vector2(300, 200):   # размер квадрата; позиция узла = его ЛЕВЫЙ ВЕРХНИЙ угол
	set(value):
		size = value
		queue_redraw()
@export var anchor_path: NodePath               # якорь Льва, который «страхует» рисунок
@export var reach: float = 350.0                # как близко должна быть Мира, чтобы рисовать
@export var max_ink: float = 700.0              # сколько пикселей линии можно нарисовать
@export var life_time: float = 5.0              # сколько живёт линия без страховки
@export var thickness: float = 14.0             # толщина линии (и её твёрдой части)
@export var min_point_dist: float = 10.0        # расстояние между точками линии

var linked_anchor: Node = null
var active: bool = false                        # Мира в зоне досягаемости

var _strokes: Array = []                        # готовые линии: {line, body, length, age}
var _cur_line: Line2D = null                    # линия, которую сейчас рисуют
var _cur_points: PackedVector2Array = PackedVector2Array()
var _cur_length: float = 0.0
var _full: bool = false                         # чернила кончились посреди линии
var _was_active: bool = false


func _ready() -> void:
	add_to_group("draw_zones")
	queue_redraw()
	if Engine.is_editor_hint():
		return
	if linked_anchor == null and anchor_path != NodePath(""):
		linked_anchor = get_node_or_null(anchor_path)


# ---------- Что вызывает Мира ----------

func rect_global() -> Rect2:
	return Rect2(global_position, size)


func contains(point: Vector2) -> bool:
	return rect_global().has_point(point)


func is_reachable_by(node: Node2D) -> bool:
	var r := rect_global()
	var p := node.global_position
	var nearest := Vector2(clamp(p.x, r.position.x, r.end.x), clamp(p.y, r.position.y, r.end.y))
	return p.distance_to(nearest) <= reach


func ink_used() -> float:
	var total := _cur_length
	for s in _strokes:
		total += s.length
	return total


func stroke_full() -> bool:
	return _full


func is_drawing() -> bool:
	return _cur_line != null


func begin_stroke(point: Vector2) -> bool:
	if _cur_line != null or not contains(point) or ink_used() >= max_ink:
		return false
	_full = false
	_cur_points = PackedVector2Array([to_local(point)])
	_cur_length = 0.0
	_cur_line = _make_line()
	_cur_line.add_point(to_local(point))
	return true


# Продлевает линию до точки. affordable_px = сколько пикселей Мира ещё может оплатить светом.
# Возвращает, сколько пикселей реально добавлено.
func try_extend(point: Vector2, affordable_px: float) -> float:
	if _cur_line == null or not contains(point):
		return 0.0
	var last := _cur_points[_cur_points.size() - 1]
	var target := to_local(point)
	var dist := target.distance_to(last)
	if dist < min_point_dist:
		return 0.0
	var allowed := minf(affordable_px, max_ink - ink_used())
	if allowed < 1.0:
		_full = true
		return 0.0
	if dist > allowed:
		target = last + (target - last).normalized() * allowed
		dist = allowed
		_full = true
	_cur_points.append(target)
	_cur_line.add_point(target)
	_cur_length += dist
	return dist


func end_stroke() -> void:
	if _cur_line == null:
		return
	if _cur_points.size() >= 2:
		_strokes.append({
			"line": _cur_line,
			"body": _make_body(_cur_points),
			"length": _cur_length,
			"age": 0.0,
		})
	else:
		_cur_line.queue_free()
	_cur_line = null
	_cur_points = PackedVector2Array()
	_cur_length = 0.0
	_full = false


# Стирает все линии. Возвращает, сколько пикселей линии стёрто (чтобы вернуть часть света).
func erase_all() -> float:
	var total := 0.0
	for s in _strokes:
		total += s.length
		_free_stroke(s)
	_strokes.clear()
	return total


# ---------- Внутренняя кухня ----------

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Рамка горит, пока Мира рядом
	var mira := get_tree().get_first_node_in_group("mira")
	active = mira != null and mira.input_enabled and is_reachable_by(mira)
	if active != _was_active:
		_was_active = active
		queue_redraw()

	# Жизнь линий: под страховкой Льва не стареют
	var held: bool = linked_anchor != null and linked_anchor.attached
	for s in _strokes.duplicate():
		if held:
			s.age = 0.0
		else:
			s.age += delta
		if s.age >= life_time:
			_free_stroke(s)
			_strokes.erase(s)
			continue
		var alpha := clampf((life_time - s.age) / 1.5, 0.25, 1.0)
		var col := Color(0.35, 0.69, 1.0, alpha) if held else Color(1.0, 0.88, 0.54, alpha)
		s.line.default_color = col


func _make_line() -> Line2D:
	var line := Line2D.new()
	line.width = thickness
	line.default_color = Color(1.0, 0.95, 0.75, 0.6)   # пока рисуем, линия полупрозрачная
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(line)
	return line


# Твёрдая часть линии: цепочка капсул вдоль каждого отрезка.
func _make_body(points: PackedVector2Array) -> StaticBody2D:
	var body := StaticBody2D.new()
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var seg := b - a
		var capsule := CapsuleShape2D.new()
		capsule.radius = thickness / 2.0
		capsule.height = seg.length() + thickness
		var shape := CollisionShape2D.new()
		shape.shape = capsule
		shape.position = (a + b) / 2.0
		shape.rotation = seg.angle() - PI / 2.0
		body.add_child(shape)
	add_child(body)
	return body


func _free_stroke(s: Dictionary) -> void:
	if is_instance_valid(s.line):
		s.line.queue_free()
	if is_instance_valid(s.body):
		s.body.queue_free()


# Временная рамка. Заменишь на свою рисованную. В редакторе рамка всегда яркая, чтобы её было видно.
func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var lit := active or Engine.is_editor_hint()
	var a := 0.95 if lit else 0.35
	draw_rect(rect, Color(1.0, 0.88, 0.54, 0.10 if lit else 0.03), true)
	draw_rect(rect, Color(1.0, 0.88, 0.54, a), false, 2.0)
	var c := 18.0
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var sx := 1.0 if corner.x <= rect.position.x else -1.0
		var sy := 1.0 if corner.y <= rect.position.y else -1.0
		draw_line(corner, corner + Vector2(c * sx, 0), Color(1, 1, 1, a), 3.0)
		draw_line(corner, corner + Vector2(0, c * sy), Color(1, 1, 1, a), 3.0)
