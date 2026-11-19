class_name TownPlayer
extends CharacterBody2D

## Walking character used in the Town scene (and any other physical scene).
## WASD / arrow keys walk; the pixel fisher sprite bobs while moving.
##
## Scene structure:
##   TownPlayer (CharacterBody2D, town_player.gd)
##   └─ CollisionShape2D (CircleShape2D, created in code)

@export var speed := 200.0

var facing := 1.0
var walk_phase := 0.0
var moving := false
var can_move := true


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	shape.position = Vector2(0.0, -14.0)
	add_child(shape)


func _physics_process(dt: float) -> void:
	var dir := Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up"))
	moving = dir.length() > 0.1 and can_move
	if moving:
		velocity = dir.normalized() * speed
		if absf(dir.x) > 0.1:
			facing = 1.0 if dir.x > 0.0 else -1.0
		walk_phase = fposmod(walk_phase + dt * 10.0, TAU)
	else:
		velocity = Vector2.ZERO
		walk_phase = move_toward(walk_phase, 0.0, dt * 20.0)
	move_and_slide()
	queue_redraw()


func _pr(r: Rect2, c: Color) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	draw_rect(Rect2(snapped(r.position.x, 2.0), snapped(r.position.y, 2.0),
			maxf(2.0, snapped(r.size.x, 2.0)), maxf(2.0, snapped(r.size.y, 2.0))), c)


func _draw() -> void:
	var bob := absf(sin(walk_phase)) * 2.0 if moving else sin(Time.get_ticks_msec() / 1000.0 * 2.0) * 1.5
	var swing := sin(walk_phase) * 2.0 if moving else 0.0
	draw_set_transform(Vector2(0.0, -bob), 0.0, Vector2(facing, 1.0))
	# same pixel-fisher construction as the fishing scene
	_pr(Rect2(-10.0 - swing, -24.0, 7.0, 20.0), GameTheme.PANTS)
	_pr(Rect2(3.0 + swing, -24.0, 7.0, 20.0), GameTheme.PANTS)
	_pr(Rect2(-12.0 - swing, -6.0, 9.0, 6.0), GameTheme.BOOT)
	_pr(Rect2(3.0 + swing, -6.0, 9.0, 6.0), GameTheme.BOOT)
	_pr(Rect2(-11.0, -46.0, 22.0, 24.0), GameTheme.SHIRT)
	_pr(Rect2(-11.0, -28.0, 22.0, 4.0), GameTheme.BELT)
	_pr(Rect2(7.0, -45.0, 9.0, 15.0), GameTheme.SHIRT_DARK)
	_pr(Rect2(-7.0, -62.0, 15.0, 16.0), GameTheme.SKIN)
	_pr(Rect2(-8.0, -64.0, 16.0, 7.0), GameTheme.HAIR)
	_pr(Rect2(-9.0, -59.0, 3.0, 10.0), GameTheme.HAIR)
	_pr(Rect2(3.0, -56.0, 3.0, 3.0), GameTheme.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)