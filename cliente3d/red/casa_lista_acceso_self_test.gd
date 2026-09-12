extends SceneTree

# Self-test de la ventana de lista de acceso de casa 7.72, sin sockets ni
# servidor. Bytes exactos contra la fuente del oracle.
#
#   protocolgame.cpp:2129-2137  sendHouseWindow -> 0x97  (servidor -> cliente)
#     u8  0x00        relleno, siempre cero
#     u32 id de ventana
#     string texto    lista actual, con encabezado '#'
#
#   protocolgame.cpp:1102-1108  parseHouseWindow <- 0x8A  (cliente -> servidor)
#     u8  id de lista
#     u32 id de ventana
#     string texto
#
# LA DIRECCION ES PARTE DEL SIGNIFICADO. Saliente, 0x97 es "pedir la lista de
# canales"; entrante es esta ventana. Son dos mensajes distintos que comparten
# numero. No es una rareza aislada: el 0x96 saliente es hablar y entrando es la
# ventana de texto, y el servidor lo confirma en su propio dispatch
# (protocolgame.cpp:521-526), donde 0x89/0x8A y 0x96/0x97 entrantes no tienen
# nada que ver con lo que el servidor manda con esos mismos numeros.
#
# Por eso este self-test comprueba EXPLICITAMENTE que agregar el 0x97 entrante
# no cambio el 0x97 saliente.
#
#   ...Godot --headless --path cliente3d --script res://red/casa_lista_acceso_self_test.gd

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const MENSAJE := preload("res://red/mensaje.gd")

var _fallas := 0


func _initialize() -> void:
	print("Lista de acceso de casa TVP 7.72 self-test")
	_probar_recepcion()
	_probar_envio()
	_probar_direccion()
	if _fallas > 0:
		printerr("Lista de acceso de casa self-test: %d falla(s)" % _fallas)
		quit(1)
		return
	print("Lista de acceso de casa TVP 7.72 self-test: OK")
	quit(0)


func _probar_recepcion() -> void:
	var estado = ESTADO.new()
	var ventanas: Array = []
	estado.ventana_casa.connect(func(datos): ventanas.append(datos))
	var textos: Array = []
	estado.mensaje_servidor.connect(func(texto): textos.append(texto))

	# Lo que manda `Player::sendHouseWindow` (player.cpp:875-892): una linea de
	# encabezado con '#' y despues la lista, un nombre por linea.
	var lista := "# Guests of Mill Avenue 3\nQa Share Duo\n"
	var msg = MENSAJE.new()
	msg.escribir_u8(0x97)
	msg.escribir_u8(0x00)
	msg.escribir_u32(0x0A0B0C0D)
	msg.escribir_texto(lista)
	# Un mensaje pegado detras comprueba que no quedo ni un byte de mas.
	msg.escribir_u8(0xB4)
	msg.escribir_u8(0x16)
	msg.escribir_texto("sigue alineado")
	estado.procesar(msg)

	_comprobar("la ventana de casa llega una sola vez", ventanas.size() == 1)
	if ventanas.size() == 1:
		var datos: Dictionary = ventanas[0]
		_comprobar("conserva el id de ventana",
			int(datos.get("id", 0)) == 0x0A0B0C0D)
		_comprobar("conserva el texto entero, con encabezado y saltos",
			str(datos.get("texto", "")) == lista,
			"obtenido %s" % str(datos.get("texto", "")))
	_comprobar("el mensaje siguiente no queda corrido",
		textos == ["sigue alineado"] and msg.sin_leer() == 0)

	_comprobar("el estado conserva la ultima ventana de casa",
		int(estado.ultima_ventana_casa.get("id", 0)) == 0x0A0B0C0D)

	# Una casa sin nadie invitado: el servidor manda solo el encabezado. Es el
	# caso normal de una casa recien comprada, no un error.
	var vacia = MENSAJE.new()
	vacia.escribir_u8(0x97)
	vacia.escribir_u8(0x00)
	vacia.escribir_u32(7)
	vacia.escribir_texto("# Guests of Mill Avenue 3\n")
	estado.procesar(vacia)
	_comprobar("una lista vacia tambien abre su ventana",
		ventanas.size() == 2
		and str(ventanas[1].get("texto", "")) == "# Guests of Mill Avenue 3\n")
	_comprobar("la lista vacia consume su mensaje entero",
		vacia.sin_leer() == 0)

	# Truncada en el medio del u32: no debe emitir nada.
	var corta = MENSAJE.new()
	corta.escribir_u8(0x97)
	corta.escribir_u8(0x00)
	corta.escribir_u16(9)
	estado.procesar(corta)
	_comprobar("una ventana truncada en el id no se emite",
		ventanas.size() == 2)

	# Truncada en el cuerpo del texto: el prefijo de largo dice 40 bytes y solo
	# vienen 4. Es la trampa que `puede_leer_texto` existe para atajar.
	var mentirosa = MENSAJE.new()
	mentirosa.escribir_u8(0x97)
	mentirosa.escribir_u8(0x00)
	mentirosa.escribir_u32(11)
	mentirosa.escribir_u16(40)
	mentirosa.escribir_bytes("Qa S".to_utf8_buffer())
	estado.procesar(mentirosa)
	_comprobar("un texto con largo mentiroso no se emite",
		ventanas.size() == 2)
	_comprobar("el estado no quedo pisado por los mensajes truncados",
		int(estado.ultima_ventana_casa.get("id", 0)) == 7)


func _probar_envio() -> void:
	var con = CONEXION.new()
	root.add_child(con)

	var lista := "# Guests of Mill Avenue 3\nQa Share Duo\n"
	con.enviar_lista_acceso_casa(0x0A0B0C0D, lista)
	var esperado := PackedByteArray([0x8A,
		0x00,                          # id de lista: el servidor exige 0
		0x0D, 0x0C, 0x0B, 0x0A,        # id de ventana, little-endian
		0x27, 0x00])                   # 39 bytes de texto: 26 + 12 + 1
	esperado.append_array(lista.to_utf8_buffer())
	_comprobar("enviar manda 0x8A con id de lista 0, id de ventana y texto",
		con.ultimo_envio_juego == esperado,
		"obtenido %s" % str(con.ultimo_envio_juego))
	_comprobar("no quedan bytes de mas al final",
		con.ultimo_envio_juego.size() == 8 + lista.to_utf8_buffer().size())

	# Vaciar la lista es una accion legitima: es como se desinvita a todos.
	con.ultimo_envio_juego = PackedByteArray()
	con.enviar_lista_acceso_casa(5, "")
	_comprobar("vaciar la lista es un envio valido",
		con.ultimo_envio_juego == PackedByteArray([0x8A, 0, 5, 0, 0, 0, 0, 0]),
		"obtenido %s" % str(con.ultimo_envio_juego))

	# Sin ventana abierta no hay nada que contestar. El servidor exige que el
	# id coincida con el suyo, asi que un 0 nunca podria aplicarse.
	con.ultimo_envio_juego = PackedByteArray()
	con.enviar_lista_acceso_casa(0, "Qa Share Duo")
	_comprobar("sin id de ventana no se manda nada",
		con.ultimo_envio_juego.is_empty())


## El 0x97 tiene dos significados segun la direccion. Esta prueba existe para
## que nadie los unifique despues "para limpiar": son mensajes distintos.
func _probar_direccion() -> void:
	var con = CONEXION.new()
	root.add_child(con)

	con.enviar_pedir_canales()
	_comprobar("0x97 SALIENTE sigue siendo pedir canales, sin payload",
		con.ultimo_envio_juego == PackedByteArray([0x97]),
		"obtenido %s" % str(con.ultimo_envio_juego))

	# Y el 0x97 ENTRANTE, con los mismos bytes de opcode, es la ventana.
	var estado = ESTADO.new()
	var ventanas: Array = []
	estado.ventana_casa.connect(func(datos): ventanas.append(datos))
	var msg = MENSAJE.new()
	msg.escribir_u8(0x97)
	msg.escribir_u8(0x00)
	msg.escribir_u32(3)
	msg.escribir_texto("# Guests of Mill Avenue 3\n")
	estado.procesar(msg)
	_comprobar("0x97 ENTRANTE es la ventana de lista de acceso",
		ventanas.size() == 1 and int(ventanas[0].get("id", 0)) == 3)

	# El 0x8A saliente no debe confundirse con el 0x89 de la ventana de texto,
	# que es su vecino y tiene un campo menos.
	con.ultimo_envio_juego = PackedByteArray()
	con.enviar_texto_ventana(3, "")
	_comprobar("0x89 sigue sin byte de lista, con un campo menos que el 0x8A",
		con.ultimo_envio_juego == PackedByteArray([0x89, 3, 0, 0, 0, 0, 0]),
		"obtenido %s" % str(con.ultimo_envio_juego))


func _comprobar(nombre: String, correcto: bool, detalle: String = "") -> void:
	if correcto:
		print("  OK   %s" % nombre)
	else:
		_fallas += 1
		printerr("  FALLA %s%s" % [nombre, "" if detalle.is_empty() else ": " + detalle])
