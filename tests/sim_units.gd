extends SceneTree
# Правила Льва и обмена: трос без стамины, обрыв при большой длине, обмен местами.
var f := 0
var main
var lev
var mira
var ok := true
var rel := {}

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		ok = false

func tap(a: String, at: int, frames := 2) -> void:
	if f == at:
		Input.action_press(a)
		rel[a] = f + frames

var pos_l := Vector2.ZERO
var pos_m := Vector2.ZERO
const T0 := 20

func _physics_process(_d: float) -> bool:
	f += 1
	for a in rel.keys():
		if f >= rel[a]:
			Input.action_release(a)
			rel.erase(a)
	if f == 1:
		main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		return false
	if f == 2:
		lev = main.lev
		mira = main.mira
		lev.input_enabled = true
		mira.input_enabled = true
		lev.position = Vector2(330, 330)
		mira.position = Vector2(-60, 330)
	if f == 60:
		check("Оба стоят на земле", lev.is_on_floor() and mira.is_on_floor())
		check("Герои не сталкиваются друг с другом", lev.collision_layer != mira.collision_layer)
		lev.facing = 1
	tap("p1_throw", 70)
	if f == 80:
		check("Лев нацелился на опору", lev.anchor != null and lev.anchor.kind == 0)
	if f == 80 + 600:
		check("Трос держится 10 секунд без усталости", lev.anchor != null)
		check("У Льва нет стамины (grip)", not ("grip" in lev))
		mira.swap_left = 0.0
		pos_l = lev.get_feet()
		pos_m = mira.get_feet()
	tap("p2_swap", 80 + 610)
	if f == 80 + 630:
		check("Обмен: Мира встала на место Льва", mira.get_feet().distance_to(pos_l) < 6.0)
		check("Обмен: Лев встал на место Миры", lev.get_feet().distance_to(pos_m) < 6.0)
		check("Трос оборвался: Лев оказался далеко от опоры", lev.anchor == null)
		pos_l = lev.get_feet()
	tap("p2_swap", 80 + 640)
	if f == 80 + 660:
		check("Кулдаун: повторный обмен сразу не сработал", lev.get_feet().distance_to(pos_l) < 6.0)
		mira.swap_left = 0.0
		lev.position = Vector2(300, 100)
		lev.velocity = Vector2.ZERO
		pos_m = mira.global_position
	tap("p2_swap", 80 + 662)
	if f == 80 + 680:
		check("Обмен запрещён, когда Лев в воздухе", mira.global_position.distance_to(pos_m) < 30.0)
		# Обрыв троса при слишком большом расстоянии
		lev.position = Vector2(330, 330)
		lev.velocity = Vector2.ZERO
		lev.facing = 1
	tap("p1_throw", 80 + 700)
	if f == 80 + 715:
		check("Трос снова привязан", lev.anchor != null)
		lev.position = Vector2(100, 330)       # дальше 470 px от опоры (720)
	if f == 80 + 720:
		check("Трос оборвался при слишком большом расстоянии", lev.anchor == null)
		print(("ВСЕ ТЕСТЫ ПРОШЛИ" if ok else "ЕСТЬ ПРОВАЛЫ"))
		quit(0 if ok else 1)
	return false
