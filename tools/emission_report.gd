extends SceneTree
func _init() -> void:
	for id in ["house", "tree_oak_1", "barrel", "crate", "bridge", "deer", "fox", "hare", "campfire", "bush_1"]:
		var n := (load("res://assets/%s/godot_package/%s.tscn" % [id, id]) as PackedScene).instantiate()
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var mat := mi.get_active_material(0) as BaseMaterial3D
			if mat:
				print("%-12s emi=%s col=%s energy=%.2f rough=%.2f metal=%.2f albedo=%s" % [id, mat.emission_enabled, mat.emission, mat.emission_energy_multiplier, mat.roughness, mat.metallic, mat.albedo_color])
		n.free()
	quit()
