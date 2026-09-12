extends Node

# Captura QA-owned en vivo: REGLA DE RANGO de la experiencia compartida
# (Phase 2D.1). Fixture `PARITY-PARTY-SHARED-EXP-RANGE-001`.
#
# Adaptador SEPARADO del de `PARITY-PARTY-SHARED-EXP-001`, que ya esta
# certificado en vivo y endurecido: aquel archivo NO se toca ni se extiende.
#
# Esta rama NO decide PASS/FAIL: lo hace `qa/parity/tools/replay.py` contra la
# `ParityExpectationV1` publicada. Este script solo observa y serializa.
#
# ---------------------------------------------------------------------------
# REGLA QUE SE PRUEBA, VERIFICADA EN EL CODIGO VIGENTE DEL ORACLE
# ---------------------------------------------------------------------------
#
# `Party::canUseSharedExperience` (`servidor/src/party.cpp:356`):
#
#     if (!Position::areInRange<30, 30, 1>(leader->getPosition(),
#                                          player->getPosition())) {
#         return false;
#     }
#
# y la plantilla (`servidor/src/position.h:32-35`) es exactamente
#
#     getDistanceX(p1,p2) <= 30 && getDistanceY(p1,p2) <= 30
#                              && getDistanceZ(p1,p2) <= 1
#
# es decir distancias ABSOLUTAS POR EJE con limite INCLUSIVO. No es distancia
# euclidiana ni de Chebyshev, y el eje Z tolera un piso de diferencia.
#
# ---------------------------------------------------------------------------
# POR QUE HACE FALTA FORZAR UNA REEVALUACION
# ---------------------------------------------------------------------------
#
# Moverse NO recalcula `sharedExpEnabled` por si solo. Las UNICAS llamadas a
# `Party::updateSharedExperience()` en el oracle son:
#
#     party.cpp:113  leaveParty()
#     party.cpp:146  passPartyLeadership()
#     party.cpp:197  joinParty()
#     party.cpp:392  updatePlayerTicks()
#     party.cpp:401  clearPlayerPoints()
#
# Ninguna cuelga del movimiento. Por eso la separacion sola no basta y la
# reevaluacion se fuerza con dano autoritativo del LIDER a un segundo monstruo
# hostil:
#
#     Player::onAttackedCreatureDrainHealth (player.cpp:3218-3231)
#       -> party->updatePlayerTicks(this, points)      [points != 0]
#       -> Party::updateSharedExperience()             (party.cpp:392)
#       -> Party::canEnableSharedExperience()          (party.cpp:291)
#       -> Party::canUseSharedExperience(cada participante)
#
# El monstruo TIENE que ser hostil: `player.cpp:3225` exige
# `tmpMonster->isHostile()`, y en este fork `Monster::isHostile()`
# (`servidor/src/monster.h:115-117`) es
# `baseSkill != 0 && health > runAwayHealth`. Por eso los golpes que cuentan
# son los que caen mientras al monstruo le queda vida por encima de su umbral
# de huida, no los ultimos.
#
# Con el reparto deshabilitado, `Creature::death` (`creature.cpp:391-407`) ya
# no mete la parte del atacante en el pozo de la party: la paga individual al
# unico atacante. El miembro distante no figura en `damageMap` del segundo
# monstruo, asi que no cobra nada.
#
# ---------------------------------------------------------------------------
# AISLAMIENTO FRENTE AL VENCIMIENTO DE ACTIVIDAD
# ---------------------------------------------------------------------------
#
# Un 0 de experiencia del miembro tambien lo produciria que se le venciera la
# participacion. Ese confundidor se aisla por DOS vias independientes:
#
# 1. `canUseSharedExperience` borra la elegibilidad si el miembro no esta en
#    `ticksMap`. Quien lo saca de ahi es `Party::clearPlayerPoints`, llamado
#    desde `Player::onIdleStatus` (`player.cpp:3201-3208`) cuando TERMINA
#    `CONDITION_INFIGHT` (`player.cpp:3106-3113`). Esa condicion es la que
#    enciende `ICON_SWORDS` (`condition.cpp:272-274`, `const.h:139`), que el
#    cliente recibe en el `0xA2` y expone como `estado.en_combate`. Si el
#    miembro conserva su signo de batalla en el instante de la medicion
#    negativa, el servidor no puede haberle limpiado los puntos.
#
# 2. Aunque siga en `ticksMap`, la entrada caduca si
#    `OTSYS_TIME() - tick > PZ_LOCKED` (`party.cpp:366-369`), con
#    `pzLocked = 60000` (`servidor/config.lua:79`). Se acota con un
#    presupuesto de tiempo ESTRICTO y del lado seguro: se mide desde que el
#    miembro EMPIEZA a golpear al primer monstruo (su tick no puede ser
#    anterior a eso) hasta que muere el segundo. Si ese total supera
#    `VENTANA_FRESCURA` la captura devuelve BLOCKED y NO declara un resultado
#    de rango.
#
# ---------------------------------------------------------------------------
# ESTA CAPTURA NO MODIFICA LA PROGRESION DE NADIE
# ---------------------------------------------------------------------------
#
# No emite `/addSkill` ni ningun comando administrativo que suba nivel,
# habilidades, magia, vida, mana, vocacion ni experiencia. Los unicos comandos
# que manda el god son `/gotopos`, `/c`, `/m` y el `omani` de limpieza; se
# pueden auditar buscando `enviar_hablar` en este archivo.
#
# El estado actual de los personajes de QA es una PRECONDICION DE ENTORNO que
# se comprueba, nunca algo que esta captura fabrique. Si no estan en
# condiciones devuelve BLOCKED y no toca a nadie.
#
# ---------------------------------------------------------------------------
# POR QUE NO SE HEREDA `PUNO_MINIMO` DEL ADAPTADOR POSITIVO
# ---------------------------------------------------------------------------
#
# El adaptador de Phase 2D.0.1 exige `habilidades.puno.nivel >= 20`. Eso era
# una heuristica OPERATIVA para combate a puno limpio, y mide la cosa
# equivocada en cuanto un participante pelea con arma: la propia evidencia de
# Phase 2D.0.1 registra que a un participante le subio GARROTE (+1) durante la
# corrida, o sea que el dano no salia de los punos. Un piso de punos puede
# entonces bloquear a un participante perfectamente capaz, o dejar pasar a uno
# incapaz.
#
# Aca la capacidad de combate se establece de forma GENERICA y empirica: no se
# exige ninguna habilidad concreta, se exige que el primer monstruo de prueba
# efectivamente MUERA dentro de `ESPERA_COMBATE` y que ambos participantes
# hayan registrado dano (probado por el reparto en partes iguales). Si no
# muere, la captura devuelve BLOCKED informando el ritmo observado. Esto es
# una precondicion del harness, no semantica de paridad: no entra al payload.
#
# ---------------------------------------------------------------------------
# CREDENCIALES: SOLO POR ENTORNO, NUNCA LITERALES, NUNCA IMPRESAS
# ---------------------------------------------------------------------------
#   TVP772_ACCOUNT            cuenta del LIDER de la party de prueba
#   TVP772_PASSWORD
#   TVP772_PLAYER_CHARACTER   lider
#   TVP772_PLAYER2_ACCOUNT    cuenta del MIEMBRO (tiene que ser otra cuenta)
#   TVP772_PLAYER2_PASSWORD
#   TVP772_PLAYER2_CHARACTER  miembro
#   TVP772_GOD_ACCOUNT        god operador; no entra a la party
#   TVP772_GOD_PASSWORD
#   TVP772_GOD_CHARACTER
#   TVP772_MONSTER_BASE_EXP   experiencia base del PRIMER monstruo de prueba
# Opcionales:
#   TVP772_HOST, TVP772_LOGIN_PORT
#   TVP772_MONSTER            especie del primer monstruo  (def. "cave rat")
#   TVP772_MONSTER2           especie del segundo monstruo (def. "rat")
#
# El servidor rechaza dos sesiones simultaneas de la MISMA cuenta para
# personajes normales, asi que lider y miembro necesitan cuentas distintas.
# El god esquiva esa restriccion por su bandera `canalwayslogin`.
#
# El god NO entra a la party y NUNCA golpea a ningun monstruo: su grupo tiene
# `notgainexperience`, y ademas su parte proporcional del dano le RESTARIA al
# pozo de la party (`creature.cpp:375`) porque no es miembro.
#
#   ...Godot --headless --path cliente3d \
#       pruebas/prueba_parity_party_shared_exp_range_capture.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST_DEFECTO := "127.0.0.1"
const PUERTO_LOGIN_DEFECTO := 7171

## Par de casillas ya calificado en Phase 2C.1/2C.2 y reusado por Phase 2D:
## mismo piso, colocables, operacionalmente aisladas, dy = 61.
## Es detalle de implementacion del harness: NUNCA entra al payload.
const POS_A := Vector3i(32008, 32400, 7)
const POS_B := Vector3i(32008, 32339, 7)
const RADIO_LLEGADA := 3

## Regla de rango del oracle: `Position::areInRange<30, 30, 1>`.
const RANGO_PARTY_XY := 30
const RANGO_PARTY_Z := 1

const SHIELD_MIEMBRO := 3   ## SHIELD_BLUE   (const.h:187-193)
const SHIELD_LIDER := 4     ## SHIELD_YELLOW

const PAUSA_SESION := 6.0
const ESPERA_PASO := 20.0
const ESPERA_MENSAJE := 8.0
const ESPERA_COMBATE := 90.0
## Margen para que expire un eventual signo de batalla (`pzLocked` = 60 s) y
## la solicitud de experiencia compartida deje de descartarse.
const ESPERA_SOLICITUD := 80.0
const LIMITE_TOTAL := 520.0

## Guarda de seguridad continua sobre los participantes.
const VIDA_MINIMA_SEGURA := 40
## Holgura de dano absorbible por encima del piso. Absoluta y no porcentual a
## proposito: el dano entrante no escala con el nivel del participante.
const HOLGURA_DANO_ESPERADO := 110

## `pzLocked` del oracle (`servidor/config.lua:79`), en milisegundos. Es a la
## vez la duracion de `CONDITION_INFIGHT` y el umbral de caducidad de la
## participacion en `ticksMap`.
const PZ_LOCKED_MS := 60000
## Presupuesto de frescura, del lado seguro: se cuenta desde que se le ORDENA
## al MIEMBRO empezar a golpear al primer monstruo hasta que muere el SEGUNDO.
##
## La cota es conservadora por construccion: el tick de participacion del
## miembro no puede ser ANTERIOR a esa orden, asi que la antiguedad real del
## tick en el momento de la medicion es siempre MENOR que lo que se mide aca.
## Si la cota conservadora no entra en el presupuesto, la captura devuelve
## BLOCKED aunque el tick real pudiera estar fresco: se prefiere bloquear a
## reclamar un resultado de rango que no se pueda defender.
##
## 5 s de margen sobre `pzLocked` para latencia de red y tick del servidor.
const VENTANA_FRESCURA := 55.0

## El miembro entra a golpear al primer monstruo recien cuando a este le queda
## este porcentaje de vida o menos.
##
## No es un capricho: el presupuesto de frescura se consume desde que el
## miembro registra participacion, asi que cuanto MAS TARDE participe, mas
## presupuesto queda para la medicion negativa. Entrar al 50% deja al miembro
## una ventana de golpes suficiente para que el reparto del control positivo
## sea real (si no llegara a golpear, el reparto no seria en partes iguales y
## la captura lo detecta y aborta) y a la vez evita gastar el presupuesto en la
## primera mitad del combate, donde el miembro no aporta nada a la prueba.
const UMBRAL_ENTRADA_MIEMBRO := 50

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
var _monstruo_1 := "cave rat"
## `snake` es la mejor eleccion medida contra los datos del propio oracle para
## el SEGUNDO monstruo, y la eleccion importa porque el presupuesto de frescura
## es el recurso escaso de esta captura:
##   - 15 de vida: el minimo entre los monstruos hostiles con experiencia > 0,
##     asi que es el que mas rapido puede matar el lider SOLO;
##   - `runonhealth = 0`: no huye, asi que no hay persecucion que alargue el
##     combate;
##   - y sobre todo, como `Monster::isHostile()` es
##     `baseSkill != 0 && health > runAwayHealth` (`monster.h:115-117`), con
##     `runAwayHealth = 0` sigue siendo HOSTIL hasta el ultimo punto de vida.
##     En una `rat` (huye a 5) o una `cave rat` (huye a 3) los golpes finales
##     dejan de contar como participacion y dejarian de reevaluar; en una
##     `snake` CADA golpe del lider reevalua la elegibilidad.
##   - experiencia 10 > 0, que es lo unico que se le exige: el lider tiene que
##     poder ganar algo.
var _monstruo_2 := "snake"
var _exp_bruta := 0
var _multiplicador := 1.20

var _id_p2_visto_por_p1 := 0
var _id_p1_visto_por_p2 := 0
var _party_solicitada := false
var _preflight_ok := false

## Monstruo 1: lo ven las DOS sesiones porque los dos lo atacan.
var _ids_previos_p1 := {}
var _ids_previos_p2 := {}
var _id_m1 := 0
var _id_m1_p2 := 0
## Monstruo 2: solo lo ve el LIDER. El miembro esta a 61 casillas.
var _ids_previos_m2 := {}
var _id_m2 := 0

var _ultimo_reataque := 0.0
var _ultimo_intento_activar := 0.0
var _exp_p1_antes := -1
var _exp_p2_antes := -1

## Mensajes de experiencia compartida, normalizados a semantica. El texto
## exacto nunca se versiona ni se compara.
var _msg_activada_habilitada := 0
var _msg_activada_inactivos := 0
var _msg_desactivada := 0

## Signo de batalla del miembro LATCHEADO en el instante exacto en que muere el
## segundo monstruo. Se toma ahi y no despues: esperar seria darle tiempo a la
## condicion a expirar y destruir justamente la evidencia que aisla el rango
## del vencimiento de actividad.
var _miembro_en_combate_al_morir := false

## Relojes reales (ms). El presupuesto de frescura no se puede medir con
## acumulacion de deltas de frame.
var _t_m1_lider_ataque := 0
var _t_m1_ataque := 0
var _t_m1_muerto := 0
var _t_m2_primer_golpe := 0
var _t_m2_muerto := 0
var _miembro_unido := false

## Vigilancia continua, latcheada: una sola violacion la deja en false.
var _sesiones_continuas := true
var _party_continua := true
var _piso_continuo := true
var _mensaje_party_rota := false
var _vigilar_party := false
var _vigilar_piso := 0

var _reparto_en_rango := false
var _fuera_de_rango := false
var _obs := {}


func _ready() -> void:
	print("=========================================================")
	print(" TVP3D QA - captura en vivo: rango de experiencia compartida")
	print("=========================================================")
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
	_nombre_p1 = OS.get_environment("TVP772_PLAYER_CHARACTER")
	if _nombre_p1.is_empty():
		return "TVP772_PLAYER_CHARACTER"
	_nombre_p2 = OS.get_environment("TVP772_PLAYER2_CHARACTER")
	if _nombre_p2.is_empty():
		return "TVP772_PLAYER2_CHARACTER"
	_nombre_god = OS.get_environment("TVP772_GOD_CHARACTER")
	if _nombre_god.is_empty():
		return "TVP772_GOD_CHARACTER"

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

	var m1_env := OS.get_environment("TVP772_MONSTER")
	if not m1_env.is_empty():
		_monstruo_1 = m1_env.to_lower()
	var m2_env := OS.get_environment("TVP772_MONSTER2")
	if not m2_env.is_empty():
		_monstruo_2 = m2_env.to_lower()

	# El god puede vivir en otra cuenta. Por defecto, la del lider.
	_cuenta_god = _cuenta
	_clave_god = _clave
	var cuenta_god_env := OS.get_environment("TVP772_GOD_ACCOUNT")
	if not cuenta_god_env.is_empty() and cuenta_god_env.is_valid_int():
		_cuenta_god = int(cuenta_god_env)
	var clave_god_env := OS.get_environment("TVP772_GOD_PASSWORD")
	if not clave_god_env.is_empty():
		_clave_god = clave_god_env

	# El miembro DEBE estar en otra cuenta: una cuenta normal no admite dos
	# sesiones simultaneas.
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
	_vigilar()
	if _terminando:
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
			_esperar_god(POS_A, "reunir p1")
		"reunir p1":
			_reunir(_estado_p1, _nombre_p1, "reunir p2")
		"reunir p2":
			_reunir(_estado_p2, _nombre_p2, "preflight")
		"preflight":
			_preflight()
		"formar party":
			_formar_party()
		"esperar party":
			_esperar_party()
		"lider solicita":
			_lider_solicita()
		"esperar inactivos":
			_esperar_inactivos()
		"invocar 1":
			_invocar_1()
		"esperar monstruo 1":
			_esperar_monstruo_1()
		"combate 1":
			_combate_1()
		"medir control":
			_medir_control()
		"god a b":
			_god_a_b()
		"esperar god b":
			_esperar_god(POS_B, "traer miembro")
		"traer miembro":
			_traer_miembro()
		"esperar miembro b":
			_esperar_miembro_b()
		"god vuelve a a":
			_god_vuelve_a_a()
		"esperar god a":
			_esperar_god(POS_A, "invocar 2")
		"invocar 2":
			_invocar_2()
		"esperar monstruo 2":
			_esperar_monstruo_2()
		"combate 2":
			_combate_2()
		"medir negativo":
			_medir_negativo()
		"devolver miembro":
			_devolver_miembro()
		"confirmar party":
			_confirmar_party()


# -----------------------------------------------------------------
#  Vigilancia continua
# -----------------------------------------------------------------
## Se arma recien cuando el preflight confirmo condiciones. Antes de eso el
## propio preflight evalua la vida, una sola vez y con motivo BLOCKED claro.
func _vigilar() -> void:
	if not _preflight_ok:
		return
	for estado in [_estado_p1, _estado_p2]:
		if estado == null:
			continue
		if not estado.adentro:
			_sesiones_continuas = false
			continue
		var v := int(estado.estadisticas.get("vida", -1))
		if v >= 0 and v < VIDA_MINIMA_SEGURA:
			_fallar("FAIL un participante bajo del minimo seguro de vida; se aborta sin emitir observacion")
			return
	if _vigilar_party:
		# Solo se latchea con una lectura POSITIVAMENTE equivocada. Un escudo
		# todavia desconocido (por ejemplo justo despues de un `0x64` que
		# vacia el mundo visible) no es evidencia de que la party se rompio.
		var e1 := _escudo_propio(_estado_p1)
		var e2 := _escudo_propio(_estado_p2)
		if e1 >= 0 and e1 != SHIELD_LIDER:
			_party_continua = false
		if e2 >= 0 and e2 != SHIELD_MIEMBRO:
			_party_continua = false
	if _vigilar_piso != 0:
		if _estado_p1 != null and _estado_p1.adentro \
				and _estado_p1.mi_pos.z != _vigilar_piso:
			_piso_continuo = false
		if _estado_p2 != null and _estado_p2.adentro \
				and _estado_p2.mi_pos.z != _vigilar_piso:
			_piso_continuo = false


## Escudo de party que la propia sesion se ve a si misma. Es la senal robusta
## de continuidad: el servidor la manda con `Game::updatePlayerShield`
## (`game.cpp:4904-4911`), cuyos espectadores incluyen al propio jugador, y
## tambien viaja en cada AddCreature (`protocolgame.cpp:1258`). No depende de
## que los dos participantes se vean entre si, cosa imposible a 61 casillas.
func _escudo_propio(estado) -> int:
	if estado == null or not estado.adentro:
		return -1
	if not estado.criaturas.has(estado.mi_id):
		return -1
	return int(estado.criaturas[estado.mi_id].get("escudo_party", -1))


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
	if int(_puertos.get(_nombre_p1, 0)) <= 0:
		_fallar("FAIL character configured by TVP772_PLAYER_CHARACTER was not found")
		return
	_con_login.cerrar()
	_con_login.queue_free()
	_con_login = null
	_login_p2()


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


func _al_mensaje(quien: String, texto: String) -> void:
	print("  [%s] %s" % [quien, texto])
	var t := texto.to_lower()
	# Disolucion de party: `Party::leaveParty` (`party.cpp:111,117`) y
	# `Party::disband` (`party.cpp:35`). Cualquiera de las tres invalida la
	# continuidad, y se latchea.
	if t.contains("left the party") or t.contains("has been disbanded"):
		_mensaje_party_rota = true
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
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [POS_A.x, POS_A.y, POS_A.z])
	_pasar_a("esperar god campo")


func _esperar_god(destino: Vector3i, siguiente: String) -> void:
	if _estado_god != null and _cerca(_estado_god.mi_pos, destino):
		_pasar_a(siguiente)
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL el god no llego a una posicion operativa a tiempo")


func _reunir(estado, nombre: String, siguiente: String) -> void:
	if _cerca(estado.mi_pos, POS_A):
		_pasar_a(siguiente)
		return
	if _espera < 0.2:
		return
	if _espera < 0.5:
		_con_god.enviar_hablar("/c %s" % nombre)
	if _espera > ESPERA_PASO:
		_fallar("FAIL /c no acerco a un participante al campo")


## Preflight generico: comprueba, nunca fabrica. Ninguna rama manda comandos
## administrativos. Los motivos son no secretos: hablan de umbrales y
## relaciones, nunca de nombres, cuentas ni valores concretos de nadie.
func _preflight() -> void:
	var listo: bool = not _estado_p1.estadisticas.is_empty() \
		and not _estado_p2.estadisticas.is_empty()
	if not listo:
		if _espera > ESPERA_PASO:
			_fallar("BLOCKED el servidor no publico estadisticas de ambos participantes")
		return

	for estado in [_estado_p1, _estado_p2]:
		if estado == null or not estado.adentro:
			_fallar("BLOCKED un participante no esta conectado")
			return
		var vida := int(estado.estadisticas.get("vida", -1))
		var vida_max := int(estado.estadisticas.get("vida_max", 0))
		if vida <= 0:
			_fallar("BLOCKED un participante no esta vivo")
			return
		if vida < VIDA_MINIMA_SEGURA:
			_fallar("BLOCKED participant health below safe threshold")
			return
		if vida < VIDA_MINIMA_SEGURA + HOLGURA_DANO_ESPERADO:
			_fallar("BLOCKED participant cannot absorb expected combat damage above safe floor")
			return
		if vida_max > 0 and vida_max < VIDA_MINIMA_SEGURA + HOLGURA_DANO_ESPERADO:
			_fallar("BLOCKED participant maximum health too low for controlled combat")
			return

	# Regla de nivel del oracle (`party.cpp:344-354`): el mas bajo debe
	# alcanzar ceil(nivel_mas_alto * 2 / 3). Se comprueba, no se corrige.
	var n1 := int(_estado_p1.estadisticas.get("nivel", 0))
	var n2 := int(_estado_p2.estadisticas.get("nivel", 0))
	if n1 <= 0 or n2 <= 0:
		_fallar("BLOCKED no se pudo leer el nivel de ambos participantes")
		return
	var minimo := int(ceil(float(max(n1, n2)) * 2.0 / 3.0))
	if min(n1, n2) < minimo:
		_fallar("BLOCKED party level eligibility not satisfied")
		return

	# Regla de rango del oracle: al ARRANCAR los dos tienen que estar DENTRO.
	# La medicion positiva de control depende de eso.
	if not _en_rango(_estado_p1.mi_pos, _estado_p2.mi_pos):
		_fallar("BLOCKED participants are not initially inside the shared experience range")
		return

	print("Preflight OK: ambos participantes en condiciones, sin modificar a nadie.")
	_preflight_ok = true
	_vigilar_piso = POS_A.z
	_pasar_a("formar party")


## `Position::areInRange<30, 30, 1>` tal cual: distancias absolutas por eje,
## limite inclusivo, tolerancia de un piso en Z.
func _en_rango(a: Vector3i, b: Vector3i) -> bool:
	return absi(a.x - b.x) <= RANGO_PARTY_XY \
		and absi(a.y - b.y) <= RANGO_PARTY_XY \
		and absi(a.z - b.z) <= RANGO_PARTY_Z


## Se resuelve al companero por su NOMBRE configurado, nunca "la otra criatura
## que haya": el campo puede tener fauna natural. El nombre vive solo en
## memoria de proceso y nunca se serializa.
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
	# `await` no frena `_process`: sin esta guarda la invitacion se reenvia en
	# bucle cada frame.
	if _party_solicitada:
		return
	_party_solicitada = true
	print("Formando party de prueba: el lider invita, el miembro se une.")
	_con_p1.enviar_invitar_a_party(_id_p2_visto_por_p1)
	await get_tree().create_timer(1.5).timeout
	if _terminando:
		return
	_con_p2.enviar_unirse_a_party(_id_p1_visto_por_p2)
	_pasar_a("esperar party")


func _esperar_party() -> void:
	var p1_ve := int(_estado_p1.criaturas.get(_id_p2_visto_por_p1, {}).get("escudo_party", 0))
	var p2_ve := int(_estado_p2.criaturas.get(_id_p1_visto_por_p2, {}).get("escudo_party", 0))
	# Exactamente dos participantes: el god no entra y no se invita a nadie mas.
	if p1_ve == SHIELD_MIEMBRO and p2_ve == SHIELD_LIDER \
			and _escudo_propio(_estado_p1) == SHIELD_LIDER \
			and _escudo_propio(_estado_p2) == SHIELD_MIEMBRO:
		print("Party formada: lider y miembro, sin terceros.")
		_vigilar_party = true
		_pasar_a("lider solicita")
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL la party de prueba no quedo formada a tiempo")


# -----------------------------------------------------------------
#  Solicitud (montaje del harness, no asercion propia)
# -----------------------------------------------------------------
func _lider_solicita() -> void:
	_ultimo_intento_activar = 0.0
	_pasar_a("esperar inactivos")


## `Game::playerEnableSharedPartyExperience` (`game.cpp:5089-5102`) DESCARTA la
## orden en silencio si el solicitante tiene `CONDITION_INFIGHT` fuera de zona
## protegida: ni mensaje ni cambio de estado. Es una regla real del oracle, ya
## certificada por `PARITY-PARTY-SHARED-EXP-001`, no un defecto del adaptador.
##
## Aca solo es montaje del harness, asi que en vez de fallar de entrada la
## orden se reintenta hasta que el signo de batalla expire. Repetir es inocuo:
## si ya quedo solicitada, `setSharedExperience` vuelve temprano
## (`party.cpp:305-307`) sin mensaje ni transicion.
func _esperar_inactivos() -> void:
	if _msg_activada_inactivos > 0:
		print("Confirmado: solicitud aceptada, todavia NO habilitada por participantes inactivos.")
		_pasar_a("invocar 1")
		return
	if _msg_activada_habilitada > 0:
		_fallar("FAIL quedo habilitada sin participacion reciente; el montaje no es el esperado")
		return
	if _ultimo_intento_activar == 0.0 or _espera - _ultimo_intento_activar >= ESPERA_MENSAJE:
		_ultimo_intento_activar = _espera
		print("El LIDER solicita activar la experiencia compartida (%ds, aun sin participacion reciente)."
			% int(_espera))
		_con_p1.enviar_experiencia_compartida(true)
	if _espera > ESPERA_SOLICITUD:
		_fallar("FAIL el servidor no confirmo la solicitud del lider ni despues de que pudiera expirar el signo de batalla")


# -----------------------------------------------------------------
#  FASE 3 - Control positivo en rango
# -----------------------------------------------------------------
func _invocar_1() -> void:
	_exp_p1_antes = int(_estado_p1.estadisticas.get("experiencia", -1))
	_exp_p2_antes = int(_estado_p2.estadisticas.get("experiencia", -1))
	if _exp_p1_antes < 0 or _exp_p2_antes < 0:
		if _espera > ESPERA_PASO:
			_fallar("FAIL no se pudo leer la experiencia autoritativa de ambos participantes")
		return
	# Sin limpieza amplia y sin matar fauna preexistente: se anotan los ids
	# conocidos ANTES de invocar y despues se exige exactamente un id NUEVO por
	# sesion. Nunca se usa `/killall`.
	_ids_previos_p1 = _ids_actuales(_estado_p1)
	_ids_previos_p2 = _ids_actuales(_estado_p2)
	print("Invocando el PRIMER monstruo de prueba (control positivo).")
	_con_god.enviar_hablar("/m %s" % _monstruo_1)
	_pasar_a("esperar monstruo 1")


func _ids_actuales(estado) -> Dictionary:
	var ids := {}
	for id in estado.criaturas:
		ids[int(id)] = true
	return ids


## Ids del tipo buscado que NO estaban antes de invocar. Se exige exactamente
## uno: cero significa que todavia no llego, y mas de uno significa identidad
## ambigua (fauna que entro en la misma ventana), caso en el que no se mide.
func _monstruos_nuevos(estado, previos: Dictionary, especie: String) -> Array:
	var nuevos: Array = []
	for id in estado.criaturas:
		if previos.has(int(id)):
			continue
		var criatura: Dictionary = estado.criaturas[id]
		if int(criatura.get("vida", 100)) <= 0:
			continue
		if str(criatura.get("nombre", "")).to_lower() == especie:
			nuevos.append(int(id))
	return nuevos


func _esperar_monstruo_1() -> void:
	var nuevos_p1 := _monstruos_nuevos(_estado_p1, _ids_previos_p1, _monstruo_1)
	var nuevos_p2 := _monstruos_nuevos(_estado_p2, _ids_previos_p2, _monstruo_1)
	if nuevos_p1.size() > 1 or nuevos_p2.size() > 1:
		_fallar("BLOCKED aparecio mas de un monstruo nuevo de la especie de control; identidad ambigua")
		return
	if nuevos_p1.is_empty() or nuevos_p2.is_empty():
		if _espera > ESPERA_PASO:
			_fallar("FAIL el primer monstruo de prueba no aparecio para ambos participantes")
		return
	_id_m1 = int(nuevos_p1[0])
	_id_m1_p2 = int(nuevos_p2[0])
	print("Primer monstruo visible; ABRE el lider solo. El miembro entra al %d%% de vida."
		% UMBRAL_ENTRADA_MIEMBRO)
	_t_m1_lider_ataque = Time.get_ticks_msec()
	_atacar_m1(false)
	_pasar_a("combate 1")


## El miembro solo golpea despues de unirse. Antes de eso la orden es unica
## para el lider, asi que el miembro no registra participacion todavia y no
## empieza a consumir el presupuesto de frescura.
func _atacar_m1(con_miembro: bool) -> void:
	_con_p1.enviar_modos_combate(1, 1, 0)
	_con_p1.enviar_atacar(_id_m1)
	if con_miembro:
		_con_p2.enviar_modos_combate(1, 1, 0)
		_con_p2.enviar_atacar(_id_m1_p2)


func _combate_1() -> void:
	var vivo: bool = _estado_p1.criaturas.has(_id_m1) \
		and int(_estado_p1.criaturas[_id_m1].get("vida", 0)) > 0
	if vivo:
		var vida_pct := int(_estado_p1.criaturas[_id_m1].get("vida", 100))
		if not _miembro_unido and vida_pct <= UMBRAL_ENTRADA_MIEMBRO:
			# Desde ESTE instante corre el presupuesto de frescura: el tick de
			# participacion del miembro no puede ser anterior a esta orden.
			_miembro_unido = true
			_t_m1_ataque = Time.get_ticks_msec()
			print("  el MIEMBRO entra al combate (vida del objetivo %d%%); arranca el presupuesto de frescura."
				% vida_pct)
			_atacar_m1(true)
			return
		# El servidor puede cancelar el objetivo; se reenvia la orden y se
		# informa la vida vista para que un fallo por falta de dano sea
		# distinguible de un fallo por objetivo perdido.
		if _espera - _ultimo_reataque >= 5.0:
			_ultimo_reataque = _espera
			print("  combate 1 a los %ds: vida del objetivo vista por el lider = %d%% (miembro dentro=%s)"
				% [int(_espera), vida_pct, str(_miembro_unido)])
			_atacar_m1(_miembro_unido)
		if _espera > ESPERA_COMBATE:
			_fallar("BLOCKED el primer monstruo no murio dentro de la ventana de combate; capacidad de combate insuficiente para esta corrida")
		return
	if not _miembro_unido:
		_fallar("BLOCKED el primer monstruo murio antes de que el miembro llegara a participar; sin participacion del miembro no hay control positivo")
		return
	_t_m1_muerto = Time.get_ticks_msec()
	print("Primer monstruo muerto: %.1fs de combate total, %.1fs con el miembro adentro."
		% [(_t_m1_muerto - _t_m1_lider_ataque) / 1000.0,
			(_t_m1_muerto - _t_m1_ataque) / 1000.0])
	_pasar_a("medir control")


func _medir_control() -> void:
	if _espera < 2.0:
		return
	var g1 := int(_estado_p1.estadisticas.get("experiencia", -1)) - _exp_p1_antes
	var g2 := int(_estado_p2.estadisticas.get("experiencia", -1)) - _exp_p2_antes
	var esperado := int(ceil(float(_exp_bruta) * _multiplicador / 2.0))
	print("Control positivo (relaciones, no totales): ambos ganan=%s, iguales=%s, coinciden con la formula=%s"
		% [str(g1 > 0 and g2 > 0), str(g1 == g2), str(g1 == esperado and g2 == esperado)])
	if g1 <= 0 or g2 <= 0:
		_fallar("FAIL el control positivo no repartio a ambos participantes; sin control valido no se mide el rango")
		return
	# `enabled` no viaja por la red. Se deriva POR COMPORTAMIENTO: sin
	# habilitar, cada atacante cobra su parte proporcional al dano
	# (`creature.cpp:375`) y las ganancias serian distintas; solo con el
	# reparto habilitado se juntan en un pozo y se pagan iguales
	# (`creature.cpp:391-402, 411-413` + `party.cpp:327-336`).
	_reparto_en_rango = g1 > 0 and g2 > 0 and g1 == g2 and g1 == esperado
	if not _reparto_en_rango:
		_fallar("FAIL el reparto en rango no coincidio con la formula vigente; el control positivo no quedo establecido")
		return
	# Este control prueba tres cosas a la vez: el reparto quedo habilitado, el
	# miembro tenia participacion fresca registrada en `ticksMap`, y la
	# composicion de prueba es valida.
	print("Control positivo establecido: el reparto en rango ocurrio.")
	_pasar_a("god a b")


# -----------------------------------------------------------------
#  FASE 4 - Separacion fuera de rango
# -----------------------------------------------------------------
## El lider NO se mueve. El god va al punto lejano, se trae al miembro con el
## mismo mecanismo de reubicacion del lado del servidor que ya usa el harness
## (`/c`, `teleport_creature_here.lua`), y vuelve. Sin logout y sin cambio de
## piso.
func _god_a_b() -> void:
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [POS_B.x, POS_B.y, POS_B.z])
	_pasar_a("esperar god b")


func _traer_miembro() -> void:
	_con_god.enviar_hablar("/c %s" % _nombre_p2)
	_pasar_a("esperar miembro b")


func _esperar_miembro_b() -> void:
	if not _cerca(_estado_p2.mi_pos, POS_B):
		if _espera > ESPERA_PASO:
			_fallar("FAIL el miembro no llego al punto lejano a tiempo")
		return
	if not _cerca(_estado_p1.mi_pos, POS_A):
		_fallar("FAIL el lider no se mantuvo en el punto de medicion")
		return
	# La separacion se afirma contra la GEOMETRIA REAL observada, no contra la
	# constante de destino.
	if _en_rango(_estado_p1.mi_pos, _estado_p2.mi_pos):
		_fallar("BLOCKED la separacion observada sigue dentro del rango permitido; no hay caso negativo")
		return
	if _estado_p1.mi_pos.z != _estado_p2.mi_pos.z:
		_fallar("FAIL el piso cambio durante la separacion; el resultado no seria atribuible al rango")
		return
	_fuera_de_rango = true
	print("Miembro fuera del rango permitido, mismo piso, misma sesion.")
	_pasar_a("god vuelve a a")


func _god_vuelve_a_a() -> void:
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [POS_A.x, POS_A.y, POS_A.z])
	_pasar_a("esperar god a")


# -----------------------------------------------------------------
#  FASES 5 y 6 - Reevaluacion forzada y reparto negativo
# -----------------------------------------------------------------
func _invocar_2() -> void:
	# Solo el LIDER puede ver este monstruo: el miembro esta a mas de 60
	# casillas, muy fuera de la ventana de espectadores del servidor.
	_ids_previos_m2 = _ids_actuales(_estado_p1)
	print("Invocando el SEGUNDO monstruo de prueba (medicion negativa).")
	_con_god.enviar_hablar("/m %s" % _monstruo_2)
	_pasar_a("esperar monstruo 2")


func _esperar_monstruo_2() -> void:
	var nuevos := _monstruos_nuevos(_estado_p1, _ids_previos_m2, _monstruo_2)
	if nuevos.size() > 1:
		_fallar("BLOCKED aparecio mas de un monstruo nuevo de la segunda especie; identidad ambigua")
		return
	if nuevos.is_empty():
		if _espera > ESPERA_PASO:
			_fallar("FAIL el segundo monstruo de prueba no aparecio para el lider")
		return
	_id_m2 = int(nuevos[0])
	# El miembro no debe verlo. Si lo viera, la separacion no seria real.
	if _estado_p2.criaturas.has(_id_m2):
		_fallar("BLOCKED el miembro distante ve el segundo monstruo; la separacion no es efectiva")
		return
	print("Segundo monstruo visible SOLO para el lider; solo el lider lo ataca.")
	_exp_p1_antes = int(_estado_p1.estadisticas.get("experiencia", -1))
	_exp_p2_antes = int(_estado_p2.estadisticas.get("experiencia", -1))
	_ultimo_reataque = 0.0
	# Instante de la PRIMERA orden de ataque del lider sobre el segundo
	# monstruo. El primer golpe que conecte a partir de aca es el que dispara
	# la primera reevaluacion con el miembro ya fuera de rango, o sea el
	# momento en que `sharedExpEnabled` deberia pasar a false.
	_t_m2_primer_golpe = Time.get_ticks_msec()
	_atacar_solo_lider()
	_pasar_a("combate 2")


func _atacar_solo_lider() -> void:
	_con_p1.enviar_modos_combate(1, 1, 0)
	_con_p1.enviar_atacar(_id_m2)


func _combate_2() -> void:
	# El presupuesto de frescura manda sobre la ventana de combate.
	var desde_primer_golpe := (Time.get_ticks_msec() - _t_m1_ataque) / 1000.0
	if desde_primer_golpe > VENTANA_FRESCURA:
		_fallar("BLOCKED freshness budget exceeded before the negative measurement completed; el 0 del miembro no seria atribuible al rango")
		return
	var vivo: bool = _estado_p1.criaturas.has(_id_m2) \
		and int(_estado_p1.criaturas[_id_m2].get("vida", 0)) > 0
	if vivo:
		if _espera - _ultimo_reataque >= 4.0:
			_ultimo_reataque = _espera
			print("  combate 2 a los %ds (presupuesto %.1fs de %.1fs): vida = %d%%, miembro en combate = %s"
				% [int(_espera), desde_primer_golpe, VENTANA_FRESCURA,
					int(_estado_p1.criaturas[_id_m2].get("vida", -1)),
					str(_estado_p2.en_combate)])
			_atacar_solo_lider()
		return
	_t_m2_muerto = Time.get_ticks_msec()
	# Se latchea AQUI, en el mismo frame en que se observa la muerte del
	# objetivo: es el instante en que el servidor resolvio el reparto.
	_miembro_en_combate_al_morir = _estado_p2.en_combate
	print("Segundo monstruo muerto; midiendo el reparto negativo.")
	_pasar_a("medir negativo")


func _medir_negativo() -> void:
	# Se le da margen al `0xA0` de experiencia del lider antes de comparar.
	if _espera < 2.0:
		return
	var g1 := int(_estado_p1.estadisticas.get("experiencia", -1)) - _exp_p1_antes
	var g2 := int(_estado_p2.estadisticas.get("experiencia", -1)) - _exp_p2_antes
	var ventana := (_t_m2_muerto - _t_m1_ataque) / 1000.0
	print("Medicion negativa (relaciones, no totales): el lider gano=%s, el miembro distante gano=%s"
		% [str(g1 > 0), str(g2 > 0)])
	# Diagnostico operativo desglosado: si esta corrida se bloqueara por
	# presupuesto, estos numeros dicen exactamente donde se fue el tiempo.
	# Ninguno entra a la observacion normalizada.
	print("Desglose del presupuesto (cota conservadora, solo diagnostico):")
	print("  miembro adentro del combate 1 : %.1fs"
		% ((_t_m1_muerto - _t_m1_ataque) / 1000.0))
	print("  separacion e invocacion       : %.1fs"
		% ((_t_m2_primer_golpe - _t_m1_muerto) / 1000.0))
	print("  combate 2 (lider solo)        : %.1fs"
		% ((_t_m2_muerto - _t_m2_primer_golpe) / 1000.0))
	print("  primera reevaluacion fuera de rango a los %.1fs de la cota"
		% ((_t_m2_primer_golpe - _t_m1_ataque) / 1000.0))
	print("Ventana de frescura consumida: %.1fs de %.1fs (pzLocked = %dms); miembro con signo de batalla al morir el objetivo = %s"
		% [ventana, VENTANA_FRESCURA, PZ_LOCKED_MS, str(_miembro_en_combate_al_morir)])

	# --- Desambiguacion: el 0 del miembro tiene que ser por RANGO ---
	if not _miembro_en_combate_al_morir:
		_fallar("BLOCKED el miembro perdio su signo de batalla; el servidor pudo haberle limpiado los puntos de participacion y el 0 no seria atribuible al rango")
		return
	if ventana > VENTANA_FRESCURA:
		_fallar("BLOCKED freshness budget exceeded; el 0 del miembro no seria atribuible al rango")
		return
	if not _sesiones_continuas or not _estado_p1.adentro or not _estado_p2.adentro:
		_fallar("BLOCKED una sesion se desconecto durante la medicion")
		return
	if _mensaje_party_rota or not _party_continua:
		_fallar("BLOCKED la party no se mantuvo formada durante la medicion")
		return
	if not _piso_continuo or _estado_p1.mi_pos.z != _estado_p2.mi_pos.z:
		_fallar("BLOCKED el piso cambio durante la medicion")
		return
	if _en_rango(_estado_p1.mi_pos, _estado_p2.mi_pos):
		_fallar("BLOCKED el miembro volvio a entrar en rango antes de terminar la medicion")
		return
	if g1 <= 0:
		_fallar("FAIL el lider no gano experiencia del segundo monstruo; la medicion no discrimina")
		return
	if g2 != 0:
		_fallar("FAIL el miembro distante gano experiencia estando fuera de rango")
		return

	_obs = {
		"positive_control": {
			"in_range_shared_distribution_observed": _reparto_en_rango,
		},
		"range_transition": {
			"member_outside_allowed_range": _fuera_de_rango
				and not _en_rango(_estado_p1.mi_pos, _estado_p2.mi_pos),
			"same_floor_preserved": _piso_continuo
				and _estado_p1.mi_pos.z == _estado_p2.mi_pos.z,
			"party_remained_formed": _party_continua and not _mensaje_party_rota
				and _escudo_propio(_estado_p1) == SHIELD_LIDER
				and _escudo_propio(_estado_p2) == SHIELD_MIEMBRO,
			"both_sessions_remained_connected": _sesiones_continuas
				and _estado_p1.adentro and _estado_p2.adentro,
		},
		"out_of_range_distribution": {
			"leader_gained_experience": g1 > 0,
			"distant_member_gained_experience": g2 > 0,
			# El reparto quedo suprimido, no repartido-excluyendo-al-miembro:
			# hubo un control positivo con reparto real en la MISMA corrida, y
			# despues, con el unico cambio de la separacion espacial, el
			# miembro no cobro nada mientras el lider si.
			"shared_distribution_suppressed": _reparto_en_rango and g1 > 0 and g2 == 0,
		},
	}
	_pasar_a("devolver miembro")


# -----------------------------------------------------------------
#  Limpieza y confirmacion final de continuidad
# -----------------------------------------------------------------
## Se trae al miembro de vuelta al punto operativo. Ademas de dejar el entorno
## como estaba, permite confirmar la relacion lider/miembro con los dos
## viendose otra vez, no solo por el escudo propio de cada sesion.
func _devolver_miembro() -> void:
	_con_god.enviar_hablar("/c %s" % _nombre_p2)
	_pasar_a("confirmar party")


func _confirmar_party() -> void:
	var p1_ve := int(_estado_p1.criaturas.get(_id_p2_visto_por_p1, {}).get("escudo_party", -1))
	var p2_ve := int(_estado_p2.criaturas.get(_id_p1_visto_por_p2, {}).get("escudo_party", -1))
	if p1_ve == SHIELD_MIEMBRO and p2_ve == SHIELD_LIDER:
		print("Confirmado tras la medicion: la party seguia formada, lider y miembro.")
		_emitir_observacion()
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED no se pudo reconfirmar la relacion de party tras la medicion")


func _emitir_observacion() -> void:
	## Ningun nombre, nivel, vocacion, id de runtime, coordenada, vida, total de
	## experiencia, marca de tiempo ni metadata de host. Solo relaciones.
	print("OBSERVATION_JSON: " + JSON.stringify(_obs))
	print("Captura de rango de experiencia compartida: OK")
	_limpiar()
	_terminar(0)


func _limpiar() -> void:
	## Los monstruos de prueba ya murieron como parte del recorrido. Se deshace
	## SOLO la party creada por esta prueba y se devuelve a los participantes a
	## su templo. Nunca `/killall`.
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
