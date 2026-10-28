extends Camera3D
## Камеры для съёмки v3. План выбирается аргументом:  -- --shot=fly_a   (список — SHOTS)
## Время — по кадрам (--fixed-fps 30), поэтому запись ровная и повторяемая.
## -- --stills=a,b,c   снять по кадру с каждого плана в shots/v3/check/ (для проверки глазами).
## Типы:
##   path   — гладкий сплайн позиций и точек взгляда, от начала к концу за dur секунд;
##   orbit  — облёт вокруг точки фокуса (focus из LevelV3), радиус/высота/скорость;
##   follow — камера сопровождает животное сбоку-спереди, с плавным запаздыванием.

const SHOTS := {
	# пролёты по готовому уровню
	"fly_a": {"type": "path", "dur": 75.0,
		"pos": [Vector3(4, 18, 52), Vector3(2, 10, 30), Vector3(-4, 6, 17), Vector3(0, 4.5, 4), Vector3(5, 5, -4), Vector3(8, 8, -17), Vector3(2, 12, -27), Vector3(-6, 20, -40)],
		"look": [Vector3(4, 2, 20), Vector3(3, 1, 10), Vector3(-4, 1, 4), Vector3(8, 1, 0), Vector3(13, 2, -7), Vector3(13, 2, -6), Vector3(6, 1, -4), Vector3(4, 0, 0)]},
	"fly_b_river": {"type": "river", "dur": 60.0, "z0": -44.0, "z1": 34.0, "y": 4.2, "off": 0.0, "look_y": 0.0},
	"fly_b_old": {"type": "path", "dur": 70.0,
		"pos": [Vector3(4, 6, -46), Vector3(1, 3.2, -32), Vector3(-1, 2.6, -20), Vector3(1, 2.6, -8), Vector3(4, 2.8, 2), Vector3(4.5, 3.4, 13), Vector3(7, 4.5, 24), Vector3(12, 8, 36)],
		"look": [Vector3(1, 0, -28), Vector3(-1, 0, -14), Vector3(1, 0.3, -2), Vector3(4, 0.5, 8), Vector3(7, 1, 12), Vector3(8, 1, 24), Vector3(10, 1, 34), Vector3(12, 2, 50)]},
	"fly_c_high": {"type": "orbit", "dur": 70.0, "center": Vector3(3, 0, 0), "radius": 40.0, "height": 40.0, "speed": 0.075, "start": 0.4, "look_y": 0.0},
	"fly_d_low": {"type": "path", "dur": 65.0,
		"pos": [Vector3(-3, 2.2, 22), Vector3(-4, 1.8, 17), Vector3(-2.5, 1.6, 10), Vector3(-1, 1.8, 2), Vector3(5, 2.8, 4), Vector3(8, 2.6, 2), Vector3(9.5, 2.0, -0.5)],
		"look": [Vector3(-5, 1, 14), Vector3(-6, 1.2, 6), Vector3(-7, 2, 5), Vector3(6, 1, 8), Vector3(13, 2, -6), Vector3(14, 2, -6), Vector3(8.3, 0.6, -4.2)]},
	# крупные планы
	"cu_tree_wind": {"type": "orbit", "focus": "hero_tree", "dur": 9.0, "radius": 10.0, "height": 2.0, "speed": 0.05, "start": 0.2, "look_y": 4.0, "fov": 50.0},
	"cu_water": {"type": "river", "dur": 9.0, "z0": -16.0, "z1": -9.0, "y": 1.1, "off": -1.2, "look_y": -0.5, "fov": 50.0},
	"cu_water_old": {"type": "path", "dur": 9.0, "fov": 50.0,
		"pos": [Vector3(-6, 1.6, -11), Vector3(-5, 1.3, -6), Vector3(-4.5, 1.2, -1)],
		"look": [Vector3(0, -0.4, -7), Vector3(1, -0.4, -2), Vector3(2, -0.4, 3)]},
	"cu_campfire": {"type": "orbit", "focus": "campfire", "dur": 9.0, "radius": 3.6, "height": 1.3, "speed": 0.09, "start": 3.6, "look_y": 0.35, "fov": 45.0},
	"cu_house_smoke": {"type": "orbit", "focus": "house", "dur": 9.0, "radius": 12.5, "height": 3.0, "speed": 0.05, "start": -1.45, "look_y": 3.6, "fov": 50.0},
	"cu_deer": {"type": "follow", "focus": "deer", "dur": 10.0, "dist": 4.6, "side": 1.0, "height": 1.3, "look_y": 1.0, "fov": 45.0},
	"cu_fox": {"type": "follow", "focus": "fox", "dur": 9.0, "dist": 3.4, "side": -1.0, "height": 0.8, "look_y": 0.35, "fov": 42.0},
	"cu_hare": {"type": "follow", "focus": "hare", "dur": 9.0, "dist": 2.6, "side": 1.0, "height": 1.35, "look_y": 0.3, "fov": 40.0},
	"cu_birds": {"type": "follow_air", "focus": "crow_0", "dur": 9.0, "dist": 4.5, "height": -1.2, "fov": 50.0},
	"cu_sparrow": {"type": "follow", "focus": "sparrow", "dur": 8.0, "dist": 1.5, "side": 1.0, "height": 0.95, "look_y": 0.1, "fov": 38.0},
	"cu_bridge": {"type": "orbit", "focus": "bridge", "dur": 9.0, "radius": 9.0, "height": 2.5, "speed": 0.05, "start": -0.8, "look_y": 0.8, "fov": 50.0},
	# сравнение 3D и пикселя: тот же кусок карты сверху в три четверти (40°), как пиксельная версия
	"bridge_upstream": {"type": "static", "dur": 5.0, "pos": Vector3(6.63, 0.1, 0.5), "look": Vector3(6.63, 0.6, 9.0), "fov": 50.0},
	"bridge_downstream": {"type": "static", "dur": 5.0, "pos": Vector3(6.63, 0.1, 17.5), "look": Vector3(6.63, 0.6, 9.0), "fov": 50.0},
	"bridge_east_end": {"type": "static", "dur": 5.0, "pos": Vector3(14.13, 1.4, 12.0), "look": Vector3(10.83, 0.3, 9.4), "fov": 45.0},
	"bridge_west_end": {"type": "static", "dur": 5.0, "pos": Vector3(-0.87, 1.4, 6.0), "look": Vector3(2.43, 0.3, 8.6), "fov": 45.0},
	"bridge_east_low": {"type": "static", "dur": 5.0, "pos": Vector3(10.13, 0.2, 4.0), "look": Vector3(10.13, 0.2, 9.0), "fov": 45.0},
	"bridge_west_low": {"type": "static", "dur": 5.0, "pos": Vector3(3.13, 0.2, 14.0), "look": Vector3(3.13, 0.2, 9.0), "fov": 45.0},
	"dbg": {"type": "static", "dur": 5.0, "pos": Vector3(-5.5, 1.6, -7.0), "look": Vector3(-10.5, 1.2, -12.0), "fov": 50.0},
	"map": {"type": "static", "dur": 5.0, "pos": Vector3(3.0, 150.0, 0.1), "look": Vector3(3.0, 0.0, 0.0), "ortho": 80.0},
	"cmp_3d": {"type": "static", "dur": 10.0, "pos": Vector3(5.0, 22.0, 23.0), "look": Vector3(5.0, 0.0, -3.0), "fov": 40.0, "ortho": 33.75},
}

var level: LevelV3
var shot := {}
var shot_name := ""
var _t := 0.0
var _follow_pos := Vector3.ZERO
var _follow_init := false
var _side := 0.0
var _stills: Array = []
const SUN_XZ := Vector2(-0.62, 0.78)        # откуда светит солнце (по сцене): камера встаёт с этой стороны
var _still_i := -1
var _still_wait := 0.0
var _still_tag := ""


func _ready() -> void:
	level = get_parent().get_node("Level") as LevelV3
	var args := OS.get_cmdline_user_args()
	shot_name = "fly_a"
	for a in args:
		if a.begins_with("--shot="):
			shot_name = a.substr(7)
		elif a == "--validate":
			_validate.call_deferred()
			return
		elif a.begins_with("--stills="):
			_stills = Array(a.substr(9).split(","))
	if not _stills.is_empty():
		_next_still()
		return
	_use(shot_name)


func _use(n: String) -> void:
	shot_name = n
	shot = SHOTS[n]
	_t = float(shot.get("t0", 0.0))
	_follow_init = false
	fov = float(shot.get("fov", 55.0))
	if shot.has("ortho"):
		projection = PROJECTION_ORTHOGONAL
		size = float(shot["ortho"])
	else:
		projection = PROJECTION_PERSPECTIVE
	_apply(0.0)


func _process(delta: float) -> void:
	_t += delta
	if not _stills.is_empty():
		_apply(delta)
		_still_wait -= delta
		if _still_wait <= 0.0:
			var img := get_viewport().get_texture().get_image()
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/v3/check"))
			img.save_png("res://shots/v3/check/%s%s.png" % [shot_name if not shot_name.begins_with("bridge_") else shot_name, _still_tag])
			print("still: ", shot_name)
			_next_still()
		return
	_apply(delta)


func _next_still() -> void:
	_still_i += 1
	if _still_i >= _stills.size():
		get_tree().quit()
		return
	var parts: PackedStringArray = str(_stills[_still_i]).split("@")
	_use(parts[0])
	_t = float(parts[1]) if parts.size() > 1 else float(shot["dur"]) * 0.5
	_still_tag = ("_" + parts[1]) if parts.size() > 1 else ""
	_still_wait = 1.2


func _apply(delta: float) -> void:
	var u := clampf(_t / float(shot["dur"]), 0.0, 1.0)
	match str(shot["type"]):
		"river":
			var zz := lerpf(float(shot["z0"]), float(shot["z1"]), u)
			var y := float(shot["y"])
			global_position = Vector3(LevelTerrain.river_x(zz) + float(shot.get("off", 0.0)), y, zz)
			var za := zz + 9.0 * signf(float(shot["z1"]) - float(shot["z0"]))
			look_at(Vector3(LevelTerrain.river_x(za), float(shot.get("look_y", -0.2)), za), Vector3.UP)
		"path":
			var e := u * u * (3.0 - 2.0 * u) * 0.35 + u * 0.65            # мягкий старт и финиш
			global_position = _spline(shot["pos"], e)
			look_at(_spline(shot["look"], e), Vector3.UP)
		"static":
			global_position = shot["pos"]
			look_at(shot["look"], Vector3.UP)
		"orbit":
			var c: Vector3 = shot.get("center", Vector3.ZERO)
			if shot.has("focus"):
				c = (level.focus[shot["focus"]] as Node3D).global_position
			var a := float(shot["start"]) + _t * float(shot["speed"])
			var r := float(shot["radius"])
			var p := c + Vector3(sin(a) * r, float(shot["height"]), cos(a) * r)
			p.y = maxf(p.y, LevelTerrain.height(p.x, p.z) + 0.25)
			global_position = p
			look_at(c + Vector3(0, float(shot["look_y"]), 0), Vector3.UP)
		"follow":
			var n := level.focus[shot["focus"]] as Node3D
			var fwd := Vector3(sin(n.rotation.y), 0, cos(n.rotation.y))
			var sv := fwd.cross(Vector3.UP)
			var sd := Vector2(sv.x, sv.z).dot(SUN_XZ)
			if _side == 0.0 or sd * _side < -0.35:              # сторона к солнцу, с запасом против дёрганья
				_side = signf(sd) if sd != 0.0 else 1.0
			var side := sv * _side
			var want := n.global_position + (side * 0.85 + fwd * 0.55).normalized() * float(shot["dist"])
			want.y = n.global_position.y + float(shot["height"])
			if not _follow_init:
				_follow_pos = want
				_follow_init = true
			_follow_pos = _follow_pos.lerp(want, clampf(delta * 0.9, 0.0, 1.0))
			for o in Wander.obstacles:                          # не влезать в кусты, стволы, камни
				var dv: Vector2 = Vector2(_follow_pos.x - o.x, _follow_pos.z - o.y)
				if dv.length() < float(o.z) + 0.9:
					var pv: Vector2 = Vector2(o.x, o.y) + dv.normalized() * (o.z + 0.9)
					_follow_pos.x = pv.x
					_follow_pos.z = pv.y
			_follow_pos.y = maxf(_follow_pos.y, LevelTerrain.height(_follow_pos.x, _follow_pos.z) + 0.25)
			global_position = _follow_pos
			look_at(n.global_position + Vector3(0, float(shot["look_y"]) * n.scale.y, 0), Vector3.UP)
		"follow_air":
			var b := level.focus[shot["focus"]] as Node3D
			var bf := b.global_basis.z
			bf.y = 0.0
			bf = bf.normalized()
			var bs := bf.cross(Vector3.UP)
			if Vector2(bs.x, bs.z).dot(SUN_XZ) < 0.0:
				bs = -bs
			var want := b.global_position + (bs * 0.8 + bf * 0.6).normalized() * float(shot["dist"]) + Vector3(0, float(shot["height"]), 0)
			if not _follow_init:
				_follow_pos = want
				_follow_init = true
			_follow_pos = _follow_pos.lerp(want, clampf(delta * 1.5, 0.0, 1.0))
			global_position = _follow_pos
			look_at(b.global_position, Vector3.UP)


## Проверка пролётов: камера не должна задевать кроны, дом, мост и землю.
func _validate() -> void:
	var dump := []
	for tr in level.tree_list:
		if absf(tr.x) < 60 and absf(tr.z) < 60:
			dump.append([snappedf(tr.x, 0.1), snappedf(tr.z, 0.1), snappedf(tr.y, 0.1), snappedf(tr.w, 0.01)])
	var f := FileAccess.open("res://shots/v3/check/trees.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(dump))
	f.close()
	var lf := FileAccess.open("res://assets_px/layout_3d.json", FileAccess.WRITE)
	lf.store_string(JSON.stringify(level.layout))
	lf.close()
	for n in SHOTS:
		var sh: Dictionary = SHOTS[n]
		if str(sh["type"]) in ["follow", "follow_air"] or n.ends_with("_old") or n.begins_with("bridge_"):
			continue
		_use(n)
		var bad: Array = []
		var t := 0.0
		while t <= float(sh["dur"]):
			_t = t
			_apply(0.0)
			var p := global_position
			var why := ""
			if p.y < LevelTerrain.height(p.x, p.z) + 0.6:
				why = "земля"
			for tr in level.tree_list:
				var d := Vector2(p.x - tr.x, p.z - tr.z).length()
				if d < 2.7 * tr.w and p.y > tr.y + 1.0 * tr.w and p.y < tr.y + 6.2 * tr.w:
					why = "крона (%.0f,%.0f)" % [tr.x, tr.z]
					break
				if d < 0.8 * tr.w and p.y < tr.y + 6.2 * tr.w:
					why = "ствол"
			for so in level.solid_list:
				if Vector2(p.x - so.x, p.z - so.z).length() < so.w and p.y < so.y + 4.5:
					why = "постройка (%.0f,%.0f)" % [so.x, so.z]
			if why != "":
				bad.append("%.1fс %s" % [t, why])
			t += 0.5
		print("%-16s %s" % [n, "OK" if bad.is_empty() else str(bad.slice(0, 12))])
	get_tree().quit()


## Открытый Catmull-Rom через все точки, u в 0..1.
func _spline(pts: Array, u: float) -> Vector3:
	var n := pts.size()
	var f := u * (n - 1)
	var i := clampi(int(floor(f)), 0, n - 2)
	var t := f - i
	var p0: Vector3 = pts[maxi(i - 1, 0)]
	var p1: Vector3 = pts[i]
	var p2: Vector3 = pts[i + 1]
	var p3: Vector3 = pts[mini(i + 2, n - 1)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
