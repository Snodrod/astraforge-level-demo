extends SceneTree
## Скорость шага по клипу: пока лапа стоит на земле, она едет назад со скоростью тела.
## Эту скорость и надо давать телу в wander.gd, тогда лапы не скользят.
##   godot --headless --path . --script tools/stride_speed.gd

const ANIMALS := ["deer", "fox", "hare", "sparrow", "crow"]
var out := {}
const FOOT_WORDS := ["paw", "foot", "hoof", "toe"]


func _init() -> void:
	for id in ANIMALS:
		if not ResourceLoader.exists("res://assets/%s/godot_package/%s.tscn" % [id, id]):
			continue
		var n := (load("res://assets/%s/godot_package/%s.tscn" % [id, id]) as PackedScene).instantiate() as Node3D
		out[id] = {}
		get_root().add_child(n)
		await process_frame
		var aps := n.find_children("*", "AnimationPlayer", true, false)
		var sks := n.find_children("*", "Skeleton3D", true, false)
		if aps.is_empty() or sks.is_empty():
			n.queue_free()
			continue
		var ap := aps[0] as AnimationPlayer
		var sk := sks[0] as Skeleton3D
		var feet: Array[int] = []
		for b in sk.get_bone_count():
			var bn := sk.get_bone_name(b).to_lower()
			for w in FOOT_WORDS:
				if bn.contains(w) and not bn.contains("ik") and not bn.contains("pole"):
					feet.append(b)
					break
		var names := []
		for b in feet:
			names.append(sk.get_bone_name(b))
		print(id, " feet: ", names)
		for clip in ap.get_animation_list():
			if clip == "RESET":
				continue
			var anim := ap.get_animation(clip)
			ap.play(clip)
			var steps := 120
			var dt := anim.length / steps
			var tracks := {}
			for b in feet:
				tracks[b] = []
			for s in steps + 1:
				ap.seek(s * dt, true)
				sk.force_update_all_bone_transforms()
				var to_root := n.global_transform.affine_inverse() * sk.global_transform
				for b in feet:
					tracks[b].append(to_root * sk.get_bone_global_pose(b).origin)
			var speeds := []
			for b in feet:
				var arr: Array = tracks[b]
				var miny := INF
				for p in arr:
					miny = minf(miny, p.y)
				var sum := 0.0
				var cnt := 0
				for s in steps:
					if arr[s].y < miny + 0.015 and arr[s + 1].y < miny + 0.015:
						sum += -(arr[s + 1].z - arr[s].z) / dt
						cnt += 1
				if cnt > 0:
					speeds.append(sum / cnt)
			var avg := 0.0
			for v in speeds:
				avg += v
			avg /= maxf(speeds.size(), 1)
			var fmt := []
			for v in speeds:
				fmt.append("%.2f" % v)
			out[id][clip] = snappedf(maxf(avg, 0.0), 0.001)
			print("  %-8s len=%.2fs  контакт-скорость лап %s  => %.2f м/с" % [clip, anim.length, fmt, avg])
		n.queue_free()
	var f := FileAccess.open("res://assets/strides.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()
	print("assets/strides.json: ", out)
	quit()
