extends SceneTree

# Regresion del conjunto "conocido" del protocolo TVP 7.72.
#
# Origen: el defecto observado en vivo durante Phase 2C.2
# (`docs/qa/PARITY_PHASE2C2_MONSTER_REACQUISITION_LIVE.md`), donde el
# monstruo objetivo, el god y el propio personaje aparecieron los tres con
# `nombre` vacio a mitad de la medicion.
#
# Semantica verificada contra el servidor, no inferida de comentarios:
#   `ProtocolGame::AddCreature` (protocolgame.cpp):
#     0x61 -> marca, removedKnown u32, id u32, nombre texto, + estado comun
#     0x62 -> marca, id u32,                                 + estado comun
#   `sendCreatureTurn` (protocolgame.cpp:1529-1531):
#     0x63 -> marca, id u32, direccion u8   (y nada mas)
#   `ProtocolGame::checkCreatureAsKnown` (protocolgame.cpp:665-698):
#     el `knownCreatureSet` NO se vacia cuando una criatura sale de la vista;
#     solo desaloja al pasar de 150 entradas, y avisa mandando ese id como
#     `removedKnown` dentro de un `0x61`. `removedKnown == 0` = no olvidar.
#
# Ejecutar:
#   Godot --headless --path cliente3d --script red/identidad_conocida_self_test.gd

const ESTADO := preload("res://red/estado_mundo.gd")
const MAPA := preload("res://red/mapa772.gd")
const MENSAJE := preload("res://red/mensaje.gd")

const POS := Vector3i(32097, 32219, 7)

var _fallas := 0


func _comprobar(nombre: String, correcto: bool) -> void:
	if correcto:
		print("  OK  " + nombre)
	else:
		print("  FAIL " + nombre)
		_fallas += 1


## `0x61`: la unica forma que trae nombre y la unica que desaloja.
func _escribir_desconocida(msg, olvidar_id: int, id: int, nombre: String) -> void:
	msg.escribir_u16(0x61)
	msg.escribir_u32(olvidar_id)
	msg.escribir_u32(id)
	msg.escribir_texto(nombre)
	_escribir_estado_comun(msg)


## `0x62`: el servidor omite el nombre a proposito porque cree que ya lo
## tenemos. Reproduce exactamente el caso que rompia antes.
func _escribir_conocida(msg, id: int) -> void:
	msg.escribir_u16(0x62)
	msg.escribir_u32(id)
	_escribir_estado_comun(msg)


## `0x63`: forma corta de giro. Solo id y direccion.
func _escribir_ya_vista(msg, id: int, direccion: int) -> void:
	msg.escribir_u16(0x63)
	msg.escribir_u32(id)
	msg.escribir_u8(direccion)


func _escribir_estado_comun(msg) -> void:
	msg.escribir_u8(87)     # vida %
	msg.escribir_u8(2)      # direccion
	msg.escribir_u16(128)   # apariencia
	msg.escribir_u8(10)
	msg.escribir_u8(20)
	msg.escribir_u8(30)
	msg.escribir_u8(40)
	msg.escribir_u8(6)      # luz nivel
	msg.escribir_u8(215)    # luz color
	msg.escribir_u16(180)   # velocidad
	msg.escribir_u8(1)      # calavera
	msg.escribir_u8(2)      # escudo party


func _absorber_una(estado, mapa, msg) -> void:
	var nuevas := []
	mapa.leer_cosa(msg, POS, nuevas)
	assert(msg.sin_leer() == 0)
	estado._absorber({"casillas": {}, "criaturas": nuevas})


func _nombre_de(estado, id: int) -> String:
	if not estado.criaturas.has(id):
		return "<no visible>"
	return str(estado.criaturas[id].get("nombre", ""))


func _init() -> void:
	print("=================================================")
	print(" TVP3D - regresion de identidades conocidas 7.72")
	print("=================================================")

	_caso_1_a_3()
	_caso_4_y_5()
	_caso_6()
	_caso_7()
	_caso_8()
	_caso_forma_viva()

	if _fallas == 0:
		print("Regresion de identidades conocidas: OK")
	else:
		print("Regresion de identidades conocidas: %d fallas" % _fallas)
	quit(1 if _fallas > 0 else 0)


# CASO 1: una criatura desconocida cachea su nombre.
# CASO 2: sacarla de la vista NO borra la identidad de protocolo.
# CASO 3: al volver como conocida (0x62, sin nombre) el nombre se recupera.
func _caso_1_a_3() -> void:
	print("--- casos 1-3: alta, perdida de visibilidad y reaparicion ---")
	var estado = ESTADO.new()
	var mapa = MAPA.new()
	var id := 1001

	var alta = MENSAJE.new()
	_escribir_desconocida(alta, 0, id, "cave rat")
	_absorber_una(estado, mapa, alta)

	_comprobar("1: el alta cachea la identidad",
		estado.identidades_conocidas.get(id, "") == "cave rat")
	_comprobar("1: la criatura visible tiene nombre",
		_nombre_de(estado, id) == "cave rat")

	# Mismo camino que disparaba el defecto real: un 0x64 limpia el mundo
	# visible entero, pero el servidor NO vacia su knownCreatureSet.
	estado.criaturas.clear()
	_comprobar("2: ya no es visible", not estado.criaturas.has(id))
	_comprobar("2: la identidad de protocolo sobrevive",
		estado.identidades_conocidas.get(id, "") == "cave rat")

	var vuelta = MENSAJE.new()
	_escribir_conocida(vuelta, id)
	_absorber_una(estado, mapa, vuelta)
	_comprobar("3: 0x62 recupera el nombre y no queda vacio",
		_nombre_de(estado, id) == "cave rat")


# CASO 4: el servidor desaloja explicitamente con removedKnown.
# CASO 5: un id desalojado no resucita metadata vieja.
func _caso_4_y_5() -> void:
	print("--- casos 4-5: desalojo del servidor y no resurreccion ---")
	var estado = ESTADO.new()
	var mapa = MAPA.new()

	var alta = MENSAJE.new()
	_escribir_desconocida(alta, 0, 1001, "cave rat")
	_absorber_una(estado, mapa, alta)

	var reemplazo = MENSAJE.new()
	_escribir_desconocida(reemplazo, 1001, 2002, "rat")
	_absorber_una(estado, mapa, reemplazo)

	_comprobar("4: el id desalojado sale del conjunto conocido",
		not estado.identidades_conocidas.has(1001))
	_comprobar("4: el id nuevo queda cacheado",
		estado.identidades_conocidas.get(2002, "") == "rat")

	# El id viejo tampoco debe seguir visible con su nombre viejo.
	estado.criaturas.clear()

	var avisos := []
	estado.identidad_conocida_ausente.connect(
		func(detalle): avisos.append(detalle))

	var zombie = MENSAJE.new()
	_escribir_conocida(zombie, 1001)
	_absorber_una(estado, mapa, zombie)

	_comprobar("5: no resucita el nombre viejo",
		_nombre_de(estado, 1001) != "cave rat")
	_comprobar("5: avisa con un diagnostico determinista",
		avisos.size() == 1 and int(avisos[0].get("id", 0)) == 1001)


# CASO 6: reiniciar_sesion vacia el conjunto conocido.
func _caso_6() -> void:
	print("--- caso 6: reinicio de sesion ---")
	var estado = ESTADO.new()
	var mapa = MAPA.new()

	var alta = MENSAJE.new()
	_escribir_desconocida(alta, 0, 1001, "cave rat")
	_absorber_una(estado, mapa, alta)
	_comprobar("6: hay identidad antes del reinicio",
		not estado.identidades_conocidas.is_empty())

	estado.reiniciar_sesion()
	_comprobar("6: el reinicio vacia el conjunto conocido",
		estado.identidades_conocidas.is_empty())


# CASO 7: comportamiento generico, sin logica por tipo de criatura.
func _caso_7() -> void:
	print("--- caso 7: jugador, monstruo y NPC por igual ---")
	var estado = ESTADO.new()
	var mapa = MAPA.new()
	var esperados := {
		0x10000001: "Guillermo Knight",
		3001: "dragon",
		4001: "Thanita",
	}

	for id in esperados:
		var alta = MENSAJE.new()
		_escribir_desconocida(alta, 0, int(id), esperados[id])
		_absorber_una(estado, mapa, alta)

	estado.criaturas.clear()

	for id in esperados:
		var vuelta = MENSAJE.new()
		_escribir_conocida(vuelta, int(id))
		_absorber_una(estado, mapa, vuelta)

	var todas_bien := true
	for id in esperados:
		if _nombre_de(estado, int(id)) != esperados[id]:
			todas_bien = false
	_comprobar("7: los tres tipos recuperan su nombre sin logica especifica",
		todas_bien)


# CASO 8: forma corta 0x63, tal como la manda sendCreatureTurn.
func _caso_8() -> void:
	print("--- caso 8: forma corta 0x63 ---")
	var estado = ESTADO.new()
	var mapa = MAPA.new()
	var id := 5001

	var alta = MENSAJE.new()
	_escribir_desconocida(alta, 0, id, "orc")
	_absorber_una(estado, mapa, alta)
	var apariencia_inicial: int = int(estado.criaturas[id].get("apariencia", 0))
	var vida_inicial: int = int(estado.criaturas[id].get("vida", 0))

	var giro = MENSAJE.new()
	_escribir_ya_vista(giro, id, 3)
	_absorber_una(estado, mapa, giro)

	_comprobar("8: el giro conserva el nombre", _nombre_de(estado, id) == "orc")
	_comprobar("8: el giro conserva la apariencia",
		int(estado.criaturas[id].get("apariencia", 0)) == apariencia_inicial)
	_comprobar("8: el giro no cura visualmente",
		int(estado.criaturas[id].get("vida", 0)) == vida_inicial)
	_comprobar("8: el giro aplica la direccion nueva",
		int(estado.criaturas[id].get("direccion", -1)) == 3)

	# Y sigue funcionando aunque pierda la visibilidad antes del giro.
	estado.criaturas.clear()
	var giro2 = MENSAJE.new()
	_escribir_ya_vista(giro2, id, 1)
	_absorber_una(estado, mapa, giro2)
	_comprobar("8: el giro tras perder visibilidad tampoco pierde el nombre",
		_nombre_de(estado, id) == "orc")


# Reproduce la forma exacta del fallo en vivo de Phase 2C.2: tres criaturas
# (monstruo objetivo, god y personaje) presentes, luego un 0x64 que limpia el
# mundo visible, luego las tres reenviadas como conocidas sin nombre.
func _caso_forma_viva() -> void:
	print("--- forma del fallo vivo de Phase 2C.2 ---")
	var estado = ESTADO.new()
	var mapa = MAPA.new()
	var esperados := {
		1073764921: "cave rat",
		268435503: "GOD VALENTINO",
		268435504: "Valentino",
	}

	for id in esperados:
		var alta = MENSAJE.new()
		_escribir_desconocida(alta, 0, int(id), esperados[id])
		_absorber_una(estado, mapa, alta)

	# Lo que hace `0x64`: limpiar el mundo visible entero.
	estado.casillas.clear()
	estado.criaturas.clear()

	var avisos := []
	estado.identidad_conocida_ausente.connect(
		func(detalle): avisos.append(detalle))

	for id in esperados:
		var vuelta = MENSAJE.new()
		_escribir_conocida(vuelta, int(id))
		_absorber_una(estado, mapa, vuelta)

	var vacios := 0
	for id in esperados:
		if _nombre_de(estado, int(id)) == "":
			vacios += 1
	_comprobar("vivo: ninguna de las tres queda con nombre vacio", vacios == 0)
	_comprobar("vivo: las tres recuperan su nombre exacto",
		_nombre_de(estado, 1073764921) == "cave rat"
		and _nombre_de(estado, 268435503) == "GOD VALENTINO"
		and _nombre_de(estado, 268435504) == "Valentino")
	_comprobar("vivo: no hace falta ningun diagnostico de identidad ausente",
		avisos.is_empty())
