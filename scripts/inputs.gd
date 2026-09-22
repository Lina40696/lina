extends Node
# Регистрирует управление обоих героев прямо из кода и умеет переназначать клавиши.
#
# Имена действий: "p1_..." = Лев, "p2_..." = Мира.
# Клавиши, которые игрок может менять, лежат в bindings (см. DEFAULTS). Сохраняет их Settings.
#
# solo_mode = true  -> ты играешь одна: клавиатура управляет ОДНИМ героем за раз,
#                      переключение клавишей switch_hero (Tab). Удобно для тестов.
# solo_mode = false -> два человека на одной клавиатуре (эту схему менять нельзя).

var solo_mode: bool = true

# Клавиши по умолчанию (physical keycode: не зависит от раскладки, работает и на русской).
const DEFAULTS := {
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_W,
	"throw": KEY_F,
	"release": KEY_G,
	"dash": KEY_SHIFT,
	"light": KEY_Q,
	"swap": KEY_C,
	"switch_hero": KEY_TAB,
	"interact": KEY_E,
}

const MANAGED_ACTIONS := [
	"p1_left", "p1_right", "p1_jump", "p1_throw", "p1_release", "p1_dash",
	"p2_left", "p2_right", "p2_jump", "p2_light", "p2_swap", "switch_hero", "interact",
]

var bindings: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	for key in Settings.saved_bindings:
		if DEFAULTS.has(key):
			bindings[key] = int(Settings.saved_bindings[key])
	_rebuild()


# Как называется клавиша для показа игроку: "A", "Shift", "Tab"...
func key_name(binding: String) -> String:
	return OS.get_keycode_string(bindings.get(binding, 0))


# Назначает клавишу. Если она уже занята другим действием, они меняются клавишами местами.
func rebind(binding: String, keycode: int) -> void:
	if not DEFAULTS.has(binding) or keycode == KEY_ESCAPE or keycode == KEY_NONE:
		return
	var old: int = bindings[binding]
	for other in bindings:
		if other != binding and bindings[other] == keycode:
			bindings[other] = old
	bindings[binding] = keycode
	_rebuild()
	Settings.save_settings()


func reset_bindings() -> void:
	bindings = DEFAULTS.duplicate()
	_rebuild()
	Settings.save_settings()


func _rebuild() -> void:
	for a in MANAGED_ACTIONS:
		if InputMap.has_action(a):
			InputMap.action_erase_events(a)
		else:
			InputMap.add_action(a, 0.3)

	if solo_mode:
		# Движение и прыжок общие для обоих героев (двигает тот, кого сейчас выбрали).
		for who in ["p1", "p2"]:
			_key(who + "_left", bindings.move_left)
			_key(who + "_left", KEY_LEFT)
			_key(who + "_right", bindings.move_right)
			_key(who + "_right", KEY_RIGHT)
			_key(who + "_jump", bindings.jump)
			_key(who + "_jump", KEY_UP)
			_key(who + "_jump", KEY_SPACE)
		_key("p1_throw", bindings.throw)
		_key("p1_release", bindings.release)
		_key("p1_dash", bindings.dash)
		_key("p2_light", bindings.light)
		_key("p2_swap", bindings.swap)
	else:
		# Две схемы на одной клавиатуре: Лев слева (WASD), Мира справа (стрелки).
		_key("p1_left", KEY_A)
		_key("p1_right", KEY_D)
		_key("p1_jump", KEY_W)
		_key("p2_left", KEY_LEFT)
		_key("p2_right", KEY_RIGHT)
		_key("p2_jump", KEY_UP)
		_key("p1_throw", KEY_F)
		_key("p1_release", KEY_G)
		_key("p1_dash", KEY_SHIFT)
		_key("p2_light", KEY_COMMA)
		_key("p2_swap", KEY_M)
	_key("switch_hero", bindings.switch_hero)
	_key("interact", bindings.interact)          # E: заговорить/использовать объект (общая для обоих героев)

	_register_gamepads()


func _register_gamepads() -> void:
	# Геймпад 0 = Лев, геймпад 1 = Мира.
	# ВНИМАНИЕ: геймпады я не могла проверить, у меня их нет. Если что-то не работает, скажи.
	_pad_axis("p1_left", JOY_AXIS_LEFT_X, -1.0, 0)
	_pad_axis("p1_right", JOY_AXIS_LEFT_X, 1.0, 0)
	_pad_button("p1_jump", JOY_BUTTON_A, 0)
	_pad_button("p1_throw", JOY_BUTTON_X, 0)
	_pad_button("p1_release", JOY_BUTTON_B, 0)
	_pad_button("p1_dash", JOY_BUTTON_Y, 0)

	_pad_axis("p2_left", JOY_AXIS_LEFT_X, -1.0, 1)
	_pad_axis("p2_right", JOY_AXIS_LEFT_X, 1.0, 1)
	_pad_button("p2_jump", JOY_BUTTON_A, 1)
	_pad_button("p2_light", JOY_BUTTON_X, 1)
	_pad_button("p2_swap", JOY_BUTTON_B, 1)

	_pad_button("interact", JOY_BUTTON_RIGHT_SHOULDER, 0)
	_pad_button("interact", JOY_BUTTON_RIGHT_SHOULDER, 1)


func _key(action: String, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode as Key
	InputMap.action_add_event(action, ev)


func _pad_button(action: String, button: JoyButton, device: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = device
	InputMap.action_add_event(action, ev)


func _pad_axis(action: String, axis: JoyAxis, value: float, device: int) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	ev.device = device
	InputMap.action_add_event(action, ev)
