extends Node

const MUNDO := preload("res://mundo3d.gd")

class EstadoRuta:
	var casillas: Dictionary = {}
	var criaturas: Dictionary = {}


class CatalogoRuta:
	func info_item(_cid: int) -> Dictionary:
		return {"bloquea": false}


var _fallas := 0


func _ready() -> void:
	var mundo = MUNDO.new()
	_comprobar("8 entradas de teclado", MUNDO.TECLAS_DIRECCION.size() == 8)
	_comprobar("W sin giro es norte",
		MUNDO._direccion_girada(Vector2i(0, -1), 0.0) == Vector2i(0, -1))
	_comprobar("D sin giro es este",
		MUNDO._direccion_girada(Vector2i(1, 0), 0.0) == Vector2i(1, 0))
	_comprobar("W a 45 grados cae en octante noroeste",
		MUNDO._direccion_girada(Vector2i(0, -1), 45.0) == Vector2i(-1, -1))
	_comprobar("diagonal noroeste usa opcode 0x6D",
		mundo._opcode_de_direccion(Vector2i(-1, -1)) == 0x6D)
	_comprobar("diagonal sureste usa opcode 0x6B",
		mundo._opcode_de_direccion(Vector2i(1, 1)) == 0x6B)
	_comprobar("map click calcula ruta sin diagonales", _probar_ruta_cardinal(mundo))
	print("Controles TVP3D: %d falla(s)" % _fallas)
	mundo.free()
	get_tree().quit(1 if _fallas > 0 else 0)


func _comprobar(nombre: String, correcto: bool) -> void:
	if correcto:
		print("  OK  " + nombre)
	else:
		print("  FAIL " + nombre)
		_fallas += 1


func _probar_ruta_cardinal(mundo) -> bool:
	var estado := EstadoRuta.new()
	mundo._estado = estado
	mundo._catalogo = CatalogoRuta.new()
	mundo._mapa_visible.clear()
	mundo._bloqueo_disco_cache.clear()
	for x in range(0, 4):
		for y in range(0, 3):
			mundo._mapa_visible[Vector3i(x, y, 7)] = PackedInt32Array([1])
	var ruta: Array = mundo._buscar_ruta(
		Vector3i(0, 0, 7), Vector3i(3, 2, 7), false)
	if ruta.size() != 5:
		return false
	for paso in ruta:
		if absi(paso.x) + absi(paso.y) != 1:
			return false
	return true
