extends SceneTree
## Пиксельный спрайт моста под карту: тот же пакет студии (assets/bridge), тот же масштаб и поворот,
## что в 3D-уровне (поперёк русла), ортографическая камера 40°, как пиксельный профиль студии.
## Рендер 64 px/м с прозрачным фоном -> assets_px/bridge_flat/raw.png; уменьшение до 16 px/м
## с палитрой моста делает tools/pixel_resample.py (раздел BRIDGE_FLAT).
##   godot --path . --script tools/render_bridge_px.gd

const PPM := 64.0
const SIZE := Vector2i(768, 512)
var _n := 0
var _vp: SubViewport


func _init() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.82)
	e.ambient_light_energy = 0.9
	env.environment = e
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -38, 0)
	sun.light_energy = 1.3
	_vp.add_child(sun)
	var b := (load("res://assets/bridge/godot_package/bridge.tscn") as PackedScene).instantiate() as Node3D
	b.scale = Vector3(1.7, 1.25, 2.55)                         # как в level_v3.gd
	b.rotation.y = PI * 0.5 + 0.12
	_vp.add_child(b)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = SIZE.y / PPM
	cam.rotation_degrees = Vector3(-40, 0, 0)
	cam.position = Vector3(0, 0, 0) + cam.basis.z * 30.0       # центр кадра = точка опоры моста
	_vp.add_child(cam)
	cam.current = true


func _process(_d: float) -> bool:
	_n += 1
	if _n == 20:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets_px/bridge_flat"))
		_vp.get_texture().get_image().save_png("res://assets_px/bridge_flat/raw.png")
		return true
	return false
