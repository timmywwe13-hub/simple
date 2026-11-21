class_name TownPlayer
extends CharacterBody2D

## Walking character used in the Town scene (and any other physical scene).
## WASD / arrow keys walk; movement eases in and out, the legs and arms
## swing in a proper walk cycle, and the boots kick up small dust puffs.
##
## Scene structure:
##   TownPlayer (CharacterBody2D, town_player.gd)
##   └─ CollisionShape2D (CircleShape2D, created in code)

@export var speed := 205.0
@export var acceleration := 1500.0
@export var friction := 1900.0

var facing := 1.0
var walk_phase := 0.0
var moving := false
var can_move := true
## The rectangle the walker is allowed to roam (set by Town on layout, so
## the character can never wander off-screen or behind the horizon).
var bounds := Rect2(-100000.0, -100000.0, 200000.0, 200000.0)

var move_ratio := 0.0
var last_step := 0
var dust: Array[Dictionary] = []


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	shape.position = Vector2(0.0, -14.0)
	add_child(shape)


func set_bounds(rect: Rect2) -> void:
	bounds = rect
	global_position = global_position.clamp(bounds.position, bounds.end)


func _physics_process(dt: float) -> void:
	var dir := Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up"))
	if dir.length() > 1.0:
		dir = dir.normalized()
	if dir.length() < 0.15 or not can_move:
		dir = Vector2.ZERO

	var target := dir * speed
	if not can_move:
		# Panels freeze the walker instantly so it never slides behind a shop.
		velocity = Vector2.ZERO
	else:
		var rate := acceleration if dir != Vector2.ZERO else friction
		velocity = velocity.move_toward(target, rate * dt)

	moving = can_move and velocity.length() > 6.0
	move_ratio = clampf(velocity.length() / speed, 0.0, 1.0)
	if moving:
		if absf(velocity.x) > 8.0:
			facing = 1.0 if velocity.x > 0.0 else -1.0
		walk_phase = fposmod(walk_phase + dt * (4.5 + 7.5 * move_ratio), TAU)
		var step_index := int(floor(walk_phase / PI))
		if step_index != last_step:
			last_step = step_index
			if move_ratio > 0.2:
				_spawn_dust(Vector2(global_position.x + (7.0 if step_index % 2 == 0 else -7.0),
						global_position.y))
	else:
		walk_phase = move_toward(walk_phase, 0.0, dt * 14.0)

	move_and_slide()
	var clamped := global_position.clamp(bounds.position, bounds.end)
	if not clamped.is_equal_approx(global_position):
		if not is_equal_approx(clamped.x, global_position.x):
			velocity.x = 0.0
		if not is_equal_approx(clamped.y, global_position.y):
			velocity.y = 0.0
		global_position = clamped

	_update_dust(dt)
	queue_redraw()


## Small dust puff under the boot that lands; stored in world space so the
## puffs stay behind while the walker moves on.
func _spawn_dust(pos: Vector2) -> void:
	dust.append({
		"pos": pos + Vector2(randf_range(-3.0, 3.0), -1.0),
		"vel": Vector2(-signf(velocity.x) * randf_range(6.0, 16.0), randf_range(-14.0, -6.0)),
		"life": randf_range(0.28, 0.42),
		"max_life": 0.4,
		"size": randf_range(2.0, 3.0),
	})
	if dust.size() > 26:
		dust.remove_at(0)


func _update_dust(dt: float) -> void:
	for i in range(dust.size() - 1, -1, -1):
		var d: Dictionary = dust[i]
		d["life"] = float(d["life"]) - dt
		if float(d["life"]) <= 0.0:
			dust.remove_at(i)
			continue
		d["pos"] = Vector2(d["pos"]) + Vector2(d["vel"]) * dt
		d["vel"] = Vector2(d["vel"]) * 0.9


func _pr(r: Rect2, c: Color) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	draw_rect(Rect2(snapped(r.position.x, 2.0), snapped(r.position.y, 2.0),
			maxf(2.0, snapped(r.size.x, 2.0)), maxf(2.0, snapped(r.size.y, 2.0))), c)


## Soft pixel shadow under the boots, so the walker feels planted.
func _draw_shadow(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var rows := maxi(2, int(ry / 2.0))
	for i in range(rows):
		var y := center.y - ry + (float(i) + 0.5) * (ry * 2.0 / float(rows))
		var dy := (y - center.y) / maxf(0.001, ry)
		var w := rx * sqrt(maxf(0.0, 1.0 - dy * dy))
		if w > 0.5:
			_pr(Rect2(center.x - w, y - 1.0, w * 2.0, 2.0), color)


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var stride := sin(walk_phase)
	var amp := 5.0 * move_ratio
	var step_bob := absf(sin(walk_phase)) * 2.2 * move_ratio
	var breathe := sin(t * 2.2) * 0.8 * (1.0 - move_ratio)
	var bob := step_bob + breathe

	_draw_shadow(Vector2(0.0, 1.0), 15.0 - move_ratio * 2.0, 4.5, Color(0.04, 0.07, 0.1, 0.26))
	for d in dust:
		var p := to_local(Vector2(d["pos"]))
		var a := clampf(float(d["life"]) / float(d["max_life"]), 0.0, 1.0) * 0.55
		var s := float(d["size"])
		_pr(Rect2(p.x - s * 0.5, p.y - s * 0.5, s, s), Color(0.86, 0.8, 0.66, a))

	draw_set_transform(Vector2(0.0, -bob), 0.0, Vector2(facing, 1.0))

	var lift_a := maxf(0.0, stride) * 4.0 * move_ratio
	var lift_b := maxf(0.0, -stride) * 4.0 * move_ratio

	# back arm (behind the torso)
	var arm_back := -stride * amp * 0.8
	_pr(Rect2(-13.0 + arm_back, -45.0, 6.0, 12.0), GameTheme.SHIRT_DARK)
	_pr(Rect2(-14.0 + arm_back * 1.4, -35.0, 7.0, 6.0), GameTheme.SKIN)

	# back leg, then the front leg: one foot lifts while the other plants
	_pr(Rect2(-9.0 - stride * amp * 0.7, -24.0, 7.0, 18.0 - lift_a), GameTheme.PANTS.darkened(0.12))
	_pr(Rect2(-11.0 - stride * amp, -8.0 - lift_a, 9.0, 5.0), GameTheme.BOOT.darkened(0.1))

	# torso + belt + shaded side
	_pr(Rect2(-11.0, -46.0, 22.0, 24.0), GameTheme.SHIRT)
	_pr(Rect2(-11.0, -28.0, 22.0, 4.0), GameTheme.BELT)
	_pr(Rect2(7.0, -45.0, 9.0, 15.0), GameTheme.SHIRT_DARK)
	_pr(Rect2(-6.0, -45.0, 2.0, 15.0), GameTheme.SHIRT.lightened(0.12))

	# front leg
	var arm_front := stride * amp * 0.3
	_pr(Rect2(2.0 + stride * amp * 0.7, -24.0, 7.0, 18.0 - lift_b), GameTheme.PANTS)
	_pr(Rect2(3.0 + stride * amp, -8.0 - lift_b, 9.0, 5.0), GameTheme.BOOT)

	# front arm
	_pr(Rect2(8.0 + arm_front, -45.0, 6.0, 11.0), GameTheme.SHIRT)
	_pr(Rect2(9.0 + arm_front * 1.4, -36.0, 7.0, 6.0), GameTheme.SKIN)

	# head, hair and eye
	_pr(Rect2(-7.0, -62.0, 15.0, 16.0), GameTheme.SKIN)
	_pr(Rect2(-8.0, -64.0, 16.0, 7.0), GameTheme.HAIR)
	_pr(Rect2(-9.0, -59.0, 3.0, 10.0), GameTheme.HAIR)
	_pr(Rect2(4.0, -66.0, 5.0, 4.0), GameTheme.HAIR)
	_pr(Rect2(3.0, -56.0, 3.0, 3.0), GameTheme.INK)
	_pr(Rect2(-7.0, -52.0, 3.0, 2.0), GameTheme.SKIN.darkened(0.12))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
