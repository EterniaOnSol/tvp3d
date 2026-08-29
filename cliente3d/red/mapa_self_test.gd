extends SceneTree

# Self-test del lector de mapas 7.72, sin servidor ni sockets.
#
# El codificador de esta prueba replica `ProtocolGame::GetFloorDescription`
# (`servidor/src/protocolgame.cpp:641-663`) byte a byte, incluido el contador
# `skip` que arranca en -1 y se comparte entre pisos:
#
#   for nx in ancho: for ny in alto:
#       si la casilla existe:  si skip >= 0 -> (skip, 0xFF); skip = 0; casilla
#       si no existe:          ++skip; si skip == 0xFF -> (0xFF, 0xFF); skip = -1
#   al final:                  si skip >= 0 -> (skip, 0xFF)
#
# Si el lector se desalinea, las casillas aparecen en coordenadas que no son
# las que el servidor describio, y entonces el `stackpos` de `0x6A`/`0x6C` deja
# de coincidir con el del servidor.

const MAPA := preload("res://red/mapa772.gd")
const MENSAJE := preload("res://red/mensaje.gd")

const ANCHO := 18
const ALTO := 14

var _fallas := 0
var _cid_simple := 0


func _initialize() -> void:
	var mapa = MAPA.new()
	_cid_simple = _buscar_cid_simple(mapa)
	if _cid_simple == 0:
		printerr("FALLA: el catalogo no tiene ningun item de ancho fijo")
		quit(1)
		return
	print("Self-test del mapa 7.72 (item de prueba: cid %d)" % _cid_simple)

	_probar_un_piso_lleno()
	_probar_una_sola_casilla()
	_probar_casillas_sueltas()
	_probar_tanda_de_255()
	_probar_varios_pisos()

	if _fallas > 0:
		printerr("Self-test del mapa: %d falla(s)" % _fallas)
		quit(1)
		return
	print("Self-test del mapa: OK")
	quit(0)


func _buscar_cid_simple(mapa) -> int:
	## Un item que no sea apilable ni liquido ocupa exactamente dos bytes, asi
	## que la prueba no depende de las banderas de ningun id concreto.
	for cid in range(100, 12000):
		var info: Dictionary = mapa.info_item(cid)
		if info.is_empty():
			continue
		if bool(info.get("apilable", false)) or bool(info.get("liquido", false)):
			continue
		return cid
	return 0


# --------------------------------------------------------------------
#  Codificador: el mismo algoritmo del servidor
# --------------------------------------------------------------------
class Codificador:
	var bytes := PackedByteArray()
	var skip := -1

	func casilla(cuantas_cosas: int, cid: int) -> void:
		if skip >= 0:
			bytes.append(skip)
			bytes.append(0xFF)
		skip = 0
		for _i in range(cuantas_cosas):
			bytes.append(cid & 0xFF)
			bytes.append((cid >> 8) & 0xFF)

	func vacia() -> void:
		skip += 1
		if skip == 0xFF:
			bytes.append(0xFF)
			bytes.append(0xFF)
			skip = -1

	func cerrar() -> void:
		if skip >= 0:
			bytes.append(skip)
			bytes.append(0xFF)


func _codificar_piso(cod: Codificador, presentes: Dictionary, x0: int, y0: int,
		desfase: int, cosas_por_casilla: int) -> void:
	for nx in range(ANCHO):
		for ny in range(ALTO):
			var donde := Vector2i(x0 + nx + desfase, y0 + ny + desfase)
			if presentes.has(donde):
				cod.casilla(cosas_por_casilla, _cid_simple)
			else:
				cod.vacia()


func _leer(bytes: PackedByteArray, x0: int, y0: int, z0: int) -> Dictionary:
	var mapa = MAPA.new()
	var msg = MENSAJE.new(bytes)
	var salida: Dictionary = mapa.leer_descripcion(msg, x0, y0, z0, ANCHO, ALTO)
	salida["sobran"] = msg.sin_leer()
	return salida


func _comprobar(nombre: String, correcto: bool, detalle: String = "") -> void:
	if correcto:
		print("  OK   %s" % nombre)
	else:
		_fallas += 1
		printerr("  FALLA %s%s" % [nombre, "" if detalle.is_empty() else ": " + detalle])


# --------------------------------------------------------------------
#  Casos
# --------------------------------------------------------------------
func _probar_un_piso_lleno() -> void:
	# Un solo piso, todas las casillas presentes: no hay ningun vacio.
	var z0 := 7
	var x0 := 32000
	var y0 := 32000
	var presentes := {}
	for nx in range(ANCHO):
		for ny in range(ALTO):
			presentes[Vector2i(x0 + nx, y0 + ny)] = true
	var cod := Codificador.new()
	# `leer_descripcion` con z0 == 7 espera los pisos 7..0; solo el 7 tiene
	# casillas y los demas van enteros vacios.
	_codificar_piso(cod, presentes, x0, y0, 0, 1)
	for piso in range(6, -1, -1):
		_codificar_piso(cod, {}, x0, y0, z0 - piso, 1)
	cod.cerrar()

	var salida := _leer(cod.bytes, x0, y0, z0)
	var casillas: Dictionary = salida["casillas"]
	_comprobar("un piso lleno entrega sus 252 casillas",
		casillas.size() == ANCHO * ALTO,
		"entrego %d" % casillas.size())
	_comprobar("un piso lleno consume todo el mensaje",
		int(salida["sobran"]) == 0, "sobran %d bytes" % int(salida["sobran"]))
	_comprobar("la esquina del piso lleno cae donde el servidor la puso",
		casillas.has(Vector3i(x0, y0, z0)))
	_comprobar("el centro del piso lleno cae donde el servidor lo puso",
		casillas.has(Vector3i(x0 + 8, y0 + 6, z0)))


func _probar_una_sola_casilla() -> void:
	# El caso que importa: una unica casilla en el centro, con todo lo demas
	# vacio. Es lo que pasa en el mundo real cuando el jugador esta en un
	# claro y casi ninguna casilla vecina tiene nada.
	var z0 := 7
	var x0 := 32000
	var y0 := 32000
	var centro := Vector2i(x0 + 8, y0 + 6)
	var cod := Codificador.new()
	_codificar_piso(cod, {centro: true}, x0, y0, 0, 2)
	for piso in range(6, -1, -1):
		_codificar_piso(cod, {}, x0, y0, z0 - piso, 1)
	cod.cerrar()

	var salida := _leer(cod.bytes, x0, y0, z0)
	var casillas: Dictionary = salida["casillas"]
	var esperada := Vector3i(centro.x, centro.y, z0)
	_comprobar("una sola casilla entrega exactamente una",
		casillas.size() == 1, "entrego %d" % casillas.size())
	_comprobar("la casilla unica cae en la coordenada que dijo el servidor",
		casillas.has(esperada), "quedo en %s" % str(casillas.keys()))
	_comprobar("una sola casilla consume todo el mensaje",
		int(salida["sobran"]) == 0, "sobran %d bytes" % int(salida["sobran"]))


func _probar_casillas_sueltas() -> void:
	# Varias casillas separadas por huecos de distinto tamaño, incluido un
	# hueco de cero (dos casillas pegadas).
	var z0 := 7
	var x0 := 31900
	var y0 := 31900
	var presentes := {
		Vector2i(x0, y0): true,              # la primerisima
		Vector2i(x0, y0 + 1): true,          # pegada a la anterior
		Vector2i(x0 + 3, y0 + 5): true,
		Vector2i(x0 + 8, y0 + 6): true,      # el centro
		Vector2i(x0 + ANCHO - 1, y0 + ALTO - 1): true,  # la ultima
	}
	var cod := Codificador.new()
	_codificar_piso(cod, presentes, x0, y0, 0, 1)
	for piso in range(6, -1, -1):
		_codificar_piso(cod, {}, x0, y0, z0 - piso, 1)
	cod.cerrar()

	var salida := _leer(cod.bytes, x0, y0, z0)
	var casillas: Dictionary = salida["casillas"]
	var faltan: Array = []
	for donde in presentes:
		if not casillas.has(Vector3i(donde.x, donde.y, z0)):
			faltan.append(str(donde))
	_comprobar("las casillas sueltas caen todas en su coordenada",
		faltan.is_empty() and casillas.size() == presentes.size(),
		"faltan %s, entrego %d" % [str(faltan), casillas.size()])
	_comprobar("las casillas sueltas consumen todo el mensaje",
		int(salida["sobran"]) == 0, "sobran %d bytes" % int(salida["sobran"]))


func _probar_tanda_de_255() -> void:
	# Un piso entero vacio son 252 casillas, asi que la tanda de 255 solo
	# aparece cruzando pisos. Con ocho pisos vacios y una sola casilla al
	# final se ejercita el reinicio del contador a -1.
	var z0 := 7
	var x0 := 31800
	var y0 := 31800
	var cod := Codificador.new()
	for piso in range(7, 0, -1):
		_codificar_piso(cod, {}, x0, y0, z0 - piso, 1)
	var ultima := Vector2i(x0 + ANCHO - 1 + 7, y0 + ALTO - 1 + 7)
	_codificar_piso(cod, {ultima: true}, x0, y0, 7, 1)
	cod.cerrar()

	var salida := _leer(cod.bytes, x0, y0, z0)
	var casillas: Dictionary = salida["casillas"]
	_comprobar("la tanda de 255 no pierde la unica casilla del final",
		casillas.has(Vector3i(ultima.x, ultima.y, 0)),
		"entrego %s" % str(casillas.keys()))
	_comprobar("la tanda de 255 consume todo el mensaje",
		int(salida["sobran"]) == 0, "sobran %d bytes" % int(salida["sobran"]))


func _probar_varios_pisos() -> void:
	# Cada piso de arriba se describe corrido una casilla por nivel.
	var z0 := 7
	var x0 := 31700
	var y0 := 31700
	var cod := Codificador.new()
	var esperadas: Array = []
	for piso in range(7, -1, -1):
		var desfase := z0 - piso
		var donde := Vector2i(x0 + 8 + desfase, y0 + 6 + desfase)
		esperadas.append(Vector3i(donde.x, donde.y, piso))
		_codificar_piso(cod, {donde: true}, x0, y0, desfase, 1)
	cod.cerrar()

	var salida := _leer(cod.bytes, x0, y0, z0)
	var casillas: Dictionary = salida["casillas"]
	var faltan: Array = []
	for donde in esperadas:
		if not casillas.has(donde):
			faltan.append(str(donde))
	_comprobar("cada piso deja su casilla en la coordenada corrida que toca",
		faltan.is_empty(), "faltan %s" % str(faltan))
	_comprobar("los ocho pisos consumen todo el mensaje",
		int(salida["sobran"]) == 0, "sobran %d bytes" % int(salida["sobran"]))
