extends SceneTree
## Отчёт по пакетам студии: габариты, материалы, клипы. godot --headless --path . --script tools/inspect_assets.gd


func _init() -> void:
	var da := DirAccess.open("res://assets")
	for d in da.get_directories():
		var p := "res://assets/%s/godot_package/%s.tscn" % [d, d]
		if not ResourceLoader.exists(p):
			continue
		var n := (load(p) as PackedScene).instantiate() as Node3D
		get_root().add_child(n)
		var box := Populate._node_aabb(n)
		var mats := []
		var tris := 0
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(i)
				var s := mat.get_class()
				if mat is BaseMaterial3D:
					s += " tex=%s emi=%s/%s tr=%d" % [mat.albedo_texture != null, mat.emission_enabled, mat.emission_texture != null, mat.transparency]
				mats.append(s)
				tris += mi.mesh.surface_get_array_index_len(i) / 3 if mi.mesh is ArrayMesh else 0
		var anims := []
		for a in n.find_children("*", "AnimationPlayer", true, false):
			for nm in (a as AnimationPlayer).get_animation_list():
				anims.append("%s(%.2fs)" % [nm, (a as AnimationPlayer).get_animation(nm).length])
		print("%-14s pos=%s size=%s mats=%s anims=%s" % [d, _v(box.position), _v(box.size), mats, anims])
		n.queue_free()
	quit()


func _v(v: Vector3) -> String:
	return "(%.2f,%.2f,%.2f)" % [v.x, v.y, v.z]


func _aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b: AABB = root.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
