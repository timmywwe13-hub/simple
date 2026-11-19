class_name UILib
extends RefCounted

## Tiny UI toolkit used across the game's screens.
## Everything is built in code (no .tres themes) so the whole game stays
## editable in one folder with no external assets.

const INK := Color("#182236")
const CREAM := Color("#f6ead8")
const PAPER := Color("#f3e3c6")
const PANEL := Color("#1d2536")
const PANEL_LIGHT := Color("#33405a")
const WOOD := Color("#8a5a3b")
const WOOD_DARK := Color("#5f3d28")
const GOLD := Color("#f2c14e")
const LEAF := Color("#68a35c")

static func sfx_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#20303e")
	sb.set_corner_radius_all(14)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = Color("#16202a")
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	return sb

static func sfx_btn(base: Color, hover_c: Color, pressed_c: Color) -> Dictionary:
	var mk := func(c: Color, pressed: bool) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(10)
		sb.border_width_left = 2 if pressed else 3
		sb.border_width_right = 2 if pressed else 3
		sb.border_width_top = 2 if pressed else 3
		sb.border_width_bottom = 2 if pressed else 3
		sb.border_color = Color("#16202a") if not pressed else Color("#0e151c")
		return sb
	return {
		"normal": mk.call(base, false),
		"hover": mk.call(hover_c, false),
		"pressed": mk.call(pressed_c, true),
		"disabled": mk.call(base.darkened(0.35), false),
		"focus": mk.call(base, false),
	}

static func label(parent: Control, text: String, size := 18, color := CREAM,
		outline := true, align := HORIZONTAL_ALIGNMENT_LEFT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		pass  # default font kept for the cozy look
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
		l.add_theme_constant_override("outline_size", int(max(2.0, size * 0.16)))
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(l)
	return l

static func button(parent: Control, text: String, callable: Callable, size := 18,
		base := PANEL_LIGHT, hover := Color("#55708a"), pressed := Color("#2c3d4d"),
		text_color := CREAM, min_size := Vector2(150, 46)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", text_color)
	b.add_theme_color_override("font_color_hover", Color("#ffffff"))
	b.add_theme_color_override("font_color_pressed", Color("#ffe9b0"))
	b.add_theme_color_override("font_color_disabled", Color("#8d9aa6"))
	var styles := sfx_btn(base, hover, pressed)
	b.add_theme_stylebox_override("normal", styles["normal"])
	b.add_theme_stylebox_override("hover", styles["hover"])
	b.add_theme_stylebox_override("pressed", styles["pressed"])
	b.add_theme_stylebox_override("disabled", styles["disabled"])
	b.add_theme_stylebox_override("focus", styles["focus"])
	b.pressed.connect(callable)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if parent != null:
		parent.add_child(b)
	return b

## Rounded "pill" label, used for rarity tags and small status chips.
static func pill(parent: Control, text: String, color: Color, size := 14) -> Label:
	var l := label(parent, text, size, Color("#12202c"))
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.0))
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_color", Color("#12202c"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	l.add_theme_stylebox_override("normal", sb)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func full_rect(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
