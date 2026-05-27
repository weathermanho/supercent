extends ColorRect
## Full-screen flash. Call `flash(intensity, duration, warm)` to fire.
## warm=true tints toward sun (1.0, 0.85, 0.55), warm=false uses near-white.

var _t: float = 0.0
var _duration: float = 0.06
var _start_color: Color = Color(1.0, 0.85, 0.55, 0.0)


func _ready() -> void:
	color = Color(1.0, 1.0, 1.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0; anchor_top = 0.0; anchor_right = 1.0; anchor_bottom = 1.0
	offset_left = 0.0; offset_top = 0.0; offset_right = 0.0; offset_bottom = 0.0


func flash(intensity: float, duration: float, warm: bool = true) -> void:
	var base := Color(1.0, 0.85, 0.55) if warm else Color(1.0, 1.0, 0.95)
	_start_color = Color(base.r, base.g, base.b, clampf(intensity, 0.0, 1.0))
	_duration = maxf(duration, 0.001)
	_t = 0.0
	color = _start_color


func _process(delta: float) -> void:
	if color.a <= 0.0:
		return
	_t += delta
	var p: float = clampf(_t / _duration, 0.0, 1.0)
	color = Color(_start_color.r, _start_color.g, _start_color.b,
				  lerpf(_start_color.a, 0.0, p))
