#!/usr/bin/env bash
# Переимпорт ассетов студии в level_demo одной командой (из папки level_demo):
#   bash tools/reimport_assets.sh            — пакеты + пиксель + проверки + пробные кадры
#   bash tools/reimport_assets.sh --probe    — то же и ещё пробные клипы (короткие, в shots/v3/probe/)
# Что делает:
#   1. читает ../assets/manifest.json; для каждого ассета со status "ok" (кроме tools/exclude.txt)
#      заново копирует godot_package и pixel (старые файлы ассета удаляются, чтобы не осталось v1);
#   2. tools/pixel_resample.py — пиксельные листы к одной сетке 16 px/м (assets_px/);
#   3. godot --import — импорт GLB и текстур;
#   4. tools/inspect_assets.gd — габариты, материалы, клипы -> shots/v3/check/assets_report.txt;
#   5. tools/stride_speed.gd — скорость шага по клипам -> assets/strides.json (сцены берут её сами);
#   6. tools/render_bridge_px.gd + pixel_resample.py --bridge — пиксельный мост поперёк русла;
#   7. --validate — раскладка для пикселя (assets_px/layout_3d.json) и проверка пролётов камер;
#   8. пробные кадры 3D и пикселя в shots/v3/check/ (+ пробные клипы с --probe).
set -e
cd "$(dirname "$0")/.."
PROJ="$(pwd)"
GODOT="${GODOT:-godot}"
CHECK="$PROJ/shots/v3/check"
mkdir -p "$CHECK"

echo "== 1. копирование пакетов по manifest.json"
py - "$PROJ" <<'PY'
import io, json, os, shutil, sys
proj = sys.argv[1]
src_root = os.path.join(os.path.dirname(proj), "assets")
man = json.load(io.open(os.path.join(src_root, "manifest.json"), encoding="utf-8"))
items = man["assets"] if isinstance(man, dict) else man
ex = set()
exf = os.path.join(proj, "tools", "exclude.txt")
if os.path.exists(exf):
    ex = {l.split("#")[0].strip() for l in io.open(exf, encoding="utf-8") if l.split("#")[0].strip()}
dst_root = os.path.join(proj, "assets")
done = []
for a in items:
    name = a.get("name") or a.get("id")
    if not name or name in ex or a.get("status", "ok") != "ok":
        continue
    pkg = a.get("godot_package") or os.path.join(src_root, name, "godot_package")
    pix = a.get("pixel_dir") or os.path.join(src_root, name, "pixel")
    if not os.path.isdir(pkg):
        print("  нет godot_package:", name)
        continue
    d = os.path.join(dst_root, name)
    shutil.rmtree(d, ignore_errors=True)
    shutil.copytree(pkg, os.path.join(d, "godot_package"))
    if os.path.isdir(pix):
        shutil.copytree(pix, os.path.join(d, "pixel"))
    done.append(name)
tex = os.path.join(src_root, "textures")
if os.path.isdir(tex):
    shutil.copytree(tex, os.path.join(dst_root, "textures"), dirs_exist_ok=True)
shutil.copy2(os.path.join(src_root, "manifest.json"), os.path.join(dst_root, "manifest.json"))
print("  скопировано ассетов:", len(done), "исключены:", sorted(ex))
PY

echo "== 2. пиксельные листы"
py tools/pixel_resample.py | tail -3

echo "== 3. импорт в Godot"
"$GODOT" --headless --path . --import > "$CHECK/import_log.txt" 2>&1 || true
grep -iE "error" "$CHECK/import_log.txt" | head -5 || true

echo "== 4. отчёт по ассетам"
"$GODOT" --headless --path . --script tools/inspect_assets.gd 2>/dev/null | grep -E "pos=" > "$CHECK/assets_report.txt" || true
wc -l < "$CHECK/assets_report.txt"

echo "== 5. скорость шага животных"
"$GODOT" --headless --path . --script tools/stride_speed.gd 2>/dev/null | grep -E "=>|strides" || true

echo "== 6. пиксельный мост"
"$GODOT" --path . --resolution 640x360 --script tools/render_bridge_px.gd > /dev/null 2>&1 || true
py tools/pixel_resample.py --bridge | tail -1

echo "== 7. раскладка и проверка камер"
"$GODOT" --headless --path . scenes/level_v3.tscn -- --validate 2>/dev/null | grep -E "^(fly|cu|bridge|map|cmp)" || true

echo "== 8. пробные кадры"
"$GODOT" --path . --resolution 1920x1080 scenes/level_v3.tscn -- \
  --stills=fly_c_high@20,fly_a@30,cu_tree_wind,cu_campfire,cu_house_smoke,cu_deer,cu_fox,cu_hare,cu_birds,cu_sparrow,bridge_upstream,bridge_downstream,bridge_east_end,bridge_west_end,cmp_3d \
  > /dev/null 2>&1 || true
for s in cmp_px px_walk px_cu_deer px_cu_fox px_cu_hare px_bridge_check; do
  "$GODOT" --path . --resolution 1920x1080 scenes/level_pixel_v3.tscn -- --stills=$s > /dev/null 2>&1 || true
done
echo "  кадры: $CHECK"

if [ "$1" = "--probe" ]; then
  echo "== пробные клипы (shots/v3/probe/)"
  bash tools/record_probe.sh
fi
echo "готово"
