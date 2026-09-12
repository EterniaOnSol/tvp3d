extends Node

# ---------------------------------------------------------------------------
# TVP3D QA - CAPTURA EN VIVO: BORDE DE ALCANCE DEL COMERCIO
# `PARITY-TRADE-RANGE-BOUNDARY-001`
# ---------------------------------------------------------------------------
#
# Mide DONDE deja de aceptarse una solicitud de comercio, moviendo UNA sola
# casilla a la vez y dejando TODO lo demas fijo:
#
#   |dx|=2 |dy|=2 |dz|=0  ->  el comercio SE ABRE
#   |dx|=3 |dy|=2 |dz|=0  ->  RECHAZADO por alcance
#   |dx|=2 |dy|=3 |dz|=0  ->  RECHAZADO por alcance
#
# ---------------------------------------------------------------------------
# LA REGLA, VERIFICADA EN LA FUENTE
# ---------------------------------------------------------------------------
#
# `Game::playerRequestTrade` (`servidor/src/game.cpp:2888-2891`):
#
#     if (!Position::areInRange<2, 2, 0>(tradePartner->getPosition(),
#                                        player->getPosition())) {
#         player->sendCancelMessage(RETURNVALUE_DESTINATIONOUTOFREACH);
#         return;
#     }
#
# Y `Position::areInRange` (`servidor/src/position.h:32-35`):
#
#     return getDistanceX(p1,p2) <= deltax
#         && getDistanceY(p1,p2) <= deltay
#         && getDistanceZ(p1,p2) <= deltaz;
#
# con `getDistanceX` = `abs(p1.x - p2.x)`. De ahi salen cuatro hechos que este
# fixture convierte en geometria medible:
#
#   1. las comparaciones son `<=`, asi que el borde es INCLUSIVO: 2 entra;
#   2. X e Y se comparan POR SEPARADO, unidos por AND. No es distancia
#      euclidea ni Manhattan: es un RECTANGULO (tipo Chebyshev con lados
#      distintos). Por eso (2,2) se acepta aunque su distancia euclidea sea
#      2.83 y la Manhattan sea 4;
#   3. son deltas ABSOLUTOS, asi que el signo no importa;
#   4. `deltaz = 0` significa `abs(dz) <= 0`, es decir MISMO PISO exacto.
#
# ---------------------------------------------------------------------------
# EL ORDEN DE LAS GUARDAS IMPORTA
# ---------------------------------------------------------------------------
#
# La comprobacion de alcance es la SEGUNDA de la funcion, antes de la linea de
# tiro (`canThrowObjectTo` -> "You cannot throw there.") y antes de validar el
# objeto. Dos consecuencias:
#
#   * un rechazo por alcance NO prueba que el objeto fuera valido, y por eso el
#     control positivo con el MISMO objeto es obligatorio;
#   * si el terreno no tuviera linea de tiro, el mensaje seria OTRO, asi que
#     exigir el mensaje exacto tambien descarta esa confusion.
#
# `"Destination is out of range."` tiene muchos productores en el servidor
# (mover criaturas, mover objetos, usar objetos, hechizos). NO es discriminador
# por si solo. Lo que lo vuelve univoco aca es la ACCION: en la ventana de
# medicion el arnes manda UNA solicitud de comercio y nada mas, y dentro de
# `playerRequestTrade` el unico origen posible de ese mensaje es la guarda de
# alcance de `game.cpp:2889`.
#
# ---------------------------------------------------------------------------
# ESTE FIXTURE NO COMPLETA NINGUN COMERCIO
# ---------------------------------------------------------------------------
#
# Mide la INICIACION, no el intercambio. Nunca se manda una aceptacion, asi que
# una transferencia es imposible por construccion. El comercio del caso
# positivo se cierra con la via de cancelacion ya certificada por
# `PARITY-TRADE-CANCEL-001` antes de pasar a los negativos.
#
# 0 objetos creados, 0 movidos, 0 transferidos, 0 muertes, 0 combate,
# 0 monstruos, 0 casas, 0 premium, 0 camas.
#
# ---------------------------------------------------------------------------
# LO QUE NO SE AFIRMA
# ---------------------------------------------------------------------------
#
# Ni el borde VERTICAL (todo ocurre en `dz = 0`), ni AMBOS O NINGUNO ante un
# fallo de transferencia, ni rollback, ni la cancelacion implicita por
# desconexion o por alejarse, ni la cancelacion despues de que uno acepto, ni
# las demas razones de rechazo del comercio.
#
# ---------------------------------------------------------------------------
# VARIABLES DE ENTORNO: NUNCA LITERALES, NUNCA IMPRESAS
# ---------------------------------------------------------------------------
#   TVP772_ACCOUNT / _PASSWORD / _PLAYER_CHARACTER    jugador A (ofrece)
#   TVP772_PLAYER2_ACCOUNT / _PASSWORD / _CHARACTER   jugador B (contraparte)
#   TVP772_GOD_ACCOUNT / _PASSWORD / _GOD_CHARACTER   operador (solo montaje)
#   TVP772_RANGE_A         "x,y,z" casilla fija de A
#   TVP772_RANGE_OPERATOR  "x,y,z" casilla desde donde el operador convoca
# Opcionales:
#   TVP772_HOST, TVP772_LOGIN_PORT

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

## Fragmento del mensaje de rechazo por alcance (`tools.cpp:1015-1016`). Es
## DISCRIMINADOR del arnes: el texto exacto no se congela ni entra al payload.
const MARCA_FUERA_DE_ALCANCE := "out of range"
## Mensaje de la guarda SIGUIENTE, la de linea de tiro. Si apareciera este en
## vez del anterior, el rechazo no seria por alcance y hay que decirlo.
const MARCA_SIN_LINEA := "cannot throw"

const PAUSA_SESION := 7.0
const ESPERA_PASO := 30.0
const ESPERA_CORTA := 15.0
const ESPERA_MEDICION := 3.0
const LIMITE_TOTAL := 900.0
const MAX_REINTENTOS := 12

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
var _reintentos := 0

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

var _pos_a := Vector3i.ZERO
var _pos_op := Vector3i.ZERO
var _ultima_posicion := Vector3i.ZERO

## Objeto controlado: se elige en vivo del equipo de A.
var _slot := 0
var _cid := 0
var _nombre_objeto := ""

## Medicion.
var _midiendo := ""
var _vio_fuera_de_alcance := false
var _vio_sin_linea := false
var _vio_oferta_propia := false
var _a_cerro := false
var _b_cerro := false
var _aceptaciones_enviadas := 0

var _geo_positivo := false
var _acepto_positivo := false
var _cerro_positivo := false
var _geo_x := false
var _rechazo_x := false
var _sin_sesion_x := false
var _geo_y := false
var _rechazo_y := false
var _sin_sesion_y := false
var _objeto_quedo := false
var _sesion_continua := true

var _obs := {}


func _ready() -> void:
	print("=========================================================")
	print(" TVP3D QA - captura en vivo: borde de alcance del comercio")
	print("=========================================================")
	var requeridas := ["TVP772_ACCOUNT", "TVP772_PASSWORD", "TVP772_PLAYER_CHARACTER",
		"TVP772_PLAYER2_ACCOUNT", "TVP772_PLAYER2_PASSWORD", "TVP772_PLAYER2_CHARACTER",
		"TVP772_GOD_ACCOUNT", "TVP772_GOD_PASSWORD", "TVP772_GOD_CHARACTER",
		"TVP772_RANGE_A", "TVP772_RANGE_OPERATOR"]
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

	# El operador no participa del comercio. Ademas, una cuenta normal no
	# admite dos sesiones, asi que A y B tienen que estar en cuentas distintas.
	if _nombre_a == _nombre_god or _nombre_b == _nombre_god:
		print("BLOCKED el operador no puede ser participante del comercio")
		get_tree().quit(2)
		return
	if _nombre_a == _nombre_b or _cuenta_a == _cuenta_b:
		print("BLOCKED los dos participantes tienen que ser personajes distintos en cuentas distintas")
		get_tree().quit(2)
		return

	if not _leer_posicion("TVP772_RANGE_A"):
		return
	_pos_a = _ultima_posicion
	if not _leer_posicion("TVP772_RANGE_OPERATOR"):
		return
	_pos_op = _ultima_posicion
	if _pos_op == _pos_a:
		print("BLOCKED el operador no puede convocar parado en la casilla de A")
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


## Las tres geometrias del fixture, derivadas de la casilla fija de A.
func _pos_b(dx: int, dy: int) -> Vector3i:
	return Vector3i(_pos_a.x + dx, _pos_a.y + dy, _pos_a.z)


func _process(delta: float) -> void:
	_total += delta
	_espera += delta
	if _terminando:
		return
	if _total > LIMITE_TOTAL:
		_fallar("FAIL tiempo agotado en la fase '%s'" % _fase)
		return
	if _estado_a != null and not _estado_a.adentro and not _fase.begins_with("esperar") \
			and _fase != "login" and _fase != "pausa a" and _fase != "pausa b":
		_sesion_continua = false
	if _estado_b != null and not _estado_b.adentro and not _fase.begins_with("esperar") \
			and _fase != "login" and _fase != "pausa a" and _fase != "pausa b":
		_sesion_continua = false
	match _fase:
		"esperar god":
			if _estado_god != null and _estado_god.adentro and _espera > 2.0:
				_ir_al_punto()
		"god en posicion": _god_en_posicion()
		"pausa a":
			if _espera >= PAUSA_SESION: _abrir_a()
		"esperar a":
			if _estado_a != null and _estado_a.adentro and _espera > 2.0:
				_convocar_a()
		"convocar a": _esperar_convocado_a()
		"a camina": _a_camina()
		"volver god": _volver_god()
		"god en posicion otra vez": _god_en_posicion_otra_vez()
		"pausa b":
			if _espera >= PAUSA_SESION: _abrir_b()
		"esperar b":
			if _estado_b != null and _estado_b.adentro and _espera > 2.0:
				_convocar_b()
		"convocar b": _esperar_convocado_b()
		"apartar god": _apartar_god()
		"esperar god lejos": _esperar_god_lejos()
		"elegir objeto": _elegir_objeto()
		"b al positivo": _b_camina(2, 2, "medir positivo")
		"medir positivo": _medir_positivo()
		"evaluar positivo": _evaluar_positivo()
		"cancelar": _cancelar()
		"evaluar cancelacion": _evaluar_cancelacion()
		"b al negativo x": _b_camina(3, 2, "medir negativo x")
		"medir negativo x": _medir_negativo("x")
		"evaluar negativo x": _evaluar_negativo("x")
		"b al negativo y": _b_camina(2, 3, "medir negativo y")
		"medir negativo y": _medir_negativo("y")
		"evaluar negativo y": _evaluar_negativo("y")
		"verificar objeto": _verificar_objeto()


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
	_con_god = CONEXION.new()
	add_child(_con_god)
	_con_god.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red del operador: %s" % t))
	_con_god.paquete_juego.connect(func(m): _estado_god.procesar(m))
	_con_god.entrar_al_mundo(_host, _puerto_god, _cuenta_god, _nombre_god, _clave_god)
	_pasar_a("esperar god")


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
		_estado_a.mensaje_servidor.connect(_al_mensaje_a)
		# Una oferta PROPIA confirmada por el servidor es la prueba de que el
		# comercio se abrio de verdad: llega por 0x7D desde el servidor, no es
		# una suposicion del cliente.
		_estado_a.comercio_actualizado.connect(func(_n, propio, _items):
			if propio: _vio_oferta_propia = true)
		_estado_a.comercio_cerrado.connect(func(): _a_cerro = true)
		_con_a = CONEXION.new()
		add_child(_con_a)
		_con_a.error_red.connect(func(t):
			if not _terminando: _fallar("FAIL fallo de red de A: %s" % t))
		_con_a.paquete_juego.connect(func(m): _estado_a.procesar(m))
		_con_a.entrar_al_mundo(_host, _puerto_a, _cuenta_a, _nombre_a, _clave_a)
		_pasar_a("esperar a"))
	login.pedir_personajes(_host, _puerto_login, _cuenta_a, _clave_a)


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
		_estado_b.mensaje_servidor.connect(func(t): print("  [B] %s" % t))
		_estado_b.comercio_cerrado.connect(func(): _b_cerro = true)
		_con_b = CONEXION.new()
		add_child(_con_b)
		_con_b.error_red.connect(func(t):
			if not _terminando: _fallar("FAIL fallo de red de B: %s" % t))
		_con_b.paquete_juego.connect(func(m): _estado_b.procesar(m))
		_con_b.entrar_al_mundo(_host, _puerto_b, _cuenta_b, _nombre_b, _clave_b)
		_pasar_a("esperar b"))
	login.pedir_personajes(_host, _puerto_login, _cuenta_b, _clave_b)


## Los mensajes de rechazo SOLO se cuentan mientras se esta midiendo. Contarlos
## siempre daria un falso positivo de otra fase: ya paso en
## `PARITY-HOUSE-ACCESS-001`, donde el mensaje llego durante el control
## positivo y la guarda correctamente no lo conto.
func _al_mensaje_a(texto: String) -> void:
	print("  [A] %s" % texto)
	if _midiendo == "":
		return
	var bajo := texto.to_lower()
	if bajo.contains(MARCA_FUERA_DE_ALCANCE):
		_vio_fuera_de_alcance = true
	if bajo.contains(MARCA_SIN_LINEA):
		_vio_sin_linea = true


# -----------------------------------------------------------------
#  Montaje
# -----------------------------------------------------------------
func _ir_al_punto() -> void:
	print("El operador va al punto de convocatoria.")
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [_pos_op.x, _pos_op.y, _pos_op.z])
	_pasar_a("god en posicion")


func _god_en_posicion() -> void:
	if _estado_god.mi_pos == _pos_op:
		_pasar_a("pausa a")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el operador no llego al punto de convocatoria")


func _convocar_a() -> void:
	print("El operador convoca a A.")
	_con_god.enviar_hablar("/c %s" % _nombre_a)
	_pasar_a("convocar a")


func _esperar_convocado_a() -> void:
	if _cerca(_estado_a.mi_pos, _pos_op, 2) and _espera > 1.5:
		# El operador se aparta ANTES de que A camine. En el intento 1 A quedo
		# trabado porque el operador estaba justo en su camino: una criatura en
		# la casilla de destino da `RETURNVALUE_NOTPOSSIBLE` (`tile.cpp:581-588`),
		# que es un rechazo por OCUPACION y no tiene nada que ver con lo que se
		# quiere medir.
		_tras_apartar = "a camina"
		_pasar_a("apartar god")
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED no se pudo convocar a A")


## Vuelve al punto de convocatoria para llamar a B, ya con A colocado.
func _volver_god() -> void:
	if not _pidio:
		_pidio = true
		_con_god.enviar_hablar("/gotopos %d,%d,%d" % [_pos_op.x, _pos_op.y, _pos_op.z])
		return
	if _estado_god.mi_pos == _pos_op:
		_pasar_a("god en posicion otra vez")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el operador no volvio al punto de convocatoria")


func _god_en_posicion_otra_vez() -> void:
	_pasar_a("pausa b")


## A camina a su casilla fija ANTES de que B sea convocado. Serializarlo evita
## el tropiezo de `PARITY-HOUSE-GUEST-ACCESS-001`, donde el camino de uno
## pasaba por la casilla ocupada por el otro y el servidor contestaba
## `NOTPOSSIBLE` por OCUPACION, no por la regla que se queria medir.
func _a_camina() -> void:
	if _estado_a.mi_pos == _pos_a:
		print("A esta en su casilla fija.")
		_pasar_a("volver god")
		return
	if _reintentos >= MAX_REINTENTOS:
		_fallar("BLOCKED A no llego a su casilla fija")
		return
	if not _pidio or _espera > 3.0:
		_pidio = true
		_espera = 0.0
		_reintentos += 1
		_caminar_hacia(_con_a, _estado_a, _pos_a)


func _convocar_b() -> void:
	print("El operador convoca a B.")
	_con_god.enviar_hablar("/c %s" % _nombre_b)
	_pasar_a("convocar b")


func _esperar_convocado_b() -> void:
	if _cerca(_estado_b.mi_pos, _pos_op, 2) and _espera > 1.5:
		_tras_apartar = "elegir objeto"
		_pasar_a("apartar god")
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED no se pudo convocar a B")


## A donde seguir despues de que el operador se aparte. El operador se aparta
## DOS veces: antes de que camine A y antes de que camine B.
var _tras_apartar := ""

func _apartar_god() -> void:
	if not _pidio:
		_pidio = true
		_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
			_pos_a.x - 9, _pos_a.y - 9, _pos_a.z])
		return
	if _espera > 1.0:
		_pasar_a("esperar god lejos")


func _esperar_god_lejos() -> void:
	if not _cerca(_estado_god.mi_pos, _pos_a, 6):
		print("El operador se aparto: no estorba ningun camino y no participa de ninguna medicion.")
		_pasar_a(_tras_apartar)
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el operador no se aparto del area de medicion")


# -----------------------------------------------------------------
#  Objeto controlado: se elige del equipo que A YA tiene
# -----------------------------------------------------------------
## No se crea nada. Se busca la primera ranura de equipo con un objeto
## levantable y que no sea contenedor, que es lo que el servidor exige
## (`isPickupable()` en `game.cpp`, mas la ausencia de `UNIQUEID`). Que el
## objeto sirva de verdad lo prueba el CONTROL POSITIVO, no esta heuristica.
func _elegir_objeto() -> void:
	for slot in range(1, 11):
		var cosa: Dictionary = _estado_a.inventario.get(slot, {})
		if cosa.is_empty():
			continue
		if not bool(cosa.get("levantable", false)):
			continue
		if bool(cosa.get("contenedor", false)):
			continue
		_slot = slot
		_cid = int(cosa.get("cid", 0))
		_nombre_objeto = str(cosa.get("nombre", ""))
		break
	if _slot <= 0 or _cid <= 0:
		if _espera > ESPERA_CORTA:
			_fallar("BLOCKED A no tiene ningun objeto de equipo levantable y no contenedor para ofrecer")
		return
	print("Objeto controlado de A: ranura %d, '%s'. No se creo nada." % [_slot, _nombre_objeto])
	_pasar_a("b al positivo")


# -----------------------------------------------------------------
#  Geometria: SIEMPRE del estado autoritativo
# -----------------------------------------------------------------
func _b_camina(dx: int, dy: int, siguiente: String) -> void:
	var destino := _pos_b(dx, dy)
	if _estado_b.mi_pos == destino:
		_pasar_a(siguiente)
		return
	if _reintentos >= MAX_REINTENTOS:
		_fallar("BLOCKED B no llego a la casilla de la geometria %d,%d" % [dx, dy])
		return
	if not _pidio or _espera > 3.0:
		_pidio = true
		_espera = 0.0
		_reintentos += 1
		_caminar_hacia(_con_b, _estado_b, destino)


## Se comprueba contra las posiciones que reporta el SERVIDOR, nunca contra la
## prediccion local: un cliente puede dibujar un paso que el servidor rechazo.
func _geometria_es(dx: int, dy: int) -> bool:
	var pa: Vector3i = _estado_a.mi_pos
	var pb: Vector3i = _estado_b.mi_pos
	var ok := absi(pa.x - pb.x) == dx and absi(pa.y - pb.y) == dy and pa.z == pb.z
	print("Geometria autoritativa: |dx|=%d |dy|=%d |dz|=%d (esperada %d,%d,0) -> %s"
		% [absi(pa.x - pb.x), absi(pa.y - pb.y), absi(pa.z - pb.z), dx, dy, str(ok)])
	return ok


func _id_de_b_visto_por_a() -> int:
	for id in _estado_a.criaturas:
		if str(_estado_a.criaturas[id].get("nombre", "")) == _nombre_b:
			return int(id)
	return 0


# -----------------------------------------------------------------
#  CONTROL POSITIVO: el borde inclusivo
# -----------------------------------------------------------------
func _medir_positivo() -> void:
	if not _pidio:
		if not _geometria_es(2, 2):
			if _espera > ESPERA_CORTA:
				_fallar("BLOCKED la geometria del borde inclusivo no se establecio")
			return
		_geo_positivo = true
		var id_b := _id_de_b_visto_por_a()
		if id_b == 0:
			if _espera > ESPERA_CORTA:
				_fallar("BLOCKED A no ve a B como criatura para ofrecerle")
			return
		_pidio = true
		_vio_oferta_propia = false
		_vio_fuera_de_alcance = false
		_vio_sin_linea = false
		_midiendo = "positivo"
		print("BORDE INCLUSIVO: A solicita comercio con el transporte de produccion.")
		_con_a.enviar_solicitar_comercio_inventario(_slot, _cid, id_b)
		return
	if _espera > ESPERA_MEDICION:
		_pasar_a("evaluar positivo")


func _evaluar_positivo() -> void:
	_midiendo = ""
	_acepto_positivo = _vio_oferta_propia
	print("Borde inclusivo: comercio abierto=%s, rechazo por alcance=%s"
		% [str(_acepto_positivo), str(_vio_fuera_de_alcance)])
	if _vio_fuera_de_alcance:
		_fallar("FAIL en el borde inclusivo el servidor rechazo por alcance; la regla no seria <= 2")
		return
	if _vio_sin_linea:
		_fallar("BLOCKED el rechazo fue por linea de tiro y no por alcance; el terreno elegido no sirve")
		return
	if not _acepto_positivo:
		_fallar("FAIL el comercio no se abrio en el borde inclusivo; sin control positivo los negativos no significan nada")
		return
	_pasar_a("cancelar")


## Se cancela por la via ya certificada en `PARITY-TRADE-CANCEL-001`. NO se
## acepta, NO se desconecta y NO se sale del alcance: eso mediria otra cosa.
func _cancelar() -> void:
	if not _pidio:
		_pidio = true
		_a_cerro = false
		_b_cerro = false
		print("Se CANCELA el comercio del borde inclusivo antes de medir los negativos.")
		_con_a.enviar_cerrar_comercio()
		return
	if _espera > ESPERA_MEDICION:
		_pasar_a("evaluar cancelacion")


func _evaluar_cancelacion() -> void:
	_cerro_positivo = _a_cerro and _b_cerro
	print("Cancelacion: A cerro=%s, B cerro=%s" % [str(_a_cerro), str(_b_cerro)])
	if not _cerro_positivo:
		_fallar("BLOCKED el comercio del borde inclusivo no quedo cerrado en los dos lados; medir un negativo con una sesion abierta daria un rechazo por otra razon")
		return
	_pasar_a("b al negativo x")


# -----------------------------------------------------------------
#  NEGATIVOS: una sola casilla mas alla, un eje por vez
# -----------------------------------------------------------------
func _medir_negativo(eje: String) -> void:
	if not _pidio:
		var dx := 3 if eje == "x" else 2
		var dy := 2 if eje == "x" else 3
		if not _geometria_es(dx, dy):
			if _espera > ESPERA_CORTA:
				_fallar("BLOCKED la geometria del negativo %s no se establecio" % eje)
			return
		if eje == "x":
			_geo_x = true
		else:
			_geo_y = true
		var id_b := _id_de_b_visto_por_a()
		if id_b == 0:
			if _espera > ESPERA_CORTA:
				_fallar("BLOCKED A no ve a B como criatura para ofrecerle")
			return
		_pidio = true
		_vio_oferta_propia = false
		_vio_fuera_de_alcance = false
		_vio_sin_linea = false
		_midiendo = eje
		print("NEGATIVO %s: A solicita el MISMO comercio, con el MISMO objeto." % eje.to_upper())
		_con_a.enviar_solicitar_comercio_inventario(_slot, _cid, id_b)
		return
	if _espera > ESPERA_MEDICION:
		_pasar_a("evaluar negativo %s" % eje)


func _evaluar_negativo(eje: String) -> void:
	_midiendo = ""
	var rechazo := _vio_fuera_de_alcance
	var sin_sesion := not _vio_oferta_propia
	print("Negativo %s: rechazo por alcance=%s, sin sesion de comercio=%s"
		% [eje.to_upper(), str(rechazo), str(sin_sesion)])
	if _vio_sin_linea:
		_fallar("BLOCKED el rechazo fue por linea de tiro y no por alcance")
		return
	if not rechazo:
		_fallar("FAIL una casilla mas alla el servidor no rechazo por alcance")
		return
	if not sin_sesion:
		_fallar("FAIL el servidor rechazo por alcance pero igual abrio una sesion de comercio")
		return
	if eje == "x":
		_rechazo_x = true
		_sin_sesion_x = true
		_pasar_a("b al negativo y")
	else:
		_rechazo_y = true
		_sin_sesion_y = true
		_pasar_a("verificar objeto")


# -----------------------------------------------------------------
#  Integridad del objeto
# -----------------------------------------------------------------
## Nunca se mando una aceptacion, asi que una transferencia es imposible por
## construccion; igual se comprueba contra el inventario autoritativo.
func _verificar_objeto() -> void:
	var cosa: Dictionary = _estado_a.inventario.get(_slot, {})
	_objeto_quedo = int(cosa.get("cid", 0)) == _cid and _aceptaciones_enviadas == 0
	print("Integridad: el objeto sigue en la ranura de A=%s, aceptaciones enviadas=%d"
		% [str(_objeto_quedo), _aceptaciones_enviadas])
	if not _objeto_quedo:
		_fallar("FAIL el objeto ofrecido no quedo donde estaba")
		return
	_construir_observacion()
	_emitir_observacion()


# -----------------------------------------------------------------
#  Observacion
# -----------------------------------------------------------------
func _construir_observacion() -> void:
	_obs = {
		"precondition": {
			"session_remained_connected": _sesion_continua
				and _estado_a.adentro and _estado_b.adentro,
		},
		"inclusive_boundary": {
			"geometry_verified": _geo_positivo,
			"trade_initiation_accepted": _acepto_positivo,
		},
		"outside_x_by_one": {
			"geometry_verified": _geo_x,
			"range_rejection_observed": _rechazo_x,
			"no_trade_session_opened": _sin_sesion_x,
		},
		"outside_y_by_one": {
			"geometry_verified": _geo_y,
			"range_rejection_observed": _rechazo_y,
			"no_trade_session_opened": _sin_sesion_y,
		},
		"integrity": {
			"offered_item_stayed_with_owner": _objeto_quedo,
		},
	}


func _emitir_observacion() -> void:
	## Ningun nombre, cuenta, coordenada, id de criatura, id de objeto, opcode
	## ni marca de tiempo. Solo relaciones.
	print("OBSERVATION_JSON: " + JSON.stringify(_obs))
	print("Aceptaciones enviadas: %d. Comercios completados: 0." % _aceptaciones_enviadas)
	print("Captura del borde de alcance del comercio: OK")
	_terminar(0)


# -----------------------------------------------------------------
#  Utilidades
# -----------------------------------------------------------------
## Camino en linea recta con desatasco.
##
## Si la posicion autoritativa no cambia entre reintentos, casi siempre es que
## OTRA CRIATURA ocupa la casilla siguiente: `Tile::queryAdd`
## (`tile.cpp:581-588`) devuelve `RETURNVALUE_NOTPOSSIBLE` en ese caso. Repetir
## el mismo camino no lo resuelve nunca. Entonces se intercala UN paso lateral
## para rodear, alternando el lado en cada intento.
##
## Esto es mecanica del arnes, no del fixture: lo que se afirma es la geometria
## AUTORITATIVA que se verifica despues, no como se llego a ella.
var _pos_previa_camino := Vector3i.ZERO
var _atascos := 0

func _caminar_hacia(con, estado, destino: Vector3i) -> void:
	var actual: Vector3i = estado.mi_pos
	if actual == _pos_previa_camino:
		_atascos += 1
	else:
		_atascos = 0
	_pos_previa_camino = actual

	var pasos: Array = []
	if _atascos >= 2:
		# Rodeo: un paso perpendicular al avance principal, alternando lado.
		var dx := signi(destino.x - actual.x)
		var dy := signi(destino.y - actual.y)
		var lado := 1 if (_atascos % 2) == 0 else -1
		var lateral := Vector2i(lado, 0) if dx == 0 else Vector2i(0, lado)
		if dx != 0 and dy != 0:
			lateral = Vector2i(dx, 0)
		pasos.append(lateral)
		print("  (desatasco: un paso lateral para rodear un bloqueo)")

	var x: int = actual.x + (pasos[0].x if not pasos.is_empty() else 0)
	var y: int = actual.y + (pasos[0].y if not pasos.is_empty() else 0)
	while (x != destino.x or y != destino.y) and pasos.size() < 10:
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
	_atascos = 0
	_pos_previa_camino = Vector3i.ZERO


## Ante cualquier fallo se cierra un comercio que haya quedado abierto. No hay
## nada mas que deshacer: este fixture no crea, no mueve y no transfiere.
func _fallar(texto: String) -> void:
	print(texto)
	if _con_a != null:
		_con_a.enviar_cerrar_comercio()
	_terminar(2)


func _terminar(codigo: int) -> void:
	if _terminando:
		return
	_terminando = true
	await get_tree().create_timer(3.0).timeout
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
