extends Node
## Progress that outlives a session (autoloaded as Game): your coins, so far. Saved to
## user://save.json whenever it changes (batched) and on quit.

signal coins_changed(total: int, delta: int)

const SAVE_PATH := "user://save.json"
const SAVE_DELAY := 2.0

var coins := 0
var _save_in := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins, amount)
	if _save_in < 0.0:
		_save_in = SAVE_DELAY  # coins come in bursts; write once after the burst


func _process(delta: float) -> void:
	if _save_in >= 0.0:
		_save_in -= delta
		if _save_in < 0.0:
			save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _save_in >= 0.0:
			save()


func save() -> void:
	_save_in = -1.0
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"coins": coins}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		coins = int(data.get("coins", 0))
