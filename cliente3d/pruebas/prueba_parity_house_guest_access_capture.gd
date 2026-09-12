extends Node

# ---------------------------------------------------------------------------
# TVP3D QA - CAPTURA EN VIVO: ACCESO POR LISTA DE INVITADOS
# `PARITY-HOUSE-GUEST-ACCESS-001`
# ---------------------------------------------------------------------------
#
# Mide UNA comparacion A/B sobre el MISMO jugador B y la MISMA casilla limite,
# mientras el jugador A es dueno de la casa:
#
#   B fuera de la lista  ->  el servidor le NIEGA la entrada
#   B en la lista        ->  el servidor se la PERMITE
#
# La comparacion ES el fixture. Lo unico que cambia entre las dos mediciones es
# la pertenencia de B a la lista de invitados; el jugador, la casilla, el
# camino, el dueno y el estado de la puerta quedan fijos.
#
# La mitad negativa cumple ademas de control de EXCLUSIVIDAD DEL DUENO: A es
# dueno y B, otro jugador normal, no puede entrar. Eso cierra la limitacion que
# `PARITY-HOUSE-OWNER-ACCESS-001` habia declarado, sin gastar un segundo
# fixture ni un segundo ciclo de propiedad.
#
# ---------------------------------------------------------------------------
# PRESUPUESTO DE UNA SOLA ASIGNACION
# ---------------------------------------------------------------------------
#
# `/owner` crea una carta de bienvenida en el deposito del nuevo dueno
# (`House::setOwner`, house.cpp:104-131) y no hay forma de desactivarlo por esa
# via. Este turno tiene autorizado EXACTAMENTE UN uso, asi que el adaptador
# valida todo lo que puede ANTES de mutar:
#
#   * las tres sesiones conectan;
#   * la casilla del limite es de la casa de sandbox esperada;
#   * la puerta esta cerrada y se puede abrir;
#   * B se posiciona y el servidor le CONFIRMA un paso ordinario;
#   * B recibe la denegacion especifica con la casa todavia SIN DUENO.
#
# Ese ultimo paso es un ENSAYO sin mutar nada que ejercita el mismo camino de
# medicion que despues se usa en serio. Si algo del arnes esta roto, se
# descubre con CERO mutaciones y sin gastar el presupuesto.
#
# ---------------------------------------------------------------------------
# LA RESTAURACION ES SEGURA POR CONSTRUCCION
# ---------------------------------------------------------------------------
#
# `House::setOwner` llama `setAccessList(GUEST_LIST, "")` de forma
# incondicional (house.cpp:69-72). Es decir que `/owner none` **por si solo**
# deja la lista de invitados vacia, que es exactamente la linea base.
#
# Igual se restaura por la via normal, con una ventana nueva y el texto base
# exacto, porque es lo que corresponde probar; pero ante cualquier fallo el
# camino de emergencia (`/owner none` + cerrar la puerta) es suficiente y no
# depende de que el flujo de edicion funcione.
#
# ---------------------------------------------------------------------------
# LA VENTANA DE EDICION ES DE UN SOLO USO
# ---------------------------------------------------------------------------
#
# `Game::playerUpdateHouseWindow` (game.cpp:2841-2872) termina SIEMPRE con
# `player->setEditHouse(nullptr)`, haya aplicado el cambio o no. Y
# `Player::setEditHouse` (player.cpp:868-873) incrementa `windowTextId` en cada
# apertura, que es el valor que el servidor exige que se le devuelva.
#
# Por eso CADA edicion abre su propia ventana, usa SU id y lo descarta. Nunca
# se reutiliza un id, nunca se manda dos veces sobre la misma ventana y nunca
# se adivina uno.
#
# Los hechizos no agresivos quedan con 1 s de exhaustion
# (`Spell::postCastSpell`, spells.cpp:665-677), asi que entre cast y cast se
# espera de sobra.
#
# ---------------------------------------------------------------------------
# TRANSPORTE: SOLO PRODUCCION
# ---------------------------------------------------------------------------
#
# Entrante `0x97`  -> `EstadoMundo.ventana_casa` / `ultima_ventana_casa`
# Saliente `0x8A`  -> `Conexion772.enviar_lista_acceso_casa(id, texto)`
#
# QA no arma ni un byte. El `u8` de id de lista no es parametro: el servidor
# exige 0 y el transporte de produccion ya lo fija.
#
# OJO CON LA DIRECCION: el `0x97` SALIENTE es "pedir canales" y no tiene nada
# que ver con la ventana entrante. Este adaptador nunca lo manda.
#
# ---------------------------------------------------------------------------
# LO QUE NO SE AFIRMA
# ---------------------------------------------------------------------------
#
# Ni subdueno, ni precedencia entre niveles, ni listas por puerta, ni comodines
# (`*`), ni entradas duplicadas, ni listas mal formadas, ni expulsar, ni
# compra/venta/alquiler, ni persistencia de la propiedad o de la lista entre
# reinicios o ciclos de Docker, ni premium, ni camas.
#
# La semantica de PUERTAS queda fuera: la puerta se abre como montaje y su
# estado se mantiene IGUAL en las dos mediciones, asi que no puede explicar la
# diferencia.
#
# ---------------------------------------------------------------------------
# VARIABLES DE ENTORNO: NUNCA LITERALES, NUNCA IMPRESAS
# ---------------------------------------------------------------------------
#   TVP772_ACCOUNT / _PASSWORD / _PLAYER_CHARACTER    jugador A (dueno temporal)
#   TVP772_PLAYER2_ACCOUNT / _PASSWORD / _CHARACTER   jugador B (el medido)
#   TVP772_GOD_ACCOUNT / _PASSWORD / _GOD_CHARACTER   operador (solo montaje)
#   TVP772_HOUSE_ID         id de la casa de sandbox
#   TVP772_HOUSE_OUTSIDE    "x,y,z" casilla EXTERIOR de partida
#   TVP772_HOUSE_BOUNDARY   "x,y,z" casilla de la CASA que se intenta pisar
#   TVP772_HOUSE_INSIDE     "x,y,z" casilla interior donde se para A a lanzar
#   TVP772_HOUSE_OPERATOR   "x,y,z" casilla interior del operador
# Opcionales:
#   TVP772_HOST, TVP772_LOGIN_PORT

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

## Fragmento del mensaje autoritativo de falta de autorizacion. Es
## DISCRIMINADOR del arnes: el texto exacto no se congela ni entra al payload.
const MARCA_NO_INVITADO := "not invited"
const HECHIZO_INVITADOS := "aleta sio"

const PAUSA_SESION := 7.0
const ESPERA_PASO := 30.0
const ESPERA_CORTA := 15.0
const ESPERA_MEDICION := 3.0
const ESPERA_VENTANA := 12.0
const PAUSA_HECHIZO := 3.0
const LIMITE_TOTAL := 1500.0

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

var _cuenta_a := 0
var _clave_a := ""
var _nombre_a := ""
var _cuenta_b := 0
var _clave_b := ""
var _nombre_b := ""
var _cuenta_god := 0
var _clave_god := ""
var _nombre_god := ""
var _host := ""
var _puerto_login := 0

var _casa_id := 0
var _afuera := Vector3i.ZERO
var _limite := Vector3i.ZERO
var _adentro := Vector3i.ZERO
var _op_adentro := Vector3i.ZERO

## Diagnostico de casilla del operador.
var _ti_pos := ""
var _ti_casa := -1
var _ti_items: Array = []
var _ti_listo := false

## Ventana de lista de acceso: una por edicion, nunca reutilizada.
var _ventana_id := 0
var _ventana_texto := ""
var _ventana_recibida := false
var _texto_base := ""
var _base_capturada := false

## Medicion.
var _dir_control := 0
var _midiendo := ""
var _denegacion := false
var _pos_antes := Vector3i.ZERO
var _ensayo_nego := false
var _nego_sin_lista := false
var _quedo_afuera := false
var _lista_aceptada := false
var _entro_con_lista := false
var _nego_tras_limpieza := false
var _guardia_final := false
var _sesion_continua := true

## Restauracion.
var _puerta_abierta := false
var _propiedad_asignada := false
var _asignaciones := 0
var _ventanas_abiertas := 0

## Cuando la casa YA quedo asignada por un intento anterior, el presupuesto de
## una sola asignacion esta gastado y NO se vuelve a asignar. La prueba de que
## A sigue siendo dueno no es esta bandera: es que el servidor le ABRA la
## ventana, porque `canEditAccessList` exige dueno o subdueno y la lista de
## subduenos esta vacia.
var _saltar_asignacion := false

## Reintentos: un contador propio por fase. NO se puede usar `_espera` para
## esto, porque cada reintento la reinicia y el limite no llegaria nunca.
var _reintentos := 0
const MAX_REINTENTOS := 10

var _obs := {}
var _ultima_posicion := Vector3i.ZERO


func _ready() -> void:
	print("=========================================================")
	print(" TVP3D QA - captura en vivo: acceso por lista de invitados")
	print("=========================================================")
	var requeridas := ["TVP772_ACCOUNT", "TVP772_PASSWORD", "TVP772_PLAYER_CHARACTER",
		"TVP772_PLAYER2_ACCOUNT", "TVP772_PLAYER2_PASSWORD", "TVP772_PLAYER2_CHARACTER",
		"TVP772_GOD_ACCOUNT", "TVP772_GOD_PASSWORD", "TVP772_GOD_CHARACTER",
		"TVP772_HOUSE_ID", "TVP772_HOUSE_OUTSIDE", "TVP772_HOUSE_BOUNDARY",
		"TVP772_HOUSE_INSIDE", "TVP772_HOUSE_OPERATOR"]
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
	_casa_id = CREDENCIALES.entero("TVP772_HOUSE_ID")
	_saltar_asignacion = CREDENCIALES.esta_definida("TVP772_HOUSE_ALREADY_OWNED")

	# El operador tiene `CanEditHouses`, que lo hace pasar por dueno de
	# CUALQUIER casa (`house.cpp:166-168`). No puede ser ninguno de los dos
	# participantes semanticos o el fixture quedaria vacio.
	if _nombre_a == _nombre_god or _nombre_b == _nombre_god:
		print("BLOCKED ningun participante puede ser el operador: su bandera de privilegio lo hace pasar por dueno")
		get_tree().quit(2)
		return
	if _nombre_a == _nombre_b:
		print("BLOCKED el dueno y el medido tienen que ser jugadores distintos")
		get_tree().quit(2)
		return
	if _cuenta_a == _cuenta_b:
		print("BLOCKED el dueno y el medido tienen que estar en cuentas distintas: una cuenta normal no admite dos sesiones")
		get_tree().quit(2)
		return

	for nombre in ["TVP772_HOUSE_OUTSIDE", "TVP772_HOUSE_BOUNDARY",
			"TVP772_HOUSE_INSIDE", "TVP772_HOUSE_OPERATOR"]:
		if not _leer_posicion(nombre):
			return
		match nombre:
			"TVP772_HOUSE_OUTSIDE": _afuera = _ultima_posicion
			"TVP772_HOUSE_BOUNDARY": _limite = _ultima_posicion
			"TVP772_HOUSE_INSIDE": _adentro = _ultima_posicion
			"TVP772_HOUSE_OPERATOR": _op_adentro = _ultima_posicion

	# El paso medido tiene que ser UN paso ordinario.
	if not _contiguas(_afuera, _limite):
		print("BLOCKED la casilla exterior y la del limite no son contiguas: el paso medido no seria un solo desplazamiento")
		get_tree().quit(2)
		return
	# A y el operador se paran adentro, y ninguno puede ocupar la casilla que B
	# necesita pisar: una criatura encima daria un rechazo que NO es el de la
	# regla de casa.
	if _adentro == _limite or _op_adentro == _limite or _adentro == _op_adentro:
		print("BLOCKED las casillas interiores no pueden coincidir entre si ni con la del limite")
		get_tree().quit(2)
		return
	if _casa_id <= 0:
		print("BLOCKED TVP772_HOUSE_ID debe ser el id de la casa de sandbox")
		get_tree().quit(2)
		return
	_abrir_login_god()


func _leer_posicion(nombre: String) -> bool:
	var partes: PackedStringArray = CREDENCIALES.texto(nombre).split(",")
	if partes.size() != 3:
		print("BLOCKED %s debe tener la forma x,y,z" % nombre)
		get_tree().quit(2)
		return false
	_ultima_posicion = Vector3i(int(partes[0]), int(partes[1]), int(partes[2]))
	return true


func _contiguas(a: Vector3i, b: Vector3i) -> bool:
	return a.z == b.z and absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1 and a != b


func _process(delta: float) -> void:
	_total += delta
	_espera += delta
	if _terminando:
		return
	if _total > LIMITE_TOTAL:
		_fallar("FAIL tiempo agotado en la fase '%s'" % _fase)
		return
	if _estado_b != null and not _estado_b.adentro \
			and _fase != "login" and not _fase.begins_with("esperar"):
		_sesion_continua = false
	match _fase:
		"esperar god":
			if _estado_god != null and _estado_god.adentro and _espera > 2.0:
				_ir_a_la_entrada()
		"god en la entrada": _god_en_la_entrada()
		"puerta base": _puerta_base()
		"abrir puerta": _abrir_puerta()
		"puerta abierta": _puerta_abierta_verificar()
		"pausa b":
			if _espera >= PAUSA_SESION: _abrir_b()
		"esperar b":
			if _estado_b != null and _estado_b.adentro and _espera > 2.0:
				_convocar_b()
		"convocar b": _esperar_convocado_b()
		"pausa a":
			if _espera >= PAUSA_SESION: _abrir_a()
		"esperar a":
			if _estado_a != null and _estado_a.adentro and _espera > 2.0:
				_convocar_a()
		"convocar a": _esperar_convocado_a()
		"apartar god": _apartar_god()
		"esperar god lejos": _esperar_god_lejos()
		"control positivo": _control_positivo()
		"volver afuera": _volver_afuera()
		"ensayo sin mutar": _ensayo_sin_mutar()
		"evaluar ensayo": _evaluar_ensayo()
		"god adentro": _god_adentro()
		"verificar casa": _verificar_casa()
		"asignar": _asignar()
		"convocar a adentro": _convocar_a_adentro()
		"esperar a adentro": _esperar_a_adentro()
		"apartar god otra vez": _apartar_god_otra_vez()
		"medir sin lista": _medir_sin_lista()
		"evaluar sin lista": _evaluar_sin_lista()
		"abrir ventana agregar": _abrir_ventana("enviar alta")
		"enviar alta": _enviar_alta()
		"abrir ventana lectura": _abrir_ventana("verificar lectura")
		"verificar lectura": _verificar_lectura()
		"medir con lista": _medir_con_lista()
		"evaluar con lista": _evaluar_con_lista()
		"sacar b": _sacar_b()
		"abrir ventana restaurar": _abrir_ventana("enviar restauracion")
		"enviar restauracion": _enviar_restauracion()
		"abrir ventana confirmar": _abrir_ventana("confirmar restauracion")
		"confirmar restauracion": _confirmar_restauracion()
		"guardia final": _guardia_final_medir()
		"evaluar guardia": _evaluar_guardia()
		"sacar a": _sacar_a()
		"god a la entrada": _god_a_la_entrada()
		"cerrar puerta": _cerrar_puerta()
		"verificar cierre": _verificar_cierre()
		"devolver casa": _devolver_casa()


# -----------------------------------------------------------------
#  Sesiones
# -----------------------------------------------------------------
func _abrir_login_god() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.error_red.connect(func(t): _fallar("FAIL fallo de red en login del operador: %s" % t))
	_con_login.lista_personajes.connect(func(_m, lista):
		for e in lista:
			if str(e.get("nombre", "")) == _nombre_god:
				_puerto_god = int(e.get("puerto", 0))
		if _puerto_god <= 0:
			_fallar("FAIL character configured by TVP772_GOD_CHARACTER was not found")
			return
		_con_login.cerrar()
		_abrir_god())
	_con_login.pedir_personajes(_host, _puerto_login, _cuenta_god, _clave_god)


func _abrir_god() -> void:
	_estado_god = ESTADO.new()
	_estado_god.pedido_ping.connect(func(): _con_god.enviar_juego(PackedByteArray([0x1E])))
	_estado_god.rechazados.connect(func(m): _fallar("FAIL el operador fue rechazado: %s" % m))
	_estado_god.mensaje_servidor.connect(_al_mensaje_god)
	_con_god = CONEXION.new()
	add_child(_con_god)
	_con_god.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red del operador: %s" % t))
	_con_god.paquete_juego.connect(func(m): _estado_god.procesar(m))
	_con_god.entrar_al_mundo(_host, _puerto_god, _cuenta_god, _nombre_god, _clave_god)
	_pasar_a("esperar god")


func _abrir_b() -> void:
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
		_estado_b = ESTADO.new()
		_estado_b.pedido_ping.connect(func(): _con_b.enviar_juego(PackedByteArray([0x1E])))
		_estado_b.rechazados.connect(func(m): _fallar("FAIL B fue rechazado: %s" % m))
		_estado_b.mensaje_servidor.connect(_al_mensaje_b)
		_con_b = CONEXION.new()
		add_child(_con_b)
		_con_b.error_red.connect(func(t):
			if not _terminando: _fallar("FAIL fallo de red de B: %s" % t))
		_con_b.paquete_juego.connect(func(m): _estado_b.procesar(m))
		_con_b.entrar_al_mundo(_host, _puerto_b, _cuenta_b, _nombre_b, _clave_b)
		_pasar_a("esperar b"))
	login.pedir_personajes(_host, _puerto_login, _cuenta_b, _clave_b)


func _abrir_a() -> void:
	var login = CONEXION.new()
	add_child(login)
	login.error_red.connect(func(t): _fallar("FAIL fallo de red en login de A: %s" % t))
	login.lista_personajes.connect(func(_m, lista):
		for e in lista:
			if str(e.get("nombre", "")) == _nombre_a:
				_puerto_a = int(e.get("puerto", 0))
		if _puerto_a <= 0:
			_fallar("FAIL character configured by TVP772_PLAYER_CHARACTER was not found")
			return
		login.cerrar()
		_estado_a = ESTADO.new()
		_estado_a.pedido_ping.connect(func(): _con_a.enviar_juego(PackedByteArray([0x1E])))
		_estado_a.rechazados.connect(func(m): _fallar("FAIL A fue rechazado: %s" % m))
		_estado_a.mensaje_servidor.connect(func(t): print("  [A] %s" % t))
		_estado_a.ventana_casa.connect(_al_ventana_casa)
		_con_a = CONEXION.new()
		add_child(_con_a)
		_con_a.error_red.connect(func(t):
			if not _terminando: _fallar("FAIL fallo de red de A: %s" % t))
		_con_a.paquete_juego.connect(func(m): _estado_a.procesar(m))
		_con_a.entrar_al_mundo(_host, _puerto_a, _cuenta_a, _nombre_a, _clave_a)
		_pasar_a("esperar a"))
	login.pedir_personajes(_host, _puerto_login, _cuenta_a, _clave_a)


## La respuesta especifica de acceso SOLO se cuenta mientras se esta midiendo.
## Contarla siempre daria un falso positivo de otra fase: ya paso en
## `PARITY-HOUSE-ACCESS-001`, donde el mensaje llego durante el control
## positivo y la guarda correctamente no lo conto.
func _al_mensaje_b(texto: String) -> void:
	print("  [B] %s" % texto)
	if _midiendo == "":
		return
	if texto.to_lower().contains(MARCA_NO_INVITADO):
		_denegacion = true


func _al_mensaje_god(texto: String) -> void:
	if texto.begins_with("tileinfo "):
		print("  [g] %s" % texto)
		_ti_items = []
		_ti_casa = -1
		_ti_pos = ""
		var dos_puntos := texto.find(":")
		if dos_puntos > 0:
			_ti_pos = texto.substr(9, dos_puntos - 9)
		var marca := texto.find("house=")
		if marca >= 0:
			var resto := texto.substr(marca + 6)
			var fin := resto.find(" ")
			var valor := resto.substr(0, fin) if fin > 0 else resto
			_ti_casa = int(valor) if valor.is_valid_int() else -1
		_ti_listo = true
		return
	if texto.begins_with("  item ") and _ti_listo:
		print("  [g] %s" % texto)
		_ti_items.append(texto)


## Ventana entrante `0x97`, parseada por el transporte de PRODUCCION. QA no
## reconstruye el paquete: solo consume lo que `EstadoMundo` ya normalizo.
func _al_ventana_casa(datos: Dictionary) -> void:
	_ventana_id = int(datos.get("id", 0))
	_ventana_texto = str(datos.get("texto", ""))
	_ventana_recibida = true
	_ventanas_abiertas += 1
	print("Ventana de lista recibida (#%d). Largo del texto: %d"
		% [_ventanas_abiertas, _ventana_texto.length()])


func _pedir_tileinfo(p: Vector3i) -> void:
	_ti_listo = false
	_ti_items = []
	_ti_casa = -1
	_ti_pos = ""
	_con_god.enviar_hablar("/tileinfo %d,%d,%d" % [p.x, p.y, p.z])


func _tileinfo_de(p: Vector3i) -> bool:
	return _ti_listo and _ti_pos == ("%d,%d,%d" % [p.x, p.y, p.z])


func _items_contienen(fragmento: String) -> bool:
	for linea in _ti_items:
		if str(linea).to_lower().contains(fragmento):
			return true
	return false


# -----------------------------------------------------------------
#  MONTAJE previo, todo reversible y sin gastar el presupuesto
# -----------------------------------------------------------------
func _ir_a_la_entrada() -> void:
	print("El operador va a la casilla exterior.")
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [_afuera.x, _afuera.y, _afuera.z])
	_pasar_a("god en la entrada")


func _god_en_la_entrada() -> void:
	if _estado_god.mi_pos == _afuera:
		_pasar_a("puerta base")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el operador no llego a la casilla exterior")


func _puerta_base() -> void:
	if not _pidio:
		_pidio = true
		_pedir_tileinfo(_limite)
		return
	if _tileinfo_de(_limite):
		if _ti_casa != _casa_id:
			_fallar("BLOCKED la casilla del limite pertenece a la casa %d y no a la de sandbox %d" % [_ti_casa, _casa_id])
			return
		if _items_contienen("closed door"):
			print("Linea base: casilla del limite de la casa de sandbox, puerta CERRADA.")
			_pasar_a("abrir puerta")
			return
		if _items_contienen("open door"):
			# Residuo declarado de un intento anterior de ESTE turno. Lo que la
			# medicion exige es que el estado de la puerta sea IDENTICO en las
			# dos mitades, no que arranque cerrada; y el objetivo de
			# restauracion del turno sigue siendo CERRADA, que es como estaba
			# antes del primer intento.
			_puerta_abierta = true
			print("Linea base: la puerta ya estaba ABIERTA (residuo de un intento anterior). Se restaurara a CERRADA igual.")
			_pasar_a("pausa b")
			return
		_fallar("BLOCKED la casilla del limite no tiene ninguna puerta reconocible")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el diagnostico de la casilla del limite no llego")


func _abrir_puerta() -> void:
	if not _pidio:
		_pidio = true
		var cosa := _item_de_la_puerta()
		if cosa.is_empty():
			_fallar("BLOCKED el cliente no ve ningun item sobre la casilla del limite")
			return
		_con_god.enviar_usar_item(_limite, int(cosa["cid"]), int(cosa["pila"]))
		return
	if _espera > 2.0:
		_pasar_a("puerta abierta")


func _item_de_la_puerta() -> Dictionary:
	var cosas: Array = _estado_god.casillas.get(_limite, [])
	for indice in range(cosas.size() - 1, -1, -1):
		var cosa: Dictionary = cosas[indice]
		if cosa.get("tipo") != "item":
			continue
		if bool(cosa.get("suelo", false)):
			continue
		return {"cid": int(cosa.get("cid", 0)), "pila": indice}
	return {}


func _puerta_abierta_verificar() -> void:
	if not _pidio:
		_pidio = true
		_pedir_tileinfo(_limite)
		return
	if _tileinfo_de(_limite):
		if _items_contienen("closed door"):
			_fallar("BLOCKED la puerta siguio cerrada; sin ella abierta el invitado quedaria frenado por el objeto y no por la regla de casa")
			return
		_puerta_abierta = true
		print("Puerta abierta. Queda IGUAL en las dos mediciones.")
		_pasar_a("pausa b")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED no se pudo verificar el estado de la puerta")


func _convocar_b() -> void:
	print("El operador convoca a B a la casilla exterior.")
	_con_god.enviar_hablar("/c %s" % _nombre_b)
	_pasar_a("convocar b")


func _esperar_convocado_b() -> void:
	if _cerca(_estado_b.mi_pos, _afuera, 2) and _espera > 1.5:
		_pasar_a("pausa a")
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED no se pudo posicionar a B junto a la casa")


func _convocar_a() -> void:
	print("El operador convoca a A a la casilla exterior.")
	_con_god.enviar_hablar("/c %s" % _nombre_a)
	_pasar_a("convocar a")


func _esperar_convocado_a() -> void:
	if _cerca(_estado_a.mi_pos, _afuera, 3) and _espera > 1.5:
		_pasar_a("apartar god")
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED no se pudo posicionar a A junto a la casa")


func _apartar_god() -> void:
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
		_afuera.x + 6, _afuera.y - 6, _afuera.z])
	_pasar_a("esperar god lejos")


func _esperar_god_lejos() -> void:
	if not _cerca(_estado_god.mi_pos, _afuera, 3):
		print("El operador se aparto: no participa de ninguna medicion.")
		_pasar_a("control positivo")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el operador no se aparto del area de la casa")


# -----------------------------------------------------------------
#  CONTROL POSITIVO de B
# -----------------------------------------------------------------
func _control_positivo() -> void:
	if _dir_control == 0:
		_pos_antes = _estado_b.mi_pos
	if _estado_b.mi_pos != _pos_antes and _dir_control > 0:
		print("Control positivo: el servidor confirmo un desplazamiento ordinario de B.")
		_pasar_a("volver afuera")
		return
	if not _pidio or _espera > 3.0:
		_pidio = true
		_espera = 0.0
		# Direcciones que se ALEJAN de la casa: gastar el control positivo
		# chocando contra el limite que se quiere medir seria absurdo.
		var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, -1)]
		_con_b.enviar_auto_camino([dirs[_dir_control % dirs.size()]])
		_dir_control += 1
		return
	if _dir_control > 8:
		_fallar("BLOCKED B no pudo dar ningun paso ordinario; sin control positivo la medicion no significa nada")


func _volver_afuera() -> void:
	if _estado_b.mi_pos == _afuera:
		if not _ensayo_nego:
			_pasar_a("ensayo sin mutar")
		elif not _propiedad_asignada:
			_pasar_a("god adentro")
		elif not _nego_sin_lista:
			_pasar_a("medir sin lista")
		elif not _entro_con_lista:
			_pasar_a("medir con lista")
		else:
			_pasar_a("guardia final")
		return
	if _reintentos >= MAX_REINTENTOS:
		_fallar("BLOCKED B no volvio a la casilla exterior de partida")
		return
	if not _pidio or _espera > 3.0:
		_pidio = true
		_espera = 0.0
		_reintentos += 1
		_caminar_hacia(_con_b, _estado_b, _afuera)


# -----------------------------------------------------------------
#  ENSAYO SIN MUTAR: valida el camino de medicion antes de gastar
#  el presupuesto de una sola asignacion de propiedad.
# -----------------------------------------------------------------
func _ensayo_sin_mutar() -> void:
	_pos_antes = _estado_b.mi_pos
	_denegacion = false
	_midiendo = "ensayo"
	print("ENSAYO (casa todavia SIN DUENO): un paso ordinario hacia la casilla de la casa.")
	_con_b.enviar_auto_camino([_paso_al_limite()])
	_pasar_a("evaluar ensayo")


func _evaluar_ensayo() -> void:
	if _espera < ESPERA_MEDICION:
		return
	_midiendo = ""
	_ensayo_nego = _denegacion and _estado_b.mi_pos == _pos_antes
	print("ENSAYO: denegacion=%s, quedo afuera=%s"
		% [str(_denegacion), str(_estado_b.mi_pos == _pos_antes)])
	if not _ensayo_nego:
		_fallar("BLOCKED el ensayo previo no reprodujo la denegacion; se corta ANTES de mutar nada y sin gastar el presupuesto de propiedad")
		return
	print("Camino de medicion validado con CERO mutaciones. Recien ahora se asigna la propiedad.")
	_pasar_a("god adentro")


# -----------------------------------------------------------------
#  LA UNICA MUTACION DE PROPIEDAD
# -----------------------------------------------------------------
func _god_adentro() -> void:
	if not _pidio:
		_pidio = true
		print("El operador entra a la casa para poder asignar la propiedad.")
		_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
			_op_adentro.x, _op_adentro.y, _op_adentro.z])
		return
	if _estado_god.mi_pos == _op_adentro:
		_pasar_a("verificar casa")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el operador no llego a la casilla interior")


## `/owner` actua sobre la casa donde esta PARADO el operador. Asignar la casa
## equivocada seria mutar estado ajeno, asi que se confirma antes.
func _verificar_casa() -> void:
	if not _pidio:
		_pidio = true
		_pedir_tileinfo(_estado_god.mi_pos)
		return
	if _tileinfo_de(_estado_god.mi_pos):
		if _ti_casa != _casa_id:
			_fallar("BLOCKED el operador esta sobre la casa %d y no sobre la de sandbox %d; no se asigna nada" % [_ti_casa, _casa_id])
			return
		print("Verificado: el operador esta dentro de la casa de sandbox.")
		_pasar_a("asignar")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED no se pudo verificar sobre que casa esta parado el operador")


func _asignar() -> void:
	if not _pidio:
		_pidio = true
		if _saltar_asignacion:
			# El presupuesto de una sola asignacion ya se gasto en un intento
			# anterior de ESTE turno. Volver a asignar crearia una SEGUNDA
			# carta de bienvenida, que es exactamente lo que no se permite.
			_propiedad_asignada = true
			print("La casa YA quedo asignada por un intento anterior: NO se vuelve a asignar.")
			print("Que A siga siendo dueno lo probara el servidor al abrirle la ventana.")
			_pasar_a("convocar a adentro")
			return
		if _asignaciones > 0:
			_fallar("FAIL se intento una SEGUNDA asignacion de propiedad; el presupuesto del turno es de una sola")
			return
		_asignaciones += 1
		print("MONTAJE (unica mutacion de propiedad del turno): la casa pasa a A.")
		_con_god.enviar_hablar("/owner %s" % _nombre_a)
		return
	if _espera > 2.5:
		_propiedad_asignada = true
		_pasar_a("convocar a adentro")


## A entra a la casa por MONTAJE, no caminando, y eso es deliberado.
##
## Lo que este fixture mide es la entrada de B; la de A ya quedo certificada en
## `PARITY-HOUSE-OWNER-ACCESS-001` y aca no se vuelve a afirmar. Hacerlo
## caminar solo agregaba una forma de fallar: en el primer intento el camino de
## A pasaba por la casilla donde estaba parado B, y una criatura en el destino
## devuelve `RETURNVALUE_NOTPOSSIBLE` (`tile.cpp:581-588`), que es un rechazo
## por OCUPACION y no tiene nada que ver con el acceso a la casa.
##
## El hechizo solo exige que A este parado sobre UNA casilla de la casa
## (`invite_guests.lua`), no una en particular.
func _convocar_a_adentro() -> void:
	print("El operador convoca a A adentro de la casa (montaje, no es la entrada medida).")
	_con_god.enviar_hablar("/c %s" % _nombre_a)
	_pasar_a("esperar a adentro")


func _esperar_a_adentro() -> void:
	if _cerca(_estado_a.mi_pos, _op_adentro, 2) and _espera > 1.5:
		if _estado_a.mi_pos == _limite:
			_fallar("BLOCKED A quedo parado en la casilla del limite y taparia la medicion de B")
			return
		print("A esta dentro de la casa y fuera de la casilla medida.")
		_pasar_a("apartar god otra vez")
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED no se pudo llevar a A adentro de la casa")


func _apartar_god_otra_vez() -> void:
	if not _pidio:
		_pidio = true
		_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
			_afuera.x + 6, _afuera.y - 6, _afuera.z])
		return
	if not _cerca(_estado_god.mi_pos, _afuera, 3) and _espera > 1.0:
		_pasar_a("volver afuera")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el operador no se aparto despues de asignar")


# -----------------------------------------------------------------
#  MITAD A: B fuera de la lista, con A ya dueno
#  (es ademas el control de EXCLUSIVIDAD DEL DUENO)
# -----------------------------------------------------------------
func _medir_sin_lista() -> void:
	_pos_antes = _estado_b.mi_pos
	_denegacion = false
	_midiendo = "sin"
	print("Medicion A (A es dueno, B NO esta en la lista): un paso ordinario hacia la casilla de la casa.")
	_con_b.enviar_auto_camino([_paso_al_limite()])
	_pasar_a("evaluar sin lista")


func _evaluar_sin_lista() -> void:
	if _espera < ESPERA_MEDICION:
		return
	_midiendo = ""
	_nego_sin_lista = _denegacion
	_quedo_afuera = _estado_b.mi_pos == _pos_antes
	print("Medicion A: denegacion especifica=%s, quedo afuera=%s"
		% [str(_nego_sin_lista), str(_quedo_afuera)])
	if not _nego_sin_lista:
		_fallar("FAIL sin estar en la lista el servidor no emitio la respuesta especifica de falta de autorizacion")
		return
	if not _quedo_afuera:
		_fallar("FAIL el servidor nego el acceso pero la posicion autoritativa de B cambio igual")
		return
	if not _sesion_continua or not _estado_b.adentro:
		_fallar("BLOCKED la sesion de B se cayo durante la medicion")
		return
	# A ya esta adentro por montaje: puede abrir la ventana sin caminar.
	_pasar_a("abrir ventana agregar")


# -----------------------------------------------------------------
#  Ventana de edicion de la lista
# -----------------------------------------------------------------
## Cada edicion abre SU ventana. Nunca se reutiliza un id.
var _fase_tras_ventana := ""

func _abrir_ventana(siguiente: String) -> void:
	if not _pidio:
		_pidio = true
		_fase_tras_ventana = siguiente
		_ventana_recibida = false
		_ventana_id = 0
		_ventana_texto = ""
		print("A lanza el hechizo de la lista de invitados.")
		_con_a.enviar_hablar(HECHIZO_INVITADOS)
		return
	if _ventana_recibida and _espera > 0.8:
		if _ventana_id <= 0:
			_fallar("FAIL la ventana llego sin id de ventana utilizable")
			return
		_pasar_a(_fase_tras_ventana)
		return
	if _espera > ESPERA_VENTANA:
		_fallar("BLOCKED el servidor no abrio la ventana de la lista de invitados")


# -----------------------------------------------------------------
#  ALTA de B en la lista
# -----------------------------------------------------------------
func _enviar_alta() -> void:
	if not _pidio:
		_pidio = true
		if not _base_capturada:
			# El texto base se captura de la PRIMERA ventana y es lo que se
			# devolvera tal cual en la restauracion. No se reconstruye de
			# memoria ni se adivina que significaba "vacio".
			_texto_base = _ventana_texto
			_base_capturada = true
			print("Texto base de la lista capturado del servidor (largo %d)." % _texto_base.length())
		# Transformacion minima: se parte del texto EXACTO que llego y se
		# agrega UNA linea con el nombre de B. Se conservan las lineas de
		# encabezado '#' que el servidor mando, porque el las vuelve a
		# descartar al recibirlas (`game.cpp:2855-2866`).
		var nuevo := _ventana_texto
		if not nuevo.is_empty() and not nuevo.ends_with("\n"):
			nuevo += "\n"
		nuevo += _nombre_b + "\n"
		# Ni comodines, ni gremios, ni A, ni nada mas: `AccessList::parseList`
		# (house.cpp:443-488) trata '*' como "todos" y '@' como gremio, y este
		# fixture no afirma nada de eso.
		if nuevo.contains("*") or nuevo.contains("@") or nuevo.contains("?") \
				or nuevo.contains("!"):
			_fallar("FAIL el texto a enviar contiene un caracter con significado especial; se aborta antes de mandarlo")
			return
		print("A envia la lista con B agregado, por el transporte de produccion.")
		_con_a.enviar_lista_acceso_casa(_ventana_id, nuevo)
		# La ventana queda consumida: el servidor la cierra siempre.
		_ventana_id = 0
		_ventana_recibida = false
		return
	if _espera > PAUSA_HECHIZO:
		_pasar_a("abrir ventana lectura")


# -----------------------------------------------------------------
#  GUARDA: que el SERVIDOR confirme la relacion, no una variable local
# -----------------------------------------------------------------
func _verificar_lectura() -> void:
	# Se abre una ventana NUEVA y se lee lo que el servidor devuelve. Una
	# variable local del arnes no probaria nada: solo diria que el texto se
	# construyo bien, no que el servidor lo acepto.
	_lista_aceptada = _ventana_texto.to_lower().contains(_nombre_b.to_lower())
	print("Lectura del servidor: la lista devuelta %s a B."
		% ("INCLUYE" if _lista_aceptada else "NO incluye"))
	if not _lista_aceptada:
		_fallar("FAIL el servidor no devolvio a B en la lista; la edicion no fue aceptada")
		return
	# Esta ventana tambien queda consumida.
	_ventana_id = 0
	_ventana_recibida = false
	_pasar_a("medir con lista")


# -----------------------------------------------------------------
#  MITAD B: B en la lista
# -----------------------------------------------------------------
func _medir_con_lista() -> void:
	if _estado_b.mi_pos != _afuera:
		_pasar_a("volver afuera")
		return
	_pos_antes = _estado_b.mi_pos
	_denegacion = false
	_midiendo = "con"
	print("Medicion B (B YA esta en la lista): el MISMO paso hacia la MISMA casilla.")
	_con_b.enviar_auto_camino([_paso_al_limite()])
	_pasar_a("evaluar con lista")


func _evaluar_con_lista() -> void:
	if _espera < ESPERA_MEDICION:
		return
	_midiendo = ""
	# Autoritativo: la posicion viene del servidor. El paso fue una orden de
	# movimiento ordinaria; en esta fase no se emitio ningun teletransporte
	# sobre B.
	_entro_con_lista = _estado_b.mi_pos == _limite
	print("Medicion B: entro=%s, denegacion=%s"
		% [str(_entro_con_lista), str(_denegacion)])
	if _denegacion:
		_fallar("FAIL estando en la lista el servidor siguio emitiendo la respuesta de falta de autorizacion")
		return
	if not _entro_con_lista:
		_fallar("FAIL estando en la lista B no llego a la casilla de la casa")
		return
	if not _sesion_continua or not _estado_b.adentro:
		_fallar("BLOCKED la sesion de B se cayo durante la medicion")
		return
	_construir_observacion()
	_pasar_a("sacar b")


# -----------------------------------------------------------------
#  RESTAURACION
# -----------------------------------------------------------------
func _sacar_b() -> void:
	if _estado_b.mi_pos == _afuera:
		_pasar_a("abrir ventana restaurar")
		return
	if _reintentos >= MAX_REINTENTOS:
		print("AVISO B no volvio solo a la casilla exterior")
		_pasar_a("abrir ventana restaurar")
		return
	if not _pidio or _espera > 3.0:
		_pidio = true
		_espera = 0.0
		_reintentos += 1
		var p := _paso_al_limite()
		_con_b.enviar_auto_camino([Vector2i(-p.x, -p.y)])


func _enviar_restauracion() -> void:
	if not _pidio:
		_pidio = true
		print("RESTAURACION: se devuelve el texto base EXACTO por una ventana NUEVA.")
		_con_a.enviar_lista_acceso_casa(_ventana_id, _texto_base)
		_ventana_id = 0
		_ventana_recibida = false
		return
	if _espera > PAUSA_HECHIZO:
		_pasar_a("abrir ventana confirmar")


func _confirmar_restauracion() -> void:
	var sigue := _ventana_texto.to_lower().contains(_nombre_b.to_lower())
	var igual := _ventana_texto == _texto_base
	print("RESTAURACION: la lista devuelta %s a B; identica al texto base = %s."
		% ["SIGUE incluyendo" if sigue else "ya NO incluye", str(igual)])
	if sigue:
		print("AVISO la lista NO quedo restaurada por la via normal; la devolucion de la casa la limpiara igual")
	_ventana_id = 0
	_ventana_recibida = false
	_pasar_a("guardia final")


## Guarda de limpieza, NO es una asercion del fixture: comprueba que quitar a B
## de la lista le volvio a quitar el acceso.
func _guardia_final_medir() -> void:
	if _estado_b.mi_pos != _afuera:
		_pasar_a("volver afuera")
		return
	_pos_antes = _estado_b.mi_pos
	_denegacion = false
	_midiendo = "guardia"
	print("GUARDA de limpieza: B intenta entrar otra vez, ya fuera de la lista.")
	_con_b.enviar_auto_camino([_paso_al_limite()])
	_pasar_a("evaluar guardia")


func _evaluar_guardia() -> void:
	if _espera < ESPERA_MEDICION:
		return
	_midiendo = ""
	_guardia_final = true
	_nego_tras_limpieza = _denegacion and _estado_b.mi_pos == _pos_antes
	print("GUARDA de limpieza: B %s tras quitarlo de la lista."
		% ("quedo AFUERA, como corresponde" if _nego_tras_limpieza else "NO fue rechazado"))
	if not _nego_tras_limpieza:
		print("AVISO la guarda de limpieza no confirmo el rechazo; se declara en el informe")
	_pasar_a("sacar a")


## A sale de la casa por montaje, igual que entro. Si se quedara adentro,
## `House::setOwner` lo teletransportaria al devolver la casa (`house.cpp:51-57`)
## y seria el servidor, y no este arnes, quien decide donde termina.
func _sacar_a() -> void:
	if not _pidio:
		_pidio = true
		_con_god.enviar_hablar("/gotopos %d,%d,%d" % [_afuera.x, _afuera.y, _afuera.z])
		return
	if _estado_god.mi_pos == _afuera and _espera > 1.0:
		_pasar_a("god a la entrada")
		return
	if _espera > ESPERA_CORTA:
		print("AVISO el operador no volvio a la casilla exterior")
		_pasar_a("god a la entrada")


func _god_a_la_entrada() -> void:
	if not _pidio:
		_pidio = true
		_con_god.enviar_hablar("/c %s" % _nombre_a)
		return
	if _espera > 2.5:
		if _cerca(_estado_a.mi_pos, _afuera, 3):
			print("A quedo fuera de la casa antes de devolverla.")
		else:
			print("AVISO A no salio de la casa; al devolverla el servidor lo reubicara")
		_pasar_a("cerrar puerta")


func _cerrar_puerta() -> void:
	if not _pidio:
		_pidio = true
		var cosa := _item_de_la_puerta()
		if cosa.is_empty():
			print("AVISO el cliente no ve la puerta para cerrarla")
			_pasar_a("verificar cierre")
			return
		_con_god.enviar_usar_item(_limite, int(cosa["cid"]), int(cosa["pila"]))
		return
	if _espera > 2.0:
		_pasar_a("verificar cierre")


func _verificar_cierre() -> void:
	if not _pidio:
		_pidio = true
		_pedir_tileinfo(_limite)
		return
	if _tileinfo_de(_limite):
		if _items_contienen("closed door"):
			_puerta_abierta = false
			print("RESTAURACION: la puerta volvio a su estado cerrado de partida.")
		else:
			print("AVISO la puerta NO volvio a cerrarse; queda declarado como residuo")
		_pasar_a("devolver casa")
		return
	if _espera > ESPERA_CORTA:
		print("AVISO no se pudo verificar el estado final de la puerta")
		_pasar_a("devolver casa")


## `/owner none` devuelve la casa a sin dueno y, por `House::setOwner`, ademas
## deja la lista de invitados vacia. Es la ultima red de seguridad.
func _devolver_casa() -> void:
	if not _pidio:
		_pidio = true
		print("RESTAURACION: se devuelve la casa a SIN DUENO.")
		_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
			_op_adentro.x, _op_adentro.y, _op_adentro.z])
		return
	# `_reintentos` hace de guarda de una sola vez. Con una condicion sobre
	# `_espera` la orden saldria una vez POR CUADRO mientras durara la ventana
	# de tiempo, que son decenas de repeticiones y un riesgo de silenciamiento.
	if _reintentos == 0 and _espera > 2.0:
		_reintentos = 1
		_con_god.enviar_hablar("/owner none")
		return
	if _espera > 5.0:
		_propiedad_asignada = false
		print("RESTAURACION completa.")
		_emitir_observacion()


# -----------------------------------------------------------------
#  Observacion
# -----------------------------------------------------------------
func _construir_observacion() -> void:
	_obs = {
		"precondition": {
			"ordinary_movement_confirmed": true,
			"session_remained_connected": _sesion_continua and _estado_b.adentro,
		},
		"without_guest_listing": {
			"house_access_denial_observed": _nego_sin_lista,
			"participant_remained_outside": _quedo_afuera,
		},
		"with_guest_listing": {
			"guest_relationship_accepted_by_server": _lista_aceptada,
			"entry_allowed": _entro_con_lista,
		},
	}


func _emitir_observacion() -> void:
	if _obs.is_empty():
		_fallar("FAIL no se llego a construir ninguna observacion")
		return
	## Ningun nombre, cuenta, identidad de casa, coordenada, id de ventana,
	## texto de lista, opcode ni marca de tiempo. Solo relaciones.
	print("OBSERVATION_JSON: " + JSON.stringify(_obs))
	print("Ventanas de edicion abiertas: %d. Asignaciones de propiedad: %d."
		% [_ventanas_abiertas, _asignaciones])
	print("Captura de acceso por lista de invitados: OK")
	_terminar(0)


# -----------------------------------------------------------------
#  Utilidades
# -----------------------------------------------------------------
func _paso_al_limite() -> Vector2i:
	return Vector2i(_limite.x - _afuera.x, _limite.y - _afuera.y)


func _caminar_hacia(con, estado, destino: Vector3i) -> void:
	var pasos: Array = []
	var actual: Vector3i = estado.mi_pos
	var x: int = actual.x
	var y: int = actual.y
	while (x != destino.x or y != destino.y) and pasos.size() < 8:
		var px: int = signi(destino.x - x)
		var py: int = signi(destino.y - y)
		pasos.append(Vector2i(px, py))
		x += px
		y += py
	if pasos.is_empty():
		return
	con.enviar_auto_camino(pasos)


func _cerca(posicion: Vector3i, centro: Vector3i, radio: int) -> bool:
	return posicion.z == centro.z \
		and absi(posicion.x - centro.x) <= radio \
		and absi(posicion.y - centro.y) <= radio


func _pasar_a(fase: String) -> void:
	print("  [%.0fs] fase: %s" % [_total, fase])
	_fase = fase
	_espera = 0.0
	_pidio = false
	_reintentos = 0


## Ante cualquier fallo se deshace lo puesto, en orden inverso. Un fixture que
## aborta NO puede dejar una casa con dueno ni una lista con gente adentro.
## `/owner none` cubre las dos cosas de una: `House::setOwner` vacia las listas.
func _fallar(texto: String) -> void:
	print(texto)
	if _propiedad_asignada and _con_god != null:
		print("RESTAURACION de emergencia: la casa vuelve a SIN DUENO, lo que ademas vacia la lista.")
		_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
			_op_adentro.x, _op_adentro.y, _op_adentro.z])
		_con_god.enviar_hablar("/owner none")
	if _puerta_abierta and _con_god != null:
		print("RESTAURACION de emergencia: se intenta cerrar la puerta.")
		var cosa := _item_de_la_puerta()
		if not cosa.is_empty():
			_con_god.enviar_usar_item(_limite, int(cosa["cid"]), int(cosa["pila"]))
	_terminar(2)


func _terminar(codigo: int) -> void:
	if _terminando:
		return
	_terminando = true
	await get_tree().create_timer(4.0).timeout
	for c in [_con_b, _con_a, _con_god]:
		if c != null:
			c.enviar_logout()
	await get_tree().create_timer(2.0).timeout
	for c in [_con_b, _con_a, _con_god]:
		if c != null:
			c.cerrar()
	await get_tree().create_timer(1.0).timeout
	print("EXITCODE=%d" % codigo)
	get_tree().quit(codigo)
