extends SceneTree

# Self-test de las ordenes de party 7.72, sin sockets ni servidor.
#
# Los seis opcodes y sus payloads salen del propio servidor:
#
#   protocolgame.cpp:536-541   el switch que los acepta
#   protocolgame.cpp:1171-1207 lo que lee cada uno
#
#   0xA3 invitar            u32 id de criatura
#   0xA4 unirse             u32 id de criatura
#   0xA5 revocar invitacion u32 id de criatura
#   0xA6 pasar liderazgo    u32 id de criatura
#   0xA7 salir              sin payload
#   0xA8 experiencia compartida  u8 (1 activa, 0 no)
#
# El servidor no contesta con un paquete de party: lo que vuelve es el escudo
# de cada criatura por el `0x91`, que ya cubre `estado_criatura_self_test.gd`.
#
#   ...Godot --headless --path cliente3d --script res://red/party_self_test.gd

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const MENSAJE := preload("res://red/mensaje.gd")

var _fallas := 0


func _initialize() -> void:
	print("Party TVP 7.72 self-test")
	var con = CONEXION.new()
	root.add_child(con)

	# Un id de criatura con los cuatro bytes distintos detecta cualquier
	# vuelta del orden little-endian.
	var id := 0x12345678

	con.enviar_invitar_a_party(id)
	_igual("invitar manda 0xA3 con el id en little-endian",
		con.ultimo_envio_juego,
		PackedByteArray([0xA3, 0x78, 0x56, 0x34, 0x12]))

	con.enviar_unirse_a_party(id)
	_igual("unirse manda 0xA4", con.ultimo_envio_juego,
		PackedByteArray([0xA4, 0x78, 0x56, 0x34, 0x12]))

	con.enviar_revocar_invitacion_party(id)
	_igual("revocar la invitacion manda 0xA5", con.ultimo_envio_juego,
		PackedByteArray([0xA5, 0x78, 0x56, 0x34, 0x12]))

	con.enviar_pasar_liderazgo_party(id)
	_igual("pasar el liderazgo manda 0xA6", con.ultimo_envio_juego,
		PackedByteArray([0xA6, 0x78, 0x56, 0x34, 0x12]))

	con.enviar_salir_de_party()
	_igual("salir de la party manda 0xA7 sin payload",
		con.ultimo_envio_juego, PackedByteArray([0xA7]))

	con.enviar_experiencia_compartida(true)
	_igual("la experiencia compartida activa manda 0xA8 01",
		con.ultimo_envio_juego, PackedByteArray([0xA8, 0x01]))

	con.enviar_experiencia_compartida(false)
	_igual("la experiencia compartida apagada manda 0xA8 00",
		con.ultimo_envio_juego, PackedByteArray([0xA8, 0x00]))

	# Un id que no identifica a nadie no se manda: el servidor solo podria
	# contestar un cancel.
	con.ultimo_envio_juego = PackedByteArray()
	con.enviar_invitar_a_party(0)
	con.enviar_unirse_a_party(-1)
	con.enviar_pasar_liderazgo_party(0)
	con.enviar_revocar_invitacion_party(0)
	_comprobar("un id vacio no manda nada", con.ultimo_envio_juego.is_empty(),
		"mando %s" % str(con.ultimo_envio_juego))

	_probar_escudos_de_party()

	if _fallas > 0:
		printerr("Party TVP 7.72 self-test: %d falla(s)" % _fallas)
		quit(1)
		return
	print("Party TVP 7.72 self-test: OK")
	quit(0)


func _probar_escudos_de_party() -> void:
	## La unica respuesta de party que manda este servidor es el escudo de una
	## criatura conocida (`Party::updateAllPartyIcons` -> `sendCreatureShield`).
	var estado = ESTADO.new()
	var id := 900
	estado.mi_id = 1
	estado.criaturas[id] = {
		"pos": Vector3i(100, 100, 7), "nombre": "Partner", "apariencia": 128,
		"direccion": 2, "vida": 100, "luz_nivel": 0, "luz_color": 0,
		"velocidad": 220, "calavera": 0, "escudo_party": 0,
	}
	var estados: Array = []
	estado.estado_criatura_actualizado.connect(func(_id, datos):
		estados.append(int(datos.get("escudo_party", -1))))

	for valor in [4, 3, 2, 1, 0]:
		var msg = MENSAJE.new()
		msg.escribir_u8(0x91)
		msg.escribir_u32(id)
		msg.escribir_u8(valor)
		estado.procesar(msg)
		_comprobar("el 0x91 deja el escudo %d en la criatura" % valor,
			int(estado.criaturas[id]["escudo_party"]) == valor)
		_comprobar("el 0x91 con escudo %d consume su mensaje entero" % valor,
			msg.sin_leer() == 0)
	_comprobar("cada cambio de escudo avisa una vez", estados.size() == 5,
		"aviso %d veces" % estados.size())

	# Un escudo para una criatura desconocida se consume pero no la inventa.
	var ajeno = MENSAJE.new()
	ajeno.escribir_u8(0x91)
	ajeno.escribir_u32(4242)
	ajeno.escribir_u8(3)
	ajeno.escribir_u8(0xB4)
	ajeno.escribir_u8(0x16)
	ajeno.escribir_texto("sigue alineado")
	var textos: Array = []
	estado.mensaje_servidor.connect(func(texto): textos.append(texto))
	estado.procesar(ajeno)
	_comprobar("un escudo de una criatura desconocida no la crea",
		not estado.criaturas.has(4242))
	_comprobar("un escudo desconocido no desalinea el mensaje siguiente",
		textos == ["sigue alineado"] and ajeno.sin_leer() == 0)


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
