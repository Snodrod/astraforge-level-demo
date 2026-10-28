extends OmniLight3D
## Мерцание света костра (сам огонь — эффект из пакета студии). Время — по кадрам, запись ровная.

var _base := 1.0
var _t := 0.0


func _ready() -> void:
	_base = light_energy
	_t = randf() * 10.0


func _process(d: float) -> void:
	_t += d
	light_energy = _base * (0.82 + 0.12 * sin(_t * 13.0) * sin(_t * 7.3 + 1.0) + 0.06 * sin(_t * 23.0))
