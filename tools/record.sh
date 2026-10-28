#!/usr/bin/env bash
# Запись одного плана: MJPEG AVI (качество 0.95, project.godot) через --write-movie (30 fps, 1920x1080) во временную папку на D:,
# затем ffmpeg -> mp4 h264 crf 18 в shots/v3/, временные кадры удаляются.
#   bash tools/record.sh <сцена.tscn> <имя_клипа> <секунд> [аргументы сцены...]
# пример: bash tools/record.sh scenes/level_v3.tscn 3d_fly_a 75 --shot=fly_a
set -e
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
SCENE="$1"; NAME="$2"; SECS="$3"; shift 3
OUT="${OUTDIR:-$PROJ/shots/v3}"
mkdir -p "$OUT" "$PROJ/shots/v3/check"
TMP="${TMPDIR:-/tmp}/lvl_tmp/$(basename "$NAME")"
rm -rf "$TMP"; mkdir -p "$TMP"
FRAMES=$(python -c "print(int(round($SECS*30)))" 2>/dev/null || py -c "print(int(round($SECS*30)))")
cd "$PROJ"
"$GODOT" --path . --resolution 1920x1080 "$SCENE" --write-movie "$(cygpath -w "$TMP")\\f.avi" --fixed-fps 30 --quit-after "$FRAMES" -- "$@" > "$TMP/log.txt" 2>&1 || true
N=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$TMP/f.avi")
ffmpeg -y -loglevel error -i "$TMP/f.avi" -an -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p -movflags +faststart "$OUT/$NAME.mp4"
ffmpeg -y -loglevel error -ss "$(py -c "print($SECS*0.5)")" -i "$OUT/$NAME.mp4" -frames:v 1 "$PROJ/shots/v3/check/thumb_$(basename "$NAME").png"
echo "$NAME: $N кадров -> $OUT/$NAME.mp4"
grep -E "SCRIPT ERROR|ERROR:" "$TMP/log.txt" | sort | uniq -c | head -5 || true
rm -rf "$TMP"
