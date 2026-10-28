class_name Wander2D
extends Node2D
## Блуждание животного в 2D (то же самое, что wander.gd в 3D): выбрать точку не в реке,
## повернуться, идти клипом walk, постоять idle, иногда побежать run, от камеры/игрока убегать.
## Листы студии дают анимации «<клип>_<НАПРАВЛЕНИЕ>» по 8 направлениям: idle_S, walk_NE, run_W ...
## Дочерний AnimatedSprite2D находим сами; клипы ищем по началу имени (idle / walk / run).

enum State { IDLE, WALK, RUN, FLEE }

const DIRS := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]

@export var walk_speed := 14.0         # пикселей в секунду
@export var run_speed := 70.0
@export var wander_radius := 120.0
@export var idle_time := Vector2(2.0, 6.0)
@export var run_chance := 0.2
@export var shore_chance := 0.0
@export var flee_distance := 70.0
@export var tempo := 1.0

var state := State.IDLE
var _target := Vector2.ZERO
var _timer := 1.0
var _dir := 0
var _sprite: AnimatedSprite2D
var _avail := {}                         # префикс клипа -> какие направления есть в листе (4 или 8)
var _clips := {}                       # "idle"/"walk"/"run" -> префикс клипа в листе
var _rng := RandomNumberGenerator.new()
var threat: Node2D                     # за кем убегать (курсор, игрок); можно не задавать


func _ready() -> void:
	_rng.seed = hash(name) + int(position.x * 10.0)
	_timer = _rng.randf_range(0.2, idle_time.y)
	_dir = _rng.randi() % 8


func _process(delta: float) -> void:
	if _sprite == null:
		_bind()
	if _check_threat():
		_pick(true)
	match state:
		State.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_pick(false)
		_:
			_move(delta)
	_animate()


func _pick(flee: bool) -> void:
	for i in 16:
		var ang := _rng.randf() * TAU
		var p := position + Vector2(cos(ang), sin(ang)) * _rng.randf_range(wander_radius * 0.4, wander_radius)
		if flee and threat:
			var away := (position - threat.global_position).normalized().rotated(_rng.randf_range(-0.7, 0.7))
			p = position + away * wander_radius
		elif _rng.randf() < shore_chance:                       # к берегу: олень пьёт
			var y := position.y + _rng.randf_range(-wander_radius, wander_radius)
			var side := signf(_rng.randf() - 0.5)
			p = Vector2((PixelMap.river_col(y / PixelMap.TILE) + side * (PixelMap.WATER_HALF + 0.9)) * PixelMap.TILE, y)
		if PixelMap.in_map(p) and not PixelMap.is_water_px(p, 0.6):
			_target = p
			state = State.FLEE if flee else (State.RUN if _rng.randf() < run_chance else State.WALK)
			return
	state = State.IDLE
	_timer = _rng.randf_range(idle_time.x, idle_time.y)


func _move(delta: float) -> void:
	var to := _target - position
	if to.length() < 3.0:
		state = State.IDLE
		_timer = _rng.randf_range(idle_time.x, idle_time.y)
		return
	var spd := (walk_speed if state == State.WALK else run_speed) * tempo
	var next := position + to.normalized() * spd * delta
	if PixelMap.is_water_px(next, 0.2) or not PixelMap.in_map(next):
		state = State.IDLE
		_timer = _rng.randf_range(idle_time.x, idle_time.y)
		return
	position = next
	_dir = _dir_index(to)


func _check_threat() -> bool:
	if state == State.FLEE or threat == null:
		return false
	return threat.global_position.distance_to(global_position) < flee_distance


## Вектор на экране -> индекс направления: 0 = S (вниз), дальше по часовой: SE, E, NE, N ...
func _dir_index(v: Vector2) -> int:
	var ang := atan2(v.x, v.y)
	return posmod(int(round(ang / (PI / 4.0))), 8)


# ---------- анимация ----------

func _bind() -> void:
	for c in get_children():
		if c is AnimatedSprite2D:
			_sprite = c
	if _sprite == null or _sprite.sprite_frames == null:
		_sprite = null
		return
	_clips.clear()
	_avail.clear()
	var prefixes := {}
	for n in _sprite.sprite_frames.get_animation_names():
		var cut := String(n).rfind("_")
		if cut > 0 and String(n).substr(cut + 1) in DIRS:
			var pre := String(n).substr(0, cut)
			prefixes[pre] = true
			if not _avail.has(pre):
				_avail[pre] = []
			_avail[pre].append(String(n).substr(cut + 1))
	for key in ["idle", "walk", "run"]:
		_clips[key] = _find_prefix(prefixes.keys(), key)


func _find_prefix(prefixes: Array, key: String) -> String:
	for p in prefixes:
		if String(p).to_lower().begins_with(key):
			return p
	if key == "run":                                   # нет бега — идём клипом шага
		return _find_prefix(prefixes, "walk")
	if key == "walk":
		return _find_prefix(prefixes, "idle")
	return prefixes[0] if not prefixes.is_empty() else ""


func _animate() -> void:
	if _sprite == null or _clips.is_empty():
		return
	var key := "idle" if state == State.IDLE else ("walk" if state == State.WALK else "run")
	var anim: String = "%s_%s" % [_clips.get(key, ""), _best_dir(_clips.get(key, ""))]
	if _sprite.sprite_frames.has_animation(anim):
		if _sprite.animation != anim:
			var frame := _sprite.frame
			_sprite.play(anim)
			_sprite.set_frame_and_progress(frame % maxi(_sprite.sprite_frames.get_frame_count(anim), 1), 0.0)
		_sprite.speed_scale = tempo


## Лист студии может быть на 4 направления (S, E, N, W) или на 8: берём ближайшее из имеющихся.
func _best_dir(prefix: String) -> String:
	var have: Array = _avail.get(prefix, [])
	if have.is_empty() or DIRS[_dir] in have:
		return DIRS[_dir]
	var best: String = have[0]
	var best_d := 99
	for d in have:
		var diff: int = absi(posmod(DIRS.find(d) - _dir + 4, 8) - 4)
		if diff < best_d:
			best_d = diff
			best = d
	return best
