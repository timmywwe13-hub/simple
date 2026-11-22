class_name Interactable
extends Node2D

## Base class for walk-up-and-press-E spots in the Town scene: the three
## shops and the Quest Giver. Subclasses override `_draw()` to paint their
## building/NPC and `interact()` to open their panel via `town.open_panel()`.
##
## Scene structure (children of Town, created in town.gd):
##   Interactable (Node2D, subclass script)   <- art is drawn in code

const PixFont := preload("res://scripts/pixel_font.gd")

@export var zone_radius := 78.0

var town: Node
var nearby := false


func setup(town_node: Node) -> void:
	town = town_node


func _process(_dt: float) -> void:
	nearby = town != null and town.player != null \
			and town.player.global_position.distance_to(global_position) < zone_radius
	queue_redraw()


## Override in subclasses: build a panel and call town.open_panel(root).
func interact() -> void:
	pass


## Override in subclasses: text shown in the prompt bubble.
func prompt_label() -> String:
	return "TALK"


## Override in subclasses: how far this node's art rises above its origin.
func art_height() -> float:
	return 90.0


## Shared prompt bubble; subclasses call this at the end of _draw().
func draw_prompt() -> void:
	if not nearby or town == null:
		return
	# Only the nearest walk-up draws a prompt. Before this, two shops close
	# together (the Harvest table and the Quest Giver) could show overlapping
	# bubbles when the player stood between them.
	if town.get("current") != self:
		return
	var bounce := sin(Time.get_ticks_msec() / 1000.0 * 5.0) * 2.0
	var sub := prompt_label()
	var w := maxf(PixFont.text_width("E", 2) + 4.0, PixFont.text_width(sub, 2)) + 20.0
	var h := 48.0
	var x := -w * 0.5
	var y := -art_height() - h - 12.0 + bounce
	var bg := Color("#0e1622", 0.9)
	_pixel_rect(Rect2(x, y, w, h), bg)
	_pixel_rect(Rect2(x, y, w, 3.0), GameTheme.CREAM)
	_pixel_rect(Rect2(x, y + h - 3.0, w, 3.0), GameTheme.CREAM)
	_pixel_rect(Rect2(x, y, 3.0, h), GameTheme.CREAM)
	_pixel_rect(Rect2(x + w - 3.0, y, 3.0, h), GameTheme.CREAM)
	_pixel_rect(Rect2(-6.0, y + h, 12.0, 6.0), bg)
	PixFont.draw_text_centered(self, 0.0, y + 8.0, "E", GameTheme.GOLD, 2, 1)
	PixFont.draw_text_centered(self, 0.0, y + 26.0, sub, GameTheme.CREAM, 2, 1)


func _pixel_rect(r: Rect2, c: Color) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	draw_rect(Rect2(snapped(r.position.x, 2.0), snapped(r.position.y, 2.0),
			maxf(2.0, snapped(r.size.x, 2.0)), maxf(2.0, snapped(r.size.y, 2.0))), c)