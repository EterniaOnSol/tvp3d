extends Node

## Valida el barril que tapa la casilla AID 1224 de la doublet quest.
## El jugador llega al piso 8, mueve el barril con 0x78 y lo devuelve.

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
const CUENTA := 123456
const CLAVE := "123456"
const IR_PATH := "res://generated/maps/rookgaard_100sqm.json"
const REPORT_PATH := "res://generated/reports/doublet_barrel.json"

const ESCALERA_INFERIOR := Vector3i(32080, 32202, 6)
const ESCALERA_SUPERIOR := Vector3i(32080, 32204, 7)
const ESCALERA_PISO_8 := Vector3i(32096, 32190, 7)
const ESCALERA_PISO_8_ARRIBA := Vector3i(32096, 32189, 7)
const ESCALERA_PISO_8_ABAJO := Vector3i(32096, 32191, 8)
const TRAMPILLA_ACCESO := Vector3i(32080, 32181, 7)
const ANTES_TRAMPILLA := Vector3i(32080, 32182, 7)
const TRAMPILLA_ABAJO := Vector3i(32080, 32181, 8)
const CERCA_BARRIL := Vector3i(32085, 32181, 8)
const BARRIL_ORIGEN := Vector3i(32084, 32181, 8)
const BARRIL_DESTINO := Vector3i(32084, 32182, 8)
const BARRIL_CLIENT_ID := 2523

var _con
var _estado
var _ir_tiles := {}
var _ruta := []
var _destinos_ruta := []
var _paso_ruta := 0
var _inicio_ruta := Vector3i.ZERO
var _proximo_paso_en: float = 0.0
var _fase: int = 0
var _reloj: float = 0.0
var _reloj_fase: float = 0.0
var _terminado := false
var _eventos := []


func _ready() -> void:
	if not _cargar_ir():
		_fallo("no se pudo cargar el IR")
		return
	_estado = ESTADO.new()
	_estado.casilla_actualizada.connect(_al_casilla_actualizada)
	_estado.paso_cancelado.connect(func(): _fallo("el servidor cancelo un paso en fase %d" % _fase))
	_estado.mensaje_servidor.connect(_al_mensaje_servidor)
	_estado.pedido_ping.connect(func(): _con.enviar_juego(PackedByteArray([0x1E])))
	_con = CONEXION.new()
	add_child(_con)
	_con.lista_personajes.connect(_al_recibir_personajes)
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.error_red.connect(_fallo)
	_con.cerrada.connect(func():
		if not _terminado:
			_fallo("conexion de juego cerrada"))
	print("[doublet] pidiendo login")
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _process(delta: float) -> void:
	_reloj += delta
	_reloj_fase += delta
	if _terminado:
		return
	if _reloj > 180.0:
		_fallo("timeout global en fase %d, posicion %s" % [_fase, _estado.mi_pos])
		return
	if not _estado.adentro or _estado.casillas.is_empty():
		return

	match _fase:
		0:
			if _estado.mi_pos.z == 7:
				_iniciar_ruta(ANTES_TRAMPILLA)
			elif _estado.mi_pos == ESCALERA_INFERIOR:
				_fase = 1
				print("[doublet] subiendo al piso 7")
				_con.enviar_juego(PackedByteArray([0x67]))
			elif _estado.mi_pos == ESCALERA_PISO_8_ABAJO:
				_fase = 7
				_reloj_fase = 0.0
				print("[doublet] subiendo de la escalera del piso 8")
				_con.enviar_juego(PackedByteArray([0x65]))
			elif _estado.mi_pos.z == 8:
				_iniciar_ruta(CERCA_BARRIL)
		1:
			if _estado.mi_pos == ESCALERA_SUPERIOR:
				_iniciar_ruta(ANTES_TRAMPILLA)
		2:
			_avanzar_ruta_confirmada()
			if _estado.mi_pos == ANTES_TRAMPILLA:
				_fase = 3
				_reloj_fase = 0.0
				print("[doublet] entrando por trampilla %s" % TRAMPILLA_ACCESO)
				_con.enviar_juego(PackedByteArray([0x65]))
		3:
			if _estado.mi_pos == TRAMPILLA_ABAJO:
				_iniciar_ruta(CERCA_BARRIL)
		4:
			_avanzar_ruta_confirmada()
			if _estado.mi_pos == CERCA_BARRIL:
				_enviar_movimiento(BARRIL_ORIGEN, BARRIL_DESTINO)
		5:
			if _tiene_item(BARRIL_DESTINO) and not _tiene_item(BARRIL_ORIGEN):
				_enviar_movimiento(BARRIL_DESTINO, BARRIL_ORIGEN)
		6:
			if _tiene_item(BARRIL_ORIGEN) and not _tiene_item(BARRIL_DESTINO):
				_terminar_ok()
		7:
			if _estado.mi_pos == ESCALERA_PISO_8_ARRIBA:
				_iniciar_ruta(ANTES_TRAMPILLA)


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


func _iniciar_ruta(objetivo: Vector3i) -> void:
	_ruta = _buscar_ruta(_estado.mi_pos, objetivo)
	if _ruta.is_empty() and _estado.mi_pos != objetivo:
		_fallo("no encontre ruta desde %s hasta %s" % [_estado.mi_pos, objetivo])
		return
	_fase = 2 if objetivo == ANTES_TRAMPILLA else 4
	_reloj_fase = 0.0
	_inicio_ruta = _estado.mi_pos
	_destinos_ruta.clear()
	var destino: Vector3i = _estado.mi_pos
	for paso in _ruta:
		destino += Vector3i(paso.x, paso.y, 0)
		_destinos_ruta.append(destino)
	_paso_ruta = 0
	print("[doublet] ruta de %s a %s: %d pasos" % [_estado.mi_pos, objetivo, _ruta.size()])
	if not _ruta.is_empty():
		# El servidor puede rechazar un paso de un 0x64 largo aunque el IR lo
		# marque libre. Confirmamos cada 0x65-0x68 antes de seguir.
		_proximo_paso_en = _reloj + 0.8


func _avanzar_ruta_confirmada() -> void:
	if _paso_ruta >= _ruta.size() or _reloj < _proximo_paso_en:
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
	print("[doublet] paso %d/%d desde %s hacia %s opcode=0x%02X" % [
		_paso_ruta + 1, _ruta.size(), _estado.mi_pos,
		_destinos_ruta[_paso_ruta], opcode])
	_con.enviar_juego(PackedByteArray([opcode]))
	_proximo_paso_en = _reloj + 1.2


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
			if anterior.has(siguiente) or siguiente == BARRIL_ORIGEN:
				continue
			if siguiente != objetivo and not bool(_ir_tiles.get(siguiente, {}).get("walkable", false)):
				continue
			anterior[siguiente] = actual
			cola.append(siguiente)
	return []


func _enviar_movimiento(origen: Vector3i, destino: Vector3i) -> void:
	var pila := _stackpos(origen)
	if pila < 0:
		_fallo("no encontre barril en %s" % origen)
		return
	_fase = 5 if origen == BARRIL_ORIGEN else 6
	print("[doublet] moviendo barril stack=%d desde %s hacia %s" % [pila, origen, destino])
	_con.enviar_mover_cosa(origen, BARRIL_CLIENT_ID, pila, destino)


func _al_casilla_actualizada(posicion: Vector3i, opcode: int) -> void:
	if posicion not in [BARRIL_ORIGEN, BARRIL_DESTINO]:
		return
	_eventos.append({"opcode": "0x%02X" % opcode, "position": _posicion_json(posicion),
		"barrel_present": _tiene_item(posicion)})
	print("[doublet] casilla %s por 0x%02X; barril=%s" % [
		posicion, opcode, _tiene_item(posicion)])


func _al_mensaje_servidor(texto: String) -> void:
	print("[doublet] mensaje servidor: %s" % texto)
	if texto.to_lower().contains("no way") or texto.to_lower().contains("not possible"):
		_fallo("servidor rechazo la operacion: %s" % texto)


func _stackpos(posicion: Vector3i) -> int:
	var cosas: Array = _estado.casillas.get(posicion, [])
	for i in range(cosas.size()):
		if cosas[i].get("tipo") == "item" and int(cosas[i].get("cid", 0)) == BARRIL_CLIENT_ID:
			return i
	return -1


func _tiene_item(posicion: Vector3i) -> bool:
	return _stackpos(posicion) >= 0


func _posicion_json(posicion: Vector3i) -> Dictionary:
	return {"x": posicion.x, "y": posicion.y, "z": posicion.z}


func _terminar_ok() -> void:
	if _terminado:
		return
	_terminado = true
	_guardar_reporte({"version": 1, "source": {"protocol": "TVP 7.72", "opcode": "0x78"},
		"quest": {"name": "doublet", "aid": 1224,
			"barrel": _posicion_json(BARRIL_ORIGEN),
			"destination": _posicion_json(BARRIL_DESTINO)},
		"summary": {"passed": true, "restored": _tiene_item(BARRIL_ORIGEN),
			"events": _eventos.size(), "final_position": _posicion_json(_estado.mi_pos)},
		"events": _eventos})
	print("[doublet] OK: barril movido y restaurado")
	get_tree().quit(0)


func _fallo(motivo: String) -> void:
	if _terminado:
		return
	_terminado = true
	_guardar_reporte({"version": 1, "source": {"protocol": "TVP 7.72", "opcode": "0x78"},
		"summary": {"passed": false, "error": motivo,
			"final_position": _posicion_json(_estado.mi_pos) if _estado != null else {}},
		"events": _eventos})
	print("[doublet] FAIL: " + motivo)
	get_tree().quit(1)


func _guardar_reporte(reporte: Dictionary) -> void:
	var archivo := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if archivo != null:
		archivo.store_string(JSON.stringify(reporte, "\t"))
