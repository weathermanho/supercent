extends Node
## Owns GameConfig.time_scale. Two effects:
##   - hitstop: drives time_scale to ~0 briefly.
##   - slowmo: drives time_scale to a fraction (e.g. 0.25) for a longer beat.
## Hitstop trumps slowmo when both are active (the shortest, sharpest is what
## you want to read as "impact").

const HITSTOP_SCALE := 0.05  # near-freeze, not zero so animation stays smooth

var _hitstop_left: float = 0.0
var _slowmo_left: float = 0.0
var _slowmo_scale: float = 1.0


func request_hitstop(duration: float) -> void:
	_hitstop_left = maxf(_hitstop_left, duration)


func request_slowmo(scale: float, duration: float) -> void:
	# A new slowmo replaces the old (don't accumulate — last director's intent wins).
	_slowmo_scale = scale
	_slowmo_left = duration


func _process(delta: float) -> void:
	# delta here is real seconds (Engine.time_scale untouched; we apply our own
	# scale to gameplay via GameConfig.time_scale, not to _process).
	if _hitstop_left > 0.0:
		_hitstop_left -= delta
		GameConfig.time_scale = HITSTOP_SCALE
	elif _slowmo_left > 0.0:
		_slowmo_left -= delta
		GameConfig.time_scale = _slowmo_scale
	else:
		GameConfig.time_scale = 1.0
