class_name PixelMap
extends RefCounted
## Карта 2D-уровня: 40 x 23 клетки по 24 пикселя (1 клетка = 1 метр, как профиль pixel студии).
## Река идёт сверху вниз, как в 3D идёт по оси Z.

const TILE := 24
const COLS := 40
const ROWS := 23
const SIZE := Vector2(COLS * TILE, ROWS * TILE)   # 960 x 552
const WATER_HALF := 1.7          # половина ширины воды, клеток
const SAND_HALF := 2.6           # песок по берегу, клеток


## Ось реки (в клетках) на высоте row.
static func river_col(row: float) -> float:
	return 21.0 + 3.6 * sin(row * 0.33) + 1.1 * sin(row * 0.8 + 1.0)


static func is_water_px(p: Vector2, margin := 0.0) -> bool:
	return absf(p.x / TILE - river_col(p.y / TILE)) < WATER_HALF + margin


static func in_map(p: Vector2, pad := 12.0) -> bool:
	return p.x > pad and p.y > pad and p.x < SIZE.x - pad and p.y < SIZE.y - pad
