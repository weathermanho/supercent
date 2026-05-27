extends ColorRect
## Full-screen white flash. Call `flash(intensity, duration)`.
## Sits in the HUD CanvasLayer and is initially fully transparent.

var _t: float = 0.0
var _duration: float = 0.06
var _start_alpha: float = 0.0


func _ready() -> void:
	color = Color(1.0, 1.0, 1.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0; anchor_top = 0.0; anchor_right = 1.0; anchor_bottom = 1.0
	offset_left = 0.0; offset_top = 0.0; offset_right = 0.0; offset_bottom = 0.0


func flash(intensity: float, duration: float) -> void:
	_start_alpha = clampf(intensity, 0.0, 1.0)
	_duration = maxf(duration, 0.001)
	_t = 0.0
	color.a = _start_alpha


func _process(delta: float) -> void:
	if color.a <= 0.0:
		return
	_t += delta
	var p: float = clampf(_t / _duration, 0.0, 1.0)
	color.a = lerpf(_start_alpha, 0.0, p)
