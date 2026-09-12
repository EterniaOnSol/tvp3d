extends Node

# ---------------------------------------------------------------------------
# TVP3D QA - CAPTURA EN VIVO: ACCESO DEL DUENO A UNA CASA
# `PARITY-HOUSE-OWNER-ACCESS-001`
# ---------------------------------------------------------------------------
#
# Mide UNA comparacion A/B sobre el MISMO jugador y la MISMA casilla limite:
#
#   sin ser dueno  ->  el servidor le NIEGA la entrada y se queda afuera
#   siendo dueno   ->  el servidor le PERMITE la entrada
#
# La comparacion ES el fixture. Ninguna de las dos mitades significa nada sola:
# "no entro" lo produce cualquier pared, y "entro" lo produce cualquier casilla
# que no sea de una casa. Lo que se afirma es que lo UNICO que cambio entre las
# dos mediciones fue la relacion de propiedad.
#
# ---------------------------------------------------------------------------
# LA REGLA MEDIDA, VERIFICADA EN EL CODIGO
# ---------------------------------------------------------------------------
#
# `Tile::queryAdd` (`servidor/src/tile.cpp:481-489`):
#
#     if (house) {
#         if (const Player* player = creature->getPlayer()) {
#             if (!house->isInvited(player)) {
#                 return RETURNVALUE_PLAYERISNOTINVITED;
#
# `House::isInvited` (`house.cpp:307-310`) es
# `getHouseAccessLevel(player) != HOUSE_NOT_INVITED`, y el nivel
# (`house.cpp:154-183`) da `HOUSE_OWNER` cuando `player->getGUID() == owner`.
# Con `houseOwnedByAccount = false` en `config.lua:109`, la propiedad se
# resuelve por GUID del PERSONAJE, no por cuenta.
#
# DOS DATOS QUE IMPORTAN Y NO SE DAN POR SUPUESTOS:
#
#   * el control de casa esta ARRIBA de todo en `queryAdd`, inmediatamente
#     despues de comprobar que la casilla tiene suelo y ANTES de cualquier
#     chequeo de objeto que bloquee. Por eso un no invitado recibe la respuesta
#     ESPECIFICA de falta de autorizacion aunque la casilla ademas este tapada;
#   * `isPremium()` NO aparece en ninguna rama del control de entrada. Esta
#     captura no toca premium y no lo necesita.
#
# ---------------------------------------------------------------------------
# POR QUE HAY QUE ABRIR LA PUERTA, Y POR QUE NO CONTAMINA LA MEDICION
# ---------------------------------------------------------------------------
#
# Se reconocieron 734 casillas del mundo con `/tileinfo` antes de disenar esto.
# Resultado: en este mapa NO existe ninguna casa con un limite abierto. Todas
# estan cerradas por pared, ventana o puerta; el unico paso es la puerta.
#
# Eso genera una asimetria que arruinaria el A/B si se ignorara: al no invitado
# lo frena el control de casa (que corre primero), pero al DUENO lo frenaria la
# puerta cerrada, que es un bloqueo de objeto y NO tiene nada que ver con la
# propiedad. Se leeria como "el dueno tampoco puede entrar", que es falso.
#
# Por eso el operador abre la puerta UNA VEZ, ANTES de la medicion negativa, y
# la deja abierta durante LAS DOS. El estado de la puerta es identico en ambas
# mitades, asi que no puede explicar la diferencia; lo unico que cambia entre
# una y otra es la propiedad. Al final se vuelve a cerrar.
#
# Abrir la puerta NO es medir la puerta. La semantica de puertas
# (`Door::canUse`, `house.cpp:578`, que exige nivel >= SUBOWNER o la lista
# propia de la puerta) queda EXPRESAMENTE fuera de lo que este fixture afirma.
#
# ---------------------------------------------------------------------------
# LO QUE NO SE AFIRMA
# ---------------------------------------------------------------------------
#
# Ni compra, ni venta, ni alquiler, ni subasta, ni transferencia de casas; ni
# persistencia de la propiedad entre reinicios o entre ciclos de Docker; ni
# semantica de invitado, subdueno o puertas; ni precedencia entre esos niveles;
# ni expulsar; ni requisito de premium; ni camas, dormir o regeneracion.
#
# TAMPOCO se afirma EXCLUSIVIDAD, es decir que solo el dueno pueda entrar: eso
# necesitaria un segundo participante normal midiendose contra la misma casilla
# y no se midio. Queda declarado como no certificado.
#
# `/owner` es MONTAJE, no es el comportamiento certificado.
#
# ---------------------------------------------------------------------------
# MUTACION Y RESTAURACION
# ---------------------------------------------------------------------------
#
# Temporal: el dueno de UNA casa sin dueno, y el estado abierto/cerrado de su
# puerta. Las dos se revierten aca mismo, en orden inverso.
#
# `House::setOwner` (`house.cpp:28-137`) tiene efectos que se verificaron uno
# por uno antes de correr esto:
#   * escribe `houses.owner` en la DB, y pone `bid/bid_end/last_bid/
#     highest_bidder` en 0; en este mundo esos cuatro YA son 0 en las 862
#     casas, asi que ponerlos en 0 no cambia nada;
#   * expulsa a los jugadores parados en la casa. El operador es inmune por su
#     bandera `CanEditHouses` (`house.cpp:196`);
#   * limpia las listas de invitados y subduenos, que en este mundo estan
#     VACIAS para todas las casas (`house_lists` tiene 0 filas);
#   * `houseTransferItems`, `houseCleanBeds` y `houseClearDoors` son `false`
#     por defecto y no estan en `config.lua`, asi que al ASIGNAR no se mueve
#     ningun objeto, no se toca ninguna cama y no se limpia ninguna puerta;
#   * al devolverla a sin dueno llama `transferToDepot`, que manda al deposito
#     del dueno saliente los objetos RECOGIBLES que haya sobre las casillas de
#     la casa. La casa elegida se recorrio entera con `/tileinfo`: solo tiene
#     paredes, ventanas, lamparas de pared, cesped, puertas, camas, un horno y
#     una escalera. Ninguno es recogible y ninguno es contenedor, asi que no
#     hay nada que mover;
#   * al asignar, el servidor deja una carta de bienvenida en el deposito del
#     nuevo dueno. Eso es inevitable por esta via y se declara como residuo.
#
# 0 muertes, 0 combate, 0 monstruos, 0 invocaciones, 0 items creados,
# 0 progresion, 0 premium, 0 camas usadas, 0 listas de acceso modificadas.
#
# ---------------------------------------------------------------------------
# VARIABLES DE ENTORNO: NUNCA LITERALES, NUNCA IMPRESAS
# ---------------------------------------------------------------------------
#   TVP772_ACCOUNT / _PASSWORD / _PLAYER_CHARACTER   participante (normal)
#   TVP772_GOD_ACCOUNT / _PASSWORD / _GOD_CHARACTER  operador (solo montaje)
#   TVP772_HOUSE_ID         id de la casa de sandbox, para verificar el destino
#   TVP772_HOUSE_OUTSIDE    "x,y,z" casilla EXTERIOR de partida
#   TVP772_HOUSE_BOUNDARY   "x,y,z" casilla de la CASA que se intenta pisar
#   TVP772_HOUSE_INSIDE     "x,y,z" casilla interior donde se aparta el operador
# Opcionales:
#   TVP772_HOST, TVP772_LOGIN_PORT
#
#   ...Godot --headless --path cliente3d \
#       pruebas/prueba_parity_house_owner_access_capture.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

## Fragmento del mensaje autoritativo de falta de autorizacion
## (`servidor/src/tools.cpp`). Es DISCRIMINADOR del harness: el texto exacto
## no se congela y no entra al payload.
const MARCA_NO_INVITADO := "not invited"

const PAUSA_SESION := 7.0
const ESPERA_PASO := 30.0
const ESPERA_CORTA := 15.0
const ESPERA_MEDICION := 3.0
const LIMITE_TOTAL := 900.0

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

var _casa_id := 0
var _afuera := Vector3i.ZERO
var _limite := Vector3i.ZERO
var _adentro := Vector3i.ZERO

## Diagnostico de casilla: ultima respuesta de `/tileinfo` y sus items.
var _ti_pos := ""
var _ti_casa := -1
var _ti_items: Array = []
var _ti_listo := false

## Control positivo.
var _pos_control_inicial := Vector3i.ZERO
var _movimiento_confirmado := false
var _dir_control := 0

## Medicion.
var _midiendo := ""
var _denegacion_vista := false
var _pos_antes := Vector3i.ZERO
var _nego_sin_propiedad := false
var _quedo_afuera := false
var _entro_con_propiedad := false
var _sesion_continua := true

## Restauracion.
var _puerta_abierta := false
var _propiedad_asignada := false

var _obs := {}


func _ready() -> void:
	print("=========================================================")
	print(" TVP3D QA - captura en vivo: acceso del dueno a una casa")
	print("=========================================================")
	var requeridas := ["TVP772_ACCOUNT", "TVP772_PASSWORD", "TVP772_PLAYER_CHARACTER",
		"TVP772_GOD_ACCOUNT", "TVP772_GOD_PASSWORD", "TVP772_GOD_CHARACTER",
		"TVP772_HOUSE_ID", "TVP772_HOUSE_OUTSIDE", "TVP772_HOUSE_BOUNDARY",
		"TVP772_HOUSE_INSIDE"]
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
	_casa_id = CREDENCIALES.entero("TVP772_HOUSE_ID")

	# El operador NO puede ser el participante: su bandera `CanEditHouses` lo
	# hace pasar por dueno de CUALQUIER casa, asi que la mitad negativa no
	# existiria y el fixture seria vacio.
	if _nombre == _nombre_god:
		print("BLOCKED el participante no puede ser el operador: su bandera de privilegio lo haria pasar por dueno de cualquier casa")
		get_tree().quit(2)
		return

	if not _leer_posicion("TVP772_HOUSE_OUTSIDE"):
		return
	_afuera = _ultima_posicion
	if not _leer_posicion("TVP772_HOUSE_BOUNDARY"):
		return
	_limite = _ultima_posicion
	if not _leer_posicion("TVP772_HOUSE_INSIDE"):
		return
	_adentro = _ultima_posicion

	# El paso medido tiene que ser UN paso ordinario: si el limite no es
	# contiguo a la casilla exterior, lo que se mediria seria un camino, no una
	# entrada.
	if not _contiguas(_afuera, _limite):
		print("BLOCKED la casilla exterior y la del limite no son contiguas: el paso medido no seria un solo desplazamiento")
		get_tree().quit(2)
		return
	if _casa_id <= 0:
		print("BLOCKED TVP772_HOUSE_ID debe ser el id de la casa de sandbox")
		get_tree().quit(2)
		return
	_abrir_login()


var _ultima_posicion := Vector3i.ZERO

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
	if _estado != null and not _estado.adentro \
			and _fase != "login" and _fase != "esperar participante":
		_sesion_continua = false
	match _fase:
		"esperar god":
			if _estado_god != null and _estado_god.adentro and _espera > 2.0:
				_ir_a_la_entrada()
		"god en la entrada":
			_god_en_la_entrada()
		"puerta base":
			_puerta_base()
		"abrir puerta":
			_abrir_puerta()
		"puerta abierta":
			_puerta_abierta_verificar()
		"pausa participante":
			if _espera >= PAUSA_SESION:
				_abrir_participante()
		"esperar participante":
			if _estado != null and _estado.adentro and _espera > 2.0:
				_convocar()
		"convocar":
			_esperar_convocado()
		"apartar god":
			_apartar_god()
		"esperar god lejos":
			_esperar_god_lejos()
		"control positivo":
			_control_positivo()
		"volver afuera":
			_volver_afuera()
		"medir sin propiedad":
			_medir_sin_propiedad()
		"evaluar sin propiedad":
			_evaluar_sin_propiedad()
		"god adentro":
			_god_adentro()
		"verificar casa":
			_verificar_casa()
		"asignar":
			_asignar()
		"apartar god adentro":
			_apartar_god_adentro()
		"medir con propiedad":
			_medir_con_propiedad()
		"evaluar con propiedad":
			_evaluar_con_propiedad()
		"sacar participante":
			_sacar_participante()
		"devolver casa":
			_devolver_casa()
		"god a la entrada":
			_god_a_la_entrada()
		"cerrar puerta":
			_cerrar_puerta()
		"verificar cierre":
			_verificar_cierre()


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
	_estado_god.mensaje_servidor.connect(_al_mensaje_god)
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


## La respuesta especifica de acceso SOLO se cuenta mientras se esta midiendo.
## Si se contara siempre, un mensaje de otra fase daria un falso positivo: ya
## paso en `PARITY-HOUSE-ACCESS-001`, donde el mensaje llego durante el control
## positivo.
func _al_mensaje(texto: String) -> void:
	print("  [p] %s" % texto)
	if _midiendo == "":
		return
	if texto.to_lower().contains(MARCA_NO_INVITADO):
		_denegacion_vista = true


## Diagnostico de casilla. Se guarda la cabecera y los items que vengan
## despues, hasta que llegue la proxima cabecera.
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
#  Montaje: puerta abierta, con el estado ANTES y DESPUES verificado
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


## Linea base de la puerta: tiene que estar CERRADA y la casilla tiene que ser
## de la casa de sandbox esperada. Si el id no coincide, se corta: mutar la
## casa equivocada seria peor que no medir.
func _puerta_base() -> void:
	if not _pidio:
		_pidio = true
		_pedir_tileinfo(_limite)
		return
	if _tileinfo_de(_limite):
		if _ti_casa != _casa_id:
			_fallar("BLOCKED la casilla del limite pertenece a la casa %d y no a la de sandbox %d" % [_ti_casa, _casa_id])
			return
		if not _items_contienen("closed door"):
			_fallar("BLOCKED la casilla del limite no tiene una puerta cerrada en su estado de partida")
			return
		print("Linea base verificada: la casilla del limite es de la casa de sandbox y su puerta esta cerrada.")
		_pasar_a("abrir puerta")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el diagnostico de la casilla del limite no llego")


## Abre la puerta usando el transporte de PRODUCCION (`enviar_usar_item`,
## 0x82). El item se identifica en el estado de mundo del propio cliente: el
## de mas arriba que no sea suelo ni criatura.
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
			_fallar("BLOCKED la puerta de la casa siguio cerrada; sin ella abierta el dueno quedaria frenado por el objeto y no por la regla de casa")
			return
		_puerta_abierta = true
		print("Puerta abierta por el operador. Queda IGUAL en las dos mediciones, asi que no puede explicar la diferencia.")
		_pasar_a("pausa participante")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED no se pudo verificar el estado de la puerta despues de abrirla")


# -----------------------------------------------------------------
#  Posicionamiento del participante
# -----------------------------------------------------------------
func _convocar() -> void:
	print("El operador convoca al participante a la casilla exterior.")
	_con_god.enviar_hablar("/c %s" % _nombre)
	_pasar_a("convocar")


func _esperar_convocado() -> void:
	if _cerca(_estado.mi_pos, _afuera, 2) and _espera > 1.5:
		_pasar_a("apartar god")
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED no se pudo posicionar al participante junto a la casa")


## El operador se retira lejos: no participa de ninguna medicion y no debe
## ocupar una casilla que el participante necesite.
func _apartar_god() -> void:
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
		_afuera.x + 6, _afuera.y - 6, _afuera.z])
	_pasar_a("esperar god lejos")


func _esperar_god_lejos() -> void:
	if not _cerca(_estado_god.mi_pos, _afuera, 3):
		print("El operador se aparto: no participa de la medicion.")
		_pos_control_inicial = _estado.mi_pos
		_pasar_a("control positivo")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el operador no se aparto del area de la casa")


# -----------------------------------------------------------------
#  CONTROL POSITIVO
# -----------------------------------------------------------------
## Sin esto, "no me movi" no significaria nada: lo produce igual una via de
## movimiento rota. Se exige UN desplazamiento ordinario que el servidor
## CONFIRME, sobre casillas que no son de ninguna casa.
func _control_positivo() -> void:
	if _estado.mi_pos != _pos_control_inicial:
		_movimiento_confirmado = true
		print("Control positivo: el servidor confirmo un desplazamiento ordinario.")
		_pasar_a("volver afuera")
		return
	if not _pidio or _espera > 3.0:
		_pidio = true
		_espera = 0.0
		# Se prueba en direcciones que se ALEJAN de la casa, para no gastar el
		# control positivo chocando contra el limite que se quiere medir.
		var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, -1)]
		_con.enviar_auto_camino([dirs[_dir_control % dirs.size()]])
		_dir_control += 1
		return
	if _dir_control > 8:
		_fallar("BLOCKED el participante no pudo dar ningun paso ordinario; sin control positivo la medicion no significa nada")


func _volver_afuera() -> void:
	if _estado.mi_pos == _afuera:
		if _propiedad_asignada:
			_pasar_a("medir con propiedad")
		else:
			_pasar_a("medir sin propiedad")
		return
	if not _pidio or _espera > 3.0:
		_pidio = true
		_espera = 0.0
		_caminar_hacia(_afuera)
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED el participante no volvio a la casilla exterior de partida")


# -----------------------------------------------------------------
#  MITAD A: sin propiedad
# -----------------------------------------------------------------
func _medir_sin_propiedad() -> void:
	_pos_antes = _estado.mi_pos
	_denegacion_vista = false
	_midiendo = "sin"
	print("Medicion A (sin propiedad): un desplazamiento ordinario hacia la casilla de la casa.")
	_con.enviar_auto_camino([_paso_al_limite()])
	_pasar_a("evaluar sin propiedad")


func _evaluar_sin_propiedad() -> void:
	if _espera < ESPERA_MEDICION:
		return
	_midiendo = ""
	_nego_sin_propiedad = _denegacion_vista
	# La posicion se lee del SERVIDOR, nunca de la prediccion local.
	_quedo_afuera = _estado.mi_pos == _pos_antes
	print("Medicion A: denegacion especifica=%s, quedo afuera=%s"
		% [str(_nego_sin_propiedad), str(_quedo_afuera)])
	if not _nego_sin_propiedad:
		_fallar("FAIL sin propiedad el servidor no emitio la respuesta especifica de falta de autorizacion; esta casilla no sirve como limite medible")
		return
	if not _quedo_afuera:
		_fallar("FAIL el servidor nego el acceso pero la posicion autoritativa cambio igual")
		return
	if not _sesion_continua or not _estado.adentro:
		_fallar("BLOCKED la sesion se cayo durante la medicion sin propiedad")
		return
	_pasar_a("god adentro")


# -----------------------------------------------------------------
#  MONTAJE: propiedad temporal
# -----------------------------------------------------------------
func _god_adentro() -> void:
	if not _pidio:
		_pidio = true
		print("El operador entra a la casa para poder asignar la propiedad.")
		_con_god.enviar_hablar("/gotopos %d,%d,%d" % [_adentro.x, _adentro.y, _adentro.z])
		return
	if _estado_god.mi_pos == _adentro:
		_pasar_a("verificar casa")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el operador no llego a la casilla interior")


## `/owner` actua sobre la casa donde esta PARADO el operador. Antes de
## mutar nada se confirma que esa casilla es de la casa de sandbox: asignar la
## casa equivocada seria una mutacion sobre estado ajeno.
func _verificar_casa() -> void:
	if not _pidio:
		_pidio = true
		_pedir_tileinfo(_estado_god.mi_pos)
		return
	if _tileinfo_de(_estado_god.mi_pos):
		if _ti_casa != _casa_id:
			_fallar("BLOCKED el operador esta parado sobre la casa %d y no sobre la de sandbox %d; no se asigna nada" % [_ti_casa, _casa_id])
			return
		print("Verificado: el operador esta dentro de la casa de sandbox.")
		_pasar_a("asignar")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED no se pudo verificar sobre que casa esta parado el operador")


func _asignar() -> void:
	if not _pidio:
		_pidio = true
		print("MONTAJE: se asigna la casa de sandbox al participante.")
		_con_god.enviar_hablar("/owner %s" % _nombre)
		return
	if _espera > 2.5:
		_propiedad_asignada = true
		_pasar_a("apartar god adentro")


## El operador se corre de la casilla del limite hacia el fondo de la casa: si
## se quedara encima, el participante chocaria con una CRIATURA y el rechazo no
## seria el de la regla de casa.
func _apartar_god_adentro() -> void:
	if not _pidio:
		_pidio = true
		_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
			_adentro.x, _adentro.y + 1, _adentro.z])
		return
	if _estado_god.mi_pos != _limite and _espera > 2.0:
		_pasar_a("volver afuera")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el operador no se aparto de la casilla del limite")


# -----------------------------------------------------------------
#  MITAD B: con propiedad
# -----------------------------------------------------------------
func _medir_con_propiedad() -> void:
	if _estado.mi_pos != _afuera:
		_pasar_a("volver afuera")
		return
	_pos_antes = _estado.mi_pos
	_denegacion_vista = false
	_midiendo = "con"
	print("Medicion B (con propiedad): el MISMO desplazamiento ordinario hacia la MISMA casilla.")
	_con.enviar_auto_camino([_paso_al_limite()])
	_pasar_a("evaluar con propiedad")


func _evaluar_con_propiedad() -> void:
	if _espera < ESPERA_MEDICION:
		return
	_midiendo = ""
	# Autoritativo: la posicion viene del servidor. El paso fue una orden de
	# movimiento ordinaria; en esta fase no se emitio ningun teletransporte
	# sobre el participante.
	_entro_con_propiedad = _estado.mi_pos == _limite
	print("Medicion B: entro=%s, denegacion especifica=%s"
		% [str(_entro_con_propiedad), str(_denegacion_vista)])
	if _denegacion_vista:
		_fallar("FAIL siendo dueno el servidor siguio emitiendo la respuesta de falta de autorizacion")
		return
	if not _entro_con_propiedad:
		_fallar("FAIL siendo dueno el participante no llego a la casilla de la casa")
		return
	if not _sesion_continua or not _estado.adentro:
		_fallar("BLOCKED la sesion se cayo durante la medicion con propiedad")
		return
	_construir_observacion()
	_pasar_a("sacar participante")


# -----------------------------------------------------------------
#  RESTAURACION
# -----------------------------------------------------------------
## El participante sale ANTES de devolver la casa. `House::setOwner` expulsa a
## quien este adentro teletransportandolo, y conviene que la salida sea un paso
## ordinario y no una expulsion.
func _sacar_participante() -> void:
	if _estado.mi_pos == _afuera:
		_pasar_a("devolver casa")
		return
	if not _pidio or _espera > 3.0:
		_pidio = true
		_espera = 0.0
		var p := _paso_al_limite()
		_con.enviar_auto_camino([Vector2i(-p.x, -p.y)])
		return
	if _espera > ESPERA_PASO:
		print("AVISO el participante no volvio solo a la casilla exterior; la devolucion de la casa lo reubicara igual")
		_pasar_a("devolver casa")


func _devolver_casa() -> void:
	if not _pidio:
		_pidio = true
		print("RESTAURACION: se devuelve la casa a SIN DUENO.")
		_con_god.enviar_hablar("/owner none")
		return
	if _espera > 2.5:
		_propiedad_asignada = false
		_pasar_a("god a la entrada")


func _god_a_la_entrada() -> void:
	if not _pidio:
		_pidio = true
		_con_god.enviar_hablar("/gotopos %d,%d,%d" % [_afuera.x, _afuera.y, _afuera.z])
		return
	if _estado_god.mi_pos == _afuera:
		_pasar_a("cerrar puerta")
		return
	if _espera > ESPERA_CORTA:
		print("AVISO el operador no volvio a la casilla exterior; se intenta cerrar la puerta igual")
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
		_emitir_observacion()
		return
	if _espera > ESPERA_CORTA:
		print("AVISO no se pudo verificar el estado final de la puerta")
		_emitir_observacion()


# -----------------------------------------------------------------
#  Observacion
# -----------------------------------------------------------------
func _construir_observacion() -> void:
	_obs = {
		"precondition": {
			"ordinary_movement_confirmed": _movimiento_confirmado,
			"session_remained_connected": _sesion_continua and _estado.adentro,
		},
		"without_ownership": {
			"house_access_denial_observed": _nego_sin_propiedad,
			"participant_remained_outside": _quedo_afuera,
		},
		"with_ownership": {
			"entry_allowed": _entro_con_propiedad,
		},
	}


func _emitir_observacion() -> void:
	if _obs.is_empty():
		_fallar("FAIL no se llego a construir ninguna observacion")
		return
	## Ningun nombre, cuenta, identidad de casa, coordenada, opcode, texto de
	## mensaje ni marca de tiempo. Solo relaciones.
	print("OBSERVATION_JSON: " + JSON.stringify(_obs))
	print("Captura de acceso del dueno: OK")
	_terminar(0)


# -----------------------------------------------------------------
#  Utilidades
# -----------------------------------------------------------------
func _paso_al_limite() -> Vector2i:
	return Vector2i(_limite.x - _afuera.x, _limite.y - _afuera.y)


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


## Ante cualquier fallo se intenta deshacer lo que este puesto, en orden
## inverso. Un fixture que aborta NO puede dejar una casa con dueno.
func _fallar(texto: String) -> void:
	print(texto)
	if _propiedad_asignada and _con_god != null:
		print("RESTAURACION de emergencia: se devuelve la casa a SIN DUENO.")
		_con_god.enviar_hablar("/gotopos %d,%d,%d" % [_adentro.x, _adentro.y, _adentro.z])
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
	await get_tree().create_timer(3.0).timeout
	if _con != null:
		_con.enviar_logout()
	if _con_god != null:
		_con_god.enviar_logout()
	await get_tree().create_timer(2.0).timeout
	if _con != null:
		_con.cerrar()
	if _con_god != null:
		_con_god.cerrar()
	await get_tree().create_timer(1.0).timeout
	print("EXITCODE=%d" % codigo)
	get_tree().quit(codigo)
