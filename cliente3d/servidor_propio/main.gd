extends Node

## Servidor autoritativo inicial de TVP3D.
## Corre sin renderizar con Godot --headless y carga el mismo mapa que usa
## el editor. El cliente nunca decide si una casilla es caminable.

const PROTOCOLO := preload("res://comun/protocolo_tvp3d.gd")
const MAPA := preload("res://comun/mapa_tvp3d.gd")

const HOST := "127.0.0.1"
const PUERTO := 7277
const RUTA_MAPA := MAPA.RUTA_MAPA
const MAX_CLIENTES := 16
const MODO_MAPA_ENV := "TVP3D_MAPA_MODO"

var _servidor := TCPServer.new()
var _mapa: MapaTVP3D
var _posicion_inicial := Vector3i.ZERO
var _siguiente_id := 1
var _clientes: Dictionary = {}
var _transiciones: Array = []


func _ready() -> void:
	var carga := MAPA.cargar_validado(RUTA_MAPA)
	if bool(carga.get("ok", false)):
		_mapa = carga["mapa"]
	else:
		var error_mapa := str(carga.get("error", "MAPA_INVALIDO"))
		if error_mapa != "MAPA_ARCHIVO_AUSENTE" or not _modo_demo_permitido():
			push_error("No se pudo cargar el mapa: %s" % error_mapa)
			get_tree().quit(2)
			return
		_mapa = MAPA.new()
		print("Mapa ausente; usando mapa demo determinista (modo demo)")
	_posicion_inicial = _mapa.posicion_inicial()
	var resultado := _servidor.listen(PUERTO, HOST)
	if resultado != OK:
		push_error("No se pudo escuchar en %s:%d (error %s)" % [HOST, PUERTO, resultado])
		get_tree().quit(1)
		return

	print("=========================================")
	print(" TVP3D - servidor Godot propio")
	print("=========================================")
	print("Escuchando en %s:%d" % [HOST, PUERTO])
	print("Mapa: %dx%d desde %s" % [_mapa.ancho, _mapa.alto, _mapa.origen])
	print("Posicion inicial: %s" % _posicion_inicial)


func _process(_delta: float) -> void:
	while _servidor.is_connection_available():
		_registrar_cliente(_servidor.take_connection())

	for id in _clientes.keys():
		if not _clientes.has(id):
			continue
		_procesar_cliente(int(id))


func _registrar_cliente(peer: StreamPeerTCP) -> void:
	if peer == null:
		return
	if _clientes.size() >= MAX_CLIENTES:
		peer.set_no_delay(true)
		peer.put_data(PROTOCOLO.empaquetar(PROTOCOLO.Tipo.ERROR, {
			"mensaje": "SERVIDOR_LLENO",
		}))
		peer.disconnect_from_host()
		return
	var posicion := _posicion_inicial_para_nuevo()
	if not _puede_caminar(posicion):
		peer.set_no_delay(true)
		peer.put_data(PROTOCOLO.empaquetar(PROTOCOLO.Tipo.ERROR, {
			"mensaje": "MUNDO_SIN_CASILLAS",
		}))
		peer.disconnect_from_host()
		return
	peer.set_no_delay(true)
	var id := _siguiente_id
	_siguiente_id += 1
	_clientes[id] = {
		"peer": peer,
		"buffer": PackedByteArray(),
		"nombre": "",
		"pos": posicion,
		"direccion": "sur",
		"listo": false,
	}
	print("Conexion recibida: jugador %d" % id)


func _procesar_cliente(id: int) -> void:
	var cliente: Dictionary = _clientes[id]
	var peer: StreamPeerTCP = cliente["peer"]
	peer.poll()
	if peer.get_status() == StreamPeerTCP.STATUS_ERROR \
			or peer.get_status() == StreamPeerTCP.STATUS_NONE:
		_desconectar(id)
		return

	var disponibles := peer.get_available_bytes()
	if disponibles <= 0:
		return
	var recibido: Array = peer.get_data(disponibles)
	if recibido[0] != OK:
		_desconectar(id)
		return
	cliente["buffer"].append_array(recibido[1])

	var resultado: Dictionary = PROTOCOLO.extraer(cliente["buffer"])
	cliente["buffer"] = resultado["buffer"]
	_clientes[id] = cliente
	if resultado["error"] != "":
		_enviar_error(id, resultado["error"])
		_desconectar(id)
		return

	for mensaje in resultado["mensajes"]:
		if not _clientes.has(id):
			return
		_procesar_mensaje(id, mensaje)


func _procesar_mensaje(id: int, mensaje: Dictionary) -> void:
	var tipo: int = mensaje["tipo"]
	var datos: Dictionary = mensaje["datos"]
	if tipo == PROTOCOLO.Tipo.WELCOME or tipo == PROTOCOLO.Tipo.STATE \
			or tipo == PROTOCOLO.Tipo.ERROR or tipo == PROTOCOLO.Tipo.PONG:
		_enviar_error(id, "OPCODE_NO_PERMITIDO")
		_desconectar(id)
		return

	match tipo:
		PROTOCOLO.Tipo.HELLO:
			_recibir_hello(id, datos)
		PROTOCOLO.Tipo.MOVE:
			_recibir_movimiento(id, datos)
		PROTOCOLO.Tipo.PING:
			_enviar(id, PROTOCOLO.Tipo.PONG, {})
		PROTOCOLO.Tipo.GOODBYE:
			_desconectar(id)
		_:
			_enviar_error(id, "OPCODE_NO_PERMITIDO")
			_desconectar(id)


func _recibir_hello(id: int, datos: Dictionary) -> void:
	var cliente: Dictionary = _clientes[id]
	if cliente["listo"]:
		_enviar_error(id, "HELLO_DUPLICADO")
		_desconectar(id)
		return
	var nombre := str(datos.get("nombre", "Jugador %d" % id)).strip_edges()
	if nombre.is_empty():
		nombre = "Jugador %d" % id
	cliente["nombre"] = nombre.left(24)
	cliente["listo"] = true
	_clientes[id] = cliente

	_enviar(id, PROTOCOLO.Tipo.WELCOME, {
		"id": id,
		"nombre": cliente["nombre"],
		"pos": PROTOCOLO.posicion_a_diccionario(cliente["pos"]),
		"mapa": _mapa.a_diccionario(),
	})
	print("Jugador %d entro como %s" % [id, cliente["nombre"]])
	_broadcast_estado()


func _recibir_movimiento(id: int, datos: Dictionary) -> void:
	if not _clientes[id]["listo"]:
		_registrar_transicion(id, "SOLICITADA", "RECHAZADA", Vector3i.ZERO,
			"IDENTIFICACION_REQUERIDA")
		_enviar_error(id, "IDENTIFICACION_REQUERIDA")
		return

	var dx := int(datos.get("dx", 0))
	var dy := int(datos.get("dy", 0))
	if absi(dx) + absi(dy) != 1:
		_registrar_transicion(id, "SOLICITADA", "RECHAZADA", Vector3i.ZERO,
			"MOVIMIENTO_NO_CARDINAL")
		_enviar_error(id, "MOVIMIENTO_NO_CARDINAL")
		return

	var cliente: Dictionary = _clientes[id]
	var actual: Vector3i = cliente["pos"]
	var nueva := actual + Vector3i(dx, dy, 0)
	_registrar_transicion(id, "SOLICITADA", "SOLICITADA", nueva, "")
	if not _puede_caminar(nueva):
		_registrar_transicion(id, "SOLICITADA", "RECHAZADA", nueva,
			"MOVIMIENTO_BLOQUEADO")
		_enviar_error(id, "MOVIMIENTO_BLOQUEADO")
		return
	if _ocupada_por_otro(id, nueva):
		_registrar_transicion(id, "SOLICITADA", "RECHAZADA", nueva,
			"MOVIMIENTO_OCUPADO")
		_enviar_error(id, "MOVIMIENTO_OCUPADO")
		return

	_registrar_transicion(id, "SOLICITADA", "VALIDADA", nueva, "")
	cliente["pos"] = nueva
	cliente["direccion"] = _direccion_de(dx, dy)
	_clientes[id] = cliente
	_registrar_transicion(id, "VALIDADA", "APLICADA", nueva, "")
	print("%s camino a %s" % [cliente["nombre"], nueva])
	_registrar_transicion(id, "APLICADA", "EMITIDA", nueva, "")
	_broadcast_estado()


func _puede_caminar(posicion: Vector3i) -> bool:
	return _mapa.es_caminable(posicion)


func _ocupada_por_otro(id: int, posicion: Vector3i) -> bool:
	for otro_id in _clientes:
		if int(otro_id) == id:
			continue
		var otro: Dictionary = _clientes[otro_id]
		if otro["listo"] and otro["pos"] == posicion:
			return true
	return false


func _direccion_de(dx: int, dy: int) -> String:
	if dy < 0:
		return "norte"
	if dx > 0:
		return "este"
	if dy > 0:
		return "sur"
	return "oeste"


func _broadcast_estado() -> void:
	var jugadores: Array = []
	var ids: Array = _clientes.keys()
	ids.sort()
	for id_sin_tipo in ids:
		var id := int(id_sin_tipo)
		var cliente: Dictionary = _clientes[id]
		if not cliente["listo"]:
			continue
		jugadores.append({
			"id": int(id),
			"nombre": cliente["nombre"],
			"pos": PROTOCOLO.posicion_a_diccionario(cliente["pos"]),
			"direccion": cliente["direccion"],
		})

	for id_sin_tipo in ids:
		var id := int(id_sin_tipo)
		if _clientes[id]["listo"]:
			_enviar(id, PROTOCOLO.Tipo.STATE, {"jugadores": jugadores})


func _enviar(id: int, tipo: int, datos: Dictionary) -> void:
	if not _clientes.has(id):
		return
	var peer: StreamPeerTCP = _clientes[id]["peer"]
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var paquete := PROTOCOLO.empaquetar(tipo, datos)
	if paquete.is_empty():
		return
	var resultado := peer.put_data(paquete)
	if resultado != OK:
		_desconectar(id)


func _enviar_error(id: int, texto: String) -> void:
	_enviar(id, PROTOCOLO.Tipo.ERROR, {"mensaje": texto})


func _desconectar(id: int) -> void:
	if not _clientes.has(id):
		return
	var cliente: Dictionary = _clientes[id]
	var peer: StreamPeerTCP = cliente["peer"]
	peer.disconnect_from_host()
	_clientes.erase(id)
	print("Jugador %d desconectado" % id)
	_broadcast_estado()


func _modo_demo_permitido() -> bool:
	var modo := OS.get_environment(MODO_MAPA_ENV).strip_edges().to_lower()
	return modo.is_empty() or modo == "demo"


func _posicion_inicial_para_nuevo() -> Vector3i:
	var preferida := _posicion_inicial
	if _puede_caminar(preferida) and not _posicion_en_uso(0, preferida):
		return preferida
	var vecinos := [
		Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(-1, 0, 0),
		Vector3i(0, -1, 0),
	]
	for desplazamiento in vecinos:
		var candidata: Vector3i = preferida + desplazamiento
		if _puede_caminar(candidata) and not _posicion_en_uso(0, candidata):
			return candidata
	for radio in range(1, max(_mapa.ancho, _mapa.alto)):
		for y in range(_mapa.alto):
			for x in range(_mapa.ancho):
				if absi(x - 12) > radio or absi(y - 9) > radio:
					continue
				var candidata: Vector3i = _mapa.origen + Vector3i(x, y, 0)
				if _puede_caminar(candidata) and not _posicion_en_uso(0, candidata):
					return candidata
	return Vector3i.ZERO


func _posicion_en_uso(id: int, posicion: Vector3i) -> bool:
	for otro_id in _clientes:
		if int(otro_id) == id:
			continue
		var otro: Dictionary = _clientes[otro_id]
		if otro["pos"] == posicion:
			return true
	return false


func _registrar_transicion(id: int, estado: String, resultado: String,
		posicion: Vector3i, motivo: String) -> void:
	_transiciones.append({
		"jugador_id": id,
		"estado": estado,
		"accion": "MOVER",
		"resultado": null if resultado in ["RECHAZADA", "SOLICITADA"] else PROTOCOLO.posicion_a_diccionario(posicion),
		"motivo": motivo,
	})
	if _transiciones.size() > 256:
		_transiciones.pop_front()
