extends Node

# Captura QA-owned en vivo: RUTEO AUTORITATIVO DE CORREO de punta a punta
# (Phase 2F). Fixture `PARITY-PARCEL-DELIVERY-001`.
#
# Adaptador NUEVO y SEPARADO. `prueba_parcel_vivo.gd` es evidencia historica de
# implementacion y **no se toca ni se convierte** en el adaptador de paridad.
#
# Esta rama NO decide PASS/FAIL: lo hace `qa/parity/tools/replay.py` contra la
# `ParityExpectationV1` publicada. Este script solo observa y serializa.
#
# ---------------------------------------------------------------------------
# QUE PROPIEDAD ES NUEVA
# ---------------------------------------------------------------------------
#
# La ventana de texto, el contenedor y la persistencia del deposito son
# MECANISMOS DE APOYO y ya estan cubiertos por otros dominios. Lo que este
# fixture congela es distinto: que el servidor LEA UNA DIRECCION ESCRITA Y
# LLEVE EL OBJETO HASTA EL DEPOSITO DEL DESTINATARIO DIRECCIONADO.
#
# ---------------------------------------------------------------------------
# LA REGLA, VERIFICADA EN EL CODIGO VIGENTE DEL ORACLE
# ---------------------------------------------------------------------------
#
# `Mailbox::getReceiver` (`servidor/src/mailbox.cpp`):
#
#     - si el objeto es contenedor, busca adentro un item cuyo id sea
#       `ITEM_LABEL` y recurre sobre el;
#     - sobre la etiqueta, parte su texto POR LINEAS:
#         linea 1 -> nombre del destinatario
#         linea 2 -> nombre del PUEBLO
#       y le pasa `trimString` a las dos.
#
#   Esto importa y se verifico a proposito: la direccion NO es "nombre / pueblo"
#   en una sola linea. Tiene que ir en DOS LINEAS o el pueblo queda vacio.
#
# `Mailbox::sendItem`:
#
#     - resuelve el pueblo POR NOMBRE, sin distinguir mayusculas
#       (`Towns::getTown` usa `strcasecmp`, `servidor/src/town.h:56-63`);
#     - si el destinatario esta ONLINE: `getDepotLocker(town->getID(), true)` y
#       mueve la encomienda ahi;
#     - si esta OFFLINE: arma un `Player` temporal, lo carga con
#       `IOLoginData::loadPlayerByName`, obtiene el mismo locker, mueve la
#       encomienda y **guarda el archivo del destinatario**;
#     - en los dos casos `transformItem(item, item->getID() + 1)`, asi que lo
#       que queda en el deposito es la encomienda SELLADA, no la original.
#
#   El destino del movimiento es el LOCKER, no el cofre de adentro: la
#   encomienda entregada queda como HERMANA del cofre de deposito. Por eso la
#   medicion del destinatario se hace al nivel del locker.
#
#   `sendItem` no consulta NADA del remitente: ni su grupo, ni sus permisos.
#   El ruteo depende solo de la etiqueta y del destinatario, asi que usar al
#   operador como remitente no cambia la semantica.
#
# `Mailbox::canSend` acepta unicamente `ITEM_PARCEL` o `ITEM_LETTER`.
#
# `Mailbox::addThing` tiene una guarda que descarta el envio si la casilla
# tiene mas de un objeto movible, pero solo cuando `trashableMailbox` es falso;
# en `servidor/config.lua` esta en **true**, asi que los residuos historicos de
# la casilla no bloquean el envio. Se verifico antes de disenar la corrida.
#
# ---------------------------------------------------------------------------
# EL ARREGLO HISTORICO DEL SERVIDOR, VERIFICADO VIGENTE
# ---------------------------------------------------------------------------
#
# `docs/qa/PRUEBA_VIVA_PARCEL.md` documenta que los items escribibles eran
# rechazados antes de llegar a `Actions::internalUseItem`, lo que dejaba el
# correo entero inutilizable. La guarda actual de `servidor/src/game.cpp`
# incluye `&& !useItemType.canReadText`, o sea que el arreglo **sigue puesto**.
# Si hubiera regresado, esta captura devuelve BLOCKED: QA no repara el oracle
# para poder certificarlo.
#
# ---------------------------------------------------------------------------
# DISENO FUERTE: EL DESTINATARIO ESTA DESCONECTADO AL ENVIAR
# ---------------------------------------------------------------------------
#
# El destinatario toma su linea base, CIERRA su sesion de verdad, y recien
# entonces el remitente manda la encomienda. Asi el buzon no puede limitarse a
# entregarsela a un objeto de jugador que ya estaba vivo en memoria: tiene que
# recorrer el camino offline, que carga y vuelve a guardar el archivo del
# destinatario. Despues el destinatario abre una sesion NUEVA y encuentra la
# encomienda.
#
# Esto es una GUARDA DEL HARNESS, no una asercion congelada: la evidencia
# historica no demuestra el caso offline, asi que no se afirma como hecho
# grabado por mas que la corrida viva sea mas fuerte.
#
# ---------------------------------------------------------------------------
# NADA SE DA POR BUENO SIN VOLVER A LEERLO
# ---------------------------------------------------------------------------
#
#   - la direccion no se da por escrita porque se mando el `0x89`: se vuelve a
#     abrir la etiqueta y se exige que el servidor devuelva EXACTAMENTE el
#     mismo texto;
#   - la aceptacion del buzon no se da por buena porque el movimiento no diera
#     error: se exige que la encomienda DEJE de estar en la casilla, medido
#     contra una linea base tomada antes, para que una encomienda vieja apoyada
#     ahi no pase por resultado nuevo;
#   - la entrega no se da por buena por ver una encomienda cualquiera: se
#     compara contra la linea base del deposito del destinatario.
#
# ---------------------------------------------------------------------------
# CREDENCIALES: SOLO POR ENTORNO, NUNCA LITERALES, NUNCA IMPRESAS
# ---------------------------------------------------------------------------
#   TVP772_GOD_ACCOUNT        MAIL_SENDER y operador
#   TVP772_GOD_PASSWORD
#   TVP772_GOD_CHARACTER
#   TVP772_PLAYER2_ACCOUNT    MAIL_RECIPIENT (personaje dedicado de QA, distinto)
#   TVP772_PLAYER2_PASSWORD
#   TVP772_PLAYER2_CHARACTER
# Opcionales:
#   TVP772_HOST, TVP772_LOGIN_PORT
#   TVP772_MAIL_TOWN          pueblo de destino (def. "Thais")
#
#   ...Godot --headless --path cliente3d \
#       pruebas/prueba_parity_parcel_delivery_capture.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

## Geometria operativa de Thais. METADATA DEL HARNESS: nunca entra al payload.
const POS_LOCKER := Vector3i(32354, 32231, 7)
const POS_BALDOSA := Vector3i(32354, 32230, 7)
const POS_MAILBOX := Vector3i(32372, 32253, 7)
const POS_JUNTO_MAILBOX := Vector3i(32372, 32252, 7)
const POS_GOD_NEUTRAL := Vector3i(32369, 32241, 7)

const SLOT_MOCHILA := 3
## La encomienda de prueba se apoya en el SUELO, en la casilla del propio
## operador, no en una mano.
##
## Motivo verificado en vivo: el operador lleva un arma de DOS MANOS, asi que
## el servidor rechaza ocupar la otra mano con "Drop the double-handed object
## first". Desequipar el arma del operador seria tocar el equipo de un
## personaje que este turno no debe modificar. El suelo da exactamente lo que
## hacia falta -una posicion estable que no depende de indices de contenedor-
## sin mover nada ajeno.

## Ventanas de contenedor del CLIENTE. Implementacion del harness, NO semantica
## de paridad.
const VENTANA_MOCHILA := 0
const VENTANA_LOCKER := 1
const VENTANA_COFRE := 2
const VENTANA_PARCEL := 3

## Nombres que publica el propio catalogo del cliente. Son metadata del harness:
## el fixture no congela ninguna especie ni ningun id.
const NOMBRE_PARCEL := "parcel"
const NOMBRE_PARCEL_ENTREGADA := "stamped parcel"
const NOMBRE_ETIQUETA := "label"

const MAX_INTENTOS_CAMINATA := 6
const PAUSA_SESION := 8.0
const ESPERA_PASO := 25.0
const ESPERA_CORTA := 12.0
const ESPERA_ITEM := 10.0
const LIMITE_TOTAL := 720.0

var _con_login
var _con_god
var _con_dest
var _estado_god
var _estado_dest
var _puerto_god := 0
var _puerto_dest := 0
var _fase := "login"
var _espera := 0.0
var _total := 0.0
var _terminando := false

var _cuenta_god := 0
var _clave_god := ""
var _nombre_god := ""
var _cuenta_dest := 0
var _clave_dest := ""
var _nombre_dest := ""
var _host := ""
var _puerto_login := 0
var _ciudad := "Thais"

var _segunda_sesion := false
var _sesion_dest_cerrada := false
var _sesion_dest_nueva := false

## Contenedores del destinatario (ids por sesion).
var _id_locker := -1
var _id_cofre_presente := false
var _ids_dest := {}
var _avisos_depot := 0
var _base_encomiendas := -1

## Contenedores y objetos del operador.
var _ids_god := {}
var _id_mochila := -1
var _id_parcel := -1
var _cid_parcel := 0
var _cid_etiqueta := 0
var _pos_etiqueta := Vector3i.ZERO
var _mochila_antes := -1
var _stack_parcel := -1
var _base_casilla_suelo := -1
var _base_casilla_buzon := -1
var _ventana := {}
var _direccion := ""
var _escribio := false
var _releyo := false

## Descubrimiento empirico de la casilla de salida del destinatario.
var _intentos_caminata := 0
var _indice_candidato := 0
var _pidio := false

## Hechos normalizados.
var _ventana_abierta := false
var _direccion_coincide := false
var _etiqueta_adentro := false
var _buzon_presente := false
var _encomienda_consumida := false
var _deposito_recibio := false
## Guarda viva extra, NO congelada: la etiqueta de la encomienda entregada.
var _etiqueta_entregada_coincide := false

var _obs := {}


func _ready() -> void:
	print("=========================================================")
	print(" TVP3D QA - captura en vivo: entrega de correo")
	print("=========================================================")
	var requeridas := ["TVP772_GOD_ACCOUNT", "TVP772_GOD_PASSWORD",
		"TVP772_GOD_CHARACTER", "TVP772_PLAYER2_ACCOUNT",
		"TVP772_PLAYER2_PASSWORD", "TVP772_PLAYER2_CHARACTER"]
	if not CREDENCIALES.exigir(self, requeridas):
		return
	_host = CREDENCIALES.host()
	_puerto_login = CREDENCIALES.puerto_login()
	_cuenta_god = CREDENCIALES.entero("TVP772_GOD_ACCOUNT")
	_clave_god = CREDENCIALES.texto("TVP772_GOD_PASSWORD")
	_nombre_god = CREDENCIALES.texto("TVP772_GOD_CHARACTER")
	_cuenta_dest = CREDENCIALES.entero("TVP772_PLAYER2_ACCOUNT")
	_clave_dest = CREDENCIALES.texto("TVP772_PLAYER2_PASSWORD")
	_nombre_dest = CREDENCIALES.texto("TVP772_PLAYER2_CHARACTER")
	var ciudad_env := CREDENCIALES.texto("TVP772_MAIL_TOWN")
	if not ciudad_env.is_empty():
		_ciudad = ciudad_env
	if _nombre_god == _nombre_dest:
		print("BLOCKED el remitente y el destinatario no pueden ser el mismo personaje")
		get_tree().quit(2)
		return
	# `Mailbox::getReceiver` parte el texto POR LINEAS: destinatario y pueblo.
	_direccion = "%s\n%s" % [_nombre_dest, _ciudad]
	_abrir_login_god()


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
				print("Operador dentro; abriendo la sesion del destinatario.")
				_abrir_destinatario()
				_pasar_a("esperar destinatario")
		"esperar destinatario":
			if _espera > ESPERA_PASO:
				_fallar("BLOCKED el destinatario no entro al mundo")
		"god al deposito":
			_god_al_deposito()
		"esperar god deposito":
			if _cerca(_estado_god.mi_pos, POS_BALDOSA, 0):
				_traer_destinatario()
			elif _espera > ESPERA_CORTA:
				_fallar("BLOCKED el operador no llego a la casilla del deposito")
		"esperar destinatario cerca":
			_esperar_destinatario_cerca()
		"apartar god":
			_apartar_god()
		"esperar god lejos":
			_esperar_god_lejos()
		"salir de la baldosa":
			_salir_de_la_baldosa()
		"entrar a la baldosa":
			_entrar_a_la_baldosa()
		"confirmar deposito":
			_confirmar_deposito()
		"abrir locker":
			_abrir_locker()
		"medir base":
			_medir_base()
		"cerrar destinatario":
			_cerrar_destinatario()
		"pausa reingreso":
			if _espera >= PAUSA_SESION:
				_ir_al_buzon()
		"esperar god buzon":
			_esperar_god_buzon()
		"abrir mochila god":
			_abrir_mochila_god()
		"crear parcel":
			_crear_parcel()
		"parcel al suelo":
			_parcel_al_suelo()
		"crear etiqueta":
			_crear_etiqueta()
		"usar etiqueta":
			_usar_etiqueta()
		"escribir direccion":
			_escribir_direccion()
		"abrir parcel":
			_abrir_parcel()
		"meter etiqueta":
			_meter_etiqueta()
		"despachar":
			_despachar()
		"verificar despacho":
			_verificar_despacho()
		"reentrar destinatario":
			_reentrar_destinatario()
		"esperar destinatario nuevo":
			if _espera > ESPERA_PASO:
				_fallar("BLOCKED el destinatario no entro al mundo en la sesion nueva")
		"medir entrega":
			_medir_entrega()
		"leer etiqueta entregada":
			_leer_etiqueta_entregada()


# -----------------------------------------------------------------
#  Sesiones
# -----------------------------------------------------------------
func _abrir_login_god() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.error_red.connect(func(t): _fallar("FAIL fallo de red en login del operador: %s" % t))
	_con_login.lista_personajes.connect(func(_m, lista):
		for entrada in lista:
			if str(entrada.get("nombre", "")) == _nombre_god:
				_puerto_god = int(entrada.get("puerto", 0))
		if _puerto_god <= 0:
			_fallar("FAIL character configured by TVP772_GOD_CHARACTER was not found")
			return
		_con_login.cerrar()
		_abrir_login_destinatario())
	_con_login.pedir_personajes(_host, _puerto_login, _cuenta_god, _clave_god)


func _abrir_login_destinatario() -> void:
	var login = CONEXION.new()
	add_child(login)
	login.error_red.connect(func(t): _fallar("FAIL fallo de red en login del destinatario: %s" % t))
	login.lista_personajes.connect(func(_m, lista):
		for entrada in lista:
			if str(entrada.get("nombre", "")) == _nombre_dest:
				_puerto_dest = int(entrada.get("puerto", 0))
		if _puerto_dest <= 0:
			_fallar("FAIL character configured by TVP772_PLAYER2_CHARACTER was not found")
			return
		login.cerrar()
		_abrir_god())
	login.pedir_personajes(_host, _puerto_login, _cuenta_dest, _clave_dest)


func _abrir_god() -> void:
	_estado_god = ESTADO.new()
	_estado_god.pedido_ping.connect(func(): _con_god.enviar_juego(PackedByteArray([0x1E])))
	_estado_god.rechazados.connect(func(m): _fallar("FAIL el operador fue rechazado: %s" % m))
	_estado_god.mensaje_servidor.connect(func(t): print("  [ope] %s" % t))
	_estado_god.contenedor_actualizado.connect(func(id, datos):
		if not _ids_god.has(id):
			_ids_god[id] = str(datos.get("nombre", ""))
			print("  [ope] contenedor %d: '%s' con %d cosas."
				% [id, str(datos.get("nombre", "")),
					(datos.get("items", []) as Array).size()]))
	_estado_god.ventana_texto.connect(func(datos): _ventana = datos)
	_con_god = CONEXION.new()
	add_child(_con_god)
	_con_god.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red del operador: %s" % t))
	_con_god.paquete_juego.connect(func(m): _estado_god.procesar(m))
	_con_god.entrar_al_mundo(_host, _puerto_god, _cuenta_god, _nombre_god, _clave_god)
	_pasar_a("esperar god")


func _abrir_destinatario() -> void:
	_estado_dest = ESTADO.new()
	_estado_dest.pedido_ping.connect(func(): _con_dest.enviar_juego(PackedByteArray([0x1E])))
	_estado_dest.rechazados.connect(func(m): _fallar("FAIL el destinatario fue rechazado: %s" % m))
	_estado_dest.mensaje_servidor.connect(func(t):
		print("  [dst] %s" % t)
		if t.begins_with("Your depot contains"):
			_avisos_depot += 1)
	_estado_dest.contenedor_actualizado.connect(func(id, datos):
		if not _ids_dest.has(id):
			_ids_dest[id] = str(datos.get("nombre", ""))
			print("  [dst] contenedor %d: '%s' con %d cosas."
				% [id, str(datos.get("nombre", "")),
					(datos.get("items", []) as Array).size()]))
	_estado_dest.ventana_texto.connect(func(datos): _ventana = datos)
	_estado_dest.entramos.connect(_al_entrar_destinatario)
	_con_dest = CONEXION.new()
	add_child(_con_dest)
	_con_dest.error_red.connect(func(t):
		if _fase != "cerrar destinatario" and not _terminando:
			_fallar("FAIL fallo de red del destinatario: %s" % t))
	_con_dest.paquete_juego.connect(func(m): _estado_dest.procesar(m))
	_con_dest.cerrada.connect(_al_cerrarse_destinatario)
	_con_dest.entrar_al_mundo(_host, _puerto_dest, _cuenta_dest, _nombre_dest, _clave_dest)


func _al_entrar_destinatario() -> void:
	if not _segunda_sesion:
		print("Sesion 1 del destinatario establecida.")
		_pasar_a("god al deposito")
		return
	_sesion_dest_nueva = true
	print("Sesion NUEVA del destinatario establecida, despues del envio.")
	_pasar_a("god al deposito")


func _al_cerrarse_destinatario() -> void:
	if _terminando or _segunda_sesion:
		return
	_segunda_sesion = true
	_sesion_dest_cerrada = true
	print("Sesion del destinatario CERRADA: queda desconectado mientras se envia.")
	_pasar_a("pausa reingreso")


# -----------------------------------------------------------------
#  Posicionamiento del destinatario en su deposito
# -----------------------------------------------------------------
func _god_al_deposito() -> void:
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
		POS_BALDOSA.x, POS_BALDOSA.y, POS_BALDOSA.z])
	_pasar_a("esperar god deposito")


func _traer_destinatario() -> void:
	print("El operador trae al destinatario al area del deposito.")
	_con_god.enviar_hablar("/c %s" % _nombre_dest)
	_pasar_a("esperar destinatario cerca")


func _esperar_destinatario_cerca() -> void:
	if _estado_dest == null or not _estado_dest.adentro:
		if _espera > ESPERA_PASO:
			_fallar("BLOCKED el destinatario no estaba en el mundo para posicionarlo")
		return
	if _cerca(_estado_dest.mi_pos, POS_BALDOSA, 2):
		_pasar_a("apartar god")
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED el destinatario no llego al area del deposito")


func _apartar_god() -> void:
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
		POS_GOD_NEUTRAL.x, POS_GOD_NEUTRAL.y, POS_GOD_NEUTRAL.z])
	_pasar_a("esperar god lejos")


func _esperar_god_lejos() -> void:
	if _estado_god != null and not _cerca(_estado_god.mi_pos, POS_BALDOSA, 3):
		_avisos_depot = 0
		_pasar_a("salir de la baldosa")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el operador no se aparto del area del deposito")


## Leccion de Phase 2C.1 y Phase 2E: alcanzable con `/gotopos` de un god NO es
## lo mismo que caminable por un personaje normal. La casilla de salida se
## descubre empiricamente entre las vecinas, no se hereda de una constante.
func _salir_de_la_baldosa() -> void:
	if _estado_dest == null or not _estado_dest.adentro:
		if _espera > ESPERA_PASO:
			_fallar("BLOCKED el destinatario no esta en el mundo")
		return
	if _estado_dest.mi_pos != POS_BALDOSA:
		_pasar_a("entrar a la baldosa")
		return
	var candidatos := _candidatos_fuera()
	if _indice_candidato >= candidatos.size():
		_fallar("BLOCKED ninguna casilla vecina de la baldosa resulto caminable")
		return
	if _reintentar_caminata(candidatos[_indice_candidato]):
		return
	_indice_candidato += 1
	_intentos_caminata = 0


func _candidatos_fuera() -> Array:
	return [
		POS_BALDOSA + Vector3i(0, -1, 0),
		POS_BALDOSA + Vector3i(-1, 0, 0),
		POS_BALDOSA + Vector3i(1, 0, 0),
		POS_BALDOSA + Vector3i(-1, -1, 0),
		POS_BALDOSA + Vector3i(1, -1, 0),
		POS_BALDOSA + Vector3i(-1, 1, 0),
		POS_BALDOSA + Vector3i(1, 1, 0),
	]


func _entrar_a_la_baldosa() -> void:
	if _estado_dest.mi_pos == POS_BALDOSA:
		_pasar_a("confirmar deposito")
		return
	if _reintentar_caminata(POS_BALDOSA):
		return
	_fallar("BLOCKED el destinatario no pudo entrar a la baldosa de activacion")


func _confirmar_deposito() -> void:
	if _avisos_depot > 0:
		print("El servidor confirmo la carga del deposito PERSONAL del destinatario.")
		_pasar_a("abrir locker")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el servidor no confirmo la carga del deposito personal del destinatario")


## La encomienda entregada queda al nivel del LOCKER, hermana del cofre, porque
## `Mailbox::sendItem` mueve al `DepotLocker` y no al cofre de adentro. Por eso
## se cuenta ahi. El cofre se sigue exigiendo como prueba de que el deposito es
## el PERSONAL y no el mueble del mapa.
func _abrir_locker() -> void:
	if _id_locker >= 0:
		if not _id_cofre_presente:
			for cosa in _items_de(_estado_dest, _id_locker):
				if str(cosa.get("nombre", "")).to_lower().contains("depot"):
					_id_cofre_presente = true
					break
		if not _id_cofre_presente:
			if _espera > ESPERA_CORTA:
				_fallar("BLOCKED el mueble abierto no trae el cofre del deposito; podria ser el contenedor del mapa")
			return
		_pasar_a("medir entrega" if _segunda_sesion else "medir base")
		return
	if _pidio:
		_id_locker = _primer_id_nuevo(_ids_dest, [])
		if _id_locker < 0 and _espera > ESPERA_CORTA:
			_fallar("BLOCKED el servidor no abrio el mueble del deposito del destinatario")
		return
	var pila := _buscar_locker()
	if pila < 0:
		if _espera > ESPERA_CORTA:
			_fallar("BLOCKED no aparece el mueble del deposito en la casilla operativa")
		return
	_pidio = true
	var cosa: Dictionary = _estado_dest.casillas[POS_LOCKER][pila]
	print("Abriendo el mueble del deposito del destinatario.")
	_con_dest.enviar_usar_item(POS_LOCKER, int(cosa.get("cid", 0)), pila, VENTANA_LOCKER)


func _medir_base() -> void:
	_base_encomiendas = _contar_entregadas(_estado_dest, _id_locker)
	print("Linea base del deposito del destinatario: %d encomiendas entregadas."
		% _base_encomiendas)
	_pasar_a("cerrar destinatario")


## Cierre REAL de la sesion del destinatario. El envio ocurre con el
## destinatario DESCONECTADO, asi el buzon tiene que recorrer el camino offline.
func _cerrar_destinatario() -> void:
	if not _pidio:
		_pidio = true
		print("Cerrando la sesion del destinatario ANTES de enviar.")
		_con_dest.enviar_logout()
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED el servidor no cerro la sesion del destinatario")


# -----------------------------------------------------------------
#  Envio: operador junto al buzon
# -----------------------------------------------------------------
func _ir_al_buzon() -> void:
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
		POS_JUNTO_MAILBOX.x, POS_JUNTO_MAILBOX.y, POS_JUNTO_MAILBOX.z])
	_pasar_a("esperar god buzon")


func _esperar_god_buzon() -> void:
	if not _cerca(_estado_god.mi_pos, POS_JUNTO_MAILBOX, 1):
		if _espera > ESPERA_CORTA:
			_fallar("BLOCKED el operador no llego junto al buzon")
		return
	var cosas: Array = _estado_god.casillas.get(POS_MAILBOX, [])
	if cosas.is_empty():
		if _espera > ESPERA_CORTA:
			_fallar("BLOCKED el cliente no ve nada en la casilla del buzon")
		return
	_buzon_presente = true
	_base_casilla_buzon = _contar_encomiendas_en(POS_MAILBOX)
	_base_casilla_suelo = _contar_encomiendas_en(_pos_suelo())
	if _base_casilla_suelo != 0:
		_fallar("BLOCKED la casilla operativa del remitente ya tiene una encomienda apoyada; no se mide sobre suciedad")
		return
	print("Buzon visible. Encomiendas ya apoyadas en su casilla: %d (residuo historico, no se toca)."
		% _base_casilla_buzon)
	_pasar_a("abrir mochila god")


func _abrir_mochila_god() -> void:
	if _id_mochila >= 0:
		_pasar_a("crear parcel")
		return
	if _pidio:
		_id_mochila = _primer_id_nuevo(_ids_god, [])
		if _id_mochila < 0 and _espera > ESPERA_CORTA:
			_fallar("BLOCKED el servidor no abrio la mochila del operador")
		return
	_pidio = true
	var mochila: Dictionary = _estado_god.inventario.get(SLOT_MOCHILA, {})
	if mochila.is_empty():
		_fallar("BLOCKED el operador no tiene mochila en la ranura esperada")
		return
	_con_god.enviar_usar_inventario(SLOT_MOCHILA, int(mochila.get("cid", 0)))


## Los dos `/i` van SEPARADOS y cada uno se espera contra el estado
## autoritativo: la evidencia historica encontro que dos ordenes en el mismo
## instante pueden perder una.
func _crear_parcel() -> void:
	if not _pidio:
		_pidio = true
		_mochila_antes = _items_de(_estado_god, _id_mochila).size()
		print("Creando UNA encomienda de prueba.")
		_con_god.enviar_hablar("/i %d" % _id_servidor_parcel())
		return
	var ahora := _items_de(_estado_god, _id_mochila)
	if ahora.size() == _mochila_antes + 1:
		var primera: Dictionary = ahora[0]
		if str(primera.get("nombre", "")).to_lower() != NOMBRE_PARCEL:
			_fallar("BLOCKED lo que aparecio en la mochila del operador no es la encomienda esperada")
			return
		_cid_parcel = int(primera.get("cid", 0))
		print("Encomienda creada; apoyandola en el suelo para que su posicion no dependa de indices.")
		_con_god.enviar_mover_ubicacion(
			Vector3i(0xFFFF, 0x40 | _id_mochila, 0), _cid_parcel, 0, _pos_suelo())
		_pasar_a("parcel al suelo")
		return
	if _espera > ESPERA_ITEM:
		_fallar("BLOCKED la encomienda de prueba no aparecio en la mochila del operador")


func _parcel_al_suelo() -> void:
	_stack_parcel = _stack_de_encomienda(_pos_suelo())
	if _stack_parcel >= 0:
		print("Encomienda apoyada en la casilla operativa del remitente.")
		_pasar_a("crear etiqueta")
		return
	if _espera > ESPERA_ITEM:
		_fallar("BLOCKED la encomienda no quedo apoyada en la casilla operativa")


func _crear_etiqueta() -> void:
	if not _pidio:
		_pidio = true
		_mochila_antes = _items_de(_estado_god, _id_mochila).size()
		print("Creando UNA etiqueta de direccion en blanco.")
		_con_god.enviar_hablar("/i %d" % _id_servidor_etiqueta())
		return
	var indice := _indice_por_nombre(_estado_god, _id_mochila, NOMBRE_ETIQUETA)
	if indice >= 0:
		var cosa: Dictionary = _items_de(_estado_god, _id_mochila)[indice]
		_cid_etiqueta = int(cosa.get("cid", 0))
		_pos_etiqueta = Vector3i(0xFFFF, 0x40 | _id_mochila, indice)
		print("Etiqueta creada dentro de la mochila del operador.")
		_pasar_a("usar etiqueta")
		return
	if _espera > ESPERA_ITEM:
		_fallar("BLOCKED la etiqueta de prueba no aparecio en la mochila del operador")


func _usar_etiqueta() -> void:
	if not _pidio:
		_pidio = true
		_ventana = {}
		print("Usando la etiqueta para que el servidor abra su ventana de texto.")
		_con_god.enviar_usar_item(_pos_etiqueta, _cid_etiqueta, 0, VENTANA_PARCEL)
		return
	if not _ventana.is_empty() and int(_ventana.get("id", 0)) > 0:
		_ventana_abierta = true
		print("Ventana de texto recibida del servidor.")
		_pasar_a("escribir direccion")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el servidor no abrio la ventana de texto de la etiqueta; si volvio a rechazar el objeto, la guarda de items legibles regreso y QA no repara el oracle")


## La direccion NO se da por escrita porque se mando el paquete: se vuelve a
## abrir la etiqueta y se exige que el servidor devuelva exactamente lo mismo.
func _escribir_direccion() -> void:
	if not _escribio:
		_escribio = true
		_con_god.enviar_texto_ventana(int(_ventana.get("id", 0)), _direccion)
		_espera = 0.0
		return
	if not _releyo and _espera > 2.0:
		_releyo = true
		_ventana = {}
		_con_god.enviar_usar_item(_pos_etiqueta, _cid_etiqueta, 0, VENTANA_PARCEL)
		_espera = 0.0
		return
	if _releyo and not _ventana.is_empty() and int(_ventana.get("id", 0)) > 0:
		var guardado := str(_ventana.get("texto", ""))
		_direccion_coincide = guardado == _direccion
		print("Relectura de la etiqueta: el texto guardado coincide con el escrito = %s"
			% str(_direccion_coincide))
		if not _direccion_coincide:
			_fallar("FAIL el servidor no devolvio la direccion que se escribio")
			return
		_pasar_a("abrir parcel")
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED no se pudo releer la etiqueta escrita")


func _abrir_parcel() -> void:
	if _id_parcel >= 0:
		_pasar_a("meter etiqueta")
		return
	if _pidio:
		_id_parcel = _primer_id_nuevo(_ids_god, [_id_mochila])
		if _id_parcel < 0 and _espera > ESPERA_CORTA:
			_fallar("BLOCKED el servidor no abrio la encomienda de prueba")
		return
	_pidio = true
	_stack_parcel = _stack_de_encomienda(_pos_suelo())
	if _stack_parcel < 0:
		_fallar("BLOCKED la encomienda ya no esta en la casilla operativa")
		return
	print("Abriendo la encomienda de prueba desde el suelo.")
	_con_god.enviar_usar_item(_pos_suelo(), _cid_parcel, _stack_parcel, VENTANA_PARCEL)


## Se mete LA ETIQUETA QUE SE ESCRIBIO, resuelta por su identidad de proceso, no
## la primera etiqueta que aparezca.
func _meter_etiqueta() -> void:
	if not _pidio:
		_pidio = true
		var indice := _indice_por_cid(_estado_god, _id_mochila, _cid_etiqueta)
		if indice < 0:
			_fallar("BLOCKED la etiqueta escrita ya no esta donde se la dejo")
			return
		print("Metiendo la etiqueta escrita dentro de la encomienda.")
		_con_god.enviar_mover_ubicacion(
			Vector3i(0xFFFF, 0x40 | _id_mochila, indice), _cid_etiqueta, 0,
			Vector3i(0xFFFF, 0x40 | _id_parcel, 0))
		return
	if _indice_por_cid(_estado_god, _id_parcel, _cid_etiqueta) >= 0:
		_etiqueta_adentro = true
		print("La etiqueta escrita quedo dentro de la encomienda.")
		_pasar_a("despachar")
		return
	if _espera > ESPERA_ITEM:
		_fallar("FAIL la etiqueta escrita no entro en la encomienda")


func _despachar() -> void:
	if not _pidio:
		_pidio = true
		_stack_parcel = _stack_de_encomienda(_pos_suelo())
		if _stack_parcel < 0:
			_fallar("BLOCKED la encomienda ya no esta en la casilla operativa para despacharla")
			return
		print("Dejando la encomienda sobre la casilla del buzon.")
		_con_god.enviar_mover_ubicacion(_pos_suelo(), _cid_parcel, _stack_parcel,
			POS_MAILBOX)
		return
	if _espera > 2.0:
		_pasar_a("verificar despacho")


## El buzon se queda con la encomienda: tiene que salir de la mano del
## remitente Y no quedar apoyada como residuo nuevo en la casilla.
func _verificar_despacho() -> void:
	var salio: bool = _contar_encomiendas_en(_pos_suelo()) == _base_casilla_suelo
	var en_casilla := _contar_encomiendas_en(POS_MAILBOX)
	print("Tras el despacho: la encomienda salio de la casilla del remitente = %s; encomiendas en la casilla del buzon = %d (linea base %d)."
		% [str(salio), en_casilla, _base_casilla_buzon])
	if not salio:
		if _espera > ESPERA_ITEM:
			_fallar("FAIL la encomienda no salio de la posesion del remitente")
		return
	if en_casilla > _base_casilla_buzon:
		if _espera > ESPERA_ITEM:
			_fallar("FAIL la encomienda quedo apoyada en la casilla del buzon en vez de ser aceptada")
		return
	_encomienda_consumida = true
	print("El buzon se llevo la encomienda.")
	_pasar_a("reentrar destinatario")


# -----------------------------------------------------------------
#  Sesion nueva del destinatario y prueba de entrega
# -----------------------------------------------------------------
func _reentrar_destinatario() -> void:
	if _con_dest != null:
		_con_dest.queue_free()
		_con_dest = null
	_estado_dest = null
	_id_locker = -1
	_id_cofre_presente = false
	_ids_dest = {}
	_avisos_depot = 0
	_indice_candidato = 0
	print("Abriendo una sesion NUEVA del destinatario para ver si le llego.")
	_abrir_destinatario()
	_pasar_a("esperar destinatario nuevo")


func _medir_entrega() -> void:
	var ahora := _contar_entregadas(_estado_dest, _id_locker)
	print("Deposito del destinatario tras el envio: %d encomiendas entregadas (linea base %d)."
		% [ahora, _base_encomiendas])
	if ahora != _base_encomiendas + 1:
		if _espera > ESPERA_CORTA:
			_fallar("FAIL el deposito del destinatario no sumo exactamente una encomienda entregada")
		return
	_deposito_recibio = true
	print("LA ENCOMIENDA LLEGO AL DEPOSITO DEL DESTINATARIO DIRECCIONADO.")
	_construir_observacion()
	_pasar_a("leer etiqueta entregada")


## Guarda VIVA extra, NO congelada: se abre la encomienda entregada y se lee la
## etiqueta de adentro. La evidencia historica no demuestra esta lectura, asi
## que no entra al payload; se reporta como corroboracion causal.
func _leer_etiqueta_entregada() -> void:
	if not _pidio:
		_pidio = true
		var indice := _indice_por_nombre(_estado_dest, _id_locker, NOMBRE_PARCEL_ENTREGADA)
		if indice < 0:
			print("Aviso: no se pudo ubicar la encomienda entregada para la guarda extra.")
			_emitir_observacion()
			return
		var cosa: Dictionary = _items_de(_estado_dest, _id_locker)[indice]
		_ventana = {}
		_con_dest.enviar_usar_item(Vector3i(0xFFFF, 0x40 | _id_locker, indice),
			int(cosa.get("cid", 0)), 0, VENTANA_PARCEL)
		return
	if _espera > 3.0:
		var id_entregada := _primer_id_nuevo(_ids_dest, [_id_locker])
		if id_entregada >= 0:
			var indice := _indice_por_nombre(_estado_dest, id_entregada, NOMBRE_ETIQUETA)
			if indice >= 0:
				print("La encomienda entregada trae la etiqueta de direccion adentro.")
				_etiqueta_entregada_coincide = true
		print("Guarda viva extra (no congelada): etiqueta hallada dentro de la encomienda entregada = %s"
			% str(_etiqueta_entregada_coincide))
		_emitir_observacion()


func _construir_observacion() -> void:
	_obs = {
		"addressing": {
			"text_window_opened": _ventana_abierta,
			"address_roundtrip_matches": _direccion_coincide,
		},
		"parcel": {
			"written_label_inserted": _etiqueta_adentro,
		},
		"mailbox": {
			"mailbox_present": _buzon_presente,
			"submitted_parcel_consumed": _encomienda_consumida,
		},
		"delivery": {
			"recipient_depot_received_parcel": _deposito_recibio,
		},
	}


func _emitir_observacion() -> void:
	## Ningun nombre, cuenta, texto de direccion, pueblo, coordenada, id de
	## item, id de runtime, cantidad absoluta, indice de ventana ni ruta de
	## archivo. Solo relaciones.
	print("OBSERVATION_JSON: " + JSON.stringify(_obs))
	print("Captura de entrega de correo: OK")
	_terminar(0)


# -----------------------------------------------------------------
#  Utilidades
# -----------------------------------------------------------------
func _id_servidor_parcel() -> int:
	return 2595


func _id_servidor_etiqueta() -> int:
	return 2599


## Casilla operativa del remitente: la que pisa el propio operador.
func _pos_suelo() -> Vector3i:
	return _estado_god.mi_pos


func _contar_encomiendas_en(donde: Vector3i) -> int:
	var total := 0
	for cosa in _estado_god.casillas.get(donde, []):
		var nombre := str(cosa.get("nombre", "")).to_lower()
		if nombre == NOMBRE_PARCEL or nombre == NOMBRE_PARCEL_ENTREGADA:
			total += 1
	return total


## Indice de pila de LA encomienda de prueba en una casilla. Se exige que haya
## exactamente una: si hubiera dos, la identidad seria ambigua y no se mide.
func _stack_de_encomienda(donde: Vector3i) -> int:
	var encontrado := -1
	var pila := 0
	for cosa in _estado_god.casillas.get(donde, []):
		if int(cosa.get("cid", 0)) == _cid_parcel:
			if encontrado >= 0:
				return -1
			encontrado = pila
		pila += 1
	return encontrado


func _contar_entregadas(estado, id_contenedor: int) -> int:
	var total := 0
	for cosa in _items_de(estado, id_contenedor):
		if str(cosa.get("nombre", "")).to_lower() == NOMBRE_PARCEL_ENTREGADA:
			total += 1
	return total


func _buscar_locker() -> int:
	var pila := 0
	for cosa in _estado_dest.casillas.get(POS_LOCKER, []):
		if cosa.get("tipo") == "item" and bool(cosa.get("contenedor", false)):
			return pila
		pila += 1
	return -1


func _items_de(estado, id_contenedor: int) -> Array:
	if estado == null or id_contenedor < 0:
		return []
	return estado.contenedores.get(id_contenedor, {}).get("items", [])


func _indice_por_nombre(estado, id_contenedor: int, nombre: String) -> int:
	var indice := 0
	for cosa in _items_de(estado, id_contenedor):
		if str(cosa.get("nombre", "")).to_lower() == nombre:
			return indice
		indice += 1
	return -1


func _indice_por_cid(estado, id_contenedor: int, cid: int) -> int:
	var indice := 0
	for cosa in _items_de(estado, id_contenedor):
		if int(cosa.get("cid", 0)) == cid:
			return indice
		indice += 1
	return -1


func _primer_id_nuevo(vistos: Dictionary, excluidos: Array) -> int:
	for id in vistos:
		if int(id) in excluidos:
			continue
		return int(id)
	return -1


func _reintentar_caminata(destino: Vector3i) -> bool:
	if _intentos_caminata >= MAX_INTENTOS_CAMINATA:
		return false
	if _intentos_caminata > 0 and _espera < 3.0:
		return true
	_intentos_caminata += 1
	_espera = 0.0
	_caminar_hacia(destino)
	return true


func _caminar_hacia(destino: Vector3i) -> void:
	var pasos: Array = []
	var actual: Vector3i = _estado_dest.mi_pos
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
	_con_dest.enviar_auto_camino(pasos)


func _cerca(posicion: Vector3i, centro: Vector3i, radio: int) -> bool:
	return posicion.z == centro.z \
		and absi(posicion.x - centro.x) <= radio \
		and absi(posicion.y - centro.y) <= radio


func _pasar_a(fase: String) -> void:
	print("  [%.0fs] fase: %s" % [_total, fase])
	_fase = fase
	_espera = 0.0
	_pidio = false
	_intentos_caminata = 0


func _fallar(texto: String) -> void:
	print(texto)
	_terminar(1)


func _terminar(codigo: int) -> void:
	if _terminando:
		return
	_terminando = true
	if _con_dest != null:
		_con_dest.enviar_logout()
	await get_tree().create_timer(2.0).timeout
	if _con_god != null:
		_con_god.cerrar()
	if _con_dest != null:
		_con_dest.cerrar()
	get_tree().quit(codigo)
