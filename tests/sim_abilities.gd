extends SceneTree
# Проверка способностей Миры: двойной прыжок, рывок, стена, сферы, рисование мышью.
var f := 0
var main
var lev
var mira
var ok := true
var mouse_world := Vector2.ZERO
var zone1
var orbs := []

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		ok = false

var _rel := {}
func tap(a: String, frames := 2) -> void:
	Input.action_press(a)
	_rel[a] = f + frames

func mouse_button(pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(ev)

var y0 := 0.0
var min_y := 0.0
var x0 := 0.0
var light0 := 0.0
var single_h := 0.0

func _physics_process(_d: float) -> bool:
	f += 1
	for a in _rel.keys():
		if f >= _rel[a]:
			Input.action_release(a)
			_rel.erase(a)
	if f == 1:
		main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		return false
	if f == 2:
		lev = main.lev
		mira = main.mira
		lev.input_enabled = true
		mira.input_enabled = true
		orbs = get_nodes_in_group("light_orbs")
		for z in get_nodes_in_group("draw_zones"):
			if z.global_position.x < 1000:
				zone1 = z
		lev.position = Vector2(300, 330)      # отодвигаем Льва, чтобы не мешал бегать
		mira.mouse_source = func() -> Vector2: return mouse_world
	# ---------- Лев: одиночный прыжок (для сравнения)
	if f == 60:
		check("Лев умеет акробатику, у Миры её нет", lev.can_dash and lev.can_wall_jump and lev.max_air_jumps == 1 and not mira.can_dash and not mira.can_wall_jump and mira.max_air_jumps == 0)
		lev.position = Vector2(200, 330)
		lev.velocity = Vector2.ZERO
	if f == 80:
		y0 = lev.position.y
		min_y = y0
		tap("p1_jump", 12)
	if f > 80 and f < 140:
		min_y = min(min_y, lev.position.y)
	if f == 140:
		single_h = y0 - min_y
		print("   высота одного прыжка Льва: ", snappedf(single_h, 1))
		check("Одиночный прыжок Льва ~90-110 px", single_h > 80 and single_h < 120)
	# ---------- Лев: двойной прыжок
	if f == 150:
		y0 = lev.position.y
		min_y = y0
		tap("p1_jump", 12)
	if f == 150 + 18:
		tap("p1_jump", 12)
	if f > 150 and f < 220:
		min_y = min(min_y, lev.position.y)
	if f == 220:
		var dh: float = y0 - min_y
		print("   высота двойного прыжка Льва: ", snappedf(dh, 1))
		check("Двойной прыжок Льва заметно выше одиночного (>1.6x)", dh > single_h * 1.6)
	# ---------- Мира: двойного прыжка НЕТ
	if f == 230:
		mira.position = Vector2(0, 330)
		mira.velocity = Vector2.ZERO
	if f == 260:
		y0 = mira.position.y
		min_y = y0
		tap("p2_jump", 12)
	if f == 260 + 18:
		tap("p2_jump", 12)
	if f > 260 and f < 330:
		min_y = min(min_y, mira.position.y)
	if f == 330:
		var mh: float = y0 - min_y
		print("   высота прыжка Миры (два нажатия): ", snappedf(mh, 1))
		check("У Миры второй прыжок в воздухе не срабатывает (<100 px)", mh < 100.0)
	# ---------- Лев: рывок
	if f == 340:
		lev.position = Vector2(200, 330)
		lev.velocity = Vector2.ZERO
		x0 = lev.position.x
		Input.action_press("p1_right")
	if f == 360:
		var normal_run: float = lev.position.x - x0
		x0 = lev.position.x
		tap("p1_dash", 2)
		lev.set_meta("normal20", normal_run)
	if f == 360 + 10:
		var dash_dist: float = lev.position.x - x0
		print("   рывок Льва за 10 кадров: ", snappedf(dash_dist, 1), " px, бег за 20 кадров: ", snappedf(lev.get_meta("normal20"), 1))
		check("Рывок Льва быстрее бега (>50 px за 10 кадров)", dash_dist > 50.0)
		Input.action_release("p1_right")
	# ---------- Лев: стена, скольжение и прыжок от стены
	if f == 400:
		lev.position = Vector2(-128, 150)   # левая стена: грань на x=-150
		lev.velocity = Vector2.ZERO
		Input.action_press("p1_left")
	if f == 425:
		check("Лев прижат к стене", lev.is_on_wall() and not lev.is_on_floor())
		check("Скольжение по стене медленное (<=130 px/с)", lev.velocity.y <= 130.0)
		tap("p1_jump", 12)
	if f == 428:
		print("   после прыжка от стены: v=", lev.velocity)
		check("Прыжок от стены: отскок от стены и вверх", lev.velocity.x > 150.0 and lev.velocity.y < -300.0)
		Input.action_release("p1_left")
	# ---------- Сферы света: только Мира
	if f == 480:
		mira.position = Vector2(0, 330)
		mira.velocity = Vector2.ZERO
		lev.position = Vector2(60, 330)
		lev.velocity = Vector2.ZERO
		mira.light = 50.0
	if f == 500:
		var orb_pillar
		for o in orbs:
			if o.global_position.x > 920 and o.global_position.x < 970:
				orb_pillar = o
		lev.position = orb_pillar.global_position
		lev.velocity = Vector2.ZERO
		lev.set_meta("orb", orb_pillar)
	if f == 510:
		check("Лев проходит сквозь сферу: не собирает", not lev.get_meta("orb").collected)
		var orb_b
		for o in orbs:
			if o.global_position.x > 780 and o.global_position.x < 820:
				orb_b = o
		light0 = mira.light
		mira.position = orb_b.global_position
		mira.velocity = Vector2.ZERO
		mira.set_meta("orb", orb_b)
		lev.position = Vector2(0, 330)
	if f == 520:
		check("Мира собирает сферу: свет +25", mira.light > light0 + 20.0)
		check("Сфера исчезла", mira.get_meta("orb").collected)
	# ---------- Рисование мышью
	if f == 540:
		mira.position = Vector2(400, 330)
		mira.velocity = Vector2.ZERO
		lev.position = Vector2(0, 330)
		lev.velocity = Vector2.ZERO
		mira.light = 100.0
	if f == 580:
		check("Рамка загорелась, Мира рядом", zone1.active)
		mouse_world = Vector2(300, 380)      # снаружи (рамка 420..720)
		mouse_button(true)
	if f == 583:
		check("Клик вне рамки не начинает линию", not mira.drawing)
		mouse_button(false)
	if f == 590:
		mouse_world = Vector2(430, 385)
		mouse_button(true)
	if f == 593:
		check("Клик внутри рамки начинает линию", mira.drawing)
		light0 = mira.light
	if f > 593 and f < 640:
		mouse_world = Vector2(430 + (f - 593) * 6.0, 385)
	if f == 640:
		mouse_world = Vector2(430 + 47 * 6.0, 385)
		mouse_button(false)
	if f == 645:
		check("Линия нарисована и стала твёрдой", zone1._strokes.size() == 1)
		var spent: float = light0 - mira.light
		print("   длина линии: ", snappedf(zone1.ink_used(), 1), " px, потрачено света: ", snappedf(spent, 0.1))
		check("Свет потрачен пропорционально длине", spent > 15.0 and spent < 30.0)
		mira.position = Vector2(560, 330)
		mira.velocity = Vector2.ZERO
	if f == 700:
		check("Мира стоит на нарисованной линии над провалом", mira.is_on_floor() and mira.position.y < 385.0)
	if f == 645 + 5 * 60 + 30:
		check("Линия исчезла через ~5 секунд без троса", zone1._strokes.size() == 0)
	# Второй заход: Лев страхует трос
	if f == 1000:
		mira.position = Vector2(400, 330)
		mira.velocity = Vector2.ZERO
		lev.position = Vector2(330, 330)
		lev.velocity = Vector2.ZERO
		lev.facing = 1
		mira.light = 100.0
	if f == 1005:
		tap("p1_throw", 2)
	if f == 1015:
		check("Лев привязан к опоре", lev.anchor != null and lev.anchor.kind == 0)
		mouse_world = Vector2(430, 385)
		mouse_button(true)
	if f > 1018 and f < 1065:
		mouse_world = Vector2(430 + (f - 1018) * 6.0, 385)
	if f == 1065:
		mouse_button(false)
	if f == 1070:
		check("Линия нарисована", zone1._strokes.size() == 1)
	if f == 1070 + 8 * 60:
		check("Со страховкой Льва линия держится дольше 5 секунд", zone1._strokes.size() == 1)
		Input.action_press("p1_release")
	if f == 1070 + 8 * 60 + 2:
		Input.action_release("p1_release")
	if f == 1070 + 8 * 60 + 6 * 60:
		check("Через 5 секунд после отпускания линия исчезла", zone1._strokes.size() == 0)
	# ПКМ стирает и возвращает часть света
	if f == 1700:
		mira.light = 100.0
		mouse_world = Vector2(430, 385)
		mouse_button(true)
	if f > 1702 and f < 1750:
		mouse_world = Vector2(430 + (f - 1702) * 6.0, 385)
	if f == 1750:
		mouse_button(false)
		light0 = mira.light
		check("Новая линия есть", zone1._strokes.size() == 1)
	if f == 1753:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_RIGHT
		ev.pressed = true
		ev.button_mask = MOUSE_BUTTON_MASK_RIGHT
		Input.parse_input_event(ev)
		mouse_world = Vector2(570, 330)
	if f == 1757:
		check("ПКМ стёрла линию", zone1._strokes.size() == 0)
		check("Стирание вернуло часть света", mira.light > light0)
		print(("ВСЕ ТЕСТЫ ПРОШЛИ" if ok else "ЕСТЬ ПРОВАЛЫ"))
		quit(0 if ok else 1)
	return false
