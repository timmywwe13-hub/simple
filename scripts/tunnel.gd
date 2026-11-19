class_name Tunnel
extends Node2D

const PixFont := preload("res://scripts/pixel_font.gd")

## Loading trigger. Walking into the tunnel (or touching it with a physics
## body such as the TownPlayer) swaps the current scene for `target_scene`.
##
## Scene structure:
##   Tunnel (Node2D, tunnel.gd)
##   └─ Trigger (Area2D)
##      └─ CollisionShape2D (RectangleShape2D, sized from `radius`)

@export var target_scene := "res://town.tscn"
@export var radius := 40.0
@export var sign := "TOWN"

const STONE := Color("#5a5462")
const STONE_DARK := Color("#3a3542")
const MOUTH := Color("#0b0f18")
const FRAME := Color("#6b543a")

var triggered := false


func _ready() -> void:
	var area := Area2D.new()
	area.name = "Trigger"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(radius * 1.5, radius * 1.5)
	shape.shape = rect
	shape.position = Vector2(0.0, -radius * 0.7)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node) -> void:
	_enter_tunnel()


## Manual check for drawn/2D characters that have no physics body
## (the fisher in the fishing scene). Returns true when `pos` is at the mouth.
func proximity_check(pos: Vector2) -> bool:
	return pos.distance_to(global_position) < radius


func _enter_tunnel() -> void:
	if triggered:
		return
	triggered = true
	GameState.travel(target_scene)


func _pr(r: Rect2, c: Color) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	draw_rect(Rect2(snapped(r.position.x, 2.0), snapped(r.position.y, 2.0),
			maxf(2.0, snapped(r.size.x, 2.0)), maxf(2.0, snapped(r.size.y, 2.0))), c)


func _draw() -> void:
	var w := radius * 0.9
	var opening_h := radius * 1.5
	# stone arch around a dark opening
	var cx := 0.0
	var top_y := -opening_h
	_pr(Rect2(cx - w - 10.0, top_y - 12.0, w + w + 20.0, 14.0), STONE_DARK)   # lintel
	_pr(Rect2(cx - w - 10.0, top_y, 10.0, opening_h + 12.0), STONE_DARK)     # left column
	_pr(Rect2(cx + w, top_y, 10.0, opening_h + 12.0), STONE_DARK)
	_pr(Rect2(cx - w - 10.0, top_y - 12.0, w + w + 20.0, 4.0), STONE)        # highlight
	_pr(Rect2(cx - w, top_y, w + w, opening_h), MOUTH)                        # opening
	var glow := Color("#2c4a66", 0.8)
	_pr(Rect2(cx - w * 0.55, top_y + opening_h * 0.45, w * 1.1, opening_h * 0.55), glow)
	# sign post
	_pr(Rect2(cx + w + 16.0, top_y + 40.0, 5.0, 46.0), FRAME)
	_pr(Rect2(cx + w + 2.0, top_y + 26.0, 46.0, 20.0), GameTheme.WOOD)
	_pr(Rect2(cx + w + 2.0, top_y + 26.0, 46.0, 4.0), GameTheme.WOOD_DARK)
	PixFont.draw_text_centered(self, cx + w + 25.0, top_y + 32.0, sign,
			GameTheme.CREAM, 2, 1)
	# ground shadow at the mouth
	_pr(Rect2(cx - w - 16.0, 0.0, w * 2.0 + 32.0, 5.0), Color("#000000", 0.25))