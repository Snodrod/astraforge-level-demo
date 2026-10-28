class_name LevelTerrain
extends RefCounted
## Рельеф уровня: поляна 64 x 64 м в центре, холм, ложбина-русло, а по краям — лесистые холмы,
## чтобы в кадре нигде не было обрыва земли. Всё считается формулой, поэтому земля, вода,
## трава и животные согласованы.

const SIZE := 64.0          # сторона игровой поляны, метры
const WORLD := 300.0        # сторона всей земли вместе с холмами по краям (дальше края камера не заглядывает)
const CELLS := 300         # квадратов по стороне всей земли (1 м)
const WATER_Y := -0.45      # уровень воды
const RIVER_W := 2.5        # ширина ложбины-русла (вода ~6.5 м)

const COL_GRASS := Color("7fb34a")
const COL_SAND := Color("c9b27a")
const COL_ROCK := Color("9a958c")
const COL_LEAF := Color("3f7d3a")
const COL_BARK := Color("6b4a2f")
const COL_WATER := Color("3b7fa8")
const COL_WARM := Color("e0913a")

## Ровные площадки под постройки: (x, z, радиус). Дом и костёр стоят на плоском.
## Мост: центр, направление пролёта и высоты. Под концами настила — насыпи-устои вровень с настилом,
## к ним пологие подходы; посередине русло остаётся, там мост стоит на сваях.
const BRIDGE_C := Vector2(6.632, 9.0)
const BRIDGE_YAW := PI * 0.5 + 0.12        # поворот моста; его +Z идёт поперёк реки
const BRIDGE_Y := -0.2                     # основание пакета моста
const ABUT_Y := 0.25                       # верх насыпи: настил (верх 0.53 м над основанием) лежит на ней

const PADS := [Vector3(14.0, -7.0, 6.5), Vector3(8.3, -4.2, 2.6)]


## Ось русла: x, где течёт река на данной z (плавные меандры).
static func river_x(z: float) -> float:
	return 3.0 + 4.5 * sin(z * 0.10) + 1.5 * sin(z * 0.23 + 1.0)


static func _raw(x: float, z: float) -> float:
	var d: float = absf(x - river_x(z))
	var h := 0.30 * sin(x * 0.17) * cos(z * 0.13) + 0.15 * sin(x * 0.41 + z * 0.37)   # лёгкая рябь
	var hd := Vector2(x + 16.0, z + 10.0).length()
	h += 4.2 * exp(-pow(hd / 9.0, 2.0))                    # холм
	h += rim(x, z) * smoothstep(6.0, 34.0, d)              # холмы по краям, долина реки уходит между ними (пологие склоны)
	h -= 2.6 * exp(-pow(d / RIVER_W, 2.0))                 # русло
	h = lerpf(h, maxf(h, -0.12), smoothstep(5.5, 7.5, d))   # вдали от реки — без луж ниже уровня воды
	return h


## Холмы вокруг поляны: начинаются за 26 м от центра, к 60 м поднимаются на 9-16 м.
static func rim(x: float, z: float) -> float:
	var q := pow(pow(absf(x), 4.0) + pow(absf(z), 4.0), 0.25)       # «скруглённый квадрат»
	var k := smoothstep(25.0, 62.0, q)
	var wav := 0.65 + 0.2 * sin(x * 0.11 + 1.3) * cos(z * 0.09) + 0.15 * sin(x * 0.043 - z * 0.051)
	return k * k * 17.0 * wav


static func height(x: float, z: float) -> float:
	var h := _raw(x, z)
	for p in PADS:
		var w := 1.0 - smoothstep(p.z * 0.6, p.z, Vector2(x - p.x, z - p.y).length())
		if w > 0.0:
			h = lerpf(h, _raw(p.x, p.y), w)
	var bw := bridge_weight(x, z)
	if bw > 0.0:
		h = lerpf(h, ABUT_Y, bw)
	return h


## Координаты точки в осях моста: x — вдоль пролёта, y — поперёк.
static func bridge_local(x: float, z: float) -> Vector2:
	var d := Vector2(x, z) - BRIDGE_C
	var along := Vector2(sin(BRIDGE_YAW), cos(BRIDGE_YAW))
	var across := Vector2(-along.y, along.x)
	return Vector2(d.dot(along), d.dot(across))


## Вес насыпи под концами моста: крутой откос к воде (2.6-3.0 м от центра), полка до 4.6 м,
## пологий подход до 8 м; по ширине — полка 2 м и откосы до 3.4 м.
static func bridge_weight(x: float, z: float) -> float:
	var l := bridge_local(x, z)
	var a := absf(l.x)
	var w := absf(l.y)
	if a > 8.0 or w > 3.4:
		return 0.0
	return smoothstep(2.55, 3.05, a) * (1.0 - smoothstep(4.6, 8.0, a)) * (1.0 - smoothstep(2.0, 3.4, w))


## Расстояние от точки до оси реки по X (для песка, леса и травы).
static func river_dist(x: float, z: float) -> float:
	return absf(x - river_x(z))


static func is_water(x: float, z: float, margin: float = 0.0) -> bool:
	return height(x, z) < WATER_Y + margin


static func in_bounds(x: float, z: float, pad: float = 2.0) -> bool:
	var h := SIZE * 0.5 - pad
	return absf(x) < h and absf(z) < h


## Нормаль рельефа (для наклона животных и проверки крутизны).
static func normal(x: float, z: float) -> Vector3:
	var e := 0.3
	return Vector3(height(x - e, z) - height(x + e, z), 2.0 * e, height(x, z - e) - height(x, z + e)).normalized()


## Меш рельефа: сетка с гладкими нормалями (нормаль по разности высот).
## Цвет и смешивание земли/травы/песка/камня делает shaders/terrain.gdshader по высоте и уклону.
static func build_mesh(world := WORLD, cells := CELLS) -> ArrayMesh:
	var n := cells + 1
	var step := world / cells
	var half := world * 0.5
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(n * n)
	norms.resize(n * n)
	uvs.resize(n * n)
	for j in n:
		for i in n:
			var x := -half + i * step
			var z := -half + j * step
			var k := j * n + i
			verts[k] = Vector3(x, height(x, z), z)
			norms[k] = normal(x, z)
			uvs[k] = Vector2(float(i), float(j)) / cells
	for j in cells:
		for i in cells:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			idx.append_array(PackedInt32Array([a, b, c, b, d, c]))   # лицевая сторона вверх
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
