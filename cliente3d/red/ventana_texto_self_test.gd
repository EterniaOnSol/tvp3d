extends SceneTree

# Self-test de la ventana de texto 7.72, sin sockets ni servidor.
#
# El servidor la abre al usar un cartel, una carta o la etiqueta de una parcel:
#
#   protocolgame.cpp:2091-2115  sendTextWindow -> 0x96
#     u32 id de ventana
#     item (client id, mas un byte si es apilable o liquido)
#     u16 maximo
#     string texto
#     string autor
#
#   protocolgame.cpp:1095-1100  parseTextWindow <- 0x89
#     u32 id de ventana, string texto
#
# El paquete NO dice si el item se puede escribir: manda un maximo y, si no
# correspondia, el servidor rechaza el 0x89 con un 0xB4. Por eso el cliente no
# adivina: expone lo que llego y deja que el servidor decida.
#
#   ...Godot --headless --path cliente3d --script res://red/ventana_texto_self_test.gd

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const MENSAJE := preload("res://red/mensaje.gd")

var _fallas := 0


func _initialize() -> void:
	print("Ventana de texto TVP 7.72 self-test")
	_probar_recepcion()
	_probar_envio()
	if _fallas > 0:
		printerr("Ventana de texto self-test: %d falla(s)" % _fallas)
		quit(1)
		return
	print("Ventana de texto TVP 7.72 self-test: OK")
	quit(0)


func _probar_recepcion() -> void:
	var estado = ESTADO.new()
	var ventanas: Array = []
	estado.ventana_texto.connect(func(datos): ventanas.append(datos))
	var textos: Array = []
	estado.mensaje_servidor.connect(func(texto): textos.append(texto))

	var msg = MENSAJE.new()
	msg.escribir_u8(0x96)
	msg.escribir_u32(0x0A0B0C0D)
	msg.escribir_u16(2599)          # tapestry: ni apilable ni liquido
	msg.escribir_u16(128)           # maximo de caracteres
	msg.escribir_texto("Valentino\nRookgaard")
	msg.escribir_texto("GOD VALENTINO")
	# Un mensaje pegado detras comprueba que no quedo ni un byte de mas.
	msg.escribir_u8(0xB4)
	msg.escribir_u8(0x16)
	msg.escribir_texto("sigue alineado")
	estado.procesar(msg)

	_comprobar("la ventana de texto llega una sola vez", ventanas.size() == 1)
	if ventanas.size() == 1:
		var datos: Dictionary = ventanas[0]
		_comprobar("conserva el id de ventana",
			int(datos.get("id", 0)) == 0x0A0B0C0D)
		_comprobar("conserva el client id del item",
			int(datos.get("cid", 0)) == 2599)
		_comprobar("nombra el item con el catalogo",
			str(datos.get("nombre", "")) == "tapestry")
		_comprobar("conserva el maximo de caracteres",
			int(datos.get("maximo", 0)) == 128)
		_comprobar("conserva el texto con sus saltos de linea",
			str(datos.get("texto", "")) == "Valentino\nRookgaard")
		_comprobar("conserva quien lo escribio",
			str(datos.get("autor", "")) == "GOD VALENTINO")
	_comprobar("el mensaje siguiente no queda corrido",
		textos == ["sigue alineado"] and msg.sin_leer() == 0)

	# Una ventana sin texto ni autor es lo que llega en una etiqueta en blanco.
	var vacia = MENSAJE.new()
	vacia.escribir_u8(0x96)
	vacia.escribir_u32(7)
	vacia.escribir_u16(2599)
	vacia.escribir_u16(64)
	vacia.escribir_texto("")
	vacia.escribir_texto("")
	estado.procesar(vacia)
	_comprobar("una etiqueta en blanco tambien abre su ventana",
		ventanas.size() == 2 and str(ventanas[1].get("texto", "x")) == ""
		and str(ventanas[1].get("autor", "x")) == "")
	_comprobar("la etiqueta en blanco consume su mensaje entero",
		vacia.sin_leer() == 0)
	_comprobar("el estado conserva la ultima ventana",
		int(estado.ultima_ventana_texto.get("id", 0)) == 7)

	# Truncada: no debe emitir nada ni dejar basura.
	var corta = MENSAJE.new()
	corta.escribir_u8(0x96)
	corta.escribir_u32(9)
	corta.escribir_u16(2599)
	estado.procesar(corta)
	_comprobar("una ventana truncada no se emite", ventanas.size() == 2)


func _probar_envio() -> void:
	var con = CONEXION.new()
	root.add_child(con)

	con.enviar_texto_ventana(0x0A0B0C0D, "Valentino\nRookgaard")
	var esperado := PackedByteArray([0x89, 0x0D, 0x0C, 0x0B, 0x0A,
		0x13, 0x00])   # 19 caracteres
	esperado.append_array("Valentino\nRookgaard".to_utf8_buffer())
	_comprobar("escribir manda 0x89 con id y texto",
		con.ultimo_envio_juego == esperado,
		"obtenido %s" % str(con.ultimo_envio_juego))

	con.ultimo_envio_juego = PackedByteArray()
	con.enviar_texto_ventana(0, "sin ventana")
	_comprobar("sin id de ventana no se manda nada",
		con.ultimo_envio_juego.is_empty())

	con.enviar_texto_ventana(5, "")
	_comprobar("borrar el texto es un envio valido",
		con.ultimo_envio_juego == PackedByteArray([0x89, 5, 0, 0, 0, 0, 0]),
		"obtenido %s" % str(con.ultimo_envio_juego))


func _comprobar(nombre: String, correcto: bool, detalle: String = "") -> void:
	if correcto:
		print("  OK   %s" % nombre)
	else:
		_fallas += 1
		printerr("  FALLA %s%s" % [nombre, "" if detalle.is_empty() else ": " + detalle])
