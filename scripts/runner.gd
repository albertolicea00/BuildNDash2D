## Player B character: auto-runs (the world scrolls), jumps and slides.
## Supports trampolines (big bounce) and a shield power-up (one free hit).
## Only the simulation authority runs physics; clients are positioned
## directly from synced state.
class_name Runner
extends CharacterBody2D

const GRAVITY := 2200.0
const JUMP_VELOCITY := -820.0
const BOUNCE_VELOCITY := -1150.0
const SLIDE_TIME := 0.6

signal died
signal shield_changed(active: bool)

var alive := true
var has_shield := false
var slide_left := 0.0

var _shape: CollisionShape2D
var _visual: Polygon2D
var _shield_ring: Polygon2D


func _ready() -> void:
	# Visual: neon cube with a glowing shield ring (original code-drawn art).
	_visual = Polygon2D.new()
	_visual.polygon = _rect_points(Vector2(44, 44))
	_visual.color = Color(0.0, 0.9, 1.0)
	add_child(_visual)

	var eye := Polygon2D.new()
	eye.polygon = _rect_points(Vector2(8, 8))
	eye.color = Color(0.05, 0.05, 0.1)
	eye.position = Vector2(10, -8)
	add_child(eye)

	_shield_ring = Polygon2D.new()
	_shield_ring.polygon = _circle(34.0, 24)
	_shield_ring.color = Color(1.0, 0.85, 0.2, 0.45)
	_shield_ring.visible = false
	add_child(_shield_ring)

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 44)
	_shape.shape = rect
	add_child(_shape)


static func _rect_points(size: Vector2) -> PackedVector2Array:
	var half := size / 2.0
	return PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)])


static func _circle(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func jump() -> void:
	if alive and is_on_floor():
		velocity.y = JUMP_VELOCITY


func slide() -> void:
	if alive and slide_left <= 0.0:
		slide_left = SLIDE_TIME
		# Halve the hitbox so the Runner fits under low obstacles.
		(_shape.shape as RectangleShape2D).size = Vector2(44, 22)
		_shape.position = Vector2(0, 11)
		_visual.scale = Vector2(1.0, 0.5)
		_visual.position = Vector2(0, 11)


func grant_shield() -> void:
	has_shield = true
	_shield_ring.visible = true
	shield_changed.emit(true)


## Called by the game world each physics frame, authority side only.
func step_physics(delta: float) -> void:
	if not alive:
		return
	if slide_left > 0.0:
		slide_left -= delta
		if slide_left <= 0.0:
			_end_slide()
	velocity.y += GRAVITY * delta
	move_and_slide()
	# Resolve contacts by gameplay group:
	#   hazard -> hit (spike), bounce -> trampoline,
	#   solid side hit -> hit (running face-first into a block).
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider == null:
			continue
		if collider.is_in_group("hazard"):
			_take_hit()
			return
		if collider.is_in_group("bounce"):
			velocity.y = BOUNCE_VELOCITY
		elif collider.is_in_group("solid") and collision.get_normal().x < -0.7:
			# The block pushed us backward: that's a face-first crash.
			_take_hit()
			return


func _end_slide() -> void:
	slide_left = 0.0
	(_shape.shape as RectangleShape2D).size = Vector2(44, 44)
	_shape.position = Vector2.ZERO
	_visual.scale = Vector2.ONE
	_visual.position = Vector2.ZERO


func _take_hit() -> void:
	# The shield absorbs exactly one hit, then the next one kills.
	if has_shield:
		has_shield = false
		_shield_ring.visible = false
		shield_changed.emit(false)
		return
	alive = false
	died.emit()


func reset(start_position: Vector2) -> void:
	position = start_position
	velocity = Vector2.ZERO
	alive = true
	has_shield = false
	_shield_ring.visible = false
	_end_slide()
