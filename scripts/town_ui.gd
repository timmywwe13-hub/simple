class_name TownUI
extends RefCounted

## Shared Control scaffolding for the town shop panels: a dimmed overlay
## with a centered pixel-bordered card, a scrolling body and coins /
## status labels. Built in code like the rest of the game's UI.

## One pixel frame (ColorRects, no themes) around a filled rect. Adds the
## 1px wheat highlight along the top edge, so the panel reads as a bevelled
## wooden plank instead of a flat box.
static func frame(parent: Control, r: Rect2, fill: Color, border: Color, bw := 4.0) -> void:
	var bg := ColorRect.new()
	bg.color = fill
	bg.position = r.position
	bg.size = r.size
	parent.add_child(bg)
	var edges := [
		Rect2(r.position.x, r.position.y, r.size.x, bw),
		Rect2(r.position.x, r.position.y + r.size.y - bw, r.size.x, bw),
		Rect2(r.position.x, r.position.y, bw, r.size.y),
		Rect2(r.position.x + r.size.x - bw, r.position.y, bw, r.size.y),
	]
	for e in edges:
		var b := ColorRect.new()
		b.color = border
		b.position = e.position
		b.size = e.size
		parent.add_child(b)
	if SeasonTheme.is_harvest():
		var wheat := ColorRect.new()
		wheat.color = UILib.WHEAT
		wheat.position = r.position + Vector2(bw + 6.0, 1.0)
		wheat.size = Vector2(maxf(0.0, r.size.x - bw * 2.0 - 12.0), 1.0)
		parent.add_child(wheat)


## Notched ribbon banner used for every screen title.
static func ribbon(parent: Control, text: String, pos: Vector2, width := 360.0,
		height := 38.0) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = Vector2(width, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	c.draw.connect(func() -> void:
		var w := c.size.x
		var h := c.size.y
		var notch := minf(12.0, w * 0.08)
		var pts := PackedVector2Array([
			Vector2(notch, 0.0), Vector2(w - notch, 0.0), Vector2(w, h * 0.5),
			Vector2(w - notch, h), Vector2(notch, h), Vector2(0.0, h * 0.5),
		])
		c.draw_colored_polygon(pts, UILib.PANEL_LIGHT)
		c.draw_polyline(PackedVector2Array([
			Vector2(notch, 0.0), Vector2(w - notch, 0.0), Vector2(w, h * 0.5),
			Vector2(w - notch, h), Vector2(notch, h), Vector2(0.0, h * 0.5),
			Vector2(notch, 0.0)]), UILib.WOOD_DARK, 2.0)
		if SeasonTheme.is_harvest():
			c.draw_rect(Rect2(notch + 4.0, 1.0, maxf(0.0, w - notch * 2.0 - 8.0), 2.0),
					UILib.WHEAT)
		# stitched tail shadow under the ribbon
		c.draw_rect(Rect2(notch, h - 2.0, w - notch * 2.0, 3.0), UILib.WOOD_DARK.darkened(0.2))
	)
	var l := UILib.label(c, text, 24, UILib.CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 16.0
	l.offset_right = -16.0
	return c


## Static leaf sprigs in the top-left and bottom-right corners of the
## full-screen boards. Deliberately not animated, so reduce_motion leaves
## them exactly as they are.
static func leaf_sprigs(parent: Control, card: Vector2) -> void:
	if not SeasonTheme.is_harvest():
		return
	var corners := [Vector2(6.0, 6.0), Vector2(card.x - 58.0, card.y - 42.0)]
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	c.draw.connect(func() -> void:
		for corner in corners:
			var o: Vector2 = corner
			c.draw_line(o, o + Vector2(26.0, 18.0), UILib.WOOD_DARK, 2.0)
			for i in range(4):
				var p := o + Vector2(8.0 + float(i) * 6.0, 5.0 + float(i) * 4.0)
				c.draw_colored_polygon(PackedVector2Array([p, p + Vector2(9.0, -5.0),
					p + Vector2(11.0, 4.0)]), [UILib.PUMPKIN, UILib.GOLD, UILib.EMBER, UILib.LEAF][i])
	)


## Full-screen shop screen. Returns:
##   {"root": Control, "body": VBoxContainer, "coins": Label, "status": Label}
static func screen(layer: Node, title: String, card := Vector2(760.0, 470.0)) -> Dictionary:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var dim := ColorRect.new()
	var dim_c := UILib.DIM
	dim_c.a = 0.72
	dim.color = dim_c
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := Control.new()
	panel.custom_minimum_size = card
	panel.size = card
	root.add_child(panel)
	# Fit the card on small windows (landscape phones / 640x360) instead of
	# drawing its title and close hint off-screen.
	var vp := layer.get_viewport().get_visible_rect().size
	var sc := clampf(minf((vp.x - 24.0) / card.x, (vp.y - 24.0) / card.y), 0.45, 1.0)
	panel.scale = Vector2(sc, sc)
	panel.position = (vp - card * sc) * 0.5
	# Rounded chestnut panel with a soft shadow and a wheat top highlight.
	var pbg := Panel.new()
	pbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pbg.add_theme_stylebox_override("panel", UILib.sfx_bg())
	panel.add_child(pbg)
	if SeasonTheme.is_harvest():
		var wheat := ColorRect.new()
		wheat.color = UILib.WHEAT
		wheat.position = Vector2(14.0, 3.0)
		wheat.size = Vector2(maxf(0.0, card.x - 28.0), 1.0)
		panel.add_child(wheat)
	leaf_sprigs(panel, card)
	var title_w := clampf(64.0 + float(title.length()) * 16.0, 240.0, card.x - 360.0)
	ribbon(panel, title, Vector2(18.0, 10.0), title_w, 42.0)
	var coins := UILib.label(panel, "", 20, UILib.GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT)
	coins.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coins.offset_left = -320.0
	coins.offset_right = -24.0
	coins.offset_top = 22.0
	coins.offset_bottom = 52.0
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24.0, 66.0)
	scroll.size = Vector2(card.x - 48.0, card.y - 66.0 - 78.0)
	panel.add_child(scroll)
	UILib.style_scroll(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)
	var status := UILib.label(panel, "", 15, UILib.CREAM, true, HORIZONTAL_ALIGNMENT_LEFT)
	status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status.offset_left = 24.0
	status.offset_right = 420.0
	status.offset_top = -58.0
	status.offset_bottom = -22.0
	var close_hint := UILib.label(panel, "ESC - CLOSE", 14, UILib.SUBTEXT, false, HORIZONTAL_ALIGNMENT_RIGHT)
	close_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	close_hint.offset_left = -220.0
	close_hint.offset_right = -24.0
	close_hint.offset_top = -56.0
	close_hint.offset_bottom = -24.0
	return {"root": root, "body": body, "coins": coins, "status": status, "scroll": scroll}


## Small gold section header inside a shop body, underlined with a dotted
## wheat separator.
static func header(parent: Control, text: String) -> void:
	var t := UILib.label(parent, text, 19, UILib.GOLD, true)
	t.custom_minimum_size = Vector2(0.0, 28.0)
	UILib.separator(parent, 8.0)


## Fixed-height row Control for shop lists.
static func row(parent: Control, height := 46.0, width := 640.0) -> Control:
	var r := Control.new()
	r.custom_minimum_size = Vector2(width, height)
	parent.add_child(r)
	return r


## Right-aligned action button pinned inside a row.
static func row_button(parent: Control, text: String, callable: Callable, width := 120.0) -> Button:
	var b := UILib.button(parent, text, callable, 13, UILib.PANEL_LIGHT,
			UILib.BUTTON_HOVER, UILib.BUTTON_PRESS, UILib.CREAM, Vector2(width, 34.0))
	b.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	b.offset_left = -(width + 12.0)
	b.offset_right = -12.0
	b.offset_top = -17.0
	b.offset_bottom = 17.0
	return b