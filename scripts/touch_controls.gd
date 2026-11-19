extends CanvasLayer

## On-screen touch controls for phones and tablets.
##
## One full-rect Control draws translucent buttons (a movement pad, a big
## ACTION button, and small tap buttons) and raw InputEventScreenTouch
## input is hit-tested against the button rects, so multi-touch works
## (walk with the left thumb, cast with the right).
##
## Movement buttons feed the regular Input actions via Input.action_press,
## so main.gd / town_player.gd movement code works unchanged. Tap buttons
## latch a one-frame edge polled through consume_tap(), and the ACTION
## button additionally tracks action_held for the tug-of-war hold
## minigame.
##
## Touches are also emulated as mouse clicks by the engine
## (emulate_mouse_from_touch); blocks_click() lets gameplay code ignore
## clicks that land on a virtual button so pressing a button never also
## casts or hooks.

const PixFont := preload("res://scripts/pixel_font.gd")

var enabled := false
var mode := "fishing"
var context := "world"
var action_held := false
var action_label := "CAST"

var view_size := Vector2(960.0, 540.0)
var scale_f := 1.0
var buttons: Array = []

var _canvas: Control
var _active: Dictionary = {}  # pointer index -> button id
var _taps: Dictionary = {}    # button id -> process frame of the tap


func setup(p_mode: String) -> void:
	mode = p_mode
	layer = 20
	enabled = DisplayServer.is_touchscreen_available()
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_buttons)
	add_child(_canvas)
	get_viewport().size_changed.connect(relayout)
	relayout()


func relayout() -> void:
	view_size = get_viewport().get_visible_rect().size
	scale_f = clampf(view_size.y / 540.0, 0.75, 2.2)
	_build_buttons()
	if _canvas:
		_canvas.queue_redraw()


## Context decides which buttons show: e.g. only the ACTION button while
## reeling, everything while walking around.
func set_context(ctx: String) -> void:
	if context == ctx:
		return
	context = ctx
	_release_all()
	if _canvas:
		_canvas.queue_redraw()


func set_action_label(text: String) -> void:
	if action_label == text:
		return
	action_label = text
	if _canvas:
		_canvas.queue_redraw()


## One-frame tap edge; consuming clears it so each tap fires once.
func consume_tap(id: String) -> bool:
	if _taps.has(id) and Engine.get_process_frames() - int(_taps[id]) <= 1:
		_taps.erase(id)
		return true
	return false


## True when `pos` sits on a visible button, so gameplay code can ignore
## the emulated mouse click that comes with the touch.
func blocks_click(pos: Vector2) -> bool:
	if not enabled:
		return false
	for b in buttons:
		if _btn_visible(b) and (b["rect"] as Rect2).has_point(pos):
			return true
	return false


func _build_buttons() -> void:
	buttons.clear()
	var s := scale_f
	var w := view_size.x
	var h := view_size.y
	var pad_c := Vector2(118.0 * s, h - 118.0 * s)
	var arm := 66.0 * s
	var pad := 80.0 * s
	_add_move("pad_left", Rect2(pad_c.x - arm - pad * 0.5, pad_c.y - pad * 0.5, pad, pad),
			"move_left", "<", ["world", "fishing"])
	_add_move("pad_right", Rect2(pad_c.x + arm - pad * 0.5, pad_c.y - pad * 0.5, pad, pad),
			"move_right", ">", ["world", "fishing"])
	_add_move("pad_up", Rect2(pad_c.x - pad * 0.5, pad_c.y - arm - pad * 0.5, pad, pad),
			"move_up", "^", ["world", "fishing"])
	_add_move("pad_down", Rect2(pad_c.x - pad * 0.5, pad_c.y + arm - pad * 0.5, pad, pad),
			"move_down", "v", ["world", "fishing"])
	if mode == "fishing":
		_add_button("action", Rect2(w - 158.0 * s, h - 158.0 * s, 118.0 * s, 118.0 * s),
				"action", "", ["world", "fishing", "reel"], true)
		_add_button("rod", Rect2(w - 158.0 * s, h - 212.0 * s, 74.0 * s, 46.0 * s),
				"tap", "ROD", ["world"])
		_add_button("boat", Rect2(w - 78.0 * s, h - 212.0 * s, 74.0 * s, 46.0 * s),
				"tap", "BOAT", ["world"])
		_add_button("index", Rect2(w - 158.0 * s, 58.0 * s, 74.0 * s, 46.0 * s),
				"tap", "INDEX", ["world"])
		_add_button("menu", Rect2(w - 78.0 * s, 58.0 * s, 74.0 * s, 46.0 * s),
				"tap", "MENU", ["world", "fishing", "reel"])
		for i in range(4):
			_add_button("spot%d" % (i + 1),
					Rect2(18.0 * s, 58.0 * s + float(i) * 56.0 * s, 50.0 * s, 48.0 * s),
					"tap", str(i + 1), ["world"])
	else:
		_add_button("interact", Rect2(w - 158.0 * s, h - 158.0 * s, 118.0 * s, 118.0 * s),
				"tap", "TALK", ["world"], true)
		_add_button("menu", Rect2(w - 96.0 * s, 58.0 * s, 84.0 * s, 46.0 * s),
				"tap", "CLOSE", ["panel"])


func _add_move(id: String, rect: Rect2, action: String, label: String, ctxs: Array) -> void:
	buttons.append({"id": id, "rect": rect, "kind": "move", "action": action,
			"label": label, "contexts": ctxs, "round": false, "down": false})


func _add_button(id: String, rect: Rect2, kind: String, label: String, ctxs: Array,
		round := false) -> void:
	buttons.append({"id": id, "rect": rect, "kind": kind, "action": "",
			"label": label, "contexts": ctxs, "round": round, "down": false})


func _btn_visible(b: Dictionary) -> bool:
	return enabled and (b["contexts"] as Array).has(context)


func _button_at(pos: Vector2) -> Dictionary:
	for b in buttons:
		if _btn_visible(b) and (b["rect"] as Rect2).has_point(pos):
			return b
	return {}


func _button_by_id(id: String) -> Dictionary:
	for b in buttons:
		if String(b["id"]) == id:
			return b
	return {}


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			var b := _button_at(e.position)
			if not b.is_empty():
				_active[e.index] = String(b["id"])
				_press(b)
				get_viewport().set_input_as_handled()
		elif _active.has(e.index):
			var id := String(_active[e.index])
			_active.erase(e.index)
			var b := _button_by_id(id)
			if not b.is_empty():
				_release(b)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _active.has((event as InputEventScreenDrag).index):
		get_viewport().set_input_as_handled()


func _press(b: Dictionary) -> void:
	b["down"] = true
	match String(b["kind"]):
		"move":
			Input.action_press(String(b["action"]))
		"action":
			action_held = true
			_taps["action"] = Engine.get_process_frames()
		_:
			_taps[String(b["id"])] = Engine.get_process_frames()
	if _canvas:
		_canvas.queue_redraw()


func _release(b: Dictionary) -> void:
	b["down"] = false
	match String(b["kind"]):
		"move":
			Input.action_release(String(b["action"]))
		"action":
			action_held = _held_elsewhere("action")
	if _canvas:
		_canvas.queue_redraw()


func _held_elsewhere(id: String) -> bool:
	for k in _active:
		if String(_active[k]) == id:
			return true
	return false


func _release_all() -> void:
	for b in buttons:
		if bool(b["down"]):
			_release(b)
	_active.clear()
	action_held = false


func _draw_buttons() -> void:
	if not enabled:
		return
	for b in buttons:
		if not _btn_visible(b):
			continue
		var r := b["rect"] as Rect2
		var down := bool(b["down"])
		var fill := Color(1.0, 0.92, 0.7, 0.42) if down else Color(0.06, 0.1, 0.16, 0.38)
		var border := Color(1.0, 0.95, 0.8, 0.9) if down else Color(0.96, 0.92, 0.84, 0.5)
		if bool(b["round"]):
			_canvas.draw_circle(r.get_center(), r.size.x * 0.5, fill)
			_canvas.draw_arc(r.get_center(), r.size.x * 0.5, 0.0, TAU, 32, border, 2.0)
		else:
			_canvas.draw_rect(r, fill, true)
			_canvas.draw_rect(r, border, false, 2.0)
		var label := String(b["label"])
		if String(b["id"]) == "action":
			label = action_label
		if label != "":
			var ps := 2 if label.length() > 3 else 3
			PixFont.draw_text_centered(_canvas, r.get_center().x,
					r.get_center().y - float(ps) * 4.0, label, Color(1.0, 1.0, 1.0, 0.85), ps, 1)
