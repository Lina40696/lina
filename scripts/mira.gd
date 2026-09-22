extends "res://scripts/actor.gd"
# МИРА, «Сценический обман»: иллюзионистка. Бегает и прыгает обычно (акробатика у Льва).
#
# РИСОВАНИЕ (только мышь, только внутри квадратов-рамок):
#   ЛКМ (держать)   - вести линию внутри рамки; линия становится твёрдой
#   ПКМ             - стереть все линии в квадрате
#
# ПРОЧЕЕ:  Q = фонарь вкл/выкл,  C = поменяться местами с Львом.
#
# «Свет» тратится на рисование и на фонарь. Пополнить его можно, только собирая сферы света.
# Сферы часто лежат там, куда Мира не достаёт. Тогда Лев забирается туда, а Мира меняется с ним местами.

signal swap_failed(reason)

@export var light_max: float = 100.0
@export var lantern_drain: float = 0.6       # расход света в секунду, пока горит фонарь
@export var ink_per_px: float = 0.08         # сколько света стоит один пиксель линии
@export var erase_refund: float = 0.5        # какую долю света вернёт стирание
@export var swap_range: float = 700.0        # на каком расстоянии от Льва работает обмен
@export var swap_cooldown: float = 1.5       # пауза между обменами, секунды

var light: float = 100.0
var lantern_on: bool = true
var swap_left: float = 0.0
var drawing: bool = false                    # прямо сейчас ведёт линию

var mouse_source: Callable = Callable()      # только для автотестов: подменяет положение мыши

var _lantern: PointLight2D
var _zone: Node = null                       # квадрат, в котором рисует
var _draw_locked: bool = false               # ждём, пока отпустят ЛКМ
var _rmb_prev: bool = false


func _ready() -> void:
	player_id = 2
	add_to_group("mira")
	collision_layer = 4      # Мира на слое 3, видит только мир (слой 1): со Львом не сталкивается
	collision_mask = 1
	light = light_max
	move_speed = 195.0      # Мира чуть медленнее Льва
	jump_speed = 450.0
	_build_lantern()


# ---------- Всё остальное, каждый кадр ----------

func _extra(delta: float) -> void:
	# Фонарь
	if just_pressed("light"):
		lantern_on = not lantern_on
	if lantern_on and light > 0.0:
		light -= lantern_drain * delta
	_lantern.enabled = lantern_on and light > 0.0
	_lantern.energy = 0.4 + 0.8 * (light / light_max)

	# Обмен местами с Львом
	swap_left = max(swap_left - delta, 0.0)
	if just_pressed("swap"):
		_try_swap()

	_handle_drawing()
	light = clamp(light, 0.0, light_max)


# Вызывается сферами света и стиранием.
func add_light(amount: float) -> void:
	light = min(light + amount, light_max)


# ---------- Рисование мышью ----------

func _handle_drawing() -> void:
	var lmb := input_enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var rmb := input_enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var mouse := _mouse_world()

	if not lmb:
		_draw_locked = false
		if drawing:
			_end_stroke()
	elif not _draw_locked:
		if not drawing:
			_begin_stroke(mouse)
		else:
			_extend_stroke(mouse)

	if rmb and not _rmb_prev:
		_erase_at(mouse)
	_rmb_prev = rmb


func _mouse_world() -> Vector2:
	if mouse_source.is_valid():
		return mouse_source.call()
	return get_global_mouse_position()


func _find_zone(point: Vector2) -> Node:
	for z in get_tree().get_nodes_in_group("draw_zones"):
		if z.contains(point) and z.is_reachable_by(self):
			return z
	return null


func _begin_stroke(point: Vector2) -> void:
	if light <= 0.0:
		return
	var zone := _find_zone(point)
	if zone != null and zone.begin_stroke(point):
		_zone = zone
		drawing = true


func _extend_stroke(point: Vector2) -> void:
	if _zone == null or not _zone.is_reachable_by(self):
		_end_stroke()
		return
	var added: float = _zone.try_extend(point, light / ink_per_px)
	light -= added * ink_per_px
	if light <= 0.0 or _zone.stroke_full():
		_end_stroke()
		_draw_locked = true     # отпусти кнопку, чтобы начать новую линию


func _end_stroke() -> void:
	if _zone != null:
		_zone.end_stroke()
	_zone = null
	drawing = false


func _erase_at(point: Vector2) -> void:
	var zone := _find_zone(point)
	if zone == null:
		return
	var length: float = zone.erase_all()
	add_light(length * ink_per_px * erase_refund)


# ---------- Обмен местами ----------

func _try_swap() -> void:
	if swap_left > 0.0:
		swap_failed.emit(tr("Обмен ещё не готов"))
		return
	var lev := get_tree().get_first_node_in_group("lev")
	if lev == null:
		return
	if not is_on_floor() or not lev.is_on_floor():
		swap_failed.emit(tr("Обмен: оба должны стоять на земле"))
		return
	if global_position.distance_to(lev.global_position) > swap_range:
		swap_failed.emit(tr("Обмен: Лев слишком далеко"))
		return
	var my_feet := get_feet()
	var lev_feet: Vector2 = lev.get_feet()
	teleport_feet(lev_feet)
	lev.teleport_feet(my_feet)
	swap_left = swap_cooldown


# Фонарь создаём кодом, чтобы не возиться с текстурами. Позже заменишь своей текстурой света.
func _build_lantern() -> void:
	_lantern = PointLight2D.new()
	_lantern.texture = preload("res://scripts/light_util.gd").make_light_texture()
	_lantern.texture_scale = 1.6
	_lantern.position = Vector2(0, -20)
	add_child(_lantern)
