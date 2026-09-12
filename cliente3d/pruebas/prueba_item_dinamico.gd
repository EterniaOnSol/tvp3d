extends Node

## Valida el ciclo vivo de un item accionable del mapa:
##   lever 2772 -> lever 2773 -> lever 2772
##
## La autoridad sigue en TVP. La prueba solo envia 0x82 y exige que el
## cambio llegue como 0x6B antes de avanzar al siguiente paso.

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

var HOST := CREDENCIALES.HOST_DEFECTO
var PUERTO_LOGIN := CREDENCIALES.PUERTO_LOGIN_DEFECTO
var CUENTA := 0
var CLAVE := ""
const IR_PATH := "res://generated/maps/rookgaard_100sqm.json"
const REPORT_PATH := "res://generated/reports/dynamic_item.json"

const ESCALERA_SUPERIOR := Vector3i(32080, 32204, 7)
const ESCALERA_INFERIOR := Vector3i(32080, 32202, 6)
const ITEM_DINAMICO := Vector3i(32086, 32204, 6)
const APROXIMACION := Vector3i(32085, 32204, 6)
const ITEM_CERRADO := 2772
const ITEM_ACTIVO := 2773

const FASE_INICIAL := 0
const FASE_BAJAR := 1
const FASE_RUTA_ITEM := 2
const FASE_ABRIR := 3
const FASE_CERRAR := 4
const FASE_RETORNO_BAJO := 5
const FASE_RETORNO_ALTO := 6
const FASE_RETORNO_ORIGEN := 7

var _con
var _estado
var _ir_tiles := {}
var _origen_real := Vector3i.ZERO
var _fase := FASE_INICIAL
var _ruta := []
var _destinos_ruta := []
var _paso_ruta := 0
var _inicio_ruta := Vector3i.ZERO
var _proximo_paso_en: float = 0.0
var _reloj := 0.0
var _reloj_fase := 0.0
var _terminado := false
var _eventos := []
var _fases := []


func _ready() -> void:
	# Credenciales e identidades de prueba: SOLO por entorno, nunca literales.
	# Si falta alguna, corta aca y no intenta ninguna conexion.
	if not CREDENCIALES.exigir(self, ["TVP772_ACCOUNT", "TVP772_PASSWORD"]):
		return
	HOST = CREDENCIALES.host()
	PUERTO_LOGIN = CREDENCIALES.puerto_login()
	CUENTA = CREDENCIALES.entero("TVP772_ACCOUNT")
	CLAVE = CREDENCIALES.texto("TVP772_PASSWORD")
	if not _cargar_ir():
		_fallo("no se pudo cargar " + IR_PATH)
		return
	_estado = ESTADO.new()
	_estado.casilla_actualizada.connect(_al_casilla_actualizada)
	_estado.paso_cancelado.connect(_al_paso_cancelado)
	_estado.mensaje_servidor.connect(func(texto: String): print("[item] mensaje servidor: %s" % texto))
	_con = CONEXION.new()
	add_child(_con)
	_con.lista_personajes.connect(_al_recibir_personajes)
	_con.paquete_juego.connect(_al_recibir_paquete)
	_con.error_red.connect(_fallo)
	_con.cerrada.connect(func():
		if not _terminado:
			_fallo("conexion de juego cerrada"))
	print("[item] cargadas %d tiles del IR" % _ir_tiles.size())
	print("[item] pidiendo login")
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _process(delta: float) -> void:
	_reloj += delta
	_reloj_fase += delta
	if _terminado:
		return
	if _reloj > 120.0:
		_fallo("timeout global en fase %d, posicion %s" % [_fase, _estado.mi_pos])
		return
	if _reloj_fase > 30.0 and _fase != FASE_INICIAL:
		_fallo("timeout en fase %d, esperaba %s; actual %s" % [
			_fase, _objetivo_de_fase(), _estado.mi_pos])
		return

	match _fase:
		FASE_INICIAL:
			if _estado.adentro and not _estado.casillas.is_empty():
				_iniciar_desde_mapa()
		FASE_BAJAR:
			if _estado.mi_pos == ESCALERA_INFERIOR:
				_iniciar_uso_item()
		FASE_RUTA_ITEM:
			_avanzar_ruta_confirmada()
			if _estado.mi_pos == APROXIMACION and _tiene_item(ITEM_DINAMICO, ITEM_CERRADO):
				_usar_item(ITEM_CERRADO, FASE_ABRIR)
		FASE_ABRIR:
			if _estado.mi_pos == APROXIMACION and _tiene_item(ITEM_DINAMICO, ITEM_ACTIVO) \
					and _tiene_evento(0x6B, ITEM_DINAMICO, ITEM_ACTIVO):
				_usar_item(ITEM_ACTIVO, FASE_CERRAR)
		FASE_CERRAR:
			if _estado.mi_pos == APROXIMACION and _tiene_item(ITEM_DINAMICO, ITEM_CERRADO) \
					and _tiene_evento(0x6B, ITEM_DINAMICO, ITEM_CERRADO):
				_iniciar_retorno_bajo()
		FASE_RETORNO_BAJO:
			if _estado.mi_pos == ESCALERA_INFERIOR:
				if _origen_real.z == 6:
					_iniciar_retorno_origen()
				else:
					_fase = FASE_RETORNO_ALTO
					_reloj_fase = 0.0
					_con.enviar_auto_camino([Vector2i(0, 1)])
		FASE_RETORNO_ALTO:
			if _estado.mi_pos == ESCALERA_SUPERIOR:
				_iniciar_retorno_origen()
		FASE_RETORNO_ORIGEN:
			if _estado.mi_pos == _origen_real:
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
		_ir_tiles[Vector3i(int(posicion["x"]), int(posicion["y"]), int(posicion["z"]))] = tile
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


func _iniciar_desde_mapa() -> void:
	_origen_real = _estado.mi_pos
	if _origen_real.z == 6:
		_fase = FASE_BAJAR
		_reloj_fase = 0.0
		_iniciar_uso_item()
		return
	if _origen_real.z != 7:
		_fallo("origen no soportado para prueba de item: %s" % _origen_real)
		return
	_ruta = _buscar_ruta(_origen_real, ESCALERA_SUPERIOR)
	if _ruta.is_empty() and _origen_real != ESCALERA_SUPERIOR:
		_fallo("no encontre ruta a la escalera superior desde %s" % _origen_real)
		return
	_fase = FASE_BAJAR
	_reloj_fase = 0.0
	_fases.append({"name": "preparar_piso", "from": _posicion_json(_origen_real),
		"to": _posicion_json(ESCALERA_INFERIOR), "steps": _ruta.size()})
	if _ruta.is_empty():
		_con.enviar_auto_camino([Vector2i(0, -1)])
	else:
		_con.enviar_auto_camino(_ruta)


func _iniciar_uso_item() -> void:
	if not _tiene_item(ITEM_DINAMICO, ITEM_CERRADO):
		_fallo("el lever 2772 no esta en el mapa vivo en %s" % ITEM_DINAMICO)
		return
	_usar_item(ITEM_CERRADO, FASE_ABRIR)


func _iniciar_ruta_puerta() -> void:
	# Ruta cardinal controlada: evita que el auto-path atraviese de nuevo la
	# escalera y que el servidor aplique una subida automatica de piso.
	if _estado.mi_pos == ESCALERA_INFERIOR:
		_ruta = []
		_ruta.append(Vector2i(0, -1))
		for _i in range(5):
			_ruta.append(Vector2i(1, 0))
		for _i in range(3):
			_ruta.append(Vector2i(0, 1))
	else:
		_ruta = _buscar_ruta(_estado.mi_pos, APROXIMACION)
	if _ruta.is_empty() and _estado.mi_pos != APROXIMACION:
		_fallo("no encontre ruta al item desde %s" % _estado.mi_pos)
		return
	_fase = FASE_RUTA_ITEM
	_reloj_fase = 0.0
	_inicio_ruta = _estado.mi_pos
	_destinos_ruta.clear()
	var destino: Vector3i = _estado.mi_pos
	for paso in _ruta:
		destino += Vector3i(paso.x, paso.y, 0)
		_destinos_ruta.append(destino)
	_paso_ruta = 0
	_fases.append({"name": "aproximar_item", "from": _posicion_json(_estado.mi_pos),
		"to": _posicion_json(APROXIMACION), "steps": _ruta.size()})
	if _ruta.is_empty():
		return
	# El paso que nos dejó en la escalera puede seguir ejecutándose en la
	# cola del servidor aunque ya recibimos su 0x6D.
	_proximo_paso_en = _reloj + 1.2


func _avanzar_ruta_confirmada() -> void:
	if _paso_ruta >= _ruta.size():
		return
	if _reloj < _proximo_paso_en:
		return
	if _paso_ruta == 0 and _estado.mi_pos == _inicio_ruta:
		_enviar_siguiente_paso()
		return
	if _estado.mi_pos != _destinos_ruta[_paso_ruta]:
		return
	_paso_ruta += 1
	if _paso_ruta < _ruta.size():
		_enviar_siguiente_paso()


func _enviar_siguiente_paso() -> void:
	var paso: Vector2i = _ruta[_paso_ruta]
	var opcode := 0
	if paso == Vector2i(0, -1): opcode = 0x65
	elif paso == Vector2i(1, 0): opcode = 0x66
	elif paso == Vector2i(0, 1): opcode = 0x67
	elif paso == Vector2i(-1, 0): opcode = 0x68
	if opcode == 0:
		_fallo("ruta contiene direccion no cardinal: %s" % paso)
		return
	print("[item] paso %d/%d desde %s hacia %s opcode=0x%02X" % [
		_paso_ruta + 1, _ruta.size(), _estado.mi_pos,
		_destinos_ruta[_paso_ruta], opcode])
	_con.enviar_juego(PackedByteArray([opcode]))
	# El servidor calcula earliestWalkTime según la velocidad y el suelo;
	# 1.2 s deja terminar el TODO_WALK antes de aceptar el siguiente.
	_proximo_paso_en = _reloj + 1.2


func _al_paso_cancelado() -> void:
	print("[item] recibido 0xB5 en fase %d, posicion %s, ultimo=%s" % [
		_fase, _estado.mi_pos, _estado.ultimo_movimiento])
	_fallo("paso cancelado en fase %d" % _fase)


func _usar_item(client_id: int, siguiente_fase: int) -> void:
	var pila := _stackpos(ITEM_DINAMICO, client_id)
	if pila < 0:
		return
	_fase = siguiente_fase
	_reloj_fase = 0.0
	_fases.append({"name": "usar_item", "client_id": client_id,
		"position": _posicion_json(ITEM_DINAMICO), "stackpos": pila,
		"expected_opcode": "0x6B"})
	print("[item] usando item cli=%d stack=%d" % [client_id, pila])
	_con.enviar_usar_item(ITEM_DINAMICO, client_id, pila)


func _iniciar_retorno_bajo() -> void:
	_ruta = _buscar_ruta(_estado.mi_pos, ESCALERA_INFERIOR)
	if _ruta.is_empty() and _estado.mi_pos != ESCALERA_INFERIOR:
		_fallo("no encontre regreso a la escalera desde %s" % _estado.mi_pos)
		return
	_fase = FASE_RETORNO_BAJO
	_reloj_fase = 0.0
	_fases.append({"name": "regreso_a_escalera", "from": _posicion_json(_estado.mi_pos),
		"to": _posicion_json(ESCALERA_INFERIOR), "steps": _ruta.size()})
	if not _ruta.is_empty():
		_con.enviar_auto_camino(_ruta)


func _iniciar_retorno_origen() -> void:
	_ruta = _buscar_ruta(_estado.mi_pos, _origen_real)
	if _ruta.is_empty() and _estado.mi_pos != _origen_real:
		_fallo("no encontre regreso al origen desde %s" % _estado.mi_pos)
		return
	_fase = FASE_RETORNO_ORIGEN
	_reloj_fase = 0.0
	if _ruta.is_empty():
		_terminar_ok()
	else:
		_con.enviar_auto_camino(_ruta)


func _al_casilla_actualizada(posicion: Vector3i, opcode: int) -> void:
	if posicion != ITEM_DINAMICO:
		return
	var cid := _client_id_en(posicion)
	_eventos.append({"opcode": "0x%02X" % opcode,
		"position": _posicion_json(posicion), "client_id": cid})
	print("[item] casilla dinamica actualizada por 0x%02X: cli=%d" % [opcode, cid])


func _tiene_item(posicion: Vector3i, client_id: int) -> bool:
	return _stackpos(posicion, client_id) >= 0


func _stackpos(posicion: Vector3i, client_id: int) -> int:
	var cosas: Array = _estado.casillas.get(posicion, [])
	for i in range(cosas.size()):
		if cosas[i].get("tipo") == "item" and int(cosas[i].get("cid", 0)) == client_id:
			return i
	return -1


func _client_id_en(posicion: Vector3i) -> int:
	var cosas: Array = _estado.casillas.get(posicion, [])
	for cosa in cosas:
		if cosa.get("tipo") == "item":
			return int(cosa.get("cid", 0))
	return 0


func _tiene_evento(opcode: int, posicion: Vector3i, client_id: int) -> bool:
	var esperado := "0x%02X" % opcode
	for evento in _eventos:
		if evento["opcode"] == esperado and evento["position"] == _posicion_json(posicion) \
				and evento["client_id"] == client_id:
			return true
	return false


func _buscar_ruta(inicio: Vector3i, objetivo: Vector3i) -> Array:
	if inicio == objetivo:
		return []
	var deltas := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
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
			if anterior.has(siguiente) or siguiente == ITEM_DINAMICO:
				continue
			if siguiente != objetivo and not bool(_ir_tiles.get(siguiente, {}).get("queryadd_walkable", false)):
				continue
			anterior[siguiente] = actual
			cola.append(siguiente)
	return []


func _objetivo_de_fase() -> Vector3i:
	match _fase:
		FASE_BAJAR: return ESCALERA_INFERIOR
		FASE_RUTA_ITEM: return APROXIMACION
		FASE_RETORNO_BAJO: return ESCALERA_INFERIOR
		FASE_RETORNO_ALTO: return ESCALERA_SUPERIOR
		FASE_RETORNO_ORIGEN: return _origen_real
	return ITEM_DINAMICO


func _posicion_json(posicion: Vector3i) -> Dictionary:
	return {"x": posicion.x, "y": posicion.y, "z": posicion.z}


func _terminar_ok() -> void:
	if _terminado:
		return
	_terminado = true
	_guardar_reporte(_reporte(true, ""))
	print("[item] OK: lever 2772<->2773 por %d actualizaciones 0x6B; posicion final %s" % [
		_eventos.size(), _estado.mi_pos])
	get_tree().quit(0)


func _fallo(motivo: String) -> void:
	if _terminado:
		return
	_terminado = true
	_guardar_reporte(_reporte(false, motivo))
	print("[item] FAIL: " + motivo)
	get_tree().quit(1)


func _reporte(paso: bool, motivo: String) -> Dictionary:
	return {
		"version": 1,
		"source": {"protocol": "TVP 7.72", "state_parser": "red/estado_mundo.gd"},
		"item": {"position": _posicion_json(ITEM_DINAMICO), "inactive_client_id": ITEM_CERRADO,
			"active_client_id": ITEM_ACTIVO, "server_ids": [1945, 1946], "name": "lever"},
		"summary": {"passed": paso, "restored": _estado != null and _estado.mi_pos == _origen_real,
			"updates_0x6B": _eventos.size(), "final_position": _posicion_json(_estado.mi_pos)
				if _estado != null else {}, "error": motivo},
		"phases": _fases,
		"events": _eventos,
	}


func _guardar_reporte(reporte: Dictionary) -> void:
	var archivo := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo escribir " + REPORT_PATH)
		return
	archivo.store_string(JSON.stringify(reporte, "\t"))
