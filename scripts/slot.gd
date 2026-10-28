class_name AssetSlot
extends Node3D
## Слот под ассет. Пока студия не отдала пакет, внутри стоит заглушка-примитив.
## populate.gd заменяет заглушку на реальный пакет одной операцией: slot.fill(node).

@export var kind := "tree"       # tree, bush, rock, house, bridge, campfire, barrel, crate, torch, hare, deer, fox, bird
@export var variant := 0         # номер породы / вида внутри kind
@export var target_height := 0.0 # желаемая высота, м (0 — не масштабировать)

var filled_with := ""            # id подставленного ассета ("" — заглушка)


func _ready() -> void:
	if get_child_count() == 0:
		add_child(Placeholders.make(kind, variant))


## Заменить содержимое слота на готовый узел (экземпляр пакета студии).
func fill(asset_node: Node3D, asset_id: String) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	add_child(asset_node)
	filled_with = asset_id
