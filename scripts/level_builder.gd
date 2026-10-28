class_name LevelBuilder
extends Node3D
## Собирает 3D-уровень по этапам: земля -> река -> деревья -> трава -> камни -> реквизит -> животные.
## Каждый этап — отдельная группа узлов (Node3D). Сцена-таймлапс показывает их по очереди.
## Всё, что потом заменится ассетами студии, стоит в слотах (AssetSlot) — см. populate.gd.

const STAGES := ["ground", "river", "trees", "grass", "rocks", "props", "animals"]
const HOUSE_POS := Vector2(11.0, -6.0)

@export var auto_build := true
@export var seed_value := 7
@export var grass_count := 16000
@export var use_assets := true          # подставлять пакеты из assets/manifest.json

var groups := {}                        # этап -> Node3D
var _rng := RandomNumberGenerator.new()
var _keepout: Array[Vector3] = []       # (x, z, радиус): сюда не ставим деревья и траву
var _animal_n := 0


func _ready() -> void:
	add_to_group("level")
	if auto_build:
		build_all()


func build_all() -> void:
	for s in STAGES:
		build_stage(s)
	if use_assets:
		Populate.apply_3d(self)


## Построить один этап (повторный вызов вернёт уже созданную группу).
func build_stage(stage: String) -> Node3D:
	if groups.has(stage):
		return groups[stage]
	_rng.seed = seed_value + STAGES.find(stage) * 101
	var g := Node3D.new()
	g.name = stage.capitalize()
	add_child(g)
	groups[stage] = g
	call("_build_" + stage, g)
	return g


## Сколько ассетов (слотов) в группе — для счётчика «0 -> 64».
func asset_count(stage: String) -> int:
	if not groups.has(stage):
		return 0
	return (groups[stage] as Node).find_children("*", "AssetSlot", true, false).size()


# ---------- этапы ----------

func _build_ground(g: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = LevelTerrain.build_mesh()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	m.set_shader_parameter("noise_tex", detail_texture())
	mi.material_override = m
	g.add_child(mi)
	# «горизонт»: широкая плоскость под краями карты, чтобы не было дыры
	var far := MeshInstance3D.new()
	far.name = "Horizon"
	var pm := PlaneMesh.new()
	pm.size = Vector2(500, 500)
	far.mesh = pm
	far.position.y = -0.7
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("6a9440")
	fm.roughness = 1.0
	far.material_override = fm
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(far)


func _build_river(g: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(LevelTerrain.SIZE, LevelTerrain.SIZE)
	mi.mesh = pm
	mi.position.y = LevelTerrain.WATER_Y
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("noise_tex", noise_texture())
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)


func _build_trees(g: Node3D) -> void:
	# keepout: дом, костёр, мост, чтобы лес не лез в реквизит
	_keepout = [Vector3(HOUSE_POS.x, HOUSE_POS.y, 6.0), Vector3(7.5, -2.5, 3.0), Vector3(LevelTerrain.river_x(9.0), 9.0, 9.0)]
	var species := [0, 0, 1, 2, 0, 1, 3, 2, 0, 1, 0, 2, 1, 3, 0, 1, 2, 0, 1, 3, 0, 2, 1, 0]   # 24 дерева: дуб, ель, берёза, сухое
	var clusters := [Vector2(-20, -8), Vector2(-14, 18), Vector2(22, -20), Vector2(24, 20), Vector2(-6, -24)]
	var placed: Array[Vector2] = []
	var i := 0
	var tries := 0
	while i < species.size() and tries < 4000:
		tries += 1
		var c: Vector2 = clusters[_rng.randi() % clusters.size()]
		var x := c.x + _rng.randf_range(-7.0, 7.0)
		var z := c.y + _rng.randf_range(-7.0, 7.0)
		if not _free_spot(x, z, 1.4) or not _spaced(placed, x, z, 3.6):
			continue
		placed.append(Vector2(x, z))
		var s := _slot("tree", species[i], Vector3(x, LevelTerrain.height(x, z), z), g, "Tree_%02d" % i)
		s.rotation.y = _rng.randf() * TAU
		s.scale = Vector3.ONE * _rng.randf_range(0.85, 1.25)
		i += 1
	# кусты по краям леса и у берега
	var k := 0
	tries = 0
	while k < 8 and tries < 600:
		tries += 1
		var x := _rng.randf_range(-28, 28)
		var z := _rng.randf_range(-28, 28)
		if not _free_spot(x, z, 0.8):
			continue
		var b := _slot("bush", 0, Vector3(x, LevelTerrain.height(x, z), z), g, "Bush_%02d" % k)
		b.rotation.y = _rng.randf() * TAU
		b.scale = Vector3.ONE * _rng.randf_range(0.8, 1.4)
		k += 1


func _build_grass(g: Node3D) -> void:
	# трава режется на 4x4 куска: у каждого своя дальность видимости (LOD по расстоянию)
	const CH := 4
	var cell := 60.0 / CH
	var buckets: Array = []
	for i in CH * CH:
		buckets.append([])
	var base := LevelTerrain.COL_GRASS
	var n := 0
	var tries := 0
	while n < grass_count and tries < grass_count * 14:
		tries += 1
		var x := _rng.randf_range(-30.0, 30.0)
		var z := _rng.randf_range(-30.0, 30.0)
		var h := LevelTerrain.height(x, z)
		if LevelTerrain.river_dist(x, z) < 5.4 or h > 3.8:        # без травы в русле, на песке и на скале
			continue
		if not _outside_keepout(x, z, 0.0):
			continue
		var patch := 0.5 + 0.5 * sin(x * 0.31) * sin(z * 0.27) + 0.25 * sin(x * 0.9 + z * 0.7)   # пятна гуще/реже
		if _rng.randf() > 0.38 + 0.62 * clampf(patch, 0.0, 1.0):
			continue
		var sc := _rng.randf_range(0.7, 1.6)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc * _rng.randf_range(0.8, 1.4), sc))
		var col := Color.from_hsv(base.h + _rng.randf_range(-0.04, 0.03), base.s * _rng.randf_range(0.8, 1.1), base.v * _rng.randf_range(0.82, 1.15))
		var cx := clampi(int((x + 30.0) / cell), 0, CH - 1)
		var cz := clampi(int((z + 30.0) / cell), 0, CH - 1)
		buckets[cz * CH + cx].append([Transform3D(basis, Vector3(x, h - 0.03, z)), col])   # приземляем на рельеф
		n += 1
	var root := Node3D.new()
	root.name = "GrassTufts"
	g.add_child(root)
	var mesh := grass_mesh()
	var mat := Placeholders.wind_material(Color.WHITE, 0.05, 0.6)
	for bi in buckets.size():
		var items: Array = buckets[bi]
		if items.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = items.size()
		for k in items.size():
			mm.set_instance_transform(k, items[k][0])
			mm.set_instance_color(k, items[k][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Chunk_%d" % bi
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 62.0
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		root.add_child(mmi)
	_build_flowers(g)


## Цветы: мелкие цветные шарики в траве (белые, жёлтые, розовые, сиреневые, тёплые).
func _build_flowers(g: Node3D) -> void:
	var pal := [Color("f4f0e0"), Color("f2d24a"), Color("e8789a"), Color("a98ad8"), Color("e0913a")]
	var pts: Array = []
	var tries := 0
	while pts.size() < 900 and tries < 20000:
		tries += 1
		var x := _rng.randf_range(-30.0, 30.0)
		var z := _rng.randf_range(-30.0, 30.0)
		if LevelTerrain.river_dist(x, z) < 6.0 or LevelTerrain.height(x, z) > 3.0 or not _outside_keepout(x, z, 0.0):
			continue
		if sin(x * 0.5 + 1.0) * sin(z * 0.43) < 0.2:                  # цветут полянами
			continue
		pts.append(Vector3(x, LevelTerrain.height(x, z), z))
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.radial_segments = 6
	sm.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sm
	mm.instance_count = pts.size()
	for k in pts.size():
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _rng.randf_range(0.8, 1.5)), pts[k] + Vector3(0, 0.22, 0)))
		mm.set_instance_color(k, pal[(k / 7) % pal.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Flowers"
	mmi.multimesh = mm
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.roughness = 0.6
	mmi.material_override = fm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 45.0
	g.add_child(mmi)


func _build_rocks(g: Node3D) -> void:
	var i := 0
	var tries := 0
	while i < 10 and tries < 400:
		tries += 1
		var z := _rng.randf_range(-27, 27)
		var side := 1.0 if i % 2 == 0 else -1.0
		var x := LevelTerrain.river_x(z) + side * _rng.randf_range(5.4, 6.8)   # по берегу
		if i >= 8:                                                              # два валуна на холме
			x = _rng.randf_range(-22, -10)
			z = _rng.randf_range(-16, -4)
		if LevelTerrain.is_water(x, z, 0.1) or not _outside_keepout(x, z, 0.0):
			continue
		var s := _slot("rock", i, Vector3(x, LevelTerrain.height(x, z) - 0.05, z), g, "Rock_%02d" % i)
		s.rotation.y = _rng.randf() * TAU
		s.scale = Vector3.ONE * (_rng.randf_range(1.4, 2.2) if i >= 8 else _rng.randf_range(0.6, 1.5))
		i += 1


func _build_props(g: Node3D) -> void:
	var h := Vector3(HOUSE_POS.x, 0, HOUSE_POS.y)
	h.y = LevelTerrain.height(h.x, h.z) - 0.1
	var house := _slot("house", 0, h, g, "House")
	house.rotation.y = -PI * 0.5                                # дверь смотрит на реку (−X)
	# мост через русло: поперёк реки на z = 9
	var bz := 9.0
	var bx := LevelTerrain.river_x(bz)
	_slot("bridge", 0, Vector3(bx, 0.5, bz), g, "Bridge")
	# костёр у домика
	var fire := Vector3(7.5, 0, -2.5)
	fire.y = LevelTerrain.height(fire.x, fire.z)
	_slot("campfire", 0, fire, g, "Campfire")
	# бочки и ящики у стены дома (локально: x вдоль стены, z наружу)
	var local := [Vector2(-1.4, 2.4), Vector2(-0.6, 2.5), Vector2(0.4, 2.45), Vector2(1.5, 2.6)]
	for i in 3:
		_slot("barrel", 0, _house_point(local[i]), g, "Barrel_%d" % i).rotation.y = _rng.randf() * TAU
	for i in 4:
		var p := _house_point(Vector2(-2.1 + i * 1.1, -2.7)) if i < 3 else _house_point(Vector2(1.2, 2.6) + Vector2(0.0, 0.0))
		_slot("crate", 0, p, g, "Crate_%d" % i).rotation.y = _rng.randf() * TAU
	# факелы: два у костра, два на мосту
	_slot("torch", 0, Vector3(fire.x - 1.2, LevelTerrain.height(fire.x - 1.2, fire.z + 1.0), fire.z + 1.0), g, "Torch_0")
	_slot("torch", 0, Vector3(fire.x + 1.2, LevelTerrain.height(fire.x + 1.2, fire.z - 1.0), fire.z - 1.0), g, "Torch_1")
	_slot("torch", 0, Vector3(bx - 6.2, 0.55, bz - 1.0), g, "Torch_2")
	_slot("torch", 0, Vector3(bx + 6.2, 0.55, bz + 1.0), g, "Torch_3")
	# дым из трубы
	var smoke := make_smoke()
	smoke.position = h + Vector3(0.0, 4.3, 0.0) + Basis(Vector3.UP, -PI * 0.5) * Vector3(1.1, 0, -0.5)
	g.add_child(smoke)


func _build_animals(g: Node3D) -> void:
	for i in 3:                                                    # зайцы на поляне
		_animal("hare", Vector2([-8.0, 10.0, -4.0][i], [10.0, 14.0, -16.0][i]), g, 0.7, 4.6, 0.3, 0.0, 6)
	for i in 2:                                                    # олени у воды
		var z: float = [-14.0, 16.0][i]
		_animal("deer", Vector2(LevelTerrain.river_x(z) - 5.0, z), g, 1.1, 4.4, 0.1, 0.7, 9)
	_animal("fox", Vector2(17.0, 12.0), g, 0.9, 4.0, 0.2, 0.0, 7)
	for i in 2:                                                    # птицы над рекой
		var b := Node3D.new()
		b.name = "Bird_%d" % i
		b.set_script(load("res://scripts/bird_orbit.gd"))
		b.set("phase", PI * i)
		b.set("altitude", 5.5 + i * 1.6)
		b.set("speed", 0.34 + i * 0.05)
		g.add_child(b)
		var s := AssetSlot.new()
		s.kind = "bird"
		s.name = "Slot"
		b.add_child(s)


# ---------- помощники ----------

func _animal(kind: String, at: Vector2, g: Node3D, walk: float, run: float, run_chance: float, shore: float, radius: float) -> void:
	_animal_n += 1
	var a := Node3D.new()
	a.name = "%s_%d" % [kind.capitalize(), _animal_n]
	a.set_script(load("res://scripts/wander.gd"))
	var x := at.x
	var z := at.y
	while LevelTerrain.is_water(x, z, 0.2):                         # не ставим в воду
		x += 1.0
	a.position = Vector3(x, LevelTerrain.height(x, z), z)
	var size := _rng.randf_range(0.88, 1.15)                         # разный рост и темп у каждого
	a.scale = Vector3.ONE * size
	a.set("tempo", _rng.randf_range(0.85, 1.2))
	a.set("walk_speed", walk)
	a.set("run_speed", run)
	a.set("run_chance", run_chance)
	a.set("shore_chance", shore)
	a.set("wander_radius", radius)
	g.add_child(a)
	var s := AssetSlot.new()
	s.kind = kind
	s.name = "Slot"
	a.add_child(s)


func _slot(kind: String, variant: int, pos: Vector3, parent: Node3D, node_name: String) -> AssetSlot:
	var s := AssetSlot.new()
	s.kind = kind
	s.variant = variant
	s.name = node_name
	s.position = pos
	parent.add_child(s)
	return s


func _house_point(local_xz: Vector2) -> Vector3:
	var b := Basis(Vector3.UP, -PI * 0.5)
	var p := b * Vector3(local_xz.x, 0, local_xz.y) + Vector3(HOUSE_POS.x, 0, HOUSE_POS.y)
	p.y = LevelTerrain.height(p.x, p.z)
	return p


func _free_spot(x: float, z: float, extra: float) -> bool:
	if not LevelTerrain.in_bounds(x, z, 3.0):
		return false
	if LevelTerrain.river_dist(x, z) < 6.2:      # не у самой воды
		return false
	return _outside_keepout(x, z, extra)


func _outside_keepout(x: float, z: float, extra: float) -> bool:
	for k in _keepout:
		if Vector2(x - k.x, z - k.y).length() < k.z + extra:
			return false
	return true


func _spaced(placed: Array[Vector2], x: float, z: float, dist: float) -> bool:
	for p in placed:
		if p.distance_to(Vector2(x, z)) < dist:
			return false
	return true


# ---------- ресурсы ----------

static var _noise_tex: Texture2D

## Бесшовный шум для воды. Если студия положила assets/textures/water_noise.png — берём её.
static func noise_texture() -> Texture2D:
	if _noise_tex:
		return _noise_tex
	var path := "res://assets/textures/water_noise.png"
	if ResourceLoader.exists(path):
		_noise_tex = load(path)
		return _noise_tex
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.012
	fn.fractal_octaves = 3
	fn.seed = 11
	var img := fn.get_seamless_image(256, 256)
	_noise_tex = ImageTexture.create_from_image(img)
	return _noise_tex


static var _detail_tex: Texture2D

## Зернистый шум для земли (несколько октав), чтобы текстура читалась вблизи.
static func detail_texture() -> Texture2D:
	if _detail_tex:
		return _detail_tex
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.045
	fn.fractal_octaves = 5
	fn.seed = 5
	_detail_tex = ImageTexture.create_from_image(fn.get_seamless_image(512, 512))
	return _detail_tex


## Пучок травы: 3 перекрещённых лезвия-треугольника (бюджет 40 тр., тут 6). Основание темнее.
static func grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var a := i * PI / 5.0
		var d := Vector3(cos(a), 0, sin(a)) * 0.07
		for side in [1.0, -1.0]:
			var lean: Vector3 = Vector3(sin(a), 0, -cos(a)) * 0.06 * float(side)
			st.set_color(Color(0.62, 0.62, 0.62))
			st.add_vertex(-d)
			st.set_color(Color(0.62, 0.62, 0.62))
			st.add_vertex(d)
			st.set_color(Color(1.05, 1.05, 1.05))
			st.add_vertex(Vector3(0, 0.5, 0) + lean)
	st.generate_normals()
	return st.commit()


func make_smoke() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "ChimneySmoke"
	p.amount = 24
	p.lifetime = 4.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.2, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0.15, 0.1, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.6))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	pm.color = Color(0.8, 0.8, 0.82, 0.45)
	p.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 1)
	sm.material = mat
	p.draw_pass_1 = sm
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
