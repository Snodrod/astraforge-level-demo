# crow — пакет Godot 4.5 (AstraForge Forge)

Профиль: `godot`. Создан шагом `godot_package`; в целевой проект ничего не записано.

## Состав

| Файл | Что |
|---|---|
| `crow.glb` | модель (байт-в-байт копия входного GLB) |
| `crow.tscn` | сцена: `Node3D` + экземпляр GLB (`model`) + скрипт `af_fx_mount.gd` |
| `af_fx_mount.gd` | на `_ready` находит сокеты по `extras.game_socket` или имени и ставит FX |
| `fx/*.tscn` | эффекты: `GPUParticles3D` + `ParticleProcessMaterial` + `QuadMesh` |
| `fx/textures/*.png` | процедурные текстуры частиц (белые, форма в альфе) |

## Оси

- GLB смотрит в `+Z` (glTF/Godot; источник: manifest kind creature). Персонажи по контракту AstraForge смотрят в +Z glTF, корабли Space Quest — в −Z.
- Сцена `crow.tscn` смотрит в `+Z`.
- FX излучают вдоль локальной +Y сокета (= +Z сокета в Blender: «наружу», выхлоп, клинок); `muzzle_flash` — вдоль −Z (дуло Space Quest). Исключение — сокеты сопел (`socket_thruster_*`): у кораблей рамка сопла разная (`extras.frame` = `thrust`, `exhaust`, `sq_legacy` или её нет), поэтому `af_fx_mount.gd` поворачивает узел FX так, чтобы его +Y легла на ось выхлопа сокета (`emit_axis`, в осях сокета: из `extras.frame`, если она сходится с геометрией, иначе локальная ось, смотрящая назад от носа).

## Сокеты

- `socket_fx_head` (кость `head`), kind `fx`
- `socket_fx_mouth` (кость `head`), kind `fx`
- `socket_fx_tail` (кость `tail_03`), kind `fx`
- `socket_mount_back` (кость `spine_02`), kind `mount`

## Эффекты

Пресеты метрические; масштаб под ассет (длинная ось 0.5569 м): k и откуда он взят.

- нет

## Анимации

- `fly-loop` → в Godot `fly`, зациклена (суффикс `-loop`)
- `glide-loop` → в Godot `glide`, зациклена (суффикс `-loop`)
- `idle-loop` → в Godot `idle`, зациклена (суффикс `-loop`)

## Как подключить

1. Скопировать папку `crow/` в любой каталог проекта (пути внутри относительные).
2. Инстанцировать `crow.tscn`; одноразовые FX (`muzzle_flash`) запускать `trigger("<сокет>")`.
3. Импорт Godot 4.5: суффикс `-loop` снимается, режим цикла ставится сам.

## Проверка в Godot 4.5.1.stable.official.f62fdbde1 (headless)

- сцена загружена: True, экземпляр: True
- сокеты найдены: 4 из 4
- FX прикреплены: 0 из 0
- анимации: fly loop_mode=1, glide loop_mode=1, idle loop_mode=1
- ошибок движка: 0


## v2 (28.10)
Модель перекрашена со всех сторон (8 видов x2 прохода, SDXL img2img + обратная проекция). Скелет и клипы собраны вручную (Blender bpy).
