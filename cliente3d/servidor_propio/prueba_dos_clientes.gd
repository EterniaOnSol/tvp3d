extends Node

## Prueba de integracion del carril servidor.
## Se ejecuta con servidor_propio/servidor.tscn ya escuchando en 127.0.0.1:7277.

const PROTOCOLO := preload("res://comun/protocolo_tvp3d.gd")

const HOST := "127.0.0.1"
const PUERTO := 7277
const NOMBRES := ["Ana", "Beto"]
const TIEMPO_MAXIMO := 12.0

var _clientes: Array = []
var _reloj := 0.0
var _movimiento_enviado := false
var _esperando_rechazo := false
var _terminando := false


func _ready() -> void:
	for nombre in NOMBRES:
		var peer := StreamPeerTCP.new()
		var resultado := peer.connect_to_host(HOST, PUERTO)
		if resultado != OK:
			_fallar("No se pudo conectar %s: %s" % [nombre, resultado])
			return
		_clientes.append({
			"nombre": nombre,
			"peer": peer,
			"buffer": PackedByteArray(),
			"hello_enviado": false,
			"welcome": false,
			"id": 0,
			"jugadores": [],
		})
	print("Dos clientes conectando a %s:%d ..." % [HOST, PUERTO])


func _process(delta: float) -> void:
	if _terminando:
		return
	_reloj += delta
	if _reloj > TIEMPO_MAXIMO:
		_fallar("Se agoto el tiempo de la prueba")
		return

	for indice in _clientes.size():
		_procesar_cliente(indice)
		if _terminando:
			return

	if _listos_los_dos() and not _movimiento_enviado:
		_ejecutar_prueba_ocupacion()


func _procesar_cliente(indice: int) -> void:
	var cliente: Dictionary = _clientes[indice]
	var peer: StreamPeerTCP = cliente["peer"]
	peer.poll()
	if peer.get_status() == StreamPeerTCP.STATUS_ERROR \
			or peer.get_status() == StreamPeerTCP.STATUS_NONE:
		_fallar("Conexion perdida para %s" % cliente["nombre"])
		return

	if not cliente["hello_enviado"] \
			and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_enviar(indice, PROTOCOLO.Tipo.HELLO, {"nombre": cliente["nombre"]})
		cliente["hello_enviado"] = true
		_clientes[indice] = cliente

	var disponibles := peer.get_available_bytes()
	if disponibles <= 0:
		return
	var recibido: Array = peer.get_data(disponibles)
	if recibido[0] != OK:
		_fallar("Error leyendo a %s" % cliente["nombre"])
		return
	cliente["buffer"].append_array(recibido[1])
	var resultado: Dictionary = PROTOCOLO.extraer(cliente["buffer"])
	cliente["buffer"] = resultado["buffer"]
	_clientes[indice] = cliente
	if resultado["error"] != "":
		_fallar("Error de protocolo para %s: %s" % [cliente["nombre"], resultado["error"]])
		return
	for mensaje in resultado["mensajes"]:
		_procesar_mensaje(indice, mensaje)
		if _terminando:
			return


func _procesar_mensaje(indice: int, mensaje: Dictionary) -> void:
	var cliente: Dictionary = _clientes[indice]
	match int(mensaje["tipo"]):
		PROTOCOLO.Tipo.WELCOME:
			cliente["welcome"] = true
			cliente["id"] = int(mensaje["datos"]["id"])
			print("WELCOME %s: id=%d" % [cliente["nombre"], cliente["id"]])
		PROTOCOLO.Tipo.STATE:
			cliente["jugadores"] = mensaje["datos"].get("jugadores", [])
		PROTOCOLO.Tipo.ERROR:
			var texto := str(mensaje["datos"].get("mensaje", ""))
			if _esperando_rechazo and indice == 1 and texto == "MOVIMIENTO_OCUPADO":
				print("OK ocupacion: Beto no puede ocupar la casilla de Ana")
				_terminar(0)
				return
			_fallar("Error inesperado de %s: %s" % [cliente["nombre"], texto])
			return
		_:
			_fallar("Opcode inesperado: %d" % mensaje["tipo"])
			return
	_clientes[indice] = cliente


func _listos_los_dos() -> bool:
	for cliente in _clientes:
		if not cliente["welcome"] or cliente["jugadores"].size() < 2:
			return false
	return true


func _ejecutar_prueba_ocupacion() -> void:
	var jugadores_a: Array = _clientes[0]["jugadores"]
	var jugadores_b: Array = _clientes[1]["jugadores"]
	if jugadores_a != jugadores_b:
		_fallar("Los dos clientes no recibieron el mismo STATE")
		return
	var id_a := int(_clientes[0]["id"])
	var id_b := int(_clientes[1]["id"])
	var pos_a := _posicion_de(jugadores_a, id_a)
	var pos_b := _posicion_de(jugadores_a, id_b)
	if pos_a.is_empty() or pos_b.is_empty():
		_fallar("Faltan entidades en STATE")
		return
	if int(pos_b["x"]) != int(pos_a["x"]) + 1 \
			or int(pos_b["y"]) != int(pos_a["y"]):
		_fallar("Las posiciones iniciales no permiten probar ocupacion")
		return

	_enviar(1, PROTOCOLO.Tipo.MOVE, {"dx": -1, "dy": 0})
	_movimiento_enviado = true
	_esperando_rechazo = true
	print("Movimiento de Beto hacia la casilla ocupada enviado")


func _posicion_de(jugadores: Array, id: int) -> Dictionary:
	for jugador in jugadores:
		if int(jugador.get("id", 0)) == id:
			return jugador.get("pos", {})
	return {}


func _enviar(indice: int, tipo: int, datos: Dictionary) -> void:
	var peer: StreamPeerTCP = _clientes[indice]["peer"]
	var paquete := PROTOCOLO.empaquetar(tipo, datos)
	if paquete.is_empty() or peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	peer.put_data(paquete)


func _fallar(mensaje: String) -> void:
	print("FALLO: %s" % mensaje)
	_terminar(1)


func _terminar(codigo: int) -> void:
	if _terminando:
		return
	_terminando = true
	for indice in _clientes.size():
		var peer: StreamPeerTCP = _clientes[indice]["peer"]
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			peer.put_data(PROTOCOLO.empaquetar(PROTOCOLO.Tipo.GOODBYE, {}))
			peer.disconnect_from_host()
	print("Resultado dos clientes: %s" % ("OK" if codigo == 0 else "FALLO"))
	get_tree().quit(codigo)
