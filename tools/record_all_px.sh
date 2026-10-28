#!/usr/bin/env bash
# Пиксельные планы v3 + сравнение 3D/пиксель + контактный лист.  bash tools/record_all_px.sh
cd "$(dirname "$0")/.."
R="bash tools/record.sh"
P=scenes/level_pixel_v3.tscn
$R $P 40_px_overview 16 --shot=px_overview
$R $P 41_px_walk 45 --shot=px_walk
$R $P 42_px_cu_deer 9 --shot=px_cu_deer
$R $P 43_px_cu_fox 9 --shot=px_cu_fox
$R $P 44_px_cu_hare 9 --shot=px_cu_hare
$R $P 45_px_cu_camp 9 --shot=px_cu_camp
$R $P 31_cmp_px 10 --shot=cmp_px
# шторка: слева 3D, справа пиксель, граница плавно уезжает слева направо и обратно
ffmpeg -y -loglevel error -i shots/v3/30_cmp_3d.mp4 -i shots/v3/31_cmp_px.mp4 -filter_complex \
 "[0:v][1:v]blend=all_expr='if(lte(X,W*(0.5+0.4*sin(2*PI*T/10))),A,B)'[v]" -map "[v]" \
 -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p -movflags +faststart shots/v3/32_cmp_wipe.mp4
py tools/contact_sheet_v3.py
