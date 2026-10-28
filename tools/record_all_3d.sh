#!/usr/bin/env bash
# Все 3D-планы v3 подряд (см. отчёт). bash tools/record_all_3d.sh
cd "$(dirname "$0")/.."
R="bash tools/record.sh"
S=scenes/level_v3.tscn
$R scenes/timelapse_v3.tscn 01_timelapse_build 53
$R $S 02_fly_a_grand_tour 75 --shot=fly_a
$R $S 03_fly_b_river 60 --shot=fly_b_river
$R $S 04_fly_c_high_orbit 70 --shot=fly_c_high
$R $S 05_fly_d_low_meadow 65 --shot=fly_d_low
$R $S 10_cu_tree_wind 9 --shot=cu_tree_wind
$R $S 11_cu_water 9 --shot=cu_water
$R $S 12_cu_campfire 9 --shot=cu_campfire
$R $S 13_cu_house_smoke 9 --shot=cu_house_smoke
$R $S 14_cu_deer 10 --shot=cu_deer
$R $S 15_cu_fox 9 --shot=cu_fox
$R $S 16_cu_hare 9 --shot=cu_hare
$R $S 17_cu_birds 9 --shot=cu_birds
$R $S 18_cu_sparrow 8 --shot=cu_sparrow
$R $S 19_cu_bridge 9 --shot=cu_bridge
$R $S 30_cmp_3d 10 --shot=cmp_3d
