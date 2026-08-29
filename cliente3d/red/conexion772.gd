extends Node

# =====================================================================
#  La conexión con TVP — protocolo 7.72.
#
#  Todo lo de acá está sacado LEYENDO el servidor, no adivinando. TVP es
#  C++ y el código está en el repo, así que se puede abrir y ver exacto
#  qué espera:
#
#    servidor/src/protocollogin.cpp:85   -> el pedido de personajes
#    servidor/src/protocollogin.cpp:32   -> la lista que contesta
#    servidor/src/protocolgame.cpp:338   -> la entrada al mundo
#    servidor/src/protocol.cpp           -> el sobre y el XTEA
#
#  El sobre de un paquete es lo más simple que hay:
#
#      [u16 largo][ ... cuerpo ... ]
#
#  Nada más. Sin compresión, sin contador de secuencia (eso es del 15.25)
#  y SIN FIRMA (eso es del 8.0 para arriba).
#
#  Diferencias con el 8.6 de INTEN3D — SON TRES Y LAS TRES ROMPEN EL LOGIN:
#    1. La cuenta es un NÚMERO de 32 bits, no un texto. En 7.72 todavía
#       se entraba con número de cuenta (protocollogin.cpp:156).
#    2. NO hay saludo del servidor. En 8.6 había que esperar el 0x1F
#       antes de mandar el login; acá se manda apenas conecta.
#    3. NO hay checksum adler32. El adler32 aparece en Tibia 8.0; acá
#       `addCryptoHeader()` sólo escribe el largo (outputmessage.h:29-31)
#       y en connection.cpp no se verifica nada. Si igual se mandan los 4
#       bytes de firma, el servidor lee el primero como identificador de
#       protocolo, no reconoce ninguno (server.cpp:121-129) y CIERRA LA
#       CONEXIÓN SIN DECIR NADA. El síntoma engaña: parece que el
#       servidor estuviera caído.
# =====================================================================

signal error_red(texto: String)
signal lista_personajes(motd: String, personajes: Array)
signal paquete_juego(mensaje)
signal cerrada()

const MENSAJE := preload("res://red/mensaje.gd")
const RSA := preload("res://red/rsa.gd")
const XTEA := preload("res://red/xtea.gd")

## TVP acepta exactamente la 772 (src/definitions.h:10-12).
const VERSION := 772
const SISTEMA := 2   # 1=linux 2=windows

enum Modo { LOGIN, JUEGO }

var _sock: StreamPeerTCP = null
var _modo: int = Modo.LOGIN
var _llave := PackedInt64Array()
var _cifrado := false          ## ya se acordó la llave XTEA
var _buf := PackedByteArray()

## Ultimo paquete de juego que se mando. Sirve para comprobar los bytes en un
## self-test sin abrir un socket; el envio real no depende de esto.
var ultimo_envio_juego := PackedByteArray()


# --------------------------------------------------------------------
#  Arranque
# --------------------------------------------------------------------
func pedir_personajes(host: String, puerto: int, cuenta: int, clave: String) -> void:
	"""Se conecta al servidor de login y pide la lista de personajes."""
	_modo = Modo.LOGIN
	if not _abrir(host, puerto):
		return
	_llave = XTEA.llave_al_azar()

	var adentro := MENSAJE.new()
	adentro.escribir_u8(0)   # RSA_decrypt exige que el primer byte sea 0
	for k in _llave:
		adentro.escribir_u32(k)
	adentro.escribir_u32(cuenta)
	adentro.escribir_texto(clave)

	var afuera := MENSAJE.new()
	afuera.escribir_u8(0x01)
	afuera.escribir_u16(SISTEMA)
	afuera.escribir_u16(VERSION)
	# 12 bytes que el servidor saltea sin mirar: las firmas de Tibia.dat,
	# Tibia.spr y Tibia.pic (protocollogin.cpp:95-101).
	afuera.escribir_relleno(12)
	afuera.escribir_bytes(_bloque_rsa(adentro.datos))

	_enviar(afuera.datos, false)
	_cifrado = true   # la respuesta ya viene cifrada


func entrar_al_mundo(host: String, puerto: int, cuenta: int, personaje: String, clave: String) -> void:
	"""Se conecta al servidor de juego y entra de una. Acá no hay saludo
	que esperar: el 7.72 manda el login apenas se abre el socket."""
	_modo = Modo.JUEGO
	if not _abrir(host, puerto):
		return
	_llave = XTEA.llave_al_azar()

	var adentro := MENSAJE.new()
	adentro.escribir_u8(0)
	for k in _llave:
		adentro.escribir_u32(k)
	adentro.escribir_u8(0)   # bandera de gamemaster (protocolgame.cpp:374)
	adentro.escribir_u32(cuenta)
	adentro.escribir_texto(personaje)
	adentro.escribir_texto(clave)

	var afuera := MENSAJE.new()
	afuera.escribir_u8(0x0A)
	afuera.escribir_u16(SISTEMA)
	afuera.escribir_u16(VERSION)
	afuera.escribir_bytes(_bloque_rsa(adentro.datos))

	_enviar(afuera.datos, false)
	_cifrado = true


func cerrar() -> void:
	if _sock:
		_sock.disconnect_from_host()
		_sock = null


# --------------------------------------------------------------------
#  Bucle de lectura
# --------------------------------------------------------------------
func _process(_delta: float) -> void:
	if _sock == null:
		return
	_sock.poll()

	var estado := _sock.get_status()
	if estado == StreamPeerTCP.STATUS_ERROR or estado == StreamPeerTCP.STATUS_NONE:
		_sock = null
		cerrada.emit()
		return
	if estado != StreamPeerTCP.STATUS_CONNECTED:
		return

	var disponibles := _sock.get_available_bytes()
	if disponibles > 0:
		var leido: Array = _sock.get_data(disponibles)
		if leido[0] == OK:
			_buf.append_array(leido[1])

	_desarmar_paquetes()


func _desarmar_paquetes() -> void:
	while _buf.size() >= 2:
		var largo: int = _buf[0] | (_buf[1] << 8)
		if _buf.size() < 2 + largo:
			return   # todavía no llegó entero
		var cuerpo := _buf.slice(2, 2 + largo)
		_buf = _buf.slice(2 + largo)
		_procesar(cuerpo)


func _procesar(cuerpo: PackedByteArray) -> void:
	if _cifrado:
		cuerpo = XTEA.descifrar(cuerpo, _llave)

	# Adentro del cuerpo va otra vez el largo real.
	if cuerpo.size() < 2:
		return
	var largo_real: int = cuerpo[0] | (cuerpo[1] << 8)
	var carga := cuerpo.slice(2, 2 + largo_real)
	var msg = MENSAJE.new(carga)

	if _modo == Modo.LOGIN:
		_leer_respuesta_login(msg)
	else:
		paquete_juego.emit(msg)


# --------------------------------------------------------------------
#  Respuesta del servidor de login
# --------------------------------------------------------------------
func _leer_respuesta_login(msg) -> void:
	var motd := ""
	var personajes := []

	while msg.sin_leer() > 0:
		var tipo: int = msg.leer_u8()
		match tipo:
			0x14:   # mensaje del día
				motd = msg.leer_texto()
			0x64:   # lista de personajes (protocollogin.cpp:55-66)
				var cuantos: int = msg.leer_u8()
				for _i in range(cuantos):
					var nombre: String = msg.leer_texto()
					var mundo: String = msg.leer_texto()
					var ip := "%d.%d.%d.%d" % [
						msg.leer_u8(), msg.leer_u8(), msg.leer_u8(), msg.leer_u8()]
					var puerto: int = msg.leer_u16()
					personajes.append({
						"nombre": nombre, "mundo": mundo,
						"ip": ip, "puerto": puerto})
				var _premium: int = msg.leer_u16()
				lista_personajes.emit(motd, personajes)
				return
			0x0A, 0x0B:   # el servidor rechazó el login
				error_red.emit(msg.leer_texto())
				return
			_:
				error_red.emit("Respuesta inesperada del login: byte %d" % tipo)
				return


# --------------------------------------------------------------------
#  Plomería
# --------------------------------------------------------------------
func _abrir(host: String, puerto: int) -> bool:
	_sock = StreamPeerTCP.new()
	_buf = PackedByteArray()
	_cifrado = false
	if _sock.connect_to_host(host, puerto) != OK:
		error_red.emit("No se pudo abrir la conexión a %s:%d" % [host, puerto])
		_sock = null
		return false
	# Esperamos a que el sistema termine de conectar antes de escribir.
	var intentos := 0
	while _sock.get_status() == StreamPeerTCP.STATUS_CONNECTING and intentos < 500:
		_sock.poll()
		OS.delay_msec(10)
		intentos += 1
	if _sock.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		error_red.emit("El servidor %s:%d no contesta" % [host, puerto])
		_sock = null
		return false
	return true


func _bloque_rsa(contenido: PackedByteArray) -> PackedByteArray:
	"""Mete el contenido en un bloque de 128 bytes y lo cifra con la clave
	pública. Si no entra, es un error de programación nuestro."""
	assert(contenido.size() <= 128, "el contenido no entra en el bloque RSA")
	var bloque := contenido.duplicate()
	while bloque.size() < 128:
		bloque.append(randi() & 0xFF)
	return RSA.new().cifrar(bloque)


func _enviar(carga: PackedByteArray, cifrar: bool) -> void:
	if _sock == null:
		return
	var cuerpo: PackedByteArray
	if cifrar:
		var adentro := PackedByteArray([carga.size() & 0xFF, (carga.size() >> 8) & 0xFF])
		adentro.append_array(carga)
		while adentro.size() % 8 != 0:
			adentro.append(0x33)
		cuerpo = XTEA.cifrar(adentro, _llave)
	else:
		cuerpo = carga

	var sobre := PackedByteArray()
	var total := cuerpo.size()
	sobre.append(total & 0xFF)
	sobre.append((total >> 8) & 0xFF)
	sobre.append_array(cuerpo)
	_sock.put_data(sobre)


func enviar_juego(carga: PackedByteArray) -> void:
	"""Manda un paquete ya dentro de la partida (siempre cifrado)."""
	ultimo_envio_juego = carga.duplicate()
	_enviar(carga, true)


func enviar_voz(trama: PackedByteArray) -> void:
	"""Envia un cuadro binario por el canal extendido reservado para voz."""
	if _modo != Modo.JUEGO or trama.is_empty():
		return
	var mensaje := MENSAJE.new()
	mensaje.escribir_u8(0x32)
	mensaje.escribir_u8(0xF1) # TVP3D proximity voice
	mensaje.escribir_u16(trama.size())
	mensaje.escribir_bytes(trama)
	enviar_juego(mensaje.datos)


func enviar_logout() -> void:
	"""Solicita logout limpio al servidor (0x14)."""
	enviar_juego(PackedByteArray([0x14]))


func enviar_cancelar_accion() -> void:
	"""Cancela ataque/seguimiento y el auto-camino en el servidor."""
	# 0xBE cancela ataque y follow; 0x69 detiene el auto-walk.
	enviar_juego(PackedByteArray([0xBE]))
	enviar_juego(PackedByteArray([0x69]))


func enviar_detener_auto_camino() -> void:
	"""Detiene solo el auto-walk, sin cancelar el objetivo de combate."""
	enviar_juego(PackedByteArray([0x69]))


func enviar_hablar(texto: String) -> void:
	"""Envia chat/spells sin cancelar el auto-walk del personaje."""
	var mensaje := MENSAJE.new()
	mensaje.escribir_u8(0x32)
	mensaje.escribir_u8(0xF2) # TVP3D say/cast, movimiento continua
	mensaje.escribir_texto(texto.strip_edges())
	enviar_juego(mensaje.datos)


func enviar_pedir_canales() -> void:
	"""Solicita la lista real de canales (0x97)."""
	enviar_juego(PackedByteArray([0x97]))


func enviar_abrir_canal(id_canal: int) -> void:
	"""Abre un canal de la lista (0x98 + uint16)."""
	enviar_juego(PackedByteArray([0x98, id_canal & 0xFF,
		(id_canal >> 8) & 0xFF]))


func enviar_cerrar_canal(id_canal: int) -> void:
	"""Cierra un canal abierto (0x99 + uint16)."""
	enviar_juego(PackedByteArray([0x99, id_canal & 0xFF,
		(id_canal >> 8) & 0xFF]))


func enviar_abrir_canal_privado(nombre: String) -> void:
	"""Abre un privado por nombre (0x9A + string)."""
	var mensaje := MENSAJE.new()
	mensaje.escribir_u8(0x9A)
	mensaje.escribir_texto(nombre.strip_edges())
	enviar_juego(mensaje.datos)


func enviar_crear_canal_privado() -> void:
	"""Crea el canal privado del jugador (0xAA)."""
	enviar_juego(PackedByteArray([0xAA]))


func enviar_hablar_en_canal(id_canal: int, texto: String,
		clase: int = 0x05) -> void:
	"""Envia una frase al canal usando parseSay 7.72.

	El servidor es quien valida que el canal este abierto y que la clase sea
	legal; el cliente solo construye el wire format exacto.
	"""
	var mensaje := MENSAJE.new()
	mensaje.escribir_u8(0x96)
	mensaje.escribir_u8(clase)
	mensaje.escribir_u16(id_canal)
	mensaje.escribir_texto(texto.strip_edges())
	enviar_juego(mensaje.datos)


func enviar_agregar_vip(nombre: String) -> void:
	"""Agrega un personaje a la lista VIP (0xDC)."""
	var limpio := nombre.strip_edges()
	if limpio.is_empty():
		return
	var mensaje := MENSAJE.new()
	mensaje.escribir_u8(0xDC)
	mensaje.escribir_texto(limpio)
	enviar_juego(mensaje.datos)


func enviar_quitar_vip(guid: int) -> void:
	"""Quita un personaje de la lista VIP (0xDD)."""
	var mensaje := MENSAJE.new()
	mensaje.escribir_u8(0xDD)
	mensaje.escribir_u32(guid)
	enviar_juego(mensaje.datos)


func enviar_usar_item(posicion: Vector3i, client_id: int, stackpos: int = 1,
		indice: int = 0) -> void:
	"""Usa un item del mapa (opcode 0x82, parseUseItem del servidor)."""
	var carga := PackedByteArray([0x82,
		posicion.x & 0xFF, (posicion.x >> 8) & 0xFF,
		posicion.y & 0xFF, (posicion.y >> 8) & 0xFF,
		posicion.z & 0xFF,
		client_id & 0xFF, (client_id >> 8) & 0xFF,
		stackpos & 0xFF, indice & 0xFF])
	enviar_juego(carga)


func enviar_usar_inventario(ranura: int, client_id: int) -> void:
	"""Usa un item del equipo (0xFFFF, ranura, 0), como Tibia."""
	enviar_usar_item(Vector3i(0xFFFF, ranura, 0), client_id, 0, 0)


func enviar_mirar(posicion: Vector3i, client_id: int = 0,
		stackpos: int = 0) -> void:
	"""Pide al servidor el look real de una casilla (0x8C).

	El servidor 7.72 resuelve el objeto visible desde la posicion y el
	stackpos; el client id se conserva por compatibilidad con Tibia aunque el
	servidor de TVP3D no lo usa para esta orden.
	"""
	var carga := PackedByteArray([0x8C])
	_agregar_posicion(carga, posicion)
	carga.append(client_id & 0xFF)
	carga.append((client_id >> 8) & 0xFF)
	carga.append(stackpos & 0xFF)
	enviar_juego(carga)


func enviar_usar_item_ex(origen: Vector3i, client_id: int, stackpos: int,
		destino: Vector3i, destino_client_id: int, destino_stackpos: int) -> void:
	"""Usa un objeto con otro objeto (0x83, parseUseItemEx)."""
	var carga := PackedByteArray([0x83])
	_agregar_posicion(carga, origen)
	carga.append(client_id & 0xFF)
	carga.append((client_id >> 8) & 0xFF)
	carga.append(stackpos & 0xFF)
	_agregar_posicion(carga, destino)
	carga.append(destino_client_id & 0xFF)
	carga.append((destino_client_id >> 8) & 0xFF)
	carga.append(destino_stackpos & 0xFF)
	enviar_juego(carga)


func enviar_usar_con_criatura(origen: Vector3i, client_id: int,
		stackpos: int, id_criatura: int) -> void:
	"""Usa un objeto con una criatura (0x84, parseUseWithCreature)."""
	var carga := PackedByteArray([0x84])
	_agregar_posicion(carga, origen)
	carga.append(client_id & 0xFF)
	carga.append((client_id >> 8) & 0xFF)
	carga.append(stackpos & 0xFF)
	carga.append(id_criatura & 0xFF)
	carga.append((id_criatura >> 8) & 0xFF)
	carga.append((id_criatura >> 16) & 0xFF)
	carga.append((id_criatura >> 24) & 0xFF)
	enviar_juego(carga)


func enviar_cerrar_contenedor(id_contenedor: int) -> void:
	"""Cierra una ventana de contenedor (0x87, parseCloseContainer)."""
	enviar_juego(PackedByteArray([0x87, id_contenedor & 0xFF]))


func enviar_subir_contenedor(id_contenedor: int) -> void:
	"""Muestra el contenedor padre en la misma ventana (0x88)."""
	enviar_juego(PackedByteArray([0x88, id_contenedor & 0xFF]))


func enviar_solicitar_comercio(origen: Vector3i, client_id: int,
		stackpos: int, id_jugador: int) -> void:
	"""Ofrece un objeto a otro jugador (0x7D).

	`ProtocolGame::parseRequestTrade` (protocolgame.cpp:1000-1009) lee posicion,
	client id, stackpos y el id del jugador, en ese orden. Quien decide si el
	objeto se puede ofrecer, si hay distancia y si el otro acepta es el
	servidor: esto solo transporta la intencion."""
	if id_jugador <= 0:
		return
	enviar_juego(PackedByteArray([0x7D,
		origen.x & 0xFF, (origen.x >> 8) & 0xFF,
		origen.y & 0xFF, (origen.y >> 8) & 0xFF,
		origen.z & 0xFF,
		client_id & 0xFF, (client_id >> 8) & 0xFF,
		stackpos & 0xFF,
		id_jugador & 0xFF, (id_jugador >> 8) & 0xFF,
		(id_jugador >> 16) & 0xFF, (id_jugador >> 24) & 0xFF]))


func enviar_solicitar_comercio_inventario(ranura: int, client_id: int,
		id_jugador: int) -> void:
	"""Ofrece un objeto del equipo, con la posicion (0xFFFF, ranura, 0) que usa
	Tibia para el inventario."""
	enviar_solicitar_comercio(Vector3i(0xFFFF, ranura, 0), client_id, 0,
		id_jugador)


func enviar_aceptar_comercio() -> void:
	"""Acepta la oferta actual del comercio jugador-a-jugador (0x7F)."""
	enviar_juego(PackedByteArray([0x7F]))


func enviar_cerrar_comercio() -> void:
	"""Cancela el comercio jugador-a-jugador (0x80)."""
	enviar_juego(PackedByteArray([0x80]))


func enviar_mirar_comercio(es_contraparte: bool, indice: int) -> void:
	"""Pide el look de un objeto dentro de la ventana de trade (0x7E)."""
	enviar_juego(PackedByteArray([0x7E, 1 if es_contraparte else 0,
		indice & 0xFF]))


func enviar_atacar(id_criatura: int) -> void:
	"""Selecciona objetivo de combate (0xA1)."""
	var carga := PackedByteArray([0xA1,
		id_criatura & 0xFF, (id_criatura >> 8) & 0xFF,
		(id_criatura >> 16) & 0xFF, (id_criatura >> 24) & 0xFF])
	enviar_juego(carga)


# --------------------------------------------------------------------
#  Party (protocolgame.cpp:536-541 y 1171-1207)
#
#  Las seis ordenes van del cliente al servidor y todas llevan el id de
#  criatura del otro jugador, salvo salir y experiencia compartida. Lo que
#  vuelve no es un paquete de party: es el escudo de cada criatura por el
#  `0x91`, que ya conserva `estado_mundo.gd`.
# --------------------------------------------------------------------
func _party_con_id(opcode: int, id_criatura: int) -> void:
	if id_criatura <= 0:
		# Un id cero no identifica a nadie; el servidor lo buscaria y
		# respondaria con un cancel. No se manda.
		return
	enviar_juego(PackedByteArray([opcode,
		id_criatura & 0xFF, (id_criatura >> 8) & 0xFF,
		(id_criatura >> 16) & 0xFF, (id_criatura >> 24) & 0xFF]))


func enviar_invitar_a_party(id_criatura: int) -> void:
	"""Invita a un jugador a nuestra party (0xA3)."""
	_party_con_id(0xA3, id_criatura)


func enviar_unirse_a_party(id_criatura: int) -> void:
	"""Acepta la invitacion del lider indicado (0xA4)."""
	_party_con_id(0xA4, id_criatura)


func enviar_revocar_invitacion_party(id_criatura: int) -> void:
	"""Retira una invitacion que habiamos hecho (0xA5)."""
	_party_con_id(0xA5, id_criatura)


func enviar_pasar_liderazgo_party(id_criatura: int) -> void:
	"""Le pasa el liderazgo de la party a un miembro (0xA6)."""
	_party_con_id(0xA6, id_criatura)


func enviar_salir_de_party() -> void:
	"""Sale de la party (0xA7). No lleva payload."""
	enviar_juego(PackedByteArray([0xA7]))


func enviar_experiencia_compartida(activa: bool) -> void:
	"""Pide activar o desactivar la experiencia compartida (0xA8).

	El servidor acepta la orden (`parseEnableSharedPartyExperience`), pero
	ofrecerla o no es decision de la interfaz: el cliente 7.72 original no
	tenia ese boton. Aca solo esta el transporte."""
	enviar_juego(PackedByteArray([0xA8, 1 if activa else 0]))


func enviar_seguir(id_criatura: int) -> void:
	"""Sigue una criatura (0xA2)."""
	var carga := PackedByteArray([0xA2,
		id_criatura & 0xFF, (id_criatura >> 8) & 0xFF,
		(id_criatura >> 16) & 0xFF, (id_criatura >> 24) & 0xFF])
	enviar_juego(carga)


func enviar_modos_combate(ofensivo: int = 2, perseguir: int = 1,
		seguro: int = 1) -> void:
	"""Actualiza fight mode, chase mode y secure mode (0xA0)."""
	enviar_juego(PackedByteArray([0xA0, ofensivo, perseguir, seguro]))


func enviar_mover_cosa(origen: Vector3i, client_id: int, stackpos: int,
		destino: Vector3i, cantidad: int = 1) -> void:
	"""Mueve un objeto del mapa (opcode 0x78, parseThrow del servidor)."""
	enviar_mover_ubicacion(origen, client_id, stackpos, destino, cantidad)


func enviar_mover_inventario(ranura: int, client_id: int,
		destino: Vector3i, cantidad: int = 1) -> void:
	"""Mueve un item del equipo al suelo con el formato 0x78 real."""
	enviar_mover_ubicacion(Vector3i(0xFFFF, ranura, 0), client_id, 0,
		destino, cantidad)


func enviar_mover_ubicacion(origen: Vector3i, client_id: int, stackpos: int,
		destino: Vector3i, cantidad: int = 1) -> void:
	var carga := PackedByteArray([0x78])
	_agregar_posicion(carga, origen)
	carga.append(client_id & 0xFF)
	carga.append((client_id >> 8) & 0xFF)
	carga.append(stackpos & 0xFF)
	_agregar_posicion(carga, destino)
	carga.append(cantidad & 0xFF)
	enviar_juego(carga)


func _agregar_posicion(carga: PackedByteArray, posicion: Vector3i) -> void:
	carga.append(posicion.x & 0xFF)
	carga.append((posicion.x >> 8) & 0xFF)
	carga.append(posicion.y & 0xFF)
	carga.append((posicion.y >> 8) & 0xFF)
	carga.append(posicion.z & 0xFF)


func enviar_auto_camino(pasos: Array) -> void:
	"""Envia un camino en el formato 0x64 de Tibia 7.72.

	El servidor lee las direcciones desde el final del buffer y despues
	invierte el vector. Por eso aca se escribe el camino en orden natural,
	desde el jugador hasta el destino; escribirlo al reves hacia que una ruta
	de varias casillas se ejecutara en sentido contrario.
	"""
	if _modo != Modo.JUEGO or pasos.is_empty():
		return
	var carga := _paquete_auto_camino(pasos)
	if carga.is_empty():
		return
	_enviar(carga, true)


func _paquete_auto_camino(pasos: Array) -> PackedByteArray:
	var cantidad := mini(128, pasos.size())
	var carga := PackedByteArray([0x64, cantidad])
	for i in range(cantidad):
		var direccion := _direccion_auto_walk(pasos[i])
		if direccion == 0:
			return PackedByteArray()
		carga.append(direccion)
	return carga


func _direccion_auto_walk(paso: Vector2i) -> int:
	if paso == Vector2i(1, 0): return 1
	if paso == Vector2i(1, -1): return 2
	if paso == Vector2i(0, -1): return 3
	if paso == Vector2i(-1, -1): return 4
	if paso == Vector2i(-1, 0): return 5
	if paso == Vector2i(-1, 1): return 6
	if paso == Vector2i(0, 1): return 7
	if paso == Vector2i(1, 1): return 8
	return 0
