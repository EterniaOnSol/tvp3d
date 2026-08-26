extends Node

## Recupera el fixture persistente de Doublet si una prueba anterior se
## interrumpio despues de moverlo. No toca storages ni completa la quest.

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
const CUENTA := 123456
const CLAVE := "123456"
const BARRIL_CLIENT_ID := 2523
const ORIGEN_CORRECTO := Vector3i(32084, 32181, 8)

var _con
var _estado
var _origen_actual := Vector3i.ZERO
var _enviado := false
var _reloj := 0.0


func _ready() -> void:
	_estado = ESTADO.new()
	_estado.casilla_actualizada.connect(_al_casilla_actualizada)
	_estado.mensaje_servidor.connect(func(texto): print("[restaurar] %s" % texto))
	_con = CONEXION.new()
	add_child(_con)
	_con.lista_personajes.connect(_al_personajes)
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.error_red.connect(_fallo)
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _process(delta: float) -> void:
	_reloj += delta
	if _reloj > 35.0:
		_fallo("timeout")
		return
	if _enviado or _estado == null or not _estado.adentro \
			or _estado.casillas.is_empty():
		return
	for posicion in _estado.casillas:
		if posicion == ORIGEN_CORRECTO:
			continue
		var cosas: Array = _estado.casillas[posicion]
		for indice in range(cosas.size()):
			if cosas[indice].get("tipo") == "item" \
					and int(cosas[indice].get("cid", 0)) == BARRIL_CLIENT_ID:
				_origen_actual = posicion
				_enviado = true
				print("[restaurar] moviendo barril desde %s a %s stack=%d" % [
					_origen_actual, ORIGEN_CORRECTO, indice])
				_con.enviar_mover_cosa(_origen_actual, BARRIL_CLIENT_ID,
					indice, ORIGEN_CORRECTO)
				return
	_fallo("no encontre un barril fuera del origen correcto")


func _al_casilla_actualizada(posicion: Vector3i, _opcode: int) -> void:
	if posicion != ORIGEN_CORRECTO and posicion != _origen_actual:
		return
	var tiene_origen := _tiene_item(ORIGEN_CORRECTO)
	var tiene_actual := _tiene_item(_origen_actual)
	print("[restaurar] casilla %s; origen=%s actual=%s" % [
		posicion, tiene_origen, tiene_actual])
	if tiene_origen and not tiene_actual:
		print("[restaurar] OK: fixture restaurado")
		get_tree().quit(0)


func _tiene_item(posicion: Vector3i) -> bool:
	for cosa in _estado.casillas.get(posicion, []):
		if cosa.get("tipo") == "item" and int(cosa.get("cid", 0)) == BARRIL_CLIENT_ID:
			return true
	return false


func _al_personajes(_motd: String, personajes: Array) -> void:
	if personajes.is_empty():
		_fallo("sin personajes")
		return
	var personaje: Dictionary = personajes[0]
	_con.cerrar()
	_con.queue_free()
	_con = CONEXION.new()
	add_child(_con)
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.error_red.connect(_fallo)
	_con.entrar_al_mundo(personaje.get("ip", HOST), int(personaje["puerto"]),
		CUENTA, personaje["nombre"], CLAVE)


func _fallo(texto: String) -> void:
	print("[restaurar] FAIL: %s" % texto)
	get_tree().quit(1)
