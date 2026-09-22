extends Node
# НАСТРОЙКИ ИГРЫ: язык и громкость. Сохраняются в файл user://settings.cfg.
# (Клавиши хранит inputs.gd, но записывает в тот же файл через save_settings().)
#
# Как устроен перевод: в коде все надписи пишутся по-русски внутри tr("..."),
# а ниже в таблице EN лежат английские варианты. Хочешь добавить язык: сделай такую же таблицу.
# Новую надпись в игре: напиши tr("Текст") в коде и добавь строку "Текст": "Text" в EN.

signal language_changed(lang)

const SAVE_PATH := "user://settings.cfg"
const LANGUAGES := {"ru": "Русский", "en": "English"}   # код языка: как показывать в списке

var language: String = "ru"
var volume: float = 0.8                 # 0..1
var saved_bindings: Dictionary = {}     # клавиши из файла (читает inputs.gd)

const EN := {
	# --- меню
	"АНТРАКТ": "THE INTERMISSION",
	"Атмосферный кооперативный паззл-платформер": "An atmospheric co-op puzzle platformer",
	"Играть": "Play",
	"Настройки": "Settings",
	"Выход": "Quit",
	# --- настройки
	"Язык": "Language",
	"Громкость": "Volume",
	"Управление": "Controls",
	"Назад": "Back",
	"Сбросить управление": "Reset controls",
	"Нажми клавишу… (Esc: отмена)": "Press a key… (Esc: cancel)",
	"Движение (оба героя)": "Movement (both heroes)",
	"Общее": "General",
	"Влево": "Left",
	"Вправо": "Right",
	"Прыжок": "Jump",
	"Бросить трос": "Throw rope",
	"Отпустить трос": "Release rope",
	"Рывок": "Dash",
	"Фонарь": "Lantern",
	"Обмен с Львом": "Swap with Lev",
	"Сменить героя": "Switch hero",
	"Стрелки и Пробел тоже работают для движения и прыжка.": "Arrow keys and Space also work for movement and jump.",
	"Рисование: ЛКМ рисует внутри рамки, ПКМ стирает (мышь не переназначается).": "Drawing: LMB draws inside a frame, RMB erases (mouse cannot be rebound).",
	# --- герои
	"Лев": "Lev",
	"Мира": "Mira",
	# --- игра
	"Антракт": "Intermission",
	"Комната пройдена": "Room complete",
	"Контрольная точка": "Checkpoint",
	"Управляешь: %s (%s: переключить героя)": "Controlling: %s (%s: switch hero)",
	"Esc: меню": "Esc: menu",
	"Трос: свободен": "Rope: free",
	"Трос: на опоре": "Rope: on post",
	"Трос: на крюке": "Rope: on hook",
	"Рывок: готов": "Dash: ready",
	"Рывок: %.1f c": "Dash: %.1f s",
	"Свет Миры": "Mira's light",
	"Обмен: готов": "Swap: ready",
	"Обмен: %.1f c": "Swap: %.1f s",
	"Обмен ещё не готов": "Swap not ready yet",
	"Обмен: оба должны стоять на земле": "Swap: both must be on the ground",
	"Обмен: Лев слишком далеко": "Swap: Lev is too far away",
	"Лев: %s/%s бег, %s прыжок (двойной, от стены), %s рывок, %s бросить трос, %s отпустить (на крюке: %s/%s раскачка)": "Lev: %s/%s run, %s jump (double, off walls), %s dash, %s throw rope, %s release (on hook: %s/%s swing)",
	"Мира: %s/%s бег, %s прыжок, %s фонарь, %s обмен с Львом; мышь: ЛКМ рисовать в рамке, ПКМ стереть": "Mira: %s/%s run, %s jump, %s lantern, %s swap with Lev; mouse: LMB draw inside a frame, RMB erase",
}


func _ready() -> void:
	_register_translations()
	load_settings()
	apply_language()
	apply_volume()


func _register_translations() -> void:
	# Для русского тоже нужна таблица (сама на себя), иначе движок подставит английский как запасной.
	var ru := Translation.new()
	ru.locale = "ru"
	var en := Translation.new()
	en.locale = "en"
	for key in EN:
		ru.add_message(key, key)
		en.add_message(key, EN[key])
	TranslationServer.add_translation(ru)
	TranslationServer.add_translation(en)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var lang: String = str(cfg.get_value("game", "language", "ru"))
	language = lang if LANGUAGES.has(lang) else "ru"
	volume = clampf(float(cfg.get_value("audio", "volume", 0.8)), 0.0, 1.0)
	saved_bindings = {}
	if cfg.has_section("controls"):
		for key in cfg.get_section_keys("controls"):
			saved_bindings[key] = int(cfg.get_value("controls", key))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "language", language)
	cfg.set_value("audio", "volume", volume)
	var inputs := get_node_or_null("/root/Inputs")
	if inputs:
		for key in inputs.bindings:
			cfg.set_value("controls", key, int(inputs.bindings[key]))
	cfg.save(SAVE_PATH)


func set_language(lang: String) -> void:
	if not LANGUAGES.has(lang):
		return
	language = lang
	apply_language()
	save_settings()
	language_changed.emit(lang)


func apply_language() -> void:
	TranslationServer.set_locale(language)


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply_volume()
	save_settings()


func apply_volume() -> void:
	var muted := volume <= 0.001
	AudioServer.set_bus_mute(0, muted)
	AudioServer.set_bus_volume_db(0, -80.0 if muted else linear_to_db(volume))
