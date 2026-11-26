extends CanvasLayer

## On-screen touch controls for phones and tablets (v1.7).
##
## A virtual thumb-stick replaces the old four-arrow pad: drag anywhere in
## the stick zone and the vector is exposed as `stick` (with a dead zone
## and analog strength). Keyboard input keeps working because the stick is
## additive in the movement code, not a replacement for Input actions.
##
## A big contextual ACTION button (cast / hook / reel / hold / talk), a few
## small tap buttons that only appear in the contexts that use them, and a
## rotate-device overlay in portrait.
##
## Safe-area insets from DisplayServer.get_display_safe_area() keep every
## control out from under a notch, and all targets are at least 48dp.
## Touch is enabled when the OS reports a touchscreen OR the first real
## touch arrives, unless the player forced it on/off in Settings.
##
## Touches are also emulated as mouse clicks by the engine
## (emulate_mouse_from_touch); blocks_click() lets gameplay code ignore
## clicks that land on a control so pressing a button never also casts.

const PixFont := preload("res://scripts/pixel_font.gd")

const DEAD_ZONE := 0.18
const STICK_RADIUS := 66.0
const MIN_TARGET := 48.0

var enabled := false
var mode := "fishing"
var context := "world"
var action_held := false
var action_label := "CAST"
## Analog movement vector from the thumb-stick (-1..1 on each axis).
var stick := Vector2.ZERO

var view_size := Vector2(960.0, 540.0)
var scale_f := 1.0
var buttons: Array = []
var portrait := false

var _canvas: Control
var _active := {}       # pointer index -> button id
var _taps := {}         # button id -> process frame of the tap
var _stick_pointer := -1
var _stick_origin := Vector2.ZERO
var _stick_center := Vector2.ZERO
var _stick_radius := STICK_RADIUS
var _touch_seen := false
var _settings_mode := ""


func setup(p_mode: String) -> void:
	mode = p_mode
	layer = 20
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	get_viewport().size_changed.connect(relayout)
	sync_settings(true)
	relayout()


## Recompute enablement from the settings override + hardware. Called every
## frame by the scenes (cheap) and immediately when Settings changes.
func sync_settings(force := false) -> void:
	var m := GameState.touch_ui_mode()
	if not force and m == _settings_mode:
		return
	_settings_mode = m
	var want := false
	match m:
		"on":
			want = true
		"off":
			want = false
		_:
			want = DisplayServer.is_touchscreen_available() or _touch_seen
	if want == enabled:
		return
	enabled = want
	_release_all()
	relayout()


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	_release_all()
	relayout()


func relayout() -> void:
	view_size = get_viewport().get_visible_rect().size
	scale_f = clampf(minf(view_size.x / 960.0, view_size.y / 540.0), 0.68, 2.2)
	portrait = view_size.y > view_size.x * 1.02
	_build_buttons()
	if _canvas:
		_canvas.queue_redraw()


## Context decides which controls show: e.g. only ACTION + MENU while
## reeling, nothing at all under a full-screen panel.
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


## True when `pos` sits on a visible control, so gameplay code can ignore
## the emulated mouse click that comes with the touch.
func blocks_click(pos: Vector2) -> bool:
	if not enabled or portrait:
		return false
	if _stick_visible() and pos.distance_to(_stick_center) <= _stick_radius + 18.0 * scale_f:
		return true
	for b in buttons:
		if _btn_visible(b) and (b["rect"] as Rect2).has_point(pos):
			return true
	return false


func _process(_dt: float) -> void:
	# share the analog vector with town_player.gd (which has no touch node)
	GameState.touch_vector = stick


## --- layout -----------------------------------------------------------
func _safe_insets() -> Dictionary:
	var out := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if DisplayServer.get_name() == "headless":
		return out
	# safe-area insets only matter on handheld/notched devices
	var mobile := OS.has_feature("mobile") or OS.has_feature("web_android") 			or OS.has_feature("web_ios")
	if not mobile:
		return out
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return out
	var win := get_window().size
	if win.x <= 0 or win.y <= 0:
		return out
	var sx := float(win.x) / float(screen.x)
	var sy := float(win.y) / float(screen.y)
	out["left"] = maxf(0.0, float(safe.position.x)) * sx
	out["top"] = maxf(0.0, float(safe.position.y)) * sy
	out["right"] = maxf(0.0, float(screen.x - safe.end.x)) * sx
	out["bottom"] = maxf(0.0, float(screen.y - safe.end.y)) * sy
	return out


func _build_buttons() -> void:
	buttons.clear()
	if not enabled:
		return
	var s := scale_f
	var safe := _safe_insets()
	var ml := 18.0 * s + float(safe["left"])
	var mr := 18.0 * s + float(safe["right"])
	var mt := 14.0 * s + float(safe["top"])
	var mb := 18.0 * s + float(safe["bottom"])
	var w := view_size.x
	var h := view_size.y
	var target := maxf(MIN_TARGET * s, 48.0)

	# thumb-stick zone (bottom-left)
	_stick_radius = maxf(STICK_RADIUS * s, 56.0)
	_stick_center = Vector2(ml + _stick_radius + 12.0 * s, h - mb - _stick_radius - 6.0 * s)

	var action_d := maxf(104.0 * s, 72.0)
	var action_c := Vector2(w - mr - action_d * 0.5, h - mb - action_d * 0.5)
	if mode == "fishing":
		_add_button("action", Rect2(action_c - Vector2(action_d, action_d) * 0.5,
				Vector2(action_d, action_d)), "action", "", ["world", "fishing", "reel"], true)
	else:
		_add_button("interact", Rect2(action_c - Vector2(action_d, action_d) * 0.5,
				Vector2(action_d, action_d)), "tap", "TALK", ["world"], true)

	# small context buttons above the action button (min 48dp each). Keep
	# every utility in this one row: the old top-right INDEX/MENU pair sat
	# on top of the boat/bait/set-line HUD as soon as the Harvest banner
	# pushed that readout down.
	var small_w := maxf(target, 62.0 * s)
	var small_h := maxf(target, 44.0 * s)
	var row_y := action_c.y - action_d * 0.5 - small_h - 10.0 * s
	var row_x := w - mr - small_w * 6.0 - 8.0 * s * 5.0
	if mode == "fishing":
		_add_button("rod", Rect2(row_x, row_y, small_w, small_h), "tap", "ROD", ["world"])
		_add_button("boat", Rect2(row_x + (small_w + 8.0 * s), row_y, small_w, small_h),
				"tap", "BOAT", ["world"])
		_add_button("axe", Rect2(row_x + (small_w + 8.0 * s) * 2.0, row_y, small_w, small_h),
				"tap", "AXE", ["world"])
		_add_button("line", Rect2(row_x + (small_w + 8.0 * s) * 3.0, row_y, small_w, small_h),
				"tap", "LINE", ["world"])
		_add_button("index", Rect2(row_x + (small_w + 8.0 * s) * 4.0, row_y, small_w, small_h),
				"tap", "IDX", ["world"])
		_add_button("menu", Rect2(row_x + (small_w + 8.0 * s) * 5.0, row_y, small_w, small_h),
				"tap", "MENU", ["world", "fishing", "reel"])
		# The four fishing spots run down the left edge. On short screens
		# (landscape phones) there is not enough room above the thumb-stick,
		# so use a single row instead of a column.
		var spot_h := maxf(target, 46.0 * s)
		if h < 540.0:
			var gap := 6.0 * s
			var spot_y := mt + 112.0
			for i in range(4):
				_add_button("spot%d" % (i + 1),
						Rect2(ml + float(i) * (spot_h + gap), spot_y, spot_h, spot_h),
						"tap", str(i + 1), ["world"])
		else:
			var spot_y := mt + 140.0 * s
			for i in range(4):
				_add_button("spot%d" % (i + 1),
						Rect2(ml, spot_y + float(i) * (spot_h + 6.0 * s), spot_h, spot_h),
						"tap", str(i + 1), ["world"])
	else:
		var menu_w := maxf(target, 78.0 * s)
		_add_button("menu", Rect2(w - mr - menu_w, mt, menu_w, maxf(target, 44.0 * s)),
				"tap", "CLOSE", ["world", "panel"])

	# keep the stick inside the safe bottom edge
	if _stick_center.y + _stick_radius > h - mb:
		_stick_center.y = h - mb - _stick_radius


func _add_button(id: String, rect: Rect2, kind: String, label: String, ctxs: Array,
		round := false) -> void:
	buttons.append({"id": id, "rect": rect, "kind": kind, "action": "",
			"label": label, "contexts": ctxs, "round": round, "down": false})


func _btn_visible(b: Dictionary) -> bool:
	return enabled and not portrait and (b["contexts"] as Array).has(context)


func _stick_visible() -> bool:
	return enabled and not portrait and (context == "world")


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


## --- input ------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if not _touch_seen:
			_touch_seen = true
			sync_settings(true)
		if not enabled or portrait:
			return
		if e.pressed:
			if _stick_visible() and e.position.distance_to(_stick_center) <= _stick_radius + 24.0 * scale_f:
				_stick_pointer = e.index
				_stick_origin = _stick_center
				_update_stick(e.position)
				get_viewport().set_input_as_handled()
				return
			var b := _button_at(e.position)
			if not b.is_empty():
				_active[e.index] = String(b["id"])
				_press(b)
				get_viewport().set_input_as_handled()
		else:
			if e.index == _stick_pointer:
				_stick_pointer = -1
				stick = Vector2.ZERO
				get_viewport().set_input_as_handled()
			elif _active.has(e.index):
				var id := String(_active[e.index])
				_active.erase(e.index)
				var b := _button_by_id(id)
				if not b.is_empty():
					_release(b)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_pointer:
			_update_stick(d.position)
			get_viewport().set_input_as_handled()


func _update_stick(pos: Vector2) -> void:
	var off := pos - _stick_origin
	var v := off / _stick_radius
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() < DEAD_ZONE:
		stick = Vector2.ZERO
		return
	# rescale past the dead zone so the stick is analog but responsive
	var strength := (v.length() - DEAD_ZONE) / (1.0 - DEAD_ZONE)
	stick = v.normalized() * clampf(strength, 0.0, 1.0)


func _press(b: Dictionary) -> void:
	b["down"] = true
	match String(b["kind"]):
		"action":
			action_held = true
			_taps["action"] = Engine.get_process_frames()
		_:
			_taps[String(b["id"])] = Engine.get_process_frames()
	if _canvas:
		_canvas.queue_redraw()


func _release(b: Dictionary) -> void:
	b["down"] = false
	if String(b["kind"]) == "action":
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
	stick = Vector2.ZERO
	_stick_pointer = -1


## --- drawing ----------------------------------------------------------
func _draw_controls() -> void:
	if not enabled:
		return
	if portrait:
		_draw_rotate_overlay()
		return
	if _stick_visible():
		_draw_stick()
	for b in buttons:
		if not _btn_visible(b):
			continue
		var r := b["rect"] as Rect2
		var down := bool(b["down"])
		var fill := Color(1.0, 0.92, 0.7, 0.42) if down else Color(0.06, 0.1, 0.16, 0.40)
		var border := Color(1.0, 0.95, 0.8, 0.9) if down else Color(0.96, 0.92, 0.84, 0.55)
		if bool(b["round"]):
			_canvas.draw_circle(r.get_center(), r.size.x * 0.5, fill)
			_canvas.draw_arc(r.get_center(), r.size.x * 0.5, 0.0, TAU, 40, border, 2.0)
		else:
			_canvas.draw_rect(r, fill, true)
			_canvas.draw_rect(r, border, false, 2.0)
		var label := String(b["label"])
		if String(b["id"]) == "action":
			label = action_label
		if label != "":
			var ps := 3
			while ps > 1 and PixFont.text_width(label, ps) > r.size.x - 10.0:
				ps -= 1
			PixFont.draw_text_centered(_canvas, r.get_center().x,
					r.get_center().y - float(ps) * 4.0, label, Color(1.0, 1.0, 1.0, 0.9), ps, 1)


func _draw_stick() -> void:
	var base := Color(0.06, 0.1, 0.16, 0.34)
	var ring := Color(0.96, 0.92, 0.84, 0.42)
	_canvas.draw_circle(_stick_center, _stick_radius, base)
	_canvas.draw_arc(_stick_center, _stick_radius, 0.0, TAU, 48, ring, 2.0)
	_canvas.draw_arc(_stick_center, _stick_radius * DEAD_ZONE, 0.0, TAU, 28,
			Color(0.96, 0.92, 0.84, 0.18), 1.0)
	var knob := _stick_center + stick * _stick_radius * 0.72
	_canvas.draw_circle(knob, _stick_radius * 0.34, Color(1.0, 0.95, 0.82, 0.55))
	_canvas.draw_arc(knob, _stick_radius * 0.34, 0.0, TAU, 28, Color(1.0, 0.97, 0.88, 0.85), 2.0)


## Portrait warning: the game is landscape-only, so ask for a rotate.
func _draw_rotate_overlay() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.04, 0.07, 0.11, 0.90), true)
	var cx := view_size.x * 0.5
	var cy := view_size.y * 0.5
	# a little phone, tilting
	var s := minf(view_size.x, view_size.y) * 0.10
	var phone := Rect2(cx - s * 0.5, cy - s * 1.3, s, s * 1.8)
	_canvas.draw_rect(phone, Color(0.86, 0.92, 0.98, 0.9), false, 3.0)
	_canvas.draw_rect(Rect2(phone.position.x + s * 0.2, phone.position.y + s * 0.2,
			s * 0.6, s * 1.3), Color(0.86, 0.92, 0.98, 0.35), true)
	var ps := 4 if view_size.x > 420.0 else 3
	PixFont.draw_text_centered(_canvas, cx, cy + s * 1.2,
			"ROTATE YOUR DEVICE", GameTheme.GOLD, ps, 1)
	PixFont.draw_text_centered(_canvas, cx, cy + s * 1.2 + 40.0,
			"COTTAGE CREEK IS PLAYED IN LANDSCAPE", GameTheme.SUBTEXT, 2, 1)
