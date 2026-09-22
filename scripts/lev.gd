extends "res://scripts/actor.gd"
# ЛЕВ, «Точный расчёт»: закидывает трос на якорь. За высокие крюки может цепляться и раскачиваться.
#
# Кнопки (клавиатура): F = бросить трос на ближайший якорь, G = отпустить.
#
# Как работает качание:
#   1. Подойди к крюку (HOOK) и нажми F. Нужный якорь подсвечивается белым кольцом.
#   2. Разбегись и прыгни: в воздухе Лев повисает на тросе и качается как маятник.
#   3. Стрелки влево/вправо раскачивают сильнее.
#   4. Прыжок или G в воздухе = отпустить трос и полететь дальше по инерции.
# Стамины у троса нет: висеть можно сколько угодно.
#
# АКРОБАТИКА (Лев акробат): двойной прыжок, рывок (Shift), прыжок от стены. Общий код лежит
# в actor.gd, а Льву эти умения включены флагами can_dash и can_wall_jump.

signal rope_attached(anchor)
signal rope_released

const AnchorScript := preload("res://scripts/anchor.gd")

@export var rope_range: float = 420.0        # как далеко можно бросить трос
@export var rope_max_length: float = 470.0   # дальше этой длины трос обрывается (отпускается)
@export var swing_pump: float = 650.0        # сила раскачивания стрелками
@export var swing_max_speed: float = 800.0   # предел скорости на качелях
@export var swing_damping: float = 0.15      # затухание: 0 = качается вечно
@export var release_boost: float = 120.0     # подскок при отпускании прыжком

var anchor: Node2D = null                    # к какому якорю сейчас привязан (или null)
var rope_length: float = 0.0                 # длина троса (фиксируется, когда Лев отрывается от земли)

var _rope_line: Line2D
var _hinted: Node2D = null


func _ready() -> void:
	player_id = 1
	add_to_group("lev")
	collision_layer = 2      # Лев на слое 2, видит только мир (слой 1): с Мирой не сталкивается
	collision_mask = 1
	max_air_jumps = 1        # двойной прыжок
	can_dash = true          # рывок (Shift)
	can_wall_jump = true     # скольжение по стене и прыжок от стены
	# Линия-верёвка. top_level = true, чтобы точки задавались в мировых координатах.
	_rope_line = Line2D.new()
	_rope_line.top_level = true
	_rope_line.width = 3.0
	_rope_line.default_color = Color(0.35, 0.69, 1.0)
	_rope_line.visible = false
	add_child(_rope_line)


# Подменяем обычное движение на «качание», когда Лев висит на крюке в воздухе.
func _move(delta: float) -> void:
	if _is_swinging():
		_swing_move(delta)
	else:
		super._move(delta)


func _extra(_delta: float) -> void:
	if just_pressed("throw"):
		throw_rope()
	if just_pressed("release"):
		release_rope()
	if anchor != null:
		_update_rope()
	_update_hint()


func _is_swinging() -> bool:
	return anchor != null and anchor.kind == AnchorScript.Kind.HOOK and not is_on_floor()


func _swing_move(delta: float) -> void:
	velocity.y = min(velocity.y + gravity * delta, max_fall_speed)

	# Раскачка стрелками
	var dir := 0.0
	if input_enabled:
		dir = Input.get_axis(action("left"), action("right"))
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
		# Разгоняем только когда Лев уже движется в ту же сторону, как на настоящих качелях:
		# держи направление, куда летишь, и размах растёт.
		if velocity.x * dir > 0.0 or absf(velocity.x) < 40.0:
			velocity.x += dir * swing_pump * delta
	velocity *= (1.0 - swing_damping * delta)
	velocity = velocity.limit_length(swing_max_speed)

	# Прыжок в воздухе = отпустить трос и лететь дальше
	if just_pressed("jump"):
		velocity.y -= release_boost
		release_rope()
		move_and_slide()
		return

	move_and_slide()
	_apply_rope_constraint()

	_apply_facing()


# Трос не даёт отлететь дальше своей длины: как настоящий маятник.
func _apply_rope_constraint() -> void:
	if anchor == null:
		return
	var offset := global_position - anchor.global_position
	var dist := offset.length()
	if dist > rope_length and dist > 0.01:
		var n := offset / dist
		move_and_collide(-n * (dist - rope_length))
		var radial := velocity.dot(n)
		if radial > 0.0:
			velocity -= n * radial


func throw_rope() -> void:
	if anchor != null:
		return
	var target := _find_anchor()
	if target == null:
		return
	anchor = target
	anchor.set_attached(true)
	rope_length = clamp((global_position - anchor.global_position).length(), 30.0, rope_max_length)
	_rope_line.visible = true
	rope_attached.emit(anchor)


func release_rope() -> void:
	if anchor == null:
		return
	anchor.set_attached(false)
	anchor = null
	_rope_line.visible = false
	rope_released.emit()


func _update_rope() -> void:
	var dist := (global_position - anchor.global_position).length()
	# Слишком далеко: трос обрывается (отпускается)
	if dist > rope_max_length:
		release_rope()
		return
	# Пока Лев стоит на земле, трос свободный, а длина запоминает расстояние
	if is_on_floor():
		rope_length = dist
	_rope_line.points = PackedVector2Array([
		global_position + Vector2(0, -10), anchor.global_position])


# Выбираем якорь: ближайший в пределах дальности, якоря «за спиной» получают штраф.
func _find_anchor() -> Node2D:
	var best: Node2D = null
	var best_score := INF
	for a in get_tree().get_nodes_in_group("anchors"):
		var to_anchor: Vector2 = a.global_position - global_position
		var dist := to_anchor.length()
		if dist > rope_range:
			continue
		var score := dist
		if to_anchor.x * facing < 0.0:
			score += 300.0
		if score < best_score:
			best_score = score
			best = a
	return best


# Подсвечиваем якорь, на который Лев сейчас нацелен.
func _update_hint() -> void:
	var want: Node2D = null
	if anchor == null and input_enabled:
		want = _find_anchor()
	if want != _hinted:
		if _hinted != null and is_instance_valid(_hinted):
			_hinted.set_hinted(false)
		_hinted = want
		if _hinted != null:
			_hinted.set_hinted(true)
