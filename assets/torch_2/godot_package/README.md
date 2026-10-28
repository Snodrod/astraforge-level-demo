# torch_2 — пакет Godot 4.5 (AstraForge Forge)

Профиль: `godot`. Создан шагом `godot_package`; в целевой проект ничего не записано.

## Состав

| Файл | Что |
|---|---|
| `torch_2.glb` | модель (байт-в-байт копия входного GLB) |
| `torch_2.tscn` | сцена: `Node3D` + экземпляр GLB (`model`) + скрипт `af_fx_mount.gd` |
| `af_fx_mount.gd` | на `_ready` находит сокеты по `extras.game_socket` или имени и ставит FX |
| `fx/*.tscn` | эффекты: `GPUParticles3D` + `ParticleProcessMaterial` + `QuadMesh` |
| `fx/textures/*.png` | процедурные текстуры частиц (белые, форма в альфе) |
| `sprites/` | листы спрайтов и `SpriteFrames` из `render_sprites` |

## Оси

- GLB смотрит в `+Z` (glTF/Godot; источник: manifest kind item). Персонажи по контракту AstraForge смотрят в +Z glTF, корабли Space Quest — в −Z.
- Сцена `torch_2.tscn` смотрит в `+Z`.
- FX излучают вдоль локальной +Y сокета (= +Z сокета в Blender: «наружу», выхлоп, клинок); `muzzle_flash` — вдоль −Z (дуло Space Quest). Исключение — сокеты сопел (`socket_thruster_*`): у кораблей рамка сопла разная (`extras.frame` = `thrust`, `exhaust`, `sq_legacy` или её нет), поэтому `af_fx_mount.gd` поворачивает узел FX так, чтобы его +Y легла на ось выхлопа сокета (`emit_axis`, в осях сокета: из `extras.frame`, если она сходится с геометрией, иначе локальная ось, смотрящая назад от носа).

## Сокеты

- `socket_fx_tip`, kind `fx`
- `socket_grip_main`, kind `grip`

## Эффекты

Пресеты метрические; масштаб под ассет (длинная ось 0.6317 м): k и откуда он взят.

- `fire` → `socket_fx_tip` (узел `fx_fire`, сцена `fx/fire.tscn`; k = 0.351 — asset longest axis 0.632 m / preset 1.8 m; частица 0.1228 м)

## Анимации

- нет

## Как подключить

1. Скопировать папку `torch_2/` в любой каталог проекта (пути внутри относительные).
2. Инстанцировать `torch_2.tscn`; одноразовые FX (`muzzle_flash`) запускать `trigger("<сокет>")`.
3. Импорт Godot 4.5: суффикс `-loop` снимается, режим цикла ставится сам.

## Проверка в Godot 4.5.1.stable.official.f62fdbde1 (headless)

- сцена загружена: True, экземпляр: True
- сокеты найдены: 2 из 2
- FX прикреплены: 1 из 1
- анимации: 
- ошибок движка: 0
