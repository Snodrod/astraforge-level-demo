class_name Populate
extends RefCounted
## Подставляет реальные пакеты студии вместо заглушек по assets/manifest.json.
##
## Как это работает:
##   1. читаем assets/manifest.json (формат гибкий: список или словарь, см. _normalize);
##   2. для каждого слота (AssetSlot / 2D-слот) ищем ассеты того же вида (kind);
##   3. слот.fill(ассет) — одна операция: заглушка уходит, на её месте пакет;
##   4. деревья и кусты получают шейдер ветра, трава — мэш из ассета, животные — wander.
## Нет ассета нужного вида — заглушка остаётся, ничего не ломается.
##
## Запуск без сцены (проверка + запись сцены с реальными ассетами):
##   godot --headless --path . --script scripts/populate_cli.gd -- --bake

const ASSETS := "res://assets"

## Ожидаемая высота (м) по виду: если ассет отличается больше чем в ~3 раза — масштабируем.
## (ассеты станут детальнее: дерево 4-6 тыс. тр., дом 12-20 тыс. — размеры в метрах те же)
const EXPECT := {"tree": 6.0, "bush": 1.2, "rock": 0.9, "house": 5.0, "barrel": 0.95, "crate": 0.85,
	"torch": 1.6, "campfire": 0.6, "hare": 0.4, "deer": 1.5, "fox": 0.6, "bird": 0.3}

const KIND_WORDS := [
	["hare", ["hare", "rabbit", "bunny", "заяц"]],
	["deer", ["deer", "stag", "олень", "олен"]],
	["fox", ["fox", "лис"]],
	["bird", ["bird", "sparrow", "crow", "eagle", "owl", "птиц"]],
	["bush", ["bush", "shrub", "fern", "куст"]],
	["campfire", ["campfire", "bonfire", "fireplace", "костёр", "костер"]],
	["torch", ["torch", "факел"]],
	["barrel", ["barrel", "бочк"]],
	["crate", ["crate", "box", "chest", "ящик", "сундук"]],
	["bridge", ["bridge", "мост"]],
	["house", ["house", "hut", "cabin", "cottage", "домик"]],
	["rock", ["rock", "stone", "boulder", "камен", "камн"]],
	["grass", ["grass", "tuft", "трав"]],
	["tree", ["tree", "oak", "spruce", "fir", "pine", "birch", "дерев", "дуб", "ель", "берез"]],
]

static var _entries: Array = []
static var _loaded := false


# ======================= манифест =======================

static func load_manifest(force := false) -> Array:
	if _loaded and not force:
		return _entries
	_loaded = true
	_entries = []
	var path := ASSETS + "/manifest.json"
	if not FileAccess.file_exists(path):
		# манифеста нет — каждая подпапка assets/ считается ассетом (id = имя папки)
		var da := DirAccess.open(ASSETS)
		if da:
			for d in da.get_directories():
				if d.begins_with("_") or d == "textures":
					continue
				var e := _normalize({"id": d})
				if not e.is_empty() and (e.scene != "" or not e.frames.is_empty()):
					_entries.append(e)
		return _entries
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_warning("populate: manifest.json не разобрался как JSON")
		return _entries
	var items: Array = []
	if data is Array:
		items = data
	elif data is Dictionary:
		var holder = data
		for key in ["assets", "items", "packages", "entries", "list"]:
			if data.has(key):
				holder = data[key]
				break
		if holder is Array:
			items = holder
		elif holder is Dictionary:                       # словарь «id -> запись»
			for k in holder:
				if holder[k] is Dictionary:
					var e: Dictionary = (holder[k] as Dictionary).duplicate()
					if not e.has("id"):
						e["id"] = k
					items.append(e)
	for it in items:
		if it is Dictionary:
			var e := _normalize(it)
			if not e.is_empty():
				_entries.append(e)
	return _entries


## Запись манифеста -> {id, kind, species, scene, frames[], raw}. Любое поле может быть пустым.
static func _normalize(raw: Dictionary) -> Dictionary:
	var id := ""
	for k in ["id", "asset_id", "name", "slug"]:
		if raw.has(k) and str(raw[k]) != "":
			id = str(raw[k])
			break
	if id == "":
		return {}
	var kind_text := ""
	for k in ["kind", "role", "category", "type", "group", "class"]:
		if raw.has(k):
			kind_text += " " + str(raw[k]).to_lower()
	var kind := _infer_kind(kind_text)
	if kind == "":
		kind = _infer_kind(id.to_lower())
	var dirs: Array = []
	for k in ["path", "dir", "package", "package_dir", "folder", "godot"]:
		if raw.has(k) and raw[k] is String and str(raw[k]) != "":
			dirs.append(_to_res(str(raw[k])))
	dirs.append(ASSETS + "/" + id)
	var scene := ""
	for k in ["scene", "tscn", "godot_scene", "package_scene", "glb", "model"]:
		if raw.has(k) and raw[k] is String:
			var p := _to_res(str(raw[k]))
			if FileAccess.file_exists(p):
				scene = p
				break
			for d in dirs:
				if FileAccess.file_exists(str(d) + "/" + str(raw[k])):
					scene = str(d) + "/" + str(raw[k])
					break
			if scene != "":
				break
	if scene == "":
		for d in dirs:
			if FileAccess.file_exists(str(d) + "/" + id + ".tscn"):
				scene = str(d) + "/" + id + ".tscn"
				break
			if FileAccess.file_exists(str(d) + "/godot_package/" + id + ".tscn"):
				scene = str(d) + "/godot_package/" + id + ".tscn"
				break
			if FileAccess.file_exists(d) and str(d).ends_with(".tscn"):
				scene = d
				break
			var found := _find_files(str(d), ["tscn"], false)
			if found.is_empty():
				found = _find_files(str(d), ["glb"], false)
			if not found.is_empty():
				scene = found[0]
				break
	var frames: Array = []
	for k in ["frames", "sprite_frames", "sprites_tres", "tres"]:
		if raw.has(k) and raw[k] is String and FileAccess.file_exists(_to_res(str(raw[k]))):
			frames.append(_to_res(str(raw[k])))
	if frames.is_empty():
		for d in dirs:
			frames.append_array(_find_files(str(d), ["tres"], true, "_frames"))
	return {"id": id, "kind": kind, "species": _species(id), "scene": scene, "frames": frames, "raw": raw}


static func _infer_kind(text: String) -> String:
	if text.strip_edges() == "":
		return ""
	for pair in KIND_WORDS:
		for w in pair[1]:
			if text.contains(w):
				return pair[0]
	return ""


## oak_v02, oak_003, oak-2 -> "oak": варианты одной породы.
static func _species(id: String) -> String:
	var re := RegEx.new()
	re.compile("[_\\-]?(v|var|variant|seed)?[_\\-]?\\d+$")
	var s := id.to_lower()
	var guard := 0
	while guard < 3:
		var n := re.sub(s, "")
		if n == s or n == "":
			break
		s = n
		guard += 1
	return s


## Абсолютный путь студии (C:\...\assets\oak\...) -> res://assets/oak/...
static func _to_res(p: String) -> String:
	var s := p.replace("\\", "/")
	if s.begins_with("res://"):
		return s
	var idx := s.rfind("/assets/")
	if idx >= 0:
		return ASSETS + "/" + s.substr(idx + 8)
	if s.begins_with("assets/"):
		return "res://" + s
	return ASSETS + "/" + s.trim_prefix("./")


static func _find_files(dir: String, exts: Array, recursive: bool, contains := "") -> Array:
	var out: Array = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	da.list_dir_begin()
	var f := da.get_next()
	while f != "":
		var full := dir + "/" + f
		if da.current_is_dir():
			if recursive and not f.begins_with("."):
				out.append_array(_find_files(full, exts, true, contains))
		elif f.get_extension().to_lower() in exts and (contains == "" or f.contains(contains)):
			out.append(full)
		f = da.get_next()
	da.list_dir_end()
	out.sort()
	return out


## Выбор ассета для слота: вид -> порода по variant -> экземпляр по seed.
static func pick(kind: String, variant: int, seed_value: int, need: String) -> Dictionary:
	var list: Array = []
	for e in load_manifest():
		if e.kind == kind and (not e[need].is_empty()):
			list.append(e)
	if list.is_empty():
		return {}
	var species := {}
	for e in list:
		if not species.has(e.species):
			species[e.species] = []
		species[e.species].append(e)
	var keys := species.keys()
	keys.sort()
	var arr: Array = species[keys[absi(variant) % keys.size()]]
	return arr[absi(seed_value) % arr.size()]


# ======================= 3D =======================

static func apply_3d(root: Node) -> Dictionary:
	var report := {"manifest_entries": load_manifest().size(), "filled": 0, "placeholders": 0, "by_id": {}}
	if _entries.is_empty():
		report["placeholders"] = root.find_children("*", "AssetSlot", true, false).size()
		return report
	for n in root.find_children("*", "AssetSlot", true, false):
		var slot := n as AssetSlot
		var e := pick(slot.kind, slot.variant, hash(str(slot.name)), "scene")
		if e.is_empty():
			report["placeholders"] += 1
			continue
		var packed = load(e.scene)
		if packed == null or not (packed is PackedScene):
			push_warning("populate: %s не загрузился (импорт? запусти godot --headless --path . --import)" % e.scene)
			report["placeholders"] += 1
			continue
		var node := (packed as PackedScene).instantiate() as Node3D
		if node == null:
			report["placeholders"] += 1
			continue
		_fit_height(node, slot.target_height if slot.target_height > 0.0 else float(EXPECT.get(slot.kind, 0.0)), e.id)
		if slot.kind == "tree" or slot.kind == "bush":
			apply_wind(node, 0.07 if slot.kind == "tree" else 0.05)
		slot.fill(node, e.id)
		report["filled"] += 1
		report["by_id"][e.id] = int(report["by_id"].get(e.id, 0)) + 1
	_apply_grass(root)
	return report


## Трава: мэш из ассета вида grass идёт в MultiMesh вместо заглушки.
static func _apply_grass(root: Node) -> void:
	var e := pick("grass", 0, 0, "scene")
	if e.is_empty():
		return
	var holder := root.find_child("GrassTufts", true, false)
	var packed = load(e.scene)
	if holder == null or not (packed is PackedScene):
		return
	var inst := (packed as PackedScene).instantiate() as Node3D
	var src := _first_mesh(inst)
	if src == null:
		inst.free()
		return
	var chunks := holder.find_children("*", "MultiMeshInstance3D", true, false)
	for c in chunks:
		(c as MultiMeshInstance3D).multimesh.mesh = src.mesh
	var mat := src.get_active_material(0)
	var sm := Placeholders.wind_material(Color.WHITE, 0.04, maxf(_node_aabb(inst).size.y, 0.3))
	if mat is BaseMaterial3D:
		sm.set_shader_parameter("albedo_tex", mat.albedo_texture)
		if mat.albedo_texture == null:
			sm.set_shader_parameter("albedo", mat.albedo_color)
	for c in chunks:
		(c as MultiMeshInstance3D).material_override = sm
	inst.free()


## Шейдер ветра на все материалы ассета; цвет и текстуру берём из исходного материала.
static func apply_wind(node: Node, amplitude: float) -> void:
	var h := maxf(_node_aabb(node).size.y, 0.5)
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var base := mi.get_active_material(i)
			if base is ShaderMaterial:
				continue
			var sm := Placeholders.wind_material(Color.WHITE, amplitude, h)
			if base is BaseMaterial3D:
				sm.set_shader_parameter("albedo", base.albedo_color)
				if base.albedo_texture:
					sm.set_shader_parameter("albedo_tex", base.albedo_texture)
			mi.set_surface_override_material(i, sm)


static func _fit_height(node: Node3D, expect: float, id: String) -> void:
	if expect <= 0.0:
		return
	var h := _node_aabb(node).size.y
	if h <= 0.001:
		return
	var ratio := h / expect
	if ratio < 0.33 or ratio > 3.0:
		node.scale *= expect / h
		push_warning("populate: %s высотой %.2f м, ожидалось ~%.1f м — отмасштабирован" % [id, h, expect])


static func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _first_mesh(c)
		if r:
			return r
	return null


## AABB всех мешей узла в его локальных координатах (узел может быть вне дерева).
static func _node_aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array = [[n, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it = stack.pop_back()
		var cur: Node = it[0]
		var t: Transform3D = it[1]
		if cur is MeshInstance3D and cur.mesh:
			var b: AABB = t * cur.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		for c in cur.get_children():
			if c is Node3D:
				stack.append([c, t * (c as Node3D).transform])
	return box


# ======================= 2D =======================

## 2D-слот — AnimatedSprite2D с метаданными slot_kind / slot_variant (см. level_pixel.gd).
static func apply_2d(root: Node) -> Dictionary:
	var report := {"manifest_entries": load_manifest().size(), "filled": 0, "placeholders": 0}
	for n in root.find_children("*", "AnimatedSprite2D", true, false):
		if not n.has_meta("slot_kind"):
			continue
		var spr := n as AnimatedSprite2D
		var e := pick(str(spr.get_meta("slot_kind")), int(spr.get_meta("slot_variant", 0)), hash(str(spr.name)), "frames")
		if e.is_empty():
			report["placeholders"] += 1
			continue
		# из нескольких наборов листов предпочитаем пиксельный (путь содержит "pixel")
		var chosen: String = e.frames[0]
		for f in e.frames:
			if str(f).to_lower().contains("pixel"):
				chosen = f
				break
		var sf = load(chosen)
		if not (sf is SpriteFrames):
			push_warning("populate: %s не SpriteFrames" % chosen)
			report["placeholders"] += 1
			continue
		spr.sprite_frames = sf
		_apply_sprite_offset(spr, chosen)
		_apply_sprite_scale(spr, chosen)
		var names := (sf as SpriteFrames).get_animation_names()
		if names.size() > 0:
			var start := "idle_S" if (sf as SpriteFrames).has_animation("idle_S") else names[0]
			spr.play(start)
		spr.set_meta("filled_with", e.id)
		report["filled"] += 1
	return report


## sprites.json рядом с листами хранит godot_offset для AnimatedSprite2D.
static func _apply_sprite_offset(spr: AnimatedSprite2D, frames_path: String) -> void:
	var dir := frames_path.get_base_dir()
	for cand in [dir + "/sprites.json", dir.get_base_dir() + "/sprites.json"]:
		if FileAccess.file_exists(cand):
			var d = JSON.parse_string(FileAccess.get_file_as_string(cand))
			if d is Dictionary and d.has("godot_offset") and d["godot_offset"] is Array and d["godot_offset"].size() >= 2:
				spr.offset = Vector2(float(d["godot_offset"][0]), float(d["godot_offset"][1]))
				return


## Размер пикселя: уровень рассчитан на 24 px/м. Лист с другим pixels_per_meter приводим,
## если отношение целое (24/12 = 2, 48/24 = 0.5), чтобы пиксели оставались ровными.
static func _apply_sprite_scale(spr: AnimatedSprite2D, frames_path: String) -> void:
	var dir := frames_path.get_base_dir()
	for cand in [dir + "/sprites.json", dir.get_base_dir() + "/sprites.json"]:
		if FileAccess.file_exists(cand):
			var d = JSON.parse_string(FileAccess.get_file_as_string(cand))
			var ppm := 0.0
			if d is Dictionary:
				ppm = float(d.get("pixels_per_meter", d.get("ppm", 0.0)))
			if ppm > 0.0:
				var ratio := 24.0 / ppm
				if absf(ratio - 1.0) < 0.01 or absf(ratio - 2.0) < 0.01 or absf(ratio - 0.5) < 0.01:
					spr.scale = Vector2.ONE * ratio
			return
