extends Node2D
## Тот же уровень в пиксель-арте, в духе «ферм»: вид сверху в три четверти.
## Мир рисуется в SubViewport 640x360 и растягивается ровно в 3 раза без сглаживания (крупный пиксель).
## Земля запекается в одну картинку: трава в 4 тонах с растушёвкой, песок, мокрый берег, тропинка.
## Вода — спрайт по маске с шейдером (течение, блики, пена). Деревья, дом, камни — спрайты с тенью
## и сортировкой по Y: кто ниже на экране, тот перекрывает стоящего выше.
## Листья и пыльца — частицы, мягкие пятна света — шейдер dapple.
## Нет листов студии — рисуются заглушки из pixel_assets.gd; Populate.apply_2d меняет их по manifest.

const VIEW := Vector2i(640, 360)
const T := PixelMap.TILE

@export var scare_with_mouse := false     # животные убегают от курсора (для игры, не для съёмки)
@export var use_assets := true
@export var pan_camera := true            # камера плавно ездит по уровню (целые пиксели)

var world: Node2D
var things: Node2D                        # Y-сортировка
var cam: Camera2D
var _rng := RandomNumberGenerator.new()
var _wind_mats := {}
var _animal_n := 0
var _scare: Node2D
var _noise_tex: Texture2D
var _t := 0.0
var _path_pts: Array[Vector2] = []

const GRASS := ["5f9a3c", "7fb34a", "93c456", "a9d466"]       # четыре тона травы (палитра проекта: #7fb34a)
const SAND := ["e0c98c", "d4bd85", "c9b27a"]
const WET := ["b49a62", "a88f58"]
const DIRT := ["b58f5d", "a47d4d", "c49c6a"]


func _ready() -> void:
	_rng.seed = 7
	_make_viewport()
	_noise_tex = LevelBuilder.noise_texture()
	_bake_ground()
	things = Node2D.new()
	things.name = "Things"
	things.y_sort_enabled = true
	world.add_child(things)
	_build_things()
	var report := {}
	if use_assets:
		report = Populate.apply_2d(things)
	_refresh_wind()
	_build_overlay()
	if scare_with_mouse:
		_scare = Node2D.new()
		world.add_child(_scare)
		for a in get_tree().get_nodes_in_group("wander2d"):
			a.threat = _scare
	if not report.is_empty() and report.get("filled", 0) > 0:
		print("level_pixel: подставлено листов студии: ", report["filled"])
	_move_camera()


func _process(delta: float) -> void:
	_t += delta
	if _scare:
		_scare.position = world.get_local_mouse_position()
	_move_camera()


## Камера двигается только целыми пикселями, поэтому пиксель-арт не «плывёт».
func _move_camera() -> void:
	if cam == null:
		return
	var c := Vector2(560, 236)
	if pan_camera:
		c += Vector2(210.0 * sin(_t * 0.12), 100.0 * sin(_t * 0.083 + 1.0))
	cam.position = Vector2(round(clampf(c.x, VIEW.x * 0.5, PixelMap.SIZE.x - VIEW.x * 0.5)), round(clampf(c.y, VIEW.y * 0.5, PixelMap.SIZE.y - VIEW.y * 0.5)))


func _make_viewport() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var cont := SubViewportContainer.new()
	cont.stretch = false
	cont.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var win := get_viewport_rect().size
	cont.scale = Vector2.ONE * floorf(win.x / VIEW.x)                 # целое увеличение
	layer.add_child(cont)
	var sv := SubViewport.new()
	sv.size = VIEW
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cont.add_child(sv)
	world = Node2D.new()
	world.name = "World"
	sv.add_child(world)
	var mod := CanvasModulate.new()                                   # тёплый свет дня
	mod.color = Color(1.0, 0.975, 0.91)
	world.add_child(mod)
	cam = Camera2D.new()
	world.add_child(cam)


# ---------- земля: запекаем одной картинкой ----------

func _noise_img(freq: float, octaves: int, seed_v: int) -> Image:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = freq
	fn.fractal_octaves = octaves
	fn.seed = seed_v
	return fn.get_image(int(PixelMap.SIZE.x), int(PixelMap.SIZE.y), false, false, true)


func _bake_ground() -> void:
	var w := int(PixelMap.SIZE.x)
	var h := int(PixelMap.SIZE.y)
	var na := _noise_img(0.018, 3, 1)       # крупные пятна травы
	var nb := _noise_img(0.06, 2, 2)        # неровность берега
	var nc := _noise_img(0.16, 1, 3)        # мелкое зерно
	var gcols: Array = []
	for c in GRASS:
		gcols.append(Color(c))
	var path := _stamp_path(w, h)
	var ground := PixelAssets.new_img(w, h)
	var mask := PixelAssets.new_img(w, h)
	var bayer := [0.0, 0.5, 0.75, 0.25]
	var wh := PixelMap.WATER_HALF
	var sh := PixelMap.SAND_HALF
	var flower_cols := [Color("f4f0e0"), Color("f2d24a"), Color("e8789a"), Color("a98ad8")]
	for y in h:
		var rc := PixelMap.river_col((y + 0.5) / T)
		for x in w:
			var bay: float = bayer[(x & 1) + (y & 1) * 2] * 0.07
			var wob: float = nb.get_pixel(x, y).r
			var dw: float = absf((x + 0.5) / T - rc) + (wob - 0.5) * 0.6
			var col: Color
			if dw < wh:                                                   # вода: дно песчаное, сверху спрайт воды
				col = Color(SAND[2])
				var m := Color(0, 0, 0, 1)
				m.r = 1.0 if dw > wh - 0.2 else 0.0                         # пена
				m.g = 1.0 if dw > wh - 0.65 else 0.0                        # мелководье
				mask.set_pixel(x, y, m)
			elif dw < sh - 0.12:                                          # берег: мокрый песок -> сухой
				var cn: float = nc.get_pixel(x, y).r
				if dw < wh + 0.32:
					col = Color(WET[0] if cn + bay < 0.55 else WET[1])
				else:
					col = Color(SAND[0] if cn + bay > 0.62 else (SAND[1] if cn + bay > 0.3 else SAND[2]))
				if PixelAssets.h2(x, y) < 0.012:
					col = Color("9a958c")                                   # галька
			else:
				var a: float = na.get_pixel(x, y).r
				a += clampf(1.0 - Vector2(x - 150, y - 150).length() / 170.0, 0.0, 1.0) * 0.18   # холм слева светлее
				a += (nc.get_pixel(x, y).r - 0.5) * 0.12 + bay
				var gi := 0 if a < 0.30 else (1 if a < 0.52 else (2 if a < 0.72 else 3))
				col = gcols[gi]
				if dw < sh + 0.3 and PixelAssets.h2(x, y) < 0.55 - (dw - sh) * 1.2:   # растушёвка трава/песок
					col = Color(SAND[1])
				var hh := PixelAssets.h2(x * 2, y)
				if hh < 0.011:                                              # травинки
					col = col.darkened(0.22)
				elif hh > 0.9994 and dw > sh + 0.8:                         # цветочки
					col = flower_cols[int(PixelAssets.h2(x, y + 9) * 4.0)]
			var p: float = path.get_pixel(x, y).r
			if p > 0.9 and dw > sh - 0.35:
				var dn: float = nc.get_pixel(x, y).r
				col = Color(DIRT[0] if dn + bay < 0.5 else (DIRT[1] if dn + bay < 0.66 else DIRT[2]))
			elif p > 0.3 and dw > sh - 0.35 and PixelAssets.h2(x, y + 5) < 0.55:
				col = Color(DIRT[1]).darkened(0.1)                          # кромка тропинки
			ground.set_pixel(x, y, col)
	var gs := Sprite2D.new()
	gs.name = "Ground"
	gs.centered = false
	gs.texture = PixelAssets.tex(ground)
	gs.z_index = -20
	world.add_child(gs)
	var ws := Sprite2D.new()
	ws.name = "Water"
	ws.centered = false
	ws.texture = PixelAssets.tex(mask)
	ws.z_index = -19
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water_2d.gdshader")
	wm.set_shader_parameter("noise_tex", _noise_tex)
	ws.material = wm
	world.add_child(ws)


## Тропинка: от двери дома к мосту и дальше в лес. Штампуем круги вдоль ломаной в маску.
func _stamp_path(w: int, h: int) -> Image:
	var bridge := Vector2(PixelMap.river_col(15.5) * T, 15.5 * T)
	_path_pts = [Vector2(744, 238), Vector2(738, 290), Vector2(690, 332), Vector2(bridge.x + 112, bridge.y + 4),
		Vector2(bridge.x - 112, bridge.y + 4), Vector2(bridge.x - 190, bridge.y - 30), Vector2(130, 290), Vector2(60, 250)]
	var m := PixelAssets.new_img(w, h)
	m.fill(Color(0, 0, 0, 1))
	for pass_i in 2:
		var r := 4.5 if pass_i == 1 else 6.5
		var v := 1.0 if pass_i == 1 else 0.5
		for i in _path_pts.size() - 1:
			var a := _path_pts[i]
			var b := _path_pts[i + 1]
			var steps := int(a.distance_to(b) / 1.5)
			for s in steps:
				var p := a.lerp(b, float(s) / steps) + Vector2(0, sin(s * 0.21 + i) * 2.0)
				for dy in range(-7, 8):
					for dx in range(-7, 8):
						if dx * dx + dy * dy <= r * r:
							var x := int(p.x) + dx
							var y := int(p.y) + dy
							if x >= 0 and y >= 0 and x < w and y < h and m.get_pixel(x, y).r < v:
								m.set_pixel(x, y, Color(v, 0, 0, 1))
	return m


# ---------- предметы ----------

func _build_things() -> void:
	var house_box := Rect2(660, 90, 170, 185)
	var fire := Vector2(630, 276)
	var bridge_pos := Vector2(PixelMap.river_col(15.5) * T, 15.5 * T)
	var bridge_box := Rect2(bridge_pos.x - 120, bridge_pos.y - 40, 240, 80)
	var placed: Array[Vector2] = []

	# трава и цветы
	var g := 0
	while g < 240:
		var p := Vector2(_rng.randf_range(10, PixelMap.SIZE.x - 10), _rng.randf_range(16, PixelMap.SIZE.y - 4))
		if absf(p.x / T - PixelMap.river_col(p.y / T)) < PixelMap.SAND_HALF + 0.5 or house_box.has_point(p) or p.distance_to(fire) < 30 or _near_path(p, 14.0):
			continue
		_sprite("grass", _rng.randi() % 3, p, "Grass_%03d" % g, 1.0)
		g += 1
	g = 0
	while g < 70:
		var p := Vector2(_rng.randf_range(10, PixelMap.SIZE.x - 10), _rng.randf_range(16, PixelMap.SIZE.y - 4))
		if absf(p.x / T - PixelMap.river_col(p.y / T)) < PixelMap.SAND_HALF + 0.8 or house_box.has_point(p) or _near_path(p, 12.0):
			continue
		_sprite("flower", g / 6, p, "Flower_%03d" % g, 0.8)
		g += 1

	# деревья: 24 штуки, дуб / ель / берёза / сухое
	var species := [0, 0, 1, 2, 0, 1, 3, 2, 0, 1, 0, 2, 1, 3, 0, 1, 2, 0, 1, 3, 0, 2, 1, 0]
	var clusters := [Vector2(110, 150), Vector2(90, 430), Vector2(870, 70), Vector2(880, 480), Vector2(300, 70), Vector2(420, 500)]
	var i := 0
	var tries := 0
	while i < species.size() and tries < 4000:
		tries += 1
		var cl: Vector2 = clusters[_rng.randi() % clusters.size()]
		var p := cl + Vector2(_rng.randf_range(-110, 110), _rng.randf_range(-90, 90))
		if not _free(p, 3.4, house_box, fire, bridge_box) or not _spaced(placed, p, 52.0) or _near_path(p, 22.0):
			continue
		placed.append(p)
		_sprite("tree", species[i], p, "Tree_%02d" % i, 2.4)
		i += 1
	var k := 0
	tries = 0
	while k < 8 and tries < 600:                                # кусты
		tries += 1
		var p := Vector2(_rng.randf_range(30, 930), _rng.randf_range(40, 520))
		if not _free(p, 3.0, house_box, fire, bridge_box) or _near_path(p, 18.0):
			continue
		_sprite("bush", k, p, "Bush_%02d" % k, 1.2)
		k += 1

	# камни по берегам и на холме
	for r in 10:
		var y := _rng.randf_range(30, 520)
		var side := 1.0 if r % 2 == 0 else -1.0
		var p := Vector2((PixelMap.river_col(y / T) + side * _rng.randf_range(PixelMap.WATER_HALF + 0.6, PixelMap.WATER_HALF + 1.5)) * T, y)
		if r >= 8:
			p = Vector2(_rng.randf_range(60, 200), _rng.randf_range(80, 220))
		if bridge_box.has_point(p) or house_box.has_point(p):
			p.y += 100.0
		_sprite("rock", r, p, "Rock_%02d" % r, 0.0)

	# реквизит
	_sprite("house", 0, Vector2(744, 232), "House", 0.0)
	_sprite("bridge", 0, bridge_pos, "Bridge", 0.0, true)
	_sprite("campfire", 0, fire, "Campfire", 0.0)
	var barrels := [Vector2(682, 240), Vector2(698, 252), Vector2(812, 246)]
	for b in 3:
		_sprite("barrel", 0, barrels[b], "Barrel_%d" % b, 0.0)
	var crates := [Vector2(826, 252), Vector2(678, 226), Vector2(828, 234), Vector2(666, 258)]
	for c in 4:
		_sprite("crate", 0, crates[c], "Crate_%d" % c, 0.0)
	var torches := [fire + Vector2(-26, 8), fire + Vector2(28, -4), bridge_pos + Vector2(-100, 16), bridge_pos + Vector2(100, 16)]
	for t in 4:
		_sprite("torch", 0, torches[t], "Torch_%d" % t, 0.0)
	# забор у домика: передняя линия с проходом для тропинки и боковины
	var fx := 672
	var n_f := 0
	while fx < 828:
		if fx < 720 or fx >= 768:
			_sprite("fence_h", 0, Vector2(fx + 12, 268), "Fence_%d" % n_f, 0.0)
			n_f += 1
		fx += 24
	for side_x in [664.0, 836.0]:
		for fy in [248.0, 228.0]:
			_sprite("fence_v", 0, Vector2(side_x, fy + 20.0), "FenceSide_%d" % n_f, 0.0)
			n_f += 1

	# животные
	for a in 3:
		_animal("hare", Vector2([200.0, 560.0, 330.0][a], [380.0, 120.0, 90.0][a]), 18.0, 1.2, 0.0, 130.0)
	for a in 2:
		var y: float = [120.0, 420.0][a]
		_animal("deer", Vector2((PixelMap.river_col(y / T) - 4.2) * T, y), 18.0, 1.4, 0.6, 170.0)
	_animal("fox", Vector2(840, 400), 20.0, 1.2, 0.0, 150.0)
	for a in 2:
		var b := BirdOrbit2D.new()
		b.name = "Bird_%d" % a
		b.phase = PI * a
		b.speed = 0.38 + 0.06 * a
		b.length = 170.0 + 20.0 * a
		b.z_index = 50
		var s := _animal_sprite("bird")
		s.position.y = -34.0                                   # высота полёта
		b.add_child(s)
		things.add_child(b)


func _near_path(p: Vector2, d: float) -> bool:
	for i in _path_pts.size() - 1:
		var a := _path_pts[i]
		var b := _path_pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if (a + ab * t).distance_to(p) < d:
			return true
	return false


func _sprite(kind: String, variant: int, pos: Vector2, node_name: String, wind_amp: float, centered := false) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.name = node_name
	s.sprite_frames = PixelAssets.static_frames(kind, variant)
	s.position = pos
	s.set_meta("slot_kind", kind)
	s.set_meta("slot_variant", variant)
	s.offset = Vector2.ZERO if centered else PixelAssets.foot_offset(s.sprite_frames, "idle_S", false)
	if wind_amp > 0.0:
		s.set_meta("wind", wind_amp)
	things.add_child(s)
	s.play("idle_S")
	var spec := PixelAssets.shadow_spec(kind)                  # тень под объектом (за спрайтом)
	if kind == "bridge":
		spec = [96, 12, Vector2(0, 20)]
	if not spec.is_empty():
		var sh := Sprite2D.new()
		sh.name = "Shadow"
		sh.texture = PixelAssets.shadow_tex(spec[0], spec[1])
		sh.position = spec[2]
		sh.show_behind_parent = true
		s.add_child(sh)
	return s


func _animal_sprite(kind: String) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.name = "Sprite"
	s.sprite_frames = PixelAssets.animal_frames(kind)
	s.offset = PixelAssets.foot_offset(s.sprite_frames, "idle_S", true)
	s.set_meta("slot_kind", kind)
	s.set_meta("slot_variant", 0)
	s.play("idle_S")
	return s


func _animal(kind: String, pos: Vector2, walk: float, run_chance: float, shore: float, radius: float) -> void:
	_animal_n += 1
	var a := Wander2D.new()
	a.name = "%s_%d" % [kind.capitalize(), _animal_n]
	while PixelMap.is_water_px(pos, 0.8):
		pos.x += T
	a.position = pos
	a.walk_speed = walk
	a.run_speed = walk * 4.5 + 20.0
	a.run_chance = run_chance * 0.25
	a.shore_chance = shore
	a.wander_radius = radius
	a.tempo = _rng.randf_range(0.85, 1.2)
	a.add_to_group("wander2d")
	a.add_child(_animal_sprite(kind))
	things.add_child(a)


func _free(p: Vector2, river_margin: float, house_box: Rect2, fire: Vector2, bridge_box: Rect2) -> bool:
	if not PixelMap.in_map(p, 20.0):
		return false
	if absf(p.x / T - PixelMap.river_col(p.y / T)) < river_margin + PixelMap.WATER_HALF:
		return false
	return not house_box.has_point(p) and p.distance_to(fire) > 50.0 and not bridge_box.has_point(p)


func _spaced(placed: Array[Vector2], p: Vector2, d: float) -> bool:
	for q in placed:
		if q.distance_to(p) < d:
			return false
	return true


# ---------- ветер ----------

## Общий материал на каждую высоту спрайта (шейдеру нужна высота в пикселях).
func _refresh_wind() -> void:
	for n in things.find_children("*", "AnimatedSprite2D", true, false):
		if not n.has_meta("wind"):
			continue
		var s := n as AnimatedSprite2D
		var h := 64
		if s.sprite_frames and s.sprite_frames.has_animation(s.animation):
			h = s.sprite_frames.get_frame_texture(s.animation, 0).get_height()
		var key := "%d_%s" % [h, s.get_meta("wind")]
		if not _wind_mats.has(key):
			var m := ShaderMaterial.new()
			m.shader = load("res://shaders/wind_2d.gdshader")
			m.set_shader_parameter("sprite_height", float(h))
			m.set_shader_parameter("amplitude", float(s.get_meta("wind")))
			_wind_mats[key] = m
		s.material = _wind_mats[key]


# ---------- свет и частицы ----------

func _build_overlay() -> void:
	var white := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	var d := Sprite2D.new()                                        # пятна света и облачных теней
	d.name = "Dapple"
	d.centered = false
	d.texture = PixelAssets.tex(white)
	d.scale = PixelMap.SIZE / 4.0
	d.z_index = 80
	var dm := ShaderMaterial.new()
	dm.shader = load("res://shaders/dapple.gdshader")
	dm.set_shader_parameter("noise_tex", _noise_tex)
	d.material = dm
	world.add_child(d)
	world.add_child(_particles("Leaves", 46, 9.0, [Color("e0913a"), Color("c9b24a"), Color("7fb34a"), Color("a0502a")], 2.0, Vector2(26, 8), Vector2(5, 14), 3.0, true))
	world.add_child(_particles("Pollen", 70, 7.0, [Color("fff3b0"), Color("ffffff")], 1.0, Vector2(6, -3), Vector2(2, -1), 4.0, true))
	var smoke := _particles("ChimneySmoke", 16, 3.5, [Color(0.86, 0.86, 0.88, 0.7), Color(0.75, 0.75, 0.8, 0.6)], 3.0, Vector2(8, -22), Vector2(3, -6), 1.0, false)
	smoke.position = Vector2(744 + 32, 232 - 108)
	smoke.z_index = 60
	world.add_child(smoke)


## Пиксельные частицы: квадратики 1-3 px, разные цвета, ветер вправо-вниз.
func _particles(node_name: String, amount: int, life: float, colors: Array, size: float, vel: Vector2, grav: Vector2, spread_v: float, whole_map: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = node_name
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	if whole_map:
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = PixelMap.SIZE * 0.5
		p.position = PixelMap.SIZE * 0.5
	p.direction = vel.normalized()
	p.spread = 25.0
	p.initial_velocity_min = vel.length() * 0.6
	p.initial_velocity_max = vel.length() * 1.2 + spread_v
	p.gravity = grav
	p.scale_amount_min = size
	p.scale_amount_max = size * 1.4
	p.angle_max = 90.0
	var gr := Gradient.new()
	var offs := PackedFloat32Array()
	for i in colors.size():
		offs.append(float(i) / maxf(colors.size() - 1, 1))
	gr.offsets = offs
	gr.colors = PackedColorArray(colors)
	p.color_initial_ramp = gr
	p.z_index = 70
	return p
