class_name TownUI
extends RefCounted

## Shared Control scaffolding for the town shop panels: a dimmed overlay
## with a centered pixel-bordered card, a scrolling body and coins /
## status labels. Built in code like the rest of the game's UI.

## One pixel frame (ColorRects, no themes) around a filled rect.
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


## Full-screen shop screen. Returns:
##   {"root": Control, "body": VBoxContainer, "coins": Label, "status": Label}
static func screen(layer: Node, title: String, card := Vector2(760.0, 470.0)) -> Dictionary:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color("#0b1320", 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = -card * 0.5
	panel.custom_minimum_size = card
	panel.size = card
	root.add_child(panel)
	frame(panel, Rect2(Vector2.ZERO, card), UILib.PANEL, UILib.CREAM, 4.0)
	var t := UILib.label(panel, title, 26, UILib.GOLD, true, HORIZONTAL_ALIGNMENT_LEFT)
	t.position = Vector2(24.0, 18.0)
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
	var close_hint := UILib.label(panel, "ESC - CLOSE", 14, Color("#9fb3bd"), false, HORIZONTAL_ALIGNMENT_RIGHT)
	close_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	close_hint.offset_left = -220.0
	close_hint.offset_right = -24.0
	close_hint.offset_top = -56.0
	close_hint.offset_bottom = -24.0
	return {"root": root, "body": body, "coins": coins, "status": status}


## Small gold section header inside a shop body.
static func header(parent: Control, text: String) -> void:
	var t := UILib.label(parent, text, 19, UILib.GOLD, true)
	t.custom_minimum_size = Vector2(0.0, 28.0)


## Fixed-height row Control for shop lists.
static func row(parent: Control, height := 46.0, width := 640.0) -> Control:
	var r := Control.new()
	r.custom_minimum_size = Vector2(width, height)
	parent.add_child(r)
	return r


## Right-aligned action button pinned inside a row.
static func row_button(parent: Control, text: String, callable: Callable, width := 120.0) -> Button:
	var b := UILib.button(parent, text, callable, 13, UILib.PANEL_LIGHT,
			Color("#55708a"), Color("#2c3d4d"), UILib.CREAM, Vector2(width, 34.0))
	b.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	b.offset_left = -(width + 12.0)
	b.offset_right = -12.0
	b.offset_top = -17.0
	b.offset_bottom = 17.0
	return b