extends Node

# Sonda pasiva de terreno QA (Phase 2C.1).
#
# Proposito: comprobar EN VIVO que un par de casillas candidatas, ya
# calificadas estaticamente por
# `qa/parity/tools/qualify_reacquisition_terrain.py`, esta realmente
# tranquilo: que el god llega a cada punto y que durante una ventana de
# observacion fija no aparece ninguna criatura natural.
#
# Esta sonda es DELIBERADAMENTE NO COMBATIVA y NO MUTANTE:
#   - usa UNA sola sesion god;
#   - NO usa el personaje normal (no se pide TVP772_PLAYER_CHARACTER);
#   - solo emite `/gotopos` y observa de forma pasiva;
#   - NO invoca (`/m`), NO mata, NO ataca, NO usa `/killall`, NO mueve al
#     personaje normal con `/c`.
# Si aparece un monstruo natural, el candidato FALLA la sonda y se pasa al
# siguiente; nunca se "limpia" el candidato.
#
# No decide nada sobre paridad: no emite `OBSERVATION_JSON` ni toca ningun
# fixture. Es evidencia operativa de calificacion de terreno.
#
# Credenciales: exclusivamente por variable de entorno, nunca literal:
#   TVP772_ACCOUNT
#   TVP772_PASSWORD
#   TVP772_GOD_CHARACTER
# Opcionales:
#   TVP772_HOST            (por defecto 127.0.0.1)
#   TVP772_LOGIN_PORT      (por defecto 7171)
# Puntos a sondear (obligatorio), como "x,y,z;x,y,z":
#   TVP772_PROBE_POINTS
# Ventana de observacion por punto en segundos (opcional, por defecto 60):
#   TVP772_PROBE_DWELL
#
#   ...Godot --headless --path cliente3d pruebas/prueba_parity_terrain_probe.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST_DEFECTO := "127.0.0.1"
const PUERTO_LOGIN_DEFECTO := 7171
const DWELL_DEFECTO := 60.0
const ESPERA_TELEPORT := 20.0
const RADIO_LLEGADA := 1
const LIMITE_TOTAL := 600.0

var _con_login
var _con
var _estado
var _fase := "login"
var _espera := 0.0
var _total := 0.0
var _terminando := false

var _cuenta := 0
var _clave := ""
var _personaje_god := ""
var _host := HOST_DEFECTO
var _puerto_login := PUERTO_LOGIN_DEFECTO
var _dwell := DWELL_DEFECTO

var _puntos: Array = []
var _indice := 0
var _intrusos: Dictionary = {}
var _resultados: Array = []
var _fallas := 0


func _ready() -> void:
	print("=================================================")
	print(" TVP3D QA - sonda pasiva de terreno (solo god)")
	print("=================================================")

	var falta := _resolver_config()
	if not falta.is_empty():
		print("BLOCKED missing environment variable %s" % falta)
		get_tree().quit(2)
		return

	print("Puntos a sondear: %d | ventana por punto: %.0fs" % [_puntos.size(), _dwell])
	_abrir_login()


func _resolver_config() -> String:
	var cuenta_texto := OS.get_environment("TVP772_ACCOUNT")
	if cuenta_texto.is_empty() or not cuenta_texto.is_valid_int():
		return "TVP772_ACCOUNT"
	_cuenta = int(cuenta_texto)

	_clave = OS.get_environment("TVP772_PASSWORD")
	if _clave.is_empty():
		return "TVP772_PASSWORD"

	_personaje_god = OS.get_environment("TVP772_GOD_CHARACTER")
	if _personaje_god.is_empty():
		return "TVP772_GOD_CHARACTER"

	var puntos_texto := OS.get_environment("TVP772_PROBE_POINTS")
	if puntos_texto.is_empty():
		return "TVP772_PROBE_POINTS"
	for bloque in puntos_texto.split(";", false):
		var partes := bloque.strip_edges().split(",", false)
		if partes.size() != 3:
			continue
		if not (partes[0].is_valid_int() and partes[1].is_valid_int() and partes[2].is_valid_int()):
			continue
		_puntos.append(Vector3i(int(partes[0]), int(partes[1]), int(partes[2])))
	if _puntos.is_empty():
		return "TVP772_PROBE_POINTS"

	var host_env := OS.get_environment("TVP772_HOST")
	if not host_env.is_empty():
		_host = host_env

	var puerto_env := OS.get_environment("TVP772_LOGIN_PORT")
	if not puerto_env.is_empty() and puerto_env.is_valid_int():
		_puerto_login = int(puerto_env)

	var dwell_env := OS.get_environment("TVP772_PROBE_DWELL")
	if not dwell_env.is_empty() and dwell_env.is_valid_float():
		_dwell = maxf(1.0, dwell_env.to_float())

	return ""


func _process(delta: float) -> void:
	_total += delta
	_espera += delta
	if _terminando:
		return
	if _total > LIMITE_TOTAL:
		_fallar("FAIL tiempo total agotado en la fase '%s'" % _fase)
		return
	if _estado == null:
		return
	match _fase:
		"esperar god":
			if _estado.adentro and _espera > 2.0:
				_ir_al_punto()
		"esperar llegada":
			_esperar_llegada()
		"observar":
			_observar(delta)


func _abrir_login() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.error_red.connect(func(texto): _fallar("FAIL fallo de red en login: %s" % texto))
	_con_login.lista_personajes.connect(_al_lista)
	_con_login.pedir_personajes(_host, _puerto_login, _cuenta, _clave)


func _al_lista(_motd: String, personajes: Array) -> void:
	var puerto := 0
	for entrada in personajes:
		if str(entrada.get("nombre", "")) == _personaje_god:
			puerto = int(entrada.get("puerto", 0))
			break
	if puerto <= 0:
		_fallar("FAIL character configured by TVP772_GOD_CHARACTER was not found")
		return
	_con_login.cerrar()
	_con_login.queue_free()
	_con_login = null

	_estado = ESTADO.new()
	_estado.pedido_ping.connect(func(): _con.enviar_juego(PackedByteArray([0x1E])))
	_estado.mensaje_servidor.connect(func(texto): print("  [god] ", texto))
	_estado.rechazados.connect(func(motivo): _fallar("FAIL el god fue rechazado: %s" % motivo))
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(func(texto):
		if not _terminando: _fallar("FAIL fallo de red del god: %s" % texto))
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.entrar_al_mundo(_host, puerto, _cuenta, _personaje_god, _clave)
	_pasar_a("esperar god")


func _punto_actual() -> Vector3i:
	return _puntos[_indice]


func _ir_al_punto() -> void:
	var destino := _punto_actual()
	print("--- punto %d/%d: (%d,%d,%d) ---" % [
		_indice + 1, _puntos.size(), destino.x, destino.y, destino.z])
	_con.enviar_hablar("/gotopos %d,%d,%d" % [destino.x, destino.y, destino.z])
	_pasar_a("esperar llegada")


func _esperar_llegada() -> void:
	var destino := _punto_actual()
	if _cerca(_estado.mi_pos, destino):
		print("God llego a %s. Observando %.0fs sin tocar nada." % [str(_estado.mi_pos), _dwell])
		_intrusos.clear()
		_pasar_a("observar")
		return
	if _espera > ESPERA_TELEPORT:
		print("  el god no llego al punto; quedo en %s" % str(_estado.mi_pos))
		_registrar(false, "el god no pudo posicionarse en el punto")
		_siguiente_punto()


func _observar(_delta: float) -> void:
	## Observacion puramente pasiva: se anota cualquier criatura distinta del
	## propio god que aparezca en el conjunto visible. No se ataca, no se
	## invoca y no se retira nada.
	for id in _estado.criaturas:
		if int(id) == _estado.mi_id:
			continue
		var criatura: Dictionary = _estado.criaturas[id]
		var nombre := str(criatura.get("nombre", "?"))
		if not _intrusos.has(nombre):
			_intrusos[nombre] = true
			print("  criatura observada: '%s'" % nombre)
	if _espera >= _dwell:
		var nombres: Array = _intrusos.keys()
		nombres.sort()
		if nombres.is_empty():
			print("  sin criaturas naturales durante la ventana completa.")
			_registrar(true, "")
		else:
			print("  FALLA de aislamiento: %s" % str(nombres))
			_registrar(false, "criaturas observadas: %s" % str(nombres))
		_siguiente_punto()


func _registrar(limpio: bool, detalle: String) -> void:
	var punto := _punto_actual()
	var nombres: Array = _intrusos.keys()
	nombres.sort()
	_resultados.append({
		"x": punto.x, "y": punto.y, "z": punto.z,
		"clean": limpio,
		"observed": nombres,
		"detail": detalle,
	})
	if not limpio:
		_fallas += 1


func _siguiente_punto() -> void:
	_indice += 1
	if _indice >= _puntos.size():
		_resumen()
		return
	_ir_al_punto()


func _resumen() -> void:
	print("--- resumen de la sonda ---")
	for resultado in _resultados:
		var estado_txt := "LIMPIO" if resultado["clean"] else "FALLA"
		print("  (%d,%d,%d) %s %s" % [
			resultado["x"], resultado["y"], resultado["z"], estado_txt,
			str(resultado["observed"])])
	var payload := {"dwell_seconds": int(_dwell), "points": _resultados}
	print("PROBE_JSON: " + JSON.stringify(payload))
	if _fallas == 0:
		print("Sonda pasiva de terreno: OK")
	else:
		print("Sonda pasiva de terreno: %d punto(s) no aislados" % _fallas)
	_terminar(0 if _fallas == 0 else 1)


func _cerca(posicion: Vector3i, centro: Vector3i) -> bool:
	return posicion.z == centro.z \
		and absi(posicion.x - centro.x) <= RADIO_LLEGADA \
		and absi(posicion.y - centro.y) <= RADIO_LLEGADA


func _pasar_a(fase: String) -> void:
	_fase = fase
	_espera = 0.0


func _fallar(texto: String) -> void:
	print(texto)
	_terminar(1)


func _terminar(codigo: int) -> void:
	if _terminando:
		return
	_terminando = true
	if _con != null:
		_con.cerrar()
	if _con_login != null:
		_con_login.cerrar()
	get_tree().quit(codigo)
