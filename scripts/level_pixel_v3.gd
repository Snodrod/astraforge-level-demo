extends Node2D
## Пиксельная версия v3: тот же уровень, что в 3D (раскладка assets_px/layout_3d.json — те же места),
## вид сверху в три четверти (40°, как пиксельный профиль студии), 16 px на метр.
## Спрайты — пиксельные листы AstraForge (assets/<id>/pixel), приведённые к одной сетке пикселей
## (tools/pixel_resample.py). Животные — 8 направлений, клипы idle/walk/run; сортировка по Y.
## Мир рисуется в SubViewport и растягивается в целое число раз без сглаживания.
## План выбирается аргументом:  -- --shot=px_walk  (см. SHOTS)

const PPM := 16.0
const SY := 0.6428                  # sin(40°): глубина по земле сжимается
const X0 := -32.0
const Z0 := -30.0
const MAP := Vector2i(1024, 617)    # 64 x 60 м

const SHOTS := {
	"px_overview": {"view": Vector2i(960, 540), "dur": 16.0, "path": [Vector2(-1, -5), Vector2(4, -1), Vector2(7, 3)]},
	"px_walk": {"view": Vector2i(480, 270), "dur": 45.0,
		"path": [Vector2(-8, 22), Vector2(-6, 12), Vector2(-5, 4), Vector2(0, -3), Vector2(7, -5), Vector2(13, -5), Vector2(13, 4), Vector2(7, 10), Vector2(-2, 12), Vector2(-10, 6)]},
	"px_cu_deer": {"view": Vector2i(320, 180), "dur": 9.0, "follow": "deer"},
	"px_cu_fox": {"view": Vector2i(240, 135), "dur": 9.0, "follow": "fox"},
	"px_cu_hare": {"view": Vector2i(240, 135), "dur": 9.0, "follow": "hare", "spot": Vector2(-3.0, -5.0)},
	"px_cu_camp": {"view": Vector2i(320, 180), "dur": 9.0, "path": [Vector2(10.5, -6.5), Vector2(10.0, -5.0)]},
	"px_bridge_check": {"view": Vector2i(320, 180), "dur": 5.0, "path": [Vector2(6.6, 9.0), Vector2(6.6, 9.0)]},
	"cmp_px": {"view": Vector2i(960, 540), "dur": 10.0, "path": [Vector2(5, -3), Vector2(5, -3)]},
}

## Замер tools/stride_speed.gd (как в level_v3.gd), м/с при темпе 1 и масштабе 1.
const STRIDE := {"deer": [0.52, 1.24], "fox": [0.14, 0.33], "hare": [0.0, 0.30], "sparrow": [0.02, 0.02]}
const SCALE3D := {"deer": 1.0, "fox": 1.35, "hare": 1.25, "sparrow": 1.8}

const GRASS := ["5f9a3c", "79b046", "8fc253", "a6d265"]
const SAND := ["e0c98c", "d4bd85", "c9b27a"]
const WET := ["b49a62", "a88f58"]
const DIRT := ["b58f5d", "a47d4d", "c49c6a"]

var world: Node2D
var things: Node2D
var cam: Camera2D
var shot := {}
var focus := {}
var _t := 0.0
var _frames := {}
var _wind := {}
var _noise: Texture2D
var _cam_pos := Vector2.ZERO
var _path_pts: Array = []
var obstacles: Array = []           # Vector3(x, z, r) в метрах
var stills: Array = []


static func to_px(x: float, z: float) -> Vector2:
	return Vector2((x - X0) * PPM, (z - Z0) * PPM * SY)


func _ready() -> void:
	var name_ := "px_walk"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			name_ = a.substr(7)
		elif a.begins_with("--stills="):
			stills = Array(a.substr(9).split(","))
			name_ = str(stills[0]).split("@")[0]
	shot = SHOTS[name_]
	_noise = LevelV3.water_noise()
	_make_viewport(shot["view"])
	_bake_ground()
	things = Node2D.new()
	things.y_sort_enabled = true
	world.add_child(things)
	_place_layout()
	_overlay()
	if shot.has("spot") and focus.has(shot["follow"]):   # крупный план: животное на открытом месте поляны
		var fa = focus[shot["follow"]]
		fa.wx = shot["spot"].x
		fa.wz = shot["spot"].y
		fa.home = shot["spot"]
	_update_camera(0.0, true)


func _process(delta: float) -> void:
	_t += delta
	_update_camera(delta, false)
	if not stills.is_empty() and _t > 2.0:
		_take_stills()


func _take_stills() -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/v3/check"))
	img.save_png("res://shots/v3/check/%s.png" % str(stills[0]).split("@")[0])
	get_tree().quit()


# ---------- окно ----------

func _make_viewport(view: Vector2i) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var cont := SubViewportContainer.new()
	cont.stretch = false
	cont.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cont.scale = Vector2.ONE * floorf(1920.0 / view.x)
	layer.add_child(cont)
	var sv := SubViewport.new()
	sv.size = view
	sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cont.add_child(sv)
	world = Node2D.new()
	sv.add_child(world)
	var mod := CanvasModulate.new()
	mod.color = Color(1.0, 0.98, 0.93)
	world.add_child(mod)
	cam = Camera2D.new()
	world.add_child(cam)


func _update_camera(delta: float, snap: bool) -> void:
	var view: Vector2i = shot["view"]
	var c := Vector2.ZERO
	var u := clampf(_t / float(shot["dur"]), 0.0, 1.0)
	if shot.has("follow"):
		var n := focus.get(shot["follow"]) as Node2D
		if n:
			c = n.position + Vector2(0, -10)
			if snap or _cam_pos == Vector2.ZERO:
				_cam_pos = c
			_cam_pos = _cam_pos.lerp(c, clampf(delta * 1.2, 0.0, 1.0))
			c = _cam_pos
	else:
		var pts: Array = shot["path"]
		var e := u * u * (3.0 - 2.0 * u) * 0.4 + u * 0.6
		var w := _spline(pts, e)
		c = to_px(w.x, w.y)
	c.x = clampf(c.x, view.x * 0.5, MAP.x - view.x * 0.5)
	c.y = clampf(c.y, view.y * 0.5, MAP.y - view.y * 0.5)
	cam.position = c.round()                    # только целые пиксели — картинка не «плывёт»


func _spline(pts: Array, u: float) -> Vector2:
	var n := pts.size()
	if n == 1:
		return pts[0]
	var f := u * (n - 1)
	var i := clampi(int(floor(f)), 0, n - 2)
	var t := f - i
	var p0: Vector2 = pts[maxi(i - 1, 0)]
	var p1: Vector2 = pts[i]
	var p2: Vector2 = pts[i + 1]
	var p3: Vector2 = pts[mini(i + 2, n - 1)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


# ---------- земля ----------

func _noise_img(freq: float, octaves: int, seed_v: int) -> Image:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = freq
	fn.fractal_octaves = octaves
	fn.seed = seed_v
	return fn.get_image(MAP.x, MAP.y, false, false, true)


func _bake_ground() -> void:
	var na := _noise_img(0.012, 3, 1)
	var nb := _noise_img(0.06, 2, 2)
	var nc := _noise_img(0.16, 1, 3)
	var path := _stamp_path()
	var ground := PixelAssets.new_img(MAP.x, MAP.y)
	var mask := PixelAssets.new_img(MAP.x, MAP.y)
	var bayer := [0.0, 0.5, 0.75, 0.25]
	var light := Vector3(-0.47, 0.64, 0.60).normalized()
	for py in MAP.y:
		var z := Z0 + (py + 0.5) / (PPM * SY)
		for px in MAP.x:
			var x := X0 + (px + 0.5) / PPM
			var bay: float = bayer[(px & 1) + (py & 1) * 2] * 0.07
			var h := LevelTerrain.height(x, z)
			var wob: float = (nb.get_pixel(px, py).r - 0.5) * 0.5
			var d := LevelTerrain.river_dist(x, z) + wob
			var col: Color
			var cn: float = nc.get_pixel(px, py).r
			if h < LevelTerrain.WATER_Y + wob * 0.15:
				col = Color(SAND[2])
				var depth := LevelTerrain.WATER_Y - h
				mask.set_pixel(px, py, Color(1.0 if depth < 0.08 else 0.0, 1.0 if depth < 0.45 else 0.0, 0.0, 1.0))
			elif d < 4.1:
				if h < LevelTerrain.WATER_Y + 0.25:
					col = Color(WET[0] if cn + bay < 0.55 else WET[1])
				else:
					col = Color(SAND[0] if cn + bay > 0.62 else (SAND[1] if cn + bay > 0.3 else SAND[2]))
				if PixelAssets.h2(px, py) < 0.012:
					col = Color("9a958c")
			else:
				var a: float = na.get_pixel(px, py).r + (cn - 0.5) * 0.12 + bay
				var nrm := LevelTerrain.normal(x, z)
				a += (nrm.dot(light) - 0.78) * 1.6                       # склоны к солнцу светлее
				var gi := 0 if a < 0.30 else (1 if a < 0.52 else (2 if a < 0.72 else 3))
				col = Color(GRASS[gi])
				if d < 4.6 and PixelAssets.h2(px, py) < 0.55 - (d - 4.1) * 1.2:
					col = Color(SAND[1])
				if PixelAssets.h2(px * 2, py) < 0.012:
					col = col.darkened(0.22)                                # травинки
			var p: float = path.get_pixel(px, py).r
			if p > 0.9 and d > 3.8:
				col = Color(DIRT[0] if cn + bay < 0.5 else (DIRT[1] if cn + bay < 0.66 else DIRT[2]))
			elif p > 0.3 and d > 3.8 and PixelAssets.h2(px, py + 5) < 0.55:
				col = Color(DIRT[1]).darkened(0.1)
			ground.set_pixel(px, py, col)
	var gs := Sprite2D.new()
	gs.centered = false
	gs.texture = PixelAssets.tex(ground)
	gs.z_index = -20
	world.add_child(gs)
	var ws := Sprite2D.new()
	ws.centered = false
	ws.texture = PixelAssets.tex(mask)
	ws.z_index = -19
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water_2d.gdshader")
	wm.set_shader_parameter("noise_tex", _noise)
	ws.material = wm
	world.add_child(ws)


## Тропинка: от двери дома мимо костра к мосту и дальше на западную поляну.
func _stamp_path() -> Image:
	var bx := LevelTerrain.river_x(LevelV3.BRIDGE_Z)
	var pts := [Vector2(10.2, -7.0), Vector2(9.8, -2.0), Vector2(10.6, 4.0), Vector2(bx + 4.6, 9.0),
		Vector2(bx - 4.4, 9.2), Vector2(-3.0, 11.0), Vector2(-10.0, 14.0), Vector2(-18.0, 15.0)]
	for p in pts:
		_path_pts.append(to_px(p.x, p.y))
	var m := PixelAssets.new_img(MAP.x, MAP.y)
	m.fill(Color(0, 0, 0, 1))
	for pass_i in 2:
		var r := 4.0 if pass_i == 1 else 6.0
		var v := 1.0 if pass_i == 1 else 0.5
		for i in _path_pts.size() - 1:
			var a: Vector2 = _path_pts[i]
			var b: Vector2 = _path_pts[i + 1]
			var steps := int(a.distance_to(b) / 1.5)
			for s in steps:
				var p := a.lerp(b, float(s) / steps) + Vector2(0, sin(s * 0.21 + i) * 1.5)
				for dy in range(-7, 8):
					for dx in range(-7, 8):
						if dx * dx + dy * dy <= r * r:
							var x := int(p.x) + dx
							var y := int(p.y) + dy
							if x >= 0 and y >= 0 and x < MAP.x and y < MAP.y and m.get_pixel(x, y).r < v:
								m.set_pixel(x, y, Color(v, 0, 0, 1))
	return m


# ---------- спрайты студии ----------

func _px_meta(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets_px/%s/px.json" % id))


## SpriteFrames из приведённых листов: анимации «<клип>_<вид>» (idle_S, walk_NE ...).
func frames(id: String) -> SpriteFrames:
	if _frames.has(id):
		return _frames[id]
	var meta := _px_meta(id)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var cw := int(meta["cell"][0])
	var ch := int(meta["cell"][1])
	var views: Array = meta["views"]
	for clip in meta["clips"]:
		var c: Dictionary = meta["clips"][clip]
		var tex: Texture2D = load("res://assets_px/%s/%s.png" % [id, clip])
		for vi in views.size():
			var an := "%s_%s" % [clip, views[vi]]
			sf.add_animation(an)
			sf.set_animation_speed(an, float(c["fps"]))
			sf.set_animation_loop(an, bool(c["loop"]))
			for fi in int(c["frames"]):
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(fi * cw, vi * ch, cw, ch)
				sf.add_frame(an, at)
	sf.set_meta("anchor", Vector2(meta["anchor"][0], meta["anchor"][1]))
	sf.set_meta("cell", Vector2(cw, ch))
	sf.set_meta("meta", meta)
	_frames[id] = sf
	return sf


func sprite(id: String, x: float, z: float, wind := 0.0) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(id)
	s.centered = false
	var anchor: Vector2 = s.sprite_frames.get_meta("anchor")
	s.offset = -anchor.round()
	s.position = to_px(x, z).round()
	var first: String = s.sprite_frames.get_animation_names()[0]
	s.play(first)
	if wind > 0.0:
		var h := int((s.sprite_frames.get_meta("cell") as Vector2).y)
		var key := "%d_%.1f" % [h, wind]
		if not _wind.has(key):
			var m := ShaderMaterial.new()
			m.shader = load("res://shaders/wind_2d.gdshader")
			m.set_shader_parameter("sprite_height", float(h))
			m.set_shader_parameter("amplitude", wind)
			_wind[key] = m
		s.material = _wind[key]
	things.add_child(s)
	return s


func _shadow(parent: Node2D, rx: int, ry: int, off: Vector2) -> void:
	var sh := Sprite2D.new()
	sh.texture = PixelAssets.shadow_tex(rx, ry)
	sh.position = off
	sh.show_behind_parent = true
	parent.add_child(sh)


func _place_layout() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets_px/layout_3d.json"))
	var lim := Rect2(X0 - 3.0, Z0 - 2.0, 70.0, 66.0)
	for e in data:
		var id: String = e[0]
		var x := float(e[1])
		var z := float(e[2])
		var s := float(e[4])
		if not lim.has_point(Vector2(x, z)):
			continue
		if id.begins_with("animal_"):
			_animal(id.substr(7), x, z)
			continue
		# мост: лист студии нарисован по диагонали (вид SE) — берём рендер того же пакета поперёк русла
		if id == "bridge" and FileAccess.file_exists("res://assets_px/bridge_flat/px.json"):
			id = "bridge_flat"
		if id == "grass_1" or id == "grass_2":   # пиксельные листы кустов травы v2 тёмные, как камешки — на карте их не ставим
			continue
		if not FileAccess.file_exists("res://assets_px/%s/px.json" % id):
			continue
		var wind := 0.0
		if id.begins_with("tree"):
			wind = 1.5
		elif id in ["bush_1", "fern", "grass_1", "grass_2", "flower_1", "flower_2"]:
			wind = 1.0
		var sp := sprite(id, x, z, wind)
		if id.begins_with("tree"):
			_shadow(sp, int(15 * s), int(5 * s), Vector2(6, 1))
			obstacles.append(Vector3(x, z, 0.45 * s))
		elif id in ["rock_5", "rock_6", "rock_3"]:
			_shadow(sp, 9, 3, Vector2(2, 1))
			obstacles.append(Vector3(x, z, 0.6 * s))
		elif id == "house":
			_shadow(sp, 42, 12, Vector2(10, 2))
			obstacles.append(Vector3(x, z, 4.0))
			focus["house"] = sp
		elif id in ["barrel", "crate", "chest", "log", "campfire", "bush_1"]:
			_shadow(sp, 7, 3, Vector2(1, 1))
			obstacles.append(Vector3(x, z, 0.6))
		if id == "campfire":
			focus["campfire"] = sp
		if id == "bridge_flat":
			focus["bridge"] = sp
	# вороны кружат над поляной
	for i in 2:
		var b := PixelBird.new()
		b.lvl = self
		b.center = Vector2(2.0 + 3.0 * i, 1.0 - 2.0 * i)
		b.radius = Vector2(16.0 - 3.0 * i, 11.0 + 2.0 * i)
		b.altitude = 11.0 + 3.5 * i
		b.speed = 0.24 - 0.03 * i
		b.phase = PI * i
		var s := AnimatedSprite2D.new()
		s.sprite_frames = frames("crow")
		s.centered = false
		s.offset = -(s.sprite_frames.get_meta("anchor") as Vector2).round()
		b.add_child(s)
		b.z_index = 60
		world.add_child(b)


func _animal(kind: String, x: float, z: float) -> void:
	if not FileAccess.file_exists("res://assets_px/%s/px.json" % kind):
		return
	var a := PixelAnimal.new()
	a.lvl = self
	a.kind = kind
	a.wx = x
	a.wz = z
	a.home = Vector2(x, z)
	var meta := _px_meta(kind)
	var clips: Dictionary = meta["clips"]
	var rate: Array = {"deer": [1.3, 1.25], "fox": [2.2, 2.0], "hare": [1.0, 1.6], "sparrow": [2.0, 2.0]}[kind]
	for i in 2:
		var cname := "walk" if i == 0 else "run"
		if i == 0 and not clips.has("walk") and clips.has("hop"):   # у зайца v3 спокойный шаг — клип hop
			cname = "hop"
			a.clip_alias["walk"] = "hop"
		if clips.has(cname):
			var c: Dictionary = clips[cname]
			var cycle := float(c["frames"]) / float(c["fps"])
			# темп листа: исходный клип играет с тем же темпом, что в 3D;
			# скорость тела — скорость лапы в пикселях листа (лист крупнее карты в ppm листа / 16 раз)
			a.rates["walk" if cname == "hop" else cname] = rate[i] * cycle / maxf(float(c["source_duration_s"]), 0.01)
			a.speeds["walk" if cname == "hop" else cname] = float(LevelV3.stride(kind)[i]) * rate[i] * float(meta["ppm"]) / PPM
	a.radius = float({"deer": 7.0, "fox": 6.0, "hare": 4.0, "sparrow": 1.2}[kind])
	a.run_chance = float({"deer": 0.12, "fox": 0.25, "hare": 0.3, "sparrow": 0.0}[kind])
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(kind)
	s.centered = false
	s.offset = -(s.sprite_frames.get_meta("anchor") as Vector2).round()
	a.add_child(s)
	var cell: Vector2 = s.sprite_frames.get_meta("cell")
	_shadow(a, maxi(3, int(cell.x * 0.22)), maxi(1, int(cell.x * 0.07)), Vector2(1, 0))
	things.add_child(a)
	# для крупного плана — животное на самом открытом месте (кроны в 2D закрывают тех, кто за деревом)
	var clear := 99.0
	for o in obstacles:
		var dd := Vector2(o.x, o.y).distance_to(Vector2(x, z))
		clear = minf(clear, dd * (0.4 if o.y > z else 1.0))   # дерево южнее (ниже на экране) закрывает кроной
	if not focus.has(kind) or clear > float(focus[kind].get_meta("clear", 0.0)):
		a.set_meta("clear", clear)
		focus[kind] = a


# ---------- свет и частицы ----------

func _overlay() -> void:
	var white := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	var d := Sprite2D.new()
	d.centered = false
	d.texture = PixelAssets.tex(white)
	d.scale = Vector2(MAP) / 4.0
	d.z_index = 80
	var dm := ShaderMaterial.new()
	dm.shader = load("res://shaders/dapple.gdshader")
	dm.set_shader_parameter("noise_tex", _noise)
	dm.set_shader_parameter("strength", 0.10)
	d.material = dm
	world.add_child(d)
	world.add_child(_particles("Leaves", 60, 9.0, [Color("e0913a"), Color("c9b24a"), Color("7fb34a"), Color("a0502a")], 1.0, Vector2(22, 8), Vector2(4, 12), 3.0, true))
	world.add_child(_particles("Pollen", 80, 7.0, [Color("fff3b0"), Color("ffffff")], 1.0, Vector2(6, -3), Vector2(2, -1), 4.0, true))
	if focus.has("house"):
		var hs := focus["house"] as Node2D
		var smoke := _particles("Smoke", 22, 3.5, [Color(0.86, 0.86, 0.88, 0.75), Color(0.72, 0.72, 0.76, 0.5)], 3.0, Vector2(6, -20), Vector2(3, -5), 1.0, false)
		smoke.position = hs.position + Vector2(-17, -68)
		smoke.z_index = 61
		world.add_child(smoke)
	if focus.has("campfire"):
		var cf := focus["campfire"] as Node2D
		var fire := _particles("Fire", 26, 0.7, [Color("fff4a0"), Color("ffb23a"), Color("e8571c"), Color(0.6, 0.15, 0.05, 0.0)], 1.0, Vector2(0, -16), Vector2(0, -10), 5.0, false)
		fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		fire.emission_rect_extents = Vector2(3, 1)
		fire.spread = 15.0
		fire.position = cf.position + Vector2(0, -6)
		fire.z_index = 62
		world.add_child(fire)
		var embers := _particles("Embers", 8, 1.6, [Color("ffd27a"), Color("ff7a2a")], 1.0, Vector2(2, -22), Vector2(0, -2), 6.0, false)
		embers.position = cf.position + Vector2(0, -8)
		embers.z_index = 62
		world.add_child(embers)


func _particles(node_name: String, amount: int, life: float, colors: Array, size: float, vel: Vector2, grav: Vector2, spread_v: float, whole_map: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = node_name
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	if whole_map:
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(MAP) * 0.5
		p.position = Vector2(MAP) * 0.5
	p.direction = vel.normalized()
	p.spread = 25.0
	p.initial_velocity_min = vel.length() * 0.6
	p.initial_velocity_max = vel.length() * 1.2 + spread_v
	p.gravity = grav
	p.scale_amount_min = size
	p.scale_amount_max = size * 1.5
	var gr := Gradient.new()
	var offs := PackedFloat32Array()
	for i in colors.size():
		offs.append(float(i) / maxf(colors.size() - 1, 1))
	gr.offsets = offs
	gr.colors = PackedColorArray(colors)
	p.color_ramp = gr
	p.z_index = 70
	return p


## Можно ли стоять: не вода, не круто, не в стволе/доме, в пределах поляны.
func walkable(x: float, z: float) -> bool:
	if not LevelTerrain.in_bounds(x, z, 3.0) or LevelTerrain.is_water(x, z, 0.2):
		return false
	if LevelTerrain.normal(x, z).y < 0.82:
		return false
	for o in obstacles:
		if Vector2(x - o.x, z - o.y).length() < o.z + 0.4:
			return false
	return true
