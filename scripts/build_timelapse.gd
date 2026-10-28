extends Node3D
## Таймлапс сборки уровня: земля -> река -> деревья -> трава -> камни -> реквизит -> животные.
## Этапы появляются по таймеру (время кадров, не стенное), поэтому запись ровная:
##   godot --path . scenes/build_timelapse.tscn --write-movie shots/timelapse.avi --fixed-fps 30 --quit-after 780
## В углу счётчик ассетов 0 -> 64.

# когда начинается этап и сколько он идёт (сек)
const SCHEDULE := {
	"ground": [0.5, 2.2], "river": [3.0, 2.4], "trees": [5.8, 4.0], "grass": [10.2, 3.0],
	"rocks": [13.6, 2.2], "props": [16.2, 3.2], "animals": [19.8, 3.0],
}
const TITLES := {
	"ground": "Земля", "river": "Река", "trees": "Деревья", "grass": "Трава и кусты",
	"rocks": "Камни", "props": "Реквизит", "animals": "Животные",
}

@onready var level: LevelBuilder = $Level
@onready var cam: Camera3D = $Camera3D
@onready var counter: Label = $UI/Counter
@onready var stage_label: Label = $UI/Stage

var _t := 0.0
var _items: Array = []          # {node, orig, start, kind}
var _revealed := 0
var _total := 0


func _ready() -> void:
	for s in LevelBuilder.STAGES:
		level.build_stage(s)
	Populate.apply_3d(level)
	for s in LevelBuilder.STAGES:
		_prepare(s, level.groups[s])
	counter.text = "0"
	stage_label.text = ""


func _prepare(stage: String, g: Node3D) -> void:
	var start: float = SCHEDULE[stage][0]
	var dur: float = SCHEDULE[stage][1]
	# сначала всё скрыто: земля/вода/трава выезжают целиком, остальное — по одному предмету
	if stage in ["ground", "river", "grass"]:
		for c in g.get_children():
			_items.append({"node": c, "orig": c.scale, "start": start, "dur": dur, "stage": stage, "counted": false})
			(c as Node3D).scale = Vector3(1, 0.001, 1) if stage != "river" else Vector3(1, 1, 0.001)
		return
	var kids := g.get_children()
	for i in kids.size():
		var c := kids[i] as Node3D
		var counted := c is AssetSlot or c.find_children("*", "AssetSlot", true, false).size() > 0
		_items.append({"node": c, "orig": c.scale, "start": start + dur * float(i) / maxf(kids.size(), 1), "dur": 0.45,
			"stage": stage, "counted": counted})
		c.scale = Vector3.ONE * 0.001
		if counted:
			_total += 1


func _process(delta: float) -> void:
	_t += delta
	for it in _items:
		var p := clampf((_t - it.start) / it.dur, 0.0, 1.0)
		if p <= 0.0:
			continue
		var node: Node3D = it.node
		var k := _ease_out_back(p)
		match it.stage:
			"ground", "grass":
				node.scale = Vector3(it.orig.x, maxf(it.orig.y * p * p * (3.0 - 2.0 * p), 0.001), it.orig.z)
			"river":
				node.scale = Vector3(it.orig.x, it.orig.y, maxf(it.orig.z * p * p * (3.0 - 2.0 * p), 0.001))
			_:
				node.scale = it.orig * maxf(k, 0.001)
		if p > 0.0 and it.counted and not it.get("done", false):
			it["done"] = true
			_revealed += 1
			counter.text = str(_revealed)
		stage_label.text = TITLES[it.stage]
	# камера плавно обходит уровень и приближается
	var a := 0.6 + _t * 0.1
	var r := lerpf(58.0, 44.0, clampf(_t / 24.0, 0.0, 1.0))
	var h := lerpf(34.0, 20.0, clampf(_t / 24.0, 0.0, 1.0))
	cam.global_position = Vector3(sin(a) * r, h, cos(a) * r)
	cam.look_at(Vector3(2, 0.5, 0), Vector3.UP)


func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
