class_name MapCollision
extends RefCounted
## Chunk the trimesh so physics broadphase can skip far triangles.


static func add_chunked(parent: Node3D, mesh: Mesh, cell := 12.0) -> int:
	if mesh == null:
		return 0
	var buckets: Dictionary = {}
	for s in mesh.get_surface_count():
		var arrs: Array = mesh.surface_get_arrays(s)
		if arrs.is_empty() or arrs[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
		var idx = arrs[Mesh.ARRAY_INDEX]
		if idx != null and idx.size() >= 3:
			for i in range(0, idx.size() - 2, 3):
				_tri(buckets, cell, verts[idx[i]], verts[idx[i + 1]], verts[idx[i + 2]])
		else:
			for i in range(0, verts.size() - 2, 3):
				_tri(buckets, cell, verts[i], verts[i + 1], verts[i + 2])
	var n := 0
	for key in buckets:
		var faces: PackedVector3Array = buckets[key]
		if faces.size() < 9:
			continue
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("surf", "plaster")
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		cs.shape = shape
		body.add_child(cs)
		parent.add_child(body)
		n += 1
	return n


static func _tri(buckets: Dictionary, cell: float, a: Vector3, b: Vector3, c: Vector3) -> void:
	var mid := (a + b + c) * (1.0 / 3.0)
	var key := Vector2i(int(floor(mid.x / cell)), int(floor(mid.z / cell)))
	if not buckets.has(key):
		buckets[key] = PackedVector3Array()
	var faces: PackedVector3Array = buckets[key]
	faces.append(a)
	faces.append(b)
	faces.append(c)
	buckets[key] = faces
