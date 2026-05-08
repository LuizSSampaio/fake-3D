@tool
extends RefCounted


static func find_first_player_with_animations(root: Node) -> Dictionary:
	if root == null:
		return _not_found()

	var players := find_animation_players(root)
	for player in players:
		var animation_names := get_animation_names(player)
		if not animation_names.is_empty():
			return {
				"ok": true,
				"player": player,
				"animations": animation_names,
			}

	return _not_found()


static func find_animation_players(root: Node) -> Array[AnimationPlayer]:
	var players: Array[AnimationPlayer] = []
	if root != null:
		_collect_animation_players(root, players)
	return players


static func get_animation_names(player: AnimationPlayer) -> PackedStringArray:
	if player == null:
		return PackedStringArray()

	return player.get_animation_list()


static func get_animation_length(player: AnimationPlayer, animation_name: String) -> float:
	if player == null or animation_name.is_empty() or not player.has_animation(animation_name):
		return 0.0

	var animation := player.get_animation(animation_name)
	if animation == null:
		return 0.0

	return max(animation.length, 0.0)


static func animation_loops(player: AnimationPlayer, animation_name: String) -> bool:
	if player == null or animation_name.is_empty() or not player.has_animation(animation_name):
		return false

	var animation := player.get_animation(animation_name)
	if animation == null:
		return false

	return animation.loop_mode != Animation.LOOP_NONE


static func calculate_sample_times(animation_length: float, frame_count: int, avoid_duplicate_endpoint := false) -> PackedFloat32Array:
	var times := PackedFloat32Array()
	if frame_count <= 0:
		return times

	var safe_length := max(animation_length, 0.0)
	if frame_count == 1 or safe_length <= 0.0:
		times.append(0.0)
		return times

	var denominator := float(frame_count) if avoid_duplicate_endpoint else float(max(frame_count - 1, 1))
	for frame_index in range(frame_count):
		times.append(min(safe_length, safe_length * float(frame_index) / denominator))

	return times


static func calculate_frame_index(animation_time: float, animation_length: float, frame_count: int, avoid_duplicate_endpoint := false) -> int:
	if frame_count <= 1 or animation_length <= 0.0:
		return 0

	var denominator := float(frame_count) if avoid_duplicate_endpoint else float(max(frame_count - 1, 1))
	var frame_index := int(round(clampf(animation_time, 0.0, animation_length) / animation_length * denominator))
	return clampi(frame_index, 0, frame_count - 1)


static func seek_player(player: AnimationPlayer, animation_name: String, animation_time: float) -> Dictionary:
	if player == null:
		return _failure("Animation player is not available.")

	if animation_name.is_empty() or not player.has_animation(animation_name):
		return _failure("Requested animation doesn't exist: \"%s\"." % animation_name)

	var animation_length := get_animation_length(player, animation_name)
	var safe_time := clampf(animation_time, 0.0, animation_length)
	player.play(animation_name)
	player.seek(safe_time, true)
	player.pause()
	return {
		"ok": true,
		"time": safe_time,
	}


static func _collect_animation_players(node: Node, players: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		players.append(node as AnimationPlayer)

	for child in node.get_children():
		_collect_animation_players(child, players)


static func _not_found() -> Dictionary:
	return {
		"ok": false,
		"message": "No AnimationPlayer with animations was found in the loaded source.",
	}


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
