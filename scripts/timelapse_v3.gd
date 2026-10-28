extends Node3D
## Таймлапс v3: пустая сцена Godot (серая сетка) -> земля -> река -> трава -> деревья -> камни -> реквизит -> животные.
## Время — по кадрам: godot --path . scenes/timelapse_v3.tscn --write-movie shots/v3/tmp/tl/f.png --fixed-fps 30 --quit-after 1590
## В углу: сколько разных ассетов AstraForge уже на сцене и название этапа.

const SCHEDULE := {   # этап: [начало, длительность], сек
	"ground": [3.0, 4.5], "river": [8.0, 4.0], "grass": [12.5, 6.0], "trees": [19.0, 10.0],
	"rocks": [29.5, 3.5], "props": [33.0, 5.5], "animals": [38.5, 4.5],
}
const TITLES := {
	"ground": "Земля", "river": "Река", "grass": "Трава, кусты, цветы", "trees": "Деревья",
	"rocks": "Камни", "props": "Реквизит", "animals": "Животные",
}
const TOTAL := 53.0

@onready var level: LevelV3 = $Level
@onready var cam: Camera3D = $Camera3D
@onready var grid: MeshInstance3D = $Grid
@onready var counter: Label = $UI/Counter
@onready var stage_label: Label = $UI/Stage

var _t := 0.0
var _items: Array = []          # {node, orig, start, dur, mode, id}
var _ring_start := 0.0
var _ring_dur := 0.0
var _seen := {}


func _ready() -> void:
	for s in LevelV3.STAGES:
		level.build_stage(s)
	for s in LevelV3.STAGES:
		_prepare(s, level.groups[s])
	_ring_start = SCHEDULE["trees"][0] + 2.0
	_ring_dur = SCHEDULE["trees"][1] - 2.0
	_ring_apply()
	counter.text = "0"
	stage_label.text = "Пустая сцена"


func _prepare(stage: String, g: Node3D) -> void:
	var start: float = SCHEDULE[stage][0]
	var dur: float = SCHEDULE[stage][1]
	if stage == "ground" or stage == "river":
		for c in g.get_children():
			if c is Node3D:
				_items.append({"node": c, "orig": c.scale, "start": start, "dur": dur, "mode": stage, "id": "textures"})
				_hide(c, stage)
		return
	var kids: Array = []
	for c in g.get_children():
		if c is Node3D and not (stage == "trees" and c.name == "RingForest"):
			kids.append(c)
	# сначала крупное ближе к центру, потом дальше: появление «волной» от центра
	kids.sort_custom(func(a, b): return Vector2(a.position.x, a.position.z).length() < Vector2(b.position.x, b.position.z).length())
	var span := dur * (0.55 if stage == "trees" else 0.85)
	for i in kids.size():
		var c: Node3D = kids[i]
		var mode := "grow" if c.name in ["Meadow", "HillGrass", "GrassClumps", "Flowers"] else "pop"
		var st := start + span * float(i) / maxf(kids.size(), 1)
		if mode == "grow":
			st = start
		_items.append({"node": c, "orig": c.scale, "start": st, "dur": 2.5 if mode == "grow" else 0.5, "mode": mode,
			"id": str(c.get_meta("asset", ""))})
		_hide(c, mode)


func _hide(c: Node3D, mode: String) -> void:
	match mode:
		"river":
			c.scale = Vector3(1, 1, 0.001)
		"ground", "grow":
			c.scale = Vector3(1, 0.001, 1)
		_:
			c.scale = Vector3.ONE * 0.001
	c.visible = false


func _process(delta: float) -> void:
	_t += delta
	for it in _items:
		var p := clampf((_t - it.start) / it.dur, 0.0, 1.0)
		if p <= 0.0:
			continue
		var node: Node3D = it.node
		node.visible = true
		var sm := p * p * (3.0 - 2.0 * p)
		match it.mode:
			"ground", "grow":
				node.scale = Vector3(it.orig.x, maxf(it.orig.y * sm, 0.001), it.orig.z)
			"river":
				node.scale = Vector3(it.orig.x, it.orig.y, maxf(it.orig.z * sm, 0.001))
			_:
				node.scale = it.orig * maxf(_ease_out_back(p), 0.001)
		if it.id != "" and not _seen.has(it.id):
			_seen[it.id] = true
			if it.id == "ring":
				pass
			counter.text = str(_count())
		if p < 1.0 or _t < it.start + it.dur + 0.1:
			stage_label.text = TITLES[_stage_of(it)]
	_ring_apply()
	# сетка пустой сцены гаснет, когда поднимается земля
	var gp := clampf((_t - SCHEDULE["ground"][0]) / 2.5, 0.0, 1.0)
	grid.visible = gp < 1.0
	grid.position.y = 0.02 - gp * 3.0                      # сетка уходит под поднимающуюся землю
	if _t > SCHEDULE["animals"][0] + SCHEDULE["animals"][1] + 1.0:
		stage_label.text = "Уровень готов"
	# камера: высокий облёт, понемногу снижается и подлетает ближе
	var k := clampf(_t / TOTAL, 0.0, 1.0)
	var a := 0.55 + _t * 0.055
	var r := lerpf(52.0, 40.0, k)
	var h := lerpf(42.0, 27.0, k * k * (3.0 - 2.0 * k))
	cam.global_position = Vector3(3.0 + sin(a) * r, h, cos(a) * r)
	cam.look_at(Vector3(4, 0.0, -1), Vector3.UP)


func _stage_of(it: Dictionary) -> String:
	var best := "ground"
	for s in SCHEDULE:
		if it.start >= SCHEDULE[s][0] - 0.01:
			best = s
	return best


func _count() -> int:
	var n := 0
	for id in _seen:
		if id == "ring" or id == "textures":
			continue
		n += 1
	# лес на холмах — все 11 деревьев студии; ассеты, которые пришли только с лесом
	if _seen.has("ring"):
		n = maxi(n, n)
	return n + (1 if _seen.has("textures") else 0)


## Лес на холмах вырастает волной от поляны к горизонту.
func _ring_apply() -> void:
	if _t > _ring_start + _ring_dur + 1.0 and _t > 1.0:
		return
	for e in level.ring:
		var q: float = e[3]
		var st := _ring_start + _ring_dur * clampf((q - 27.0) / 65.0, 0.0, 1.0) * 0.8
		var p := clampf((_t - st) / 0.6, 0.0, 1.0)
		var kk := maxf(_ease_out_back(p), 0.0005) if p > 0.0 else 0.0005
		var o: Vector3 = e[4]
		var t: Transform3D = e[2]
		var xf := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * kk), o - o * kk) * t
		(e[0] as MultiMesh).set_instance_transform(e[1], xf)


func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
