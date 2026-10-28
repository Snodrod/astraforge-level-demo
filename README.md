# AstraForge — игровой уровень с нуля (демо-проект Godot 4.5)

Проект-пример из видеоинструкции канала **MyWay** «Игровой уровень с нуля в AstraForge».
Живой лесной уровень: земля и река, деревья на ветру, трава, камни, домик с дымом, мост,
костёр, олень, лиса, заяц и птицы. Тот же уровень собран в двух стилях: стилизованное 3D
и пиксель-арт с видом сверху. Все 3D-ассеты сделаны в бесплатной студии
[AstraForge](https://github.com/Snodrod/AstraForge) на локальной видеокарте.

*English below.*

## Как открыть

1. Установи [Godot 4.5.1](https://godotengine.org/download) (проект проверен на этой версии).
2. Скачай репозиторий (Code → Download ZIP или `git clone`).
3. В Godot: Import → выбери `project.godot`. Первый импорт ассетов занимает пару минут.
4. Запусти (F5): откроется `scenes/level_v3.tscn` — 3D-уровень.

## Что внутри

| Папка | Что там |
|---|---|
| `scenes/` | `level_v3.tscn` — 3D-уровень, `level_pixel_v3.tscn` — пиксельная версия, `timelapse_v3.tscn` — сборка уровня из пустой сцены, `empty.tscn` — пустая сцена из начала ролика |
| `shaders/` | вода с рябью, пеной и френелем, ветер для травы и листвы, небо, рельеф, 2D-ветер и 2D-вода |
| `scripts/` | блуждание животных (`wander.gd`, `wander_2d.gd`), полёт птиц, рельеф и река, расстановка ассетов по `assets/manifest.json` (`populate.gd`), режиссёр камер |
| `assets/` | 32 ассета AstraForge пакетами для Godot + пиксельные листы спрайтов (8 направлений у животных), бесшовные текстуры земли и воды |
| `tools/` | переимпорт ассетов и запись кадров без окна (`bash tools/reimport_assets.sh`, `tools/record.sh`); путь к Godot — переменная `GODOT` |

Скорость шага животных берётся из их клипов (`assets/strides.json`), поэтому лапы не скользят.
Свои ассеты из AstraForge подставляются заменой папок в `assets/` и записей в `manifest.json`.

## Честно о качестве

Модели сделаны генеративными нейросетями прямо на домашней видеокарте, а не одним промптом
в облаке. Косяки есть: местами плывут текстуры, у части моделей кривоватая покраска.
Любую модель можно поправить руками в студии или в Blender — для этого проект и открыт.

## Ссылки

- Студия AstraForge (бесплатно, MIT): https://github.com/Snodrod/AstraForge/releases/latest
- Подписка на обновления студии: https://snodrod.github.io/AstraForge/#subscribe
- Канал MyWay: https://www.youtube.com/@MywayDorn
- Поддержать автора: https://dalink.to/artemdorn

## Лицензия

Код, сцены и шейдеры — MIT (см. `LICENSE`). Ассеты сгенерированы локально моделями
Hunyuan3D-2 и Stable Diffusion XL; используя их в своём проекте, учитывай лицензии этих моделей.

---

## English

Demo project from the MyWay video tutorial "A game level from scratch in AstraForge".
A living forest level (terrain and river, trees in the wind, grass, rocks, a cottage with chimney
smoke, a bridge, a campfire, a deer, a fox, a hare and birds), built twice: stylized 3D and
top-down pixel art. All 3D assets were made with the free local studio
[AstraForge](https://github.com/Snodrod/AstraForge).

**Open:** install Godot 4.5.1 → Import → `project.godot` → run (F5), the main scene is
`scenes/level_v3.tscn`. Pixel version: `scenes/level_pixel_v3.tscn`; build timelapse:
`scenes/timelapse_v3.tscn`.

**Inside:** water, wind, sky and terrain shaders; animal wandering scripts with stride speed taken
from the clips; asset placement from `assets/manifest.json`; 32 AstraForge asset packages and
pixel sprite sheets.

**Honest note:** the assets were generated on a home GPU, so some textures and paint jobs are
rough. Everything can be fixed by hand.

**License:** code, scenes and shaders — MIT. Assets were generated locally with Hunyuan3D-2 and
Stable Diffusion XL; check those models' licenses before using the assets.
