class_name Placeholders
extends RefCounted
## Заглушки-примитивы: конусы и сферы вместо деревьев, кубы вместо камней, капсулы вместо животных.
## Ориентация как у студии: «нос» животных и персонажей смотрит в +Z, основание стоит на y = 0.

static var _wind: Shader
static var _cache: Dictionary = {}


static func make(kind: String, variant: int = 0) -> Node3D:
	match kind:
		"tree": return tree(variant)
		"bush": return bush()
		"rock": return rock(variant)
		"house": return house()
		"bridge": return bridge()
		"campfire": return campfire()
		"barrel": return barrel()
		"crate": return crate()
		"torch": return torch()
		"hare": return animal(Vector3(0.18, 0.2, 0.42), Color("b59a78"), 0.45)
		"deer": return animal(Vector3(0.45, 0.8, 1.5), Color("a87648"), 1.6)
		"fox": return animal(Vector3(0.22, 0.3, 0.7), Color("d8782f"), 0.8)
		"bird": return bird()
	return _mesh(BoxMesh.new(), Color.MAGENTA)


# ---------- материалы ----------

static func wind_material(col: Color, amp: float, height_ref: float, tex: Texture2D = null) -> ShaderMaterial:
	if _wind == null:
		_wind = load("res://shaders/wind.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _wind
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("amplitude", amp)
	m.set_shader_parameter("height_ref", height_ref)
	if tex != null:
		m.set_shader_parameter("albedo_tex", tex)
	return m


static func flat(col: Color, rough: float = 0.9) -> StandardMaterial3D:
	var key := "%s_%s" % [col.to_html(), rough]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = rough
		_cache[key] = m
	return _cache[key]


static func _mesh(mesh: Mesh, col: Color, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat if mat != null else flat(col)
	return mi


static func _add(parent: Node3D, mi: MeshInstance3D, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func _cyl(r_top: float, r_bot: float, h: float, seg: int = 7) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _sphere(r: float, seg: int = 7) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = max(seg / 2, 3)
	return s


# ---------- растения ----------

## Четыре «породы»: 0 дуб (шары), 1 ель (конусы), 2 берёза, 3 сухое дерево.
static func tree(variant: int) -> Node3D:
	var root := Node3D.new()
	root.name = "TreePlaceholder"
	var bark := Color("6b4a2f")
	var leaf := Color("3f7d3a")
	match variant % 4:
		0:
			_add(root, _mesh(_cyl(0.22, 0.34, 2.4), bark, wind_material(bark, 0.02, 6.0)), Vector3(0, 1.2, 0))
			var cm := wind_material(leaf, 0.07, 6.0)
			_add(root, _mesh(_sphere(1.6), leaf, cm), Vector3(0, 3.7, 0), Vector3.ZERO, Vector3(1, 0.85, 1))
			_add(root, _mesh(_sphere(1.1), leaf, cm), Vector3(0.9, 3.0, 0.4))
			_add(root, _mesh(_sphere(1.0), leaf, cm), Vector3(-0.8, 3.2, -0.5))
		1:
			var spruce := Color("2f6a39")
			_add(root, _mesh(_cyl(0.16, 0.26, 1.2), bark, wind_material(bark, 0.01, 7.0)), Vector3(0, 0.6, 0))
			var sm := wind_material(spruce, 0.08, 7.0)
			for i in 3:
				var r := 1.5 - i * 0.4
				_add(root, _mesh(_cyl(0.0, r, 1.9, 8), spruce, sm), Vector3(0, 1.8 + i * 1.3, 0))
		2:
			var white := Color("e6e2d6")
			_add(root, _mesh(_cyl(0.1, 0.16, 3.4), white, wind_material(white, 0.03, 6.0)), Vector3(0, 1.7, 0))
			var bm := wind_material(Color("5f9a42"), 0.08, 6.0)
			_add(root, _mesh(_sphere(1.0), leaf, bm), Vector3(0, 4.1, 0), Vector3.ZERO, Vector3(0.9, 1.5, 0.9))
		_:
			var dead := Color("5a4636")
			var dm := wind_material(dead, 0.03, 5.0)
			_add(root, _mesh(_cyl(0.1, 0.28, 3.6), dead, dm), Vector3(0, 1.8, 0))
			_add(root, _mesh(_cyl(0.05, 0.1, 1.4), dead, dm), Vector3(0.5, 3.1, 0), Vector3(0, 0, -50))
			_add(root, _mesh(_cyl(0.04, 0.08, 1.1), dead, dm), Vector3(-0.4, 2.5, 0.1), Vector3(0, 0, 55))
	return root


static func bush() -> Node3D:
	var root := Node3D.new()
	var col := Color("4d8f3f")
	var m := wind_material(col, 0.05, 1.2)
	_add(root, _mesh(_sphere(0.6, 6), col, m), Vector3(0, 0.4, 0), Vector3.ZERO, Vector3(1.2, 0.8, 1))
	_add(root, _mesh(_sphere(0.4, 6), col, m), Vector3(0.5, 0.3, 0.2))
	return root


# ---------- камни и реквизит ----------

static func rock(variant: int) -> Node3D:
	var root := Node3D.new()
	var col := Color("9a958c")
	var b := BoxMesh.new()
	b.size = Vector3(1.0, 0.7, 0.8)
	match variant % 3:
		0:
			_add(root, _mesh(b, col), Vector3(0, 0.3, 0), Vector3(8, 25, 5))
		1:
			_add(root, _mesh(_sphere(0.5, 6), col), Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1.3, 0.7, 1.0))
		_:
			_add(root, _mesh(_cyl(0.3, 0.5, 0.6, 6), col), Vector3(0, 0.3, 0), Vector3(4, 10, 6))
	return root


static func house() -> Node3D:
	var root := Node3D.new()
	var wall := BoxMesh.new()
	wall.size = Vector3(4.0, 2.4, 3.2)
	_add(root, _mesh(wall, Color("cdb38a")), Vector3(0, 1.2, 0))
	var roof := _cyl(0.0, 3.1, 1.8, 4)
	_add(root, _mesh(roof, Color("e0913a")), Vector3(0, 3.3, 0), Vector3(0, 45, 0), Vector3(1.0, 1.0, 0.85))
	var door := BoxMesh.new()
	door.size = Vector3(0.8, 1.5, 0.1)
	_add(root, _mesh(door, Color("6b4a2f")), Vector3(0, 0.75, 1.62))
	var chim := BoxMesh.new()
	chim.size = Vector3(0.5, 1.2, 0.5)
	_add(root, _mesh(chim, Color("9a958c")), Vector3(1.1, 3.5, -0.5))
	return root


static func bridge() -> Node3D:
	# длина вдоль оси X, ширина 2.2 м
	var root := Node3D.new()
	var wood := Color("8a6240")
	var deck := BoxMesh.new()
	deck.size = Vector3(13.0, 0.18, 2.2)
	_add(root, _mesh(deck, wood), Vector3(0, 0.0, 0))
	var rail := BoxMesh.new()
	rail.size = Vector3(13.0, 0.1, 0.1)
	var post := BoxMesh.new()
	post.size = Vector3(0.14, 0.9, 0.14)
	for sz in [-1.0, 1.0]:
		_add(root, _mesh(rail, Color("6b4a2f")), Vector3(0, 0.85, sz * 1.0))
		for i in 6:
			_add(root, _mesh(post, Color("6b4a2f")), Vector3(-6.0 + i * 2.4, 0.45, sz * 1.0))
	return root


static func campfire() -> Node3D:
	var root := Node3D.new()
	var log_m := _cyl(0.09, 0.09, 1.0, 5)
	for i in 4:
		_add(root, _mesh(log_m, Color("6b4a2f")), Vector3(0, 0.12, 0), Vector3(80, i * 45.0, 0))
	for i in 7:
		var a := i / 7.0 * TAU
		_add(root, _mesh(_sphere(0.14, 5), Color("9a958c")), Vector3(cos(a) * 0.65, 0.1, sin(a) * 0.65))
	var flame := _mesh(_cyl(0.0, 0.3, 0.8, 6), Color("e0913a"))
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("e0913a")
	fm.emission_enabled = true
	fm.emission = Color("e0913a")
	fm.emission_energy_multiplier = 2.5
	flame.material_override = fm
	_add(root, flame, Vector3(0, 0.5, 0))
	var light := OmniLight3D.new()
	light.light_color = Color("ffb060")
	light.omni_range = 6.0
	light.light_energy = 1.6
	light.position = Vector3(0, 0.8, 0)
	light.set_script(load("res://scripts/fire_flicker.gd"))
	root.add_child(light)
	return root


static func barrel() -> Node3D:
	var root := Node3D.new()
	_add(root, _mesh(_cyl(0.38, 0.38, 0.9, 8), Color("8a6240")), Vector3(0, 0.45, 0))
	_add(root, _mesh(_cyl(0.4, 0.4, 0.06, 8), Color("4a4a4a")), Vector3(0, 0.25, 0))
	_add(root, _mesh(_cyl(0.4, 0.4, 0.06, 8), Color("4a4a4a")), Vector3(0, 0.65, 0))
	return root


static func crate() -> Node3D:
	var root := Node3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.8, 0.8, 0.8)
	_add(root, _mesh(b, Color("a07848")), Vector3(0, 0.4, 0))
	return root


static func torch() -> Node3D:
	var root := Node3D.new()
	_add(root, _mesh(_cyl(0.04, 0.05, 1.6, 5), Color("6b4a2f")), Vector3(0, 0.8, 0))
	var f := _mesh(_sphere(0.12, 5), Color("e0913a"))
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("e0913a")
	fm.emission_enabled = true
	fm.emission = Color("e0913a")
	fm.emission_energy_multiplier = 3.0
	f.material_override = fm
	_add(root, f, Vector3(0, 1.7, 0), Vector3.ZERO, Vector3(1, 1.5, 1))
	var light := OmniLight3D.new()
	light.light_color = Color("ffb060")
	light.omni_range = 3.5
	light.light_energy = 0.9
	light.position = Vector3(0, 1.8, 0)
	light.set_script(load("res://scripts/fire_flicker.gd"))
	root.add_child(light)
	return root


# ---------- животные ----------

## Капсула вдоль +Z и «голова» — шарик спереди, чтобы было видно направление.
static func animal(size: Vector3, col: Color, body_len: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var cap := CapsuleMesh.new()
	cap.radius = max(size.x, size.y) * 0.5
	cap.height = body_len
	cap.radial_segments = 8
	cap.rings = 3
	var mi := _mesh(cap, col)
	var leg_h := body_len * 0.28
	_add(root, mi, Vector3(0, leg_h + cap.radius, 0), Vector3(90, 0, 0))
	var head_r := cap.radius * 0.8
	_add(root, _mesh(_sphere(head_r, 6), col.lightened(0.1)), Vector3(0, leg_h + cap.radius * 1.5, body_len * 0.5 + head_r * 0.4))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add(root, _mesh(_cyl(0.03 + size.x * 0.05, 0.03 + size.x * 0.05, leg_h * 1.6, 4), col.darkened(0.2)),
				Vector3(sx * cap.radius * 0.6, leg_h * 0.8, sz * body_len * 0.28))
	return root


static func bird() -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var col := Color("4a4a58")
	_add(root, _mesh(_sphere(0.14, 6), col), Vector3.ZERO, Vector3.ZERO, Vector3(0.8, 0.8, 1.6))
	_add(root, _mesh(_sphere(0.07, 5), col.lightened(0.2)), Vector3(0, 0.03, 0.26))
	var wing := BoxMesh.new()
	wing.size = Vector3(0.5, 0.02, 0.2)
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "WingL" if s < 0 else "WingR"
		pivot.position = Vector3(s * 0.1, 0.02, 0)
		root.add_child(pivot)
		_add(pivot, _mesh(wing, col.darkened(0.1)), Vector3(s * 0.25, 0, 0))
	return root
