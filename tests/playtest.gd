## Automated smoke playtest (headless-friendly).
## Boots the real game in LOCAL mode and drives both roles programmatically:
## the Runner jumps on a timer, the Builder Pro cycles through every tool
## placing objects ahead (spikes will eventually kill the Runner).
## Verifies: play -> die -> game over -> restart -> play.
## Run with: godot --headless res://tests/playtest.tscn
extends Node

const MAX_TIME := 60.0

var main: Node
var game: Node2D
var phase := "play"
var t := 0.0
var jump_timer := 0.8
var place_timer := 1.5
var tool_cycle := 0
var died_once := false
var restarted := false
var max_score := 0

func _ready() -> void:
	main = $Main
	await get_tree().process_frame
	main._on_local()
	game = main.game
	print("[playtest] BuildNDash2D started in LOCAL mode")


func _physics_process(delta: float) -> void:
	if game == null:
		return
	t += delta
	max_score = maxi(max_score, game.score)
	match phase:
		"play":
			# Drive the Runner: periodic jumps (no aiming — spikes will land hits).
			jump_timer -= delta
			if jump_timer <= 0.0:
				jump_timer = 0.8
				game.runner.jump()
			# Drive the Builder Pro: cycle all five tools, placing ahead.
			place_timer -= delta
			if place_timer <= 0.0:
				place_timer = 2.2
				game._try_place(Vector2(1050, 620), tool_cycle % 5)
				tool_cycle += 1
			if not game.playing:
				died_once = true
				print("[playtest] game over at t=%.1fs dist=%dm placed=%d speed=%.0f" % [
					t, game.score,
					get_tree().get_nodes_in_group("placed").size(), game.speed])
				phase = "restart"
		"restart":
			game._on_restart_pressed()
			restarted = game.playing and game.score == 0
			print("[playtest] restart -> playing=%s score=%d" % [game.playing, game.score])
			phase = "second"
		"second":
			jump_timer -= delta
			if jump_timer <= 0.0:
				jump_timer = 0.8
				game.runner.jump()
			if t > 45.0 or not game.playing:
				_finish()
	if t > MAX_TIME:
		_finish()


func _finish() -> void:
	var ok := died_once and restarted
	print("[playtest] RESULT: %s | died_once=%s restarted=%s max_dist=%dm tools_used=%d" % [
		"PASS" if ok else "FAIL", died_once, restarted, max_score, mini(tool_cycle, 5)])
	get_tree().quit(0 if ok else 1)
