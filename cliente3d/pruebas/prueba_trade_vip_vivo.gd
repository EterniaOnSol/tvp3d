extends Node

# Prueba viva de VIP y comercio contra el servidor TVP 7.72.
#
# Usa dos sesiones reales. GOD VALENTINO agrega a Valentino a VIP, observa
# su cambio offline -> online, acerca ambos personajes y les hace intercambiar
# dos objetos por la ruta autoritativa de trade. Al final Valentino sale y el
# god debe recibir el cambio online -> offline.
#
# La solicitud inicial de trade usa el 0x7D saliente que publico
# `protocolo-red` 1.5.0. Antes se armaba a mano aca, cuando el cliente todavia
# no exponia ese metodo.

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
const CUENTA := 123456
const CLAVE := "123456"
const PERSONAJE_GOD := "GOD VALENTINO"
const PERSONAJE := "Valentino"
const GUID_PERSONAJE := 2
## Templo de Valentino: zona segura para que una criatura de otra prueba no
## interfiera mientras se prepara el intercambio.
const POS_SEGURA := Vector3i(32369, 32241, 7)
const PAUSA_SESION := 6.0
const LIMITE_TOTAL := 180.0
## Fixture vivo confirmado en servidor/gamedata/players/1/1.tvpp: el god
## conserva fluid containers en ambas manos. Su server id 2006 corresponde al
## client id 2874 en items.otb 7.72.
const CID_FLUID_CONTAINER := 2874
const SLOT_MANO_DERECHA := 5
const SLOT_MANO_IZQUIERDA := 6

var _con_login
var _con_god
var _con_personaje
var _estado_god
var _estado_personaje
var _puertos := {}
var _fase := "login"
var _paso := 0
var _espera := 0.0
var _total := 0.0
var _fallas := 0
var _terminando := false

var _vip_online := false
var _vip_offline_final := false
var _slot_oferta_god := -1
var _slot_donacion := -1
var _cid_oferta_god := 0
var _cid_donacion := 0
var _slot_oferta_personaje := 5
var _ofertas := {
	"god_propia": false,
	"god_contraparte": false,
	"personaje_propia": false,
	"personaje_contraparte": false,
}
var _trade_cerro_god := false
var _trade_cerro_personaje := false
var _errores_trade: Array[String] = []
var _personaje := PERSONAJE
var _guid_personaje := GUID_PERSONAJE
var _cuenta := CUENTA
var _clave := CLAVE


func _ready() -> void:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--personaje="):
			_personaje = argumento.trim_prefix("--personaje=").strip_edges()
		elif argumento.begins_with("--guid="):
			_guid_personaje = int(argumento.trim_prefix("--guid="))
		elif argumento.begins_with("--cuenta="):
			_cuenta = int(argumento.trim_prefix("--cuenta="))
		elif argumento.begins_with("--clave-env="):
			var variable := argumento.trim_prefix("--clave-env=").strip_edges()
			_clave = OS.get_environment(variable)
	if _clave.is_empty():
		_error("La clave de prueba no esta disponible")
		_terminar()
		return
	print("=================================================")
	print(" TVP3D - prueba viva de VIP y trade con %s" % _personaje)
	print("=================================================")
	_abrir_login()


func _process(delta: float) -> void:
	_total += delta
	_espera += delta
	if _terminando:
		return
	if _total > LIMITE_TOTAL:
		_error("Tiempo agotado en la fase '%s'" % _fase)
		_terminar()
		return

	match _fase:
		"esperar god":
			if _estado_god != null and _estado_god.adentro and _espera > 2.0:
				_preparar_vip()
		"quitar vip":
			if _espera > 1.0:
				_fase = "agregar vip"
				_espera = 0.0
				_con_god.enviar_agregar_vip(_personaje)
		"pausa segundo cliente":
			if _espera >= PAUSA_SESION:
				_abrir_personaje()
		"esperar vip online":
			if _vip_online:
				_pasar_a("reunir personajes")
		"reunir personajes":
			_reunir_personajes()
		"normalizar manos":
			_normalizar_manos()
		"esperar objeto donante":
			_verificar_objeto_donante()
		"esperar donacion":
			_buscar_donacion()
		"esperar equipo":
			_verificar_equipo_personaje()
		"esperar objeto god":
			_verificar_objeto_god()
		"esperar oferta god":
			if _ofertas["god_propia"]:
				_enviar_oferta_personaje()
		"esperar ambas ofertas":
			if _todas_las_ofertas():
				_aceptar_trade()
		"aceptar contraparte":
			if _espera > 0.5:
				_con_personaje.enviar_aceptar_comercio()
				_pasar_a("esperar cierre trade")
		"esperar cierre trade":
			if _trade_cerro_god and _trade_cerro_personaje:
				_cerrar_personaje()
		"esperar vip offline":
			if _vip_offline_final:
				_comprobar("VIP informa online -> offline", true)
				_con_god.enviar_logout()
				_pasar_a("salir god")
		"salir god":
			if _espera > 8.0:
				# El logout puede ser rechazado temporalmente por estado in-fight.
				_con_god.enviar_logout()
				_espera = 0.0


func _abrir_login() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.lista_personajes.connect(_al_lista)
	_con_login.error_red.connect(func(texto): _error("Login: " + texto))
	_con_login.pedir_personajes(HOST, PUERTO_LOGIN, _cuenta, _clave)


func _al_lista(_motd: String, personajes: Array) -> void:
	for entrada in personajes:
		_puertos[str(entrada.get("nombre", ""))] = int(entrada.get("puerto", 0))
	if int(_puertos.get(PERSONAJE_GOD, 0)) <= 0 \
			or int(_puertos.get(_personaje, 0)) <= 0:
		_error("La cuenta no contiene los dos personajes de la prueba")
		_terminar()
		return
	_con_login.cerrar()
	_con_login.queue_free()
	_con_login = null
	_abrir_god()


func _abrir_god() -> void:
	_estado_god = ESTADO.new()
	_estado_god.pedido_ping.connect(func():
		_con_god.enviar_juego(PackedByteArray([0x1E])))
	_estado_god.vip_actualizado.connect(_al_vip_god)
	_estado_god.comercio_actualizado.connect(func(nombre, propia, items):
		_al_oferta("god", nombre, propia, items))
	_estado_god.comercio_cerrado.connect(func(): _trade_cerro_god = true)
	_estado_god.mensaje_servidor.connect(func(texto): _al_mensaje("god", texto))
	_con_god = CONEXION.new()
	add_child(_con_god)
	_con_god.error_red.connect(func(texto): _error("God: " + texto))
	_con_god.paquete_juego.connect(func(msg): _estado_god.procesar(msg))
	_con_god.cerrada.connect(_al_cierre_god)
	_con_god.entrar_al_mundo(HOST, int(_puertos[PERSONAJE_GOD]), _cuenta,
		PERSONAJE_GOD, _clave)
	_pasar_a("esperar god")


func _preparar_vip() -> void:
	# Se fuerza remove + add para demostrar que 0xDC llega al servidor y que
	# este responde con una entrada 0xD2 nueva, incluso si ya estaba guardada.
	_con_god.enviar_quitar_vip(_guid_personaje)
	_pasar_a("quitar vip")


func _al_vip_god(guid: int, entrada: Dictionary) -> void:
	if guid != _guid_personaje:
		return
	var estado := int(entrada.get("estado", -1))
	if _fase == "agregar vip" and estado == 0:
		_comprobar("VIP agrega por nombre y devuelve GUID real",
			str(entrada.get("nombre", "")) == _personaje)
		_comprobar("VIP agregado aparece offline", estado == 0)
		_pasar_a("pausa segundo cliente")
	elif estado == 1:
		_vip_online = true
	elif _vip_online and estado == 0:
		_vip_offline_final = true


func _abrir_personaje() -> void:
	_estado_personaje = ESTADO.new()
	_estado_personaje.pedido_ping.connect(func():
		_con_personaje.enviar_juego(PackedByteArray([0x1E])))
	_estado_personaje.entramos.connect(func(): _pasar_a("esperar vip online"))
	_estado_personaje.comercio_actualizado.connect(func(nombre, propia, items):
		_al_oferta("personaje", nombre, propia, items))
	_estado_personaje.comercio_cerrado.connect(func():
		_trade_cerro_personaje = true)
	_estado_personaje.mensaje_servidor.connect(func(texto):
		_al_mensaje("personaje", texto))
	_con_personaje = CONEXION.new()
	add_child(_con_personaje)
	_con_personaje.error_red.connect(func(texto): _error("Valentino: " + texto))
	_con_personaje.paquete_juego.connect(func(msg): _estado_personaje.procesar(msg))
	_con_personaje.cerrada.connect(_al_cierre_personaje)
	_con_personaje.entrar_al_mundo(HOST, int(_puertos[_personaje]), _cuenta,
		_personaje, _clave)
	_pasar_a("entrando personaje")


func _reunir_personajes() -> void:
	if _paso == 0:
		_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
			POS_SEGURA.x, POS_SEGURA.y, POS_SEGURA.z])
		_paso = 1
		_espera = 0.0
		return
	if _paso == 1 and _espera > 2.0:
		_con_god.enviar_hablar("/c %s" % _personaje)
		_paso = 2
		_espera = 0.0
		return
	if _paso != 2 or _espera < 3.0:
		return
	var cerca := _misma_planta_y_cerca(_estado_god.mi_pos,
		_estado_personaje.mi_pos, 2)
	_comprobar("servidor reune ambos jugadores a distancia de trade", cerca)
	if not cerca:
		_error("Posiciones recibidas: god=%s, Valentino=%s" % [
			str(_estado_god.mi_pos), str(_estado_personaje.mi_pos)])
		_terminar()
		return
	# El mapa 0x64 puede cortar el resto del paquete inicial y ocultar los
	# 0x78 de inventario. La prueba no inventa los objetos: usa el fixture
	# persistente del servidor, comprobado arriba, y deja que este valide slot,
	# client id y pickupable al procesar 0x78/0x7D.
	# Primero dona el vial de la mano derecha. Cuando Valentino lo recoge, el
	# god crea otro server id 2006 en la mano que quedo libre y lo ofrece.
	_slot_oferta_god = SLOT_MANO_DERECHA
	_slot_donacion = SLOT_MANO_DERECHA
	_cid_oferta_god = CID_FLUID_CONTAINER
	_cid_donacion = CID_FLUID_CONTAINER
	print("Donando CID %d desde slot %d; oferta god CID %d desde slot %d." % [
		_cid_donacion, _slot_donacion, _cid_oferta_god, _slot_oferta_god])
	_pasar_a("normalizar manos")


func _normalizar_manos() -> void:
	if _espera < 1.0:
		return
	var ranuras := [5, 6, 10]
	if _paso < ranuras.size():
		var slot: int = ranuras[_paso]
		# Las corridas son deliberadamente mutantes. Se vacian los tres slots
		# usados por el fixture para que la prueba sea repetible aunque un trade
		# anterior haya dejado el vial en la otra mano.
		_con_god.enviar_mover_inventario(slot, CID_FLUID_CONTAINER,
			_estado_god.mi_pos, 1)
		_con_personaje.enviar_mover_inventario(slot, CID_FLUID_CONTAINER,
			_estado_god.mi_pos, 1)
		_paso += 1
		_espera = 0.0
		return
	_con_god.enviar_hablar("/i 2006,0")
	_pasar_a("esperar objeto donante")


func _verificar_objeto_donante() -> void:
	var item: Dictionary = _estado_god.inventario.get(_slot_donacion, {})
	if int(item.get("cid", 0)) == _cid_donacion:
		_con_god.enviar_mover_inventario(_slot_donacion, _cid_donacion,
			_estado_personaje.mi_pos, 1)
		_pasar_a("esperar donacion")
		return
	if _espera > 12.0:
		_error("El servidor no creo el objeto donante en la mano libre")
		_terminar()


func _buscar_donacion() -> void:
	if _espera < 1.0:
		return
	var cosas: Array = _estado_personaje.casillas.get(
		_estado_personaje.mi_pos, [])
	for indice in range(cosas.size()):
		var cosa: Dictionary = cosas[indice]
		if cosa.get("tipo") == "item" and int(cosa.get("cid", 0)) == _cid_donacion:
			_con_personaje.enviar_mover_ubicacion(_estado_personaje.mi_pos,
				_cid_donacion, indice,
				Vector3i(0xFFFF, _slot_oferta_personaje, 0), 1)
			_pasar_a("esperar equipo")
			return
	if _espera > 12.0:
		_error("El objeto donado no aparecio en la casilla de Valentino")
		_terminar()


func _verificar_equipo_personaje() -> void:
	var item: Dictionary = _estado_personaje.inventario.get(
		_slot_oferta_personaje, {})
	if int(item.get("cid", 0)) == _cid_donacion:
		_comprobar("%s recoge un objeto real para contraofertar" % _personaje,
			true)
		_con_god.enviar_hablar("/i 2006,0")
		_pasar_a("esperar objeto god")
		return
	if _espera > 12.0:
		_error("Valentino no pudo equipar el objeto donado")
		_terminar()


func _verificar_objeto_god() -> void:
	var item: Dictionary = _estado_god.inventario.get(_slot_oferta_god, {})
	if int(item.get("cid", 0)) == _cid_oferta_god:
		_comprobar("el servidor crea un segundo objeto para la oferta del god", true)
		_enviar_solicitud_trade(_con_god, _slot_oferta_god,
			_cid_oferta_god, _estado_personaje.mi_id)
		_pasar_a("esperar oferta god")
		return
	if _espera > 12.0:
		_error("El objeto creado por /i no llego a la mano del god")
		_terminar()


func _enviar_oferta_personaje() -> void:
	_enviar_solicitud_trade(_con_personaje, _slot_oferta_personaje,
		_cid_donacion, _estado_god.mi_id)
	_pasar_a("esperar ambas ofertas")


func _enviar_solicitud_trade(conexion, slot: int, cid: int,
		id_contraparte: int) -> void:
	# `protocolo-red` 1.5.0 ya publica el 0x7D saliente con el atajo de
	# inventario, asi que la prueba dejo de armar esos bytes a mano.
	conexion.enviar_solicitar_comercio_inventario(slot, cid, id_contraparte)


func _al_oferta(quien: String, nombre: String, propia: bool,
		items: Array) -> void:
	var clave := "%s_%s" % [quien, "propia" if propia else "contraparte"]
	_ofertas[clave] = not items.is_empty()
	print("Oferta %s: nombre=%s propia=%s items=%d" % [
		quien, nombre, str(propia), items.size()])


func _todas_las_ofertas() -> bool:
	for clave in _ofertas:
		if not bool(_ofertas[clave]):
			return false
	return true


func _aceptar_trade() -> void:
	_comprobar("ambos clientes reciben oferta propia y contraparte", true)
	_con_god.enviar_aceptar_comercio()
	_pasar_a("aceptar contraparte")


func _cerrar_personaje() -> void:
	_comprobar("servidor cierra trade en ambas sesiones tras aceptar", true)
	_comprobar("trade aceptado no devuelve error mecanico",
		_errores_trade.is_empty())
	# El servidor reserva ambas ofertas antes de moverlas. Por eso el vial de
	# Valentino entra en la mano izquierda libre del god mientras el suyo sale
	# de la derecha; Valentino recibe el otro en su derecha. No alcanza con ver
	# 0x7F: estas dos actualizaciones prueban que hubo transferencia.
	_comprobar("trade transfiere ambos objetos en inventarios autoritativos",
		int(_estado_god.inventario.get(SLOT_MANO_IZQUIERDA, {}).get("cid", 0))
			== CID_FLUID_CONTAINER
		and int(_estado_personaje.inventario.get(
			SLOT_MANO_DERECHA, {}).get("cid", 0)) == CID_FLUID_CONTAINER)
	_con_personaje.enviar_logout()
	_pasar_a("esperar vip offline")


func _al_mensaje(quien: String, texto: String) -> void:
	print("  [%s] %s" % [quien, texto])
	if _fase not in ["esperar oferta god", "esperar ambas ofertas",
			"aceptar contraparte", "esperar cierre trade"]:
		return
	var bajo := texto.to_lower()
	for patron in ["not enough room", "not possible", "out of reach",
			"cannot throw", "already trading", "trade cancelled"]:
		if patron in bajo:
			_errores_trade.append("%s: %s" % [quien, texto])


func _al_cierre_personaje() -> void:
	if _fase == "esperar vip offline":
		return
	if not _terminando:
		_error("Valentino se desconecto durante '%s'" % _fase)


func _al_cierre_god() -> void:
	if _fase == "salir god" or _terminando:
		_terminar()
	else:
		_error("El god se desconecto durante '%s'" % _fase)


func _misma_planta_y_cerca(a: Vector3i, b: Vector3i, radio: int) -> bool:
	return a != Vector3i.ZERO and b != Vector3i.ZERO and a.z == b.z \
		and absi(a.x - b.x) <= radio and absi(a.y - b.y) <= radio


func _pasar_a(fase: String) -> void:
	_fase = fase
	_paso = 0
	_espera = 0.0
	print("  [%.1fs] fase: %s" % [_total, fase])


func _comprobar(nombre: String, condicion: bool) -> void:
	if condicion:
		print("  OK: ", nombre)
	else:
		_fallas += 1
		print("  FALLO: ", nombre)


func _error(texto: String) -> void:
	_fallas += 1
	print("  ERROR: ", texto)


func _terminar() -> void:
	if _terminando:
		return
	_terminando = true
	if _con_personaje != null:
		_con_personaje.cerrar()
	if _con_god != null:
		_con_god.cerrar()
	print("=================================================")
	print(" RESULTADO: %s (%d fallas)" % [
		"OK" if _fallas == 0 else "FALLO", _fallas])
	print("=================================================")
	get_tree().quit(1 if _fallas > 0 else 0)
