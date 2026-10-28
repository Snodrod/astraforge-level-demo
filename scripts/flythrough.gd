class_name Flythrough
extends Camera3D
## Облёт уровня по пути: камера идёт по гладкому сплайну (Catmull-Rom), смотрит на другой сплайн.
## Для финального пролёта и хука. Время считается по кадрам, поэтому запись через
## --write-movie --fixed-fps получается ровной.

@export var duration := 40.0        # секунд на полный круг
@export var loop := true
@export var autostart := true
@export var start_offset := 0.0     # 0..1, откуда стартовать

## Точки пути камеры и точки, на которые она смотрит (замкнутый круг над уровнем).
@export var path_points := PackedVector3Array([
	Vector3(30, 11, 30), Vector3(34, 8, 4), Vector3(26, 6, -22), Vector3(4, 9, -34),
	Vector3(-22, 12, -24), Vector3(-34, 8, 4), Vector3(-18, 7, 28), Vector3(6, 5, 24)])
@export var look_points := PackedVector3Array([
	Vector3(2, 0, 2), Vector3(4, 0, 0), Vector3(2, 1, -4), Vector3(0, 1, 0),
	Vector3(-6, 1, -2), Vector3(0, 0, 2), Vector3(4, 0, 6), Vector3(8, 0, 0)])

var _time := 0.0
var running := false


func _ready() -> void:
	_time = start_offset * duration
	running = autostart
	_apply(start_offset)


func _process(delta: float) -> void:
	if not running:
		return
	_time += delta
	var u := _time / duration
	if loop:
		u = fposmod(u, 1.0)
	elif u >= 1.0:
		u = 1.0
		running = false
	_apply(u)


func _apply(u: float) -> void:
	global_position = _spline(path_points, u)
	look_at(_spline(look_points, u), Vector3.UP)


## Замкнутый Catmull-Rom по массиву точек, u в 0..1.
func _spline(pts: PackedVector3Array, u: float) -> Vector3:
	var n := pts.size()
	var f := u * n
	var i := int(floor(f))
	var t := f - i
	var p0 := pts[(i - 1 + n) % n]
	var p1 := pts[i % n]
	var p2 := pts[(i + 1) % n]
	var p3 := pts[(i + 2) % n]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
