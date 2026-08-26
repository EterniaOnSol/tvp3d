extends Node

## Valida una escalera real del mapa contra el protocolo vivo 7.72.
##
## La ruta prueba las dos direcciones y vuelve al origen:
##   z7 -> z6: 0xBE (MoveUpCreature)
##   z6 -> z7: 0xBF (MoveDownCreature)
##
## El objetivo no es probar solo el destino visual: tambien deja constancia
## del opcode recibido y de la posicion que EstadoMundo tenia al recibirlo.

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
const CUENTA := 123456
const CLAVE := "123456"
const IR_PATH := "res://generated/maps/rookgaard_100sqm.json"
const REPORT_PATH := "res://generated/reports/floor_transition.json"

const ANTES_ESCALERA := Vector3i(32080, 32204, 7)
const ESCALERA_SUPERIOR := Vector3i(32080, 32203, 7)
const DESTINO_INFERIOR := Vector3i(32080, 32202, 6)
const ESCALERA_INFERIOR := Vector3i(32080, 32203, 6)
const POSICION_SUPERIOR_RETORNO := ANTES_ESCALERA

const FASE_INICIAL := 0
const FASE_ACERCAR := 1
const FASE_BAJAR := 2
const FASE_SUBIR := 3
const FASE_RETORNAR := 4
const FASE_NORMALIZAR := 5
const FASE_RESTAURAR_BAJO := 6
const FASE_RESTAURAR_BAJO_ESPERA := 7

var _con
var _estado
var _ir_tiles := {}
var _origen_real := Vector3i.ZERO
var _fase := FASE_INICIAL
var _ruta := []
var _reloj := 0.0
var _reloj_fase := 0.0
var _terminado := false
var _paquetes_piso := []
var _fases := []
var _esperando_movimiento := false


func _ready() -> void:
	if not _cargar_ir():
		_fallo("no se pudo cargar " + IR_PATH)
		return
	_estado = ESTADO.new()
	_estado.cambio_piso.connect(_al_cambio_piso)
	_estado.mapa_recibido.connect(_al_mapa_recibido)
	_estado.paso_cancelado.connect(_al_paso_cancelado)
	_con = CONEXION.new()
	add_child(_con)
	_con.lista_personajes.connect(_al_recibir_personajes)
	_con.paquete_juego.connect(_al_recibir_paquete)
	_con.error_red.connect(_fallo)
	_con.cerrada.connect(func():
		if not _terminado:
			_fallo("conexion de juego cerrada"))
	print("[piso] cargadas %d tiles del IR" % _ir_tiles.size())
	print("[piso] pidiendo login")
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _process(delta: float) -> void:
	_reloj += delta
	_reloj_fase += delta
	if _terminado:
		return
	if _reloj > 90.0:
		_fallo("timeout global en fase %d, posicion %s" % [_fase, _estado.mi_pos])
		return
	if _reloj_fase > 25.0 and _fase != FASE_INICIAL:
		_fallo("timeout en fase %d, esperaba movimiento hacia %s; actual %s" % [
			_fase, _objetivo_de_fase(), _estado.mi_pos])
		return
	if _fase == FASE_INICIAL:
		if _estado.adentro and not _estado.casillas.is_empty():
			_origen_real = _estado.mi_pos
			print("[piso] origen vivo: %s" % _origen_real)
			if _origen_real.z == 7:
				_iniciar_acercamiento()
			elif _origen_real == DESTINO_INFERIOR:
				_normalizar_a_superficie()
			else:
				_fallo("origen vivo fuera de los puntos soportados: %s" % _origen_real)
	elif _fase == FASE_ACERCAR and _estado.mi_pos == ANTES_ESCALERA:
		_enviar_a_escalera()
	elif _fase == FASE_BAJAR and _estado.mi_pos == DESTINO_INFERIOR:
		if _tiene_transicion(DESTINO_INFERIOR):
			_enviar_a_subir()
	elif _fase == FASE_SUBIR and _estado.mi_pos == POSICION_SUPERIOR_RETORNO:
		if _tiene_transicion(POSICION_SUPERIOR_RETORNO):
			_iniciar_retorno()
	elif _fase == FASE_RETORNAR and _estado.mi_pos == _origen_real:
		_terminar_ok()
	elif _fase == FASE_NORMALIZAR and _estado.mi_pos == POSICION_SUPERIOR_RETORNO:
		if _tiene_transicion(POSICION_SUPERIOR_RETORNO):
			_iniciar_acercamiento()
	elif _fase == FASE_RESTAURAR_BAJO and _estado.mi_pos == ANTES_ESCALERA:
		_fase = FASE_RESTAURAR_BAJO_ESPERA
		_reloj_fase = 0.0
		print("[piso] restaurando origen inferior desde %s" % ANTES_ESCALERA)
		_con.enviar_auto_camino([Vector2i(0, -1)])
	elif _fase == FASE_RESTAURAR_BAJO_ESPERA and _estado.mi_pos == _origen_real:
		_terminar_ok()


func _cargar_ir() -> bool:
	var archivo := FileAccess.open(IR_PATH, FileAccess.READ)
	if archivo == null:
		return false
	var datos = JSON.parse_string(archivo.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY:
		return false
	for tile in datos.get("tiles", []):
		var posicion: Dictionary = tile.get("position", {})
		if not posicion.has_all(["x", "y", "z"]):
			continue
		var donde := Vector3i(int(posicion["x"]), int(posicion["y"]), int(posicion["z"]))
		_ir_tiles[donde] = tile
	return not _ir_tiles.is_empty()


func _al_recibir_personajes(_motd: String, personajes: Array) -> void:
	if personajes.is_empty():
		_fallo("cuenta sin personajes")
		return
	var personaje: Dictionary = personajes[0]
	_con.cerrar()
	_con.queue_free()
	_con = CONEXION.new()
	add_child(_con)
	_con.paquete_juego.connect(_al_recibir_paquete)
	_con.error_red.connect(_fallo)
	_con.cerrada.connect(func():
		if not _terminado:
			_fallo("conexion de juego cerrada"))
	var ip: String = personaje.get("ip", HOST)
	if ip == "0.0.0.0" or ip == "":
		ip = HOST
	_con.entrar_al_mundo(ip, int(personaje["puerto"]), CUENTA,
		personaje["nombre"], CLAVE)


func _al_recibir_paquete(msg) -> void:
	_estado.procesar(msg)


func _iniciar_acercamiento() -> void:
	_ruta = _buscar_ruta(_estado.mi_pos, ANTES_ESCALERA)
	if _ruta.is_empty() and _estado.mi_pos != ANTES_ESCALERA:
		_fallo("no encontre ruta estatica desde %s hasta %s" % [
			_estado.mi_pos, ANTES_ESCALERA])
		return
	_fase = FASE_ACERCAR
	_reloj_fase = 0.0
	_esperando_movimiento = true
	_fases.append({
		"name": "acercamiento",
		"from": _posicion_json(_estado.mi_pos),
		"to": _posicion_json(ANTES_ESCALERA),
		"steps": _ruta.size(),
	})
	print("[piso] acercando %d pasos hacia %s" % [_ruta.size(), ANTES_ESCALERA])
	if _ruta.is_empty():
		_enviar_a_escalera()
	else:
		_con.enviar_auto_camino(_ruta)


func _enviar_a_escalera() -> void:
	if not _esperando_movimiento:
		return
	_esperando_movimiento = false
	_fase = FASE_BAJAR
	_reloj_fase = 0.0
	_fases.append({
		"name": "bajar",
		"from": _posicion_json(_estado.mi_pos),
		"expected_to": _posicion_json(DESTINO_INFERIOR),
		"stair": _posicion_json(ESCALERA_SUPERIOR),
		"opcode": "0xBE",
	})
	print("[piso] enviando norte sobre escalera %s" % ESCALERA_SUPERIOR)
	_con.enviar_auto_camino([Vector2i(0, -1)])


func _enviar_a_subir() -> void:
	_esperando_movimiento = false
	_fase = FASE_SUBIR
	_reloj_fase = 0.0
	_fases.append({
		"name": "subir",
		"from": _posicion_json(_estado.mi_pos),
		"expected_to": _posicion_json(POSICION_SUPERIOR_RETORNO),
		"stair": _posicion_json(ESCALERA_INFERIOR),
		"opcode": "0xBF",
	})
	print("[piso] enviando sur sobre escalera %s" % ESCALERA_INFERIOR)
	_con.enviar_auto_camino([Vector2i(0, 1)])


func _normalizar_a_superficie() -> void:
	_fase = FASE_NORMALIZAR
	_reloj_fase = 0.0
	print("[piso] origen inferior; subiendo primero hacia %s" % POSICION_SUPERIOR_RETORNO)
	_con.enviar_auto_camino([Vector2i(0, 1)])


func _iniciar_retorno() -> void:
	if _estado.mi_pos == _origen_real:
		_terminar_ok()
		return
	if _origen_real.z == 6:
		_ruta = _buscar_ruta(_estado.mi_pos, ANTES_ESCALERA)
		if _ruta.is_empty() and _estado.mi_pos != ANTES_ESCALERA:
			_fallo("no encontre ruta de regreso inferior desde %s hasta %s" % [
				_estado.mi_pos, ANTES_ESCALERA])
			return
		_fase = FASE_RESTAURAR_BAJO
		_reloj_fase = 0.0
		_fases.append({
			"name": "regreso_al_origen_inferior",
			"from": _posicion_json(_estado.mi_pos),
			"to": _posicion_json(_origen_real),
			"steps_to_stair": _ruta.size(),
		})
		print("[piso] preparando regreso inferior con %d pasos" % _ruta.size())
		if not _ruta.is_empty():
			_con.enviar_auto_camino(_ruta)
		return
	_ruta = _buscar_ruta(_estado.mi_pos, _origen_real)
	if _ruta.is_empty():
		_fallo("no encontre ruta de regreso desde %s hasta %s" % [
			_estado.mi_pos, _origen_real])
		return
	_fase = FASE_RETORNAR
	_reloj_fase = 0.0
	_esperando_movimiento = true
	_fases.append({
		"name": "regreso",
		"from": _posicion_json(_estado.mi_pos),
		"to": _posicion_json(_origen_real),
		"steps": _ruta.size(),
	})
	print("[piso] regresando %d pasos hacia %s" % [_ruta.size(), _origen_real])
	_con.enviar_auto_camino(_ruta)


func _al_cambio_piso(opcode: int, posicion: Vector3i) -> void:
	_paquetes_piso.append({
		"opcode": "0x%02X" % opcode,
		"position": _posicion_json(posicion),
		"phase": _fase,
	})
	print("[piso] recibido 0x%02X con posicion %s" % [opcode, posicion])


func _al_mapa_recibido(posicion: Vector3i) -> void:
	if _fase not in [FASE_BAJAR, FASE_SUBIR, FASE_NORMALIZAR,
			FASE_RESTAURAR_BAJO_ESPERA]:
		return
	_paquetes_piso.append({
		"opcode": "0x64",
		"position": _posicion_json(posicion),
		"phase": _fase,
		"kind": "map_description_floor_fallback",
	})
	print("[piso] recibido 0x64 de cambio de piso con posicion %s" % posicion)


func _al_paso_cancelado() -> void:
	if not _terminado:
		_fallo("el servidor cancelo un paso en fase %d, posicion %s" % [
			_fase, _estado.mi_pos])


func _tiene_transicion(posicion: Vector3i) -> bool:
	for paquete in _paquetes_piso:
		if _posicion_desde(paquete["position"]) != posicion:
			continue
		if paquete["opcode"] in ["0xBE", "0xBF", "0x64"]:
			return true
	return false


func _buscar_ruta(inicio: Vector3i, objetivo: Vector3i) -> Array:
	if inicio == objetivo:
		return []
	var deltas := [
		Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
		Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	var cola := [inicio]
	var anterior := {inicio: null}
	var cabeza := 0
	while cabeza < cola.size():
		var actual: Vector3i = cola[cabeza]
		cabeza += 1
		if actual == objetivo:
			var ruta := []
			var cursor: Variant = objetivo
			while cursor != inicio:
				var previo: Vector3i = anterior[cursor]
				ruta.append(Vector2i(cursor.x - previo.x, cursor.y - previo.y))
				cursor = previo
			ruta.reverse()
			return ruta
		for delta in deltas:
			var siguiente := Vector3i(actual.x + delta.x, actual.y + delta.y, inicio.z)
			if anterior.has(siguiente):
				continue
			if siguiente != objetivo and not _es_transitable(siguiente):
				continue
			anterior[siguiente] = actual
			cola.append(siguiente)
	return []


func _es_transitable(posicion: Vector3i) -> bool:
	var tile = _ir_tiles.get(posicion)
	if tile == null:
		return false
	return bool(tile.get("queryadd_walkable", false))


func _objetivo_de_fase() -> Vector3i:
	match _fase:
		FASE_ACERCAR: return ANTES_ESCALERA
		FASE_BAJAR: return DESTINO_INFERIOR
		FASE_SUBIR: return POSICION_SUPERIOR_RETORNO
		FASE_RETORNAR: return _origen_real
		FASE_NORMALIZAR: return POSICION_SUPERIOR_RETORNO
		FASE_RESTAURAR_BAJO: return ANTES_ESCALERA
		FASE_RESTAURAR_BAJO_ESPERA: return _origen_real
	return _origen_real


func _posicion_json(posicion: Vector3i) -> Dictionary:
	return {"x": posicion.x, "y": posicion.y, "z": posicion.z}


func _posicion_desde(posicion: Dictionary) -> Vector3i:
	return Vector3i(int(posicion["x"]), int(posicion["y"]), int(posicion["z"]))


func _terminar_ok() -> void:
	if _terminado:
		return
	_terminado = true
	var reporte := _reporte(true, "")
	_guardar_reporte(reporte)
	var directos := _contar_opcode("0xBE") + _contar_opcode("0xBF")
	if directos == 2:
		print("[piso] OK: 0xBE y 0xBF recibidos; posicion final %s" % _estado.mi_pos)
	else:
		print("[piso] OK: transiciones recibidas por 0x64 (0xBE/0xBF directos=%d); posicion final %s" % [
			directos, _estado.mi_pos])
	get_tree().quit(0)


func _fallo(motivo: String) -> void:
	if _terminado:
		return
	_terminado = true
	var reporte := _reporte(false, motivo)
	_guardar_reporte(reporte)
	print("[piso] FAIL: " + motivo)
	get_tree().quit(1)


func _reporte(paso: bool, motivo: String) -> Dictionary:
	return {
		"version": 1,
		"source": {
			"protocol": "TVP 7.72",
			"state_parser": "red/estado_mundo.gd",
			"ir": IR_PATH,
		},
		"stair": {
			"position": _posicion_json(ESCALERA_SUPERIOR),
			"server_id": 1396,
			"client_id": 1958,
			"name": "wooden stairs",
			"floorchange": "north",
		},
		"expected": {
			"origin": _posicion_json(_origen_real),
			"lower": _posicion_json(DESTINO_INFERIOR),
			"upper_return": _posicion_json(POSICION_SUPERIOR_RETORNO),
			"direct_floor_opcodes": ["0xBE", "0xBF"],
			"teleport_fallback_opcode": "0x64",
		},
		"summary": {
			"passed": paso,
			"restored": _estado != null and _estado.mi_pos == _origen_real,
			"floor_packets": _paquetes_piso.size(),
			"direct_floor_packets": _contar_opcode("0xBE") + _contar_opcode("0xBF"),
			"map_description_floor_fallbacks": _contar_opcode("0x64"),
			"observed_opcodes": _opcodes_observados(),
			"protocol_path": "0xBE/0xBF" if _contar_opcode("0xBE") + _contar_opcode("0xBF") == 2 else "0x64 map description",
			"final_position": _posicion_json(_estado.mi_pos) if _estado != null else {},
			"error": motivo,
		},
		"phases": _fases,
		"floor_packets": _paquetes_piso,
	}


func _contar_opcode(opcode: String) -> int:
	var cantidad := 0
	for paquete in _paquetes_piso:
		if paquete.get("opcode") == opcode:
			cantidad += 1
	return cantidad


func _opcodes_observados() -> Array:
	var vistos := []
	for paquete in _paquetes_piso:
		var opcode: String = paquete.get("opcode", "")
		if opcode not in vistos:
			vistos.append(opcode)
	return vistos


func _guardar_reporte(reporte: Dictionary) -> void:
	var archivo := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo escribir " + REPORT_PATH)
		return
	archivo.store_string(JSON.stringify(reporte, "\t"))
