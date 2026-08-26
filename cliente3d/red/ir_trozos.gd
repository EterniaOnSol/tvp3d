extends RefCounted

## Lector bajo demanda del IR de depuracion particionado espacialmente.
## El JSON completo sigue siendo la fuente auditable; este lector solo abre
## los archivos de chunk que necesita una ventana.

var _index_path := ""
var _base_path := ""
var _index := {}
var _chunks := {}
var _cache := {}


func abrir(path: String) -> bool:
	_index_path = path
	_base_path = path.get_base_dir()
	var archivo := FileAccess.open(path, FileAccess.READ)
	if archivo == null:
		return false
	var datos = JSON.parse_string(archivo.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY:
		return false
	if int(datos.get("version", 0)) != 1:
		return false
	if typeof(datos.get("chunks", {})) != TYPE_DICTIONARY:
		return false
	_index = datos
	_chunks = datos["chunks"]
	_cache.clear()
	return true


func region() -> Dictionary:
	return _index.get("region", {})


func chunk_size() -> int:
	return int(_index.get("chunk_size", 32))


func chunks_cargados() -> int:
	return _cache.size()


func claves_cargadas() -> Array:
	return _cache.keys()


func cargar_chunk(clave: String) -> Dictionary:
	if _cache.has(clave):
		return _cache[clave]
	var metadata: Dictionary = _chunks.get(clave, {})
	if metadata.is_empty():
		return {}
	var archivo_path := _base_path.path_join(str(metadata.get("file", "")))
	var archivo := FileAccess.open(archivo_path, FileAccess.READ)
	if archivo == null:
		push_error("Falta chunk IR: " + archivo_path)
		return {}
	var datos = JSON.parse_string(archivo.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY or not datos.has("tiles"):
		push_error("Chunk IR invalido: " + archivo_path)
		return {}
	_cache[clave] = datos
	return datos


func cargar_ventana(centro: Vector3i, radio: int, min_z := -100, max_z := 100) -> Dictionary:
	var tamano := chunk_size()
	var tx0 := floori(float(centro.x - radio) / tamano)
	var tx1 := floori(float(centro.x + radio) / tamano)
	var ty0 := floori(float(centro.y - radio) / tamano)
	var ty1 := floori(float(centro.y + radio) / tamano)
	var necesarios := {}
	var salida := {}
	for tx in range(tx0, tx1 + 1):
		for ty in range(ty0, ty1 + 1):
			for z in range(min_z, max_z + 1):
				var clave := "%d_%d_%d" % [tx, ty, z]
				if not _chunks.has(clave):
					continue
				necesarios[clave] = true
				var documento := cargar_chunk(clave)
				for tile in documento.get("tiles", []):
					var p: Dictionary = tile.get("position", {})
					if not p.has("x") or not p.has("y") or not p.has("z"):
						continue
					var donde := Vector3i(int(p["x"]), int(p["y"]), int(p["z"]))
					if absi(donde.x - centro.x) <= radio and \
						absi(donde.y - centro.y) <= radio and \
						min_z <= donde.z and donde.z <= max_z:
						salida[donde] = tile

	for clave in _cache.keys():
		if not necesarios.has(clave):
			_cache.erase(clave)
	return salida
