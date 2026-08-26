extends Node3D

## Mapper runtime de una casa del inventario OTBM.
##
## Lee la huella completa de la casa, conserva las coordenadas Tibia y
## coloca modelos 3D por categoria. La geometria no se infiere de una
## captura: house_tiles.jsonl contiene cada SQM, sus pisos e items.

const COORD := preload("res://comun/coordenadas_tibia.gd")
const MODELOS := preload("res://mundo/catalogo_modelos_3d.gd")

const ARCHIVO_CASAS := "res://generated/world_mapper/houses.json"
const ARCHIVO_TILES := "res://generated/world_mapper/house_tiles.jsonl"

var _catalogo := MODELOS.new()
var _nodo_modelos := Node3D.new()
var _house_id := -1
var _info: Dictionary = {}
var _ancla := Vector3i.ZERO
var _objetos: Array = []
var _posiciones: Dictionary = {}
var _categorias: Dictionary = {}
var _conteos: Dictionary = {}


func _ready() -> void:
	add_child(_nodo_modelos)


func cargar_casa(house_id: int) -> bool:
	_limpiar()
	var casas = _leer_json(ARCHIVO_CASAS)
	if typeof(casas) != TYPE_ARRAY:
		push_error("House mapper: invalid houses.json")
		return false
	for candidata in casas:
		if int(candidata.get("house_id", -1)) == house_id:
			_info = candidata
			break
	if _info.is_empty():
		push_error("House mapper: house %d not found" % house_id)
		return false

	_house_id = house_id
	var entrada: Dictionary = _info.get("entry", {})
	_ancla = Vector3i(int(entrada.get("x", _info["min"]["x"])),
		int(entrada.get("y", _info["min"]["y"])), 7)

	var archivo := FileAccess.open(ARCHIVO_TILES, FileAccess.READ)
	if archivo == null:
		push_error("House mapper: missing " + ARCHIVO_TILES)
		return false
	while true:
		var linea := archivo.get_line()
		# FileAccess marca EOF despues de intentar leer mas alla de la
		# ultima linea. El corte explicito evita que un JSONL terminado en
		# salto de linea deje el visor girando para siempre.
		if archivo.eof_reached() and linea.is_empty():
			break
		if linea.is_empty():
			continue
		var tile = JSON.parse_string(linea)
		if typeof(tile) != TYPE_DICTIONARY or int(tile.get("house_id", -1)) != house_id:
			continue
		var p: Dictionary = tile.get("position", {})
		var posicion := Vector3i(int(p.get("x", 0)), int(p.get("y", 0)), int(p.get("z", 7)))
		_posiciones[posicion] = true
		for objeto in tile.get("objects", []):
			var copia: Dictionary = objeto.duplicate(true)
			copia["position"] = posicion
			_objetos.append(copia)
			var categoria := str(copia.get("category", "decoration")).to_lower()
			_categorias[posicion] = _categorias.get(posicion, [])
			_categorias[posicion].append(categoria)
			_conteos[categoria] = int(_conteos.get(categoria, 0)) + 1
	archivo.close()

	for objeto in _objetos:
		_colocar_objeto(objeto)
	return not _objetos.is_empty()


func _limpiar() -> void:
	for hijo in _nodo_modelos.get_children():
		hijo.queue_free()
	_house_id = -1
	_info = {}
	_objetos.clear()
	_posiciones.clear()
	_categorias.clear()
	_conteos.clear()


func _leer_json(ruta: String):
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return null
	var resultado = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	return resultado


func _colocar_objeto(objeto: Dictionary) -> void:
	var posicion: Vector3i = objeto["position"]
	var categoria := str(objeto.get("category", "decoration")).to_lower()
	var nombre := str(objeto.get("name", "unknown"))
	var client_id := int(objeto.get("client_id", 0))
	var orientacion := _orientacion_de(posicion, categoria)
	var modelo := _catalogo.crear_modelo(categoria, nombre, orientacion, client_id)
	modelo.position = COORD.tibia_a_mundo(posicion, _ancla)
	modelo.name = "%s_%d_%d_%d_%d" % [categoria, client_id, posicion.x, posicion.y, posicion.z]
	modelo.set_meta("house_id", _house_id)
	modelo.set_meta("tibia_position", posicion)
	modelo.set_meta("source_object", objeto)
	if bool(modelo.get_meta("solid", false)):
		_anadir_colision(modelo, Vector3(modelo.get_meta("collision_size")))
	_nodo_modelos.add_child(modelo)


func _orientacion_de(posicion: Vector3i, categoria: String) -> String:
	if categoria not in ["wall", "window", "door", "sign"]:
		return "x"
	var horizontal := _tiene_categoria(posicion + Vector3i(-1, 0, 0), categoria) \
		or _tiene_categoria(posicion + Vector3i(1, 0, 0), categoria)
	var vertical := _tiene_categoria(posicion + Vector3i(0, -1, 0), categoria) \
		or _tiene_categoria(posicion + Vector3i(0, 1, 0), categoria)
	if vertical and not horizontal:
		return "z"
	return "x"


func _tiene_categoria(posicion: Vector3i, categoria: String) -> bool:
	for valor in _categorias.get(posicion, []):
		if valor == categoria or (categoria == "door" and valor == "wall") \
				or (categoria == "window" and valor == "wall"):
			return true
	return false


func _anadir_colision(modelo: Node3D, tamano: Vector3) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Collision"
	var shape := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tamano
	shape.shape = caja
	shape.position.y = tamano.y * 0.5
	cuerpo.add_child(shape)
	modelo.add_child(cuerpo)


func house_id() -> int:
	return _house_id


func house_info() -> Dictionary:
	return _info


func anchor() -> Vector3i:
	return _ancla


func world_center() -> Vector3:
	if _info.is_empty():
		return Vector3.ZERO
	var minimo: Dictionary = _info.get("min", {})
	var maximo: Dictionary = _info.get("max", {})
	var centro := Vector3i(
		(int(minimo.get("x", _ancla.x)) + int(maximo.get("x", _ancla.x))) / 2,
		(int(minimo.get("y", _ancla.y)) + int(maximo.get("y", _ancla.y))) / 2,
		7)
	return COORD.tibia_a_mundo(centro, _ancla)


func object_count() -> int:
	return _objetos.size()


func category_counts() -> Dictionary:
	return _conteos.duplicate()
