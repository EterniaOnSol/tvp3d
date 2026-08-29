extends RefCounted

# =====================================================================
#  El mapa entero, leido del disco.
#
#  El servidor solo manda 18x14 casillas alrededor tuyo — es el protocolo
#  y no hay forma de pedir mas (protocolgame.cpp:1699). Para ver el mundo
#  a lo lejos hace falta el mismo `.otbm` que usa el servidor, ya
#  convertido a trozos por herramientas/extraer_mapa772.py.
#
#  El reparto es este, y conviene tenerlo claro:
#
#      del disco   -> el decorado: pisos, paredes, arboles, lo quieto
#      del servidor -> lo que se mueve y lo que cambia, en vivo
#
#  El cliente puede precargar los 576 trozos al arrancar. Asi el mapa
#  completo queda disponible para minimapa, editor y rutas; el render 3D
#  sigue dibujando solo la ventana alrededor de la camara por rendimiento.
# =====================================================================

const CARPETA := "res://assets/mapa772/"

var _indice := {}
var _lado := 64
var _archivo: FileAccess
var _cargados := {}     ## "tx_ty" -> {Vector3i -> PackedInt32Array}
## En modo completo se conserva el binario compacto de cada trozo. No se
## convierten los 576 trozos a diccionarios a la vez porque eso multiplica el
## archivo de 46 MiB hasta varios gigabytes.
var _bytes_en_memoria := {} ## "tx_ty" -> PackedByteArray
var _listo := false
var _mapa_completo := false

## Limites del mundo, para saber si una casilla puede existir.
var minx := 0
var miny := 0
var maxx := 0
var maxy := 0


func _init() -> void:
	var f := FileAccess.open(CARPETA + "mapa.json", FileAccess.READ)
	if f == null:
		push_error("Falta el mapa. Corre herramientas/extraer_mapa772.py")
		return
	var datos = JSON.parse_string(f.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY:
		push_error("El indice del mapa no se entiende")
		return

	_lado = int(datos.get("lado_trozo", 64))
	_indice = datos.get("trozos", {})
	minx = int(datos.get("minx", 0))
	miny = int(datos.get("miny", 0))
	maxx = int(datos.get("maxx", 0))
	maxy = int(datos.get("maxy", 0))

	_archivo = FileAccess.open(CARPETA + "mapa.bin", FileAccess.READ)
	if _archivo == null:
		push_error("Falta " + CARPETA + "mapa.bin")
		return
	_listo = true


func listo() -> bool:
	return _listo


func trozos_cargados() -> int:
	return _indice.size() if _mapa_completo else _cargados.size()


func cargar_completo() -> void:
	"""Precarga todos los trozos del mapa antes de entrar al mundo.

	El archivo binario completo pesa 45.7 MiB y el indice tiene 576 trozos.
	Se conserva la representacion compacta por trozo para no convertir
	cada SQM en un nodo o un objeto de escena; la lectura deja de depender
	del movimiento del jugador.
	"""
	if not _listo or _mapa_completo:
		return
	var inicio := Time.get_ticks_msec()
	var cargados := 0
	var bytes_totales := 0
	for clave in _indice:
		var clave_trozo := str(clave)
		var sitio = _indice.get(clave_trozo)
		if sitio == null:
			continue
		_archivo.seek(int(sitio[0]))
		var datos := _archivo.get_buffer(int(sitio[1]))
		_bytes_en_memoria[clave_trozo] = datos
		bytes_totales += datos.size()
		cargados += 1
	_mapa_completo = true
	print("Mapa completo precargado: %d trozos, %.1f MiB, en %.2f s" % [
		cargados, float(bytes_totales) / 1048576.0,
		float(Time.get_ticks_msec() - inicio) / 1000.0])


func mapa_completo() -> bool:
	return _mapa_completo


func ids_de(posicion: Vector3i) -> PackedInt32Array:
	"""Consulta una casilla del mapa completo sin depender de la ventana 3D."""
	if not _listo:
		return PackedInt32Array()
	var tx := int(floor(float(posicion.x) / float(_lado)))
	var ty := int(floor(float(posicion.y) / float(_lado)))
	var trozo: Dictionary = _trozo("%d_%d" % [tx, ty])
	return trozo.get(posicion, PackedInt32Array())


func casillas_de(centro: Vector3i, radio: int) -> Dictionary:
	"""Todas las casillas a `radio` de distancia, de todos los pisos.
	Devuelve Vector3i -> PackedInt32Array con los ids de cliente."""
	if not _listo:
		return {}

	var salida := {}
	var t0x := (centro.x - radio) / _lado
	var t1x := (centro.x + radio) / _lado
	var t0y := (centro.y - radio) / _lado
	var t1y := (centro.y + radio) / _lado

	var cerca := {}
	for tx in range(t0x, t1x + 1):
		for ty in range(t0y, t1y + 1):
			var clave := "%d_%d" % [tx, ty]
			cerca[clave] = true
			var trozo := _trozo(clave)
			for donde in trozo:
				if absi(donde.x - centro.x) <= radio and absi(donde.y - centro.y) <= radio:
					salida[donde] = trozo[donde]

	# El binario completo permanece en memoria, pero los diccionarios decodificados
	# de la ventana anterior se sueltan. Asi cambiar de zona no acumula millones
	# de Vector3i y PackedInt32Array, y tampoco vuelve a tocar el disco.
	for clave in _cargados.keys():
		if not cerca.has(clave):
			_cargados.erase(clave)

	return salida


func _trozo(clave: String) -> Dictionary:
	if _cargados.has(clave):
		return _cargados[clave]
	var sitio = _indice.get(clave)
	if sitio == null:
		_cargados[clave] = {}
		return {}

	var b: PackedByteArray
	if _bytes_en_memoria.has(clave):
		b = _bytes_en_memoria[clave]
	else:
		_archivo.seek(int(sitio[0]))
		b = _archivo.get_buffer(int(sitio[1]))
	var partes := clave.split("_")
	var basex := int(partes[0]) * _lado
	var basey := int(partes[1]) * _lado

	var casillas := {}
	var p := 0
	var n := b.size()
	while p + 4 <= n:
		var donde := Vector3i(basex + b[p], basey + b[p + 1], b[p + 2])
		var cuantos: int = b[p + 3]
		p += 4
		var ids := PackedInt32Array()
		ids.resize(cuantos)
		for i in range(cuantos):
			ids[i] = b[p] | (b[p + 1] << 8)
			p += 2
		casillas[donde] = ids

	_cargados[clave] = casillas
	return casillas
