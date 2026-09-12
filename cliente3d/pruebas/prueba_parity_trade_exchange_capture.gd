extends Node

# Captura QA-owned en vivo: INTERCAMBIO AUTORITATIVO ENTRE DOS JUGADORES
# (Phase 2G). Fixture `PARITY-TRADE-EXCHANGE-001`.
#
# Adaptador NUEVO y SEPARADO. `prueba_trade_vip_vivo.gd` es evidencia historica
# de implementacion y **no se toca**. Este adaptador cubre SOLO comercio: no
# ejercita VIP ni afirma nada sobre VIP.
#
# Esta rama NO decide PASS/FAIL: lo hace `qa/parity/tools/replay.py` contra la
# `ParityExpectationV1` publicada. Este script solo observa y serializa.
#
# ---------------------------------------------------------------------------
# QUE PROPIEDAD ES NUEVA, Y QUE NO SE RECLAMA
# ---------------------------------------------------------------------------
#
# Lo nuevo es el INTERCAMBIO AUTORITATIVO DE DOS LADOS: dos jugadores ofrecen,
# los dos ven las dos ofertas, los dos aceptan, y el servidor termina el
# intercambio dejando cada objeto en manos del otro.
#
# Lo que este fixture NO reclama, a proposito: ATOMICIDAD BAJO FALLO, es decir
# la propiedad AMBOS O NINGUNO. Un intercambio exitoso no demuestra que exista
# deshacer. Ver la lectura del codigo mas abajo: el servidor **no tiene un
# rollback transaccional**, sino una VALIDACION PREVIA en seco. Certificar
# AMBOS O NINGUNO exige un fixture negativo dedicado.
#
# ---------------------------------------------------------------------------
# LA REGLA, VERIFICADA EN EL CODIGO VIGENTE DEL ORACLE
# ---------------------------------------------------------------------------
#
# `Game::playerRequestTrade` (`servidor/src/game.cpp:2874-2991`):
#
#   - exige contraparte distinta de uno mismo;
#   - ALCANCE: `Position::areInRange<2, 2, 0>(contraparte, jugador)`, o sea
#     **2 casillas por eje y MISMO PISO** (dz = 0, sin tolerancia de piso, a
#     diferencia de la regla de party que si tolera uno);
#   - exige linea de tiro (`canThrowObjectTo`);
#   - exige que el objeto sea `isPickupable()`, sin `ITEM_ATTRIBUTE_UNIQUEID`
#     y con action id fuera de 1000..2000;
#   - exige que el client id declarado coincida con el real del objeto;
#   - rechaza objetos ya reservados en otro comercio, en los dos sentidos de
#     anidamiento;
#   - rechaza si el jugador ya tiene un comercio abierto.
#
# `Game::internalStartTrade` (`game.cpp:2993-3022`) reserva el objeto en el
# mapa global `tradeItems` con `incrementReferenceCounter()`, y:
#
#   - al PRIMER oferente le manda su propia oferta;
#   - a la contraparte le avisa por texto y la deja en `TRADE_ACKNOWLEDGE`;
#   - cuando la contraparte ofrece a su vez, recien ahi CADA UNO recibe la
#     oferta del otro.
#
# `Game::playerAcceptTrade` (`game.cpp:3024-3135`) es el corazon, y su forma
# real importa para no sobre-reclamar:
#
#   1. solo actua cuando LOS DOS estan en `TRADE_ACCEPT`;
#   2. revalida la linea de tiro en el momento de aceptar;
#   3. libera las reservas de los dos objetos;
#   4. **prueba en seco** con `internalAddItem(..., test = true)` que cada
#      destino puede recibir el objeto del otro;
#   5. solo si las DOS pruebas en seco dan bien, ejecuta los movimientos
#      reales;
#   6. si algo falla, manda un mensaje de cancelacion y dispara
#      `ON_TRADE_CANCEL`, pero **no deshace** un movimiento ya hecho.
#
#   Es decir: la consistencia sale de VALIDAR ANTES, no de deshacer despues.
#   Por eso un exito observado desde el cliente NO puede distinguir un
#   verdadero deshacer de una validacion previa afortunada, y afirmar
#   atomicidad a partir de este fixture seria enganoso.
#
#   Al terminar, con exito o sin el, los dos quedan en `TRADE_NONE` y los dos
#   reciben cierre de ventana (`game.cpp:3126-3134`).
#
# ---------------------------------------------------------------------------
# OPCODES: EL MISMO NUMERO SIGNIFICA COSAS DISTINTAS SEGUN LA DIRECCION
# ---------------------------------------------------------------------------
#
# Verificado en el codigo, y vale la pena escribirlo porque es una trampa:
#
#   ENTRANTE (cliente -> servidor), `protocolgame.cpp:511-513`:
#       0x7D  solicitar comercio
#       0x7E  mirar un objeto dentro de la ventana
#       0x7F  ACEPTAR
#       0x80  cerrar/cancelar
#
#   SALIENTE (servidor -> cliente), `protocolgame.cpp:1465-1509`:
#       0x7D  MI oferta          (`sendTradeItemRequest` con ack = true)
#       0x7E  oferta de la CONTRAPARTE (ack = false)
#       0x7F  CERRAR la ventana  (`sendCloseTrade`)
#
# O sea que 0x7F entrante es "acepto" y 0x7F saliente es "se cerro". Ninguno
# de estos numeros entra al payload: el servidor nativo futuro no tiene por
# que reproducir la numeracion de 7.72.
#
# ---------------------------------------------------------------------------
# SE USA EL TRANSPORTE DE PRODUCCION, NO SE REARMAN BYTES
# ---------------------------------------------------------------------------
#
# La evidencia historica dice que `Conexion772` no exponia la solicitud
# inicial y que QA armaba el payload a mano. **Eso ya no es cierto**: hoy
# `cliente3d/red/conexion772.gd` publica `enviar_solicitar_comercio` y
# `enviar_solicitar_comercio_inventario`, asi que este adaptador usa el metodo
# de produccion y NO duplica el formato del paquete dentro de QA.
#
# ---------------------------------------------------------------------------
# NO SE TOCA EQUIPO AJENO
# ---------------------------------------------------------------------------
#
# El arnes historico "normalizaba las manos" vaciando ranuras. Este NO lo hace.
# Los objetos de prueba se colocan en ranuras que los dos participantes tienen
# VACIAS (cabeza y pies), asi que nada de su equipo preexistente se mueve.
#
# ---------------------------------------------------------------------------
# CREDENCIALES: SOLO POR ENTORNO, NUNCA LITERALES, NUNCA IMPRESAS
# ---------------------------------------------------------------------------
#   TVP772_ACCOUNT / _PASSWORD / _PLAYER_CHARACTER     TRADE_A (jugador normal)
#   TVP772_PLAYER2_ACCOUNT / _PASSWORD / _CHARACTER    TRADE_B (jugador normal)
#   TVP772_GOD_ACCOUNT / _PASSWORD / _CHARACTER        OPERADOR (fuera del trade)
# Opcionales:
#   TVP772_HOST, TVP772_LOGIN_PORT
#
#   ...Godot --headless --path cliente3d \
#       pruebas/prueba_parity_trade_exchange_capture.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

## Area operativa. METADATA DEL HARNESS: nunca entra al payload.
const POS_REUNION := Vector3i(32369, 32241, 7)
const POS_OPERADOR_LEJOS := Vector3i(32360, 32241, 7)

## Ranuras de equipo (`servidor/src/creature.h:17-32`). Se eligen CABEZA y PIES
## porque los dos participantes las tienen VACIAS: asi el objeto de prueba se
## coloca sin desplazar nada de su equipo preexistente.
const SLOT_CABEZA := 1
const SLOT_MOCHILA := 3
const SLOT_PIES := 8

## Alcance de comercio del oracle: `areInRange<2, 2, 0>`. Se usa como CONTROL:
## los participantes se ponen holgadamente adentro y la frontera NO se roza.
const RANGO_TRADE_XY := 2

## Tipos de los dos objetos de prueba. METADATA DEL HARNESS: no entra al
## payload. Se eligieron verificando los datos vigentes del oracle: los dos son
## equipo clasico, movible, NO apilable, NO contenedor, sin carga, sin
## `duration` ni `decayto` -el yelmo de cuero y las botas de cuero no se
## degradan-, livianos, y **ninguno de los dos participantes posee ya uno**, lo
## que evita cualquier ambiguedad de identidad.
const ID_OFERTA_A := 2461
const ID_OFERTA_B := 2643
const NOMBRE_OFERTA_A := "leather helmet"
const NOMBRE_OFERTA_B := "leather boots"

const PAUSA_SESION := 7.0
const ESPERA_PASO := 25.0
const ESPERA_CORTA := 12.0
const ESPERA_ITEM := 12.0
const LIMITE_TOTAL := 600.0

var _con_login
var _con_god
var _con_a
var _con_b
var _estado_god
var _estado_a
var _estado_b
var _puerto_god := 0
var _puerto_a := 0
var _puerto_b := 0
var _fase := "login"
var _espera := 0.0
var _total := 0.0
var _terminando := false
var _pidio := false

var _cuenta_god := 0
var _clave_god := ""
var _nombre_god := ""
var _cuenta_a := 0
var _clave_a := ""
var _nombre_a := ""
var _cuenta_b := 0
var _clave_b := ""
var _nombre_b := ""
var _host := ""
var _puerto_login := 0

var _ids_god := {}
var _ids_a := {}
var _ids_b := {}
var _id_mochila_god := -1
var _id_mochila_a := -1
var _id_mochila_b := -1

## Identidad de proceso de cada objeto de prueba.
var _cid_oferta_a := 0
var _cid_oferta_b := 0
## Id de criatura de cada participante visto por el otro.
var _id_b_visto_por_a := 0

## Hechos normalizados que se congelan.
var _en_rango := false
var _cada_uno_ofrecio := false
var _vieron_las_dos_ofertas := false
var _los_dos_aceptaron := false
var _cerro_en_los_dos := false
var _sin_error := true
var _los_dos_transferidos := false

## Vistas de oferta por sesion.
var _a_vio_propia := false
var _a_vio_contraparte := false
var _b_vio_propia := false
var _b_vio_contraparte := false
var _a_cerro := false
var _b_cerro := false

## Matriz de propiedad, guarda viva NO congelada.
var _base_ok := false
var _final_ok := false

var _obs := {}


func _ready() -> void:
	print("=========================================================")
	print(" TVP3D QA - captura en vivo: intercambio entre jugadores")
	print("=========================================================")
	var requeridas := ["TVP772_ACCOUNT", "TVP772_PASSWORD", "TVP772_PLAYER_CHARACTER",
		"TVP772_PLAYER2_ACCOUNT", "TVP772_PLAYER2_PASSWORD", "TVP772_PLAYER2_CHARACTER",
		"TVP772_GOD_ACCOUNT", "TVP772_GOD_PASSWORD", "TVP772_GOD_CHARACTER"]
	if not CREDENCIALES.exigir(self, requeridas):
		return
	_host = CREDENCIALES.host()
	_puerto_login = CREDENCIALES.puerto_login()
	_cuenta_a = CREDENCIALES.entero("TVP772_ACCOUNT")
	_clave_a = CREDENCIALES.texto("TVP772_PASSWORD")
	_nombre_a = CREDENCIALES.texto("TVP772_PLAYER_CHARACTER")
	_cuenta_b = CREDENCIALES.entero("TVP772_PLAYER2_ACCOUNT")
	_clave_b = CREDENCIALES.texto("TVP772_PLAYER2_PASSWORD")
	_nombre_b = CREDENCIALES.texto("TVP772_PLAYER2_CHARACTER")
	_cuenta_god = CREDENCIALES.entero("TVP772_GOD_ACCOUNT")
	_clave_god = CREDENCIALES.texto("TVP772_GOD_PASSWORD")
	_nombre_god = CREDENCIALES.texto("TVP772_GOD_CHARACTER")
	if _nombre_a == _nombre_b or _nombre_a == _nombre_god or _nombre_b == _nombre_god:
		print("BLOCKED los tres roles tienen que ser personajes distintos")
		get_tree().quit(2)
		return
	if _cuenta_a == _cuenta_b:
		print("BLOCKED los dos participantes necesitan cuentas distintas para tener sesiones simultaneas")
		get_tree().quit(2)
		return
	_abrir_login_a()


func _process(delta: float) -> void:
	_total += delta
	_espera += delta
	if _terminando:
		return
	if _total > LIMITE_TOTAL:
		_fallar("FAIL tiempo agotado en la fase '%s'" % _fase)
		return
	match _fase:
		"esperar god":
			if _estado_god != null and _estado_god.adentro and _espera > 2.0:
				_pasar_a("pausa a")
		"pausa a":
			if _espera >= PAUSA_SESION:
				_abrir_a()
		"esperar a":
			if _estado_a != null and _estado_a.adentro and _espera > 2.0:
				_pasar_a("pausa b")
		"pausa b":
			if _espera >= PAUSA_SESION:
				_abrir_b()
		"esperar b":
			if _estado_b != null and _estado_b.adentro and _espera > 2.0:
				_ir_a_reunion()
		"esperar god reunion":
			if _cerca(_estado_god.mi_pos, POS_REUNION, 1):
				_traer_a()
			elif _espera > ESPERA_CORTA:
				_fallar("BLOCKED el operador no llego al area de reunion")
		"traer a":
			_esperar_cerca(_estado_a, "traer b")
		"traer b":
			_esperar_cerca(_estado_b, "abrir mochilas")
		"abrir mochilas":
			_abrir_mochilas()
		"crear oferta a":
			_crear_oferta(ID_OFERTA_A, NOMBRE_OFERTA_A, "entregar a")
		"entregar a":
			_entregar(_con_a, _estado_a, NOMBRE_OFERTA_A, SLOT_CABEZA, "crear oferta b")
		"crear oferta b":
			_crear_oferta(ID_OFERTA_B, NOMBRE_OFERTA_B, "entregar b")
		"entregar b":
			_entregar(_con_b, _estado_b, NOMBRE_OFERTA_B, SLOT_PIES, "apartar operador")
		"apartar operador":
			_apartar_operador()
		"esperar operador lejos":
			_esperar_operador_lejos()
		"medir base":
			_medir_base()
		"ofrecer a":
			_ofrecer_a()
		"ofrecer b":
			_ofrecer_b()
		"esperar ofertas":
			_esperar_ofertas()
		"aceptar":
			_aceptar()
		"esperar cierre":
			_esperar_cierre()
		"medir final":
			_medir_final()


# -----------------------------------------------------------------
#  Sesiones
# -----------------------------------------------------------------
func _abrir_login_a() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.error_red.connect(func(t): _fallar("FAIL fallo de red en login de A: %s" % t))
	_con_login.lista_personajes.connect(func(_m, lista):
		for e in lista:
			if str(e.get("nombre", "")) == _nombre_a:
				_puerto_a = int(e.get("puerto", 0))
		if _puerto_a <= 0:
			_fallar("FAIL character configured by TVP772_PLAYER_CHARACTER was not found")
			return
		_con_login.cerrar()
		_abrir_login_b())
	_con_login.pedir_personajes(_host, _puerto_login, _cuenta_a, _clave_a)


func _abrir_login_b() -> void:
	var login = CONEXION.new()
	add_child(login)
	login.error_red.connect(func(t): _fallar("FAIL fallo de red en login de B: %s" % t))
	login.lista_personajes.connect(func(_m, lista):
		for e in lista:
			if str(e.get("nombre", "")) == _nombre_b:
				_puerto_b = int(e.get("puerto", 0))
		if _puerto_b <= 0:
			_fallar("FAIL character configured by TVP772_PLAYER2_CHARACTER was not found")
			return
		login.cerrar()
		_abrir_login_god())
	login.pedir_personajes(_host, _puerto_login, _cuenta_b, _clave_b)


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
	_estado_god.contenedor_actualizado.connect(func(id, datos):
		if not _ids_god.has(id):
			_ids_god[id] = str(datos.get("nombre", "")))
	_con_god = CONEXION.new()
	add_child(_con_god)
	_con_god.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red del operador: %s" % t))
	_con_god.paquete_juego.connect(func(m): _estado_god.procesar(m))
	_con_god.entrar_al_mundo(_host, _puerto_god, _cuenta_god, _nombre_god, _clave_god)
	_pasar_a("esperar god")


func _abrir_a() -> void:
	_estado_a = ESTADO.new()
	_estado_a.pedido_ping.connect(func(): _con_a.enviar_juego(PackedByteArray([0x1E])))
	_estado_a.rechazados.connect(func(m): _fallar("FAIL A fue rechazado: %s" % m))
	_estado_a.mensaje_servidor.connect(func(t): _al_mensaje("A", t))
	_estado_a.contenedor_actualizado.connect(func(id, datos):
		if not _ids_a.has(id):
			_ids_a[id] = str(datos.get("nombre", "")))
	_estado_a.comercio_actualizado.connect(func(_n, propio, _items):
		if propio: _a_vio_propia = true
		else: _a_vio_contraparte = true)
	_estado_a.comercio_cerrado.connect(func(): _a_cerro = true)
	_con_a = CONEXION.new()
	add_child(_con_a)
	_con_a.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red de A: %s" % t))
	_con_a.paquete_juego.connect(func(m): _estado_a.procesar(m))
	_con_a.entrar_al_mundo(_host, _puerto_a, _cuenta_a, _nombre_a, _clave_a)
	_pasar_a("esperar a")


func _abrir_b() -> void:
	_estado_b = ESTADO.new()
	_estado_b.pedido_ping.connect(func(): _con_b.enviar_juego(PackedByteArray([0x1E])))
	_estado_b.rechazados.connect(func(m): _fallar("FAIL B fue rechazado: %s" % m))
	_estado_b.mensaje_servidor.connect(func(t): _al_mensaje("B", t))
	_estado_b.contenedor_actualizado.connect(func(id, datos):
		if not _ids_b.has(id):
			_ids_b[id] = str(datos.get("nombre", "")))
	_estado_b.comercio_actualizado.connect(func(_n, propio, _items):
		if propio: _b_vio_propia = true
		else: _b_vio_contraparte = true)
	_estado_b.comercio_cerrado.connect(func(): _b_cerro = true)
	_con_b = CONEXION.new()
	add_child(_con_b)
	_con_b.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red de B: %s" % t))
	_con_b.paquete_juego.connect(func(m): _estado_b.procesar(m))
	_con_b.entrar_al_mundo(_host, _puerto_b, _cuenta_b, _nombre_b, _clave_b)
	_pasar_a("esperar b")


## Solo los mensajes que llegan DURANTE la oferta o la aceptacion cuentan como
## error mecanico de comercio. Los avisos de la preparacion no.
func _al_mensaje(quien: String, texto: String) -> void:
	print("  [%s] %s" % [quien, texto])
	if _fase not in ["ofrecer a", "ofrecer b", "esperar ofertas", "aceptar", "esperar cierre"]:
		return
	var t := texto.to_lower()
	for marca in ["sorry, not possible", "trade cancelled", "not enough room",
			"you cannot", "select a player", "already trading", "too far away",
			"you are not able"]:
		if t.contains(marca):
			_sin_error = false
			print("  ERROR MECANICO DE COMERCIO detectado en la fase '%s'" % _fase)
			return


# -----------------------------------------------------------------
#  Preparacion
# -----------------------------------------------------------------
func _ir_a_reunion() -> void:
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
		POS_REUNION.x, POS_REUNION.y, POS_REUNION.z])
	_pasar_a("esperar god reunion")


func _traer_a() -> void:
	_con_god.enviar_hablar("/c %s" % _nombre_a)
	_pasar_a("traer a")


func _esperar_cerca(estado, siguiente: String) -> void:
	if estado != null and estado.adentro and _cerca(estado.mi_pos, POS_REUNION, 2):
		if siguiente == "traer b":
			_con_god.enviar_hablar("/c %s" % _nombre_b)
		_pasar_a(siguiente)
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED un participante no llego al area de reunion")


func _abrir_mochilas() -> void:
	if _id_mochila_a >= 0 and _id_mochila_b >= 0 and _id_mochila_god >= 0:
		_pasar_a("crear oferta a")
		return
	if not _pidio:
		_pidio = true
		var ma: Dictionary = _estado_a.inventario.get(SLOT_MOCHILA, {})
		var mb: Dictionary = _estado_b.inventario.get(SLOT_MOCHILA, {})
		var mg: Dictionary = _estado_god.inventario.get(SLOT_MOCHILA, {})
		if ma.is_empty() or mb.is_empty() or mg.is_empty():
			_fallar("BLOCKED algun personaje no tiene mochila en la ranura esperada")
			return
		_con_a.enviar_usar_inventario(SLOT_MOCHILA, int(ma.get("cid", 0)))
		_con_b.enviar_usar_inventario(SLOT_MOCHILA, int(mb.get("cid", 0)))
		_con_god.enviar_usar_inventario(SLOT_MOCHILA, int(mg.get("cid", 0)))
		return
	if _id_mochila_a < 0:
		_id_mochila_a = _primer_id(_ids_a)
	if _id_mochila_b < 0:
		_id_mochila_b = _primer_id(_ids_b)
	if _id_mochila_god < 0:
		_id_mochila_god = _primer_id(_ids_god)
	if (_id_mochila_a < 0 or _id_mochila_b < 0 or _id_mochila_god < 0) 			and _espera > ESPERA_CORTA:
		_fallar("BLOCKED no se pudieron abrir las mochilas de los tres personajes")


## El operador crea el objeto y lo apoya en SU PROPIA casilla. No se usa el
## comercio para aprovisionar: seria usar justo el mecanismo que se esta
## midiendo.
func _crear_oferta(id_servidor: int, nombre: String, siguiente: String) -> void:
	if not _pidio:
		_pidio = true
		print("El operador crea un objeto de prueba y lo apoya en el suelo.")
		_con_god.enviar_hablar("/i %d" % id_servidor)
		return
	if _espera < 1.5:
		return
	var pos: Vector3i = _estado_god.mi_pos
	if _stack_por_nombre(_estado_god, pos, nombre) >= 0:
		_pasar_a(siguiente)
		return
	# Todavia esta en poder del operador: se lo baja al suelo. `player:addItem`
	# deja el objeto donde entre, asi que puede haber quedado equipado en una
	# ranura libre o dentro de la mochila; se contemplan los dos casos.
	var slot := _slot_por_nombre(_estado_god, nombre)
	if slot > 0:
		_con_god.enviar_mover_ubicacion(Vector3i(0xFFFF, slot, 0),
			int(_estado_god.inventario[slot].get("cid", 0)), 0, pos)
		_espera = 0.0
		return
	var indice := _indice_por_nombre(_estado_god, _id_mochila_god, nombre)
	if indice >= 0:
		var cosa: Dictionary = _estado_god.contenedores[_id_mochila_god]["items"][indice]
		_con_god.enviar_mover_ubicacion(
			Vector3i(0xFFFF, 0x40 | _id_mochila_god, indice),
			int(cosa.get("cid", 0)), 0, pos)
		_espera = 0.0
		return
	if _espera > ESPERA_ITEM:
		_fallar("BLOCKED el objeto de prueba no llego al suelo del operador")


## El participante lo levanta a una ranura que tiene VACIA. Asi su equipo
## preexistente no se mueve.
func _entregar(con, estado, nombre: String, slot: int, siguiente: String) -> void:
	if int(estado.inventario.get(slot, {}).get("cid", 0)) > 0 \
			and str(estado.inventario[slot].get("nombre", "")).to_lower() == nombre:
		var cid := int(estado.inventario[slot].get("cid", 0))
		if nombre == NOMBRE_OFERTA_A:
			_cid_oferta_a = cid
		else:
			_cid_oferta_b = cid
		print("El participante tomo su objeto de prueba en una ranura que tenia vacia.")
		_pasar_a(siguiente)
		return
	if not _pidio:
		if not estado.inventario.get(slot, {}).is_empty():
			_fallar("BLOCKED la ranura elegida no estaba vacia; no se desplaza equipo ajeno")
			return
		_pidio = true
		var pos: Vector3i = _estado_god.mi_pos
		var pila := _stack_por_nombre(estado, pos, nombre)
		if pila < 0:
			_pidio = false
			if _espera > ESPERA_ITEM:
				_fallar("BLOCKED el participante no ve el objeto de prueba en el suelo")
			return
		var cosa: Dictionary = estado.casillas[pos][pila]
		con.enviar_mover_ubicacion(pos, int(cosa.get("cid", 0)), pila,
			Vector3i(0xFFFF, slot, 0))
		return
	if _espera > ESPERA_ITEM:
		_fallar("BLOCKED el participante no pudo tomar su objeto de prueba")


func _apartar_operador() -> void:
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
		POS_OPERADOR_LEJOS.x, POS_OPERADOR_LEJOS.y, POS_OPERADOR_LEJOS.z])
	_pasar_a("esperar operador lejos")


func _esperar_operador_lejos() -> void:
	if not _cerca(_estado_god.mi_pos, POS_REUNION, 3):
		print("El operador se aparto: queda FUERA del comercio.")
		_pasar_a("medir base")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el operador no se aparto del area del comercio")


# -----------------------------------------------------------------
#  Linea base de propiedad
# -----------------------------------------------------------------
func _medir_base() -> void:
	if _cid_oferta_a == 0 or _cid_oferta_b == 0:
		_fallar("BLOCKED no se establecio la identidad de los dos objetos de prueba")
		return
	var a_tiene_a := _posee(_estado_a, _id_mochila_a, NOMBRE_OFERTA_A)
	var a_tiene_b := _posee(_estado_a, _id_mochila_a, NOMBRE_OFERTA_B)
	var b_tiene_b := _posee(_estado_b, _id_mochila_b, NOMBRE_OFERTA_B)
	var b_tiene_a := _posee(_estado_b, _id_mochila_b, NOMBRE_OFERTA_A)
	print("Linea base de propiedad: A tiene lo suyo=%s y lo del otro=%s; B tiene lo suyo=%s y lo del otro=%s"
		% [str(a_tiene_a), str(a_tiene_b), str(b_tiene_b), str(b_tiene_a)])
	if not (a_tiene_a and b_tiene_b and not a_tiene_b and not b_tiene_a):
		_fallar("BLOCKED la linea base de propiedad es ambigua; no se mide sobre duplicados")
		return
	_base_ok = true
	_cada_uno_ofrecio = true

	# Alcance del oracle: `areInRange<2, 2, 0>`, recalculado sobre las
	# posiciones REALMENTE reportadas por las dos sesiones.
	if not _en_rango_de_trade(_estado_a.mi_pos, _estado_b.mi_pos):
		_fallar("BLOCKED los participantes no estan dentro del alcance de comercio")
		return
	_en_rango = true
	print("Los dos participantes estan holgadamente dentro del alcance de comercio.")
	_pasar_a("ofrecer a")


# -----------------------------------------------------------------
#  Comercio
# -----------------------------------------------------------------
func _ofrecer_a() -> void:
	if _id_b_visto_por_a == 0:
		_id_b_visto_por_a = _id_criatura_por_nombre(_estado_a, _nombre_b)
	if _id_b_visto_por_a == 0:
		if _espera > ESPERA_CORTA:
			_fallar("BLOCKED A no llega a ver a B como criatura para ofrecerle")
		return
	if not _pidio:
		_pidio = true
		print("A inicia el comercio ofreciendo su objeto, con el transporte de produccion.")
		# Metodo de PRODUCCION publicado por `conexion772.gd`. No se rearma el
		# paquete a mano dentro de QA.
		_con_a.enviar_solicitar_comercio_inventario(SLOT_CABEZA, _cid_oferta_a,
			_id_b_visto_por_a)
		return
	if _espera > 2.0:
		_pasar_a("ofrecer b")


func _ofrecer_b() -> void:
	var id_a_visto_por_b := _id_criatura_por_nombre(_estado_b, _nombre_a)
	if id_a_visto_por_b == 0:
		if _espera > ESPERA_CORTA:
			_fallar("BLOCKED B no llega a ver a A como criatura para ofrecerle")
		return
	if not _pidio:
		_pidio = true
		print("B presenta su propio objeto.")
		_con_b.enviar_solicitar_comercio_inventario(SLOT_PIES, _cid_oferta_b,
			id_a_visto_por_b)
		return
	if _espera > 2.0:
		_pasar_a("esperar ofertas")


## No se infiere visibilidad por haber mandado el pedido: se exige que las dos
## sesiones hayan recibido de verdad su oferta propia y la de la contraparte.
func _esperar_ofertas() -> void:
	if _a_vio_propia and _a_vio_contraparte and _b_vio_propia and _b_vio_contraparte:
		_vieron_las_dos_ofertas = true
		print("Las DOS sesiones recibieron su oferta propia y la de la contraparte.")
		_pasar_a("aceptar")
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL alguna sesion no recibio las dos ofertas: A propia=%s contraparte=%s, B propia=%s contraparte=%s"
			% [str(_a_vio_propia), str(_a_vio_contraparte),
				str(_b_vio_propia), str(_b_vio_contraparte)])


func _aceptar() -> void:
	if not _pidio:
		_pidio = true
		print("A acepta.")
		_con_a.enviar_aceptar_comercio()
		return
	if _espera > 1.5:
		print("B acepta.")
		_con_b.enviar_aceptar_comercio()
		_los_dos_aceptaron = true
		_pasar_a("esperar cierre")


func _esperar_cierre() -> void:
	if _a_cerro and _b_cerro:
		_cerro_en_los_dos = true
		print("El servidor cerro la ventana de comercio en las DOS sesiones.")
		_pasar_a("medir final")
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL el comercio no cerro en las dos sesiones: A=%s B=%s"
			% [str(_a_cerro), str(_b_cerro)])


func _medir_final() -> void:
	# Se le da margen a que se asienten las actualizaciones de inventario.
	if _espera < 3.0:
		return
	var a_tiene_a := _posee(_estado_a, _id_mochila_a, NOMBRE_OFERTA_A)
	var a_tiene_b := _posee(_estado_a, _id_mochila_a, NOMBRE_OFERTA_B)
	var b_tiene_b := _posee(_estado_b, _id_mochila_b, NOMBRE_OFERTA_B)
	var b_tiene_a := _posee(_estado_b, _id_mochila_b, NOMBRE_OFERTA_A)
	print("Propiedad final: A conserva lo suyo=%s y recibio lo del otro=%s; B conserva lo suyo=%s y recibio lo del otro=%s"
		% [str(a_tiene_a), str(a_tiene_b), str(b_tiene_b), str(b_tiene_a)])
	var completo: bool = (not a_tiene_a) and a_tiene_b and (not b_tiene_b) and b_tiene_a
	if not completo:
		# Una transferencia a medias es FAIL, no una forma rara de PASS.
		if _espera > ESPERA_PASO:
			_fallar("FAIL el intercambio no dejo los dos objetos cambiados de dueno; una transferencia parcial es FAIL")
		return
	_final_ok = true
	_los_dos_transferidos = true
	if not _sin_error:
		_fallar("FAIL se observo un error mecanico de comercio durante la oferta o la aceptacion")
		return
	print("INTERCAMBIO COMPLETO: cada objeto quedo en manos del otro participante.")
	_construir_observacion()
	_emitir_observacion()


# -----------------------------------------------------------------
#  Observacion
# -----------------------------------------------------------------
func _construir_observacion() -> void:
	_obs = {
		"preconditions": {
			"participants_within_trade_range": _en_rango,
			"each_participant_offered_a_real_item": _cada_uno_ofrecio,
		},
		"offers": {
			"both_participants_saw_own_and_counterpart_offer": _vieron_las_dos_ofertas,
		},
		"completion": {
			"both_participants_accepted": _los_dos_aceptaron,
			"trade_closed_for_both_participants": _cerro_en_los_dos,
			"no_trade_error_observed": _sin_error,
			"both_offered_items_transferred": _los_dos_transferidos,
		},
	}


func _emitir_observacion() -> void:
	## Ningun nombre, cuenta, guid, id de objeto, ranura, coordenada, opcode ni
	## marca de tiempo. Solo relaciones. Nada de VIP.
	print("OBSERVATION_JSON: " + JSON.stringify(_obs))
	print("Captura de intercambio entre jugadores: OK")
	_terminar(0)


# -----------------------------------------------------------------
#  Utilidades
# -----------------------------------------------------------------
## Propiedad = el objeto esta en alguna ranura de equipo O dentro de la mochila
## abierta. Hace falta mirar las dos, porque el servidor entrega lo recibido
## con `INDEX_WHEREEVER` y no necesariamente a una ranura.
func _posee(estado, id_mochila: int, nombre: String) -> bool:
	if _slot_por_nombre(estado, nombre) > 0:
		return true
	return _indice_por_nombre(estado, id_mochila, nombre) >= 0


func _slot_por_nombre(estado, nombre: String) -> int:
	for slot in range(1, 11):
		var cosa: Dictionary = estado.inventario.get(slot, {})
		if str(cosa.get("nombre", "")).to_lower() == nombre:
			return slot
	return 0


func _indice_por_nombre(estado, id_contenedor: int, nombre: String) -> int:
	if estado == null or id_contenedor < 0:
		return -1
	var indice := 0
	for cosa in estado.contenedores.get(id_contenedor, {}).get("items", []):
		if str(cosa.get("nombre", "")).to_lower() == nombre:
			return indice
		indice += 1
	return -1


func _stack_por_nombre(estado, donde: Vector3i, nombre: String) -> int:
	var pila := 0
	for cosa in estado.casillas.get(donde, []):
		if str(cosa.get("nombre", "")).to_lower() == nombre:
			return pila
		pila += 1
	return -1


func _id_criatura_por_nombre(estado, nombre: String) -> int:
	for id in estado.criaturas:
		if int(id) == int(estado.mi_id):
			continue
		if str(estado.criaturas[id].get("nombre", "")) == nombre:
			return int(id)
	return 0


func _primer_id(vistos: Dictionary) -> int:
	for id in vistos:
		return int(id)
	return -1


## `Position::areInRange<2, 2, 0>`: dos casillas por eje y MISMO piso.
func _en_rango_de_trade(a: Vector3i, b: Vector3i) -> bool:
	return absi(a.x - b.x) <= RANGO_TRADE_XY \
		and absi(a.y - b.y) <= RANGO_TRADE_XY \
		and a.z == b.z


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
	if _con_a != null:
		_con_a.enviar_logout()
	if _con_b != null:
		_con_b.enviar_logout()
	await get_tree().create_timer(2.5).timeout
	if _con_god != null:
		_con_god.cerrar()
	if _con_a != null:
		_con_a.cerrar()
	if _con_b != null:
		_con_b.cerrar()
	get_tree().quit(codigo)
