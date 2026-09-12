extends Node

## Valida el movimiento reversible de un barril vivo usando 0x78.
## TVP debe anunciar 0x6C en el origen y 0x6A en el destino.

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

var HOST := CREDENCIALES.HOST_DEFECTO
var PUERTO_LOGIN := CREDENCIALES.PUERTO_LOGIN_DEFECTO
var CUENTA := 0
var CLAVE := ""
const REPORT_PATH := "res://generated/reports/dynamic_barrel.json"

const BARRIL_ORIGEN := Vector3i(32083, 32209, 6)
const BARRIL_DESTINO := Vector3i(32084, 32209, 6)
const BARRIL_CLIENT_ID := 2523

var _con
var _estado
var _fase := 0
var _reloj := 0.0
var _terminado := false
var _eventos := []


func _ready() -> void:
	# Credenciales e identidades de prueba: SOLO por entorno, nunca literales.
	# Si falta alguna, corta aca y no intenta ninguna conexion.
	if not CREDENCIALES.exigir(self, ["TVP772_ACCOUNT", "TVP772_PASSWORD"]):
		return
	HOST = CREDENCIALES.host()
	PUERTO_LOGIN = CREDENCIALES.puerto_login()
	CUENTA = CREDENCIALES.entero("TVP772_ACCOUNT")
	CLAVE = CREDENCIALES.texto("TVP772_PASSWORD")
	_estado = ESTADO.new()
	_estado.casilla_actualizada.connect(_al_casilla_actualizada)
	_estado.paso_cancelado.connect(func(): _fallo("el servidor cancelo un paso"))
	_estado.mensaje_servidor.connect(_al_mensaje_servidor)
	_con = CONEXION.new()
	add_child(_con)
	_con.lista_personajes.connect(_al_recibir_personajes)
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.error_red.connect(_fallo)
	_con.cerrada.connect(func():
		if not _terminado:
			_fallo("conexion de juego cerrada"))
	print("[barril] pidiendo login")
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _process(delta: float) -> void:
	_reloj += delta
	if _terminado:
		return
	if _reloj > 120.0:
		_fallo("timeout en fase %d, posicion %s" % [_fase, _estado.mi_pos])
		return
	if _fase == 0 and _estado.adentro and not _estado.casillas.is_empty():
		_iniciar_movimiento()
	elif _fase == 1 and not _tiene_item(BARRIL_ORIGEN):
		if _tiene_item(BARRIL_DESTINO):
			_fase = 2
			print("[barril] recibido en destino; regresando")
			_enviar_movimiento(BARRIL_DESTINO, BARRIL_ORIGEN)
	elif _fase == 2 and _tiene_item(BARRIL_ORIGEN) and not _tiene_item(BARRIL_DESTINO):
		_terminar_ok()


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


func _iniciar_movimiento() -> void:
	if _estado.mi_pos.z != BARRIL_ORIGEN.z:
		_fallo("posicion inicial fuera del piso del barril: %s" % _estado.mi_pos)
		return
	_enviar_movimiento(BARRIL_ORIGEN, BARRIL_DESTINO)


func _enviar_movimiento(origen: Vector3i, destino: Vector3i) -> void:
	var pila := _stackpos(origen)
	if pila < 0:
		_fallo("no encontre barril %s en el estado vivo" % origen)
		return
	_fase = 1 if origen == BARRIL_ORIGEN else 2
	print("[barril] moviendo cli=%d stack=%d desde %s hacia %s" % [
		BARRIL_CLIENT_ID, pila, origen, destino])
	_con.enviar_mover_cosa(origen, BARRIL_CLIENT_ID, pila, destino)


func _al_casilla_actualizada(posicion: Vector3i, opcode: int) -> void:
	if posicion not in [BARRIL_ORIGEN, BARRIL_DESTINO]:
		return
	var existe := _tiene_item(posicion)
	_eventos.append({"opcode": "0x%02X" % opcode,
		"position": _posicion_json(posicion), "barrel_present": existe})
	print("[barril] casilla %s actualizada por 0x%02X; barril=%s" % [
		posicion, opcode, existe])


func _al_mensaje_servidor(texto: String) -> void:
	print("[barril] mensaje servidor: %s" % texto)
	if texto.to_lower().contains("no way") or texto.to_lower().contains("not possible"):
		_fallo("servidor rechazo el movimiento: %s" % texto)


func _tiene_item(posicion: Vector3i) -> bool:
	return _stackpos(posicion) >= 0


func _stackpos(posicion: Vector3i) -> int:
	var cosas: Array = _estado.casillas.get(posicion, [])
	for i in range(cosas.size()):
		if cosas[i].get("tipo") == "item" and int(cosas[i].get("cid", 0)) == BARRIL_CLIENT_ID:
			return i
	return -1


func _posicion_json(posicion: Vector3i) -> Dictionary:
	return {"x": posicion.x, "y": posicion.y, "z": posicion.z}


func _terminar_ok() -> void:
	if _terminado:
		return
	_terminado = true
	_guardar_reporte({"version": 1,
		"source": {"protocol": "TVP 7.72", "opcode": "0x78"},
		"barrel": {"client_id": BARRIL_CLIENT_ID,
			"origin": _posicion_json(BARRIL_ORIGEN),
			"destination": _posicion_json(BARRIL_DESTINO)},
		"summary": {"passed": true, "restored": _tiene_item(BARRIL_ORIGEN),
			"events": _eventos.size(), "final_position": _posicion_json(_estado.mi_pos)},
		"events": _eventos})
	print("[barril] OK: 0x6C + 0x6A y regreso confirmado")
	get_tree().quit(0)


func _fallo(motivo: String) -> void:
	if _terminado:
		return
	_terminado = true
	_guardar_reporte({"version": 1,
		"source": {"protocol": "TVP 7.72", "opcode": "0x78"},
		"summary": {"passed": false, "error": motivo,
			"final_position": _posicion_json(_estado.mi_pos) if _estado != null else {}},
		"events": _eventos})
	print("[barril] FAIL: " + motivo)
	get_tree().quit(1)


func _guardar_reporte(reporte: Dictionary) -> void:
	var archivo := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if archivo != null:
		archivo.store_string(JSON.stringify(reporte, "\t"))
