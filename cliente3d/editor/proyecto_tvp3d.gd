class_name ProyectoTVP3D
extends RefCounted

## Modelo editable del proyecto propio del editor.
## Guarda solo autoria: overrides de tiles y perfiles 3D. Las fuentes
## importadas permanecen fuera del archivo y nunca se modifican desde aqui.

const FORMATO := "tvp3d.project.v1"
const VERSION := 1
const MAX_HISTORIAL := 64
const TIPOS_TILE := 7
const PRIMITIVAS := ["auto", "flat", "card", "wall", "box"]

var _fuente: Dictionary = {}
var _tiles: Dictionary = {}
var _perfiles: Dictionary = {}
var _undo: Array = []
var _redo: Array = []


func _init() -> void:
	_nuevo()


func _nuevo() -> void:
	_fuente = {
		"mapa": "",
		"region": {
			"min_x": 0,
			"max_x": 0,
			"min_y": 0,
			"max_y": 0,
			"z": 7,
		},
	}
	_tiles.clear()
	_perfiles.clear()
	_undo.clear()
	_redo.clear()


func configurar_fuente(ruta_mapa: String, centro: Vector3i, radio: int = 18) -> void:
	_fuente = {
		"mapa": ruta_mapa,
		"region": {
			"min_x": centro.x - radio,
			"max_x": centro.x + radio,
			"min_y": centro.y - radio,
			"max_y": centro.y + radio,
			"z": centro.z,
		},
	}


func tipo_en(posicion: Vector3i) -> int:
	return int(_tiles.get(_clave(posicion), -1))


func perfil_en(item_id: int) -> Dictionary:
	var perfil: Variant = _perfiles.get(str(item_id), {})
	if typeof(perfil) != TYPE_DICTIONARY:
		return {}
	return perfil.duplicate(true)


func editar_tile(posicion: Vector3i, tipo: int) -> Dictionary:
	if posicion.z < 0 or posicion.z > 15:
		return _error("COORDENADA_Z_INVALIDA")
	if tipo < 0 or tipo >= TIPOS_TILE:
		return _error("TIPO_TILE_DESCONOCIDO")
	var clave := _clave(posicion)
	if int(_tiles.get(clave, -1)) == tipo:
		return {"ok": true, "error": "", "cambiado": false}
	_registrar_antes()
	_tiles[clave] = tipo
	_redo.clear()
	return {"ok": true, "error": "", "cambiado": true}


func editar_perfil(item_id: int, primitiva: String, alto: float,
		grosor: float) -> Dictionary:
	if item_id <= 0:
		return _error("ITEM_ID_INVALIDO")
	if not PRIMITIVAS.has(primitiva):
		return _error("PRIMITIVA_DESCONOCIDA")
	if alto < 0.10 or alto > 3.0 or grosor < 0.05 or grosor > 1.0:
		return _error("PARAMETRO_FUERA_DE_RANGO")
	_registrar_antes()
	_perfiles[str(item_id)] = {
		"primitive": primitiva,
		"height": snappedf(alto, 0.05),
		"thickness": snappedf(grosor, 0.05),
	}
	_redo.clear()
	return {"ok": true, "error": "", "cambiado": true}


func deshacer() -> Dictionary:
	if _undo.is_empty():
		return _error("HISTORIAL_VACIO")
	_redo.append(_estado())
	_aplicar_estado(_undo.pop_back())
	return {"ok": true, "error": ""}


func rehacer() -> Dictionary:
	if _redo.is_empty():
		return _error("REHACER_VACIO")
	_undo.append(_estado())
	_aplicar_estado(_redo.pop_back())
	return {"ok": true, "error": ""}


func guardar(ruta: String) -> Dictionary:
	if ruta.strip_edges().is_empty():
		return _error("PROYECTO_RUTA_INVALIDA")
	var archivo := _abrir_para_escritura(ruta)
	if archivo == null:
		return _error("PROYECTO_NO_ESCRIBIBLE")
	archivo.store_string(JSON.stringify(a_diccionario(), "\t"))
	return {"ok": true, "error": "", "ruta": ruta}


func exportar(ruta: String) -> Dictionary:
	return guardar(ruta)


func a_diccionario() -> Dictionary:
	var fuente := _fuente.duplicate(true)
	var region: Dictionary = fuente.get("region", {}).duplicate(true)
	for campo in ["min_x", "max_x", "min_y", "max_y", "z"]:
		if region.has(campo):
			region[campo] = int(region[campo])
	fuente["region"] = region
	var tiles: Array = []
	var claves_tiles: Array = _tiles.keys()
	claves_tiles.sort()
	for clave in claves_tiles:
		var partes: PackedStringArray = str(clave).split(",")
		tiles.append({
			"x": int(partes[0]),
			"y": int(partes[1]),
			"z": int(partes[2]),
			"tipo": int(_tiles[clave]),
		})

	var perfiles: Dictionary = {}
	var claves_perfiles: Array = _perfiles.keys()
	claves_perfiles.sort()
	for clave in claves_perfiles:
		perfiles[str(clave)] = _perfiles[clave].duplicate(true)
	return {
		"format": FORMATO,
		"version": VERSION,
		"source": fuente,
		"tiles": tiles,
		"profiles": perfiles,
	}


static func cargar_validado(ruta: String) -> Dictionary:
	var proyecto = load("res://editor/proyecto_tvp3d.gd").new()
	if not FileAccess.file_exists(ruta):
		return {"ok": false, "proyecto": proyecto, "error": "PROYECTO_ARCHIVO_AUSENTE"}
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return {"ok": false, "proyecto": proyecto, "error": "PROYECTO_ILEGIBLE"}
	var datos: Variant = JSON.parse_string(archivo.get_as_text())
	var validacion := _validar_documento(datos)
	if not bool(validacion.get("ok", false)):
		return {"ok": false, "proyecto": proyecto, "error": validacion["error"]}
	proyecto._fuente = datos["source"].duplicate(true)
	for tile in datos["tiles"]:
		var posicion := Vector3i(int(tile["x"]), int(tile["y"]), int(tile["z"]))
		proyecto._tiles[proyecto._clave(posicion)] = int(tile["tipo"])
	proyecto._perfiles = datos["profiles"].duplicate(true)
	return {"ok": true, "proyecto": proyecto, "error": ""}


static func _validar_documento(datos: Variant) -> Dictionary:
	if typeof(datos) != TYPE_DICTIONARY:
		return _error("PROYECTO_JSON_INVALIDO")
	if str(datos.get("format", "")) != FORMATO:
		return _error("PROYECTO_FORMATO_INVALIDO")
	if not _es_entero(datos.get("version", -1)) or int(datos.get("version", -1)) != VERSION:
		return _error("PROYECTO_VERSION_NO_SOPORTADA")
	var fuente_valor: Variant = datos.get("source", null)
	if typeof(fuente_valor) != TYPE_DICTIONARY:
		return _error("PROYECTO_FUENTE_INVALIDA")
	var fuente: Dictionary = fuente_valor
	if typeof(fuente.get("mapa", null)) != TYPE_STRING:
		return _error("PROYECTO_FUENTE_INVALIDA")
	var region_valor: Variant = fuente.get("region", null)
	if typeof(region_valor) != TYPE_DICTIONARY:
		return _error("PROYECTO_REGION_INVALIDA")
	var region: Dictionary = region_valor
	for campo in ["min_x", "max_x", "min_y", "max_y", "z"]:
		if not _es_entero(region.get(campo, null)):
			return _error("PROYECTO_REGION_INVALIDA")
	if int(region["z"]) < 0 or int(region["z"]) > 15 \
			or int(region["min_x"]) > int(region["max_x"]) \
			or int(region["min_y"]) > int(region["max_y"]):
		return _error("PROYECTO_REGION_INVALIDA")
	var tiles_valor: Variant = datos.get("tiles", null)
	if typeof(tiles_valor) != TYPE_ARRAY:
		return _error("PROYECTO_TILES_INVALIDOS")
	var vistos: Dictionary = {}
	for tile_valor in tiles_valor:
		if typeof(tile_valor) != TYPE_DICTIONARY:
			return _error("PROYECTO_TILE_INVALIDO")
		var tile: Dictionary = tile_valor
		for campo in ["x", "y", "z", "tipo"]:
			if not _es_entero(tile.get(campo, null)):
				return _error("PROYECTO_TILE_INVALIDO")
		if int(tile["z"]) < 0 or int(tile["z"]) > 15 \
				or int(tile["tipo"]) < 0 or int(tile["tipo"]) >= TIPOS_TILE:
			return _error("PROYECTO_TILE_INVALIDO")
		var clave := "%d,%d,%d" % [tile["x"], tile["y"], tile["z"]]
		if vistos.has(clave):
			return _error("PROYECTO_TILE_DUPLICADO")
		vistos[clave] = true
	var perfiles_valor: Variant = datos.get("profiles", null)
	if typeof(perfiles_valor) != TYPE_DICTIONARY:
		return _error("PROYECTO_PERFILES_INVALIDOS")
	for clave in perfiles_valor:
		if int(clave) <= 0:
			return _error("ITEM_ID_INVALIDO")
		var perfil_valor: Variant = perfiles_valor[clave]
		if typeof(perfil_valor) != TYPE_DICTIONARY:
			return _error("PROYECTO_PERFIL_INVALIDO")
		var perfil: Dictionary = perfil_valor
		if not PRIMITIVAS.has(str(perfil.get("primitive", ""))):
			return _error("PRIMITIVA_DESCONOCIDA")
		if not _es_numero(perfil.get("height", null)) \
				or not _es_numero(perfil.get("thickness", null)):
			return _error("PROYECTO_PERFIL_INVALIDO")
		var alto := float(perfil["height"])
		var grosor := float(perfil["thickness"])
		if alto < 0.10 or alto > 3.0 or grosor < 0.05 or grosor > 1.0:
			return _error("PARAMETRO_FUERA_DE_RANGO")
	return {"ok": true, "error": ""}


func _registrar_antes() -> void:
	_undo.append(_estado())
	if _undo.size() > MAX_HISTORIAL:
		_undo.pop_front()


func _estado() -> Dictionary:
	return {
		"source": _fuente.duplicate(true),
		"tiles": _tiles.duplicate(true),
		"profiles": _perfiles.duplicate(true),
	}


func _aplicar_estado(estado: Dictionary) -> void:
	_fuente = estado.get("source", {}).duplicate(true)
	_tiles = estado.get("tiles", {}).duplicate(true)
	_perfiles = estado.get("profiles", {}).duplicate(true)


func _clave(posicion: Vector3i) -> String:
	return "%d,%d,%d" % [posicion.x, posicion.y, posicion.z]


func _abrir_para_escritura(ruta: String) -> FileAccess:
	if ruta.begins_with("res://assets/proyectos/"):
		var assets := DirAccess.open("res://assets")
		if assets != null:
			assets.make_dir_recursive("proyectos")
	return FileAccess.open(ruta, FileAccess.WRITE)


static func _error(codigo: String) -> Dictionary:
	return {"ok": false, "error": codigo}


static func _es_entero(valor: Variant) -> bool:
	if typeof(valor) == TYPE_INT:
		return true
	if typeof(valor) == TYPE_FLOAT:
		return is_equal_approx(float(valor), round(float(valor)))
	return false


static func _es_numero(valor: Variant) -> bool:
	return typeof(valor) == TYPE_INT or typeof(valor) == TYPE_FLOAT
