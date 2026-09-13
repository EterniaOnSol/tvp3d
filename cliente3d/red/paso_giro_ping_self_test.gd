extends SceneTree

# Self-test de las ordenes salientes de un solo byte, sin sockets ni servidor.
#
# Nueve acciones semanticas que el servidor despacha por el NUMERO de opcode,
# porque la direccion no viaja como dato:
#
#   protocolgame.cpp:494       0x1E -> Game::playerReceivePing
#   protocolgame.cpp:497-500   0x65..0x68 -> Game::playerMove(NORTH..WEST)
#   protocolgame.cpp:506-509   0x6F..0x72 -> Game::playerTurn(NORTH..WEST)
#
# LO QUE ESTA PRUEBA CUIDA DE VERDAD ES LA DIRECCION. Los nueve numeros ya
# significan otra cosa ENTRANDO, y `estado_mundo.gd` los lee asi:
#
#   0x1E entrante  -> el servidor pregunta "seguis ahi?" (pedido_ping)
#   0x65..0x68     -> franjas nuevas de mapa por cada lado
#   0x6F..0x72     -> contenedor cerrado / alta / cambio / baja
#
# Por eso no hay tabla de opcodes compartida entre sentidos: hay un metodo por
# direccion saliente, y esta prueba comprueba ademas que el parser ENTRANTE
# sigue leyendo esos mismos numeros con su significado de siempre.
#
#   ...Godot --headless --path cliente3d --script res://red/paso_giro_ping_self_test.gd

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const MENSAJE := preload("res://red/mensaje.gd")

var _fallas := 0


func _initialize() -> void:
	print("Paso, giro y ping TVP 7.72 self-test")
	_probar_envio()
	_probar_colision_de_direccion()
	if _fallas > 0:
		printerr("Paso, giro y ping self-test: %d falla(s)" % _fallas)
		quit(1)
		return
	print("Paso, giro y ping TVP 7.72 self-test: OK")
	quit(0)


func _probar_envio() -> void:
	var con = CONEXION.new()
	root.add_child(con)

	con.enviar_respuesta_ping()
	_un_byte("responder el latido manda 0x1E", con, 0x1E)

	con.enviar_paso_norte()
	_un_byte("paso al norte manda 0x65", con, 0x65)

	con.enviar_paso_este()
	_un_byte("paso al este manda 0x66", con, 0x66)

	con.enviar_paso_sur()
	_un_byte("paso al sur manda 0x67", con, 0x67)

	con.enviar_paso_oeste()
	_un_byte("paso al oeste manda 0x68", con, 0x68)

	con.enviar_giro_norte()
	_un_byte("giro al norte manda 0x6F", con, 0x6F)

	con.enviar_giro_este()
	_un_byte("giro al este manda 0x70", con, 0x70)

	con.enviar_giro_sur()
	_un_byte("giro al sur manda 0x71", con, 0x71)

	con.enviar_giro_oeste()
	_un_byte("giro al oeste manda 0x72", con, 0x72)

	# El auto-camino sigue siendo 0x64 con su cuenta y sus direcciones: este
	# turno no lo toca y la regresion lo deja escrito. Se comprueba sobre el
	# armador, porque `enviar_auto_camino` cifra por su cuenta con `_enviar` y
	# NO pasa por `enviar_juego`, asi que no toca `ultimo_envio_juego`.
	var antes: PackedByteArray = con.ultimo_envio_juego
	_comprobar("el auto-camino sigue armando 0x64 con cuenta y direcciones",
		con._paquete_auto_camino([Vector2i(0, -1), Vector2i(1, 0)])
			== PackedByteArray([0x64, 0x02, 0x03, 0x01]),
		"obtenido %s" % str(con._paquete_auto_camino(
			[Vector2i(0, -1), Vector2i(1, 0)])))
	con.enviar_auto_camino([Vector2i(0, -1), Vector2i(1, 0)])
	_comprobar("el auto-camino no se rearmo sobre los pasos simples",
		con.ultimo_envio_juego == antes,
		"ultimo_envio_juego cambio a %s" % str(con.ultimo_envio_juego))


func _probar_colision_de_direccion() -> void:
	# El 0x1E ENTRANTE es la pregunta, no la respuesta. Que exista
	# `enviar_respuesta_ping()` no debe convertir al parser en un emisor.
	# El acumulador es un Array a proposito: las lambdas de GDScript capturan
	# los enteros locales POR VALOR, asi que un contador `int` nunca se veria
	# incrementado desde afuera y la prueba mentiria.
	var estado = ESTADO.new()
	var latidos: Array = []
	estado.pedido_ping.connect(func(): latidos.append(true))
	var pregunta = MENSAJE.new()
	pregunta.escribir_u8(0x1E)
	estado.procesar(pregunta)
	_comprobar("el 0x1E entrante sigue siendo el pedido de latido",
		latidos.size() == 1, "latidos=%d" % latidos.size())
	_comprobar("el 0x1E entrante se consume entero",
		pregunta.sin_leer() == 0, "sobran %d byte(s)" % pregunta.sin_leer())

	# El 0x6F entrante sigue cerrando un contenedor. Es el representante del
	# bloque 0x6F..0x72, que entrando es trafico de contenedores y saliendo es
	# giro; si alguien unificara los dos sentidos, esto se rompe.
	var estado_cont = ESTADO.new()
	var cerrados: Array = []
	estado_cont.contenedor_cerrado.connect(func(id): cerrados.append(id))
	var cierre = MENSAJE.new()
	cierre.escribir_u8(0x6F)
	cierre.escribir_u8(0x07)
	estado_cont.procesar(cierre)
	_comprobar("el 0x6F entrante sigue cerrando un contenedor, no girando",
		cerrados == [7], "cerrados=%s" % str(cerrados))
	_comprobar("el 0x6F entrante se consume entero",
		cierre.sin_leer() == 0, "sobran %d byte(s)" % cierre.sin_leer())
	_comprobar("el 0x6F entrante no cae en opcode desconocido",
		estado_cont.opcodes_desconocidos().is_empty(),
		str(estado_cont.opcodes_desconocidos()))


func _un_byte(nombre: String, con, esperado: int) -> void:
	var obtenido: PackedByteArray = con.ultimo_envio_juego
	_comprobar("%s (un solo byte)" % nombre, obtenido.size() == 1,
		"largo %d" % obtenido.size())
	_comprobar(nombre, obtenido == PackedByteArray([esperado]),
		"obtenido %s, esperado %s" % [str(obtenido),
			str(PackedByteArray([esperado]))])


func _comprobar(nombre: String, correcto: bool, detalle: String = "") -> void:
	if correcto:
		print("  OK   %s" % nombre)
	else:
		_fallas += 1
		printerr("  FALLA %s%s" % [nombre, "" if detalle.is_empty() else ": " + detalle])
