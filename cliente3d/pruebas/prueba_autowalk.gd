extends Node

## Prueba el mismo paquete que usa el clic izquierdo de mundo3d.gd:
## login -> mapa real -> escoger vecino libre -> enviar 0x64 -> confirmar
## que el servidor actualizo X/Y/Z.

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const DISCO := preload("res://red/mapa_disco.gd")
const CATALOGO := preload("res://red/mapa772.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
const CUENTA := 123456
const CLAVE := "123456"

var _con
var _estado
var _disco
var _catalogo
var _origen := Vector3i.ZERO
var _objetivo := Vector3i.ZERO
var _enviado := false
var _reloj := 0.0


func _ready() -> void:
	_disco = DISCO.new()
	_catalogo = CATALOGO.new()
	_estado = ESTADO.new()
	_con = CONEXION.new()
	add_child(_con)
	_con.lista_personajes.connect(_al_recibir_personajes)
	_con.paquete_juego.connect(_al_recibir_paquete)
	_con.error_red.connect(_fallo)
	_con.cerrada.connect(func(): _fallo("conexion cerrada"))
	print("[autowalk] pidiendo login")
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _process(delta: float) -> void:
	_reloj += delta
	if _enviado and _estado.mi_pos == _objetivo:
		print("[autowalk] OK: (%d,%d,%d) -> (%d,%d,%d)" % [
			_origen.x, _origen.y, _origen.z,
			_objetivo.x, _objetivo.y, _objetivo.z])
		get_tree().quit(0)
	elif _reloj > 20.0:
		_fallo("timeout esperando la posicion confirmada")


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
	_con.cerrada.connect(func(): _fallo("conexion de juego cerrada"))
	_con.entrar_al_mundo(personaje["ip"], personaje["puerto"], CUENTA,
		personaje["nombre"], CLAVE)


func _al_recibir_paquete(msg) -> void:
	_estado.procesar(msg)
	if _enviado or not _estado.adentro or _estado.casillas.is_empty():
		return
	var deltas := [
		Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
		Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	for delta in deltas:
		var destino: Vector3i = _estado.mi_pos + Vector3i(delta.x, delta.y, 0)
		if not _bloqueada(destino):
			_origen = _estado.mi_pos
			_objetivo = destino
			_enviado = true
			_con.enviar_auto_camino([delta])
			print("[autowalk] enviando 0x64 hacia (%d,%d,%d)" % [
				destino.x, destino.y, destino.z])
			return
	_fallo("no encontre vecino libre en el mapa real")


func _bloqueada(posicion: Vector3i) -> bool:
	var ids := PackedInt32Array()
	if _estado.casillas.has(posicion):
		for cosa in _estado.casillas[posicion]:
			if cosa.get("tipo") == "item":
				ids.append(int(cosa.get("cid", 0)))
	else:
		var trozo: Dictionary = _disco.casillas_de(posicion, 0)
		ids = trozo.get(posicion, PackedInt32Array())
	if ids.is_empty():
		return true
	for cid in ids:
		if _catalogo.info_item(cid).get("bloquea", false):
			return true
	return false


func _fallo(motivo: String) -> void:
	print("[autowalk] FAIL: " + motivo)
	get_tree().quit(1)
