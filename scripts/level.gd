extends Node2D
# УРОВЕНЬ. Этот скрипт стоит на главном узле комнаты. Он сам создаёт героев, камеру, темноту
# и интерфейс. Саму комнату ты собираешь в редакторе из «кубиков» (scenes/blocks).
#
# Что должно быть в комнате:
#   SpawnLev, SpawnMira  два узла Marker2D: где появятся Лев и Мира (центр героя)
#   Goal                 зона выхода (блок goal.tscn)
#   Checkpoint           контрольные точки (по желанию)
# Остальное (платформы, якоря, рамки, сферы) ставь где угодно. Подробнее в HOW_TO_BUILD_LEVELS.md.

const LevScene := preload("res://scenes/lev.tscn")
const MiraScene := preload("res://scenes/mira.tscn")
const HudScript := preload("res://scripts/hud.gd")
const DialogueScript := preload("res://scripts/dialogue.gd")

@export var ambient_color: Color = Color(0.6, 0.57, 0.65)   # насколько темно вокруг (меньше = темнее)
@export var fall_limit: float = 900.0                        # ниже этой линии = «Антракт»

var lev: CharacterBody2D
var mira: CharacterBody2D
var camera: Camera2D
var hud: CanvasLayer
var active_hero: int = 1
var goal_reached: bool = false
var checkpoints: int = 0            # сколько контрольных точек уже пройдено

var _spawn_lev: Vector2
var _spawn_mira: Vector2
var _checkpoint_nodes: Array = []
var _goals: Array = []


func _ready() -> void:
	# Тьма и общий свет
	var modulate_node := CanvasModulate.new()
	modulate_node.color = ambient_color
	add_child(modulate_node)

	_spawn_lev = _marker_position("SpawnLev", Vector2(0, 0))
	_spawn_mira = _marker_position("SpawnMira", Vector2(-60, 0))

	_goals = get_tree().get_nodes_in_group("goals")
	if _goals.is_empty():
		push_warning("В комнате нет зоны выхода (блок goal.tscn): комната не сможет закончиться.")
	_checkpoint_nodes = get_tree().get_nodes_in_group("checkpoints")
	_checkpoint_nodes.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.x < b.global_position.x)

	# Герои
	lev = LevScene.instantiate()
	lev.position = _spawn_lev
	add_child(lev)
	mira = MiraScene.instantiate()
	mira.position = _spawn_mira
	add_child(mira)

	# Камера и интерфейс
	camera = Camera2D.new()
	camera.zoom = Vector2(0.8, 0.8)
	camera.position_smoothing_enabled = true
	add_child(camera)
	camera.global_position = (_spawn_lev + _spawn_mira) / 2.0 + Vector2(0, -40)

	hud = HudScript.new()
	hud.lev = lev
	hud.mira = mira
	hud.add_to_group("hud")      # так рычаги и другие кубики находят hud без ручных ссылок
	add_child(hud)
	mira.swap_failed.connect(func(reason: String) -> void: hud.show_message(reason, 1.5))   # текст уже переведён в mira.gd

	# Окно диалога: одно на комнату, персонажи (npc.gd) находят его через группу "dialogue_ui".
	var dialogue: CanvasLayer = DialogueScript.new()
	add_child(dialogue)

	_apply_active()


func _marker_position(node_name: String, fallback: Vector2) -> Vector2:
	var m := get_node_or_null(node_name)
	if m == null:
		push_warning("В комнате нет узла %s: беру точку по умолчанию." % node_name)
		return fallback
	return m.global_position


# Если язык сменился, пока комната открыта, пересчитываем подпись.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and hud != null and lev != null:
		_apply_active()


func _unhandled_input(event: InputEvent) -> void:
	# Esc: назад в главное меню
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return
	if event.is_action_pressed("switch_hero") and Inputs.solo_mode:
		active_hero = 2 if active_hero == 1 else 1
		_apply_active()


func _physics_process(_delta: float) -> void:
	# Камера следит за серединой между героями
	camera.global_position = (lev.global_position + mira.global_position) / 2.0 + Vector2(0, -40)

	# Падение = «Антракт»: герой возвращается на последний старт
	for hero in [lev, mira]:
		if hero.global_position.y > fall_limit:
			_respawn(hero)

	# Контрольные точки (по порядку слева направо)
	if checkpoints < _checkpoint_nodes.size():
		var cp: Node2D = _checkpoint_nodes[checkpoints]
		var x := cp.global_position.x
		if lev.global_position.x > x and mira.global_position.x > x \
				and lev.is_on_floor() and mira.is_on_floor():
			checkpoints += 1
			_spawn_mira = cp.global_position
			_spawn_lev = cp.global_position + cp.lev_offset
			hud.show_message(tr("Контрольная точка"), 1.5)

	# Комната пройдена, когда оба в зоне выхода
	if not goal_reached:
		for g in _goals:
			var bodies: Array = g.get_overlapping_bodies()
			if bodies.has(lev) and bodies.has(mira):
				goal_reached = true
				var text: String = g.message if g.message != "" else tr("Комната пройдена")
				hud.show_message(text, 4.0)
				if g.next_level != "":
					_go_to_next_level(g.next_level)


func _apply_active() -> void:
	if Inputs.solo_mode:
		lev.input_enabled = (active_hero == 1)
		mira.input_enabled = (active_hero == 2)
		hud.status_text = tr("Управляешь: %s (%s: переключить героя)") % [
			tr("Лев") if active_hero == 1 else tr("Мира"), Inputs.key_name("switch_hero")]
	else:
		lev.input_enabled = true
		mira.input_enabled = true
		hud.status_text = ""


func _respawn(hero: CharacterBody2D) -> void:
	hud.show_message(tr("Антракт"), 1.2)
	hero.velocity = Vector2.ZERO
	hero.position = _spawn_lev if hero == lev else _spawn_mira
	if hero.has_method("release_rope"):
		hero.release_rope()


# ПЕРЕХОД НА СЛЕДУЮЩИЙ УРОВЕНЬ: коротко держим надпись, затемняем экран и загружаем файл,
# указанный в поле Next Level у зоны выхода (goal.gd). В новой комнате всё начинается заново
# со своих SpawnLev/SpawnMira — отдельно ничего передавать не нужно.
func _go_to_next_level(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	fade_layer.add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.6)
	await tween.finished
	get_tree().change_scene_to_file(path)
