extends SceneTree
## Снимок факелов студии в Godot (превью в контактном листе чёрное — проверяем глазами).
var _n := 0
func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.7, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -38, 0)
	root.add_child(sun)
	for i in 2:
		var t := (load("res://assets/torch_%d/godot_package/torch_%d.tscn" % [i + 1, i + 1]) as PackedScene).instantiate() as Node3D
		t.position = Vector3(-0.2 + 0.4 * i, 0, 0)
		root.add_child(t)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.45, 1.3)
	root.add_child(cam)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	cam.current = true
func _process(_d: float) -> bool:
	_n += 1
	if _n == 30:
		get_root().get_texture().get_image().save_png("res://shots/v3/check/torch_check.png")
		return true
	return false
