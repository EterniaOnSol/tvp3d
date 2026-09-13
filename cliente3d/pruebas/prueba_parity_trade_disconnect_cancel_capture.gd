extends Node

# Captura QA-owned en vivo: CIERRE IMPLICITO POR DESCONEXION.
# Fixture `PARITY-TRADE-DISCONNECT-CANCEL-001`.
#
# Es el NEGATIVO de `PARITY-TRADE-EXCHANGE-001`, que quedo certificado en
# Phase 2G y **no se toca**. Adaptador NUEVO y SEPARADO; tampoco se toca
# `prueba_trade_vip_vivo.gd`, que es evidencia historica.
#
# Esta rama NO decide PASS/FAIL: lo hace `qa/parity/tools/replay.py` contra la
# `ParityExpectationV1` publicada. Este script solo observa y serializa.
#
# ---------------------------------------------------------------------------
# QUE PRUEBA, Y POR QUE EL CONTROL ES LO QUE LO HACE HONESTO
# ---------------------------------------------------------------------------
#
# Prueba que cortar el socket de juego de A, sin logout, aceptacion ni
# cancelacion explicita, hace que el servidor cierre el comercio para B y no
# mueve ningun objeto. A se reconecta para comprobar propiedad persistida.
#
# La parte delicada: "no se movio nada" es una afirmacion **trivialmente
# cierta** si el comercio nunca llego a abrirse. Tambien se cumpliria si el
# alcance hubiera fallado, si el objeto hubiera sido rechazado o si el pedido
# no hubiera llegado. Por eso el control es obligatorio: se exige que las DOS
# sesiones hayan recibido su oferta propia **y** la de la contraparte antes de
# cancelar nada. Sin ese control este fixture no probaria absolutamente nada.
#
# ---------------------------------------------------------------------------
# LA REGLA, VERIFICADA EN EL CODIGO VIGENTE DEL ORACLE
# ---------------------------------------------------------------------------
#
# `Conexion772.cerrar()` solo llama `StreamPeerTCP.disconnect_from_host()`.
# El error de lectura llega a `Connection::close(FORCE_CLOSE)`, libera
# `ProtocolGame` y deja `Player::client` vacio. `Player::sendPing()` detecta la
# conexion perdida y agenda la baja; `Player::onRemoveCreature()` llama a
# `internalCloseTrade(this)` antes de `IOLoginData::savePlayer(this)`.
#
# `Game::internalCloseTrade` (`game.cpp:3214-3260`) es **simetrico**: actua
# sobre el que cancela Y sobre su contraparte. Para cada uno de los dos:
#
#   - libera la reserva del objeto en el mapa global `tradeItems`;
#   - dispara `ON_TRADE_CANCEL` sobre el objeto;
#   - pone `tradeItem` y `tradePartner` en null y el estado en `TRADE_NONE`;
#   - manda el aviso de cancelacion;
#   - manda el cierre de la ventana.
#
# O sea que **alcanza con que uno cancele** para que los dos queden cerrados.
# En ningun punto se mueve un objeto: la funcion solo libera reservas.
#
# GUARDA IMPORTANTE, y es la razon por la que este fixture NO certifica
# AMBOS O NINGUNO ante un fallo de transferencia:
#
#     if ((tradePartner && tradePartner->getTradeState() == TRADE_TRANSFER)
#             || player->getTradeState() == TRADE_TRANSFER) {
#         return;
#     }
#
# El servidor **se niega a cancelar** si alguno de los dos ya esta
# transfiriendo. Es decir que en la cancelacion explicita **nunca hay una
# transferencia en curso que revertir**, asi que este camino no demuestra nada
# sobre deshacer. Son propiedades distintas y se declaran por separado.
#
# ---------------------------------------------------------------------------
# QUIEN CANCELA
# ---------------------------------------------------------------------------
#
# Se desconecta A, que inicia el comercio. B queda conectado y solo observa el
# cierre autoritativo `0x7F`; ninguno acepta ni envia `0x80`.
#
# ---------------------------------------------------------------------------
# NO SE CREA NI SE MUEVE NINGUN OBJETO
# ---------------------------------------------------------------------------
#
# `test_items_created = 0`. Los dos participantes YA poseen un objeto propio y
# distinguible del otro, asi que no hace falta crear nada ni desplazar equipo.
# Y como una cancelacion correcta **no transfiere**, al terminar el entorno
# queda exactamente como estaba: este es el unico fixture del corpus cuyo
# resultado correcto es **cero mutacion**.
#
# ---------------------------------------------------------------------------
# CREDENCIALES: SOLO POR ENTORNO, NUNCA LITERALES, NUNCA IMPRESAS
# ---------------------------------------------------------------------------
#   TVP772_ACCOUNT / _PASSWORD / _PLAYER_CHARACTER     TRADE_A (inicia)
#   TVP772_PLAYER2_ACCOUNT / _PASSWORD / _CHARACTER    TRADE_B (cancela)
#   TVP772_GOD_ACCOUNT / _PASSWORD / _CHARACTER        OPERADOR (fuera)
# Opcionales:
#   TVP772_HOST, TVP772_LOGIN_PORT
#   TVP772_TRADE_ITEM_A / TVP772_TRADE_ITEM_B  nombres de los objetos propios
#
#   ...Godot --headless --path cliente3d \
#       pruebas/prueba_parity_trade_disconnect_cancel_capture.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

## Area operativa. METADATA DEL HARNESS: nunca entra al payload.
const POS_REUNION := Vector3i(32369, 32241, 7)
const POS_OPERADOR_LEJOS := Vector3i(32360, 32241, 7)

## Ranuras de equipo (`servidor/src/creature.h:17-32`).
const SLOT_MOCHILA := 3

## Alcance de comercio del oracle: `areInRange<2, 2, 0>`. CONTROL, no variable.
const RANGO_TRADE_XY := 2

const PAUSA_SESION := 7.0
const PAUSA_RECONEXION := 3.0
const ESPERA_PASO := 25.0
const ESPERA_CORTA := 12.0
const LIMITE_TOTAL := 480.0

var _con_login
var _con_god
var _con_a
var _con_b
var _con_login_a_re
var _con_a_re
var _estado_god
var _estado_a
var _estado_b
var _estado_a_re
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

## Nombres de los objetos propios de cada participante. METADATA DEL HARNESS.
var _objeto_a := ""
var _objeto_b := ""

var _ids_a := {}
var _ids_b := {}
var _id_mochila_a := -1
var _id_mochila_b := -1
var _id_mochila_a_re := -1
var _ids_a_re := {}
var _slot_a := 0
var _slot_b := 0
var _cid_a := 0
var _cid_b := 0
var _origen_a := Vector3i.ZERO
var _origen_b := Vector3i.ZERO
var _stack_a := 0
var _stack_b := 0

## Hechos normalizados.
var _en_rango := false
var _cada_uno_ofrecio := false
var _vieron_las_dos_ofertas := false
var _aceptaciones_enviadas := 0
var _cancelaciones_explicitas_enviadas := 0
var _conexion_a_cerrada := false
var _cierre_b_autoritativo_e_inactivo := false
var _sin_transferencia := false
var _trade_viejo_no_restaurado := false

var _a_vio_propia := false
var _a_vio_contraparte := false
var _b_vio_propia := false
var _b_vio_contraparte := false
var _a_cerro := false
var _b_cerro := false
var _desconexion_a_intencional := false

var _obs := {}


func _ready() -> void:
	print("=========================================================")
	print(" TVP3D QA - captura en vivo: cierre de trade por desconexion")
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
	var oa := CREDENCIALES.texto("TVP772_TRADE_ITEM_A")
	if not oa.is_empty():
		_objeto_a = oa.to_lower()
	var ob := CREDENCIALES.texto("TVP772_TRADE_ITEM_B")
	if not ob.is_empty():
		_objeto_b = ob.to_lower()
	if _nombre_a == _nombre_b or _nombre_a == _nombre_god or _nombre_b == _nombre_god:
		print("BLOCKED los tres roles tienen que ser personajes distintos")
		get_tree().quit(2)
		return
	if _cuenta_a == _cuenta_b:
		print("BLOCKED los dos participantes necesitan cuentas distintas")
		get_tree().quit(2)
		return
	if not _objeto_a.is_empty() and _objeto_a == _objeto_b:
		print("BLOCKED los dos objetos ofrecidos tienen que ser distinguibles entre si")
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
		"desconectar a":
			_desconectar_a()
		"esperar cierre b":
			_esperar_cierre_b()
		"pausa reconexion a":
			if _espera >= PAUSA_RECONEXION:
				_abrir_login_a_re()
		"esperar a reconectado":
			if _estado_a_re != null and _estado_a_re.adentro and _espera > 2.0:
				_pasar_a("abrir mochila a reconectado")
		"abrir mochila a reconectado":
			_abrir_mochila_a_re()
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
	_estado_a.mensaje_servidor.connect(func(t): print("  [A] %s" % t))
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
		if not _terminando and not _desconexion_a_intencional:
			_fallar("FAIL fallo de red de A antes de la desconexion medida: %s" % t))
	_con_a.paquete_juego.connect(func(m): _estado_a.procesar(m))
	_con_a.entrar_al_mundo(_host, _puerto_a, _cuenta_a, _nombre_a, _clave_a)
	_pasar_a("esperar a")


func _abrir_b() -> void:
	_estado_b = ESTADO.new()
	_estado_b.pedido_ping.connect(func(): _con_b.enviar_juego(PackedByteArray([0x1E])))
	_estado_b.rechazados.connect(func(m): _fallar("FAIL B fue rechazado: %s" % m))
	_estado_b.mensaje_servidor.connect(func(t): print("  [B] %s" % t))
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


## Reconexion NUEVA, iniciada solo despues de que B recibio el cierre
## autoritativo. Nunca se reutiliza el socket cerrado.
func _abrir_login_a_re() -> void:
	if _pidio:
		return
	_pidio = true
	_con_login_a_re = CONEXION.new()
	add_child(_con_login_a_re)
	_con_login_a_re.error_red.connect(func(t):
		_fallar("FAIL fallo de red en login de reconexion de A: %s" % t))
	_con_login_a_re.lista_personajes.connect(func(_m, lista):
		var puerto := 0
		for e in lista:
			if str(e.get("nombre", "")) == _nombre_a:
				puerto = int(e.get("puerto", 0))
		if puerto <= 0:
			_fallar("FAIL A no aparecio en la lista al reconectar")
			return
		_con_login_a_re.cerrar()
		_abrir_a_re(puerto))
	_con_login_a_re.pedir_personajes(
		_host, _puerto_login, _cuenta_a, _clave_a)


func _abrir_a_re(puerto: int) -> void:
	_estado_a_re = ESTADO.new()
	_estado_a_re.pedido_ping.connect(
		func(): _con_a_re.enviar_juego(PackedByteArray([0x1E])))
	_estado_a_re.rechazados.connect(
		func(m): _fallar("FAIL A fue rechazado al reconectar: %s" % m))
	_estado_a_re.mensaje_servidor.connect(func(t): print("  [A-re] %s" % t))
	_estado_a_re.contenedor_actualizado.connect(func(id, datos):
		if not _ids_a_re.has(id):
			_ids_a_re[id] = str(datos.get("nombre", "")))
	_con_a_re = CONEXION.new()
	add_child(_con_a_re)
	_con_a_re.error_red.connect(func(t):
		if not _terminando:
			_fallar("FAIL fallo de red de A reconectado: %s" % t))
	_con_a_re.paquete_juego.connect(func(m): _estado_a_re.procesar(m))
	_con_a_re.entrar_al_mundo(
		_host, puerto, _cuenta_a, _nombre_a, _clave_a)
	_pasar_a("esperar a reconectado")


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
	if _id_mochila_a >= 0 and _id_mochila_b >= 0:
		_pasar_a("apartar operador")
		return
	if not _pidio:
		_pidio = true
		var ma: Dictionary = _estado_a.inventario.get(SLOT_MOCHILA, {})
		var mb: Dictionary = _estado_b.inventario.get(SLOT_MOCHILA, {})
		if ma.is_empty() or mb.is_empty():
			_fallar("BLOCKED algun participante no tiene mochila en la ranura esperada")
			return
		_con_a.enviar_usar_inventario(SLOT_MOCHILA, int(ma.get("cid", 0)))
		_con_b.enviar_usar_inventario(SLOT_MOCHILA, int(mb.get("cid", 0)))
		return
	if _id_mochila_a < 0:
		_id_mochila_a = _primer_id(_ids_a)
	if _id_mochila_b < 0:
		_id_mochila_b = _primer_id(_ids_b)
	if (_id_mochila_a < 0 or _id_mochila_b < 0) and _espera > ESPERA_CORTA:
		_fallar("BLOCKED no se pudieron abrir las mochilas de los dos participantes")


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
#  Linea base
# -----------------------------------------------------------------
## No se crea ni se mueve nada: cada participante YA tiene su objeto propio, y
## se exige que ninguno tenga el del otro para que la identidad no sea ambigua.
func _medir_base() -> void:
	var elegidos := false
	for ca in _candidatos_propios(_estado_a, _id_mochila_a, _objeto_a):
		for cb in _candidatos_propios(_estado_b, _id_mochila_b, _objeto_b):
			var na := str(ca.get("nombre", ""))
			var nb := str(cb.get("nombre", ""))
			if na == nb:
				continue
			if _posee(_estado_a, _id_mochila_a, nb):
				continue
			if _posee(_estado_b, _id_mochila_b, na):
				continue
			_objeto_a = na
			_objeto_b = nb
			_slot_a = int(ca.get("slot", 0))
			_slot_b = int(cb.get("slot", 0))
			_cid_a = int(ca.get("cid", 0))
			_cid_b = int(cb.get("cid", 0))
			_origen_a = ca.get("origen", Vector3i.ZERO)
			_origen_b = cb.get("origen", Vector3i.ZERO)
			_stack_a = int(ca.get("stackpos", 0))
			_stack_b = int(cb.get("stackpos", 0))
			elegidos = true
			break
		if elegidos:
			break
	if not elegidos:
		_fallar("BLOCKED no existe un par de objetos de equipo seguro, distinguible y con propiedad basal no ambigua")
		return
	var a_tiene_b := _posee(_estado_a, _id_mochila_a, _objeto_b)
	var b_tiene_a := _posee(_estado_b, _id_mochila_b, _objeto_a)
	print("Objetos QA existentes elegidos: A='%s', B='%s'. Creados=0."
		% [_objeto_a, _objeto_b])
	print("Linea base: A tiene lo suyo=true y lo del otro=%s; B tiene lo suyo=true y lo del otro=%s"
		% [str(a_tiene_b), str(b_tiene_a)])
	if a_tiene_b or b_tiene_a:
		_fallar("BLOCKED la linea base de propiedad es ambigua; no se mide sobre duplicados")
		return
	_cada_uno_ofrecio = true
	if not _en_rango_de_trade(_estado_a.mi_pos, _estado_b.mi_pos):
		_fallar("BLOCKED los participantes no estan dentro del alcance de comercio")
		return
	_en_rango = true
	print("Los dos participantes estan holgadamente dentro del alcance de comercio.")
	_pasar_a("ofrecer a")


# -----------------------------------------------------------------
#  Comercio y desconexion
# -----------------------------------------------------------------
func _ofrecer_a() -> void:
	var id_b := _id_criatura_por_nombre(_estado_a, _nombre_b)
	if id_b == 0:
		if _espera > ESPERA_CORTA:
			_fallar("BLOCKED A no llega a ver a B como criatura para ofrecerle")
		return
	if not _pidio:
		_pidio = true
		print("A INICIA el comercio ofreciendo su objeto, con el transporte de produccion.")
		_con_a.enviar_solicitar_comercio(
			_origen_a, _cid_a, _stack_a, id_b)
		return
	if _espera > 2.0:
		_pasar_a("ofrecer b")


func _ofrecer_b() -> void:
	var id_a := _id_criatura_por_nombre(_estado_b, _nombre_a)
	if id_a == 0:
		if _espera > ESPERA_CORTA:
			_fallar("BLOCKED B no llega a ver a A como criatura para ofrecerle")
		return
	if not _pidio:
		_pidio = true
		print("B presenta su propio objeto.")
		_con_b.enviar_solicitar_comercio(
			_origen_b, _cid_b, _stack_b, id_a)
		return
	if _espera > 2.0:
		_pasar_a("esperar ofertas")


## CONTROL OBLIGATORIO: sin esto, "no se movio nada" seria trivialmente cierto.
func _esperar_ofertas() -> void:
	if _a_vio_propia and _a_vio_contraparte and _b_vio_propia and _b_vio_contraparte:
		_vieron_las_dos_ofertas = true
		print("CONTROL establecido: el comercio quedo EFECTIVAMENTE ABIERTO y las dos sesiones ven las dos ofertas.")
		_pasar_a("desconectar a")
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL el comercio no llego a abrirse del todo: A propia=%s contraparte=%s, B propia=%s contraparte=%s"
			% [str(_a_vio_propia), str(_a_vio_contraparte),
				str(_b_vio_propia), str(_b_vio_contraparte)])


## ACCION MEDIDA. La unica operacion sobre la sesion original de A es
## `Conexion772.cerrar()`: el metodo auditado corta el TCP y no serializa ni
## logout, ni aceptacion, ni cancelacion de comercio.
func _desconectar_a() -> void:
	if _a_cerro or _b_cerro:
		_fallar("FAIL el comercio se cerro antes de la desconexion")
		return
	if _aceptaciones_enviadas != 0 or _cancelaciones_explicitas_enviadas != 0:
		_fallar("FAIL el harness registro una aceptacion o cancelacion explicita")
		return
	_desconexion_a_intencional = true
	print("A corta SOLO su socket de juego; no envia otra accion de gameplay.")
	_con_a.cerrar()
	_conexion_a_cerrada = true
	_pasar_a("esperar cierre b")


func _esperar_cierre_b() -> void:
	if _b_cerro and not bool(_estado_b.comercio.get("activo", false)):
		_cierre_b_autoritativo_e_inactivo = true
		print("B recibio el cierre autoritativo y quedo sin trade activo.")
		_pasar_a("pausa reconexion a")
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL B no recibio el cierre autoritativo tras desconectar A")


func _abrir_mochila_a_re() -> void:
	if _id_mochila_a_re >= 0:
		_pasar_a("medir final")
		return
	if not _pidio:
		_pidio = true
		var mochila: Dictionary = _estado_a_re.inventario.get(SLOT_MOCHILA, {})
		if mochila.is_empty():
			_fallar("BLOCKED A reconectado no tiene mochila medible")
			return
		_con_a_re.enviar_usar_inventario(
			SLOT_MOCHILA, int(mochila.get("cid", 0)))
		return
	_id_mochila_a_re = _primer_id(_ids_a_re)
	if _id_mochila_a_re >= 0:
		_pasar_a("medir final")
	elif _espera > ESPERA_CORTA:
		_fallar("BLOCKED no se pudo abrir la mochila de A reconectado")


func _medir_final() -> void:
	# Se le da margen a que se asienten eventuales actualizaciones de inventario.
	if _espera < 3.0:
		return
	var a_tiene_a := _posee(_estado_a_re, _id_mochila_a_re, _objeto_a)
	var a_tiene_b := _posee(_estado_a_re, _id_mochila_a_re, _objeto_b)
	var b_tiene_b := _posee(_estado_b, _id_mochila_b, _objeto_b)
	var b_tiene_a := _posee(_estado_b, _id_mochila_b, _objeto_a)
	_trade_viejo_no_restaurado = not bool(
		_estado_a_re.comercio.get("activo", false))
	print("Propiedad tras reconexion: A conserva lo suyo=%s y NO tiene lo del otro=%s; B conserva lo suyo=%s y NO tiene lo del otro=%s"
		% [str(a_tiene_a), str(not a_tiene_b), str(b_tiene_b), str(not b_tiene_a)])
	_sin_transferencia = a_tiene_a and b_tiene_b and not a_tiene_b and not b_tiene_a
	if not _sin_transferencia:
		_fallar("FAIL la desconexion movio algun objeto")
		return
	if not _trade_viejo_no_restaurado:
		_fallar("FAIL la sesion reconectada de A restauro el trade viejo")
		return
	print("CIERRE IMPLICITO LIMPIO: propiedad intacta y trade viejo ausente.")
	_construir_observacion()
	_emitir_observacion()


# -----------------------------------------------------------------
#  Observacion
# -----------------------------------------------------------------
func _construir_observacion() -> void:
	_obs = {
		"open_trade": {
			"participants_within_trade_range": _en_rango,
			"each_participant_offered_a_real_item": _cada_uno_ofrecio,
			"both_participants_saw_own_and_counterpart_offer": _vieron_las_dos_ofertas,
			"no_acceptance_or_explicit_cancel_sent":
				_aceptaciones_enviadas == 0
				and _cancelaciones_explicitas_enviadas == 0,
		},
		"disconnect_cleanup": {
			"production_game_socket_closed_without_gameplay_request":
				_conexion_a_cerrada
				and _aceptaciones_enviadas == 0
				and _cancelaciones_explicitas_enviadas == 0,
			"survivor_authoritative_close_left_trade_inactive":
				_cierre_b_autoritativo_e_inactivo,
		},
		"no_transfer": {
			"offered_items_kept_original_owners_after_reconnect":
				_sin_transferencia,
			"disconnected_participant_old_trade_not_restored":
				_trade_viejo_no_restaurado,
		},
	}


func _emitir_observacion() -> void:
	## Ningun nombre, cuenta, guid, id de objeto, ranura, coordenada, opcode ni
	## marca de tiempo. Tampoco cual de los dos cancelo. Solo relaciones.
	print("OBSERVATION_JSON: " + JSON.stringify(_obs))
	print("Captura de cierre de comercio por desconexion: OK")
	_terminar(0)


# -----------------------------------------------------------------
#  Utilidades
# -----------------------------------------------------------------
func _posee(estado, id_mochila: int, nombre: String) -> bool:
	if _slot_por_nombre(estado, nombre) > 0:
		return true
	return _indice_por_nombre(estado, id_mochila, nombre) >= 0


func _candidatos_propios(estado, id_mochila: int,
		nombre_requerido: String) -> Array:
	var resultado: Array = []
	for slot in range(1, 11):
		var cosa: Dictionary = estado.inventario.get(slot, {})
		if cosa.is_empty():
			continue
		var nombre := str(cosa.get("nombre", "")).to_lower()
		if not nombre_requerido.is_empty() and nombre != nombre_requerido:
			continue
		if not bool(cosa.get("levantable", false)):
			continue
		if bool(cosa.get("contenedor", false)):
			continue
		resultado.append({
			"slot": slot,
			"cid": int(cosa.get("cid", 0)),
			"nombre": nombre,
			"origen": Vector3i(0xFFFF, slot, 0),
			"stackpos": 0,
		})
	var indice := 0
	for cosa in estado.contenedores.get(id_mochila, {}).get("items", []):
		var nombre := str(cosa.get("nombre", "")).to_lower()
		if not nombre_requerido.is_empty() and nombre != nombre_requerido:
			indice += 1
			continue
		if bool(cosa.get("levantable", false)) and not bool(
				cosa.get("contenedor", false)):
			resultado.append({
				"slot": 0,
				"cid": int(cosa.get("cid", 0)),
				"nombre": nombre,
				"origen": Vector3i(0xFFFF, 0x40 | id_mochila, indice),
				"stackpos": 0,
			})
		indice += 1
	return resultado


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
	# La sesion ORIGINAL de A nunca recibe otra llamada de gameplay despues de
	# cerrar su socket. Solo se cierran ordenadamente B, el operador y, si
	# existe, la NUEVA sesion de A.
	for c in [_con_b, _con_a_re, _con_god]:
		if c != null:
			c.enviar_logout()
	await get_tree().create_timer(2.5).timeout
	for c in [_con_login, _con_login_a_re, _con_god, _con_a, _con_b, _con_a_re]:
		if c != null:
			c.cerrar()
	print("EXITCODE=%d" % codigo)
	get_tree().quit(codigo)
