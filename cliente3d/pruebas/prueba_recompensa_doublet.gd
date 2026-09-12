extends Node

## Valida el uso de la casilla AID 1224 y la entrega del Doublet.
## Requiere que el personaje conserve la posicion de la prueba anterior.

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

var HOST := CREDENCIALES.HOST_DEFECTO
var PUERTO_LOGIN := CREDENCIALES.PUERTO_LOGIN_DEFECTO
var CUENTA := 0
var CLAVE := ""
const IR_PATH := "res://generated/maps/rookgaard_100sqm.json"
const REPORT_PATH := "res://generated/reports/doublet_reward.json"

const OBJETIVO := Vector3i(32085, 32181, 8)
const CASILLA_RECOMPENSA := Vector3i(32084, 32181, 8)
const SUELO_CLIENT_ID := 408
const DOUBLET_CLIENT_ID := 3379

var _con
var _estado
var _ir_tiles := {}
var _ruta := []
var _destinos := []
var _paso := 0
var _inicio := Vector3i.ZERO
var _proximo_paso: float = 0.0
var _fase := 0
var _reloj: float = 0.0
var _reloj_fase: float = 0.0
var _uso_enviado := false
var _recompensa_preexistente := false
var _terminado := false
var _mensajes := []


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
		_fallo("no se pudo cargar el IR")
		return
	_estado = ESTADO.new()
	_estado.inventario_actualizado.connect(_al_inventario)
	_estado.mensaje_servidor.connect(_al_mensaje)
	_estado.paso_cancelado.connect(func(): _fallo("el servidor cancelo el paso"))
	_estado.pedido_ping.connect(func(): _con.enviar_juego(PackedByteArray([0x1E])))
	_con = CONEXION.new()
	add_child(_con)
	_con.lista_personajes.connect(_al_recibir_personajes)
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.error_red.connect(_fallo)
	_con.cerrada.connect(func():
		if not _terminado:
			_fallo("conexion de juego cerrada"))
	print("[doublet-reward] pidiendo login")
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _process(delta: float) -> void:
	_reloj += delta
	_reloj_fase += delta
	if _terminado:
		return
	if _reloj > 45.0:
		_fallo("timeout en fase %d, posicion %s" % [_fase, _estado.mi_pos])
		return
	if not _estado.adentro or _estado.casillas.is_empty():
		return

	match _fase:
		0:
			if _estado.mi_pos.z != 8:
				_fallo("el personaje no esta en la sala de la Doublet: %s" % _estado.mi_pos)
			elif _estado.mi_pos == OBJETIVO:
				_fase = 1
				_reloj_fase = 0.0
				print("[doublet-reward] listo junto a la casilla AID 1224")
			else:
				_iniciar_ruta(OBJETIVO)
		1:
			if _reloj_fase >= 1.0 and not _uso_enviado:
				if _recompensa_preexistente:
					_fallo("el personaje ya tenia un Doublet antes de usar AID 1224")
					return
				if not _tiene_item_en_casilla(CASILLA_RECOMPENSA, SUELO_CLIENT_ID):
					_fallo("no encontre el suelo client 408 en la casilla AID 1224")
					return
				_uso_enviado = true
				_fase = 2
				_reloj_fase = 0.0
				print("[doublet-reward] usando suelo client=408 en %s" % CASILLA_RECOMPENSA)
				_con.enviar_usar_item(CASILLA_RECOMPENSA, SUELO_CLIENT_ID, 0, 0)
		2:
			if _reloj_fase > 8.0:
				_fallo("AID 1224 no entrego el Doublet")
		3:
			_avanzar_ruta()
			if _estado.mi_pos == OBJETIVO:
				_fase = 1
				_reloj_fase = 0.0
				print("[doublet-reward] listo junto a la casilla AID 1224")


func _al_recibir_personajes(_motd: String, personajes: Array) -> void:
	if personajes.is_empty():
		_fallo("cuenta sin personajes")
		return
	var personaje: Dictionary = personajes[0]
	_con.cerrar()
	_con.queue_free()
	_con = CONEXION.new()
	add_child(_con)
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.error_red.connect(_fallo)
	_con.cerrada.connect(func():
		if not _terminado:
			_fallo("conexion de juego cerrada"))
	var ip: String = personaje.get("ip", HOST)
	if ip == "0.0.0.0" or ip == "":
		ip = HOST
	_con.entrar_al_mundo(ip, int(personaje["puerto"]), CUENTA,
			personaje["nombre"], CLAVE)


func _cargar_ir() -> bool:
	var archivo := FileAccess.open(IR_PATH, FileAccess.READ)
	if archivo == null:
		return false
	var datos = JSON.parse_string(archivo.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY:
		return false
	for tile in datos.get("tiles", []):
		var posicion: Dictionary = tile.get("position", {})
		if posicion.has_all(["x", "y", "z"]):
			_ir_tiles[Vector3i(int(posicion["x"]), int(posicion["y"]), int(posicion["z"]))] = tile
	return not _ir_tiles.is_empty()


func _iniciar_ruta(objetivo: Vector3i) -> void:
	_ruta = _buscar_ruta(_estado.mi_pos, objetivo)
	if _ruta.is_empty() and _estado.mi_pos != objetivo:
		_fallo("no encontre ruta desde %s hasta %s" % [_estado.mi_pos, objetivo])
		return
	_fase = 3
	_inicio = _estado.mi_pos
	_destinos.clear()
	var destino: Vector3i = _estado.mi_pos
	for paso in _ruta:
		destino += Vector3i(paso.x, paso.y, 0)
		_destinos.append(destino)
	_paso = 0
	print("[doublet-reward] ruta de %s a %s: %d pasos" % [_estado.mi_pos, objetivo, _ruta.size()])
	if not _ruta.is_empty():
		_proximo_paso = _reloj + 0.8


func _avanzar_ruta() -> void:
	if _paso >= _ruta.size() or _reloj < _proximo_paso:
		return
	if _paso == 0 and _estado.mi_pos == _inicio:
		_enviar_siguiente_paso()
		return
	if _estado.mi_pos != _destinos[_paso]:
		return
	_paso += 1
	if _paso < _ruta.size():
		_enviar_siguiente_paso()


func _enviar_siguiente_paso() -> void:
	var paso: Vector2i = _ruta[_paso]
	var opcode := 0
	if paso == Vector2i(0, -1): opcode = 0x65
	elif paso == Vector2i(1, 0): opcode = 0x66
	elif paso == Vector2i(0, 1): opcode = 0x67
	elif paso == Vector2i(-1, 0): opcode = 0x68
	if opcode == 0:
		_fallo("ruta no cardinal: %s" % paso)
		return
	print("[doublet-reward] paso %d/%d hacia %s" % [_paso + 1, _ruta.size(), _destinos[_paso]])
	_con.enviar_juego(PackedByteArray([opcode]))
	_proximo_paso = _reloj + 1.2


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
			var resultado := []
			var cursor: Variant = objetivo
			while cursor != inicio:
				var previo: Vector3i = anterior[cursor]
				resultado.append(Vector2i(cursor.x - previo.x, cursor.y - previo.y))
				cursor = previo
			resultado.reverse()
			return resultado
		for delta in deltas:
			var siguiente := Vector3i(actual.x + delta.x, actual.y + delta.y, inicio.z)
			if anterior.has(siguiente) or siguiente == CASILLA_RECOMPENSA:
				continue
			if siguiente != objetivo and not bool(_ir_tiles.get(siguiente, {}).get("walkable", false)):
				continue
			anterior[siguiente] = actual
			cola.append(siguiente)
	return []


func _al_inventario(ranura: int, cosa: Dictionary) -> void:
	if cosa.get("tipo") == "item" and int(cosa.get("cid", 0)) == DOUBLET_CLIENT_ID:
		if _uso_enviado:
			_terminar_ok(ranura)
		else:
			_recompensa_preexistente = true


func _al_mensaje(texto: String) -> void:
	_mensajes.append(texto)
	print("[doublet-reward] mensaje servidor: %s" % texto)
	if _uso_enviado and texto.to_lower().contains("empty"):
		_fallo("AID 1224 respondio que la casilla esta vacia")


func _tiene_item_en_casilla(posicion: Vector3i, client_id: int) -> bool:
	for cosa in _estado.casillas.get(posicion, []):
		if cosa.get("tipo") == "item" and int(cosa.get("cid", 0)) == client_id:
			return true
	return false


func _terminar_ok(ranura: int) -> void:
	if _terminado:
		return
	_terminado = true
	_guardar_reporte({"version": 1,
		"source": {"protocol": "TVP 7.72", "opcode": "0x82"},
		"quest": {"name": "doublet", "aid": 1224,
			"trigger": _posicion_json(CASILLA_RECOMPENSA),
			"reward_server_id": 2485, "reward_client_id": DOUBLET_CLIENT_ID,
			"inventory_slot": ranura},
		"summary": {"passed": true, "messages": _mensajes.size()},
		"messages": _mensajes})
	print("[doublet-reward] OK: AID 1224 entrego el Doublet en ranura %d" % ranura)
	get_tree().quit(0)


func _fallo(motivo: String) -> void:
	if _terminado:
		return
	_terminado = true
	_guardar_reporte({"version": 1,
		"source": {"protocol": "TVP 7.72", "opcode": "0x82"},
		"summary": {"passed": false, "error": motivo},
		"messages": _mensajes})
	print("[doublet-reward] FAIL: " + motivo)
	get_tree().quit(1)


func _posicion_json(posicion: Vector3i) -> Dictionary:
	return {"x": posicion.x, "y": posicion.y, "z": posicion.z}


func _guardar_reporte(reporte: Dictionary) -> void:
	var archivo := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if archivo != null:
		archivo.store_string(JSON.stringify(reporte, "\t"))
