extends Node

# Captura QA-owned en vivo: RESTRICCION DE ACCESO A UNA CASA.
# Fixture `PARITY-HOUSE-ACCESS-001`.
#
# Adaptador NUEVO y SEPARADO. No se toca ningun adaptador ya certificado, ni
# `prueba_casa_cama_vivo.gd`, que pertenece al recorrido de camas que sigue
# BLOQUEADO por `CASAS_CAMAS_SIN_PARTICIPANTE_QA_PREMIUM_CON_CASA`.
#
# Esta rama NO decide PASS/FAIL: lo hace `qa/parity/tools/replay.py` contra la
# `ParityExpectationV1` publicada. Este script solo observa y serializa.
#
# ---------------------------------------------------------------------------
# ESTE FIXTURE NO TOCA CAMAS NI PREMIUM
# ---------------------------------------------------------------------------
#
# El bloqueo de camas nace de `BedItem::canUse` (`servidor/src/bed.cpp:79-102`),
# que exige `isPremium()` y que la cama pertenezca a una casa. El control de
# acceso que mide ESTE fixture vive en otro lado por completo y **no consulta
# premium en ningun momento**:
#
#   `Tile::queryAdd` (`servidor/src/tile.cpp:481-489`):
#
#       if (house) {
#           if (const Player* player = creature->getPlayer()) {
#               if (!house->isInvited(player)) {
#                   return RETURNVALUE_PLAYERISNOTINVITED;
#               }
#           }
#       }
#
# y `House::isInvited` (`house.cpp:307-310`) es simplemente
# `getHouseAccessLevel(player) != HOUSE_NOT_INVITED`, donde el nivel
# (`house.cpp:154-183`) se resuelve por dueno, subdueno o invitado. **Ninguna
# de esas ramas mira `isPremium()`.**
#
# Por eso certificar esto NO resuelve el bloqueo de camas, y este adaptador no
# usa ninguna cama, no concede premium y no asigna ninguna casa.
#
# ---------------------------------------------------------------------------
# EL PROBLEMA REAL: DISTINGUIR EL RECHAZO, NO PROVOCARLO
# ---------------------------------------------------------------------------
#
# Que un jugador no se mueva es un resultado TRIVIAL: lo produciria igual una
# pared, un borde de mapa, una casilla ocupada, una coordenada mal elegida, una
# peticion perdida o una sesion caida. Por eso el fixture no se conforma con
# "no me movi" y exige dos cosas independientes:
#
# 1. CONTROL POSITIVO: inmediatamente antes de medir, el participante hace un
#    desplazamiento ordinario que el SERVIDOR confirma. Eso descarta que la via
#    de movimiento estuviera rota.
#
# 2. LA RESPUESTA ESPECIFICA DE ACCESO. Se verifico en el codigo que
#    `RETURNVALUE_PLAYERISNOTINVITED` tiene exactamente NUEVE productores en
#    todo el servidor, y **todos** son controles de acceso a casas: uso de item
#    en casa (`actions.cpp:280,341`), contenedor en casa
#    (`container.cpp:329,465`), comercio de un item de casa (`game.cpp:2913`),
#    el manejo de ese valor en el camino de movimiento (`game.cpp:960-961`), y
#    los dos de `tile.cpp` (`484` para criaturas, `781` para items).
#
#    Para una accion de MOVIMIENTO el unico origen posible es `tile.cpp:484`.
#    Asi que observar esa respuesta al intentar caminar prueba de una sola vez
#    que la casilla de destino pertenece de verdad a una casa Y que el
#    participante no estaba autorizado, sin publicar el identificador de la
#    casa ni sus listas de acceso.
#
#    Es el mismo patron que el aviso de deposito en Phase 2E: un mensaje que
#    solo puede salir de la rama que nos interesa.
#
# ---------------------------------------------------------------------------
# LA POSICION SE LEE DEL SERVIDOR, NO DE LA PREDICCION LOCAL
# ---------------------------------------------------------------------------
#
# Un cliente puede dibujar un paso que el servidor rechazo. Por eso la
# permanencia afuera se afirma contra `mi_pos`, que el parser de produccion
# mantiene a partir de lo que el servidor confirma, y se exige que sea
# EXACTAMENTE la casilla de partida.
#
# ---------------------------------------------------------------------------
# COMO SE ENCUENTRA EL LIMITE DE LA CASA
# ---------------------------------------------------------------------------
#
# El cliente NO sabe que casillas pertenecen a una casa: esa informacion no
# viaja por el protocolo. Y `entryPosition` de los datos del mundo es, por
# construccion, una casilla FUERA de la casa: `Tile::queryDestination`
# (`tile.cpp:788-812`) manda ahi a los no invitados, y si fuera parte de la
# casa el redireccionamiento seria un bucle.
#
# Entonces el adaptador parte de esa casilla exterior y prueba sus vecinas de a
# una con movimiento ordinario. La vecina que devuelve la respuesta especifica
# de acceso ES el limite de la casa. Probar vecinas es MECANICA DEL HARNESS; lo
# que se afirma es la respuesta autoritativa, no el metodo de busqueda.
#
# ---------------------------------------------------------------------------
# NADA SE MUTA
# ---------------------------------------------------------------------------
#
# 0 cambios de propiedad, 0 listas de invitados o subduenos tocadas, 0 premium,
# 0 camas, 0 items, 0 combate, 0 monstruos. Lo unico que cambia es la posicion
# del propio participante de QA, y el operador solo lo lleva hasta la casilla
# EXTERIOR: nunca lo cruza al otro lado del limite.
#
# ---------------------------------------------------------------------------
# CREDENCIALES: SOLO POR ENTORNO, NUNCA LITERALES, NUNCA IMPRESAS
# ---------------------------------------------------------------------------
#   TVP772_ACCOUNT / _PASSWORD / _PLAYER_CHARACTER   participante (jugador normal)
#   TVP772_GOD_ACCOUNT / _PASSWORD / _CHARACTER      operador, solo posiciona
#   TVP772_HOUSE_ENTRY                               "x,y,z" de la entrada elegida
# Opcionales:
#   TVP772_HOST, TVP772_LOGIN_PORT
#
#   ...Godot --headless --path cliente3d \
#       pruebas/prueba_parity_house_access_capture.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

## Fragmento del mensaje autoritativo de falta de autorizacion
## (`servidor/src/tools.cpp:1073-1074`). Se compara en minusculas y solo como
## DISCRIMINADOR del harness: el texto exacto NO se congela ni entra al payload.
const MARCA_NO_INVITADO := "not invited"

const PAUSA_SESION := 7.0
const ESPERA_PASO := 30.0
const ESPERA_CORTA := 12.0
const LIMITE_TOTAL := 420.0

var _con_login
var _con_god
var _con
var _estado_god
var _estado
var _puerto_god := 0
var _puerto := 0
var _fase := "login"
var _espera := 0.0
var _total := 0.0
var _terminando := false
var _pidio := false

var _cuenta := 0
var _clave := ""
var _nombre := ""
var _cuenta_god := 0
var _clave_god := ""
var _nombre_god := ""
var _host := ""
var _puerto_login := 0
var _entrada := Vector3i.ZERO

## Control positivo.
var _pos_control_inicial := Vector3i.ZERO
var _movimiento_confirmado := false

## Medicion.
var _indice_vecina := 0
var _pos_antes := Vector3i.ZERO
var _denegacion_vista := false
var _intento_real := false
var _quedo_afuera := false
var _sesion_continua := true

var _obs := {}


func _ready() -> void:
	print("=========================================================")
	print(" TVP3D QA - captura en vivo: acceso a una casa")
	print("=========================================================")
	var requeridas := ["TVP772_ACCOUNT", "TVP772_PASSWORD", "TVP772_PLAYER_CHARACTER",
		"TVP772_GOD_ACCOUNT", "TVP772_GOD_PASSWORD", "TVP772_GOD_CHARACTER",
		"TVP772_HOUSE_ENTRY"]
	if not CREDENCIALES.exigir(self, requeridas):
		return
	_host = CREDENCIALES.host()
	_puerto_login = CREDENCIALES.puerto_login()
	_cuenta = CREDENCIALES.entero("TVP772_ACCOUNT")
	_clave = CREDENCIALES.texto("TVP772_PASSWORD")
	_nombre = CREDENCIALES.texto("TVP772_PLAYER_CHARACTER")
	_cuenta_god = CREDENCIALES.entero("TVP772_GOD_ACCOUNT")
	_clave_god = CREDENCIALES.texto("TVP772_GOD_PASSWORD")
	_nombre_god = CREDENCIALES.texto("TVP772_GOD_CHARACTER")
	if _nombre == _nombre_god:
		print("BLOCKED el participante no puede ser el operador: tiene banderas que lo eximen del control de acceso")
		get_tree().quit(2)
		return
	var partes: PackedStringArray = CREDENCIALES.texto("TVP772_HOUSE_ENTRY").split(",")
	if partes.size() != 3:
		print("BLOCKED TVP772_HOUSE_ENTRY debe tener la forma x,y,z")
		get_tree().quit(2)
		return
	_entrada = Vector3i(int(partes[0]), int(partes[1]), int(partes[2]))
	_abrir_login()


func _process(delta: float) -> void:
	_total += delta
	_espera += delta
	if _terminando:
		return
	if _total > LIMITE_TOTAL:
		_fallar("FAIL tiempo agotado en la fase '%s'" % _fase)
		return
	if _estado != null and not _estado.adentro and _fase != "login" and _fase != "esperar participante":
		_sesion_continua = false
	match _fase:
		"esperar god":
			if _estado_god != null and _estado_god.adentro and _espera > 2.0:
				_pasar_a("pausa participante")
		"pausa participante":
			if _espera >= PAUSA_SESION:
				_abrir_participante()
		"esperar participante":
			if _estado != null and _estado.adentro and _espera > 2.0:
				_llevar_a_la_entrada()
		"esperar en la entrada":
			_esperar_en_la_entrada()
		"apartar god":
			_apartar_god()
		"esperar god lejos":
			_esperar_god_lejos()
		"control positivo":
			_control_positivo()
		"volver a la entrada":
			_volver_a_la_entrada()
		"probar vecina":
			_probar_vecina()
		"evaluar vecina":
			_evaluar_vecina()


# -----------------------------------------------------------------
#  Sesiones
# -----------------------------------------------------------------
func _abrir_login() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.error_red.connect(func(t): _fallar("FAIL fallo de red en login del participante: %s" % t))
	_con_login.lista_personajes.connect(func(_m, lista):
		for e in lista:
			if str(e.get("nombre", "")) == _nombre:
				_puerto = int(e.get("puerto", 0))
		if _puerto <= 0:
			_fallar("FAIL character configured by TVP772_PLAYER_CHARACTER was not found")
			return
		_con_login.cerrar()
		_abrir_login_god())
	_con_login.pedir_personajes(_host, _puerto_login, _cuenta, _clave)


func _abrir_login_god() -> void:
	var login = CONEXION.new()
	add_child(login)
	login.error_red.connect(func(t): _fallar("FAIL fallo de red en login del operador: %s" % t))
	login.lista_personajes.connect(func(_m, lista):
		for e in lista:
			if str(e.get("nombre", "")) == _nombre_god:
				_puerto_god = int(e.get("puerto", 0))
		if _puerto_god <= 0:
			_fallar("FAIL character configured by TVP772_GOD_CHARACTER was not found")
			return
		login.cerrar()
		_abrir_god())
	login.pedir_personajes(_host, _puerto_login, _cuenta_god, _clave_god)


func _abrir_god() -> void:
	_estado_god = ESTADO.new()
	_estado_god.pedido_ping.connect(func(): _con_god.enviar_juego(PackedByteArray([0x1E])))
	_estado_god.rechazados.connect(func(m): _fallar("FAIL el operador fue rechazado: %s" % m))
	_con_god = CONEXION.new()
	add_child(_con_god)
	_con_god.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red del operador: %s" % t))
	_con_god.paquete_juego.connect(func(m): _estado_god.procesar(m))
	_con_god.entrar_al_mundo(_host, _puerto_god, _cuenta_god, _nombre_god, _clave_god)
	_pasar_a("esperar god")


func _abrir_participante() -> void:
	_estado = ESTADO.new()
	_estado.pedido_ping.connect(func(): _con.enviar_juego(PackedByteArray([0x1E])))
	_estado.rechazados.connect(func(m): _fallar("FAIL el participante fue rechazado: %s" % m))
	_estado.mensaje_servidor.connect(_al_mensaje)
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red del participante: %s" % t))
	_con.paquete_juego.connect(func(m): _estado.procesar(m))
	_con.entrar_al_mundo(_host, _puerto, _cuenta, _nombre, _clave)
	_pasar_a("esperar participante")


## La respuesta especifica de acceso solo se cuenta DURANTE la medicion. Si se
## contara siempre, un mensaje de otra fase podria dar un falso positivo.
func _al_mensaje(texto: String) -> void:
	print("  [srv] %s" % texto)
	if _fase != "evaluar vecina":
		return
	if texto.to_lower().contains(MARCA_NO_INVITADO):
		_denegacion_vista = true


# -----------------------------------------------------------------
#  Posicionamiento: el operador SOLO lleva a la casilla EXTERIOR
# -----------------------------------------------------------------
func _llevar_a_la_entrada() -> void:
	print("El operador lleva al participante a la casilla EXTERIOR de la entrada.")
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [_entrada.x, _entrada.y, _entrada.z])
	_pasar_a("esperar en la entrada")


func _esperar_en_la_entrada() -> void:
	if _cerca(_estado_god.mi_pos, _entrada, 0):
		if not _pidio:
			_pidio = true
			_con_god.enviar_hablar("/c %s" % _nombre)
			return
		if _cerca(_estado.mi_pos, _entrada, 2):
			_pasar_a("apartar god")
			return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED no se pudo posicionar al participante junto a la entrada de la casa")


func _apartar_god() -> void:
	# El operador se va: no participa de la medicion y no debe estorbar una
	# casilla que el participante necesite.
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
		_entrada.x + 6, _entrada.y + 6, _entrada.z])
	_pasar_a("esperar god lejos")


func _esperar_god_lejos() -> void:
	if not _cerca(_estado_god.mi_pos, _entrada, 3):
		print("El operador se aparto: no participa de la medicion.")
		_pos_control_inicial = _estado.mi_pos
		_pasar_a("control positivo")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el operador no se aparto del area de la casa")


# -----------------------------------------------------------------
#  CONTROL POSITIVO: la via de movimiento funciona
# -----------------------------------------------------------------
## Se prueba con un paso ordinario cuyo exito CONFIRMA el servidor. Sin esto,
## un "no me movi" no significaria nada.
func _control_positivo() -> void:
	if _estado.mi_pos != _pos_control_inicial:
		_movimiento_confirmado = true
		print("Control positivo: el servidor confirmo un desplazamiento ordinario. La via de movimiento funciona.")
		# Unico punto donde se reinicia el indice: aca empieza la medicion.
		_indice_vecina = 0
		_pasar_a("volver a la entrada")
		return
	if not _pidio or _espera > 3.0:
		_pidio = true
		_espera = 0.0
		# Se prueban direcciones hasta que una prospere. Cualquiera sirve: lo
		# que importa es que el servidor confirme UN movimiento.
		var dirs := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
		_con.enviar_auto_camino([dirs[_indice_vecina % dirs.size()]])
		_indice_vecina += 1
		return
	if _indice_vecina > 8:
		_fallar("BLOCKED el participante no pudo dar ningun paso ordinario; sin control positivo la medicion no significa nada")


## Vuelve a la casilla exterior de partida entre intento e intento.
##
## OJO: aca NO se reinicia el indice de vecinas. Reiniciarlo en cada regreso
## hacia que la busqueda repitiera la primera vecina para siempre; el indice
## solo se pone en cero al SALIR del control positivo.
func _volver_a_la_entrada() -> void:
	if _estado.mi_pos == _entrada:
		_pasar_a("probar vecina")
		return
	if not _pidio or _espera > 3.0:
		_pidio = true
		_espera = 0.0
		_caminar_hacia(_entrada)
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED el participante no volvio a la casilla exterior de partida")


# -----------------------------------------------------------------
#  MEDICION
# -----------------------------------------------------------------
## Vecinas de la casilla exterior, en orden fijo. Probar vecinas es MECANICA
## DEL HARNESS: lo que se afirma es la respuesta autoritativa, no el metodo.
func _vecinas() -> Array:
	return [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]


func _probar_vecina() -> void:
	var vecinas := _vecinas()
	if _indice_vecina >= vecinas.size():
		_fallar("BLOCKED ninguna casilla vecina devolvio la respuesta especifica de acceso a casa; esta entrada no sirve como limite medible")
		return
	if _estado.mi_pos != _entrada:
		# Un paso prospero: esa vecina NO era de la casa. Se vuelve y se sigue.
		_indice_vecina += 1
		_pasar_a("volver a la entrada")
		return
	_pos_antes = _estado.mi_pos
	_denegacion_vista = false
	var paso: Vector2i = vecinas[_indice_vecina]
	print("Intento de entrada %d de %d: desplazamiento ordinario hacia una vecina."
		% [_indice_vecina + 1, vecinas.size()])
	_con.enviar_auto_camino([paso])
	_intento_real = true
	_pasar_a("evaluar vecina")


func _evaluar_vecina() -> void:
	if _espera < 2.5:
		return
	if _denegacion_vista:
		# La posicion se lee del SERVIDOR, no de la prediccion local.
		_quedo_afuera = _estado.mi_pos == _pos_antes
		print("Respuesta ESPECIFICA de acceso a casa observada. El participante quedo afuera = %s"
			% str(_quedo_afuera))
		if not _quedo_afuera:
			_fallar("FAIL el servidor nego el acceso pero la posicion autoritativa cambio igual")
			return
		if not _sesion_continua or not _estado.adentro:
			_fallar("BLOCKED la sesion se cayo durante la medicion")
			return
		_construir_observacion()
		_emitir_observacion()
		return
	# Sin denegacion especifica: esa vecina no es limite de casa. Se sigue.
	_indice_vecina += 1
	if _estado.mi_pos != _pos_antes:
		_pasar_a("volver a la entrada")
	else:
		_pasar_a("probar vecina")


# -----------------------------------------------------------------
#  Observacion
# -----------------------------------------------------------------
func _construir_observacion() -> void:
	_obs = {
		"precondition": {
			"ordinary_movement_confirmed": _movimiento_confirmado,
		},
		"access_attempt": {
			"house_access_denial_observed": _intento_real and _denegacion_vista,
			"participant_remained_outside": _quedo_afuera,
			"session_remained_connected": _sesion_continua and _estado.adentro,
		},
	}


func _emitir_observacion() -> void:
	## Ningun nombre, cuenta, identidad de casa, coordenada, opcode, texto de
	## mensaje ni marca de tiempo. Solo relaciones.
	print("OBSERVATION_JSON: " + JSON.stringify(_obs))
	print("Captura de acceso a casa: OK")
	_terminar(0)


# -----------------------------------------------------------------
#  Utilidades
# -----------------------------------------------------------------
func _caminar_hacia(destino: Vector3i) -> void:
	var pasos: Array = []
	var actual: Vector3i = _estado.mi_pos
	var x: int = actual.x
	var y: int = actual.y
	while (x != destino.x or y != destino.y) and pasos.size() < 6:
		var px: int = signi(destino.x - x)
		var py: int = signi(destino.y - y)
		pasos.append(Vector2i(px, py))
		x += px
		y += py
	if pasos.is_empty():
		return
	_con.enviar_auto_camino(pasos)


func _cerca(posicion: Vector3i, centro: Vector3i, radio: int) -> bool:
	return posicion.z == centro.z \
		and absi(posicion.x - centro.x) <= radio \
		and absi(posicion.y - centro.y) <= radio


func _pasar_a(fase: String) -> void:
	print("  [%.0fs] fase: %s" % [_total, fase])
	_fase = fase
	_espera = 0.0
	_pidio = false


func _fallar(texto: String) -> void:
	print(texto)
	_terminar(1)


func _terminar(codigo: int) -> void:
	if _terminando:
		return
	_terminando = true
	if _con != null:
		_con.enviar_logout()
	await get_tree().create_timer(2.0).timeout
	if _con_god != null:
		_con_god.cerrar()
	if _con != null:
		_con.cerrar()
	get_tree().quit(codigo)
