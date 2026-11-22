class_name UILib
extends RefCounted

## Tiny UI toolkit used across the game's screens.
## Everything is built in code (no .tres themes) so the whole game stays
## editable in one folder with no external assets.

## Season-driven palette tokens (SeasonTheme.apply reassigns these).
## They are static vars rather than consts for exactly that reason.
static var INK := Color("#182236")
static var CREAM := Color("#f6ead8")
static var PAPER := Color("#f3e3c6")
static var PANEL := Color("#1d2536")
static var PANEL_LIGHT := Color("#33405a")
static var WOOD := Color("#8a5a3b")
static var WOOD_DARK := Color("#5f3d28")
static var GOLD := Color("#f2c14e")
static var LEAF := Color("#68a35c")
static var PUMPKIN := Color("#e2703a")
static var CRANBERRY := Color("#9c3d54")
static var WHEAT := Color("#e8d5a8")
static var EMBER := Color("#c9532b")
static var HUSK := Color("#6b4a2f")
static var BUTTON_HOVER := Color("#55708a")
static var BUTTON_PRESS := Color("#2c3d4d")
static var SUBTEXT := Color("#a8c0cc")
static var DIM := Color("#0b1320")
static var FAINT := Color("#8d9aa6")
static var RARITY_OUTLINE := Color(0, 0, 0, 0)
static var PANEL_BORDER := Color("#16202a")
static var BUTTON_BORDER := Color("#16202a")
static var BUTTON_BORDER_PRESS := Color("#0e151c")

static func sfx_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(14)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = PANEL_BORDER
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
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
		sb.border_color = BUTTON_BORDER if not pressed else BUTTON_BORDER_PRESS
		return sb
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(12)
	focus.border_width_left = 2
	focus.border_width_right = 2
	focus.border_width_top = 2
	focus.border_width_bottom = 2
	focus.border_color = GOLD
	focus.expand_margin_left = 2.0
	focus.expand_margin_right = 2.0
	focus.expand_margin_top = 2.0
	focus.expand_margin_bottom = 2.0
	return {
		"normal": mk.call(base, false),
		"hover": mk.call(hover_c, false),
		"pressed": mk.call(pressed_c, true),
		"disabled": mk.call(HUSK.darkened(0.08), false),
		"focus": focus,
	}

## StyleBox used for full-screen parchment-ish boards (album, feast).
static func sfx_paper() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(14)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = WOOD_DARK
	sb.shadow_color = Color(0, 0, 0, 0.30)
	sb.shadow_size = 6
	return sb

## Dotted wheat line used instead of plain separators.
static func separator(parent: Control, height := 10.0) -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(0.0, height)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	line.draw.connect(func() -> void:
		var y := line.size.y * 0.5
		var x := 6.0
		while x < line.size.x - 6.0:
			line.draw_rect(Rect2(x, y, 4.0, 2.0), WHEAT.darkened(0.18))
			x += 10.0
	)
	return line

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
		base := PANEL_LIGHT, hover := BUTTON_HOVER, pressed := BUTTON_PRESS,
		text_color := CREAM, min_size := Vector2(150, 46)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", text_color)
	b.add_theme_color_override("font_color_hover", Color("#ffffff"))
	b.add_theme_color_override("font_color_pressed", Color("#ffe9b0"))
	b.add_theme_color_override("font_color_disabled", FAINT)
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
static func pill(parent: Control, text: String, color: Color, size := 14,
		text_color := INK) -> Label:
	var l := label(parent, text, size, text_color)
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.0))
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_color", text_color)
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

## Umber scrollbar thumbs for any ScrollContainer (or ItemList).
static func style_scroll(control: Control) -> void:
	var bar: VScrollBar = null
	if control is ScrollContainer:
		bar = (control as ScrollContainer).get_v_scroll_bar()
	elif control is ItemList:
		bar = (control as ItemList).get_v_scroll_bar()
	if bar == null:
		return
	var trough := StyleBoxFlat.new()
	trough.bg_color = HUSK.darkened(0.15)
	trough.set_corner_radius_all(4)
	var grab := StyleBoxFlat.new()
	grab.bg_color = WOOD
	grab.set_corner_radius_all(4)
	grab.content_margin_left = 2.0
	grab.content_margin_right = 2.0
	var grab_hi := grab.duplicate() as StyleBoxFlat
	grab_hi.bg_color = BUTTON_HOVER
	bar.add_theme_stylebox_override("scroll", trough)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab_hi)
	bar.add_theme_stylebox_override("grabber_pressed", grab_hi)


## Season-aware ItemList skin (rows, selection, guide lines).
static func style_item_list(list: ItemList) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL.darkened(0.10)
	panel.set_corner_radius_all(8)
	panel.border_width_left = 2
	panel.border_width_right = 2
	panel.border_width_top = 2
	panel.border_width_bottom = 2
	panel.border_color = WOOD_DARK
	panel.content_margin_left = 6.0
	panel.content_margin_right = 6.0
	panel.content_margin_top = 4.0
	panel.content_margin_bottom = 4.0
	var sel := StyleBoxFlat.new()
	sel.bg_color = PANEL_LIGHT
	sel.set_corner_radius_all(5)
	sel.content_margin_left = 4.0
	sel.content_margin_right = 4.0
	var cursor := StyleBoxFlat.new()
	cursor.bg_color = Color(WHEAT.r, WHEAT.g, WHEAT.b, 0.10)
	cursor.set_corner_radius_all(5)
	list.add_theme_stylebox_override("panel", panel)
	list.add_theme_stylebox_override("selected", sel)
	list.add_theme_stylebox_override("selected_focus", sel)
	list.add_theme_stylebox_override("cursor", cursor)
	list.add_theme_stylebox_override("cursor_unfocused", cursor)
	list.add_theme_color_override("font_color", CREAM)
	list.add_theme_color_override("font_selected_color", CREAM)
	list.add_theme_color_override("font_disabled_color", FAINT)
	list.add_theme_color_override("guide_color", Color(WHEAT.r, WHEAT.g, WHEAT.b, 0.14))
	style_scroll(list)


static func full_rect(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
