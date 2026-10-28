extends SceneTree
## Проверка и запись уровня с реальными ассетами из assets/manifest.json.
##   godot --headless --path . --script scripts/populate_cli.gd              — отчёт: что подставилось
##   godot --headless --path . --script scripts/populate_cli.gd -- --bake    — ещё и сохранить scenes/level_3d_baked.tscn
## (перед этим: tools/sync_assets.ps1, затем godot --headless --path . --import)


func _init() -> void:
	var bake := "--bake" in OS.get_cmdline_user_args()
	var entries := Populate.load_manifest(true)
	print("manifest: %d записей" % entries.size())
	for e in entries:
		print("  %-24s вид=%-9s 3D=%s  2D-листов=%d" % [e.id, e.kind, "да" if e.scene != "" else "нет", e.frames.size()])

	var level_scene := load("res://scenes/level_3d.tscn") as PackedScene
	var root := level_scene.instantiate()
	get_root().add_child(root)
	await process_frame

	var level := root.get_node("Level") as LevelBuilder
	var total := 0
	var filled := 0
	var kept := {}
	for s in level.find_children("*", "AssetSlot", true, false):
		total += 1
		var slot := s as AssetSlot
		if slot.filled_with != "":
			filled += 1
		else:
			kept[slot.kind] = int(kept.get(slot.kind, 0)) + 1
	print("слотов: %d, подставлено ассетов: %d, осталось заглушек: %d %s" % [total, filled, total - filled, kept])

	if bake:
		level.auto_build = false
		_own(root, root)
		var packed := PackedScene.new()
		var err := packed.pack(root)
		if err == OK:
			err = ResourceSaver.save(packed, "res://scenes/level_3d_baked.tscn")
		print("bake: ", "scenes/level_3d_baked.tscn" if err == OK else "ошибка %d" % err)
	quit()


## Владелец для всех сгенерированных узлов, кроме внутренностей вложенных пакетов.
func _own(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		if c.scene_file_path == "":
			_own(c, owner_node)
