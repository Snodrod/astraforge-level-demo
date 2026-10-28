extends SceneTree
func _init() -> void:
	var n := (load("res://assets/bridge/godot_package/bridge.tscn") as PackedScene).instantiate()
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var arr := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bins := {}
		for p in v:
			if absf(p.x) < 0.45:
				var k := int(floor(p.z * 4.0))
				if not bins.has(k):
					bins[k] = [99.0, -99.0]
				bins[k][0] = minf(bins[k][0], p.y)
				bins[k][1] = maxf(bins[k][1], p.y)
		var ks := bins.keys()
		ks.sort()
		for k in ks:
			print("z=%.2f  y %.2f..%.2f" % [k / 4.0, bins[k][0], bins[k][1]])
		print("xform ", mi.transform)
	quit()
