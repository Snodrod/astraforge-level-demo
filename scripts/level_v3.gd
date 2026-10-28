class_name LevelV3
extends Node3D
## Уровень v3 на настоящих ассетах AstraForge (assets/<id>/godot_package/<id>.tscn).
## Этапы: земля -> река -> трава (и кусты, цветы) -> деревья -> камни -> реквизит -> животные.
## Каждый этап — своя группа узлов; таймлапс показывает их по очереди.
## Трава — процедурная (MultiMesh, 16 000 пучков + холмы), ветер и вода — шейдеры проекта.
## Брак студии не ставим: bush_2, grass_3 (рваные), rock_1/2/4 (гладкие без текстуры).

const STAGES := ["ground", "river", "grass", "trees", "rocks", "props", "animals"]
const TREES := ["tree_oak_1", "tree_oak_2", "tree_oak_3", "tree_spruce_1", "tree_spruce_2", "tree_spruce_3",
	"tree_birch_1", "tree_birch_2", "tree_birch_3", "tree_apple_1", "tree_apple_2"]
const HOUSE_POS := Vector2(14.0, -7.0)
const FIRE_POS := Vector2(8.3, -4.2)
const BRIDGE_Z := 9.0

## Замер tools/stride_speed.gd: скорость лапы на земле, м/с при темпе 1 и масштабе 1.
const STRIDE := {"deer": [0.52, 1.24], "fox": [0.14, 0.33], "hare": [0.0, 0.30], "sparrow": [0.02, 0.02]}

## Скорости шага: assets/strides.json (пишет tools/stride_speed.gd при переимпорте), иначе — STRIDE.
static func stride(kind: String) -> Array:
	var p := "res://assets/strides.json"
	if FileAccess.file_exists(p):
		var d = JSON.parse_string(FileAccess.get_file_as_string(p))
		if d is Dictionary and d.has(kind):
			var c: Dictionary = d[kind]
			var walk := 0.0
			var run := 0.0
			for k in c:
				var l := str(k).to_lower()
				if l.begins_with("walk") or l.begins_with("hop"):
					walk = float(c[k])
				elif l.begins_with("run") or l.begins_with("gallop"):
					run = float(c[k])
			if walk > 0.0 or run > 0.0:
				return [walk, run if run > 0.0 else walk]
	return STRIDE.get(kind, [0.5, 1.0])


@export var auto_build := true
@export var seed_value := 7
@export var grass_count := 16000
@export var hill_grass := 9000
@export var ring_forest := true

var groups := {}                        # этап -> Node3D
var focus := {}                         # имя -> Node3D (точки для камер)
var ring: Array = []                    # [MultiMesh, индекс, Transform3D, дальность] — лес на холмах
var _rng := RandomNumberGenerator.new()
var _wind_cache := {}
var _trees_xz: Array[Vector3] = []      # (x, z, радиус кроны) — чтобы кусты и камни не лезли в стволы
var _animal_n := 0
var tree_list: Array[Vector4] = []      # (x, y, z, масштаб) всех деревьев — проверка пролётов камеры
var layout: Array = []                  # [id, x, z, поворот, масштаб] — та же раскладка для пиксельной версии
var solid_list: Array[Vector4] = []     # (x, y, z, радиус) дом, мост, камни-горки


func _ready() -> void:
	add_to_group("level")
	if auto_build:
		build_all()


func build_all() -> void:
	for s in STAGES:
		build_stage(s)


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


## Сколько ассетов студии в группе (для счётчика в таймлапсе).
func asset_count(stage: String) -> int:
	if not groups.has(stage):
		return 0
	var n := 0
	for c in (groups[stage] as Node).get_children():
		if c.has_meta("asset"):
			n += 1
	return n


# ======================= ассеты =======================

static func asset_path(id: String) -> String:
	return "res://assets/%s/godot_package/%s.tscn" % [id, id]


func asset(id: String) -> Node3D:
	var n := (load(asset_path(id)) as PackedScene).instantiate() as Node3D
	n.set_meta("asset", id)
	return n


## Ставит ассет на землю: высота — самая низкая точка рельефа под основанием (ничего не висит),
## sink — сколько утопить (мох, корни, трава у основания).
func place(id: String, x: float, z: float, yaw: float, s: float, parent: Node3D, sink := 0.04, foot := 0.5) -> Node3D:
	var n := asset(id)
	n.position = Vector3(x, ground_min(x, z, foot * s) - sink * s, z)
	n.rotation.y = yaw
	n.scale = Vector3.ONE * s
	parent.add_child(n)
	layout.append([id, x, z, yaw, s])
	return n


static func ground_min(x: float, z: float, r: float) -> float:
	var h := LevelTerrain.height(x, z)
	if r <= 0.01:
		return h
	for i in 8:
		var a := i * TAU / 8.0
		h = minf(h, LevelTerrain.height(x + cos(a) * r, z + sin(a) * r))
	return h


## Ветер на все материалы ассета; цвет, текстура и рисованная подсветка — из пакета студии.
## У деревьев v2 листва — карточки Leaves* со своим шейдером ветра из пакета (af_leaves_wind.gd):
## их не трогаем (ни материал, ни нормали), ствол тогда стоит на месте — качается только листва.
func apply_wind(node: Node, amplitude: float, height_ref: float, flutter := 0.012, clip := -100.0) -> void:
	var has_leaves := not node.find_children("Leaves*", "MeshInstance3D", true, false).is_empty()
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if str(mi.name).begins_with("Leaves") or mi.material_override != null:
			continue
		if has_leaves:
			amplitude = 0.0
			flutter = 0.0
		var mats: Array = []
		for i in mi.mesh.get_surface_count():
			mats.append(mi.get_active_material(i))
		mi.mesh = smooth_mesh(mi.mesh)
		for i in mats.size():
			mi.set_surface_override_material(i, mats[i])
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, wind_material(mi.get_active_material(i), amplitude, height_ref, flutter, clip))


func wind_material(base: Material, amplitude: float, height_ref: float, flutter := 0.012, clip := -100.0) -> Material:
	if not (base is BaseMaterial3D):
		return base
	var key := "%d_%.3f_%.2f_%.3f_%.2f" % [base.get_instance_id(), amplitude, height_ref, flutter, clip]
	if _wind_cache.has(key):
		return _wind_cache[key]
	var b := base as BaseMaterial3D
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/wind_tex.gdshader")
	sm.set_shader_parameter("albedo", b.albedo_color)
	sm.set_shader_parameter("albedo_tex", b.albedo_texture)
	if b.emission_enabled:
		sm.set_shader_parameter("emission", b.emission)
		sm.set_shader_parameter("emission_energy", b.emission_energy_multiplier)
		sm.set_shader_parameter("emission_tex", b.emission_texture)
	sm.set_shader_parameter("roughness", b.roughness)
	sm.set_shader_parameter("amplitude", amplitude)
	sm.set_shader_parameter("height_ref", height_ref)
	sm.set_shader_parameter("flutter", flutter)
	sm.set_shader_parameter("clip_below", clip)
	_wind_cache[key] = sm
	return sm


## Меши пакета с трансформом относительно корня (для MultiMesh).
var mesh_parts_cache := {}

func mesh_parts(id: String) -> Array:
	if mesh_parts_cache.has(id):
		return mesh_parts_cache[id]
	var root := asset(id)
	var out: Array = []
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it = stack.pop_back()
		var cur: Node = it[0]
		var t: Transform3D = it[1]
		if cur is MeshInstance3D and (cur as MeshInstance3D).mesh:
			var mi := cur as MeshInstance3D
			var mats: Array = []
			for i in mi.mesh.get_surface_count():
				mats.append(mi.get_active_material(i))
			var leaf := str(mi.name).begins_with("Leaves")
			var lm: Material = root.get("leaf_material") if leaf else null
			out.append([mi.mesh, t, mats, leaf, lm])
		for c in cur.get_children():
			if c is Node3D:
				stack.append([c, t * (c as Node3D).transform])
	root.free()
	mesh_parts_cache[id] = out
	return out


# ======================= этапы =======================

func _build_ground(g: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = LevelTerrain.build_mesh()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain_v3.gdshader")
	m.set_shader_parameter("grass_tex", load("res://assets/textures/grass_tile.png"))
	m.set_shader_parameter("dirt_tex", load("res://assets/textures/dirt_tile.png"))
	m.set_shader_parameter("sand_tex", load("res://assets/textures/sand_tile.png"))
	m.set_shader_parameter("noise_tex", water_noise())
	mi.material_override = m
	g.add_child(mi)


func _build_river(g: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(LevelTerrain.WORLD, LevelTerrain.WORLD)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	mi.mesh = pm
	mi.position.y = LevelTerrain.WATER_Y
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("noise_tex", water_noise())
	m.set_shader_parameter("flow_speed", 0.045)
	m.set_shader_parameter("noise_scale", 0.09)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
	focus["water"] = _marker(g, "FocusWater", Vector3(LevelTerrain.river_x(-6.0), LevelTerrain.WATER_Y, -6.0))


func _build_grass(g: Node3D) -> void:
	_grass_field(g, "Meadow", grass_count, 31.0, 0.0)
	_grass_field(g, "HillGrass", hill_grass, 62.0, 29.0)
	# редкие крупные кусты травы из студии
	_scatter_mm(g, "GrassClumps", ["grass_1", "grass_2"], 100, 30.0, 4.6, Vector2(0.8, 1.3), 0.06, false)
	# цветы студии полянами
	_scatter_mm(g, "Flowers", ["flower_1", "flower_2"], 420, 29.0, 5.6, Vector2(0.55, 0.9), 0.04, true)
	# кусты и папоротник: по краю леса и у берега
	var k := 0
	var tries := 0
	while k < 46 and tries < 3000:
		tries += 1
		var x := _rng.randf_range(-40, 40)
		var z := _rng.randf_range(-40, 40)
		var q := _q(x, z)
		var d := LevelTerrain.river_dist(x, z)
		var near_edge := q > 22.0 and q < 38.0
		var near_bank := d > 4.6 and d < 7.0 and q < 30.0
		if not (near_edge or near_bank) or not _free(x, z, 1.2) or LevelTerrain.normal(x, z).y < 0.85:
			continue
		var id := "bush_1" if k % 3 != 2 else "fern"
		var n := place(id, x, z, _rng.randf() * TAU, _rng.randf_range(0.9, 1.6) if id == "bush_1" else _rng.randf_range(1.1, 1.7), g, 0.06)
		Wander.obstacles.append(Vector3(x, z, 0.8))
		apply_wind(n, 0.05, 1.0)
		k += 1


## Процедурная трава: MultiMesh из пучков, куски 4 x 4 со своей дальностью видимости.
func _grass_field(g: Node3D, node_name: String, count: int, outer: float, inner: float) -> void:
	const CH := 6
	var span := outer * 2.0
	var cell := span / CH
	var buckets: Array = []
	for i in CH * CH:
		buckets.append([])
	var base := Color("7fb34a")
	var n := 0
	var tries := 0
	while n < count and tries < count * 20:
		tries += 1
		var x := _rng.randf_range(-outer, outer)
		var z := _rng.randf_range(-outer, outer)
		var q := _q(x, z)
		if q < inner or q > outer:
			continue
		var h := LevelTerrain.height(x, z)
		if LevelTerrain.river_dist(x, z) < 4.5 or h < LevelTerrain.WATER_Y + 0.25:
			continue
		if LevelTerrain.normal(x, z).y < 0.8 or not _outside_props(x, z):
			continue
		var patch := 0.5 + 0.5 * sin(x * 0.31) * sin(z * 0.27) + 0.25 * sin(x * 0.9 + z * 0.7)
		if _rng.randf() > 0.42 + 0.58 * clampf(patch, 0.0, 1.0):
			continue
		var sc := _rng.randf_range(0.75, 1.35)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc * _rng.randf_range(0.8, 1.3), sc))
		var col := Color.from_hsv(base.h + _rng.randf_range(-0.035, 0.03), base.s * _rng.randf_range(0.8, 1.05), base.v * _rng.randf_range(0.85, 1.12))
		var cx := clampi(int((x + outer) / cell), 0, CH - 1)
		var cz := clampi(int((z + outer) / cell), 0, CH - 1)
		buckets[cz * CH + cx].append([Transform3D(basis, Vector3(x, h - 0.03, z)), col])
		n += 1
	var root := Node3D.new()
	root.name = node_name
	g.add_child(root)
	var mesh := grass_mesh()
	var mat := Placeholders.wind_material(Color(0.8, 0.88, 0.66), 0.05, 0.4)
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
		mmi.visibility_range_end = 90.0
		mmi.visibility_range_end_margin = 15.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		root.add_child(mmi)


## Россыпь ассета через MultiMesh (цветы, кусты травы). patches — растут полянами.
func _scatter_mm(g: Node3D, node_name: String, ids: Array, count: int, outer: float, river_min: float, sc: Vector2, amp: float, patches: bool) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.set_meta("asset", ids[0])
	g.add_child(root)
	for id in ids:
		var xs: Array = []
		var tries := 0
		while xs.size() < count / ids.size() and tries < 20000:
			tries += 1
			var x := _rng.randf_range(-outer, outer)
			var z := _rng.randf_range(-outer, outer)
			if LevelTerrain.river_dist(x, z) < river_min or LevelTerrain.normal(x, z).y < 0.85 or not _outside_props(x, z):
				continue
			if patches and sin(x * 0.5 + 1.0) * sin(z * 0.43) < 0.25:
				continue
			var s := _rng.randf_range(sc.x, sc.y)
			xs.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, LevelTerrain.height(x, z) - 0.02, z)))
			layout.append([id, x, z, 0.0, s])
			if not patches:
				Wander.obstacles.append(Vector3(x, z, 0.45 * s))   # кусты травы: звери и камера обходят
		for part in mesh_parts(id):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			mm.instance_count = xs.size()
			for i in xs.size():
				mm.set_instance_transform(i, xs[i] * (part[1] as Transform3D))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_mm" % id
			mmi.multimesh = mm
			mmi.material_override = part[4] if (part[3] and part[4] != null) else wind_material(part[2][0], amp, 0.6, 0.004)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 70.0
			root.add_child(mmi)


func _build_trees(g: Node3D) -> void:
	# рощи на поляне: смешанные породы, разный масштаб и поворот
	var clusters := [Vector2(-20, -9), Vector2(-15, 18), Vector2(21, -19), Vector2(23, 19), Vector2(-5, -24), Vector2(-24, 5)]
	var i := 0
	var tries := 0
	while i < 34 and tries < 6000:
		tries += 1
		var c: Vector2 = clusters[i % clusters.size()]
		var x := c.x + _rng.randf_range(-7.5, 7.5)
		var z := c.y + _rng.randf_range(-7.5, 7.5)
		if not _tree_spot(x, z, 3.8):
			continue
		_tree(TREES[(i * 7 + _rng.randi() % 3) % TREES.size()], x, z, _rng.randf_range(1.1, 1.5), g)
		i += 1
	# одиночные деревья на поляне — для крупных планов
	focus["hero_tree"] = _tree("tree_oak_3", -7.0, 5.5, 1.5, g)
	_tree("tree_apple_1", 19.0, 3.0, 1.3, g)
	_tree("tree_birch_2", -10.5, -12.0, 1.4, g)
	if ring_forest:
		_build_ring(g)


func _tree(id: String, x: float, z: float, s: float, g: Node3D) -> Node3D:
	# у части деревьев студия оставила «подставку» с травой — срезаем её шейдером и чуть топим ствол
	var n := place(id, x, z, _rng.randf() * TAU, s, g, 0.16, 0.35)
	apply_wind(n, 0.07, 5.0, 0.012, 0.14)
	_trees_xz.append(Vector3(x, z, 2.0 * s))
	tree_list.append(Vector4(x, n.position.y, z, s))
	Wander.obstacles.append(Vector3(x, z, 0.45 * s))
	return n


func _tree_spot(x: float, z: float, spacing: float) -> bool:
	if not _free(x, z, 0.0) or LevelTerrain.river_dist(x, z) < 6.0:
		return false
	if Vector2(x + 7.0, z - 5.5).length() < 10.0:            # вокруг дуба для крупного плана — простор
		return false
	for t in _trees_xz:
		if Vector2(x - t.x, z - t.y).length() < spacing:
			return false
	return true


## Лес на холмах вокруг поляны: MultiMesh по породам (сотни деревьев, мало вызовов отрисовки).
func _build_ring(g: Node3D) -> void:
	var per := {}
	for id in TREES:
		per[id] = []
	var step := 5.6
	var half := 94.0                                   # лес до 94 м от центра, дальше — холмы в дымке
	var gx := -half
	while gx <= half:
		var gz := -half
		while gz <= half:
			var x := gx + _rng.randf_range(-2.2, 2.2)
			var z := gz + _rng.randf_range(-2.2, 2.2)
			gz += step
			var q := _q(x, z)
			if q < 27.0:
				continue
			if q < 34.0 and _rng.randf() < 0.45:          # опушка реже
				continue
			if LevelTerrain.river_dist(x, z) < 7.5 + clampf((q - 30.0) * 0.1, 0.0, 4.0):
				continue
			if LevelTerrain.normal(x, z).y < 0.7:
				continue
			var id: String = TREES[_rng.randi() % TREES.size()]
			if q > 55.0 and _rng.randf() < 0.45:            # дальше — больше елей
				id = TREES[3 + _rng.randi() % 3]
			var s := _rng.randf_range(1.2, 1.8)
			var y := ground_min(x, z, 0.35 * s) - 0.16 * s
			per[id].append([Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, y, z)), q])
			tree_list.append(Vector4(x, y, z, s))
			layout.append([id, x, z, 0.0, s])
			if q < 34.0:
				_trees_xz.append(Vector3(x, z, 2.0 * s))
		gx += step
	var root := Node3D.new()
	root.name = "RingForest"
	root.set_meta("asset", "ring")
	g.add_child(root)
	for id in TREES:
		var items: Array = per[id]
		if items.is_empty():
			continue
		for part in mesh_parts(id):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0] if part[3] else smooth_mesh(part[0])
			mm.instance_count = items.size()
			for k in items.size():
				var t: Transform3D = items[k][0] * (part[1] as Transform3D)
				mm.set_instance_transform(k, t)
				ring.append([mm, k, t, items[k][1], items[k][0].origin])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_ring" % id
			mmi.multimesh = mm
			if part[3] and part[4] != null:
				mmi.material_override = part[4]                  # листва: материал пакета с ветром
			else:
				var leafy := false
				for pp in mesh_parts_cache.get(id, []):
					leafy = leafy or pp[3]
				mmi.material_override = wind_material(part[2][0], 0.0 if leafy else 0.07, 5.0, 0.0 if leafy else 0.012, 0.14)
			root.add_child(mmi)


func _build_rocks(g: Node3D) -> void:
	var i := 0
	var tries := 0
	while i < 16 and tries < 900:                                       # по берегам
		tries += 1
		var z := _rng.randf_range(-29, 29)
		var side := 1.0 if i % 2 == 0 else -1.0
		var x := LevelTerrain.river_x(z) + side * _rng.randf_range(3.6, 5.2)
		if absf(z - BRIDGE_Z) < 4.0 or not _free(x, z, 0.6):
			continue
		var id := "rock_3" if i % 3 != 1 else "rock_5"
		var s := _rng.randf_range(0.7, 1.5)
		var n := place(id, x, z, _rng.randf() * TAU, s, g, 0.12, 0.3)
		Wander.obstacles.append(Vector3(x, z, 0.55 * s))
		i += 1
	var big := [Vector2(-16.0, -6.5), Vector2(-23.0, 13.0), Vector2(19.0, -12.0), Vector2(-3.0, 24.0), Vector2(26.0, 6.0)]
	for k in big.size():                                                 # валуны и каменные горки
		var p: Vector2 = big[k]
		var id := "rock_6" if k % 2 == 0 else "rock_5"
		var s := _rng.randf_range(1.0, 1.4) if id == "rock_6" else _rng.randf_range(1.6, 2.4)
		place(id, p.x, p.y, _rng.randf() * TAU, s, g, 0.15, 0.4)
		Wander.obstacles.append(Vector3(p.x, p.y, 0.9 * s))
	# камни на холмах среди леса
	var r := 0
	tries = 0
	while r < 26 and tries < 2000:
		tries += 1
		var x := _rng.randf_range(-70, 70)
		var z := _rng.randf_range(-70, 70)
		var q := _q(x, z)
		if q < 30.0 or q > 70.0 or LevelTerrain.river_dist(x, z) < 6.0:
			continue
		var id: String = ["rock_5", "rock_3", "rock_6"][r % 3]
		place(id, x, z, _rng.randf() * TAU, _rng.randf_range(1.5, 3.0), g, 0.2, 0.4)
		r += 1


func _build_props(g: Node3D) -> void:
	# домик: дверь к костру и реке (−X)
	var house := place("house", HOUSE_POS.x, HOUSE_POS.y, PI * 0.5, 1.6, g, 0.06, 2.4)
	focus["house"] = house
	solid_list.append(Vector4(HOUSE_POS.x, house.position.y, HOUSE_POS.y, 4.2))
	Wander.obstacles.append(Vector3(HOUSE_POS.x, HOUSE_POS.y, 4.0))
	# мост поперёк русла
	var bx := LevelTerrain.BRIDGE_C.x
	var bridge := asset("bridge")
	bridge.scale = Vector3(1.7, 1.25, 2.55)                         # длина пролёта ~8.6 м
	bridge.rotation.y = LevelTerrain.BRIDGE_YAW
	var by := LevelTerrain.BRIDGE_Y                                 # концы настила лежат на насыпях (level_terrain.gd)
	bridge.position = Vector3(bx, by, BRIDGE_Z)
	g.add_child(bridge)
	layout.append(["bridge", bx, BRIDGE_Z, bridge.rotation.y, 1.0])
	_bridge_piles(g, bridge)
	focus["bridge"] = bridge
	solid_list.append(Vector4(bx, by - 2.0, BRIDGE_Z, 4.5))
	# костёр, бревна-скамейки
	var fire := place("campfire", FIRE_POS.x, FIRE_POS.y, 0.4, 1.5, g, 0.02, 0.4)
	focus["campfire"] = fire
	boost_fire.call_deferred(fire, 2.6)
	Wander.obstacles.append(Vector3(FIRE_POS.x, FIRE_POS.y, 1.0))
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 1.3
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.position = Vector3(FIRE_POS.x, LevelTerrain.height(FIRE_POS.x, FIRE_POS.y) + 0.8, FIRE_POS.y)
	light.set_script(load("res://scripts/fire_flicker.gd"))
	g.add_child(light)
	place("log", FIRE_POS.x - 1.4, FIRE_POS.y + 0.3, 0.15, 1.0, g, 0.06, 0.6)
	place("log", FIRE_POS.x + 0.3, FIRE_POS.y + 1.5, PI * 0.5 + 0.3, 1.0, g, 0.06, 0.6)
	Wander.obstacles.append(Vector3(FIRE_POS.x - 1.6, FIRE_POS.y + 0.3, 1.0))
	Wander.obstacles.append(Vector3(FIRE_POS.x + 0.4, FIRE_POS.y + 1.7, 1.0))
	# бочки, ящики и сундук у стены дома (локально: x вдоль фасада, z наружу от двери)
	var spots := [["barrel", Vector2(-4.2, 2.6)], ["barrel", Vector2(-4.3, 1.5)], ["barrel", Vector2(-3.3, 2.0)],
		["crate", Vector2(4.2, 2.2)], ["crate", Vector2(4.3, 1.2)], ["crate", Vector2(4.2, 1.7)], ["chest", Vector2(2.2, 4.0)]]
	for k in spots.size():
		var id: String = spots[k][0]
		var p := _house_point(spots[k][1])
		var s := 1.15
		var n := place(id, p.x, p.z, _rng.randf_range(-0.5, 0.5) + PI * 0.5, s, g, 0.02, 0.3)
		if k == 5:                                                      # ящик на ящике
			n.position.y = ground_min(p.x, p.z, 0.3) + 0.8 * s - 0.02
		Wander.obstacles.append(Vector3(p.x, p.z, 0.6))
	focus["chest"] = g.get_child(g.get_child_count() - 1)
	# факелы студии (в Godot выглядят нормально; превью в контактном листе было чёрным — ошибка превью):
	# ручной факел 0.64 м, ставим как столбик-факел 1.5 м у двери и у моста
	for k in 2:
		var dp := _house_point(Vector2(-1.5 + 3.0 * k, 3.9))
		place("torch_%d" % (k + 1), dp.x, dp.z, 0.0, 2.4, g, 0.02, 0.05)
		Wander.obstacles.append(Vector3(dp.x, dp.z, 0.3))
	var tbx := LevelTerrain.river_x(BRIDGE_Z)
	for k in 2:
		var tx := tbx + (4.7 if k == 0 else -4.6)
		var tz := BRIDGE_Z + (1.5 if k == 0 else -1.5)
		place("torch_%d" % (2 - k), tx, tz, 0.0, 2.4, g, 0.02, 0.05)
		Wander.obstacles.append(Vector3(tx, tz, 0.3))
	place("log", -12.0, 8.0, 0.9, 1.5, g, 0.06, 0.6)                  # бревно на поляне
	Wander.obstacles.append(Vector3(-12.0, 8.0, 1.4))


func _build_animals(g: Node3D) -> void:
	focus["deer"] = _animal("deer", Vector2(-8.0, -3.0), g, 1.0, 1.3, 1.25, 0.12, 0.35, 7.0)
	focus["deer2"] = _animal("deer", Vector2(14.0, 13.0), g, 1.05, 1.3, 1.25, 0.1, 0.0, 7.0)
	focus["fox"] = _animal("fox", Vector2(16.0, 6.0), g, 1.35, 2.2, 2.0, 0.25, 0.0, 6.0)
	var best_clear := -1.0
	var hares := [Vector2(-9.0, 10.0), Vector2(-3.0, 3.0), Vector2(-13.0, 1.0), Vector2(15.0, -1.5)]
	for i in hares.size():
		var h := _animal("hare", hares[i], g, 1.25, 1.0, 1.6, 0.3, 0.0, 4.5)   # hop — спокойно, run — перебежки
		h.set("idle_time", Vector2(1.0, 3.5))
		var clear := _clearance(hares[i])
		if clear > best_clear:                                   # для крупного плана — заяц на самом открытом месте
			best_clear = clear
			focus["hare"] = h
	var sp := [Vector2(10.5, 1.5), Vector2(12.0, 3.0), Vector2(9.8, 3.6), Vector2(11.6, 0.4), Vector2(13.0, 1.8)]
	for i in sp.size():
		var s := _animal("sparrow", sp[i], g, 1.8, 2.0, 2.0, 0.0, 0.0, 1.2)
		s.set("idle_time", Vector2(0.6, 2.2))
		s.set("turn_speed", 4.0)
		if i == 0:
			focus["sparrow"] = s
	for i in 2:                                                      # вороны кружат над поляной
		var b := BirdOrbit.new()
		b.name = "Crow_%d" % i
		b.center = Vector2(2.0 + 3.0 * i, 1.0 - 2.0 * i)
		b.radius = Vector2(16.0 - 3.0 * i, 11.0 + 2.0 * i)
		b.altitude = 11.0 + 3.5 * i
		b.speed = 0.24 - 0.03 * i
		b.phase = PI * i
		var c := asset("crow")
		c.scale = Vector3.ONE * 2.2
		b.add_child(c)
		b.set_meta("asset", "crow")
		g.add_child(b)
		focus["crow_%d" % i] = b


func _animal(kind: String, at: Vector2, g: Node3D, s: float, walk_rate: float, run_rate: float, run_chance: float, shore: float, radius: float) -> Node3D:
	_animal_n += 1
	var a := Wander.new()
	a.name = "%s_%d" % [kind.capitalize(), _animal_n]
	a.position = Vector3(at.x, LevelTerrain.height(at.x, at.y), at.y)
	a.scale = Vector3.ONE * s * _rng.randf_range(0.94, 1.06)
	a.walk_stride = stride(kind)[0]
	a.run_stride = stride(kind)[1]
	a.walk_rate = walk_rate
	a.run_rate = run_rate
	a.run_chance = run_chance
	a.shore_chance = shore
	a.wander_radius = radius
	a.tempo = _rng.randf_range(0.92, 1.08)
	a.turn_speed = 1.4 if kind == "deer" else 2.4
	a.set_meta("asset", kind)
	a.add_child(asset(kind))
	g.add_child(a)
	layout.append(["animal_" + kind, at.x, at.y, 0.0, s])
	return a


# ======================= помощники =======================

func _clearance(p: Vector2) -> float:
	var m := 99.0
	for t in _trees_xz:
		m = minf(m, Vector2(t.x, t.y).distance_to(p) - t.z)
	return m


static func _q(x: float, z: float) -> float:
	return pow(pow(absf(x), 4.0) + pow(absf(z), 4.0), 0.25)


func _house_point(local_xz: Vector2) -> Vector3:
	var b := Basis(Vector3.UP, -PI * 0.5)
	var p := b * Vector3(local_xz.x, 0, local_xz.y) + Vector3(HOUSE_POS.x, 0, HOUSE_POS.y)
	p.y = LevelTerrain.height(p.x, p.z)
	return p


## Свободно ли место от дома, костра, моста (для деревьев, кустов, камней).
func _free(x: float, z: float, extra: float) -> bool:
	if LevelTerrain.is_water(x, z, 0.3):
		return false
	if Vector2(x - HOUSE_POS.x, z - HOUSE_POS.y).length() < 8.0 + extra:
		return false
	if Vector2(x - FIRE_POS.x, z - FIRE_POS.y).length() < 4.0 + extra:
		return false
	if absf(z - BRIDGE_Z) < 3.0 + extra and LevelTerrain.river_dist(x, z) < 8.0:
		return false
	for t in _trees_xz:
		if Vector2(x - t.x, z - t.y).length() < 1.0 + extra:
			return false
	return true


## Сваи моста: от дна русла до низа настила, материал — текстура самого моста (triplanar).
## Камни и папоротник у откосов насыпей прячут стык земли и настила.
func _bridge_piles(g: Node3D, bridge: Node3D) -> void:
	var src := bridge.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var base := src.get_active_material(0) as BaseMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = base.albedo_texture if base else null
	mat.albedo_color = Color(0.85, 0.75, 0.68)
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.8, 0.8, 0.8)
	mat.roughness = 0.85
	var along := Vector2(sin(LevelTerrain.BRIDGE_YAW), cos(LevelTerrain.BRIDGE_YAW))
	var across := Vector2(-along.y, along.x)
	var top := LevelTerrain.BRIDGE_Y + 0.38                          # низ настила
	for ia in [-1.7, 0.0, 1.7]:
		for iw in [-1.25, 1.25]:
			var p: Vector2 = LevelTerrain.BRIDGE_C + along * float(ia) + across * float(iw)
			var bottom := LevelTerrain.height(p.x, p.y) - 0.25
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.11
			cyl.bottom_radius = 0.13
			cyl.height = top - bottom
			cyl.radial_segments = 10
			cyl.rings = 1
			cyl.material = mat
			var mi := MeshInstance3D.new()
			mi.name = "Pile"
			mi.mesh = cyl
			mi.position = Vector3(p.x, (top + bottom) * 0.5, p.y)
			g.add_child(mi)
	var spots := [[3.0, 2.0], [3.0, -2.0], [-3.0, 2.0], [-3.0, -2.0]]
	for k in spots.size():
		var sa: float = spots[k][0]
		var sw: float = spots[k][1]
		var p: Vector2 = LevelTerrain.BRIDGE_C + along * sa + across * sw
		place("rock_3" if k % 2 == 0 else "rock_5", p.x, p.y, _rng.randf() * TAU, _rng.randf_range(0.55, 0.75), g, 0.15, 0.2)
		var f: Vector2 = LevelTerrain.BRIDGE_C + along * (sa * 1.25) + across * (sw * 1.25)
		var n := place("fern", f.x, f.y, _rng.randf() * TAU, 1.2, g, 0.06, 0.2)
		apply_wind(n, 0.05, 1.0)


## Трава и цветы не растут в доме, костре и под настилом моста.
func _outside_props(x: float, z: float) -> bool:
	var bl := LevelTerrain.bridge_local(x, z)
	if absf(bl.x) < 4.7 and absf(bl.y) < 1.9:
		return false
	if Vector2(x - HOUSE_POS.x, z - HOUSE_POS.y).length() < 4.6:
		return false
	if Vector2(x - FIRE_POS.x, z - FIRE_POS.y).length() < 1.3:
		return false
	return true


func _marker(g: Node3D, node_name: String, p: Vector3) -> Node3D:
	var m := Marker3D.new()
	m.name = node_name
	m.position = p
	g.add_child(m)
	return m


static var _water_noise: Texture2D

## Шум воды из генератора текстур студии (assets/textures/water_perlin_gray_tile.png).
static func water_noise() -> Texture2D:
	if _water_noise == null:
		_water_noise = load("res://assets/textures/water_perlin_gray_tile.png")
	return _water_noise


## Пучок травы: 7 изогнутых травинок из двух сегментов (~28 тр.), основание темнее, кончик светлее.
static func grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 7:
		var a := i * TAU / 7.0 + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var root := dir * rng.randf_range(0.0, 0.06)
		var h := rng.randf_range(0.24, 0.38)
		var lean := rng.randf_range(0.08, 0.18)
		var w := 0.035
		var p0a := root - side * w
		var p0b := root + side * w
		var mid := root + dir * lean * 0.4 + Vector3(0, h * 0.55, 0)
		var p1a := mid - side * w * 0.6
		var p1b := mid + side * w * 0.6
		var tip := root + dir * lean + Vector3(0, h, 0)
		var c0 := Color(0.55, 0.55, 0.55)
		var c1 := Color(0.85, 0.85, 0.85)
		var c2 := Color(1.0, 1.02, 0.9)
		for tri in [[p0a, c0, p0b, c0, p1a, c1], [p0b, c0, p1b, c1, p1a, c1], [p1a, c1, p1b, c1, tip, c2]]:
			for v in 3:
				st.set_color(tri[v * 2 + 1])
				st.set_normal(Vector3(dir.x * 0.25, 1.0, dir.z * 0.25).normalized())   # как у земли: трава не «блестит» боками
				st.add_vertex(tri[v * 2])
	return st.commit()


## Сглаженные нормали (по совпадающим позициям вершин): мятые после упрощения кроны
## становятся мягкими, «мультяшными». Геометрия ассета не меняется.
static var _smooth_cache := {}

static func smooth_mesh(mesh: Mesh) -> Mesh:
	if mesh == null or not (mesh is ArrayMesh):
		return mesh
	if _smooth_cache.has(mesh):
		return _smooth_cache[mesh]
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var orig = arr[Mesh.ARRAY_NORMAL]
		var acc := {}
		var keys: Array[Vector3i] = []
		keys.resize(v.size())
		for i in v.size():
			keys[i] = Vector3i((v[i] * 500.0).round())
		var tri_n := idx.size() if idx.size() > 0 else v.size()
		for t in range(0, tri_n, 3):
			var a := idx[t] if idx.size() > 0 else t
			var b := idx[t + 1] if idx.size() > 0 else t + 1
			var c := idx[t + 2] if idx.size() > 0 else t + 2
			var fn := (v[b] - v[a]).cross(v[c] - v[a])
			for k in [a, b, c]:
				acc[keys[k]] = acc.get(keys[k], Vector3.ZERO) + fn
		var norms := PackedVector3Array()
		norms.resize(v.size())
		for i in v.size():
			var nn: Vector3 = acc[keys[i]]
			if orig is PackedVector3Array and orig.size() == v.size() and nn.dot(orig[i]) < 0.0:
				nn = -nn
			norms[i] = nn.normalized() if nn.length() > 0.0 else Vector3.UP
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(si, mesh.surface_get_material(si))
	_smooth_cache[mesh] = out
	return out


## Огонь костра из пакета студии рассчитан на костёр 0.5 м; в сцене костёр крупнее —
## увеличиваем частицы и скорость подъёма под его масштаб (сам эффект тот же).
func boost_fire(fire: Node, k: float) -> void:
	for n in fire.find_children("*", "GPUParticles3D", true, false):
		var p := n as GPUParticles3D
		var pm := (p.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		pm.initial_velocity_min *= k
		pm.initial_velocity_max *= k
		pm.gravity *= k
		pm.emission_sphere_radius *= k * 1.4
		p.process_material = pm
		if p.draw_pass_1 is QuadMesh:
			var q := (p.draw_pass_1 as QuadMesh).duplicate() as QuadMesh
			q.size *= k * (1.15 if str(p.name).contains("fire") else 0.8)
			p.draw_pass_1 = q
		p.amount = int(p.amount * 1.6)
		p.visibility_aabb = p.visibility_aabb.grow(2.0)
	for n in fire.find_children("*", "OmniLight3D", true, false):
		(n as OmniLight3D).omni_range *= k
