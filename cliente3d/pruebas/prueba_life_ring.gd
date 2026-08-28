extends Node

# Prueba de integración del life ring contra el servidor real. Usa el
# personaje Guuille, que tiene el anillo activo en la ranura 9 y aparece en
# el templo (zona de protección).

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
const CUENTA := 123456
const CLAVE := "123456"
const PERSONAJE := "Guuille"
const RANURA_ANILLO := 9
const TIEMPO_MEDICION := 7.0

var _con
var _estado
var _fase := "login"
var _reloj := 0.0
var _estadisticas_recibidas := 0
var _stats_iniciales := {}
var _stats_finales := {}
var _inventario_inicial := {}
var _entramos := false
var _medicion_iniciada := false


func _ready() -> void:
	print("=========================================")
	print(" TVP3D - prueba real del life ring")
	print("=========================================")
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(_al_fallar)
	_con.lista_personajes.connect(_al_recibir_personajes)
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _process(delta: float) -> void:
	_reloj += delta
	if _reloj > 30.0:
		print("Tiempo agotado en la fase '%s'." % _fase)
		_terminar(1)


func _al_recibir_personajes(_motd: String, personajes: Array) -> void:
	var elegido := {}
	for personaje in personajes:
		if personaje.get("nombre", "") == PERSONAJE:
			elegido = personaje
			break
	if elegido.is_empty() and not personajes.is_empty():
		elegido = personajes[0]
	if elegido.is_empty():
		_al_fallar("La cuenta no tiene personajes")
		return

	_fase = "entrar al mundo"
	print("Entrando con '%s' por %s:%d ..." % [
		elegido["nombre"], elegido["ip"], elegido["puerto"]])
	_con.cerrar()
	_con.queue_free()
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(_al_fallar)
	_con.paquete_juego.connect(_al_recibir_paquete)
	_con.entrar_al_mundo(
		HOST if elegido["ip"] in ["", "0.0.0.0"] else elegido["ip"],
		elegido["puerto"], CUENTA, elegido["nombre"], CLAVE)


func _al_recibir_paquete(msg) -> void:
	if _estado == null:
		_estado = ESTADO.new()
		_estado.entramos.connect(_al_entramos)
		_estado.estadisticas_actualizadas.connect(_al_estadisticas)
		_estado.inventario_actualizado.connect(_al_inventario)
	_estado.procesar(msg)


func _al_entramos() -> void:
	if _entramos:
		return
	_entramos = true
	_fase = "medir regeneracion"
	print("Entramos al mundo en %s; esperando el estado inicial..." % _estado.mi_pos)
	_medicion.call_deferred()


func _al_estadisticas(datos: Dictionary) -> void:
	_estadisticas_recibidas += 1
	_stats_finales = datos.duplicate()
	print("  stats #%d: vida %d/%d, mana %d/%d" % [
		_estadisticas_recibidas, datos.get("vida", -1), datos.get("vida_max", -1),
		datos.get("mana", -1), datos.get("mana_max", -1)])


func _al_inventario(slot: int, cosa: Dictionary) -> void:
	if slot == RANURA_ANILLO:
		_inventario_inicial = cosa.duplicate()
		print("  ranura 9: cid=%s, nombre='%s'" % [
			cosa.get("cid", "?"), cosa.get("nombre", "")])


func _medicion() -> void:
	if _medicion_iniciada:
		return
	_medicion_iniciada = true
	await get_tree().create_timer(1.5).timeout
	if _stats_finales.is_empty():
		_al_fallar("No llegaron las estadisticas del personaje")
		return
	_stats_iniciales = _stats_finales.duplicate()
	var vida_inicial: int = _stats_iniciales.get("vida", -1)
	var mana_inicial: int = _stats_iniciales.get("mana", -1)
	print("Medicion iniciada: vida=%d, mana=%d; esperando %.1f segundos..." % [
		vida_inicial, mana_inicial, TIEMPO_MEDICION])
	await get_tree().create_timer(TIEMPO_MEDICION).timeout

	var vida_final: int = _stats_finales.get("vida", -1)
	var mana_final: int = _stats_finales.get("mana", -1)
	var vida_subio := vida_final > vida_inicial
	var mana_subio := mana_final > mana_inicial
	print("Resultado: vida %d -> %d; mana %d -> %d" % [
		vida_inicial, vida_final, mana_inicial, mana_final])
	if vida_subio and mana_subio:
		print("OK: el life ring regenera dentro de la zona de proteccion.")
		_terminar(0)
	else:
		print("FALLO: la regeneracion del life ring no avanzo.")
		_terminar(1)


func _al_fallar(texto: String) -> void:
	print("FALLO en la fase '%s': %s" % [_fase, texto])
	_terminar(1)


func _terminar(codigo: int) -> void:
	if _con:
		_con.cerrar()
	print("=========================================")
	get_tree().quit(codigo)
