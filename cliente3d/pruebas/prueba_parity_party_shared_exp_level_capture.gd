extends Node

# Captura QA-owned en vivo: REGLA DE NIVEL de la experiencia compartida
# (Phase 2D.2). Fixture `PARITY-PARTY-SHARED-EXP-LEVEL-001`.
#
# Adaptador SEPARADO de los de `PARITY-PARTY-SHARED-EXP-001` y
# `PARITY-PARTY-SHARED-EXP-RANGE-001`, ya certificados en vivo: esos archivos
# NO se tocan ni se extienden.
#
# Esta rama NO decide PASS/FAIL: lo hace `qa/parity/tools/replay.py` contra la
# `ParityExpectationV1` publicada. Este script solo observa y serializa.
#
# ---------------------------------------------------------------------------
# REGLA QUE SE PRUEBA, VERIFICADA EN EL CODIGO VIGENTE DEL ORACLE
# ---------------------------------------------------------------------------
#
# `Party::canUseSharedExperience` (`servidor/src/party.cpp:338-372`):
#
#     uint32_t highestLevel = leader->getLevel();
#     for (Player* member : memberList) {
#         if (member->getLevel() > highestLevel) {
#             highestLevel = member->getLevel();
#         }
#     }
#
#     uint32_t minLevel = static_cast<uint32_t>(
#         std::ceil((static_cast<float>(highestLevel) * 2) / 3));
#     if (player->getLevel() < minLevel) {
#         return false;
#     }
#
# Puntos exactos de la semantica, leidos del codigo y no supuestos:
#   - `highestLevel` es el MAXIMO entre el lider y TODOS los miembros;
#   - la division es en punto flotante y despues `ceil`, NO division entera:
#     con nivel mas alto 25 el minimo es 17 (`ceil(16.666...)`), no 16;
#   - la comparacion es ESTRICTA (`<`), asi que un participante exactamente en
#     `minLevel` SI es elegible;
#   - `canEnableSharedExperience` (`party.cpp:333-346`) exige que la funcion
#     devuelva true para el lider Y para cada miembro, asi que basta con que UN
#     participante quede por debajo para que el reparto no se habilite.
#
# ---------------------------------------------------------------------------
# POR QUE HACE FALTA FORZAR UNA REEVALUACION
# ---------------------------------------------------------------------------
#
# `Party::updateSharedExperience()` tiene exactamente cinco llamadores en todo
# el servidor (`party.cpp` 113, 146, 197, 392, 401) y ninguno cuelga del
# movimiento. La reevaluacion se fuerza con dano autoritativo del participante
# de NIVEL ALTO a un segundo monstruo hostil:
#
#     Player::onAttackedCreatureDrainHealth (player.cpp:3218-3231)
#       -> party->updatePlayerTicks(this, points)      [points != 0]
#       -> Party::updateSharedExperience()             (party.cpp:392)
#       -> Party::canEnableSharedExperience()          (party.cpp:333)
#       -> Party::canUseSharedExperience(cada participante)
#       -> falla el chequeo de NIVEL para el participante bajo
#
# El monstruo TIENE que ser hostil: `player.cpp:3225` exige
# `tmpMonster->isHostile()`, y en este fork `Monster::isHostile()`
# (`servidor/src/monster.h:115-117`) es
# `baseSkill != 0 && health > runAwayHealth`.
#
# Con el reparto deshabilitado, `Creature::death` (`creature.cpp:368-413`) no
# junta la parte del atacante en el pozo de la party: la paga individualmente
# y COMPLETA al unico atacante (`creature.cpp:405-407`).
#
# ---------------------------------------------------------------------------
# AISLAMIENTO: EL 0 DEL PARTICIPANTE BAJO TIENE QUE SER POR NIVEL
# ---------------------------------------------------------------------------
#
# `canUseSharedExperience` es una conjuncion de cuatro requisitos. Para que el
# resultado sea atribuible al de NIVEL, los otros tres se mantienen satisfechos
# y se verifican en runtime:
#
# 1. Party no vacia            -> escudos propios vigilados de forma continua,
#                                 ausencia de mensajes de disolucion y
#                                 reconfirmacion mutua al final.
# 2. Rango espacial            -> los dos participantes se quedan en el MISMO
#                                 punto operativo toda la corrida; `areInRange`
#                                 se recalcula sobre las posiciones realmente
#                                 reportadas y se vigila de forma continua.
# 3. Participacion en ticksMap -> los DOS danan al primer monstruo y se exige
#                                 que los DOS cobren experiencia individual por
#                                 el, que es la prueba autoritativa de que
#                                 entraron al `damageMap` con dano positivo y,
#                                 por el mismo evento, a `ticksMap`
#                                 (`player.cpp:3227`).
# 4. Frescura de esa           -> el fin de `CONDITION_INFIGHT` es lo unico que
#    participacion                dispara `Party::clearPlayerPoints`
#                                 (`player.cpp:3201-3208`), y esa condicion es
#                                 la que enciende `ICON_SWORDS`, que el cliente
#                                 expone como `estado.en_combate`. Se latchea en
#                                 el instante exacto de la muerte del segundo
#                                 objetivo. Ademas la entrada caduca si
#                                 `OTSYS_TIME() - tick > PZ_LOCKED`
#                                 (`party.cpp:366-369`, `pzLocked = 60000`), asi
#                                 que se acota con un presupuesto de tiempo
#                                 conservador; si no entra, BLOCKED.
#
# ---------------------------------------------------------------------------
# LA CORROBORACION FUERTE: LA MAGNITUD DEL PAGO DEL PARTICIPANTE ALTO
# ---------------------------------------------------------------------------
#
# "El participante bajo cobro 0" por si solo es evidencia debil. La evidencia
# fuerte es cuanto cobro el ALTO por el segundo monstruo:
#
#   - con el reparto SUPRIMIDO, el unico atacante cobra el pago individual
#     COMPLETO (`cb.total * experience / totalCombatDamageReceived`, que con un
#     unico atacante es la experiencia base entera);
#   - si el reparto estuviera habilitado y simplemente excluyera al bajo, el
#     alto cobraria `ceil(exp * 1.20 / 2)` (`party.lua:24-47`), es decir una
#     FRACCION.
#
# Los dos numeros son distintos y se comparan en tiempo de captura contra los
# datos del propio oracle. Ninguno se congela en el fixture.
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
# La diferencia de nivel entre los dos participantes es una PRECONDICION DE
# ENTORNO que se comprueba, nunca algo que esta captura fabrique. Si la relacion
# no se cumple, devuelve BLOCKED y no toca a nadie.
#
# ---------------------------------------------------------------------------
# CREDENCIALES: SOLO POR ENTORNO, NUNCA LITERALES, NUNCA IMPRESAS
# ---------------------------------------------------------------------------
#   TVP772_ACCOUNT            cuenta de QA_LEVEL_HIGH (lider de la party)
#   TVP772_PASSWORD
#   TVP772_PLAYER_CHARACTER   QA_LEVEL_HIGH
#   TVP772_PLAYER2_ACCOUNT    cuenta de QA_LEVEL_LOW (tiene que ser otra cuenta)
#   TVP772_PLAYER2_PASSWORD
#   TVP772_PLAYER2_CHARACTER  QA_LEVEL_LOW
#   TVP772_GOD_ACCOUNT        QA_GOD_OPERATOR; no entra a la party
#   TVP772_GOD_PASSWORD
#   TVP772_GOD_CHARACTER
#   TVP772_MONSTER_BASE_EXP   experiencia base del PRIMER monstruo de prueba
# Opcionales:
#   TVP772_HOST, TVP772_LOGIN_PORT
#   TVP772_MONSTER             especie del primer monstruo  (def. "snake")
#   TVP772_MONSTER2            especie del segundo monstruo (def. "snake")
#   TVP772_MONSTER2_BASE_EXP   experiencia base del segundo (def. la del primero)
#
# El servidor rechaza dos sesiones simultaneas de la MISMA cuenta para
# personajes normales, asi que los dos participantes necesitan cuentas
# distintas. El god esquiva esa restriccion por su bandera `canalwayslogin`.
#
# El god NO entra a la party y NUNCA golpea a ningun monstruo: su grupo tiene
# `notgainexperience`, y ademas su parte proporcional del dano cambiaria el
# pago individual del participante alto (`creature.cpp:375`), que es justamente
# la corroboracion fuerte de este fixture.
#
#   ...Godot --headless --path cliente3d \
#       pruebas/prueba_parity_party_shared_exp_level_capture.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST_DEFECTO := "127.0.0.1"
const PUERTO_LOGIN_DEFECTO := 7171

## Casilla ya calificada en Phase 2C.1/2C.2 y reusada por Phase 2D y 2D.1:
## colocable y operacionalmente aislada. Los DOS participantes se quedan aca
## toda la corrida, porque este fixture aisla el NIVEL y no debe rozar el
## limite espacial. Es detalle de implementacion: NUNCA entra al payload.
const POS_A := Vector3i(32008, 32400, 7)
const RADIO_LLEGADA := 3

## Regla de rango del oracle: `Position::areInRange<30, 30, 1>`. Aca se usa solo
## como CONTROL (tiene que cumplirse siempre), no como cosa a probar.
const RANGO_PARTY_XY := 30
const RANGO_PARTY_Z := 1

const SHIELD_MIEMBRO := 3   ## SHIELD_BLUE   (const.h:187-193)
const SHIELD_LIDER := 4     ## SHIELD_YELLOW

const PAUSA_SESION := 6.0
const ESPERA_PASO := 20.0
const ESPERA_MENSAJE := 8.0
const ESPERA_COMBATE := 90.0
## Margen para que expire un eventual signo de batalla (`pzLocked` = 60 s) y la
## solicitud de experiencia compartida deje de descartarse en silencio
## (`game.cpp:5089-5102`).
const ESPERA_SOLICITUD := 80.0
const LIMITE_TOTAL := 520.0

## Guarda de seguridad continua sobre los participantes. Importa mas que en los
## fixtures anteriores porque el participante de nivel bajo es de nivel 1.
const VIDA_MINIMA_SEGURA := 40
## Holgura de dano absorbible por encima del piso. Absoluta y no porcentual a
## proposito: el dano entrante no escala con el nivel del participante. Se
## conserva EXACTAMENTE el valor ya probado por el adaptador de rango; no se
## afloja para acomodar a un participante de nivel 1.
const HOLGURA_DANO_ESPERADO := 110

## `pzLocked` del oracle (`servidor/config.lua:79`), en milisegundos. Es a la
## vez la duracion de `CONDITION_INFIGHT` y el umbral de caducidad de la
## participacion en `ticksMap`.
const PZ_LOCKED_MS := 60000
## Presupuesto de frescura, del lado seguro: se cuenta desde que se le ORDENA a
## los participantes empezar a golpear al PRIMER monstruo hasta que muere el
## SEGUNDO. El tick real de participacion no puede ser ANTERIOR a esa orden, asi
## que la antiguedad real en el momento de la medicion es siempre MENOR que lo
## que se mide aca. Si la cota conservadora no entra, la captura devuelve
## BLOCKED aunque el tick real pudiera estar fresco.
const VENTANA_FRESCURA := 55.0

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

## `snake` es la mejor eleccion medida contra los datos del propio oracle para
## los DOS monstruos de prueba, y la eleccion importa por dos motivos:
##   - SEGURIDAD del participante de nivel bajo: con 15 de vida, ataque 5,
##     habilidad 11, armadura 0 y defensa 1 es el monstruo hostil con
##     experiencia > 0 mas debil y mas facil de danar de todo el bestiario del
##     oracle, asi que un personaje de nivel 1 puede aportar dano real sin tener
##     que aguantar un combate largo;
##   - FRESCURA: con `runonhealth = 0` no huye y, como `Monster::isHostile()` es
##     `baseSkill != 0 && health > runAwayHealth` (`monster.h:115-117`), sigue
##     siendo HOSTIL hasta el ultimo punto de vida, asi que CADA golpe cuenta
##     como participacion y reevalua la elegibilidad, incluido el ultimo.
## Experiencia base 10 > 0, que es lo unico que se le exige.
var _monstruo_1 := "snake"
var _monstruo_2 := "snake"
var _exp_bruta_1 := 0
var _exp_bruta_2 := 0
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
## Monstruo 2: lo ven las dos sesiones (siguen juntas), pero SOLO lo ataca el
## participante de nivel alto.
var _ids_previos_m2 := {}
var _id_m2 := 0

var _ultimo_reataque := 0.0
var _ultimo_intento_activar := 0.0
var _exp_p1_antes := -1
var _exp_p2_antes := -1

## Mensajes de experiencia compartida, normalizados a semantica. El texto exacto
## nunca se versiona ni se compara.
var _msg_activada_habilitada := 0
var _msg_activada_inactivos := 0
var _msg_desactivada := 0

## Relacion de nivel leida del estado autoritativo ANTES de tocar la party.
var _nivel_alto := 0
var _nivel_bajo := 0
var _nivel_minimo := 0
var _bajo_por_debajo := false

## Participacion probada del primer monstruo.
var _alto_participo := false
var _bajo_participo := false

## Signo de batalla del participante bajo LATCHEADO en el instante exacto en que
## muere el segundo monstruo. Se toma ahi y no despues: esperar seria darle
## tiempo a la condicion a expirar y destruir justamente la evidencia que aisla
## el nivel del vencimiento de actividad.
var _bajo_en_combate_al_morir := false

## Relojes reales (ms). El presupuesto de frescura no se puede medir con
## acumulacion de deltas de frame.
var _t_m1_ataque := 0
var _t_m1_muerto := 0
var _t_m2_primer_golpe := 0
var _t_m2_muerto := 0

## Vigilancia continua, latcheada: una sola violacion la deja en false.
var _sesiones_continuas := true
var _party_continua := true
var _piso_continuo := true
var _rango_continuo := true
var _mensaje_party_rota := false
var _vigilar_party := false
var _vigilar_piso := 0

var _pago_individual_completo := false
var _obs := {}


func _ready() -> void:
	print("=========================================================")
	print(" TVP3D QA - captura en vivo: nivel de experiencia compartida")
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
		_exp_bruta_1 = int(exp_env)
	if _exp_bruta_1 <= 0:
		return "TVP772_MONSTER_BASE_EXP"
	_exp_bruta_2 = _exp_bruta_1
	var exp2_env := OS.get_environment("TVP772_MONSTER2_BASE_EXP")
	if not exp2_env.is_empty() and exp2_env.is_valid_int():
		_exp_bruta_2 = int(exp2_env)
	if _exp_bruta_2 <= 0:
		return "TVP772_MONSTER2_BASE_EXP"

	var m1_env := OS.get_environment("TVP772_MONSTER")
	if not m1_env.is_empty():
		_monstruo_1 = m1_env.to_lower()
	var m2_env := OS.get_environment("TVP772_MONSTER2")
	if not m2_env.is_empty():
		_monstruo_2 = m2_env.to_lower()

	# El god puede vivir en otra cuenta. Por defecto, la del participante alto.
	_cuenta_god = _cuenta
	_clave_god = _clave
	var cuenta_god_env := OS.get_environment("TVP772_GOD_ACCOUNT")
	if not cuenta_god_env.is_empty() and cuenta_god_env.is_valid_int():
		_cuenta_god = int(cuenta_god_env)
	var clave_god_env := OS.get_environment("TVP772_GOD_PASSWORD")
	if not clave_god_env.is_empty():
		_clave_god = clave_god_env

	# El participante bajo DEBE estar en otra cuenta: una cuenta normal no
	# admite dos sesiones simultaneas.
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
		"medir participacion":
			_medir_participacion()
		"invocar 2":
			_invocar_2()
		"esperar monstruo 2":
			_esperar_monstruo_2()
		"combate 2":
			_combate_2()
		"medir negativo":
			_medir_negativo()
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
		# todavia desconocido (por ejemplo justo despues de un `0x64` que vacia
		# el mundo visible) no es evidencia de que la party se rompio.
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
		# El rango es CONTROL en este fixture: tiene que cumplirse siempre.
		if _estado_p1 != null and _estado_p2 != null \
				and _estado_p1.adentro and _estado_p2.adentro \
				and not _en_rango(_estado_p1.mi_pos, _estado_p2.mi_pos):
			_rango_continuo = false


## Escudo de party que la propia sesion se ve a si misma. El servidor lo manda
## con `Game::updatePlayerShield` (`game.cpp:4904-4911`), cuyos espectadores
## incluyen al propio jugador, y tambien viaja en cada AddCreature
## (`protocolgame.cpp:1258`).
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
	login.error_red.connect(func(t): _fallar("FAIL fallo de red en login del participante bajo: %s" % t))
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
	_estado_p1.rechazados.connect(func(m): _fallar("FAIL el participante alto fue rechazado: %s" % m))
	_estado_p1.mensaje_servidor.connect(func(t): _al_mensaje("HIGH", t))
	_con_p1 = CONEXION.new()
	add_child(_con_p1)
	_con_p1.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red del participante alto: %s" % t))
	_con_p1.paquete_juego.connect(func(m): _estado_p1.procesar(m))
	_con_p1.entrar_al_mundo(_host, int(_puertos[_nombre_p1]), _cuenta, _nombre_p1, _clave)
	_pasar_a("esperar p1")


func _abrir_p2() -> void:
	_estado_p2 = ESTADO.new()
	_estado_p2.pedido_ping.connect(func(): _con_p2.enviar_juego(PackedByteArray([0x1E])))
	_estado_p2.rechazados.connect(func(m): _fallar("FAIL el participante bajo fue rechazado: %s" % m))
	_estado_p2.mensaje_servidor.connect(func(t): _al_mensaje("LOW", t))
	_con_p2 = CONEXION.new()
	add_child(_con_p2)
	_con_p2.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red del participante bajo: %s" % t))
	_con_p2.paquete_juego.connect(func(m): _estado_p2.procesar(m))
	_con_p2.entrar_al_mundo(_host, _puerto_p2, _cuenta_p2, _nombre_p2, _clave_p2)
	_pasar_a("esperar p2")


func _al_mensaje(quien: String, texto: String) -> void:
	print("  [%s] %s" % [quien, texto])
	var t := texto.to_lower()
	# Disolucion de party: `Party::leaveParty` (`party.cpp:111,117`) y
	# `Party::disband` (`party.cpp:35`).
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

	# Regla de NIVEL del oracle (`party.cpp:344-355`), leida del estado
	# autoritativo parseado ANTES de cualquier mutacion de party. Aca se exige
	# lo CONTRARIO que en los fixtures positivos: el participante bajo tiene que
	# quedar por DEBAJO del minimo, y de forma natural.
	var n1 := int(_estado_p1.estadisticas.get("nivel", 0))
	var n2 := int(_estado_p2.estadisticas.get("nivel", 0))
	if n1 <= 0 or n2 <= 0:
		_fallar("BLOCKED no se pudo leer el nivel de ambos participantes")
		return
	_nivel_alto = max(n1, n2)
	_nivel_bajo = min(n1, n2)
	_nivel_minimo = _minimo_de_nivel(_nivel_alto)
	_bajo_por_debajo = _nivel_bajo < _nivel_minimo
	if not _bajo_por_debajo:
		_fallar("BLOCKED the configured participants already satisfy the level rule; there is no negative case to measure")
		return
	# El LIDER tiene que ser el de nivel alto: si el bajo fuera lider, el
	# maximo seguiria siendo el mismo, pero el reparto de roles del fixture
	# dejaria de corresponderse con lo observado.
	if n1 != _nivel_alto:
		_fallar("BLOCKED the leader session is not the high level participant")
		return

	# Regla de RANGO del oracle, aca como CONTROL: los dos tienen que estar
	# holgadamente DENTRO durante toda la corrida.
	if not _en_rango(_estado_p1.mi_pos, _estado_p2.mi_pos):
		_fallar("BLOCKED participants are not inside the shared experience range")
		return

	print("Preflight OK: relacion de nivel natural verificada (el participante bajo esta por debajo del minimo), sin modificar a nadie.")
	_preflight_ok = true
	_vigilar_piso = POS_A.z
	_pasar_a("formar party")


## `minLevel = static_cast<uint32_t>(std::ceil((float(highestLevel) * 2) / 3))`
## (`party.cpp:352`). Es ceil sobre punto flotante, NO division entera.
func _minimo_de_nivel(nivel_mas_alto: int) -> int:
	return int(ceil(float(nivel_mas_alto) * 2.0 / 3.0))


## `Position::areInRange<30, 30, 1>` tal cual: distancias absolutas por eje,
## limite inclusivo, tolerancia de un piso en Z.
func _en_rango(a: Vector3i, b: Vector3i) -> bool:
	return absi(a.x - b.x) <= RANGO_PARTY_XY \
		and absi(a.y - b.y) <= RANGO_PARTY_XY \
		and absi(a.z - b.z) <= RANGO_PARTY_Z


## Se resuelve al companero por su NOMBRE configurado, nunca "la otra criatura
## que haya": el campo puede tener fauna natural. El nombre vive solo en memoria
## de proceso y nunca se serializa.
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
	print("Formando party de prueba: el participante ALTO invita y es lider; el BAJO se une.")
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
		print("Party formada: lider de nivel alto y miembro de nivel bajo, sin terceros.")
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
## protegida. Es una regla real del oracle, ya certificada por
## `PARITY-PARTY-SHARED-EXP-001`, no un defecto del adaptador.
##
## Aca solo es montaje del harness, asi que la orden se reintenta hasta que el
## signo de batalla expire. Repetir es inocuo: si ya quedo solicitada,
## `setSharedExperience` vuelve temprano (`party.cpp:305-307`).
func _esperar_inactivos() -> void:
	if _msg_activada_habilitada > 0:
		_fallar("FAIL el servidor reporto la experiencia compartida como HABILITADA con un participante por debajo del nivel minimo; la regla de nivel no se comporta como dice el codigo leido")
		return
	if _msg_activada_inactivos > 0:
		print("Confirmado: solicitud aceptada y reparto NO habilitado (el mensaje generico del legacy habla de participantes inactivos).")
		_pasar_a("invocar 1")
		return
	if _ultimo_intento_activar == 0.0 or _espera - _ultimo_intento_activar >= ESPERA_MENSAJE:
		_ultimo_intento_activar = _espera
		print("El LIDER solicita activar la experiencia compartida (%ds)." % int(_espera))
		_con_p1.enviar_experiencia_compartida(true)
	if _espera > ESPERA_SOLICITUD:
		_fallar("FAIL el servidor no confirmo la solicitud del lider ni despues de que pudiera expirar el signo de batalla")


# -----------------------------------------------------------------
#  FASE 1 - Participacion legitima de los DOS contra el primer monstruo
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
	print("Invocando el PRIMER monstruo de prueba (participacion de ambos).")
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
		_fallar("BLOCKED aparecio mas de un monstruo nuevo de la primera especie; identidad ambigua")
		return
	if nuevos_p1.is_empty() or nuevos_p2.is_empty():
		if _espera > ESPERA_PASO:
			_fallar("FAIL el primer monstruo de prueba no aparecio para ambos participantes")
		return
	_id_m1 = int(nuevos_p1[0])
	_id_m1_p2 = int(nuevos_p2[0])
	print("Primer monstruo visible para los dos; los DOS lo atacan para registrar participacion.")
	# Desde ESTE instante corre el presupuesto de frescura: el tick de
	# participacion de cualquiera de los dos no puede ser anterior a esta orden.
	_t_m1_ataque = Time.get_ticks_msec()
	_atacar_m1()
	_pasar_a("combate 1")


func _atacar_m1() -> void:
	_con_p1.enviar_modos_combate(1, 1, 0)
	_con_p1.enviar_atacar(_id_m1)
	_con_p2.enviar_modos_combate(1, 1, 0)
	_con_p2.enviar_atacar(_id_m1_p2)


func _combate_1() -> void:
	var vivo: bool = _estado_p1.criaturas.has(_id_m1) \
		and int(_estado_p1.criaturas[_id_m1].get("vida", 0)) > 0
	if vivo:
		# El servidor puede cancelar el objetivo; se reenvia la orden y se
		# informa la vida vista para que un fallo por falta de dano sea
		# distinguible de un fallo por objetivo perdido.
		if _espera - _ultimo_reataque >= 5.0:
			_ultimo_reataque = _espera
			print("  combate 1 a los %ds: vida del objetivo vista por el alto = %d%%"
				% [int(_espera), int(_estado_p1.criaturas[_id_m1].get("vida", -1))])
			_atacar_m1()
		if _espera > ESPERA_COMBATE:
			_fallar("BLOCKED el primer monstruo no murio dentro de la ventana de combate; capacidad de combate insuficiente para esta corrida")
		return
	_t_m1_muerto = Time.get_ticks_msec()
	print("Primer monstruo muerto tras %.1fs; midiendo la participacion de ambos."
		% ((_t_m1_muerto - _t_m1_ataque) / 1000.0))
	_pasar_a("medir participacion")


## La participacion de cada uno se prueba con su ganancia INDIVIDUAL: solo entra
## al reparto de `Creature::death` (`creature.cpp:368-407`) quien figura en el
## `damageMap` con dano positivo, y ese mismo evento de dano es el que llama a
## `Party::updatePlayerTicks` (`player.cpp:3227`). Ganancia > 0 es entonces
## prueba autoritativa de participacion registrada.
func _medir_participacion() -> void:
	if _espera < 2.0:
		return
	var g1 := int(_estado_p1.estadisticas.get("experiencia", -1)) - _exp_p1_antes
	var g2 := int(_estado_p2.estadisticas.get("experiencia", -1)) - _exp_p2_antes
	var parte_compartida := int(ceil(float(_exp_bruta_1) * _multiplicador / 2.0))
	print("Participacion (relaciones, no totales): alto gano=%s, bajo gano=%s, suma <= experiencia base=%s"
		% [str(g1 > 0), str(g2 > 0), str(g1 + g2 <= _exp_bruta_1)])
	if g1 <= 0:
		_fallar("BLOCKED el participante alto no registro participacion medible contra el primer monstruo")
		return
	if g2 <= 0:
		_fallar("BLOCKED el participante bajo no registro participacion medible contra el primer monstruo; sin eso el 0 posterior no seria atribuible al nivel")
		return
	# Control independiente de que el pozo de party NO estaba operando ya en el
	# primer monstruo: con reparto habilitado los dos cobrarian `parte_compartida`
	# y la suma seria `exp * 1.20`, estrictamente MAYOR que la experiencia base.
	# Con pago individual proporcional la suma nunca puede pasar la base.
	if g1 + g2 > _exp_bruta_1:
		_fallar("FAIL la suma de las ganancias del primer monstruo supera su experiencia base; el pozo de party estaba operando pese a la regla de nivel")
		return
	if g1 == parte_compartida and g2 == parte_compartida:
		_fallar("FAIL los dos participantes cobraron exactamente la parte repartida del primer monstruo; el reparto estaba habilitado pese a la regla de nivel")
		return
	_alto_participo = true
	_bajo_participo = true
	print("Participacion establecida: los DOS danaron al primer monstruo y cobraron de forma individual.")
	_pasar_a("invocar 2")


# -----------------------------------------------------------------
#  FASE 2 - Reevaluacion forzada y medicion negativa
# -----------------------------------------------------------------
func _invocar_2() -> void:
	_ids_previos_m2 = _ids_actuales(_estado_p1)
	_exp_p1_antes = int(_estado_p1.estadisticas.get("experiencia", -1))
	_exp_p2_antes = int(_estado_p2.estadisticas.get("experiencia", -1))
	print("Invocando el SEGUNDO monstruo de prueba (medicion negativa; solo lo ataca el participante alto).")
	_con_god.enviar_hablar("/m %s" % _monstruo_2)
	_pasar_a("esperar monstruo 2")


func _esperar_monstruo_2() -> void:
	var nuevos := _monstruos_nuevos(_estado_p1, _ids_previos_m2, _monstruo_2)
	if nuevos.size() > 1:
		_fallar("BLOCKED aparecio mas de un monstruo nuevo de la segunda especie; identidad ambigua")
		return
	if nuevos.is_empty():
		if _espera > ESPERA_PASO:
			_fallar("FAIL el segundo monstruo de prueba no aparecio para el participante alto")
		return
	_id_m2 = int(nuevos[0])
	if _id_m2 == _id_m1:
		_fallar("BLOCKED el segundo objetivo tiene el mismo runtime id que el primero; identidad ambigua")
		return
	print("Segundo monstruo visible; SOLO el participante alto lo ataca.")
	_ultimo_reataque = 0.0
	# Instante de la PRIMERA orden de ataque del alto sobre el segundo monstruo.
	# El primer golpe que conecte a partir de aca dispara la reevaluacion con
	# todos los demas requisitos satisfechos y solo el de nivel roto.
	_t_m2_primer_golpe = Time.get_ticks_msec()
	_atacar_solo_alto()
	_pasar_a("combate 2")


func _atacar_solo_alto() -> void:
	_con_p1.enviar_modos_combate(1, 1, 0)
	_con_p1.enviar_atacar(_id_m2)


func _combate_2() -> void:
	# El presupuesto de frescura manda sobre la ventana de combate.
	var desde_primer_golpe := (Time.get_ticks_msec() - _t_m1_ataque) / 1000.0
	if desde_primer_golpe > VENTANA_FRESCURA:
		_fallar("BLOCKED freshness budget exceeded before the negative measurement completed; el 0 del participante bajo no seria atribuible al nivel")
		return
	var vivo: bool = _estado_p1.criaturas.has(_id_m2) \
		and int(_estado_p1.criaturas[_id_m2].get("vida", 0)) > 0
	if vivo:
		if _espera - _ultimo_reataque >= 4.0:
			_ultimo_reataque = _espera
			print("  combate 2 a los %ds (presupuesto %.1fs de %.1fs): vida = %d%%, bajo en combate = %s"
				% [int(_espera), desde_primer_golpe, VENTANA_FRESCURA,
					int(_estado_p1.criaturas[_id_m2].get("vida", -1)),
					str(_estado_p2.en_combate)])
			_atacar_solo_alto()
		return
	_t_m2_muerto = Time.get_ticks_msec()
	# Se latchea AQUI, en el mismo frame en que se observa la muerte del
	# objetivo: es el instante en que el servidor resolvio el reparto.
	_bajo_en_combate_al_morir = _estado_p2.en_combate
	print("Segundo monstruo muerto; midiendo el reparto negativo.")
	_pasar_a("medir negativo")


func _medir_negativo() -> void:
	# Se le da margen al `0xA0` de experiencia del alto antes de comparar.
	if _espera < 2.0:
		return
	var g1 := int(_estado_p1.estadisticas.get("experiencia", -1)) - _exp_p1_antes
	var g2 := int(_estado_p2.estadisticas.get("experiencia", -1)) - _exp_p2_antes
	var ventana := (_t_m2_muerto - _t_m1_ataque) / 1000.0
	var parte_compartida := int(ceil(float(_exp_bruta_2) * _multiplicador / 2.0))
	print("Medicion negativa (relaciones, no totales): el alto gano=%s, el bajo gano=%s"
		% [str(g1 > 0), str(g2 > 0)])
	print("Desglose del presupuesto (cota conservadora, solo diagnostico):")
	print("  combate 1 (los dos adentro)    : %.1fs"
		% ((_t_m1_muerto - _t_m1_ataque) / 1000.0))
	print("  medicion e invocacion del 2.o  : %.1fs"
		% ((_t_m2_primer_golpe - _t_m1_muerto) / 1000.0))
	print("  combate 2 (solo el alto)       : %.1fs"
		% ((_t_m2_muerto - _t_m2_primer_golpe) / 1000.0))
	print("Ventana de frescura consumida: %.1fs de %.1fs (pzLocked = %dms); bajo con signo de batalla al morir el objetivo = %s"
		% [ventana, VENTANA_FRESCURA, PZ_LOCKED_MS, str(_bajo_en_combate_al_morir)])

	# --- Desambiguacion: el 0 del participante bajo tiene que ser por NIVEL ---
	if not _bajo_en_combate_al_morir:
		_fallar("BLOCKED el participante bajo perdio su signo de batalla; el servidor pudo haberle limpiado los puntos de participacion y el 0 no seria atribuible al nivel")
		return
	if ventana > VENTANA_FRESCURA:
		_fallar("BLOCKED freshness budget exceeded; el 0 del participante bajo no seria atribuible al nivel")
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
	if not _rango_continuo or not _en_rango(_estado_p1.mi_pos, _estado_p2.mi_pos):
		_fallar("BLOCKED los participantes salieron del rango permitido; el 0 no seria atribuible al nivel")
		return

	# La relacion de nivel se vuelve a leer del estado autoritativo AL MEDIR, no
	# solo en el preflight: si alguno hubiera subido de nivel durante la corrida,
	# la condicion negativa podria haber dejado de existir.
	var n1 := int(_estado_p1.estadisticas.get("nivel", 0))
	var n2 := int(_estado_p2.estadisticas.get("nivel", 0))
	if n1 != _nivel_alto or n2 != _nivel_bajo:
		_fallar("BLOCKED el nivel de algun participante cambio durante la corrida; la condicion medida no seria la declarada")
		return
	if n2 >= _minimo_de_nivel(max(n1, n2)):
		_fallar("BLOCKED la relacion de nivel dejo de cumplirse en el momento de medir")
		return

	if g1 <= 0:
		_fallar("FAIL el participante alto no gano experiencia del segundo monstruo; la medicion no discrimina")
		return
	if g2 != 0:
		_fallar("FAIL el participante bajo gano experiencia estando por debajo del nivel minimo")
		return

	# Corroboracion fuerte: con el reparto suprimido el unico atacante cobra el
	# pago individual COMPLETO; con el reparto habilitado cobraria la fraccion.
	_pago_individual_completo = g1 == _exp_bruta_2
	print("Corroboracion de magnitud: pago individual completo=%s (la alternativa repartida habria sido una fraccion distinta: %d)"
		% [str(_pago_individual_completo), parte_compartida])
	if not _pago_individual_completo:
		_fallar("FAIL el participante alto no cobro el pago individual completo del segundo monstruo; la supresion no queda corroborada por magnitud")
		return

	_obs = {
		"level_condition": {
			"low_participant_below_required_level": _bajo_por_debajo
				and n2 < _minimo_de_nivel(max(n1, n2)),
		},
		"controls": {
			"party_remained_formed": _party_continua and not _mensaje_party_rota
				and _escudo_propio(_estado_p1) == SHIELD_LIDER
				and _escudo_propio(_estado_p2) == SHIELD_MIEMBRO,
			"both_sessions_remained_connected": _sesiones_continuas
				and _estado_p1.adentro and _estado_p2.adentro,
			"within_allowed_range": _rango_continuo
				and _en_rango(_estado_p1.mi_pos, _estado_p2.mi_pos),
			"both_participants_had_fresh_activity": _alto_participo and _bajo_participo
				and _bajo_en_combate_al_morir and ventana <= VENTANA_FRESCURA,
		},
		"level_ineligible_distribution": {
			"high_participant_gained_experience": g1 > 0,
			"low_participant_gained_experience": g2 > 0,
			# El reparto quedo suprimido, no repartido-excluyendo-al-bajo: el
			# participante alto cobro el pago individual COMPLETO del segundo
			# objetivo, no la fraccion que produciria la formula de reparto.
			"shared_distribution_suppressed": _pago_individual_completo and g2 == 0,
		},
	}
	_pasar_a("confirmar party")


# -----------------------------------------------------------------
#  Limpieza y confirmacion final de continuidad
# -----------------------------------------------------------------
func _confirmar_party() -> void:
	var p1_ve := int(_estado_p1.criaturas.get(_id_p2_visto_por_p1, {}).get("escudo_party", -1))
	var p2_ve := int(_estado_p2.criaturas.get(_id_p1_visto_por_p2, {}).get("escudo_party", -1))
	if p1_ve == SHIELD_MIEMBRO and p2_ve == SHIELD_LIDER:
		print("Confirmado tras la medicion: la party seguia formada, lider alto y miembro bajo.")
		_emitir_observacion()
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED no se pudo reconfirmar la relacion de party tras la medicion")


func _emitir_observacion() -> void:
	## Ningun nombre, nivel, vocacion, id de runtime, coordenada, vida, total de
	## experiencia, especie de monstruo, marca de tiempo ni metadata de host.
	## Solo relaciones.
	print("OBSERVATION_JSON: " + JSON.stringify(_obs))
	print("Captura de nivel de experiencia compartida: OK")
	_limpiar()
	_terminar(0)


func _limpiar() -> void:
	## Se deshace SOLO la party creada por esta prueba y se devuelve a los
	## participantes a su templo. Si quedara un monstruo de prueba vivo por un
	## aborto, se lo retira por ataque DIRIGIDO a su runtime id, nunca por area:
	## la fauna preexistente no se toca y `/killall` no se emite nunca.
	if _con_p1 != null:
		if _id_m2 != 0:
			_con_p1.enviar_atacar(_id_m2)
		elif _id_m1 != 0:
			_con_p1.enviar_atacar(_id_m1)
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
