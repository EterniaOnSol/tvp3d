extends Node

## Servidor autoritativo inicial de TVP3D.
## Corre sin renderizar con Godot --headless y carga el mismo mapa que usa
## el editor. El cliente nunca decide si una casilla es caminable.

const PROTOCOLO := preload("res://comun/protocolo_tvp3d.gd")
const MAPA := preload("res://comun/mapa_tvp3d.gd")

const HOST := "127.0.0.1"
const PUERTO := 7277
const RUTA_MAPA := MAPA.RUTA_MAPA

var _servidor := TCPServer.new()
var _mapa: MapaTVP3D
var _posicion_inicial := Vector3i.ZERO
var _siguiente_id := 1
var _clientes: Dictionary = {}


func _ready() -> void:
	_mapa = MAPA.cargar(RUTA_MAPA)
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
	peer.set_no_delay(true)
	var id := _siguiente_id
	_siguiente_id += 1
	_clientes[id] = {
		"peer": peer,
		"buffer": PackedByteArray(),
		"nombre": "",
		"pos": _posicion_inicial,
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
			_enviar_error(id, "Opcode desconocido: %d" % tipo)


func _recibir_hello(id: int, datos: Dictionary) -> void:
	var cliente: Dictionary = _clientes[id]
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
		_enviar_error(id, "Primero hay que identificarse")
		return

	var dx := clampi(int(datos.get("dx", 0)), -1, 1)
	var dy := clampi(int(datos.get("dy", 0)), -1, 1)
	if absi(dx) + absi(dy) != 1:
		_enviar_error(id, "Movimiento invalido")
		return

	var cliente: Dictionary = _clientes[id]
	var actual: Vector3i = cliente["pos"]
	var nueva := actual + Vector3i(dx, dy, 0)
	if not _puede_caminar(nueva) or _ocupada_por_otro(id, nueva):
		return

	cliente["pos"] = nueva
	cliente["direccion"] = _direccion_de(dx, dy)
	_clientes[id] = cliente
	print("%s camino a %s" % [cliente["nombre"], nueva])
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
	for id in _clientes:
		var cliente: Dictionary = _clientes[id]
		if not cliente["listo"]:
			continue
		jugadores.append({
			"id": int(id),
			"nombre": cliente["nombre"],
			"pos": PROTOCOLO.posicion_a_diccionario(cliente["pos"]),
			"direccion": cliente["direccion"],
		})

	for id in _clientes:
		if _clientes[id]["listo"]:
			_enviar(int(id), PROTOCOLO.Tipo.STATE, {"jugadores": jugadores})


func _enviar(id: int, tipo: int, datos: Dictionary) -> void:
	if not _clientes.has(id):
		return
	var peer: StreamPeerTCP = _clientes[id]["peer"]
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	peer.put_data(PROTOCOLO.empaquetar(tipo, datos))


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
