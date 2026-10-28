class_name PixelAnimal
extends Node2D
## Животное пиксельной версии: живёт в метрах (x, z) той же карты, что 3D, на экран — через to_px.
## Как wander.gd: выбрать точку, идти по ходу (боком не едет), постоять, иногда пробежать.
## Направление — один из 8 видов листа студии (S, SW, W, NW, N, NE, E, SE) по курсу на экране.
## Скорость тела = скорость лапы в клипе (в пикселях листа), поэтому лапы не скользят.

const VIEWS := ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]

var lvl: Node
var kind := "deer"
var wx := 0.0
var wz := 0.0
var home := Vector2.ZERO
var radius := 6.0
var run_chance := 0.2
var speeds := {}                 # клип -> м/с по карте
var rates := {}                  # клип -> темп листа
var clip_alias := {}             # walk -> hop у зайца
var state := "idle"
var _target := Vector2.ZERO
var _timer := 1.0
var _yaw := 0.0
var _spr: AnimatedSprite2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(name) + int(wx * 100.0)
	_yaw = _rng.randf() * TAU
	_timer = _rng.randf_range(0.3, 2.5)
	_spr = get_child(0) as AnimatedSprite2D
	_play("idle")
	_spr.frame = _rng.randi() % maxi(1, _spr.sprite_frames.get_frame_count(_spr.animation))
	_sync()


func _process(delta: float) -> void:
	if state == "idle":
		_timer -= delta
		if _timer <= 0.0:
			_pick()
	else:
		_move(delta)
	_sync()


func _pick() -> void:
	var no_walk := not speeds.has("walk")
	for i in 20:
		var ang := _yaw + _rng.randf_range(-1.6, 1.6) if i < 10 else _rng.randf() * TAU
		var dist := _rng.randf_range(1.5, 3.5) if no_walk else _rng.randf_range(radius * 0.35, radius)
		var p := Vector2(wx + sin(ang) * dist, wz + cos(ang) * dist)
		if p.distance_to(home) > radius * 1.5:
			continue
		if lvl.walkable(p.x, p.y) and _clear(p):
			_target = p
			state = "run" if (no_walk or _rng.randf() < run_chance) and speeds.has("run") else "walk"
			_play(state)
			return
	_idle()


func _clear(p: Vector2) -> bool:
	var a := Vector2(wx, wz)
	var steps := int(a.distance_to(p) / 0.6) + 1
	for s in range(1, steps + 1):
		var q := a.lerp(p, float(s) / steps)
		if not lvl.walkable(q.x, q.y):
			return false
	return true


func _idle() -> void:
	state = "idle"
	_timer = _rng.randf_range(1.5, 5.0) if kind != "sparrow" else _rng.randf_range(0.6, 2.0)
	_play("idle")


func _move(delta: float) -> void:
	var to := _target - Vector2(wx, wz)
	if to.length() < 0.25:
		_idle()
		return
	var want := atan2(to.x, to.y)
	var diff := angle_difference(_yaw, want)
	_yaw += clampf(diff, -2.4 * delta, 2.4 * delta)
	var k := clampf(1.2 - absf(diff) / PI, 0.4, 1.0)
	_spr.speed_scale = float(rates.get(state, 1.0)) * k
	var spd: float = float(speeds.get(state, 0.0)) * k
	var nx := wx + sin(_yaw) * spd * delta
	var nz := wz + cos(_yaw) * spd * delta
	if not lvl.walkable(nx, nz):
		_idle()
		return
	wx = nx
	wz = nz
	_play(state)


func _sync() -> void:
	position = lvl.to_px(wx, wz).round()


## Вид листа по курсу на экране: S — к зрителю (+z), W — влево (-x).
func _view() -> String:
	var sx := sin(_yaw)
	var sz := cos(_yaw) * 0.6428
	var a := atan2(sx, sz)                       # 0 = вниз по экрану
	var idx := posmod(int(round(-a / (PI / 4.0))), 8)
	return VIEWS[idx]


func _play(clip: String) -> void:
	var an := "%s_%s" % [clip_alias.get(clip, clip), _view()]
	if not _spr.sprite_frames.has_animation(an):
		an = "idle_%s" % _view()
	if _spr.animation != an:
		var f := _spr.frame
		_spr.play(an)
		_spr.frame = f % maxi(1, _spr.sprite_frames.get_frame_count(an))
	if clip == "idle":
		_spr.speed_scale = 1.0
