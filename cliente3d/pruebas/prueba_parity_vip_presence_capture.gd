extends Node

# Captura QA-owned en vivo: PRESENCIA EN LA LISTA DE CONTACTOS.
# Fixture `PARITY-VIP-PRESENCE-001`.
#
# Adaptador NUEVO y SEPARADO. `prueba_trade_vip_vivo.gd` es evidencia historica
# y **no se toca**; tampoco se extienden los adaptadores de comercio ya
# certificados.
#
# Esta rama NO decide PASS/FAIL: lo hace `qa/parity/tools/replay.py` contra la
# `ParityExpectationV1` publicada. Este script solo observa y serializa.
#
# ---------------------------------------------------------------------------
# TODO SE AFIRMA DESDE LA SESION DEL OBSERVADOR
# ---------------------------------------------------------------------------
#
# La sesion del OBJETIVO es unicamente el ESTIMULO. Que el objetivo se conecte
# NO es prueba de que el observador se haya enterado. Por eso ninguna asercion
# consulta el estado de la sesion del objetivo: las transiciones se leen de lo
# que el OBSERVADOR realmente recibe, a traves de su propia lista parseada y de
# la senal `vip_actualizado` de SU estado.
#
# ---------------------------------------------------------------------------
# OPCODES: EL MISMO NUMERO SIGNIFICA COSAS DISTINTAS SEGUN LA DIRECCION
# ---------------------------------------------------------------------------
#
# Aca la trampa es MAS filosa que en comercio, y se verifico en el codigo:
#
#   ENTRANTE (cliente -> servidor), `protocolgame.cpp:548-551`:
#       0xD2  pedir OUTFIT      <- NO tiene nada que ver con contactos
#       0xD3  fijar OUTFIT      <- NO tiene nada que ver con contactos
#       0xDC  agregar contacto
#       0xDD  quitar contacto
#
#   SALIENTE (servidor -> cliente), `protocolgame.cpp:2206-2224`:
#       0xD2  entrada de contacto (guid, nombre, estado)
#       0xD3  un contacto se CONECTO
#       0xD4  un contacto se DESCONECTO
#
# O sea que 0xD2 y 0xD3 entrantes son de APARIENCIA y salientes son de
# CONTACTOS. Ninguno de estos numeros entra al payload.
#
# ---------------------------------------------------------------------------
# SE USA EL TRANSPORTE DE PRODUCCION
# ---------------------------------------------------------------------------
#
# `cliente3d/red/conexion772.gd` ya publica `enviar_agregar_vip(nombre)` y
# `enviar_quitar_vip(guid)`, asi que este adaptador los usa y **no rearma
# ningun paquete** dentro de QA.
#
# ---------------------------------------------------------------------------
# LA REGLA, VERIFICADA EN EL CODIGO VIGENTE DEL ORACLE
# ---------------------------------------------------------------------------
#
# `Game::playerRequestAddVip` (`servidor/src/game.cpp:3417-3456`):
#
#   - si el objetivo NO esta conectado, resuelve el nombre con
#     `IOLoginData::getGuidByNameEx(guid, specialVip, formattedName)`, que
#     devuelve la IDENTIDAD REAL del personaje y ademas CANONIZA el nombre;
#     si no existe, contesta que el jugador no existe y no crea nada;
#   - agrega la entrada con `VIPSTATUS_OFFLINE`, o sea que agregar a alguien
#     desconectado es valido y la entrada nace DESCONECTADA;
#   - un personaje con la bandera `SpecialVIP` no puede ser agregado por quien
#     no la tiene. En `servidor/data/XML/groups.xml` esa bandera solo aparece
#     en los grupos elevados, asi que esta captura usa DOS JUGADORES NORMALES
#     y nunca al operador como objetivo.
#
# `Player::addVIP` (`player.cpp:2043-2060`) rechaza si se llega al tope
# (`getMaxVIPEntries`) y rechaza duplicados; recien despues manda la entrada al
# cliente. `getMaxVIPEntries` (`player.cpp:3867-3874`) usa el limite del grupo
# solo si no es 0, y en `groups.xml` los jugadores normales lo tienen en 0, asi
# que caen al limite de `servidor/config.lua`, que es holgado.
#
# LA PROPAGACION DE PRESENCIA, que es lo que hace fuerte a este fixture:
#
#   `Player::addList()`    (`player.cpp:1996-2003`) al conectarse
#   `Player::removeList()` (`player.cpp:1987-1994`) al desconectarse
#
# recorren a TODOS los jugadores conectados y llaman a
# `notifyStatusChange(this, ...)`, que en `player.cpp:2020-2032` hace:
#
#     auto it = VIPList.find(loginPlayer->guid);
#     if (it == VIPList.end()) { return; }
#     client->sendUpdatedVIPStatus(loginPlayer->guid, status);
#
# Es decir que el observador recibe la transicion **solo si la identidad del
# que entra o sale esta en SU lista**. Eso convierte a la transicion en una
# prueba independiente de que el nombre se resolvio al personaje correcto: si
# hubiera resuelto a otro, la busqueda fallaria y no llegaria nada.
#
# ---------------------------------------------------------------------------
# IDENTIDAD RESUELTA, NO ECO DE UN TEXTO
# ---------------------------------------------------------------------------
#
# No alcanza con que aparezca una entrada con el nombre tecleado: eso lo
# produciria cualquier implementacion que devolviera lo que se le mando. Se
# exige que la identidad que trae la entrada sea la del personaje objetivo
# REAL, comparandola contra la identidad esperada que se configura por entorno.
#
# Ese valor es METADATA DEL HARNESS: se usa solo para comparar y **nunca se
# serializa** en la observacion, que se queda con el booleano.
#
# Ademas se comprueba, como guarda viva, que las dos transiciones lleguen para
# ESA MISMA identidad.
#
# ---------------------------------------------------------------------------
# SIN OPERADOR, SIN COMBATE, SIN MOVIMIENTO
# ---------------------------------------------------------------------------
#
# La presencia de contactos no depende de la posicion: `addList`/`removeList`
# recorren a todos los jugadores conectados sin mirar donde estan. Por eso esta
# captura **no usa god/operador**, no mueve a nadie, no pelea y no crea nada.
# Son dos sesiones y nada mas.
#
# ---------------------------------------------------------------------------
# CREDENCIALES: SOLO POR ENTORNO, NUNCA LITERALES, NUNCA IMPRESAS
# ---------------------------------------------------------------------------
#   TVP772_PLAYER2_ACCOUNT / _PASSWORD / _CHARACTER   OBSERVADOR (dueno de la lista)
#   TVP772_ACCOUNT / _PASSWORD / _PLAYER_CHARACTER    OBJETIVO
#   TVP772_VIP_TARGET_ID                              identidad esperada del objetivo
# Opcionales:
#   TVP772_HOST, TVP772_LOGIN_PORT
#
#   ...Godot --headless --path cliente3d \
#       pruebas/prueba_parity_vip_presence_capture.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

## Estados de presencia del protocolo legacy, tal como los normaliza el parser
## de produccion. Son implementacion: no entran al payload.
const PRESENCIA_DESCONECTADO := 0
const PRESENCIA_CONECTADO := 1

const PAUSA_SESION := 7.0
const ESPERA_PASO := 30.0
const ESPERA_CORTA := 15.0
const LIMITE_TOTAL := 420.0

var _con_login
var _con_obs
var _con_obj
var _estado_obs
var _estado_obj
var _puerto_obs := 0
var _puerto_obj := 0
var _fase := "login"
var _espera := 0.0
var _total := 0.0
var _terminando := false
var _pidio := false

var _cuenta_obs := 0
var _clave_obs := ""
var _nombre_obs := ""
var _cuenta_obj := 0
var _clave_obj := ""
var _nombre_obj := ""
var _id_esperada := 0
var _host := ""
var _puerto_login := 0

## Hechos normalizados, TODOS observados desde la sesion del observador.
var _entrada_creada := false
var _identidad_resuelta := false
var _nacio_desconectado := false
var _vio_conexion := false
var _vio_desconexion := false

## Guardas vivas, no congeladas.
var _base_sin_objetivo := false
var _entrada_sobrevive := false
var _transiciones_misma_identidad := true
var _nombre_canonico := false

## Puerta de medicion. Al conectarse, el servidor le manda al observador las
## entradas que YA tenia (`sendVIPEntries`, protocolgame.cpp:1922), y cada una
## dispara la misma senal que una entrada nueva. Sin esta puerta, una entrada
## preexistente se confundiria con la que crea esta captura.
var _midiendo := false
## Se reparo una linea base sucia dejada por una corrida anterior de QA.
var _base_reparada := false

var _obs := {}


func _ready() -> void:
	print("=========================================================")
	print(" TVP3D QA - captura en vivo: presencia de contactos")
	print("=========================================================")
	var requeridas := ["TVP772_PLAYER2_ACCOUNT", "TVP772_PLAYER2_PASSWORD",
		"TVP772_PLAYER2_CHARACTER", "TVP772_ACCOUNT", "TVP772_PASSWORD",
		"TVP772_PLAYER_CHARACTER", "TVP772_VIP_TARGET_ID"]
	if not CREDENCIALES.exigir(self, requeridas):
		return
	_host = CREDENCIALES.host()
	_puerto_login = CREDENCIALES.puerto_login()
	# OBSERVADOR: dueno de la lista de contactos.
	_cuenta_obs = CREDENCIALES.entero("TVP772_PLAYER2_ACCOUNT")
	_clave_obs = CREDENCIALES.texto("TVP772_PLAYER2_PASSWORD")
	_nombre_obs = CREDENCIALES.texto("TVP772_PLAYER2_CHARACTER")
	# OBJETIVO: el que se agrega y despues entra y sale.
	_cuenta_obj = CREDENCIALES.entero("TVP772_ACCOUNT")
	_clave_obj = CREDENCIALES.texto("TVP772_PASSWORD")
	_nombre_obj = CREDENCIALES.texto("TVP772_PLAYER_CHARACTER")
	_id_esperada = CREDENCIALES.entero("TVP772_VIP_TARGET_ID")
	if _nombre_obs == _nombre_obj:
		print("BLOCKED el observador y el objetivo tienen que ser personajes distintos")
		get_tree().quit(2)
		return
	if _cuenta_obs == _cuenta_obj:
		print("BLOCKED observador y objetivo necesitan cuentas distintas para poder solaparse")
		get_tree().quit(2)
		return
	if _id_esperada <= 0:
		print("BLOCKED la identidad esperada del objetivo no es valida")
		get_tree().quit(2)
		return
	_abrir_login_obs()


func _process(delta: float) -> void:
	_total += delta
	_espera += delta
	if _terminando:
		return
	if _total > LIMITE_TOTAL:
		_fallar("FAIL tiempo agotado en la fase '%s'" % _fase)
		return
	match _fase:
		"esperar observador":
			if _estado_obs != null and _estado_obs.adentro and _espera > 3.0:
				_medir_base()
		"reparar base":
			_reparar_base()
		"agregar":
			_agregar()
		"verificar alta":
			_verificar_alta()
		"pausa objetivo":
			if _espera >= PAUSA_SESION:
				_abrir_objetivo()
		"esperar conexion":
			_esperar_conexion()
		"cerrar objetivo":
			_cerrar_objetivo()
		"esperar desconexion":
			_esperar_desconexion()
		"limpiar":
			_limpiar()


# -----------------------------------------------------------------
#  Sesiones
# -----------------------------------------------------------------
func _abrir_login_obs() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.error_red.connect(func(t): _fallar("FAIL fallo de red en login del observador: %s" % t))
	_con_login.lista_personajes.connect(func(_m, lista):
		for e in lista:
			if str(e.get("nombre", "")) == _nombre_obs:
				_puerto_obs = int(e.get("puerto", 0))
		if _puerto_obs <= 0:
			_fallar("FAIL character configured by TVP772_PLAYER2_CHARACTER was not found")
			return
		_con_login.cerrar()
		_abrir_login_obj())
	_con_login.pedir_personajes(_host, _puerto_login, _cuenta_obs, _clave_obs)


func _abrir_login_obj() -> void:
	var login = CONEXION.new()
	add_child(login)
	login.error_red.connect(func(t): _fallar("FAIL fallo de red en login del objetivo: %s" % t))
	login.lista_personajes.connect(func(_m, lista):
		for e in lista:
			if str(e.get("nombre", "")) == _nombre_obj:
				_puerto_obj = int(e.get("puerto", 0))
		if _puerto_obj <= 0:
			_fallar("FAIL character configured by TVP772_PLAYER_CHARACTER was not found")
			return
		login.cerrar()
		_abrir_observador())
	login.pedir_personajes(_host, _puerto_login, _cuenta_obj, _clave_obj)


func _abrir_observador() -> void:
	_estado_obs = ESTADO.new()
	_estado_obs.pedido_ping.connect(func(): _con_obs.enviar_juego(PackedByteArray([0x1E])))
	_estado_obs.rechazados.connect(func(m): _fallar("FAIL el observador fue rechazado: %s" % m))
	_estado_obs.mensaje_servidor.connect(func(t): print("  [obs] %s" % t))
	_estado_obs.vip_actualizado.connect(_al_vip_actualizado)
	_con_obs = CONEXION.new()
	add_child(_con_obs)
	_con_obs.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red del observador: %s" % t))
	_con_obs.paquete_juego.connect(func(m): _estado_obs.procesar(m))
	_con_obs.entrar_al_mundo(_host, _puerto_obs, _cuenta_obs, _nombre_obs, _clave_obs)
	_pasar_a("esperar observador")


## El objetivo se abre RECIEN despues de que el alta quedo verificada: tiene que
## estar desconectado cuando se lo agrega.
func _abrir_objetivo() -> void:
	_estado_obj = ESTADO.new()
	_estado_obj.pedido_ping.connect(func(): _con_obj.enviar_juego(PackedByteArray([0x1E])))
	_estado_obj.rechazados.connect(func(m): _fallar("FAIL el objetivo fue rechazado: %s" % m))
	_con_obj = CONEXION.new()
	add_child(_con_obj)
	_con_obj.error_red.connect(func(t):
		if _fase != "cerrar objetivo" and _fase != "esperar desconexion" and not _terminando:
			_fallar("FAIL fallo de red del objetivo: %s" % t))
	_con_obj.paquete_juego.connect(func(m): _estado_obj.procesar(m))
	_con_obj.entrar_al_mundo(_host, _puerto_obj, _cuenta_obj, _nombre_obj, _clave_obj)
	_pasar_a("esperar conexion")


## UNICA fuente de verdad de este fixture: lo que recibe el OBSERVADOR.
func _al_vip_actualizado(guid: int, entrada: Dictionary) -> void:
	if not _midiendo:
		# Todavia no se pidio el alta: esto es estado preexistente, no el
		# resultado de esta captura.
		return
	var estado := int(entrada.get("estado", -1))
	print("  [obs] contacto actualizado: identidad esperada=%s, presencia=%s"
		% [str(guid == _id_esperada),
			"conectado" if estado == PRESENCIA_CONECTADO else "desconectado"])
	if guid != _id_esperada:
		# Una entrada de otro contacto no debe contaminar la medicion.
		if _entrada_creada:
			_transiciones_misma_identidad = false
		return
	if not _entrada_creada:
		# Recibir la entrada prueba, ademas, que el objetivo no figuraba ya:
		# un alta duplicada no habria emitido nada.
		_entrada_creada = true
		_base_sin_objetivo = true
		_identidad_resuelta = true
		_nacio_desconectado = estado == PRESENCIA_DESCONECTADO
		_nombre_canonico = str(entrada.get("nombre", "")) == _nombre_obj
		return
	# Ya existia la entrada: esto es una TRANSICION de presencia.
	if estado == PRESENCIA_CONECTADO:
		_vio_conexion = true
	elif estado == PRESENCIA_DESCONECTADO and _vio_conexion:
		_vio_desconexion = true


# -----------------------------------------------------------------
#  Recorrido
# -----------------------------------------------------------------
## Linea base: la lista del observador NO debe tener ya al objetivo, o la
## entrada observada podria ser una preexistente.
func _medir_base() -> void:
	if _estado_obs.vip.has(_id_esperada):
		# Residuo de una corrida de QA anterior. Se quita EXACTAMENTE esa
		# entrada con el mecanismo normal de produccion; jamas se vacia la
		# lista ni se toca ningun otro contacto.
		print("Linea base sucia: el objetivo ya figura por un residuo de QA. Se quita SOLO esa entrada.")
		_base_reparada = true
		_pasar_a("reparar base")
		return
	_base_sin_objetivo = true
	print("Linea base: el observador NO tiene al objetivo en su lista. Contactos preexistentes: %d (no se tocan)."
		% _estado_obs.vip.size())
	_pasar_a("agregar")


## Reparacion acotada de la linea base. Solo quita la entrada del objetivo.
##
## LA BAJA ES SILENCIOSA POR DISENO, verificado en el codigo:
## `Game::playerRequestRemoveVip` (`game.cpp:3458-3466`) llama a
## `Player::removeVIP` (`player.cpp:2034-2041`), que borra de la lista y
## **no manda nada al cliente**; no existe ningun opcode saliente de baja. Por
## eso aca NO se espera ninguna confirmacion: esperarla colgaria la fase.
##
## Que la linea base quedo limpia se prueba DESPUES, y de forma autoritativa:
## `Player::addVIP` (`player.cpp:2043-2060`) rechaza los duplicados y en ese
## caso **no emite la entrada**. Asi que recibir una entrada fresca tras el alta
## demuestra que el objetivo NO estaba ya en la lista. Es una prueba mas fuerte
## que mirar el espejo local del cliente.
func _reparar_base() -> void:
	if not _pidio:
		_pidio = true
		_con_obs.enviar_quitar_vip(_id_esperada)
		return
	if _espera > 2.5:
		print("Baja enviada. La limpieza se confirmara por el alta: un duplicado no generaria entrada.")
		_pasar_a("agregar")


func _agregar() -> void:
	if not _pidio:
		_pidio = true
		_midiendo = true
		print("El observador agrega al objetivo indicando SOLO su nombre. El objetivo esta DESCONECTADO.")
		_con_obs.enviar_agregar_vip(_nombre_obj)
		return
	if _espera > 1.0:
		_pasar_a("verificar alta")


func _verificar_alta() -> void:
	if _entrada_creada:
		if not _identidad_resuelta:
			_fallar("FAIL la entrada creada no corresponde a la identidad del objetivo")
			return
		if not _nacio_desconectado:
			_fallar("FAIL la entrada del objetivo no nacio marcada como desconectada")
			return
		print("Alta verificada: entrada creada, identidad resuelta a la esperada y presencia inicial desconectada.")
		print("  guarda viva: el servidor devolvio el nombre canonico = %s" % str(_nombre_canonico))
		_pasar_a("pausa objetivo")
		return
	if _espera > ESPERA_CORTA:
		_fallar("FAIL el servidor no creo la entrada de contacto para el objetivo")


func _esperar_conexion() -> void:
	if _vio_conexion:
		print("El OBSERVADOR recibio la transicion a CONECTADO del objetivo.")
		_pasar_a("cerrar objetivo")
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL el observador no recibio la transicion a conectado; que el objetivo se conecte no alcanza como prueba")


func _cerrar_objetivo() -> void:
	if not _pidio:
		_pidio = true
		print("El objetivo cierra su sesion de forma limpia.")
		_con_obj.enviar_logout()
		return
	if _espera > 1.0:
		_pasar_a("esperar desconexion")


func _esperar_desconexion() -> void:
	if _vio_desconexion:
		print("El OBSERVADOR recibio la transicion a DESCONECTADO del objetivo.")
		_entrada_sobrevive = _estado_obs.vip.has(_id_esperada)
		print("  guarda viva: la entrada sigue en la lista tras el ciclo = %s" % str(_entrada_sobrevive))
		_construir_observacion()
		_pasar_a("limpiar")
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL el observador no recibio la transicion a desconectado")


## Limpieza, FUERA de la medicion: se quita exactamente la entrada que creo esta
## captura, con el mecanismo normal de produccion, para devolver la lista del
## observador a su estado original. NO se toca ningun otro contacto y NO se
## vacia la lista. La baja NO es una asercion de este fixture.
func _limpiar() -> void:
	if not _pidio:
		_pidio = true
		print("Limpieza: se quita SOLO la entrada creada por esta captura.")
		_con_obs.enviar_quitar_vip(_id_esperada)
		return
	if _espera > 2.0:
		print("Entrada de QA retirada de la lista del observador = %s"
			% str(not _estado_obs.vip.has(_id_esperada)))
		_emitir_observacion()


# -----------------------------------------------------------------
#  Observacion
# -----------------------------------------------------------------
func _construir_observacion() -> void:
	_obs = {
		"vip_add": {
			"target_entry_created": _entrada_creada,
			"target_identity_resolved": _identidad_resuelta,
			"target_initially_offline": _nacio_desconectado,
		},
		"presence": {
			"online_transition_observed": _vio_conexion,
			"offline_transition_observed": _vio_desconexion,
		},
	}


func _emitir_observacion() -> void:
	## Ningun nombre, cuenta, identidad concreta, opcode, estado numerico del
	## protocolo, otra entrada de la lista ni marca de tiempo. Solo relaciones.
	print("OBSERVATION_JSON: " + JSON.stringify(_obs))
	print("Captura de presencia de contactos: OK")
	_terminar(0)


# -----------------------------------------------------------------
#  Utilidades
# -----------------------------------------------------------------
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
	if _con_obj != null:
		_con_obj.enviar_logout()
	await get_tree().create_timer(2.0).timeout
	if _con_obs != null:
		_con_obs.cerrar()
	if _con_obj != null:
		_con_obj.cerrar()
	get_tree().quit(codigo)
