extends RefCounted
# Маленький помощник: делает мягкую круглую текстуру света (для фонаря Миры и ламп).
# Позже заменишь на свою нарисованную текстуру света.

static func make_light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.9, 0.6, 1.0))
	gradient.set_color(1, Color(1.0, 0.9, 0.6, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 512
	tex.height = 512
	return tex
