# house — пакет Godot 4.5 (AstraForge Forge)

Профиль: `godot`. Создан шагом `godot_package`; в целевой проект ничего не записано.

## Состав

| Файл | Что |
|---|---|
| `house.glb` | модель (байт-в-байт копия входного GLB) |
| `house.tscn` | сцена: `Node3D` + экземпляр GLB (`model`) + скрипт `af_fx_mount.gd` |
| `af_fx_mount.gd` | на `_ready` находит сокеты по `extras.game_socket` или имени и ставит FX |
| `fx/*.tscn` | эффекты: `GPUParticles3D` + `ParticleProcessMaterial` + `QuadMesh` |
| `fx/textures/*.png` | процедурные текстуры частиц (белые, форма в альфе) |

## Оси

- GLB смотрит в `-Z` (glTF/Godot; источник: manifest kind prop). Персонажи по контракту AstraForge смотрят в +Z glTF, корабли Space Quest — в −Z.
- Сцена `house.tscn` смотрит в `-Z`.
- FX излучают вдоль локальной +Y сокета (= +Z сокета в Blender: «наружу», выхлоп, клинок); `muzzle_flash` — вдоль −Z (дуло Space Quest). Исключение — сокеты сопел (`socket_thruster_*`): у кораблей рамка сопла разная (`extras.frame` = `thrust`, `exhaust`, `sq_legacy` или её нет), поэтому `af_fx_mount.gd` поворачивает узел FX так, чтобы его +Y легла на ось выхлопа сокета (`emit_axis`, в осях сокета: из `extras.frame`, если она сходится с геометрией, иначе локальная ось, смотрящая назад от носа).

## Сокеты

- `socket_fx_chimney`

## Эффекты

Пресеты метрические; масштаб под ассет (длинная ось 4.4122 м): k и откуда он взят.

- `smoke` → `socket_fx_chimney` (узел `fx_smoke`, сцена `fx/smoke.tscn`; k = 1.47 — asset longest axis 4.41 m / preset 3 m; частица 1.323 м)

## Анимации

- нет

## Как подключить

1. Скопировать папку `house/` в любой каталог проекта (пути внутри относительные).
2. Инстанцировать `house.tscn`; одноразовые FX (`muzzle_flash`) запускать `trigger("<сокет>")`.
3. Импорт Godot 4.5: суффикс `-loop` снимается, режим цикла ставится сам.

## Проверка в Godot 4.5.1.stable.official.f62fdbde1 (headless)

- сцена загружена: True, экземпляр: True
- сокеты найдены: 1 из 1
- FX прикреплены: 1 из 1
- анимации: 
- ошибок движка: 0


## v2 (28.10)
Модель перекрашена со всех сторон (8 видов x2 прохода, SDXL img2img + обратная проекция). 
