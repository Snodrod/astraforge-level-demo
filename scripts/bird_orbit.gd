class_name BirdOrbit
extends Node3D
## Птица кружит в небе: овал вокруг центра, высота слегка гуляет.
## Клипы пакета студии: несколько взмахов (fly), потом парение (glide) — и снова взмахи.
## На вираже птица кренится внутрь круга. Модель смотрит в +Z.

@export var center := Vector2(0, 0)
@export var radius := Vector2(14.0, 10.0)
@export var altitude := 12.0
@export var speed := 0.22           # рад/с по овалу
@export var phase := 0.0
@export var flap_time := Vector2(2.0, 3.5)
@export var glide_time := Vector2(2.5, 4.5)

var _a := 0.0
var _anim: AnimationPlayer
var _fly := ""
var _glide := ""
var _gliding := false
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(name)
	_a = phase
	_place(_a)


func _process(delta: float) -> void:
	_a += speed * delta
	_place(_a)
	_wings(delta)


func _pos(a: float) -> Vector3:
	return Vector3(center.x + radius.x * cos(a), altitude + 1.2 * sin(a * 2.0 + phase) - (0.8 if _gliding else 0.0) * 0.0,
		center.y + radius.y * sin(a))


func _place(a: float) -> void:
	var p := _pos(a)
	var ahead := _pos(a + 0.05 * signf(speed)) - p
	global_position = p
	var yaw := atan2(ahead.x, ahead.z)
	var bank := -0.38 * signf(speed)
	rotation = Vector3(-atan2(ahead.y, Vector2(ahead.x, ahead.z).length()), yaw, bank)


func _wings(delta: float) -> void:
	if _anim == null:
		_anim = _find_anim(self)
		if _anim == null:
			return
		for n in _anim.get_animation_list():
			var l := n.to_lower()
			if l.begins_with("fly") or l.contains("flap"):
				_fly = n
			elif l.contains("glide"):
				_glide = n
		if _fly == "" and _anim.get_animation_list().size() > 0:
			_fly = _anim.get_animation_list()[0]
		_timer = _rng.randf_range(0.5, flap_time.y)
		_anim.play(_fly)
		_anim.seek(_rng.randf() * _anim.get_animation(_fly).length, true)
		return
	_timer -= delta
	if _timer > 0.0 or _glide == "":
		return
	_gliding = not _gliding
	if _gliding:
		_timer = _rng.randf_range(glide_time.x, glide_time.y)
		_anim.play(_glide, 0.5)
	else:
		_timer = _rng.randf_range(flap_time.x, flap_time.y)
		_anim.play(_fly, 0.35)


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null
