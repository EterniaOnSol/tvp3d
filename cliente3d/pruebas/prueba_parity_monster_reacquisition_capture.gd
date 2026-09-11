extends Node

# Captura QA-owned en vivo: reacquisicion de objetivo de monstruo
# (Phase 2C). Endurecida siguiendo el mismo patron de
# prueba_parity_monster_corpse_capture.gd (Phase 2B.2.1).
#
# NO reemplaza ni modifica `prueba_reacquisicion_monstruo.gd` (evidencia
# historica, con credenciales fijas). Este adaptador es enteramente nuevo,
# lee credenciales solo por variable de entorno, y evita el `/killall`
# amplio inicial que usaba la version historica para "limpiar el campo":
# en vez de eso inspecciona el campo antes de invocar y aborta limpio si ya
# hay un cave rat visible que podria crear ambiguedad de identidad.
#
# Requiere DOS sesiones: una god (ordenes de servidor: /gotopos, /c, /m) y
# una de personaje normal (sujeto de la reacquisicion). El personaje normal
# nunca camina ni decide nada: todo movimiento es orden del servidor via el
# god, igual que en la evidencia historica.
#
# Esta rama NO decide PASS/FAIL: eso lo hace exclusivamente
# `qa/parity/tools/replay.py` comparando esta observacion contra la
# `ParityExpectationV1` ya publicada. Este script solo observa y serializa.
#
# Credenciales: exclusivamente por variable de entorno, nunca literal en este
# archivo:
#   TVP772_ACCOUNT           (numero de cuenta)
#   TVP772_PASSWORD          (clave)
#   TVP772_GOD_CHARACTER     (nombre del personaje god)
#   TVP772_PLAYER_CHARACTER  (nombre del personaje normal)
# Opcionales:
#   TVP772_HOST              (por defecto 127.0.0.1)
#   TVP772_LOGIN_PORT        (por defecto 7171)
#
#   ...Godot --headless --path cliente3d pruebas/prueba_parity_monster_reacquisition_capture.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST_DEFECTO := "127.0.0.1"
const PUERTO_LOGIN_DEFECTO := 7171
## Terreno operativo calificado por Phase 2C.1 y corregido en Phase 2C.2; ver
## `docs/qa/PARITY_PHASE2C2_MONSTER_REACQUISITION_LIVE.md`. Aislamiento
## estatico contra spawns y raids con
## `qa/parity/tools/qualify_reacquisition_terrain.py`, confirmado con una
## sonda pasiva solo-god de 60 s por punto que no observo ninguna criatura
## natural, y ademas comprobado en vivo que el servidor si acepta colocar al
## personaje en ambos puntos con `/c`.
##
##   POS_CAMPO = punto A: aca se reune al personaje, se invoca la rata de
##               prueba, se mide el primer golpe y se mide la reaparicion.
##   POS_LEJOS = punto B: destino temporal del hueco de visibilidad.
##
## El par preseleccionado por Phase 2C.1 resulto NO colocable: aquellas
## casillas estaban aisladas justamente porque son terreno inhabitable, y
## `/c` (`getClosestFreePosition`) no encuentra casilla libre ahi. Este par
## si acepta al personaje. Separacion dy = 61: basta con que UN eje quede
## fuera de la ventana de visibilidad (`dx in [-8,+9]`, `dy in [-6,+7]`,
## `protocolgame.cpp:766-767`) y del rango de espectadores del servidor (11),
## asi que 61 deja 50 de margen. Aun asi la desaparicion real del objetivo se
## exige en runtime; la separacion nunca se usa como prueba por si sola.
##
## Reemplazan al campo historico de `docs/qa/PRUEBA_VIVA_REACQUISICION.md`
## (que sigue siendo evidencia historica intacta) porque aquel estaba dentro
## de actividad natural de cave rats: en Phase 2C eso produjo ambiguedad de
## identidad del atacante y muertes del personaje de prueba.
##
## Son detalles internos de navegacion del capturador: NUNCA entran al
## payload normalizado ni al fixture/case/expectation.
const POS_CAMPO := Vector3i(32008, 32400, 7)
const POS_LEJOS := Vector3i(32008, 32339, 7)
const RADIO_LLEGADA := 2
const MONSTRUO := "cave rat"

const PAUSA_SESION := 6.0
const ESPERA_PASO := 15.0
const ESPERA_GOLPE := 45.0
const LIMITE_TOTAL := 240.0

var _con_login
var _con_god
var _con_jugador
var _estado_god
var _estado_jugador
var _puertos := {}
var _fase := "login"
var _espera := 0.0
var _total := 0.0
var _terminando := false

var _cuenta := 0
var _clave := ""
var _personaje_god := ""
var _personaje_jugador := ""
var _host := HOST_DEFECTO
var _puerto_login := PUERTO_LOGIN_DEFECTO

var _ids_antes := {}
var _id_monstruo := 0
var _vida_inicial := -1
var _vida_al_volver := -1
var _golpes_cave_rat := 0
var _golpes_al_salir := 0
var _intentos_limpieza := 0
var _intentos_invocar := 0
## Ids que alguna vez llegaron identificados como `cave rat`, para sobrevivir
## a la perdida de nombre de las criaturas ya conocidas (ver
## `_registrar_cave_rats`).
var _ids_cave_rat := {}
var _codigo_salida := 0
var _limpieza_emergencia_intentada := false


func _ready() -> void:
	print("=================================================")
	print(" TVP3D QA - captura en vivo: reacquisicion de monstruo")
	print("=================================================")

	var falta := _resolver_credenciales()
	if not falta.is_empty():
		print("BLOCKED missing environment variable %s" % falta)
		get_tree().quit(2)
		return

	_abrir_login()


func _resolver_credenciales() -> String:
	var cuenta_texto := OS.get_environment("TVP772_ACCOUNT")
	if cuenta_texto.is_empty():
		return "TVP772_ACCOUNT"
	if not cuenta_texto.is_valid_int():
		return "TVP772_ACCOUNT"
	_cuenta = int(cuenta_texto)

	_clave = OS.get_environment("TVP772_PASSWORD")
	if _clave.is_empty():
		return "TVP772_PASSWORD"

	_personaje_god = OS.get_environment("TVP772_GOD_CHARACTER")
	if _personaje_god.is_empty():
		return "TVP772_GOD_CHARACTER"

	_personaje_jugador = OS.get_environment("TVP772_PLAYER_CHARACTER")
	if _personaje_jugador.is_empty():
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
	## Se memoriza la identidad de cualquier cave rat en cuanto llega con
	## nombre, en cada frame: el nombre puede perderse despues (ver
	## `_registrar_cave_rats`) y entonces ya no habria forma de reconocerlo.
	if _estado_jugador != null:
		_registrar_cave_rats(_estado_jugador)
	# Guarda de seguridad continua: si alguna vez la vida del personaje llega
	# a cero, se aborta de inmediato. Este capturador nunca debe dejar morir
	# al personaje normal. Se dispara UNA sola vez (_codigo_salida == 0
	# todavia): una vez que el cierre/limpieza de emergencia ya arranco, no
	# debe volver a interrumpirse a si mismo en cada frame mientras la vida
	# siga en cero durante el respawn.
	if _codigo_salida == 0 and _estado_jugador != null and _estado_jugador.adentro \
			and int(_estado_jugador.estadisticas.get("vida", -1)) == 0:
		_fallar("FAIL el personaje normal llego a vida cero; abortando sin emitir observacion")
		return
	match _fase:
		"esperar god":
			if _estado_god != null and _estado_god.adentro and _espera > 2.0:
				_pasar_a("pausa segundo cliente")
		"pausa segundo cliente":
			if _espera >= PAUSA_SESION:
				_abrir_jugador()
		"esperar jugador":
			if _estado_jugador != null and _estado_jugador.adentro and _espera > 2.0:
				_preparar_campo()
		"esperar god en campo":
			_esperar_god_en(POS_CAMPO, "reunir en campo")
		"reunir en campo":
			_reunir_en(POS_CAMPO, "verificar campo libre")
		"verificar campo libre":
			_verificar_campo_libre()
		"invocar":
			if _espera > 2.0:
				_invocar()
		"esperar monstruo":
			_esperar_monstruo()
		"esperar primer golpe":
			_esperar_golpe(true)
		"esperar god lejos":
			_esperar_god_en(POS_LEJOS, "reunir lejos")
		"reunir lejos":
			_reunir_en(POS_LEJOS, "confirmar salida de vista")
		"confirmar salida de vista":
			_confirmar_salida_de_vista()
		"volver god al campo":
			_con_god.enviar_hablar(_orden_gotopos(POS_CAMPO))
			_pasar_a("esperar god de vuelta")
		"esperar god de vuelta":
			_esperar_god_en(POS_CAMPO, "reunir de vuelta")
		"reunir de vuelta":
			_reunir_en(POS_CAMPO, "esperar reaparicion")
		"esperar reaparicion":
			_esperar_reaparicion()
		"esperar segundo golpe":
			_esperar_golpe(false)
		"limpiar objetivo":
			_limpiar_objetivo()
		"esperar limpieza":
			_esperar_limpieza()
		"devolver templo":
			_devolver_al_templo()
		"esperar salida campo":
			_esperar_salida_campo()


# -----------------------------------------------------------------
# Sesiones
# -----------------------------------------------------------------
func _abrir_login() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.error_red.connect(func(texto): _fallar("FAIL fallo de red en login: %s" % texto))
	_con_login.lista_personajes.connect(_al_lista)
	_con_login.pedir_personajes(_host, _puerto_login, _cuenta, _clave)


func _al_lista(_motd: String, personajes: Array) -> void:
	for entrada in personajes:
		_puertos[str(entrada.get("nombre", ""))] = int(entrada.get("puerto", 0))
	if int(_puertos.get(_personaje_god, 0)) <= 0:
		_fallar("FAIL character configured by TVP772_GOD_CHARACTER was not found")
		return
	if int(_puertos.get(_personaje_jugador, 0)) <= 0:
		_fallar("FAIL character configured by TVP772_PLAYER_CHARACTER was not found")
		return
	_con_login.cerrar()
	_con_login.queue_free()
	_con_login = null
	_abrir_god()


func _abrir_god() -> void:
	_estado_god = ESTADO.new()
	_estado_god.pedido_ping.connect(func(): _con_god.enviar_juego(PackedByteArray([0x1E])))
	_estado_god.mensaje_servidor.connect(func(texto): print("  [god] ", texto))
	_estado_god.rechazados.connect(func(motivo): _fallar("FAIL el god fue rechazado: %s" % motivo))
	_con_god = CONEXION.new()
	add_child(_con_god)
	_con_god.error_red.connect(func(texto):
		if not _terminando: _fallar("FAIL fallo de red del god: %s" % texto))
	_con_god.paquete_juego.connect(func(msg): _estado_god.procesar(msg))
	_con_god.entrar_al_mundo(_host, int(_puertos[_personaje_god]), _cuenta, _personaje_god, _clave)
	_pasar_a("esperar god")


func _abrir_jugador() -> void:
	_estado_jugador = ESTADO.new()
	_estado_jugador.pedido_ping.connect(func(): _con_jugador.enviar_juego(PackedByteArray([0x1E])))
	_estado_jugador.mensaje_servidor.connect(_al_mensaje_jugador)
	_estado_jugador.rechazados.connect(func(motivo): _fallar("FAIL el personaje fue rechazado: %s" % motivo))
	_con_jugador = CONEXION.new()
	add_child(_con_jugador)
	_con_jugador.error_red.connect(func(texto):
		if not _terminando: _fallar("FAIL fallo de red del personaje: %s" % texto))
	_con_jugador.paquete_juego.connect(func(msg): _estado_jugador.procesar(msg))
	_con_jugador.entrar_al_mundo(_host, int(_puertos[_personaje_jugador]), _cuenta,
		_personaje_jugador, _clave)
	_pasar_a("esperar jugador")


func _al_mensaje_jugador(texto: String) -> void:
	print("  [jugador] ", texto)
	## Disambiguacion exacta por nombre de atacante: una bajada de vida
	## generica NO alcanza (el campo es campo abierto con criaturas
	## silvestres). Solo cuenta si el mensaje autoritativo nombra
	## explicitamente al cave rat.
	var normalizado := texto.to_lower()
	if normalizado.contains("attack by") and normalizado.contains(MONSTRUO):
		_golpes_cave_rat += 1


# -----------------------------------------------------------------
# Recorrido vivo
# -----------------------------------------------------------------
func _preparar_campo() -> void:
	print("El servidor lleva al god al campo.")
	_con_god.enviar_hablar(_orden_gotopos(POS_CAMPO))
	_pasar_a("esperar god en campo")


func _esperar_god_en(destino: Vector3i, siguiente: String) -> void:
	if _estado_god.mi_pos == destino:
		_pasar_a(siguiente)
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL el god no llego a %s a tiempo" % str(destino))


func _reunir_en(destino: Vector3i, siguiente: String) -> void:
	if _cerca(_estado_jugador.mi_pos, destino):
		if siguiente == "esperar reaparicion":
			_vida_al_volver = _vida()
		_pasar_a(siguiente)
		return
	if _espera < 0.2:
		return
	if _espera < 0.5:
		_con_god.enviar_hablar("/c %s" % _personaje_jugador)
	if _espera > ESPERA_PASO:
		_fallar("FAIL /c no acerco al personaje a %s a tiempo" % str(destino))


## Ninguna limpieza amplia (`/killall`) se emite antes de invocar: en vez de
## eso, si ya hay un cave rat vivo visible, se aborta limpio sin mutar nada
## que esta corrida no creo. Evita matar fauna salvaje preexistente solo
## para "limpiar" el campo.
func _verificar_campo_libre() -> void:
	if _cave_rats_vivos(_estado_jugador) > 0:
		_fallar("BLOCKED ya hay un cave rat visible en el campo antes de invocar; abortando para evitar ambiguedad de identidad")
		return
	_pasar_a("invocar")


## `cliente3d/red/estado_mundo.gd` puede perder el nombre de una criatura ya
## conocida: cuando el servidor la reenvia en forma corta y la entrada previa
## ya no esta en el diccionario, la reconstruye con `nombre` vacio. Se
## observo en vivo que el objetivo, el god y el propio personaje quedaban los
## tres con nombre vacio a mitad de la medicion. Ese parser pertenece al
## carril `protocolo-red` y este turno no lo toca.
##
## Por eso la identidad de "cave rat" se memoriza por id la primera vez que
## SI llega con nombre, y a partir de ahi la desambiguacion trabaja sobre ese
## conjunto de ids. No se debilita nada: el objetivo sigue identificandose
## por un runtime id nuevo y unico, el atacante sigue exigiendo el mensaje
## autoritativo que nombre al cave rat, y la ambiguedad sigue rechazandose si
## hay mas de un cave rat conocido vivo a la vista.
func _registrar_cave_rats(estado) -> void:
	for id in estado.criaturas:
		var criatura: Dictionary = estado.criaturas[id]
		if str(criatura.get("nombre", "")).to_lower() == MONSTRUO:
			_ids_cave_rat[int(id)] = true


func _cave_rats_vivos(estado) -> int:
	_registrar_cave_rats(estado)
	var cantidad := 0
	for id in estado.criaturas:
		if not _ids_cave_rat.has(int(id)):
			continue
		var criatura: Dictionary = estado.criaturas[id]
		if int(criatura.get("vida", 100)) <= 0:
			continue
		cantidad += 1
	return cantidad


func _invocar() -> void:
	_ids_antes.clear()
	for id in _estado_jugador.criaturas:
		_ids_antes[int(id)] = true
	_vida_inicial = _vida()
	print("Campo libre. Invocando %s." % MONSTRUO)
	_con_god.enviar_hablar("/m %s" % MONSTRUO)
	_pasar_a("esperar monstruo")


func _esperar_monstruo() -> void:
	var candidatos: Array = []
	for id in _estado_jugador.criaturas:
		if _ids_antes.has(int(id)) or int(id) == _estado_jugador.mi_id:
			continue
		var criatura: Dictionary = _estado_jugador.criaturas[id]
		if str(criatura.get("nombre", "")).to_lower() == MONSTRUO:
			candidatos.append(int(id))
	if candidatos.size() > 1:
		_fallar("FAIL aparecio mas de un cave rat nuevo simultaneamente; ambiguedad de identidad")
		return
	if candidatos.size() == 1:
		_id_monstruo = candidatos[0]
		## Se memoriza la identidad AHORA, que es cuando el servidor si
		## entrega el nombre. Mas adelante `estado_mundo.gd` puede reenviar la
		## criatura en forma corta y dejar `nombre` vacio; a partir de ese
		## momento el nombre ya no sirve para desambiguar y solo vale el id.
		_ids_cave_rat[_id_monstruo] = true
		print("Cave rat nuevo id %d visto por el personaje." % _id_monstruo)
		_pasar_a("esperar primer golpe")
		return
	if _espera > ESPERA_PASO:
		_intentos_invocar += 1
		if _intentos_invocar > 3:
			_fallar("FAIL el cave rat invocado no aparecio para el personaje")
			return
		_pasar_a("invocar")


## Comprobacion identica para el golpe de "antes de irse" y el de "despues
## de volver": exige mensaje autoritativo que nombre al cave rat, vida en
## baja, Y que exactamente un cave rat vivo (el nuestro) sea visible en ese
## instante. Un spider u otra criatura silvestre nunca puede satisfacer esto.
func _esperar_golpe(es_primero: bool) -> void:
	var vida := _vida()
	var referencia := _vida_inicial if es_primero else _vida_al_volver
	var golpes_previos := 0 if es_primero else _golpes_al_salir
	if _golpes_cave_rat > golpes_previos and vida >= 0 and vida < referencia:
		if _cave_rats_vivos(_estado_jugador) != 1 \
				or not _estado_jugador.criaturas.has(_id_monstruo) \
				or int(_estado_jugador.criaturas[_id_monstruo].get("vida", 0)) <= 0:
			# Ambiguedad momentanea (por ejemplo dos cave rats momentaneamente
			# visibles): no se acepta esta evidencia todavia, se sigue
			# esperando en vez de adivinar.
			if _espera > ESPERA_GOLPE:
				var diag: Array = []
				for id2 in _estado_jugador.criaturas:
					var c2: Dictionary = _estado_jugador.criaturas[id2]
					diag.append("id=%d '%s' vida=%s pos=%s" % [
						int(id2), str(c2.get("nombre", "?")),
						str(c2.get("vida", "?")), str(c2.get("pos", "?"))])
				diag.sort()
				print("DIAG objetivo=%d presente=%s | cave_rats_vivos=%d | jugador_pos=%s" % [
					_id_monstruo, str(_estado_jugador.criaturas.has(_id_monstruo)),
					_cave_rats_vivos(_estado_jugador), str(_estado_jugador.mi_pos)])
				print("DIAG criaturas visibles del jugador: %s" % str(diag))
				_fallar("FAIL identidad del atacante ambigua: mas de un cave rat visible o el objetivo esperado no es el que esta vivo")
			return
		if es_primero:
			_golpes_al_salir = _golpes_cave_rat
			print("Primer golpe de cave rat confirmado (identidad sin ambiguedad).")
			_con_god.enviar_hablar(_orden_gotopos(POS_LEJOS))
			_pasar_a("esperar god lejos")
		else:
			print("Segundo golpe de cave rat confirmado tras volver (identidad sin ambiguedad).")
			_emitir_observacion()
		return
	if _espera > ESPERA_GOLPE:
		_fallar("FAIL el cave rat esperado no golpeo a tiempo (vida %d, referencia %d)" % [vida, referencia])


func _confirmar_salida_de_vista() -> void:
	## Prueba directa, no inferida por distancia: el objetivo debe
	## desaparecer realmente del diccionario de criaturas del personaje
	## (estado_mundo.gd borra la entrada cuando el servidor retira la
	## criatura de la vista, opcode 0x6C). La separacion entre A y B no
	## alcanza por si sola como evidencia: se exige la confirmacion real.
	if _estado_jugador.criaturas.has(_id_monstruo):
		if _espera > ESPERA_PASO:
			_fallar("FAIL el cave rat objetivo nunca desaparecio del conjunto visible del personaje")
		return
	if _vida() <= 0:
		_fallar("FAIL el personaje no sobrevivio al alejamiento")
		return
	if _estado_jugador.mi_pos.z != POS_CAMPO.z:
		_fallar("FAIL el personaje cambio de piso durante el alejamiento")
		return
	print("Confirmado: el cave rat objetivo salio del conjunto visible del personaje.")
	_pasar_a("volver god al campo")


func _esperar_reaparicion() -> void:
	_registrar_cave_rats(_estado_jugador)
	## La identidad exigida es el runtime id, no el nombre: el id del objetivo
	## se fijo cuando el servidor si lo mandaba con nombre, y `_ids_cave_rat`
	## lo conserva aunque una reenvio corto posterior deje el nombre vacio.
	if _estado_jugador.criaturas.has(_id_monstruo):
		var criatura: Dictionary = _estado_jugador.criaturas[_id_monstruo]
		if int(criatura.get("vida", 0)) > 0:
			print("El mismo cave rat (id %d) reaparecio en el conjunto visible del personaje." % _id_monstruo)
			_pasar_a("esperar segundo golpe")
			return
	# Si aparece un cave rat NUEVO (id distinto) mientras el nuestro sigue
	# ausente, eso es "mismo nombre, id distinto": NO cuenta como
	# reacquisicion de la misma instancia y es un FAIL explicito.
	for id in _estado_jugador.criaturas:
		if int(id) == _id_monstruo:
			continue
		if not _ids_cave_rat.has(int(id)):
			continue
		var criatura2: Dictionary = _estado_jugador.criaturas[id]
		if int(criatura2.get("vida", 100)) <= 0:
			continue
		_fallar("FAIL reaparecio un cave rat con id distinto al objetivo original; no es la misma instancia")
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL el cave rat objetivo (mismo id) no reaparecio a tiempo")


## Limpieza del objetivo: ataque dirigido (no un area) es la opcion
## preferida. Solo si el ataque dirigido no lo retira a tiempo se recurre a
## `/killall`, reusando la misma regla de seguridad de Phase 2B.2.1: nunca
## emitirlo si otra criatura viva distinta del objetivo esta dentro de su
## area real (AREA_SQUARE1X1, radio Chebyshev 1 sobre la posicion del god).
func _limpiar_objetivo() -> void:
	if not _estado_jugador.criaturas.has(_id_monstruo) \
			or int(_estado_jugador.criaturas[_id_monstruo].get("vida", 0)) <= 0:
		print("El cave rat objetivo ya no esta vivo.")
		_pasar_a("devolver templo")
		return
	if _espera < 1.0:
		return
	_espera = 0.0
	var criatura: Dictionary = _estado_jugador.criaturas[_id_monstruo]
	var posicion: Vector3i = criatura.get("pos", POS_CAMPO)
	if not _cerca(_estado_god.mi_pos, posicion):
		_con_god.enviar_hablar(_orden_gotopos(posicion))
		return
	_con_god.enviar_modos_combate(1, 1, 0)
	_con_god.enviar_atacar(_id_monstruo)
	_pasar_a("esperar limpieza")


func _esperar_limpieza() -> void:
	if not _estado_jugador.criaturas.has(_id_monstruo) \
			or int(_estado_jugador.criaturas[_id_monstruo].get("vida", 0)) <= 0:
		print("Limpieza confirmada: el cave rat objetivo fue retirado por ataque dirigido.")
		_pasar_a("devolver templo")
		return
	if _espera > 8.0:
		_intentos_limpieza += 1
		if _intentos_limpieza < 3:
			_pasar_a("limpiar objetivo")
			return
		# Fallback: /killall, pero solo si su area real (radio Chebyshev 1
		# sobre la posicion del god) no contiene otra criatura viva.
		if _area_de_killall_segura(_estado_god.mi_pos):
			print("Ataque dirigido no alcanzo; fallback /killall (area verificada sin colateral).")
			_con_god.enviar_hablar("/killall")
			_espera = 0.0
		else:
			_fallar("FAIL no se pudo limpiar el objetivo con ataque dirigido y /killall no es seguro (otra criatura viva en su area)")


## Identica regla de seguridad que Phase 2B.2.1
## (servidor/data/scripts/talkactions/god/kill_creatures.lua +
## servidor/data/scripts/spells/areas.lua: AREA_SQUARE1X1, matriz 3x3,
## radio Chebyshev 1 centrado en la posicion propia de quien lo dice).
func _area_de_killall_segura(centro: Vector3i) -> bool:
	for id in _estado_jugador.criaturas:
		if int(id) == _estado_jugador.mi_id or int(id) == _id_monstruo:
			continue
		var criatura: Dictionary = _estado_jugador.criaturas[id]
		if int(criatura.get("vida", 100)) <= 0:
			continue
		var pos: Vector3i = criatura.get("pos", Vector3i.ZERO)
		if pos.z != centro.z:
			continue
		if absi(pos.x - centro.x) <= 1 and absi(pos.y - centro.y) <= 1:
			return false
	return true


func _devolver_al_templo() -> void:
	if _espera < 2.0:
		return
	print("Devolviendo al personaje a su templo.")
	_con_god.enviar_hablar("omani %s" % _personaje_jugador)
	_pasar_a("esperar salida campo")


func _esperar_salida_campo() -> void:
	if not _cerca(_estado_jugador.mi_pos, POS_CAMPO):
		if _vida() <= 0:
			_fallar("FAIL el personaje no sobrevivio a la limpieza/retorno")
			return
		print("El personaje quedo fuera del campo, con vida.")
		if _codigo_salida == 0:
			_terminar_ok()
		else:
			_terminar(_codigo_salida)
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL no se pudo devolver al personaje a su templo")


# -----------------------------------------------------------------
# Observacion normalizada
# -----------------------------------------------------------------
func _emitir_observacion() -> void:
	## Ningun runtime id, HP exacto, dano exacto ni coordenada entra al
	## payload: son detalles de captura, nunca hechos versionados. La
	## relacion "mismo id antes y despues" ya se verifico arriba
	## comparando IDs en memoria de proceso; aca solo se serializa el
	## resultado booleano de esa comparacion.
	var payload := {
		"monster_kind": MONSTRUO,
		"before_leave": {
			"attack_observed": true,
			"attacker_matches_monster_kind": true,
			"hp_decreased": true,
		},
		"visibility_gap": {
			"target_left_visible_set": true,
			"player_session_continued": true,
			"player_survived": true,
		},
		"after_return": {
			"target_reappeared": true,
			"same_runtime_id": true,
			"attack_observed": true,
			"attacker_matches_monster_kind": true,
			"hp_decreased": true,
		},
	}
	var linea := "OBSERVATION_JSON: " + JSON.stringify(payload)
	print(linea)
	print("Prueba de captura en vivo (reacquisicion de monstruo): observacion emitida.")
	_pasar_a("limpiar objetivo")


# -----------------------------------------------------------------
# Utilidades
# -----------------------------------------------------------------
func _vida() -> int:
	return int(_estado_jugador.estadisticas.get("vida", -1))


func _cerca(posicion: Vector3i, centro: Vector3i) -> bool:
	return posicion.z == centro.z \
		and absi(posicion.x - centro.x) <= RADIO_LLEGADA \
		and absi(posicion.y - centro.y) <= RADIO_LLEGADA


func _orden_gotopos(posicion: Vector3i) -> String:
	return "/gotopos %d,%d,%d" % [posicion.x, posicion.y, posicion.z]


func _pasar_a(fase: String) -> void:
	print("  [%.0fs] fase: %s" % [_total, fase])
	_fase = fase
	_espera = 0.0


func _fallar(texto: String) -> void:
	print(texto)
	_forzar_cierre(1)


func _terminar_ok() -> void:
	print("Prueba de captura en vivo (reacquisicion de monstruo): OK")
	_terminar(0)


## Punto de entrada unico para cualquier fallo. Si esta corrida ya invoco un
## cave rat y sigue vivo, intenta la misma limpieza dirigida del camino
## feliz antes de cerrar: una medicion fallida nunca debe dejar vivo el
## monstruo que esta corrida creo.
func _forzar_cierre(codigo: int) -> void:
	if _terminando:
		return
	_codigo_salida = codigo
	if not _limpieza_emergencia_intentada and _id_monstruo != 0 \
			and _con_god != null and _estado_jugador != null \
			and _estado_jugador.criaturas.has(_id_monstruo) \
			and int(_estado_jugador.criaturas[_id_monstruo].get("vida", 0)) > 0:
		_limpieza_emergencia_intentada = true
		print("Limpieza de emergencia: retirando el cave rat de esta corrida antes de cerrar.")
		_pasar_a("limpiar objetivo")
		return
	_terminar(codigo)


func _terminar(codigo: int) -> void:
	if _terminando:
		return
	_terminando = true
	if _con_god != null:
		_con_god.cerrar()
	if _con_jugador != null:
		_con_jugador.cerrar()
	get_tree().quit(codigo)
