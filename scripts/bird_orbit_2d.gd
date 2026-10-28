class_name BirdOrbit2D
extends Node2D
## Птица в 2D кружит над рекой овалом вдоль русла. Клип — по направлению полёта.

@export var length := 190.0
@export var width := 70.0
@export var speed := 0.4
@export var phase := 0.0

var _a := 0.0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_a = phase
	_place()


func _process(delta: float) -> void:
	_a += speed * delta
	_place()


func _pos(a: float) -> Vector2:
	var y := PixelMap.SIZE.y * 0.5 + length * sin(a)
	return Vector2(PixelMap.river_col(y / PixelMap.TILE) * PixelMap.TILE + width * cos(a), y)


func _place() -> void:
	var p := _pos(_a)
	var v := _pos(_a + 0.05) - p
	position = p
	if _sprite == null:
		for c in get_children():
			if c is AnimatedSprite2D:
				_sprite = c
	if _sprite and _sprite.sprite_frames:
		var d: String = PixelAssets.DIRS[posmod(int(round(atan2(v.x, v.y) / (PI / 4.0))), 8)]
		var anim := "walk_" + d
		if _sprite.sprite_frames.has_animation(anim) and _sprite.animation != anim:
			_sprite.play(anim)
