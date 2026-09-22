extends SceneTree
# Полное прохождение комнаты без человека: рисование мышью, качели Льва, паркур Миры, второй мост.
var f := 0
var main
var lev
var mira
var ok := true
var phase := "bridge"
var pf := 0
var mouse_world := Vector2.ZERO
var rel := {}
var last_rels := {}
# --- состояние бота-паркурщика
var jumped1 := -1
var reached_c := false
var lev_landed := false
var orbs_before := 0
var pf_swap := 0

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		ok = false

func tap(a: String, frames: int = 3) -> void:
	if Input.is_action_pressed(a) or rel.has(a) or f - int(last_rels.get(a, -10)) < 2:
		return
	Input.action_press(a)
	rel[a] = f + frames

func mouse_button(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(ev)

func _to(p: String) -> void:
	print("--- фаза: ", p)
	phase = p
	pf = 0

func _stroke(pf_now: int, start_pf: int, x0: float, x1: float, y: float) -> void:
	# Ведёт мышь от x0 до x1 по прямой шагами по 6 px за кадр.
	var steps := int(ceil((x1 - x0) / 6.0))
	if pf_now == start_pf:
		mouse_world = Vector2(x0, y)
		mouse_button(true)
	elif pf_now > start_pf + 2 and pf_now <= start_pf + 2 + steps:
		mouse_world = Vector2(min(x0 + (pf_now - start_pf - 2) * 6.0, x1), y)
	elif pf_now == start_pf + 3 + steps:
		mouse_world = Vector2(x1, y)
		mouse_button(false)

func _physics_process(_d: float) -> bool:
	f += 1
	pf += 1
	for a in rel.keys():
		if f >= rel[a]:
			Input.action_release(a)
			rel.erase(a)
			last_rels[a] = f
	if f == 1:
		main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		return false
	if f == 2:
		lev = main.lev
		mira = main.mira
		lev.input_enabled = true
		mira.input_enabled = true
		mira.mouse_source = func() -> Vector2: return mouse_world
		return false

	match phase:
		"bridge":
			if pf == 10:
				mira.position = Vector2(400, 330)
				mira.velocity = Vector2.ZERO
				lev.position = Vector2(330, 330)
				lev.velocity = Vector2.ZERO
			if pf == 30:
				tap("p1_throw", 2)
			_stroke(pf, 40, 430.0, 710.0, 372.0)
			if pf == 140:
				check("Мира нарисовала мост мышью", get_nodes_in_group("draw_zones")[0]._strokes.size() + get_nodes_in_group("draw_zones")[1]._strokes.size() >= 1)
				Input.action_press("p2_right")
			if pf == 150:
				Input.action_press("p1_right")
			if pf > 150 and pf < 500 and mira.position.x > 790 and lev.position.x > 790:
				Input.action_release("p2_right")
				Input.action_release("p1_right")
				check("Оба перешли нарисованный мост", true)
				check("Контрольная точка 1", main.checkpoints == 1)
				tap("p1_release", 2)
				_to("pillar")
			if pf == 500:
				check("Оба перешли нарисованный мост", false)
				quit(1)
		"pillar":
			# Лев забирается на столб двойным прыжком, Мира меняется с ним местами и берёт сферу
			if pf == 5:
				lev.position = Vector2(800, 330)
				lev.velocity = Vector2.ZERO
				mira.position = Vector2(720, 330)
				mira.velocity = Vector2.ZERO
				mira.light = 15.0
				Input.action_press("p1_right")
			if pf > 8 and jumped1 < 0 and lev.is_on_floor() and lev.position.x >= 850.0:
				jumped1 = pf
				tap("p1_jump", 12)
			if jumped1 > 0 and pf == jumped1 + 14:
				Input.action_release("p1_jump")
				rel.erase("p1_jump")
				last_rels["p1_jump"] = f - 2
				tap("p1_jump", 12)
			if jumped1 > 0 and lev.position.x >= 945.0:
				Input.action_release("p1_right")
			if pf == 60:
				check("Мира не достаёт до сферы на столбе (одиночный прыжок)", mira.max_air_jumps == 0 and not mira.can_dash and not mira.can_wall_jump)
			if pf > 60 and lev.is_on_floor() and lev.position.y < 240 and lev.position.x > 895:
				check("Лев забрался на столб (двойной прыжок / стена)", true)
				Input.action_release("p1_right")
				Input.action_release("p1_jump")
				rel.erase("p1_jump")
				mira.swap_left = 0.0
				pf_swap = pf + 15
				_to("pillar_swap")
			if pf == 300:
				check("Лев забрался на столб", false)
				quit(1)
		"pillar_swap":
			if pf == 15:
				tap("p2_swap", 2)
			if pf == 30:
				check("Обмен: Мира теперь на столбе", mira.position.y < 240 and mira.position.x > 895)
				check("Мира забрала сферу со столба: свет вырос", mira.light > 45.0)
				print("   свет Миры: ", snappedf(mira.light, 0.1), " (было 15)")
				_to("split")
		"split":
			# Лев качается на крюке, потом Мира меняется с ним через провал, и Лев качается ещё раз
			if pf == 5:
				mira.position = Vector2(1050, 330)
				mira.velocity = Vector2.ZERO
				lev.position = Vector2(1120, 330)
				lev.velocity = Vector2.ZERO
				lev.facing = 1
			if pf == 40:
				tap("p1_throw", 2)
			if pf == 46:
				Input.action_press("p1_right")
			if pf == 47:
				tap("p1_jump", 2)
			if pf == 47 + 90:
				tap("p1_jump", 2)
			if pf > 150 and lev.position.x > 1560 and lev.is_on_floor():
				Input.action_release("p1_right")
				check("Лев перелетел провал на качелях", true)
				_to("swap")
			if pf == 400:
				check("Лев перелетел провал на качелях", false)
				quit(1)
		"swap":
			if pf == 40:
				check("Мира ещё на ближнем берегу", mira.position.x < 1150)
				mira.swap_left = 0.0
				tap("p2_swap", 2)
			if pf == 50:
				check("Обмен: Мира теперь на дальнем берегу", mira.position.x > 1550)
				check("Обмен: Лев вернулся на ближний берег", lev.position.x < 1150)
				_to("swing2")
		"swing2":
			if pf == 20:
				if lev.anchor != null:
					lev.release_rope()
				lev.position = Vector2(1120, 330)
				lev.velocity = Vector2.ZERO
				lev.facing = 1
			if pf == 50:
				tap("p1_throw", 2)
			if pf == 56:
				Input.action_press("p1_right")
			if pf == 57:
				tap("p1_jump", 2)
			if pf == 57 + 90:
				tap("p1_jump", 2)
			if pf > 160 and pf < 400 and lev.position.x > 1560 and lev.is_on_floor():
				check("Лев перелетел вторым, оба на дальнем берегу", mira.position.x > 1550)
				Input.action_press("p2_right")
				_to("cp2")
			if pf == 400:
				check("Лев перелетел вторым", false)
				quit(1)
		"cp2":
			if pf == 60:
				Input.action_release("p2_right")
				Input.action_release("p1_right")
				check("Контрольная точка 2 (оба на третьем берегу)", main.checkpoints == 2)
				# готовимся ко второму мосту
				if lev.anchor != null:
					lev.release_rope()
				mira.position = Vector2(2060, 372)
				mira.velocity = Vector2.ZERO
				lev.position = Vector2(2030, 372)
				lev.velocity = Vector2.ZERO
				lev.facing = 1
				mira.light = 60.0
			if pf == 80:
				tap("p1_throw", 2)
			if pf == 90:
				check("Лев привязан к опоре второго моста", lev.anchor != null and lev.anchor.kind == 0)
			_stroke(pf, 95, 2085.0, 2415.0, 402.0)
			if pf == 210:
				var n := 0
				for z in get_nodes_in_group("draw_zones"):
					n += z._strokes.size()
				check("Второй мост нарисован", n >= 1)
				Input.action_press("p2_right")
				Input.action_press("p1_right")
				_to("goal")
		"goal":
			if pf > 5 and pf < 800 and main.goal_reached:
				Input.action_release("p2_right")
				Input.action_release("p1_right")
				check("Оба перешли второй мост и вошли в зону выхода", true)
				print(("ВСЕ ТЕСТЫ ПРОШЛИ" if ok else "ЕСТЬ ПРОВАЛЫ"))
				quit(0 if ok else 1)
			if pf == 800:
				check("Оба перешли второй мост и вошли в зону выхода", false)
				print("   Мира: ", mira.position, " Лев: ", lev.position)
				quit(1)
	return false
