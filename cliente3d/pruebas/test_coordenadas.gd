extends Node

const COORD := preload("res://comun/coordenadas_tibia.gd")

var _fallas := 0


func _ready() -> void:
	var ancla := Vector3i(32369, 32241, 7)
	var casos := [
		Vector3i(32369, 32241, 7),
		Vector3i(32370, 32242, 6),
		Vector3i(32300, 32100, 0),
		Vector3i(32400, 32300, 15),
	]
	for original in casos:
		var mundo := COORD.tibia_a_mundo(original, ancla)
		var recuperada := COORD.mundo_a_tibia(mundo, ancla)
		_comprobar("round-trip %s" % original, recuperada == original)

	var esquina := Vector3i(32369, 32241, 7)
	_comprobar("ancla queda en origen", \
		COORD.tibia_a_mundo(esquina, ancla) == Vector3.ZERO)
	_comprobar("piso z=6 sube una unidad", \
		is_equal_approx(COORD.tibia_a_mundo(Vector3i(32369, 32241, 6), ancla).y, 1.0))
	_comprobar("chunk positivo", \
		COORD.chunk_de(Vector3i(32097, 32219, 7), 64) == Vector2i(501, 503))
	_comprobar("local de chunk", \
		COORD.local_de_chunk(Vector3i(32097, 32219, 7), 64) == Vector2i(33, 27))

	print("Coordenadas Tibia3D: %d falla(s)" % _fallas)
	get_tree().quit(1 if _fallas > 0 else 0)


func _comprobar(nombre: String, correcto: bool) -> void:
	if correcto:
		print("  OK  %s" % nombre)
	else:
		print("  MAL %s" % nombre)
		_fallas += 1
