extends Node
## Точка входа: всё остальное живёт в автозагрузках (Game, UI, Au, Story).

func _ready() -> void:
	Game.boot()
