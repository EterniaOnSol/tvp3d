extends Node

# Captura QA-owned en vivo: experiencia compartida de party (Phase 2D).
#
# Dominio SEPARADO del ciclo de vida de party. Aca la party solo se arma como
# preparacion del harness; lo que se certifica es el comportamiento de la
# experiencia compartida.
#
# Esta rama NO decide PASS/FAIL: lo hace `qa/parity/tools/replay.py` contra la
# `ParityExpectationV1` publicada. Este script solo observa y serializa.
#
# Semantica verificada en el codigo fuente, no inferida:
#   `Party::setSharedExperience` (party.cpp): SOLO el lider puede solicitar;
#     separa `sharedExpActive` (solicitado) de `sharedExpEnabled` (habilitado).
#   `Party::canUseSharedExperience` (party.cpp): exige party no vacia, nivel
#     >= ceil(nivel_mas_alto * 2 / 3), `Position::areInRange<30,30,1>` y
#     participacion reciente en `ticksMap` dentro de `PZ_LOCKED`.
#   `Party::updateSharedExperience` (party.cpp): re-evalua `sharedExpEnabled`
#     en cada tick de participacion, SIN emitir ningun mensaje. Por eso la
#     unica evidencia externa de que quedo habilitado es que la experiencia
#     efectivamente se reparta.
#   `Creature` (creature.cpp:392): el reparto exige `isSharedExperienceActive()`
#     Y `isSharedExperienceEnabled()`.
#   `Party::shareExperience` + `data/events/scripts/party.lua`: la parte de
#     cada participante es
#     ceil(exp_bruta * multiplicador / (miembros + 1)), con multiplicador
#     1.20 salvo que haya mas de una vocacion base distinta (excluyendo
#     VOCATION_NONE), en cuyo caso
#     1.0 + (n * (5 * (n - 1) + 10)) / 100.
#
# Mutacion controlada: se invoca UN unico monstruo de prueba, ambos
# participantes lo danan y muere. Sin `/killall`, sin tocar fauna natural,
# sin muerte de jugador, sin editar niveles, vocaciones ni persistencia.
#
# Credenciales: exclusivamente por entorno, nunca literales, nunca impresas.
#   TVP772_ACCOUNT            (cuenta de los DOS participantes de la party)
#   TVP772_PASSWORD
#   TVP772_GOD_CHARACTER      (solo invoca el monstruo; NO entra a la party)
#   TVP772_PLAYER_CHARACTER   (lider de la party de prueba)
#   TVP772_PLAYER2_CHARACTER  (miembro de la party de prueba)
#   TVP772_MONSTER_BASE_EXP   (experiencia base del monstruo de prueba)
# Opcionales:
#   TVP772_GOD_ACCOUNT        (si el god vive en otra cuenta; por defecto la
#   TVP772_GOD_PASSWORD        misma que la del primer participante)
#   TVP772_PLAYER2_ACCOUNT    (idem para el segundo participante)
#   TVP772_PLAYER2_PASSWORD
#   TVP772_HOST, TVP772_LOGIN_PORT
#
# IMPORTANTE: el servidor rechaza dos sesiones simultaneas de la MISMA cuenta
# para personajes normales ("You may only login with one character of your
# account at the same time"). Un god puede saltarse eso por su bandera
# `canalwayslogin`, pero dos participantes normales NO. Por eso cada
# participante necesita su propia cuenta.
#
# El god NO participa de la party: su grupo tiene `notgainexperience`, asi que
# no podria demostrarse que "ambos participantes ganan experiencia".
#
#   ...Godot --headless --path cliente3d pruebas/prueba_parity_party_shared_exp_capture.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST_DEFECTO := "127.0.0.1"
const PUERTO_LOGIN_DEFECTO := 7171
## Terreno aislado y colocable calificado en Phase 2C.1/2C.2. Detalle de
## implementacion: nunca entra al payload normalizado.
const POS_CAMPO := Vector3i(32008, 32400, 7)
const RADIO_LLEGADA := 3
const MONSTRUO := "cave rat"

const SHIELD_MIEMBRO := 3
const SHIELD_LIDER := 4

const PAUSA_SESION := 6.0
const ESPERA_PASO := 20.0
const ESPERA_MENSAJE := 8.0
const ESPERA_COMBATE := 90.0
## El signo de batalla dura `pzLocked` = 60 s (`servidor/config.lua:79`); se
## deja margen para que expire y para los reintentos de desactivacion.
const ESPERA_SIN_COMBATE := 100.0
const LIMITE_TOTAL := 420.0
## Guarda de seguridad: si un participante baja de esto, se aborta.
const VIDA_MINIMA_SEGURA := 40
## Niveles de habilidad de punos que el god suma a cada personaje de QA para
## que el combate de prueba sea decidible. Moderado a proposito: ver `_reforzar`.
const PUNOS_EXTRA := 18
## Niveles que el god suma a cada personaje de QA. Sube la vida maxima y cura
## por cada avance (`player.cpp:1532-1533`), asi que tambien saca a los
## personajes de la resaca de vida baja de una corrida anterior. Se aplica
## ANTES de tomar la foto de experiencia, y la medicion es un delta, asi que
## no contamina lo que este fixture mide. A los dos por igual, para no romper
## la regla de nivel de la party.
const NIVELES_EXTRA := 12

var _con_login
var _con_god
var _con_p1
var _con_p2
var _estado_god
var _estado_p1
var _estado_p2
var _puertos := {}
var _fase := "login"
var _espera := 0.0
var _total := 0.0
var _terminando := false

var _cuenta := 0
var _clave := ""
var _cuenta_god := 0
var _clave_god := ""
var _puerto_god := 0
var _cuenta_p2 := 0
var _clave_p2 := ""
var _puerto_p2 := 0
var _nombre_god := ""
var _nombre_p1 := ""
var _nombre_p2 := ""
var _host := HOST_DEFECTO
var _puerto_login := PUERTO_LOGIN_DEFECTO

var _id_p2_visto_por_p1 := 0
var _id_p1_visto_por_p2 := 0
var _id_monstruo := 0
var _id_monstruo_p2 := 0
## Ids conocidos por cada sesion ANTES de invocar: el monstruo de prueba se
## identifica por ser el id NUEVO, no por su nombre. Asi la fauna natural que
## ya estuviera en el campo no vuelve ambigua la identidad ni hay que matarla.
var _ids_previos_p1 := {}
var _ids_previos_p2 := {}
var _ultimo_reataque := 0.0
var _reforzado := false
var _refuerzo_listo := false
var _desactivacion_en_combate_pedida := false
var _ultimo_intento_desactivar := 0.0

## Mensajes de experiencia compartida observados, normalizados a semantica.
var _msg_activada_habilitada := 0
var _msg_activada_inactivos := 0
var _msg_desactivada := 0

var _exp_p1_antes := -1
var _exp_p2_antes := -1
var _p1_daño := false
var _p2_daño := false
## `_process` vuelve a entrar en la fase cada frame; el `await` de la
## formacion de party no lo frena. Sin esta guarda la invitacion se reenvia
## en bucle.
var _party_solicitada := false
var _obs := {}
var _multiplicador := 1.20
var _exp_bruta := 0


func _ready() -> void:
	print("=================================================")
	print(" TVP3D QA - captura en vivo: experiencia compartida")
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
	_nombre_god = OS.get_environment("TVP772_GOD_CHARACTER")
	if _nombre_god.is_empty():
		return "TVP772_GOD_CHARACTER"
	_nombre_p1 = OS.get_environment("TVP772_PLAYER_CHARACTER")
	if _nombre_p1.is_empty():
		return "TVP772_PLAYER_CHARACTER"
	_nombre_p2 = OS.get_environment("TVP772_PLAYER2_CHARACTER")
	if _nombre_p2.is_empty():
		return "TVP772_PLAYER2_CHARACTER"
	var host_env := OS.get_environment("TVP772_HOST")
	if not host_env.is_empty():
		_host = host_env
	var puerto_env := OS.get_environment("TVP772_LOGIN_PORT")
	if not puerto_env.is_empty() and puerto_env.is_valid_int():
		_puerto_login = int(puerto_env)
	var exp_env := OS.get_environment("TVP772_MONSTER_BASE_EXP")
	if not exp_env.is_empty() and exp_env.is_valid_int():
		_exp_bruta = int(exp_env)
	if _exp_bruta <= 0:
		return "TVP772_MONSTER_BASE_EXP"

	# El god puede vivir en otra cuenta. Por defecto, la misma.
	_cuenta_god = _cuenta
	_clave_god = _clave
	var cuenta_god_env := OS.get_environment("TVP772_GOD_ACCOUNT")
	if not cuenta_god_env.is_empty() and cuenta_god_env.is_valid_int():
		_cuenta_god = int(cuenta_god_env)
	var clave_god_env := OS.get_environment("TVP772_GOD_PASSWORD")
	if not clave_god_env.is_empty():
		_clave_god = clave_god_env

	# El segundo participante tambien puede vivir en otra cuenta, y de hecho
	# DEBE hacerlo si el servidor prohibe dos sesiones normales por cuenta.
	_cuenta_p2 = _cuenta
	_clave_p2 = _clave
	var cuenta_p2_env := OS.get_environment("TVP772_PLAYER2_ACCOUNT")
	if not cuenta_p2_env.is_empty() and cuenta_p2_env.is_valid_int():
		_cuenta_p2 = int(cuenta_p2_env)
	var clave_p2_env := OS.get_environment("TVP772_PLAYER2_PASSWORD")
	if not clave_p2_env.is_empty():
		_clave_p2 = clave_p2_env
	return ""


func _process(delta: float) -> void:
	_total += delta
	_espera += delta
	if _terminando:
		return
	if _total > LIMITE_TOTAL:
		_fallar("FAIL tiempo agotado en la fase '%s'" % _fase)
		return
	# Guarda de seguridad continua sobre ambos participantes, activa recien
	# desde el refuerzo. Antes de esa etapa una vida baja es resaca de una
	# corrida anterior, no peligro creado por esta prueba, y es justamente el
	# refuerzo el que la levanta; abortar ahi dejaba la prueba trabada sin
	# forma de recuperarse.
	if _refuerzo_listo:
		for estado in [_estado_p1, _estado_p2]:
			if estado != null and estado.adentro:
				var v := int(estado.estadisticas.get("vida", -1))
				if v >= 0 and v < VIDA_MINIMA_SEGURA:
					_fallar("FAIL un participante bajo del minimo seguro de vida; se aborta sin emitir observacion")
					return
	match _fase:
		"esperar god":
			if _estado_god != null and _estado_god.adentro and _espera > 2.0:
				_pasar_a("pausa p1")
		"pausa p1":
			if _espera >= PAUSA_SESION:
				_abrir_p1()
		"esperar p1":
			if _estado_p1 != null and _estado_p1.adentro and _espera > 2.0:
				_pasar_a("pausa p2")
		"pausa p2":
			if _espera >= PAUSA_SESION:
				_abrir_p2()
		"esperar p2":
			if _estado_p2 != null and _estado_p2.adentro and _espera > 2.0:
				_ir_al_campo()
		"esperar god campo":
			_esperar_god_campo()
		"reunir p1":
			_reunir(_estado_p1, _nombre_p1, "reunir p2")
		"reunir p2":
			_reunir(_estado_p2, _nombre_p2, "formar party")
		"formar party":
			_formar_party()
		"esperar party":
			_esperar_party()
		"no lider solicita":
			_no_lider_solicita()
		"esperar no lider":
			_esperar_no_lider()
		"lider solicita":
			_lider_solicita()
		"esperar inactivos":
			_esperar_inactivos()
		"reforzar":
			_reforzar()
		"invocar":
			_invocar()
		"esperar monstruo":
			_esperar_monstruo()
		"combate":
			_combate()
		"medir":
			_medir()
		"desactivar en combate":
			_desactivar_en_combate()
		"desactivar":
			_desactivar()


# -----------------------------------------------------------------
#  Sesiones
# -----------------------------------------------------------------
func _abrir_login() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.error_red.connect(func(t): _fallar("FAIL fallo de red en login: %s" % t))
	_con_login.lista_personajes.connect(_al_lista)
	_con_login.pedir_personajes(_host, _puerto_login, _cuenta, _clave)


## Primer login: cuenta de los dos participantes de la party.
func _al_lista(_motd: String, personajes: Array) -> void:
	for entrada in personajes:
		_puertos[str(entrada.get("nombre", ""))] = int(entrada.get("puerto", 0))
	if int(_puertos.get(_nombre_p1, 0)) <= 0:
		_fallar("FAIL character configured by TVP772_PLAYER_CHARACTER was not found")
		return
	_con_login.cerrar()
	_con_login.queue_free()
	_con_login = null
	_login_p2()


## Login del segundo participante, que puede estar en otra cuenta.
func _login_p2() -> void:
	var login = CONEXION.new()
	add_child(login)
	login.error_red.connect(func(t): _fallar("FAIL fallo de red en login del miembro: %s" % t))
	login.lista_personajes.connect(func(_m, lista):
		for entrada in lista:
			if str(entrada.get("nombre", "")) == _nombre_p2:
				_puerto_p2 = int(entrada.get("puerto", 0))
		if _puerto_p2 <= 0:
			_fallar("FAIL character configured by TVP772_PLAYER2_CHARACTER was not found")
			return
		login.cerrar()
		_login_god())
	login.pedir_personajes(_host, _puerto_login, _cuenta_p2, _clave_p2)


## Segundo login: cuenta del god, que puede ser distinta.
func _login_god() -> void:
	var login = CONEXION.new()
	add_child(login)
	login.error_red.connect(func(t): _fallar("FAIL fallo de red en login del god: %s" % t))
	login.lista_personajes.connect(func(_m, lista):
		for entrada in lista:
			if str(entrada.get("nombre", "")) == _nombre_god:
				_puerto_god = int(entrada.get("puerto", 0))
		if _puerto_god <= 0:
			_fallar("FAIL character configured by TVP772_GOD_CHARACTER was not found")
			return
		login.cerrar()
		_abrir_god())
	login.pedir_personajes(_host, _puerto_login, _cuenta_god, _clave_god)


func _abrir_god() -> void:
	_estado_god = ESTADO.new()
	_estado_god.pedido_ping.connect(func(): _con_god.enviar_juego(PackedByteArray([0x1E])))
	_estado_god.rechazados.connect(func(m): _fallar("FAIL el god fue rechazado: %s" % m))
	_con_god = CONEXION.new()
	add_child(_con_god)
	_con_god.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red del god: %s" % t))
	_con_god.paquete_juego.connect(func(m): _estado_god.procesar(m))
	_con_god.entrar_al_mundo(_host, _puerto_god, _cuenta_god, _nombre_god, _clave_god)
	_pasar_a("esperar god")


func _abrir_p1() -> void:
	_estado_p1 = ESTADO.new()
	_estado_p1.pedido_ping.connect(func(): _con_p1.enviar_juego(PackedByteArray([0x1E])))
	_estado_p1.rechazados.connect(func(m): _fallar("FAIL el lider fue rechazado: %s" % m))
	_estado_p1.mensaje_servidor.connect(func(t): _al_mensaje("P1", t))
	_con_p1 = CONEXION.new()
	add_child(_con_p1)
	_con_p1.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red del lider: %s" % t))
	_con_p1.paquete_juego.connect(func(m): _estado_p1.procesar(m))
	_con_p1.entrar_al_mundo(_host, int(_puertos[_nombre_p1]), _cuenta, _nombre_p1, _clave)
	_pasar_a("esperar p1")


func _abrir_p2() -> void:
	_estado_p2 = ESTADO.new()
	_estado_p2.pedido_ping.connect(func(): _con_p2.enviar_juego(PackedByteArray([0x1E])))
	_estado_p2.rechazados.connect(func(m): _fallar("FAIL el miembro fue rechazado: %s" % m))
	_estado_p2.mensaje_servidor.connect(func(t): _al_mensaje("P2", t))
	_con_p2 = CONEXION.new()
	add_child(_con_p2)
	_con_p2.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red del miembro: %s" % t))
	_con_p2.paquete_juego.connect(func(m): _estado_p2.procesar(m))
	_con_p2.entrar_al_mundo(_host, _puerto_p2, _cuenta_p2, _nombre_p2, _clave_p2)
	_pasar_a("esperar p2")


## Clasificacion semantica de los mensajes de experiencia compartida. No se
## versiona el texto: solo se cuentan los tres estados posibles.
func _al_mensaje(quien: String, texto: String) -> void:
	print("  [%s] %s" % [quien, texto])
	var t := texto.to_lower()
	if not t.contains("shared experience"):
		return
	if t.contains("deactivated"):
		_msg_desactivada += 1
	elif t.contains("inactive"):
		_msg_activada_inactivos += 1
	elif t.contains("now active"):
		_msg_activada_habilitada += 1


# -----------------------------------------------------------------
#  Preparacion
# -----------------------------------------------------------------
func _ir_al_campo() -> void:
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
		POS_CAMPO.x, POS_CAMPO.y, POS_CAMPO.z])
	_pasar_a("esperar god campo")


func _esperar_god_campo() -> void:
	if _cerca(_estado_god.mi_pos, POS_CAMPO):
		_pasar_a("reunir p1")
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL el god no llego al campo a tiempo")


func _reunir(estado, nombre: String, siguiente: String) -> void:
	if _cerca(estado.mi_pos, POS_CAMPO):
		_pasar_a(siguiente)
		return
	if _espera < 0.2:
		return
	if _espera < 0.5:
		_con_god.enviar_hablar("/c %s" % nombre)
	if _espera > ESPERA_PASO:
		_fallar("FAIL /c no acerco a un participante al campo")


## Se resuelve al companero por su NOMBRE configurado, nunca "la otra
## criatura que haya": el campo puede tener fauna natural y una rata
## silvestre llegaria a recibir la invitacion de party. El nombre vive solo
## en memoria de proceso y nunca se serializa.
func _id_por_nombre(estado, nombre: String) -> int:
	for id in estado.criaturas:
		if int(id) == int(estado.mi_id):
			continue
		if str(estado.criaturas[id].get("nombre", "")) == nombre:
			return int(id)
	return 0


func _formar_party() -> void:
	if _id_p2_visto_por_p1 == 0:
		_id_p2_visto_por_p1 = _id_por_nombre(_estado_p1, _nombre_p2)
	if _id_p1_visto_por_p2 == 0:
		_id_p1_visto_por_p2 = _id_por_nombre(_estado_p2, _nombre_p1)
	if _id_p2_visto_por_p1 == 0 or _id_p1_visto_por_p2 == 0:
		if _espera > ESPERA_PASO:
			_fallar("FAIL los dos participantes no llegaron a verse mutuamente")
		return
	if _party_solicitada:
		return
	_party_solicitada = true
	print("Formando party de prueba: P1 invita, P2 se une.")
	_con_p1.enviar_invitar_a_party(_id_p2_visto_por_p1)
	await get_tree().create_timer(1.5).timeout
	if _terminando:
		return
	_con_p2.enviar_unirse_a_party(_id_p1_visto_por_p2)
	_pasar_a("esperar party")


func _esperar_party() -> void:
	var p1_ve := int(_estado_p1.criaturas.get(_id_p2_visto_por_p1, {}).get("escudo_party", 0))
	var p2_ve := int(_estado_p2.criaturas.get(_id_p1_visto_por_p2, {}).get("escudo_party", 0))
	if p1_ve == SHIELD_MIEMBRO and p2_ve == SHIELD_LIDER:
		print("Party formada: P1 lider, P2 miembro.")
		_pasar_a("no lider solicita")
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL la party de prueba no quedo formada a tiempo")


# -----------------------------------------------------------------
#  Autoridad: solo el lider puede solicitar
# -----------------------------------------------------------------
func _no_lider_solicita() -> void:
	## Se prueba ANTES de que el lider active nada: si el miembro pudiera
	## activar, aparecería alguno de los mensajes de activacion. Su ausencia
	## es entonces un discriminador limpio.
	print("El MIEMBRO (no lider) solicita activar experiencia compartida.")
	_con_p2.enviar_experiencia_compartida(true)
	_pasar_a("esperar no lider")


func _esperar_no_lider() -> void:
	if _espera < ESPERA_MENSAJE:
		return
	var hubo_activacion := (_msg_activada_habilitada + _msg_activada_inactivos) > 0
	if hubo_activacion:
		_fallar("FAIL un no-lider logro activar la experiencia compartida")
		return
	print("Confirmado: la solicitud del no-lider no produjo ninguna transicion.")
	_obs["transport"] = {"non_leader_request_rejected": true}
	_pasar_a("lider solicita")


# -----------------------------------------------------------------
#  Solicitado vs habilitado
# -----------------------------------------------------------------
func _lider_solicita() -> void:
	print("El LIDER solicita activar experiencia compartida (aun sin participacion reciente).")
	_con_p1.enviar_experiencia_compartida(true)
	_pasar_a("esperar inactivos")


func _esperar_inactivos() -> void:
	if _msg_activada_inactivos > 0:
		print("Confirmado: solicitud aceptada pero NO habilitada por participantes inactivos.")
		_obs["transport"]["leader_can_request_enable"] = true
		_obs["inactive_party"] = {"requested_active": true, "enabled": false}
		_pasar_a("reforzar")
		return
	if _msg_activada_habilitada > 0:
		_fallar("FAIL quedo habilitada sin participacion reciente; la regla de actividad no se observo")
		return
	if _espera > ESPERA_MENSAJE:
		_fallar("FAIL el servidor no confirmo la solicitud del lider a tiempo")


# -----------------------------------------------------------------
#  Actividad controlada y medicion
# -----------------------------------------------------------------
## Dos personajes de nivel 1 a puno limpio no bajan a un monstruo antes de
## que el monstruo los baje a ellos: la corrida anterior mostro 97% de vida
## del monstruo tras 5 s y el piso de seguridad se activo. Se sube SOLO la
## habilidad de punos de los dos personajes de QA.
##
## Por que punos y no nivel: `/addSkill ... level` suma niveles y por lo tanto
## EXPERIENCIA, que es justo la magnitud que este fixture mide; contaminaria
## la medicion. La habilidad de punos no toca la experiencia.
##
## Por que lo hace el god y no un ataque del god: si el god danara al
## monstruo, su parte proporcional del dano (creature.cpp:375) saldria del
## pozo de la party, porque el god no es miembro, y el reparto ya no
## coincidiria con la formula. El god no golpea nunca al monstruo.
##
## El refuerzo es deliberadamente moderado para que hagan falta varios
## golpes: si uno solo matara al monstruo de un golpe, el otro no llegaria a
## registrar participacion reciente y el reparto no se habilitaria.
func _reforzar() -> void:
	if not _reforzado:
		_reforzado = true
		print("Reforzando punos y vitalidad de los dos personajes de prueba.")
		_con_god.enviar_hablar("/addSkill %s, fist, %d" % [_nombre_p1, PUNOS_EXTRA])
		_con_god.enviar_hablar("/addSkill %s, fist, %d" % [_nombre_p2, PUNOS_EXTRA])
		_con_god.enviar_hablar("/addSkill %s, level, %d" % [_nombre_p1, NIVELES_EXTRA])
		_con_god.enviar_hablar("/addSkill %s, level, %d" % [_nombre_p2, NIVELES_EXTRA])
		return
	if _espera < 3.0:
		return
	# El refuerzo solo se da por bueno cuando los dos estan efectivamente por
	# encima del piso de seguridad; recien ahi se arma la guarda continua.
	var v1 := int(_estado_p1.estadisticas.get("vida", -1))
	var v2 := int(_estado_p2.estadisticas.get("vida", -1))
	if v1 < VIDA_MINIMA_SEGURA or v2 < VIDA_MINIMA_SEGURA:
		if _espera > ESPERA_PASO:
			_fallar("FAIL el refuerzo no dejo a los dos participantes por encima del piso de vida")
		return
	print("Refuerzo aplicado: ambos participantes en condiciones de pelear.")
	_refuerzo_listo = true
	_pasar_a("invocar")


func _invocar() -> void:
	_exp_p1_antes = int(_estado_p1.estadisticas.get("experiencia", -1))
	_exp_p2_antes = int(_estado_p2.estadisticas.get("experiencia", -1))
	if _exp_p1_antes < 0 or _exp_p2_antes < 0:
		if _espera > ESPERA_PASO:
			_fallar("FAIL no se pudo leer la experiencia autoritativa de ambos participantes")
		return
	# Sin limpieza amplia y sin matar fauna preexistente: en vez de exigir un
	# campo vacio, se anotan los ids conocidos ANTES de invocar y despues se
	# exige exactamente un id NUEVO por sesion. Asi la fauna natural que
	# ronde el campo no puede confundirse con el monstruo de prueba, y
	# tampoco hace falta tocarla.
	_ids_previos_p1.clear()
	for id in _estado_p1.criaturas:
		_ids_previos_p1[int(id)] = true
	_ids_previos_p2.clear()
	for id in _estado_p2.criaturas:
		_ids_previos_p2[int(id)] = true
	print("Invocando un unico monstruo de prueba.")
	_con_god.enviar_hablar("/m %s" % MONSTRUO)
	_pasar_a("esperar monstruo")


## Devuelve los ids del tipo de monstruo de prueba que NO estaban antes de
## invocar. Se exige exactamente uno: cero significa que todavia no llego, y
## mas de uno significa identidad ambigua (fauna que entro justo en la misma
## ventana), caso en el que no se mide nada.
func _monstruos_nuevos(estado, previos: Dictionary) -> Array:
	var nuevos: Array = []
	for id in estado.criaturas:
		if previos.has(int(id)):
			continue
		var criatura: Dictionary = estado.criaturas[id]
		if int(criatura.get("vida", 100)) <= 0:
			continue
		if str(criatura.get("nombre", "")).to_lower() == MONSTRUO:
			nuevos.append(int(id))
	return nuevos


func _esperar_monstruo() -> void:
	var nuevos_p1 := _monstruos_nuevos(_estado_p1, _ids_previos_p1)
	var nuevos_p2 := _monstruos_nuevos(_estado_p2, _ids_previos_p2)
	if nuevos_p1.size() > 1 or nuevos_p2.size() > 1:
		_fallar("BLOCKED aparecio mas de un %s nuevo; identidad ambigua, no se mide" % MONSTRUO)
		return
	if nuevos_p1.is_empty() or nuevos_p2.is_empty():
		if _espera > ESPERA_PASO:
			_fallar("FAIL el monstruo de prueba no aparecio para ambos participantes")
		return
	# Cada sesion ve al mismo monstruo con su propio runtime id.
	_id_monstruo = int(nuevos_p1[0])
	_id_monstruo_p2 = int(nuevos_p2[0])
	print("Monstruo de prueba visible; ambos participantes lo atacan.")
	_con_p1.enviar_modos_combate(1, 1, 0)
	_con_p2.enviar_modos_combate(1, 1, 0)
	_con_p1.enviar_atacar(_id_monstruo)
	_con_p2.enviar_atacar(_id_monstruo_p2)
	_pasar_a("combate")


func _combate() -> void:
	## Ambos deben haber danado al monstruo para registrar participacion.
	var vivo: bool = _estado_p1.criaturas.has(_id_monstruo) \
		and int(_estado_p1.criaturas[_id_monstruo].get("vida", 0)) > 0
	if vivo:
		# El servidor cancela el objetivo si el monstruo se aleja o si el
		# jugador deja de seguirlo. Se reenvia la orden periodicamente y se
		# informa la vida vista para que un fallo por falta de dano sea
		# distinguible de un fallo por objetivo perdido.
		if _espera - _ultimo_reataque >= 5.0:
			_ultimo_reataque = _espera
			var vida_vista := int(_estado_p1.criaturas[_id_monstruo].get("vida", -1))
			print("  combate %ds: vida del monstruo vista por P1 = %d%%"
				% [int(_espera), vida_vista])
			_con_p1.enviar_modos_combate(1, 1, 0)
			_con_p2.enviar_modos_combate(1, 1, 0)
			_con_p1.enviar_atacar(_id_monstruo)
			_con_p2.enviar_atacar(_id_monstruo_p2)
		if _espera > ESPERA_COMBATE:
			_fallar("FAIL el monstruo de prueba no murio a tiempo")
		return
	print("El monstruo de prueba murio; midiendo la experiencia de ambos.")
	_pasar_a("medir")


func _medir() -> void:
	if _espera < 2.0:
		return
	var exp1 := int(_estado_p1.estadisticas.get("experiencia", -1))
	var exp2 := int(_estado_p2.estadisticas.get("experiencia", -1))
	var g1 := exp1 - _exp_p1_antes
	var g2 := exp2 - _exp_p2_antes
	var esperado := int(ceil(float(_exp_bruta) * _multiplicador / 2.0))
	print("Ganancias observadas (relacion, no totales): iguales=%s, coinciden con la formula=%s"
		% [str(g1 == g2), str(g1 == esperado and g2 == esperado)])
	if g1 <= 0 or g2 <= 0:
		_fallar("FAIL no ambos participantes ganaron experiencia (g1>0=%s, g2>0=%s)"
			% [str(g1 > 0), str(g2 > 0)])
		return
	## Nada se afirma "porque si": cada hecho se deriva de lo observado.
	## `enabled` no es legible desde afuera, se prueba POR COMPORTAMIENTO:
	## sin habilitar, el servidor paga a cada atacante su parte proporcional
	## al dano (creature.cpp:375) y las ganancias serian distintas; solo con
	## el reparto habilitado se juntan en un pozo y se pagan iguales.
	var repartido: bool = g1 > 0 and g2 > 0 and g1 == g2
	_obs["activity_gate"] = {
		## Antes de participar el servidor dijo explicitamente que NO estaba
		## habilitado; despues de participar hubo reparto sin volver a pedirlo.
		"enabled_only_after_participation": _msg_activada_inactivos > 0 and repartido,
	}
	_obs["eligible_party"] = {"requested_active": true, "enabled": repartido}
	_obs["distribution"] = {
		"both_participants_gain_experience": g1 > 0 and g2 > 0,
		"same_share_for_each_participant": g1 == g2,
		"share_matches_legacy_formula": (g1 == esperado and g2 == esperado),
	}
	_pasar_a("desactivar en combate")


## Recien matado el monstruo el lider sigue con el signo de batalla, y el
## servidor DESCARTA la orden en silencio: `Game::playerEnableSharedPartyExperience`
## (game.cpp:5097) vuelve sin hacer nada si hay `CONDITION_INFIGHT` fuera de
## zona protegida. No manda mensaje ni cambia el estado. Eso no es un
## problema del adaptador: es una regla del oracle, y se registra como tal.
func _desactivar_en_combate() -> void:
	if not _desactivacion_en_combate_pedida:
		_desactivacion_en_combate_pedida = true
		print("El LIDER pide desactivar con el signo de batalla puesto.")
		_con_p1.enviar_experiencia_compartida(false)
		return
	if _msg_desactivada > 0:
		_fallar("FAIL la desactivacion se acepto con signo de batalla; la regla de combate no se observo")
		return
	if _espera > ESPERA_MENSAJE:
		print("Confirmado: con signo de batalla la orden se descarta sin transicion.")
		_obs["disable_in_fight"] = {"request_ignored_while_in_fight": true}
		_pasar_a("desactivar")


## Ya sin combate la misma orden si tiene que ser aceptada. El signo de
## batalla dura `pzLocked` (60 s en `config.lua:79`), asi que se reintenta
## hasta que expire en vez de asumir un tiempo exacto.
func _desactivar() -> void:
	if _espera - _ultimo_intento_desactivar >= 10.0 or _ultimo_intento_desactivar == 0.0:
		_ultimo_intento_desactivar = _espera
		print("El LIDER solicita desactivar la experiencia compartida (%ds)." % int(_espera))
		_con_p1.enviar_experiencia_compartida(false)
	if _msg_desactivada > 0:
		print("Confirmado: desactivacion explicita del servidor.")
		_obs["disable"] = {"requested_active": false, "enabled": false}
		_emitir_observacion()
		return
	if _espera > ESPERA_SIN_COMBATE:
		_fallar("FAIL el servidor no confirmo la desactivacion ni despues de expirar el signo de batalla")


# -----------------------------------------------------------------
#  Observacion normalizada
# -----------------------------------------------------------------
func _emitir_observacion() -> void:
	## Ningun nombre, nivel, vocacion, id ni experiencia total. Solo hechos
	## semanticos y relaciones.
	var linea := "OBSERVATION_JSON: " + JSON.stringify(_obs)
	print(linea)
	print("Captura de experiencia compartida: OK")
	_limpiar()
	_terminar(0)


# -----------------------------------------------------------------
#  Limpieza
# -----------------------------------------------------------------
func _limpiar() -> void:
	## El monstruo de prueba ya murio como parte del recorrido. Se deshace la
	## party de prueba y se devuelve a ambos participantes a su templo.
	if _con_p1 != null:
		_con_p1.enviar_salir_de_party()
	if _con_p2 != null:
		_con_p2.enviar_salir_de_party()
	if _con_god != null:
		_con_god.enviar_hablar("omani %s" % _nombre_p1)
		_con_god.enviar_hablar("omani %s" % _nombre_p2)


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
	_limpiar()
	_terminar(1)


func _terminar(codigo: int) -> void:
	if _terminando:
		return
	_terminando = true
	await get_tree().create_timer(2.0).timeout
	if _con_god != null:
		_con_god.cerrar()
	if _con_p1 != null:
		_con_p1.cerrar()
	if _con_p2 != null:
		_con_p2.cerrar()
	get_tree().quit(codigo)
