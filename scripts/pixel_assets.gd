class_name PixelAssets
extends RefCounted
## Пиксельные заглушки для 2D-уровня: деревья, камни, домик, животные по 8 направлениям.
## Рисуются кодом в палитре проекта. Настоящие листы студии (профиль pixel) заменят их через populate.gd.
## Точка опоры спрайта — основание: спрайт центрирован с offset = (0, -высота/2).

const C_GRASS := Color("7fb34a")
const C_LEAF := Color("3f7d3a")
const C_BARK := Color("6b4a2f")
const C_STONE := Color("9a958c")
const C_WATER := Color("3b7fa8")
const C_WARM := Color("e0913a")
const C_OUT := Color("243b27")           # общая обводка

const DIRS := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const DIR_VEC := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(1, -1), Vector2(0, -1), Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1)]


# ---------- рисование ----------

static func new_img(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func put(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)


static func rect(img: Image, x0: int, y0: int, w: int, h: int, col: Color) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			put(img, x, y, col)


## Шар с тремя ступенями света (свет сверху-слева) и шахматной растушёвкой на границе.
static func blob(img: Image, cx: float, cy: float, rx: float, ry: float, base: Color) -> void:
	var light := base.lightened(0.22)
	var dark := base.darkened(0.28)
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var nx := (x - cx) / rx
			var ny := (y - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				var t := (nx + ny) * 0.5
				var checker := (x + y) % 2 == 0
				var c := base
				if t < -0.35 or (t < -0.2 and checker):
					c = light
				elif t > 0.4 or (t > 0.25 and checker):
					c = dark
				put(img, x, y, c)


static func outline(img: Image, col: Color = C_OUT) -> void:
	var src := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < img.get_width() and ny < img.get_height() and src.get_pixel(nx, ny).a > 0.5:
					img.set_pixel(x, y, col)
					break


static func tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func frames_from(textures: Array, fps := 1.0) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("idle_S")
	sf.set_animation_speed("idle_S", fps)
	sf.set_animation_loop("idle_S", true)
	for t in textures:
		sf.add_frame("idle_S", t)
	return sf


## Дешёвый детерминированный хеш 0..1 для текстурных точек.
static func h2(x: int, y: int) -> float:
	var n: int = (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 10000) / 10000.0


## Листва: шар с тремя ступенями света, «рваным» краем и россыпью светлых и тёмных мазков.
static func foliage(img: Image, cx: float, cy: float, rx: float, ry: float, base: Color) -> void:
	var light := base.lightened(0.28)
	var mid_l := base.lightened(0.12)
	var dark := base.darkened(0.30)
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var nx := (x - cx) / rx
			var ny := (y - cy) / ry
			var r2 := nx * nx + ny * ny
			if r2 > 1.0 or (r2 > 0.78 and h2(x, y) < 0.3):
				continue
			var t := (nx * 0.8 + ny) * 0.5
			var c := base
			if t < -0.38:
				c = light
			elif t < -0.12:
				c = mid_l
			elif t > 0.36:
				c = dark
			var h := h2(x * 3, y * 7)
			if h < 0.09 and t < 0.25:
				c = c.lightened(0.14)
			elif h > 0.93 and t > -0.2:
				c = c.darkened(0.14)
			put(img, x, y, c)


static func ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var nx := (x - cx) / rx
			var ny := (y - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				put(img, x, y, col)


static var _shadow_cache := {}

## Мягкая тень под объектом: полупрозрачный эллипс (в 2D-пикселе допустима альфа тени).
static func shadow_tex(rx: int, ry: int) -> ImageTexture:
	var key := "%d_%d" % [rx, ry]
	if not _shadow_cache.has(key):
		var img := new_img(rx * 2 + 4, ry * 2 + 4)
		for y in img.get_height():
			for x in img.get_width():
				var nx := (x - img.get_width() * 0.5 + 0.5) / rx
				var ny := (y - img.get_height() * 0.5 + 0.5) / ry
				var r2 := nx * nx + ny * ny
				if r2 <= 1.0:
					img.set_pixel(x, y, Color(0.10, 0.16, 0.20, 0.34 if r2 < 0.55 else 0.20))
		_shadow_cache[key] = tex(img)
	return _shadow_cache[key]


## Размер тени (rx, ry) и сдвиг от точки опоры; солнце сверху-слева, тень падает вправо-вниз.
static func shadow_spec(kind: String) -> Array:
	match kind:
		"tree": return [26, 8, Vector2(8, 1)]
		"bush": return [14, 5, Vector2(3, 1)]
		"rock": return [15, 5, Vector2(3, 1)]
		"house": return [52, 11, Vector2(8, 0)]
		"barrel": return [10, 4, Vector2(2, 0)]
		"crate": return [10, 4, Vector2(2, 0)]
		"campfire": return [14, 5, Vector2(0, 1)]
		"torch": return [5, 2, Vector2(1, 0)]
		"fence_h": return [12, 3, Vector2(2, 0)]
		"fence_v": return [4, 2, Vector2(1, 0)]
	return []


# ---------- статика ----------

static func static_frames(kind: String, variant: int) -> SpriteFrames:
	match kind:
		"tree": return frames_from([tex(_tree(variant))])
		"bush": return frames_from([tex(_bush(variant))])
		"rock": return frames_from([tex(_rock(variant))])
		"house": return frames_from([tex(_house())])
		"bridge": return frames_from([tex(_bridge())])
		"campfire": return frames_from([tex(_campfire(0)), tex(_campfire(1)), tex(_campfire(2))], 7.0)
		"barrel": return frames_from([tex(_barrel())])
		"crate": return frames_from([tex(_crate())])
		"torch": return frames_from([tex(_torch(0)), tex(_torch(1))], 6.0)
		"grass": return frames_from([tex(_tuft(variant))])
		"flower": return frames_from([tex(_flower(variant))])
		"fence_h": return frames_from([tex(_fence(true))])
		"fence_v": return frames_from([tex(_fence(false))])
	return frames_from([tex(_crate())])


static func _trunk(img: Image, x0: int, y0: int, w: int, h: int, flare: int) -> void:
	for y in range(y0, y0 + h):
		var extra := 0
		if y > y0 + h - 5:
			extra = (y - (y0 + h - 5)) * flare / 4
		for x in range(x0 - extra, x0 + w + extra):
			var c := C_BARK
			if x < x0 + w * 0.3:
				c = C_BARK.lightened(0.2)
			elif x > x0 + w * 0.7:
				c = C_BARK.darkened(0.25)
			if h2(x, y / 3) < 0.12:
				c = c.darkened(0.2)
			put(img, x, y, c)


static func _tree(variant: int) -> Image:
	match variant % 4:
		0:   # дуб: широкая крона из нескольких шаров, ствол с корнями
			var img := new_img(76, 100)
			_trunk(img, 33, 52, 10, 44, 4)
			foliage(img, 38, 38, 32, 28, C_LEAF.darkened(0.12))
			foliage(img, 20, 46, 17, 14, C_LEAF.darkened(0.04))
			foliage(img, 56, 45, 18, 14, C_LEAF.darkened(0.04))
			foliage(img, 38, 30, 24, 20, C_LEAF)
			foliage(img, 27, 34, 14, 12, C_LEAF.lightened(0.08))
			foliage(img, 50, 29, 12, 10, C_LEAF.lightened(0.08))
			foliage(img, 38, 20, 14, 10, C_LEAF.lightened(0.14))
			outline(img)
			return img
		1:   # ель: ярусы с рваным краем
			var img := new_img(60, 112)
			_trunk(img, 27, 96, 6, 14, 2)
			for i in 4:
				var top := 4 + i * 22
				var h := 34
				var half_w := 11 + i * 5
				for y in h:
					var w := int(float(y) / h * half_w) + int(h2(i, y) * 2.0)
					for x in range(30 - w, 30 + w + 1):
						var side := float(x - 30) / maxf(w, 1)
						var c := C_LEAF.darkened(0.1)
						if side < -0.35:
							c = C_LEAF.lightened(0.15)
						elif side > 0.3:
							c = C_LEAF.darkened(0.32)
						if y > h - 4:
							c = c.darkened(0.25)
						elif h2(x, y) < 0.08:
							c = c.lightened(0.15)
						put(img, x, top + y, c)
			outline(img)
			return img
		2:   # берёза: белый ствол с чёрными метками, лёгкая светлая крона
			var img := new_img(52, 100)
			for y in range(40, 96):
				for x in range(23, 29):
					var c := Color("efebdd") if x < 26 else Color("c9c4b4")
					if h2(x, y / 4) < 0.12 and x > 23:
						c = Color("3a3a3a")
					put(img, x, y, c)
			foliage(img, 26, 28, 20, 26, Color("6fae48"))
			foliage(img, 16, 38, 11, 11, Color("6fae48").darkened(0.05))
			foliage(img, 36, 36, 11, 11, Color("6fae48").darkened(0.05))
			foliage(img, 26, 20, 12, 12, Color("6fae48").lightened(0.12))
			outline(img)
			return img
		_:   # сухое дерево
			var img := new_img(56, 80)
			var wood := Color("5a4636")
			for y in range(20, 78):
				for x in range(24, 31):
					put(img, x, y, wood.lightened(0.15) if x < 26 else (wood.darkened(0.2) if x > 28 else wood))
			for i in 16:
				for t in 3:
					put(img, 26 - i, 40 - i + t, wood)
					put(img, 29 + i, 30 - i * 2 / 3 + t, wood)
			for i in 9:
				put(img, 20 - i / 2, 28 - i, wood)
				put(img, 34 + i / 2, 20 - i, wood)
			outline(img)
			return img


static func _bush(variant: int) -> Image:
	var img := new_img(40, 28)
	foliage(img, 20, 16, 17, 10, Color("4d8f3f").darkened(0.05))
	foliage(img, 11, 18, 9, 7, Color("4d8f3f"))
	foliage(img, 29, 18, 9, 7, Color("4d8f3f"))
	foliage(img, 20, 11, 11, 7, Color("4d8f3f").lightened(0.1))
	if variant % 2 == 0:                                   # ягоды
		for p in [Vector2(14, 14), Vector2(24, 11), Vector2(30, 18), Vector2(18, 20), Vector2(9, 19)]:
			put(img, int(p.x), int(p.y), Color("d9443a"))
			put(img, int(p.x) + 1, int(p.y), Color("f06b52"))
	outline(img)
	return img


static func _rock(variant: int) -> Image:
	var img := new_img(44, 30)
	var rx := 15.0 + (variant % 3) * 2.0
	ellipse(img, 22, 19, rx, 8.0, C_STONE.darkened(0.3))          # передняя грань
	ellipse(img, 22, 17, rx - 1.0, 7.0, C_STONE.darkened(0.12))
	ellipse(img, 21, 11, rx - 3.0, 7.0, C_STONE.lightened(0.1))   # верх, свет сверху-слева
	ellipse(img, 19, 9, rx - 8.0, 4.0, C_STONE.lightened(0.28))
	for i in 5:                                                    # трещины и мох
		put(img, 24 + i, 15 + i / 2, C_STONE.darkened(0.4))
	for i in 6:
		put(img, 12 + i, 19, Color("5f8a3c"))
	outline(img)
	return img


static func _house() -> Image:
	var img := new_img(120, 116)
	# стена, доски, цоколь
	rect(img, 14, 62, 92, 50, Color("d8bf94"))
	for y in range(64, 108, 6):
		rect(img, 14, y, 92, 1, Color("bda274"))
	rect(img, 14, 62, 4, 50, Color("ecd9b4"))
	rect(img, 102, 62, 4, 50, Color("b69b6e"))
	rect(img, 12, 104, 96, 8, C_STONE.darkened(0.1))
	for x in range(14, 106, 9):
		rect(img, x, 104, 1, 8, C_STONE.darkened(0.35))
	# крыша: передний скат с рядами черепицы
	for y in 46:
		var w := 62 - int(y * 0.5)
		var shade := C_WARM.lightened(0.05) if y % 8 < 6 else C_WARM.darkened(0.25)
		rect(img, 60 - w, 14 + y, w * 2, 1, shade)
		if y % 8 < 6:
			for x in range(60 - w, 60 + w, 8):
				put(img, x + (4 if (y / 8) % 2 == 1 else 0), 14 + y, C_WARM.darkened(0.2))
	rect(img, 0, 58, 120, 4, C_WARM.darkened(0.35))                 # свес
	rect(img, 14, 62, 92, 3, Color(0.2, 0.15, 0.1, 0.55))           # тень под свесом
	# труба
	rect(img, 82, 2, 12, 26, C_STONE)
	rect(img, 82, 2, 3, 26, C_STONE.lightened(0.2))
	rect(img, 80, 0, 16, 4, C_STONE.darkened(0.2))
	# дверь с крыльцом
	rect(img, 48, 76, 22, 34, C_BARK.darkened(0.1))
	rect(img, 50, 78, 8, 30, C_BARK.lightened(0.1))
	put(img, 66, 94, Color("f4d36b"))
	rect(img, 44, 108, 30, 4, C_STONE.lightened(0.1))
	# окна со ставнями
	for wx in [24, 84]:
		rect(img, wx - 2, 74, 18, 20, Color("a07848"))
		rect(img, wx, 76, 14, 16, Color("7fb4d4"))
		rect(img, wx + 6, 76, 2, 16, Color("a07848"))
		rect(img, wx, 83, 14, 2, Color("a07848"))
		rect(img, wx, 76, 14, 4, Color("b8dcef"))
		rect(img, wx - 6, 74, 4, 20, Color("5f8a3c"))
		rect(img, wx + 16, 74, 4, 20, Color("5f8a3c"))
	outline(img)
	return img


static func _fence(horizontal: bool) -> Image:
	var wood := Color("b98a54")
	if horizontal:
		var img := new_img(24, 22)
		for px in [1, 21]:
			rect(img, px, 4, 3, 16, wood.darkened(0.1))
			rect(img, px, 4, 1, 16, wood.lightened(0.15))
			rect(img, px, 3, 3, 1, wood.lightened(0.3))
		rect(img, 0, 8, 24, 3, wood)
		rect(img, 0, 8, 24, 1, wood.lightened(0.2))
		rect(img, 0, 14, 24, 3, wood)
		rect(img, 0, 14, 24, 1, wood.lightened(0.2))
		outline(img)
		return img
	var img := new_img(8, 22)
	rect(img, 2, 4, 4, 16, wood.darkened(0.1))
	rect(img, 2, 4, 1, 16, wood.lightened(0.15))
	rect(img, 2, 3, 4, 1, wood.lightened(0.3))
	rect(img, 3, 9, 2, 3, wood)
	outline(img)
	return img


static func _bridge() -> Image:
	var img := new_img(208, 56)
	for x in range(6, 202, 7):                                      # настил: доски с чередованием тонов
		var c := Color("9a6c42") if (x / 7) % 2 == 0 else Color("8a5f3a")
		rect(img, x, 14, 6, 28, c)
		rect(img, x, 14, 6, 2, c.lightened(0.2))
	rect(img, 6, 40, 196, 3, Color("5c3b22"))
	rect(img, 6, 10, 196, 3, C_BARK)                                # задние перила
	rect(img, 6, 10, 196, 1, C_BARK.lightened(0.25))
	for x in range(8, 204, 36):
		rect(img, x, 4, 5, 14, C_BARK.darkened(0.1))
	rect(img, 6, 36, 196, 3, C_BARK.lightened(0.05))                # передние перила перекрывают настил
	rect(img, 6, 36, 196, 1, C_BARK.lightened(0.3))
	for x in range(8, 204, 36):
		rect(img, x, 30, 5, 20, C_BARK.darkened(0.05))
		rect(img, x, 30, 5, 2, C_BARK.lightened(0.3))
	outline(img)
	return img


static func _campfire(f: int) -> Image:
	var img := new_img(30, 34)
	for i in 3:
		rect(img, 6 + i * 2, 24 + i % 2, 16, 4, C_BARK.lightened(0.05 * i))
	for a in 8:
		var ang := a / 8.0 * TAU
		ellipse(img, 15 + cos(ang) * 11, 27 + sin(ang) * 4, 2.2, 1.8, C_STONE if a % 2 == 0 else C_STONE.darkened(0.2))
	var h := 14 + (f % 3) * 2
	for y in h:
		var w := int((1.0 - float(y) / h) * 6) + 1
		var c := C_WARM if y < h * 0.55 else Color("f4d36b")
		if y < 3:
			c = Color("c9531f")
		rect(img, 15 - w / 2 - (f % 2), 24 - y, w, 1, c)
	outline(img)
	return img


static func _barrel() -> Image:
	var img := new_img(22, 28)
	rect(img, 3, 6, 16, 18, Color("8a6240"))
	rect(img, 3, 6, 4, 18, Color("a67c52"))
	rect(img, 15, 6, 4, 18, Color("6b4a2f"))
	ellipse(img, 11, 24, 8, 3, Color("6b4a2f"))
	ellipse(img, 11, 6, 8, 3, Color("b58a5a"))
	ellipse(img, 11, 6, 5, 2, Color("9a7248"))
	rect(img, 3, 10, 16, 2, Color("4a4a4a"))
	rect(img, 3, 19, 16, 2, Color("4a4a4a"))
	outline(img)
	return img


static func _crate() -> Image:
	var img := new_img(22, 24)
	rect(img, 2, 8, 18, 14, Color("a07848"))                        # передняя грань
	for y in range(8, 22, 5):
		rect(img, 2, y, 18, 1, Color("7a5832"))
	for i in 14:
		put(img, 3 + i, 8 + i, Color("6b4a2f"))
	rect(img, 4, 3, 18, 5, Color("c9a06a"))                         # верхняя грань
	rect(img, 2, 8, 2, 14, Color("c49a64"))
	outline(img)
	return img


static func _torch(f: int) -> Image:
	var img := new_img(12, 34)
	rect(img, 5, 12, 3, 20, C_BARK)
	rect(img, 5, 12, 1, 20, C_BARK.lightened(0.2))
	rect(img, 4, 10, 5, 3, C_BARK.darkened(0.3))
	rect(img, 3 + f, 3, 6 - f, 8, C_WARM)
	rect(img, 5, 5, 2, 5, Color("f4d36b"))
	put(img, 6, 2, Color("f4d36b"))
	outline(img)
	return img


static func _tuft(variant: int) -> Image:
	var img := new_img(12, 14)
	var c := C_GRASS.darkened(0.08 * (variant % 3))
	for i in 6:
		var x := 1 + i * 2
		var hgt := 8 + (i * 5 + variant) % 5
		for y in hgt:
			put(img, x + int(float(y) / 5.0) * (1 if i % 2 == 0 else -1) * (i - 3) / 3, 13 - y, c.lightened(0.035 * y))
	return img


static func _flower(variant: int) -> Image:
	var cols := [Color("f4f0e0"), Color("f2d24a"), Color("e8789a"), Color("a98ad8"), Color("e0913a")]
	var col: Color = cols[variant % cols.size()]
	var img := new_img(12, 16)
	for y in range(6, 15):
		put(img, 6, y, Color("4d8f3f"))
	put(img, 5, 11, Color("4d8f3f"))
	put(img, 7, 9, Color("4d8f3f"))
	for p in [Vector2i(6, 4), Vector2i(4, 5), Vector2i(8, 5), Vector2i(5, 3), Vector2i(7, 3)]:
		put(img, p.x, p.y, col)
	put(img, 6, 5, Color("f4d36b"))
	put(img, 6, 4, col.lightened(0.2))
	return img


# ---------- животные (8 направлений, клипы idle/walk/run) ----------

const SPECS := {
	"hare": {"size": 24, "len": 7.0, "r": 3.5, "col": "b59a78", "head": 2.5, "legs": 2.0, "ears": true},
	"deer": {"size": 48, "len": 15.0, "r": 5.5, "col": "a87648", "head": 3.5, "legs": 6.0, "antlers": true},
	"fox": {"size": 32, "len": 10.0, "r": 4.0, "col": "d8782f", "head": 3.0, "legs": 3.0, "tail": true},
	"bird": {"size": 24, "len": 6.0, "r": 3.0, "col": "4a4a58", "head": 2.0, "legs": 0.0, "wings": true},
}


static func animal_frames(kind: String) -> SpriteFrames:
	var sp: Dictionary = SPECS.get(kind, SPECS["hare"])
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var clips := {"idle": [2, 3.0, 0.0], "walk": [4, 8.0, 1.0], "run": [4, 12.0, 2.0]}
	for clip in clips:
		var n: int = clips[clip][0]
		for di in 8:
			var anim: String = "%s_%s" % [clip, DIRS[di]]
			sf.add_animation(anim)
			sf.set_animation_speed(anim, clips[clip][1])
			sf.set_animation_loop(anim, true)
			for f in n:
				sf.add_frame(anim, tex(_animal_frame(sp, DIR_VEC[di].normalized(), f, n, clips[clip][2], kind == "bird")))
	return sf


static func _animal_frame(sp: Dictionary, v: Vector2, f: int, n: int, speed: float, fly: bool) -> Image:
	var size: int = sp.size
	var img := new_img(size, size)
	var cx := size * 0.5
	var ground := size * 0.78
	var r: float = sp.r
	var len_: float = sp.len
	var col := Color(sp.col)
	var phase := float(f) / n * TAU
	var bob := (absf(sin(phase)) * (1.5 if speed == 1.0 else 3.0) if speed > 0.5 else (1.0 if f % 2 == 1 else 0.0))
	var perp := Vector2(-v.y, v.x)
	var legs: float = sp.legs
	# тень на земле
	for y in range(-2, 3):
		for x in range(-int(len_ * 0.8), int(len_ * 0.8) + 1):
			if (x * x) / (len_ * len_ * 0.64) + (y * y) / 6.0 <= 1.0:
				put(img, int(cx) + x, int(ground) + y + (3 if fly else 0), Color(0.15, 0.28, 0.12, 1.0) if not fly else Color(0.25, 0.4, 0.2, 1.0))
	var base_y := ground - legs - r - bob - (6.0 if fly else 0.0)
	var centre := Vector2(cx, base_y)
	# ноги
	if legs > 0.0:
		for k in 4:
			var sgn := -1.0 if k % 2 == 0 else 1.0
			var along := (-0.35 if k < 2 else 0.35) * len_
			var swing := sin(phase + (PI if k % 2 == 0 else 0.0)) * (1.5 if speed == 1.0 else 3.0) if speed > 0.5 else 0.0
			var foot := centre + v * (along + swing) + perp * sgn * r * 0.6
			for yy in range(int(legs) + int(r)):
				put(img, int(foot.x), int(foot.y) + yy, col.darkened(0.35))
	# крылья птицы
	if sp.get("wings", false):
		var flap := sin(phase) * 3.0
		for s: float in [-1.0, 1.0]:
			for k in range(1, 7):
				var wp: Vector2 = centre + perp * s * k * 1.4 + Vector2(0, -flap * (k / 6.0))
				put(img, int(wp.x), int(wp.y), col.lightened(0.15))
				put(img, int(wp.x), int(wp.y) + 1, col.lightened(0.15))
	# тело: цепочка шаров вдоль курса
	var order := [-1.0, -0.4, 0.2, 0.6]
	if v.y < 0:
		order.reverse()
	for t: float in order:
		var p: Vector2 = centre + v * t * len_ * 0.5
		blob(img, p.x, p.y, r, r * 0.9, col)
	# хвост
	if sp.get("tail", false):
		var tp := centre - v * len_ * 0.75
		blob(img, tp.x, tp.y, r * 0.6, r * 0.6, Color("f2e6d2"))
	else:
		var tl := centre - v * len_ * 0.65
		put(img, int(tl.x), int(tl.y), col.lightened(0.35))
	# голова
	var hp := centre + v * len_ * 0.62 + Vector2(0, -r * 0.4)
	blob(img, hp.x, hp.y, sp.head, sp.head, col.lightened(0.1))
	if sp.get("ears", false):
		for s in [-1.0, 1.0]:
			put(img, int(hp.x + perp.x * s * 1.5), int(hp.y - 3 - 1), col)
			put(img, int(hp.x + perp.x * s * 1.5), int(hp.y - 4 - 1), col.lightened(0.2))
	if sp.get("antlers", false):
		for s in [-1.0, 1.0]:
			for k in 4:
				put(img, int(hp.x + (s * (1 + k)) * maxf(absf(perp.x), 0.4)), int(hp.y - 3 - k), Color("d9c9a0"))
	if v.y >= 0.0:                                         # глаз виден, когда смотрит к камере
		put(img, int(hp.x), int(hp.y), Color("1c1c1c"))
	outline(img)
	return img



## offset для AnimatedSprite2D: основание спрайта стоит на точке узла (земля).
## Статика: низ картинки на узле. Животные: «земля» рисуется на 0.78 высоты кадра.
static func foot_offset(sf: SpriteFrames, anim: String, animal: bool) -> Vector2:
	var h := float(sf.get_frame_texture(anim, 0).get_height())
	if animal:
		return Vector2(0, h * 0.5 - h * 0.78)
	return Vector2(0, -h * 0.5)
