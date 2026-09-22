extends CharacterBody2D
# Общая основа для Льва и Миры: бег, прыжок, гравитация.
# Способности каждого героя лежат в lev.gd и mira.gd, они «наследуют» этот файл.

@export var player_id: int = 1            # 1 = Лев, 2 = Мира
@export var move_speed: float = 210.0     # скорость бега, пикселей в секунду
@export var acceleration: float = 1500.0  # как быстро набирает скорость
@export var friction: float = 1800.0      # как быстро тормозит
@export var jump_speed: float = 480.0     # сила прыжка
@export var gravity: float = 1300.0
@export var max_fall_speed: float = 900.0
@export var coyote_time: float = 0.1      # можно прыгнуть сразу после схода с края
@export var jump_buffer_time: float = 0.1 # прыжок «запоминается», если нажат чуть раньше приземления
@export var max_air_jumps: int = 0        # сколько прыжков в воздухе (1 = двойной прыжок)
@export var step_height: float = 16.0     # на какую ступеньку герой поднимается сам, без прыжка

# Акробатика: у каждого героя включается флагами (сейчас всё это умеет только Лев).
@export var can_dash: bool = false
@export var can_wall_jump: bool = false
@export var dash_speed: float = 520.0
@export var dash_time: float = 0.16
@export var dash_cooldown: float = 0.5
@export var wall_slide_speed: float = 90.0   # скорость скольжения по стене
@export var wall_jump_push: float = 200.0    # как сильно отскакивает от стены
@export var wall_jump_speed: float = 470.0   # высота прыжка от стены
@export var wall_coyote: float = 0.12        # можно оттолкнуться сразу после касания стены
@export var wall_lock_time: float = 0.12     # столько стрелки не работают после отскока

var facing: int = 1                       # 1 = смотрит вправо, -1 = влево
var input_enabled: bool = true            # false = герой стоит и ждёт (для соло-режима)
var control_lock: float = 0.0             # пока > 0, стрелки не управляют (после прыжка от стены)
var jump_consumed: bool = false           # нажатие прыжка уже потрачено на что-то другое

var dash_cooldown_left: float = 0.0

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _air_jumps_left: int = 0
var _dash_left: float = 0.0
var _dash_dir: int = 1
var _dash_ready: bool = true
var _wall_coyote_left: float = 0.0
var _wall_normal_x: float = 0.0


# Вспомогательные функции: превращают «jump» в «p1_jump» или «p2_jump».
func action(action_name: String) -> String:
	return "p%d_%s" % [player_id, action_name]


func pressed(action_name: String) -> bool:
	return input_enabled and Input.is_action_pressed(action(action_name))


func just_pressed(action_name: String) -> bool:
	return input_enabled and Input.is_action_just_pressed(action(action_name))


# Позиция «ног» героя: нужна, чтобы при обмене местами встать ровно на землю.
func get_feet() -> Vector2:
	return global_position + Vector2(0, _half_height())


func teleport_feet(feet: Vector2) -> void:
	global_position = feet - Vector2(0, _half_height())
	velocity = Vector2.ZERO


func _half_height() -> float:
	var cs := get_node_or_null("CollisionShape2D")
	if cs and cs.shape is RectangleShape2D:
		return cs.shape.size.y / 2.0
	return 0.0


func reset_air_jumps() -> void:
	_air_jumps_left = max_air_jumps


func _physics_process(delta: float) -> void:
	_move(delta)
	_update_abilities(delta)
	_extra(delta)


# Сюда потомки (Лев, Мира) вставляют свои способности после движения.
func _extra(_delta: float) -> void:
	pass


# Вызывается прямо перед move_and_slide(): потомки могут поправить скорость (скольжение по стене).
func _pre_slide(_delta: float) -> void:
	# Скольжение по стене: если прижимаешься к ней в падении, падаешь медленно.
	if not can_wall_jump or is_on_floor() or _wall_coyote_left <= 0.0 or velocity.y <= wall_slide_speed:
		return
	var dir := 0.0
	if input_enabled:
		dir = Input.get_axis(action("left"), action("right"))
	if dir != 0.0 and signf(dir) == -signf(_wall_normal_x):
		velocity.y = wall_slide_speed


func _apply_facing() -> void:
	var body := get_node_or_null("Body")
	if body:
		body.scale.x = facing


func _move(delta: float) -> void:
	dash_cooldown_left = max(dash_cooldown_left - delta, 0.0)
	if can_dash:
		_try_dash()
	if _dash_left > 0.0:
		_dash_move(delta)
		return
	if can_wall_jump:
		_try_wall_jump()
	_walk(delta)


# Обычное движение: гравитация, бег, прыжки.
func _walk(delta: float) -> void:
	# Гравитация
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)

	# Горизонтальное движение
	control_lock = max(control_lock - delta, 0.0)
	var dir := 0.0
	if input_enabled and control_lock <= 0.0:
		dir = Input.get_axis(action("left"), action("right"))
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * move_speed, acceleration * delta)
		facing = 1 if dir > 0.0 else -1
	elif control_lock <= 0.0:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Прыжок: coyote time + буфер нажатия + прыжки в воздухе
	if is_on_floor():
		_coyote = coyote_time
		_air_jumps_left = max_air_jumps
	else:
		_coyote = max(_coyote - delta, 0.0)
	_jump_buffer = max(_jump_buffer - delta, 0.0)
	var jump_now := just_pressed("jump") and not jump_consumed
	if jump_now:
		_jump_buffer = jump_buffer_time

	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = -jump_speed
		_jump_buffer = 0.0
		_coyote = 0.0
	elif jump_now and _air_jumps_left > 0 and not is_on_floor():
		velocity.y = -jump_speed
		_jump_buffer = 0.0
		_air_jumps_left -= 1

	# Отпустил кнопку прыжка раньше времени = прыжок ниже
	if velocity.y < -jump_speed * 0.4 and not pressed("jump"):
		velocity.y = -jump_speed * 0.4

	_pre_slide(delta)
	if is_on_floor() and absf(velocity.x) > 1.0 and step_height > 0.0:
		_try_step_up(signf(velocity.x))
	move_and_slide()
	_apply_facing()
	jump_consumed = false


# Если впереди небольшая ступенька (край нарисованной линии, бордюр), герой сам на неё поднимается.
func _try_step_up(dir: float) -> void:
	var forward := Vector2(dir * 3.0, 0.0)
	if not test_move(global_transform, forward):
		return
	var rise := 2.0
	while rise <= step_height:
		var up := Vector2(0.0, -rise)
		if test_move(global_transform, up):
			return                                   # над головой потолок
		if not test_move(global_transform.translated(up), forward):
			global_position.y -= rise
			return
		rise += 2.0


# ---------- Акробатика: рывок и прыжок от стены ----------

func _try_dash() -> void:
	if not just_pressed("dash") or not _dash_ready or dash_cooldown_left > 0.0:
		return
	var dir := Input.get_axis(action("left"), action("right"))
	_dash_dir = facing if is_zero_approx(dir) else (1 if dir > 0.0 else -1)
	facing = _dash_dir
	_dash_left = dash_time
	dash_cooldown_left = dash_cooldown
	_dash_ready = false


func _dash_move(delta: float) -> void:
	velocity = Vector2(_dash_dir * dash_speed, 0.0)
	move_and_slide()
	_apply_facing()
	_dash_left -= delta
	if _dash_left <= 0.0:
		velocity.x = _dash_dir * move_speed


func _try_wall_jump() -> void:
	if is_on_floor() or _wall_coyote_left <= 0.0 or not just_pressed("jump"):
		return
	velocity = Vector2(_wall_normal_x * wall_jump_push, -wall_jump_speed)
	control_lock = wall_lock_time
	facing = 1 if _wall_normal_x > 0.0 else -1
	_wall_coyote_left = 0.0
	jump_consumed = true


# Каждый кадр после движения: контакт со стеной, восстановление рывка и прыжка в воздухе.
func _update_abilities(delta: float) -> void:
	if can_wall_jump and is_on_wall() and not is_on_floor():
		_wall_normal_x = get_wall_normal().x
		_wall_coyote_left = wall_coyote
		reset_air_jumps()
		_dash_ready = true
	else:
		_wall_coyote_left = max(_wall_coyote_left - delta, 0.0)
	if is_on_floor():
		_dash_ready = true
