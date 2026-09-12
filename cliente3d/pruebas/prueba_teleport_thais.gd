extends Node

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

var HOST := CREDENCIALES.HOST_DEFECTO
var CUENTA := 0
var CLAVE := ""
var PERSONAJE := ""
const PREPARACION := Vector3i(32097, 32219, 7)
const THAIS := Vector3i(32369, 32241, 7)

var _con
var _estado := ESTADO.new()
var _fase := "login"
var _solicito_teleport := false
var _preparacion_recibida := false
var _teleport_recibido := false
var _pos_antes := Vector3i.ZERO
var _fallo := false
var _tiempo := 0.0


func _ready() -> void:
	# Credenciales e identidades de prueba: SOLO por entorno, nunca literales.
	# Si falta alguna, corta aca y no intenta ninguna conexion.
	if not CREDENCIALES.exigir(self, ["TVP772_ACCOUNT", "TVP772_PASSWORD", "TVP772_GOD_CHARACTER"]):
		return
	HOST = CREDENCIALES.host()
	CUENTA = CREDENCIALES.entero("TVP772_ACCOUNT")
	CLAVE = CREDENCIALES.texto("TVP772_PASSWORD")
	PERSONAJE = CREDENCIALES.texto("TVP772_GOD_CHARACTER")
	_estado.entramos.connect(_al_entramos)
	_estado.mapa_recibido.connect(_al_mapa)
	_estado.cambio.connect(_al_cambio)
	_conectar_login()
	_con.pedir_personajes(HOST, 7171, CUENTA, CLAVE)


func _process(delta: float) -> void:
	_tiempo += delta
	if _tiempo > 20.0 and not _fallo:
		_fallar("timeout esperando teleport o movimiento")


func _conectar_login() -> void:
	_con = CONEXION.new()
	add_child(_con)
	_con.lista_personajes.connect(_al_personajes)
	_con.error_red.connect(_al_error)
	_con.cerrada.connect(_al_cierre)


func _al_personajes(_motd: String, personajes: Array) -> void:
	var elegido := {}
	for personaje in personajes:
		if str(personaje.get("nombre", "")) == PERSONAJE:
			elegido = personaje
			break
	if elegido.is_empty():
		_fallar("No encontre %s" % PERSONAJE)
		return
	_fase = "entrar al mundo"
	_con.cerrar()
	_con.queue_free()
	_con = CONEXION.new()
	add_child(_con)
	_con.paquete_juego.connect(_al_paquete)
	_con.error_red.connect(_al_error)
	_con.cerrada.connect(_al_cierre)
	_con.entrar_al_mundo(HOST, int(elegido["puerto"]), CUENTA,
		str(elegido["nombre"]), CLAVE)


func _al_entramos() -> void:
	_fase = "mundo inicial"
	_con.enviar_modos_combate(1, 1, 1)


func _al_paquete(msg) -> void:
	_estado.procesar(msg)


func _al_mapa(posicion: Vector3i) -> void:
	print("MAPA %s | criaturas=%d" % [posicion, _estado.criaturas.size()])
	for id in _estado.criaturas:
		print("  criatura id=%d nombre=%s mi_id=%d" % [
			int(id), str(_estado.criaturas[id].get("nombre", "")), _estado.mi_id])
	if not _solicito_teleport:
		_solicito_teleport = true
		_pos_antes = posicion
		await get_tree().create_timer(1.0).timeout
		if posicion == THAIS:
			_preparacion_recibida = false
			_fase = "preparacion fuera de Thais"
			_con.enviar_hablar("/gotopos %d,%d,%d" % [
				PREPARACION.x, PREPARACION.y, PREPARACION.z])
			print("ENVIADO preparacion a %s" % PREPARACION)
		else:
			_fase = "teleport a Thais"
			_con.enviar_hablar("/gotopos %d,%d,%d" % [
				THAIS.x, THAIS.y, THAIS.z])
			print("ENVIADO teleport a %s" % THAIS)
		return
	if not _preparacion_recibida and posicion == PREPARACION:
		_preparacion_recibida = true
		_fase = "teleport a Thais"
		await get_tree().create_timer(1.0).timeout
		_con.enviar_hablar("/gotopos %d,%d,%d" % [
			THAIS.x, THAIS.y, THAIS.z])
		print("ENVIADO teleport a %s" % THAIS)
		return
	if posicion == THAIS or (absi(posicion.x - THAIS.x) <= 2
			and absi(posicion.y - THAIS.y) <= 2 and posicion.z == THAIS.z):
		_teleport_recibido = true
		_fase = "caminar despues del teleport"
		await get_tree().create_timer(1.0).timeout
		_con.enviar_juego(PackedByteArray([0x66]))
		print("ENVIADO paso este desde %s" % _estado.mi_pos)


func _al_cambio() -> void:
	if _teleport_recibido and _estado.mi_pos != THAIS:
		print("CAMBIO despues del teleport: %s" % _estado.mi_pos)
		_terminar(0)


func _al_error(texto: String) -> void:
	_fallar(texto)


func _al_cierre() -> void:
	if _fase == "login" and not _fallo:
		_fallar("cierre durante login")


func _fallar(texto: String) -> void:
	if _fallo:
		return
	_fallo = true
	printerr("FALLO [%s]: %s" % [_fase, texto])
	_terminar(1)


func _terminar(codigo: int) -> void:
	if codigo == 0:
		print("OK teleport y movimiento: %s -> %s" % [_pos_antes, _estado.mi_pos])
	else:
		print("FALLO teleport/movimiento")
	get_tree().quit(codigo)
