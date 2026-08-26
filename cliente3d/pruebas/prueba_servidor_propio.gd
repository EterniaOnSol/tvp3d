extends Node

## Cliente de consola para comprobar el servidor Godot propio.
## No depende del protocolo TVP 7.72; usa exactamente la capa comun.

const PROTOCOLO := preload("res://comun/protocolo_tvp3d.gd")

const HOST := "127.0.0.1"
const PUERTO := 7277
const NOMBRE := "Prueba"
const MOVIMIENTOS := [
	{"dx": 1, "dy": 0, "nombre": "este"},
	{"dx": 0, "dy": 1, "nombre": "sur"},
	{"dx": -1, "dy": 0, "nombre": "oeste"},
	{"dx": 0, "dy": -1, "nombre": "norte"},
]

var _peer := StreamPeerTCP.new()
var _buffer := PackedByteArray()
var _reloj := 0.0
var _reloj_movimiento := 0.0
var _indice_movimiento := 0
var _conectado := false
var _listo := false
var _estados := 0
var _fallas := 0


func _ready() -> void:
	print("=========================================")
	print(" TVP3D - prueba del servidor Godot propio")
	print("=========================================")
	var resultado := _peer.connect_to_host(HOST, PUERTO)
	if resultado != OK:
		_fallar("No se pudo conectar: %s" % resultado)
		return
	print("Conectando a %s:%d ..." % [HOST, PUERTO])


func _process(delta: float) -> void:
	_reloj += delta
	if _reloj > 15.0:
		_fallar("Se agoto el tiempo de la prueba")
		return

	_peer.poll()
	if _peer.get_status() == StreamPeerTCP.STATUS_ERROR \
			or _peer.get_status() == StreamPeerTCP.STATUS_NONE:
		if _conectado:
			_fallar("El servidor cerro la conexion")
		return

	if not _conectado and _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_conectado = true
		_enviar(PROTOCOLO.Tipo.HELLO, {"nombre": NOMBRE})
		print("Conexion establecida; enviando HELLO")

	var disponibles := _peer.get_available_bytes()
	if disponibles > 0:
		var recibido: Array = _peer.get_data(disponibles)
		if recibido[0] != OK:
			_fallar("Error leyendo del servidor")
			return
		_buffer.append_array(recibido[1])
		var resultado: Dictionary = PROTOCOLO.extraer(_buffer)
		_buffer = resultado["buffer"]
		if resultado["error"] != "":
			_fallar(resultado["error"])
			return
		for mensaje in resultado["mensajes"]:
			_recibir(mensaje)

	if _listo:
		_reloj_movimiento += delta
		if _indice_movimiento < MOVIMIENTOS.size() and _reloj_movimiento >= 0.5:
			var movimiento: Dictionary = MOVIMIENTOS[_indice_movimiento]
			_enviar(PROTOCOLO.Tipo.MOVE, {
				"dx": movimiento["dx"],
				"dy": movimiento["dy"],
			})
			print("Paso enviado: %s" % movimiento["nombre"])
			_indice_movimiento += 1
			_reloj_movimiento = 0.0
		elif _indice_movimiento == MOVIMIENTOS.size() and _estados >= MOVIMIENTOS.size() + 1:
			_terminar(0)


func _recibir(mensaje: Dictionary) -> void:
	match int(mensaje["tipo"]):
		PROTOCOLO.Tipo.WELCOME:
			_listo = true
			print("WELCOME: id=%d nombre=%s posicion=%s" % [
				mensaje["datos"]["id"],
				mensaje["datos"]["nombre"],
				mensaje["datos"]["pos"],
			])
		PROTOCOLO.Tipo.STATE:
			_estados += 1
			var jugadores: Array = mensaje["datos"].get("jugadores", [])
			print("STATE #%d: %d jugador(es)" % [_estados, jugadores.size()])
			for jugador in jugadores:
				print("  %s -> %s" % [jugador["nombre"], jugador["pos"]])
		PROTOCOLO.Tipo.ERROR:
			_fallar("Error del servidor: %s" % mensaje["datos"].get("mensaje", "desconocido"))
		_:
			_fallar("Opcode inesperado: %d" % mensaje["tipo"])


func _enviar(tipo: int, datos: Dictionary) -> void:
	_peer.put_data(PROTOCOLO.empaquetar(tipo, datos))


func _fallar(mensaje: String) -> void:
	_fallas += 1
	print("FALLO: %s" % mensaje)
	_terminar(1)


func _terminar(codigo: int) -> void:
	if _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_enviar(PROTOCOLO.Tipo.GOODBYE, {})
		_peer.disconnect_from_host()
	print("Resultado: %s" % ("OK" if codigo == 0 else "FALLO"))
	get_tree().quit(codigo)
