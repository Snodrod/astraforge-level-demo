#!/usr/bin/env bash
# Пробные клипы (короткие) после переимпорта: shots/v3/probe/. Финальные — tools/record_all_3d.sh и record_all_px.sh.
cd "$(dirname "$0")/.."
export OUTDIR="$(pwd)/shots/v3/probe"
R="bash tools/record.sh"
S=scenes/level_v3.tscn
P=scenes/level_pixel_v3.tscn
$R $S p_fly_a 12 --shot=fly_a
$R $S p_cu_deer 6 --shot=cu_deer
$R $S p_cu_hare 6 --shot=cu_hare
$R $S p_cu_birds 6 --shot=cu_birds
$R $S p_cu_bridge 6 --shot=cu_bridge
$R $P p_px_walk 10 --shot=px_walk
$R $P p_px_cu_hare 6 --shot=px_cu_hare
