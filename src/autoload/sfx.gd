extends Node

var _cache: Dictionary = {}

func play(path: String, pos: Vector3 = Vector3.INF, vol := 0.0) -> void:
	var stream: AudioStream = _load(path)
	if stream == null:
		return
	if pos == Vector3.INF:
		var p2 := AudioStreamPlayer.new()
		p2.stream = stream
		p2.volume_db = vol
		add_child(p2)
		p2.play()
		p2.finished.connect(p2.queue_free)
		return
	var p3 := AudioStreamPlayer3D.new()
	p3.stream = stream
	p3.volume_db = vol
	p3.max_distance = 80.0
	p3.unit_size = 8.0
	add_child(p3)
	p3.global_position = pos
	p3.play()
	p3.finished.connect(p3.queue_free)


func play2d(path: String, vol := 0.0) -> void:
	play(path, Vector3.INF, vol)


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if ResourceLoader.exists(path):
		var s: AudioStream = load(path) as AudioStream
		_cache[path] = s
		return s
	return null
