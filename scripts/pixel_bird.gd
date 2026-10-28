class_name PixelBird
extends Node2D
## Ворона пиксельной версии: тот же овал, что bird_orbit.gd в 3D; высота поднимает спрайт вверх
## на экране (cos 40° x 16 px/м), клипы листа: взмахи (fly) и парение (glide), 8 направлений.

const VIEWS := ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]

var lvl: Node
var center := Vector2.ZERO
var radius := Vector2(14, 10)
var altitude := 12.0
var speed := 0.22
var phase := 0.0
var _a := 0.0
var _spr: AnimatedSprite2D
var _timer := 2.0
var _glide := false
var _shadow: Sprite2D


func _ready() -> void:
	_a = phase
	_spr = get_child(0) as AnimatedSprite2D
	_shadow = Sprite2D.new()
	_shadow.texture = PixelAssets.shadow_tex(5, 2)
	_shadow.modulate = Color(1, 1, 1, 0.6)
	get_parent().add_child.call_deferred(_shadow)
	_place()


func _process(delta: float) -> void:
	_a += speed * delta
	_timer -= delta
	if _timer <= 0.0:
		_glide = not _glide
		_timer = 3.5 if _glide else 2.5
	_place()


func _p(a: float) -> Vector3:
	return Vector3(center.x + radius.x * cos(a), altitude + 1.2 * sin(a * 2.0 + phase), center.y + radius.y * sin(a))


func _place() -> void:
	var p := _p(_a)
	var q := _p(_a + 0.05)
	var g: Vector2 = lvl.to_px(p.x, p.z)
	position = (g - Vector2(0, p.y * 16.0 * 0.766)).round()
	if _shadow:
		_shadow.position = g.round() + Vector2(6, 2)
	var a := atan2(q.x - p.x, (q.z - p.z) * 0.6428)
	var v: String = VIEWS[posmod(int(round(-a / (PI / 4.0))), 8)]
	var an := ("glide_" if _glide else "fly_") + v
	if _spr.sprite_frames.has_animation(an) and _spr.animation != an:
		_spr.play(an)
