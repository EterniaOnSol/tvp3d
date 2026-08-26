extends Node

## Diagnostico puntual del estado persistente del servidor.
## Se usa para confirmar donde quedo el barril de Doublet sin enviar acciones.

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
const CUENTA := 123456
const CLAVE := "123456"
const BARRIL_CLIENT_ID := 2523

var _con
var _estado
var _reloj := 0.0


func _ready() -> void:
	_estado = ESTADO.new()
	_con = CONEXION.new()
	add_child(_con)
	_con.lista_personajes.connect(_al_personajes)
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.error_red.connect(func(texto):
		print("[localizar] error: %s" % texto)
		get_tree().quit(1))
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _process(delta: float) -> void:
	_reloj += delta
	if _reloj > 25.0:
		print("[localizar] timeout")
		get_tree().quit(1)
		return
	if _estado == null or not _estado.adentro or _estado.casillas.is_empty():
		return
	var encontrados := []
	for posicion in _estado.casillas:
		for cosa in _estado.casillas[posicion]:
			if cosa.get("tipo") == "item" and int(cosa.get("cid", 0)) == BARRIL_CLIENT_ID:
				encontrados.append({"pos": posicion, "cosa": cosa})
	print("[localizar] jugador=%s barriles=%s" % [_estado.mi_pos, encontrados])
	get_tree().quit(0)


func _al_personajes(_motd: String, personajes: Array) -> void:
	if personajes.is_empty():
		print("[localizar] sin personajes")
		get_tree().quit(1)
		return
	var personaje: Dictionary = personajes[0]
	_con.cerrar()
	_con.queue_free()
	_con = CONEXION.new()
	add_child(_con)
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.entrar_al_mundo(personaje.get("ip", HOST), int(personaje["puerto"]),
		CUENTA, personaje["nombre"], CLAVE)
