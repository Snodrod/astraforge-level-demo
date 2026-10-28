# Копирует пакеты студии из ..\assets в level_demo\assets и пересобирает импорт Godot.
# Использование (из папки level_demo):  pwsh tools/sync_assets.ps1
# После этого сцены сами подставят ассеты по assets\manifest.json (см. scripts/populate.gd).
$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent $PSScriptRoot
$src  = Join-Path (Split-Path -Parent $proj) "assets"
$dst  = Join-Path $proj "assets"
$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
if (-not (Test-Path $src)) { Write-Host "Нет папки $src - ассетов ещё нет."; exit 0 }
robocopy $src $dst /E /NFL /NDL /NJH /NJS /NP | Out-Null
Write-Host "Скопировано: $src -> $dst"
& $godot --headless --path $proj --import 2>&1 | Select-Object -Last 5
& $godot --headless --path $proj --script scripts/populate_cli.gd
