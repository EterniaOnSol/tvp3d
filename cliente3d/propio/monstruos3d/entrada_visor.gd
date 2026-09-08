extends Node

var destino: Callable


func _input(event: InputEvent) -> void:
	if destino.is_valid():
		destino.call(event)
