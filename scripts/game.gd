## BuildNDash2D game world. See AGENTS.md for the full spec.
##
## Authority model:
##   - LOCAL / HOST: this node owns the level timeline, scroll speed,
##     runner physics, placed objects and moving platforms.
##   - CLIENT: renders synced state and forwards Builder Pro requests.
## Role assignment in network modes: host = Runner, client = Builder Pro
## (the Runner needs zero input latency, so it always runs on the host).
extends Node2D

const VIEW := Vector2(1280, 720)
const GROUND_TOP := 660.0
const RUNNER_X := 300.0
const RUNNER_START := Vector2(300.0, 600.0)
const BASE_SPEED := 280.0
const SPEED_GAIN := 6.0          # px/s gained per second (server timeline)
const MAX_SPEED := 560.0
const GRID_SNAP := 40.0
const MIN_PLACE_AHEAD := 180.0   # objects must land ahead of the Runner
const PICKUP_RADIUS := 50.0
const BEAT_INTERVAL := 0.469     # ~128 BPM, drives the EDM pulse

signal exited

var runner: Runner
var builder: BuilderPro
var scroll_root: Node2D          # all placed objects live here and scroll left
var timeline := 0.0              # server-owned level clock (drives speed + FX)
var speed := BASE_SPEED
var score := 0                   # distance in meters (10 px = 1 m)
var distance := 0.0
var playing := true
var next_object_id := 0
## Host-side cooldown tracking for the remote Builder Pro.
var remote_cooldown := 0.0
var beat_timer := 0.0

var background: ColorRect
var flash: ColorRect
var hud: CanvasLayer
var score_label: Label
var cooldown_bar: ProgressBar
var shield_label: Label
var over_box: VBoxContainer
var over_label: Label


func _ready() -> void:
	_build_world()
	_build_players()
	_build_hud()


# --- Scene construction (all original code-drawn neon art) ------------------

func _build_world() -> void:
	background = ColorRect.new()
	background.color = Color(0.08, 0.03, 0.14)
	background.size = VIEW
	add_child(background)

	scroll_root = Node2D.new()
	add_child(scroll_root)

	# Ground: a solid neon strip the Runner runs on. It never scrolls
	# (the world moves instead), so one static body covers everything.
	var ground := StaticBody2D.new()
	ground.add_to_group("solid")
	ground.position = Vector2(VIEW.x / 2.0, GROUND_TOP + 30.0)
	var visual := Polygon2D.new()
	visual.polygon = Runner._rect_points(Vector2(VIEW.x, 60))
	visual.color = Color(0.15, 0.1, 0.3)
	ground.add_child(visual)
	var glow_line := Polygon2D.new()
	glow_line.polygon = Runner._rect_points(Vector2(VIEW.x, 4))
	glow_line.color = Color(0.0, 0.9, 1.0)
	glow_line.position = Vector2(0, -30)
	ground.add_child(glow_line)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(VIEW.x, 60)
	shape.shape = rect
	ground.add_child(shape)
	add_child(ground)

	# Beat flash overlay (EDM pulse), drawn above the world, below the HUD.
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = VIEW
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)


func _build_players() -> void:
	runner = Runner.new()
	runner.position = RUNNER_START
	runner.died.connect(_on_runner_died)
	add_child(runner)

	builder = BuilderPro.new()
	# Role wiring per mode: in LOCAL both roles share the device; in HOST
	# the Builder Pro is the remote client, so the local one is disabled.
	match Net.mode:
		Net.Mode.LOCAL:
			builder.local_split = true
		Net.Mode.HOST:
			builder.active = false
		Net.Mode.CLIENT:
			builder.local_split = false
	builder.place_requested.connect(_on_place_requested)
	add_child(builder)


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	score_label = Label.new()
	score_label.text = "0 m"
	score_label.add_theme_font_size_override("font_size", 48)
	score_label.position = Vector2(VIEW.x / 2.0 - 50, 20)
	hud.add_child(score_label)

	shield_label = Label.new()
	shield_label.text = "SHIELD"
	shield_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	shield_label.position = Vector2(24, 24)
	shield_label.visible = false
	hud.add_child(shield_label)
	runner.shield_changed.connect(
		func(active: bool) -> void: shield_label.visible = active)

	var is_builder := Net.mode != Net.Mode.HOST

	cooldown_bar = ProgressBar.new()
	cooldown_bar.size = Vector2(220, 18)
	cooldown_bar.position = Vector2(VIEW.x - 244, VIEW.y - 36)
	cooldown_bar.show_percentage = false
	cooldown_bar.visible = is_builder
	hud.add_child(cooldown_bar)

	# Toolbar: the Builder Pro's advanced tools, one toggle per tool.
	if is_builder:
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 6)
		bar.position = Vector2(VIEW.x - 560, VIEW.y - 96)
		hud.add_child(bar)
		var group := ButtonGroup.new()
		var names := {
			BuilderPro.Tool.BLOCK: "Block",
			BuilderPro.Tool.SPIKE: "Spike",
			BuilderPro.Tool.TRAMPOLINE: "Tramp",
			BuilderPro.Tool.MOVING_PLATFORM: "Mover",
			BuilderPro.Tool.SHIELD: "Shield",
		}
		for tool_id: int in names:
			var btn := Button.new()
			btn.text = names[tool_id]
			btn.toggle_mode = true
			btn.button_group = group
			btn.custom_minimum_size = Vector2(100, 48)
			btn.button_pressed = tool_id == builder.tool
			btn.pressed.connect(func() -> void: builder.tool = tool_id)
			bar.add_child(btn)

	# Game-over panel, hidden until the run ends.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(center)
	over_box = VBoxContainer.new()
	over_box.add_theme_constant_override("separation", 10)
	over_box.visible = false
	center.add_child(over_box)
	over_label = Label.new()
	over_label.add_theme_font_size_override("font_size", 40)
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_box.add_child(over_label)
	var restart := Button.new()
	restart.text = "Restart"
	restart.custom_minimum_size = Vector2(220, 48)
	restart.pressed.connect(_on_restart_pressed)
	over_box.add_child(restart)
	var quit := Button.new()
	quit.text = "Back to Menu"
	quit.custom_minimum_size = Vector2(220, 48)
	quit.pressed.connect(func() -> void: exited.emit())
	over_box.add_child(quit)


# --- Runner input ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not playing or Net.mode == Net.Mode.CLIENT:
		return  # the client is the Builder Pro; it never controls the Runner
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_UP, KEY_W: runner.jump()
			KEY_DOWN, KEY_S: runner.slide()
		return
	# Touch: tap = jump, swipe down = slide. In local split-screen mode only
	# the LEFT half belongs to the Runner.
	var half := get_viewport().get_visible_rect().size.x * 0.5
	if event is InputEventScreenTouch and event.pressed:
		if Net.mode == Net.Mode.LOCAL and event.position.x >= half:
			return
		runner.jump()
	elif event is InputEventScreenDrag and event.relative.y > 30.0:
		if Net.mode == Net.Mode.LOCAL and event.position.x >= half:
			return
		runner.slide()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if Net.mode == Net.Mode.LOCAL and event.position.x >= half:
			return
		runner.jump()


# --- Simulation ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	remote_cooldown = maxf(remote_cooldown - delta, 0.0)
	cooldown_bar.value = (1.0 - builder.cooldown_left / BuilderPro.COOLDOWN) * 100.0
	_update_fx(delta)
	if not playing:
		return

	# Both sides advance the timeline locally for smooth visuals; the host's
	# sync corrects drift on the client.
	timeline += delta
	speed = minf(BASE_SPEED + timeline * SPEED_GAIN, MAX_SPEED)
	scroll_root.position.x -= speed * delta
	_update_moving_platforms()

	if Net.mode == Net.Mode.CLIENT:
		return

	runner.step_physics(delta)
	distance += speed * delta
	var meters := int(distance / 10.0)
	if meters != score:
		score = meters
		score_label.text = "%d m" % score

	_check_pickups()
	_cleanup_passed_objects()

	if Net.mode == Net.Mode.HOST:
		_sync.rpc(runner.position, runner.velocity, scroll_root.position.x,
			timeline, score, runner.has_shield)


func _update_fx(delta: float) -> void:
	# EDM visuals: the background hue drifts with the timeline and the
	# screen flashes softly on every beat (~128 BPM).
	background.color = Color.from_hsv(
		fmod(0.7 + timeline * 0.02, 1.0), 0.75, 0.16)
	beat_timer -= delta
	if beat_timer <= 0.0 and playing:
		beat_timer = BEAT_INTERVAL
		flash.color.a = 0.10
	flash.color.a = maxf(flash.color.a - delta * 0.5, 0.0)


func _update_moving_platforms() -> void:
	# Deterministic motion from the shared timeline: both peers compute the
	# exact same platform positions without per-frame sync traffic.
	for platform in get_tree().get_nodes_in_group("moving"):
		var base_y: float = platform.get_meta("base_y")
		var phase: float = platform.get_meta("phase")
		platform.position.y = base_y + sin(timeline * 2.6 + phase) * 90.0


func _check_pickups() -> void:
	# Shield pickups use a simple radius check instead of physics areas:
	# robust, cheap, and identical on every platform.
	for pickup in get_tree().get_nodes_in_group("pickup"):
		var pickup_global: Vector2 = pickup.position + scroll_root.position
		if runner.alive and pickup_global.distance_to(runner.position) < PICKUP_RADIUS:
			runner.grant_shield()
			var pickup_name := String(pickup.name)
			pickup.queue_free()
			if Net.mode == Net.Mode.HOST:
				_consume_pickup_remote.rpc(pickup_name)


@rpc("authority", "call_remote", "reliable")
func _consume_pickup_remote(node_name: String) -> void:
	var node := scroll_root.get_node_or_null(NodePath(node_name))
	if node != null:
		node.queue_free()


func _cleanup_passed_objects() -> void:
	for obj in get_tree().get_nodes_in_group("placed"):
		if obj.position.x + scroll_root.position.x < -300.0:
			obj.queue_free()


# --- Builder Pro placement -----------------------------------------------------

func _on_place_requested(screen_pos: Vector2, tool: int) -> void:
	if Net.mode == Net.Mode.CLIENT:
		# Forward to the host; the host validates and spawns authoritatively.
		_request_place.rpc_id(1, screen_pos, tool)
	else:
		_try_place(screen_pos, tool)


@rpc("any_peer", "call_remote", "reliable")
func _request_place(screen_pos: Vector2, tool: int) -> void:
	# Runs on the host when the remote Builder Pro taps.
	if not playing:
		return
	if Net.strict_validation:
		# "Local Server" mode: never trust the client. Re-check the cooldown,
		# the tool id, the bounds, and force placements ahead of the Runner.
		if remote_cooldown > 0.0:
			return
		if tool < 0 or tool > BuilderPro.Tool.SHIELD:
			return
		if screen_pos.x < runner.position.x + MIN_PLACE_AHEAD \
				or screen_pos.x > VIEW.x or screen_pos.y < 0.0 \
				or screen_pos.y > GROUND_TOP:
			return
	remote_cooldown = BuilderPro.COOLDOWN
	_try_place(screen_pos, tool)


func _try_place(screen_pos: Vector2, tool: int) -> void:
	# Snap to the build grid and keep placements ahead of the Runner so the
	# Builder can help (or challenge) but never instakill by dropping on top.
	var snapped_pos := screen_pos.snappedf(GRID_SNAP)
	if snapped_pos.x < runner.position.x + MIN_PLACE_AHEAD:
		return
	snapped_pos.y = minf(snapped_pos.y, GROUND_TOP - 20.0)
	# Convert into scroll-space so the object travels with the level.
	var world_pos: Vector2 = snapped_pos - scroll_root.position
	var id := next_object_id
	next_object_id += 1
	_spawn_object(id, tool, world_pos)
	if Net.mode == Net.Mode.HOST:
		_spawn_object_remote.rpc(id, tool, world_pos)


@rpc("authority", "call_remote", "reliable")
func _spawn_object_remote(id: int, tool: int, world_pos: Vector2) -> void:
	_spawn_object(id, tool, world_pos)


func _spawn_object(id: int, tool: int, world_pos: Vector2) -> void:
	var node: Node2D
	match tool:
		BuilderPro.Tool.BLOCK:
			node = _make_body(Vector2(80, 80), Color(0.55, 0.1, 0.9), "solid")
		BuilderPro.Tool.SPIKE:
			node = _make_spike()
		BuilderPro.Tool.TRAMPOLINE:
			node = _make_body(Vector2(80, 20), Color(1.0, 0.3, 0.65), "bounce")
		BuilderPro.Tool.MOVING_PLATFORM:
			node = _make_body(Vector2(120, 20), Color(0.0, 0.9, 1.0), "solid")
			node.add_to_group("moving")
			node.set_meta("base_y", world_pos.y)
			node.set_meta("phase", randf() * TAU if Net.is_authority() else float(id))
		BuilderPro.Tool.SHIELD:
			node = _make_pickup()
		_:
			return
	node.name = "obj_%d" % id  # stable name so pickup consumption replicates
	node.add_to_group("placed")
	node.position = world_pos
	scroll_root.add_child(node)


## Helper: solid rectangle body with a flat neon visual, grouped by role.
func _make_body(size: Vector2, color: Color, group: String) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.add_to_group(group)
	var visual := Polygon2D.new()
	visual.polygon = Runner._rect_points(size)
	visual.color = color
	body.add_child(visual)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	return body


func _make_spike() -> StaticBody2D:
	var body := StaticBody2D.new()
	body.add_to_group("hazard")
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-22, 20), Vector2(0, -24), Vector2(22, 20)])
	visual.color = Color(1.0, 0.18, 0.55)
	body.add_child(visual)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 30)  # slightly forgiving hitbox
	shape.shape = rect
	body.add_child(shape)
	return body


func _make_pickup() -> Node2D:
	# Pickups are visual-only nodes; collection is a radius check.
	var node := Node2D.new()
	node.add_to_group("pickup")
	var visual := Polygon2D.new()
	visual.polygon = Runner._circle(18.0, 16)
	visual.color = Color(1.0, 0.85, 0.2)
	node.add_child(visual)
	return node


# --- Game over / restart --------------------------------------------------------

func _on_runner_died() -> void:
	_show_game_over()
	if Net.mode == Net.Mode.HOST:
		_game_over_remote.rpc(score)


@rpc("authority", "call_remote", "reliable")
func _game_over_remote(final_score: int) -> void:
	score = final_score
	_show_game_over()


func _show_game_over() -> void:
	playing = false
	over_label.text = "Game Over — Distance: %d m" % score
	over_box.visible = true


func _on_restart_pressed() -> void:
	if Net.mode == Net.Mode.CLIENT:
		_request_restart.rpc_id(1)  # only the host may restart the match
	else:
		_restart()
		if Net.mode == Net.Mode.HOST:
			_restart_remote.rpc()


@rpc("any_peer", "call_remote", "reliable")
func _request_restart() -> void:
	if not playing:
		_restart()
		_restart_remote.rpc()


@rpc("authority", "call_remote", "reliable")
func _restart_remote() -> void:
	_restart()


func _restart() -> void:
	for node in get_tree().get_nodes_in_group("placed"):
		node.queue_free()
	scroll_root.position = Vector2.ZERO
	runner.reset(RUNNER_START)
	timeline = 0.0
	speed = BASE_SPEED
	distance = 0.0
	score = 0
	score_label.text = "0 m"
	shield_label.visible = false
	over_box.visible = false
	playing = true


# --- Client-side state sync ------------------------------------------------------

@rpc("authority", "call_remote", "unreliable")
func _sync(runner_pos: Vector2, runner_vel: Vector2, scroll_x: float,
		host_timeline: float, new_score: int, shield: bool) -> void:
	runner.position = runner_pos
	runner.velocity = runner_vel
	scroll_root.position.x = scroll_x
	timeline = host_timeline
	if shield != runner.has_shield:
		runner.has_shield = shield
		shield_label.visible = shield
	if new_score != score:
		score = new_score
		score_label.text = "%d m" % score
