extends Node

# Captura QA-owned en vivo: ciclo de vida de party (Phase 2D).
#
# Cubre SOLO el ciclo de vida: estado inicial sin party, invitacion, union,
# transferencia de liderazgo y salida/disolucion. La experiencia compartida
# es un dominio separado, con su propio fixture y su propio adaptador.
#
# Esta rama NO decide PASS/FAIL: eso lo hace exclusivamente
# `qa/parity/tools/replay.py` comparando esta observacion contra la
# `ParityExpectationV1` publicada. Este script solo observa y serializa.
#
# El servidor de esta rama NO manda una lista de miembros de party: comunica
# cada cambio reenviando el escudo de cada criatura (`PartyShields_t`,
# `servidor/src/const.h:187-193`). Por eso la evidencia son los escudos que
# ven LAS DOS sesiones, nunca una lista inventada.
#
# Valores de `PartyShields_t` verificados en el codigo fuente:
#   0 SHIELD_NONE, 1 SHIELD_WHITEYELLOW (invitacion recibida),
#   2 SHIELD_WHITEBLUE (invitacion enviada), 3 SHIELD_BLUE (miembro),
#   4 SHIELD_YELLOW (lider).
#
# Mutacion: solo comandos de party y `/c` para reunir a las dos sesiones.
# Sin invocar, sin atacar, sin matar, sin `/killall`, sin tocar inventario ni
# persistencia. Nadie pierde nivel ni experiencia.
#
# Credenciales: exclusivamente por entorno, nunca literales, nunca impresas.
# NO se copia ninguna credencial del historico
# `cliente3d/pruebas/prueba_party_viva.gd`.
#   TVP772_ACCOUNT
#   TVP772_PASSWORD
#   TVP772_GOD_CHARACTER
#   TVP772_PLAYER_CHARACTER
# Opcionales: TVP772_HOST, TVP772_LOGIN_PORT
#
#   ...Godot --headless --path cliente3d pruebas/prueba_parity_party_lifecycle_capture.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST_DEFECTO := "127.0.0.1"
const PUERTO_LOGIN_DEFECTO := 7171
## Terreno aislado y colocable ya calificado en Phase 2C.1/2C.2. Detalle de
## implementacion de la captura: nunca entra al payload normalizado.
const POS_REUNION := Vector3i(32008, 32400, 7)
const RADIO_LLEGADA := 3

const SHIELD_NONE := 0
const SHIELD_INVITACION_RECIBIDA := 1
const SHIELD_INVITACION_ENVIADA := 2
const SHIELD_MIEMBRO := 3
const SHIELD_LIDER := 4

const PAUSA_SESION := 6.0
const ESPERA_PASO := 20.0
const ESPERA_ESCUDO := 15.0
const LIMITE_TOTAL := 240.0

var _con_login
var _con_a          ## sesion que invita y arranca como lider
var _con_b          ## sesion invitada
var _estado_a
var _estado_b
var _puertos := {}
var _fase := "login"
var _espera := 0.0
var _total := 0.0
var _terminando := false

var _cuenta := 0
var _clave := ""
var _personaje_a := ""
var _personaje_b := ""
var _host := HOST_DEFECTO
var _puerto_login := PUERTO_LOGIN_DEFECTO

var _id_a_visto_por_b := 0
var _id_b_visto_por_a := 0

var _obs := {}


func _ready() -> void:
	print("=================================================")
	print(" TVP3D QA - captura en vivo: ciclo de vida de party")
	print("=================================================")
	var falta := _resolver_credenciales()
	if not falta.is_empty():
		print("BLOCKED missing environment variable %s" % falta)
		get_tree().quit(2)
		return
	_abrir_login()


func _resolver_credenciales() -> String:
	var cuenta_texto := OS.get_environment("TVP772_ACCOUNT")
	if cuenta_texto.is_empty() or not cuenta_texto.is_valid_int():
		return "TVP772_ACCOUNT"
	_cuenta = int(cuenta_texto)
	_clave = OS.get_environment("TVP772_PASSWORD")
	if _clave.is_empty():
		return "TVP772_PASSWORD"
	_personaje_a = OS.get_environment("TVP772_GOD_CHARACTER")
	if _personaje_a.is_empty():
		return "TVP772_GOD_CHARACTER"
	_personaje_b = OS.get_environment("TVP772_PLAYER_CHARACTER")
	if _personaje_b.is_empty():
		return "TVP772_PLAYER_CHARACTER"
	var host_env := OS.get_environment("TVP772_HOST")
	if not host_env.is_empty():
		_host = host_env
	var puerto_env := OS.get_environment("TVP772_LOGIN_PORT")
	if not puerto_env.is_empty() and puerto_env.is_valid_int():
		_puerto_login = int(puerto_env)
	return ""


func _process(delta: float) -> void:
	_total += delta
	_espera += delta
	if _terminando:
		return
	if _total > LIMITE_TOTAL:
		_fallar("FAIL tiempo agotado en la fase '%s'" % _fase)
		return
	match _fase:
		"esperar a":
			if _estado_a != null and _estado_a.adentro and _espera > 2.0:
				_pasar_a("pausa segunda sesion")
		"pausa segunda sesion":
			if _espera >= PAUSA_SESION:
				_abrir_b()
		"esperar b":
			if _estado_b != null and _estado_b.adentro and _espera > 2.0:
				_ir_a_reunion()
		"esperar a en reunion":
			_esperar_a_en_reunion()
		"reunir b":
			_reunir_b()
		"estado inicial":
			_estado_inicial()
		"invitar":
			_invitar()
		"esperar invitacion":
			_esperar_invitacion()
		"unirse":
			_unirse()
		"esperar union":
			_esperar_union()
		"transferir":
			_transferir()
		"esperar transferencia":
			_esperar_transferencia()
		"salir":
			_salir()
		"esperar disolucion":
			_esperar_disolucion()


# -----------------------------------------------------------------
#  Sesiones
# -----------------------------------------------------------------
func _abrir_login() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.error_red.connect(func(t): _fallar("FAIL fallo de red en login: %s" % t))
	_con_login.lista_personajes.connect(_al_lista)
	_con_login.pedir_personajes(_host, _puerto_login, _cuenta, _clave)


func _al_lista(_motd: String, personajes: Array) -> void:
	for entrada in personajes:
		_puertos[str(entrada.get("nombre", ""))] = int(entrada.get("puerto", 0))
	if int(_puertos.get(_personaje_a, 0)) <= 0:
		_fallar("FAIL character configured by TVP772_GOD_CHARACTER was not found")
		return
	if int(_puertos.get(_personaje_b, 0)) <= 0:
		_fallar("FAIL character configured by TVP772_PLAYER_CHARACTER was not found")
		return
	_con_login.cerrar()
	_con_login.queue_free()
	_con_login = null
	_abrir_a()


func _abrir_a() -> void:
	_estado_a = ESTADO.new()
	_estado_a.pedido_ping.connect(func(): _con_a.enviar_juego(PackedByteArray([0x1E])))
	_estado_a.mensaje_servidor.connect(func(t): print("  [A] ", t))
	_estado_a.rechazados.connect(func(m): _fallar("FAIL la sesion A fue rechazada: %s" % m))
	_con_a = CONEXION.new()
	add_child(_con_a)
	_con_a.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red de A: %s" % t))
	_con_a.paquete_juego.connect(func(m): _estado_a.procesar(m))
	_con_a.entrar_al_mundo(_host, int(_puertos[_personaje_a]), _cuenta, _personaje_a, _clave)
	_pasar_a("esperar a")


func _abrir_b() -> void:
	_estado_b = ESTADO.new()
	_estado_b.pedido_ping.connect(func(): _con_b.enviar_juego(PackedByteArray([0x1E])))
	_estado_b.mensaje_servidor.connect(func(t): print("  [B] ", t))
	_estado_b.rechazados.connect(func(m): _fallar("FAIL la sesion B fue rechazada: %s" % m))
	_con_b = CONEXION.new()
	add_child(_con_b)
	_con_b.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red de B: %s" % t))
	_con_b.paquete_juego.connect(func(m): _estado_b.procesar(m))
	_con_b.entrar_al_mundo(_host, int(_puertos[_personaje_b]), _cuenta, _personaje_b, _clave)
	_pasar_a("esperar b")


# -----------------------------------------------------------------
#  Reunion
# -----------------------------------------------------------------
func _ir_a_reunion() -> void:
	_con_a.enviar_hablar("/gotopos %d,%d,%d" % [
		POS_REUNION.x, POS_REUNION.y, POS_REUNION.z])
	_pasar_a("esperar a en reunion")


func _esperar_a_en_reunion() -> void:
	if _cerca(_estado_a.mi_pos, POS_REUNION):
		_pasar_a("reunir b")
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL la sesion A no llego al punto de reunion a tiempo")


func _reunir_b() -> void:
	if _cerca(_estado_b.mi_pos, POS_REUNION):
		_pasar_a("estado inicial")
		return
	if _espera < 0.2:
		return
	if _espera < 0.5:
		_con_a.enviar_hablar("/c %s" % _personaje_b)
	if _espera > ESPERA_PASO:
		_fallar("FAIL /c no acerco a la sesion B al punto de reunion")


# -----------------------------------------------------------------
#  Etapas de party
# -----------------------------------------------------------------
## Cada sesion tiene su propio runtime id para la otra criatura. Se resuelven
## una sola vez y se guardan solo en memoria de proceso.
func _resolver_ids() -> bool:
	if _id_b_visto_por_a == 0:
		_id_b_visto_por_a = _otro_id(_estado_a)
	if _id_a_visto_por_b == 0:
		_id_a_visto_por_b = _otro_id(_estado_b)
	return _id_b_visto_por_a != 0 and _id_a_visto_por_b != 0


func _otro_id(estado) -> int:
	for id in estado.criaturas:
		if int(id) == estado.mi_id:
			continue
		var criatura: Dictionary = estado.criaturas[id]
		if str(criatura.get("nombre", "")) != "":
			return int(id)
	return 0


func _escudo(estado, id: int) -> int:
	if not estado.criaturas.has(id):
		return -1
	return int(estado.criaturas[id].get("escudo_party", 0))


func _escudo_propio(estado) -> int:
	return _escudo(estado, int(estado.mi_id))


func _estado_inicial() -> void:
	if not _resolver_ids():
		if _espera > ESPERA_PASO:
			_fallar("FAIL las dos sesiones no llegaron a verse mutuamente")
		return
	var a_ve_b := _escudo(_estado_a, _id_b_visto_por_a)
	var b_ve_a := _escudo(_estado_b, _id_a_visto_por_b)
	if a_ve_b != SHIELD_NONE or b_ve_a != SHIELD_NONE:
		if _espera > ESPERA_ESCUDO:
			_fallar("FAIL alguna sesion arranco con escudo de party; no hay estado inicial limpio")
		return
	_obs["initial"] = {
		"sessions_see_each_other": true,
		"inviter_sees_invitee_shield": a_ve_b,
		"invitee_sees_inviter_shield": b_ve_a,
	}
	print("Estado inicial: ambas sesiones sin escudo de party.")
	_pasar_a("invitar")


func _invitar() -> void:
	print("A invita a B (0xA3).")
	_con_a.enviar_invitar_a_party(_id_b_visto_por_a)
	_pasar_a("esperar invitacion")


func _esperar_invitacion() -> void:
	var a_ve_b := _escudo(_estado_a, _id_b_visto_por_a)
	var b_ve_a := _escudo(_estado_b, _id_a_visto_por_b)
	if a_ve_b == SHIELD_INVITACION_ENVIADA and b_ve_a == SHIELD_INVITACION_RECIBIDA:
		_obs["after_invite"] = {
			"inviter_sees_invitee_shield": a_ve_b,
			"invitee_sees_inviter_shield": b_ve_a,
		}
		print("Invitacion confirmada por los escudos de ambas sesiones.")
		_pasar_a("unirse")
		return
	if _espera > ESPERA_ESCUDO:
		_fallar("FAIL los escudos no reflejaron la invitacion a tiempo")


func _unirse() -> void:
	print("B se une a la party de A (0xA4).")
	_con_b.enviar_unirse_a_party(_id_a_visto_por_b)
	_pasar_a("esperar union")


func _esperar_union() -> void:
	# A sigue siendo lider en esta etapa.
	var lider_ve_miembro := _escudo(_estado_a, _id_b_visto_por_a)
	var miembro_ve_lider := _escudo(_estado_b, _id_a_visto_por_b)
	var lider_propio := _escudo_propio(_estado_a)
	var miembro_propio := _escudo_propio(_estado_b)
	if lider_ve_miembro == SHIELD_MIEMBRO and miembro_ve_lider == SHIELD_LIDER \
			and lider_propio == SHIELD_LIDER and miembro_propio == SHIELD_MIEMBRO:
		_obs["after_join"] = {
			"leader_sees_member_shield": lider_ve_miembro,
			"member_sees_leader_shield": miembro_ve_lider,
			"leader_self_shield": lider_propio,
			"member_self_shield": miembro_propio,
		}
		print("Union confirmada: lider y miembro coherentes en las dos sesiones.")
		_pasar_a("transferir")
		return
	if _espera > ESPERA_ESCUDO:
		_fallar("FAIL los escudos no reflejaron la union a tiempo")


func _transferir() -> void:
	print("A pasa el liderazgo a B (0xA6).")
	_con_a.enviar_pasar_liderazgo_party(_id_b_visto_por_a)
	_pasar_a("esperar transferencia")


func _esperar_transferencia() -> void:
	# Ahora B es lider: los dos escudos deben haberse dado vuelta.
	var prev_ve_nuevo := _escudo(_estado_a, _id_b_visto_por_a)
	var nuevo_ve_prev := _escudo(_estado_b, _id_a_visto_por_b)
	var prev_propio := _escudo_propio(_estado_a)
	if prev_ve_nuevo == SHIELD_LIDER and nuevo_ve_prev == SHIELD_MIEMBRO \
			and prev_propio == SHIELD_MIEMBRO:
		_obs["after_leadership_transfer"] = {
			"previous_leader_sees_new_leader_shield": prev_ve_nuevo,
			"new_leader_sees_previous_leader_shield": nuevo_ve_prev,
			"previous_leader_self_shield": prev_propio,
		}
		print("Transferencia confirmada: los escudos se invirtieron.")
		_pasar_a("salir")
		return
	if _espera > ESPERA_ESCUDO:
		_fallar("FAIL los escudos no reflejaron la transferencia de liderazgo a tiempo")


func _salir() -> void:
	# Sale A, que ahora es el miembro. Al quedar la party con un solo
	# integrante el servidor la deshace.
	print("A (ahora miembro) sale de la party (0xA7).")
	_con_a.enviar_salir_de_party()
	_pasar_a("esperar disolucion")


func _esperar_disolucion() -> void:
	var ex_miembro_ve_otro := _escudo(_estado_a, _id_b_visto_por_a)
	var ex_miembro_propio := _escudo_propio(_estado_a)
	var restante_propio := _escudo_propio(_estado_b)
	if ex_miembro_ve_otro == SHIELD_NONE and ex_miembro_propio == SHIELD_NONE \
			and restante_propio == SHIELD_NONE:
		_obs["after_leave"] = {
			"former_member_sees_other_shield": ex_miembro_ve_otro,
			"former_member_self_shield": ex_miembro_propio,
			"remaining_player_self_shield": restante_propio,
		}
		print("Disolucion confirmada: ninguna sesion conserva escudo.")
		_emitir_observacion()
		return
	if _espera > ESPERA_ESCUDO:
		_fallar("FAIL los escudos no volvieron a cero tras deshacerse la party")


# -----------------------------------------------------------------
#  Observacion normalizada
# -----------------------------------------------------------------
func _emitir_observacion() -> void:
	## Solo hechos por rol y valores de escudo. Ningun runtime id, ningun
	## nombre de personaje, ninguna posicion y ningun texto de servidor.
	var linea := "OBSERVATION_JSON: " + JSON.stringify(_obs)
	print(linea)
	print("Captura de ciclo de vida de party: OK")
	_terminar(0)


# -----------------------------------------------------------------
#  Utilidades
# -----------------------------------------------------------------
func _cerca(posicion: Vector3i, centro: Vector3i) -> bool:
	return posicion.z == centro.z \
		and absi(posicion.x - centro.x) <= RADIO_LLEGADA \
		and absi(posicion.y - centro.y) <= RADIO_LLEGADA


func _pasar_a(fase: String) -> void:
	print("  [%.0fs] fase: %s" % [_total, fase])
	_fase = fase
	_espera = 0.0


func _fallar(texto: String) -> void:
	print(texto)
	_limpiar_party()
	_terminar(1)


## Higiene: si algo fallo a mitad, se intenta deshacer la party de prueba.
func _limpiar_party() -> void:
	if _con_a != null:
		_con_a.enviar_salir_de_party()
	if _con_b != null:
		_con_b.enviar_salir_de_party()


func _terminar(codigo: int) -> void:
	if _terminando:
		return
	_terminando = true
	if _con_a != null:
		_con_a.cerrar()
	if _con_b != null:
		_con_b.cerrar()
	get_tree().quit(codigo)
