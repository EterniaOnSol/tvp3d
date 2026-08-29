extends SceneTree

# Self-test de las ordenes de comercio 7.72, sin sockets ni servidor.
#
# Los cuatro opcodes y sus payloads salen del servidor:
#
#   protocolgame.cpp:511-514   el switch que los acepta
#   parseRequestTrade          posicion, client id, stackpos, id de jugador
#   parseLookInTrade           contraparte (u8), indice (u8)
#   0x7F aceptar y 0x80 cerrar no llevan payload
#
# El equipo se direcciona con la posicion (0xFFFF, ranura, 0), que es como
# Tibia nombra el inventario en todos los mensajes de objeto.
#
#   ...Godot --headless --path cliente3d --script res://red/comercio_self_test.gd

const CONEXION := preload("res://red/conexion772.gd")

var _fallas := 0


func _initialize() -> void:
	print("Comercio TVP 7.72 self-test")
	var con = CONEXION.new()
	root.add_child(con)

	var id_jugador := 0x12345678
	var cid := 0x0B3A          # 2874, el vial
	var posicion := Vector3i(32097, 32219, 7)

	con.enviar_solicitar_comercio(posicion, cid, 2, id_jugador)
	_igual("ofrecer un objeto del suelo manda 0x7D con posicion y stackpos",
		con.ultimo_envio_juego, PackedByteArray([0x7D,
			0x61, 0x7D,   # x 32097
			0xDB, 0x7D,   # y 32219
			0x07,         # z
			0x3A, 0x0B,   # client id
			0x02,         # stackpos
			0x78, 0x56, 0x34, 0x12]))

	con.enviar_solicitar_comercio_inventario(5, cid, id_jugador)
	_igual("ofrecer un objeto del equipo usa (0xFFFF, ranura, 0)",
		con.ultimo_envio_juego, PackedByteArray([0x7D,
			0xFF, 0xFF,   # x, marca de inventario
			0x05, 0x00,   # y, la ranura
			0x00,         # z
			0x3A, 0x0B,
			0x00,         # stackpos siempre 0 en el equipo
			0x78, 0x56, 0x34, 0x12]))

	con.ultimo_envio_juego = PackedByteArray()
	con.enviar_solicitar_comercio(posicion, cid, 2, 0)
	con.enviar_solicitar_comercio_inventario(5, cid, -1)
	_comprobar("sin jugador al que ofrecerle no se manda nada",
		con.ultimo_envio_juego.is_empty(),
		"mando %s" % str(con.ultimo_envio_juego))

	con.enviar_mirar_comercio(false, 3)
	_igual("mirar la oferta propia manda 0x7E con 0", con.ultimo_envio_juego,
		PackedByteArray([0x7E, 0x00, 0x03]))

	con.enviar_mirar_comercio(true, 1)
	_igual("mirar la oferta del otro manda 0x7E con 1", con.ultimo_envio_juego,
		PackedByteArray([0x7E, 0x01, 0x01]))

	con.enviar_aceptar_comercio()
	_igual("aceptar manda 0x7F sin payload", con.ultimo_envio_juego,
		PackedByteArray([0x7F]))

	con.enviar_cerrar_comercio()
	_igual("cerrar manda 0x80 sin payload", con.ultimo_envio_juego,
		PackedByteArray([0x80]))

	if _fallas > 0:
		printerr("Comercio TVP 7.72 self-test: %d falla(s)" % _fallas)
		quit(1)
		return
	print("Comercio TVP 7.72 self-test: OK")
	quit(0)


func _igual(nombre: String, obtenido: PackedByteArray,
		esperado: PackedByteArray) -> void:
	_comprobar(nombre, obtenido == esperado,
		"obtenido %s, esperado %s" % [str(obtenido), str(esperado)])


func _comprobar(nombre: String, correcto: bool, detalle: String = "") -> void:
	if correcto:
		print("  OK   %s" % nombre)
	else:
		_fallas += 1
		printerr("  FALLA %s%s" % [nombre, "" if detalle.is_empty() else ": " + detalle])
