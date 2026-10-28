class_name Wander
extends Node3D
## Блуждание животного: выбрать точку поблизости (не в реке, не в дереве), плавно развернуться
## на ходу и идти клипом walk, постоять в idle, иногда пробежать (run).
## Скорость тела = скорость лапы на земле в клипе (tools/stride_speed.gd) x темп клипа x масштаб,
## поэтому лапы не скользят. Животное всегда идёт туда, куда смотрит, — боком не едет.
## Нет клипа walk (заяц) — передвигается короткими перебежками клипом run.
## Модель студии смотрит в +Z, поэтому курс считаем как atan2(x, z).

enum State { IDLE, WALK, RUN, FLEE }

## Скорость лапы на земле при темпе 1 и масштабе 1, м/с (замер tools/stride_speed.gd).
@export var walk_stride := 0.5
@export var run_stride := 1.2
@export var walk_rate := 1.0           # темп клипа walk
@export var run_rate := 1.0            # темп клипа run
@export var turn_speed := 1.6          # рад/с — разворот на ходу, дугой
@export var wander_radius := 8.0
@export var idle_time := Vector2(2.0, 6.0)
@export var run_chance := 0.15
@export var shore_chance := 0.0        # шанс идти к берегу (олень пьёт у реки)
@export var flee_distance := 0.0       # 0 — не убегать от камеры (для съёмки)
@export var tempo := 1.0
@export var home := Vector2.INF        # центр участка; не уходить дальше wander_radius * 1.5
@export var dash_length := Vector2(1.5, 3.5)   # перебежка зайца, м

static var obstacles: Array = []       # Vector3(x, z, радиус) — дом, стволы, камни

var state := State.IDLE
var _target := Vector3.ZERO
var _timer := 1.0
var _yaw := 0.0
var _player: AnimationPlayer
var _clips := {}
var _current := ""
var _rng := RandomNumberGenerator.new()
var _no_walk := false

const ALIASES := {
	"idle": ["idle", "stand", "rest", "breath"],
	"walk": ["walk", "step", "hop"],
	"run": ["run", "gallop", "trot", "canter", "sprint"],
}


func _ready() -> void:
	add_to_group("wander")
	_rng.seed = hash(name) + int(global_position.x * 100.0)
	_yaw = _rng.randf() * TAU
	if home == Vector2.INF:
		home = Vector2(global_position.x, global_position.z)
	_timer = _rng.randf_range(0.3, idle_time.y * 0.6)
	_apply_rotation()


func _process(delta: float) -> void:
	if _player == null:
		_find_player()
	_check_threat()
	match state:
		State.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_pick_target(false)
		State.WALK, State.RUN, State.FLEE:
			_move(delta)
	_stick_to_ground()


func move_speed() -> float:
	if state == State.WALK:
		return walk_stride * walk_rate * tempo * scale.x
	if state == State.RUN or state == State.FLEE:
		return run_stride * run_rate * tempo * scale.x
	return 0.0


# ---------- выбор цели ----------

func _pick_target(flee: bool, threat := Vector3.ZERO) -> void:
	var origin := global_position
	for i in 24:
		var ang := _yaw + _rng.randf_range(-1.6, 1.6) if i < 12 else _rng.randf() * TAU   # чаще вперёд
		var dist := _rng.randf_range(wander_radius * 0.35, wander_radius)
		var run := _no_walk or _rng.randf() < run_chance
		if _no_walk:
			dist = _rng.randf_range(dash_length.x, dash_length.y)
		var p := origin + Vector3(sin(ang), 0, cos(ang)) * dist
		if flee:
			var away := (origin - threat)
			away.y = 0.0
			away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
			p = origin + away.rotated(Vector3.UP, _rng.randf_range(-0.8, 0.8)) * wander_radius
		elif _rng.randf() < shore_chance:
			var z := origin.z + _rng.randf_range(-3.0, 3.0)
			var side := signf(origin.x - LevelTerrain.river_x(origin.z))
			p = Vector3(LevelTerrain.river_x(z) + side * 4.2, 0, z)
		if Vector2(p.x, p.z).distance_to(home) > wander_radius * 1.5 and not flee:
			continue
		if _walkable(p) and _path_clear(origin, p):
			_target = p
			if flee:
				_start_move(State.FLEE)
			else:
				_start_move(State.RUN if run else State.WALK)
			return
	_idle()


func _walkable(p: Vector3) -> bool:
	if not LevelTerrain.in_bounds(p.x, p.z, 3.0) or LevelTerrain.is_water(p.x, p.z, 0.2):
		return false
	if LevelTerrain.normal(p.x, p.z).y < 0.82:                 # слишком круто
		return false
	for o in obstacles:
		if Vector2(p.x - o.x, p.z - o.y).length() < o.z + 0.4:
			return false
	return true


func _path_clear(a: Vector3, b: Vector3) -> bool:
	var steps := int(a.distance_to(b) / 0.6) + 1
	for s in range(1, steps + 1):
		if not _walkable(a.lerp(b, float(s) / steps)):
			return false
	return true


func _idle() -> void:
	state = State.IDLE
	_timer = _rng.randf_range(idle_time.x, idle_time.y)
	_play("idle")


func _start_move(s: State) -> void:
	state = s
	_play("walk" if s == State.WALK else "run")


# ---------- движение ----------

func _move(delta: float) -> void:
	var to := _target - global_position
	to.y = 0.0
	if to.length() < 0.3:
		_idle()
		return
	var want := atan2(to.x, to.z)
	var diff := angle_difference(_yaw, want)
	var max_turn := turn_speed * delta * (1.6 if state != State.WALK else 1.0)
	_yaw += clampf(diff, -max_turn, max_turn)
	# на крутом развороте замедляемся (лапы замедляются вместе с телом)
	var k := clampf(1.2 - absf(diff) / PI, 0.35, 1.0)
	var spd := move_speed() * k
	if _player and _current != "":
		_player.speed_scale = k
	var step := Vector3(sin(_yaw), 0, cos(_yaw)) * spd * delta
	var next := global_position + step
	if not _walkable(next):
		_idle()
		return
	global_position = next
	_apply_rotation()


func _apply_rotation() -> void:
	# лёгкий наклон по склону: нос вверх в горку
	var fwd := Vector3(sin(_yaw), 0, cos(_yaw)) * 0.4
	var p := global_position
	var dh := LevelTerrain.height(p.x + fwd.x, p.z + fwd.z) - LevelTerrain.height(p.x - fwd.x, p.z - fwd.z)
	rotation = Vector3(-atan2(dh, 0.8), _yaw, 0.0)


func _stick_to_ground() -> void:
	global_position.y = LevelTerrain.height(global_position.x, global_position.z)


func _check_threat() -> void:
	if flee_distance <= 0.0 or state == State.FLEE:
		return
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(global_position) < flee_distance:
		_pick_target(true, cam.global_position)


# ---------- анимация ----------

func _find_player() -> void:
	_player = _find_anim(self)
	if _player == null:
		return
	var names := _player.get_animation_list()
	for key in ALIASES:
		_clips[key] = _match_clip(names, ALIASES[key])
	_no_walk = _clips.get("walk", "") == ""
	_current = ""
	_play("idle")
	if _clips.get("idle", "") != "":                       # разная фаза у одинаковых животных
		_player.seek(_rng.randf() * _player.get_animation(_clips["idle"]).length, true)


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null


func _match_clip(names: PackedStringArray, words: Array) -> String:
	for w in words:
		for n in names:
			if n.to_lower() == w or n.to_lower() == w + "-loop" or n.to_lower() == w + "_loop":
				return n
	for w in words:
		for n in names:
			if n.to_lower().contains(w):
				return n
	return ""


func _play(key: String) -> void:
	if _player == null or _current == key:
		return
	var clip: String = _clips.get(key, "")
	if clip == "":
		clip = _clips.get("run", "") if key == "walk" else _clips.get("idle", "")
	if clip == "":
		return
	_current = key
	var rate := tempo * (walk_rate if key == "walk" else (run_rate if key == "run" else 1.0))
	_player.speed_scale = 1.0
	_player.play(clip, 0.25, rate)
