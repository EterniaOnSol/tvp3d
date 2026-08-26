class_name MapaTVP3D
extends RefCounted

## Mapa comun para servidor, cliente y editor.
## Las coordenadas externas conservan el formato de Tibia (x, y, z),
## mientras que el archivo usa coordenadas locales pequenas.

enum Tipo {
	SUELO = 0,
	PARED = 1,
	AGUA = 2,
	ARBOL = 3,
	ROCA = 4,
	DECORACION = 5,
	ESCALERA = 6,
}

const VERSION := 1
const ORIGEN_POR_DEFECTO := Vector3i(32085, 32210, 7)
const ANCHO_POR_DEFECTO := 25
const ALTO_POR_DEFECTO := 17
const RUTA_MAPA := "user://mapa_tvp3d.json"

var origen := ORIGEN_POR_DEFECTO
var ancho := ANCHO_POR_DEFECTO
var alto := ALTO_POR_DEFECTO
var _celdas: Dictionary = {}
var ultimo_error := ""


func _init() -> void:
	crear_demo()


static func cargar(ruta: String = RUTA_MAPA) -> MapaTVP3D:
	var resultado := cargar_validado(ruta)
	if bool(resultado.get("ok", false)):
		return resultado["mapa"]
	# Preserve the original convenience API for the offline demo, but expose
	# the reason so callers can report it instead of silently accepting data.
	var fallback := MapaTVP3D.new()
	fallback.ultimo_error = str(resultado.get("error", "MAPA_INVALIDO"))
	return fallback


static func cargar_validado(ruta: String = RUTA_MAPA) -> Dictionary:
	var mapa := MapaTVP3D.new()
	mapa.ultimo_error = ""
	if not FileAccess.file_exists(ruta):
		return _resultado_error(mapa, "MAPA_ARCHIVO_AUSENTE")

	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return _resultado_error(mapa, "MAPA_ARCHIVO_ILEGIBLE")
	var datos: Variant = JSON.parse_string(archivo.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY:
		return _resultado_error(mapa, "MAPA_JSON_INVALIDO")

	var version := int(datos.get("version", -1))
	if version != VERSION:
		return _resultado_error(mapa, "MAPA_VERSION_NO_SOPORTADA")
	var origen_datos: Variant = datos.get("origen", null)
	if typeof(origen_datos) != TYPE_DICTIONARY:
		return _resultado_error(mapa, "MAPA_ORIGEN_INVALIDO")
	if int(origen_datos.get("z", -1)) < 0 or int(origen_datos.get("z", -1)) > 15:
		return _resultado_error(mapa, "COORDENADA_Z_INVALIDA")
	var ancho_datos := int(datos.get("ancho", -1))
	var alto_datos := int(datos.get("alto", -1))
	if ancho_datos < 3 or ancho_datos > 128 or alto_datos < 3 or alto_datos > 128:
		return _resultado_error(mapa, "MAPA_DIMENSION_INVALIDA")
	var celdas: Variant = datos.get("celdas", null)
	if typeof(celdas) != TYPE_ARRAY or celdas.is_empty():
		return _resultado_error(mapa, "MAPA_SIN_CELDAS")

	var vistas: Dictionary = {}
	for celda in celdas:
		if typeof(celda) != TYPE_DICTIONARY:
			return _resultado_error(mapa, "MAPA_CELDA_INVALIDA")
		var x := int(celda.get("x", -1))
		var y := int(celda.get("y", -1))
		var tipo := int(celda.get("tipo", -1))
		if x < 0 or x >= ancho_datos or y < 0 or y >= alto_datos:
			return _resultado_error(mapa, "MAPA_CELDA_FUERA_DE_RANGO")
		if not es_tipo_valido(tipo):
			return _resultado_error(mapa, "TIPO_TILE_DESCONOCIDO")
		var clave := "%d,%d" % [x, y]
		if vistas.has(clave):
			return _resultado_error(mapa, "MAPA_CELDA_DUPLICADA")
		vistas[clave] = true

	mapa._cargar_diccionario(datos)
	return {"ok": true, "mapa": mapa, "error": ""}


func crear_demo() -> void:
	origen = ORIGEN_POR_DEFECTO
	ancho = ANCHO_POR_DEFECTO
	alto = ALTO_POR_DEFECTO
	_celdas.clear()
	for y in range(alto):
		for x in range(ancho):
			var tipo := Tipo.SUELO
			if x == 0 or y == 0 or x == ancho - 1 or y == alto - 1:
				tipo = Tipo.PARED
			# Un lago en la parte sur del mapa.
			if y >= 13 and x >= 2 and x <= ancho - 3:
				tipo = Tipo.AGUA
			_poner_local(x, y, tipo)

	# Obstaculos que permiten comprobar que el servidor bloquea el paso.
	for x in range(7, 18):
		_poner_local(x, 6, Tipo.PARED)
	_poner_local(12, 6, Tipo.SUELO)
	for sitio in [Vector2i(4, 3), Vector2i(5, 3), Vector2i(20, 3),
			Vector2i(4, 4), Vector2i(20, 4), Vector2i(4, 10),
			Vector2i(20, 10)]:
		_poner_local(sitio.x, sitio.y, Tipo.ARBOL)
	for sitio in [Vector2i(8, 10), Vector2i(9, 10), Vector2i(16, 10),
			Vector2i(17, 10), Vector2i(12, 3)]:
		_poner_local(sitio.x, sitio.y, Tipo.ROCA)


func posicion_inicial() -> Vector3i:
	var preferida := origen + Vector3i(12, 9, 0)
	if es_caminable(preferida):
		return preferida
	for radio in range(1, max(ancho, alto)):
		for y in range(alto):
			for x in range(ancho):
				if absi(x - 12) > radio or absi(y - 9) > radio:
					continue
				var candidata := origen + Vector3i(x, y, 0)
				if es_caminable(candidata):
					return candidata
	return origen


func es_caminable(posicion: Vector3i) -> bool:
	if posicion.z != origen.z:
		return false
	var local := _a_local(posicion)
	if not _dentro(local.x, local.y):
		return false
	var tipo := tipo_en(posicion)
	return tipo == Tipo.SUELO or tipo == Tipo.ESCALERA


func tipo_en(posicion: Vector3i) -> int:
	var local := _a_local(posicion)
	if not _dentro(local.x, local.y):
		return Tipo.PARED
	return int(_celdas.get(_clave(local.x, local.y), Tipo.SUELO))


func tipo_local(x: int, y: int) -> int:
	if not _dentro(x, y):
		return Tipo.PARED
	return int(_celdas.get(_clave(x, y), Tipo.SUELO))


func poner_local(x: int, y: int, tipo: int) -> bool:
	if not _dentro(x, y) or not es_tipo_valido(tipo):
		return false
	_poner_local(x, y, tipo)
	return true


func guardar(ruta: String = RUTA_MAPA) -> bool:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(JSON.stringify(a_diccionario(), "  "))
	return true


func a_diccionario() -> Dictionary:
	var celdas: Array = []
	for y in range(alto):
		for x in range(ancho):
			celdas.append({"x": x, "y": y, "tipo": tipo_local(x, y)})
	return {
		"version": VERSION,
		"origen": {"x": origen.x, "y": origen.y, "z": origen.z},
		"ancho": ancho,
		"alto": alto,
		"celdas": celdas,
	}


func nombre_tipo(tipo: int) -> String:
	match tipo:
		Tipo.SUELO:
			return "suelo"
		Tipo.PARED:
			return "pared"
		Tipo.AGUA:
			return "agua"
		Tipo.ARBOL:
			return "arbol"
		Tipo.ROCA:
			return "roca"
		Tipo.DECORACION:
			return "decoracion"
		Tipo.ESCALERA:
			return "escalera"
	return "desconocido"


static func es_tipo_valido(tipo: int) -> bool:
	return tipo >= Tipo.SUELO and tipo <= Tipo.ESCALERA


func _cargar_diccionario(datos: Dictionary) -> void:
	var origen_datos: Dictionary = datos.get("origen", {})
	origen = Vector3i(
		int(origen_datos.get("x", ORIGEN_POR_DEFECTO.x)),
		int(origen_datos.get("y", ORIGEN_POR_DEFECTO.y)),
		int(origen_datos.get("z", ORIGEN_POR_DEFECTO.z)))
	ancho = clampi(int(datos.get("ancho", ANCHO_POR_DEFECTO)), 3, 128)
	alto = clampi(int(datos.get("alto", ALTO_POR_DEFECTO)), 3, 128)
	_celdas.clear()
	for celda in datos.get("celdas", []):
		if typeof(celda) != TYPE_DICTIONARY:
			continue
		var x := int(celda.get("x", -1))
		var y := int(celda.get("y", -1))
		var tipo := int(celda.get("tipo", Tipo.SUELO))
		if _dentro(x, y) and es_tipo_valido(tipo):
			_poner_local(x, y, tipo)
	if _celdas.is_empty():
		crear_demo()


func _poner_local(x: int, y: int, tipo: int) -> void:
	_celdas[_clave(x, y)] = tipo


func _a_local(posicion: Vector3i) -> Vector2i:
	return Vector2i(posicion.x - origen.x, posicion.y - origen.y)


func _dentro(x: int, y: int) -> bool:
	return x >= 0 and x < ancho and y >= 0 and y < alto


func _clave(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


static func _resultado_error(mapa: MapaTVP3D, codigo: String) -> Dictionary:
	mapa.ultimo_error = codigo
	return {"ok": false, "mapa": mapa, "error": codigo}
