extends Node
## Watches GameConfig.distance and decides:
##   - when the next building spawn should be replaced by a giant
##   - when weapon_stage should increment
## Owns no state besides "what thresholds have already fired".

var _giant_thresholds_fired: Array[int] = []
var _weapon_thresholds_fired: Array[int] = []


## Returns true at most once per giant threshold. Call from Main._construct_building().
func consume_giant_due() -> bool:
	var d: int = floori(GameConfig.distance)
	for thresh in GameConfig.giant_distance_thresholds:
		if d >= thresh and not (thresh in _giant_thresholds_fired):
			_giant_thresholds_fired.append(thresh)
			return true
	return false


## Increment weapon_stage when distance crosses thresholds. Call every frame.
func tick_weapon(delta: float) -> void:
	var d: int = floori(GameConfig.distance)
	for thresh in GameConfig.weapon_upgrade_distances:
		if d >= thresh and not (thresh in _weapon_thresholds_fired):
			_weapon_thresholds_fired.append(thresh)
			GameConfig.weapon_stage = mini(GameConfig.weapon_stage + 1, 3)


func reset() -> void:
	_giant_thresholds_fired.clear()
	_weapon_thresholds_fired.clear()
