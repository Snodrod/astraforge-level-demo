extends Node3D
## AstraForge: applies the wind leaf material to every MeshInstance3D named Leaves* inside the model.
@export var leaf_material: Material
func _ready() -> void:
	if leaf_material == null:
		return
	for m in find_children("Leaves*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = leaf_material
