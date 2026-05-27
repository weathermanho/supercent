extends Object
## Tiny key/value store backed by user://best.save. Best-effort: silent on failure.

const SAVE_PATH := "user://best.save"


static func load_best() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return 0
	var v: int = f.get_32()
	f.close()
	return v


static func save_best(best: int) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_32(best)
	f.close()
