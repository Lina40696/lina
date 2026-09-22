extends SceneTree
# Пустой шаблон уровня запускается: герои появляются на земле, ничего не падает.
var f := 0
var lvl
var ok := true
func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		ok = false
func _physics_process(_d: float) -> bool:
	f += 1
	if f == 1:
		lvl = load("res://scenes/level_template.tscn").instantiate()
		root.add_child(lvl)
	if f == 60:
		check("Шаблон: герои созданы", lvl.lev != null and lvl.mira != null)
		check("Шаблон: оба стоят на земле", lvl.lev.is_on_floor() and lvl.mira.is_on_floor())
		check("Шаблон: герои появились в точках SpawnLev/SpawnMira", absf(lvl.lev.position.x) < 5 and absf(lvl.mira.position.x + 60) < 5)
		lvl.lev.input_enabled = true
		lvl.mira.input_enabled = true
		lvl.lev.position = Vector2(1040, 300)
		lvl.mira.position = Vector2(1060, 300)
	if f == 120:
		check("Шаблон: зона выхода срабатывает, когда оба внутри", lvl.goal_reached)
		print(("ВСЕ ТЕСТЫ ПРОШЛИ" if ok else "ЕСТЬ ПРОВАЛЫ"))
		quit(0 if ok else 1)
	return false
