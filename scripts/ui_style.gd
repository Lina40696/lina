extends RefCounted
# Общий вид кнопок меню и настроек: заметный фон и рамка. Меняй цвета здесь.

static func _box(fill: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


static func style_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _box(Color(0.17, 0.16, 0.20), Color(0.36, 0.34, 0.42)))
	b.add_theme_stylebox_override("hover", _box(Color(0.24, 0.22, 0.29), Color(0.75, 0.68, 0.45)))
	b.add_theme_stylebox_override("pressed", _box(Color(0.30, 0.27, 0.20), Color(1.0, 0.88, 0.54)))
	b.add_theme_stylebox_override("focus", _box(Color(0.0, 0.0, 0.0, 0.0), Color(1.0, 0.88, 0.54), 2))
	b.add_theme_stylebox_override("disabled", _box(Color(0.14, 0.13, 0.16), Color(0.25, 0.24, 0.28)))
