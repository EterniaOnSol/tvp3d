extends SceneTree

const PROTOCOLO := preload("res://comun/protocolo_tvp3d.gd")


func _init() -> void:
	var posicion := {"x": 32097, "y": 32219, "z": 7}
	var entidad := {
		"id": 1,
		"nombre": "Jugador",
		"pos": posicion,
		"direccion": "sur",
	}
	var mapa := {
		"version": 1,
		"origen": {"x": 32085, "y": 32210, "z": 7},
		"ancho": 3,
		"alto": 3,
		"celdas": [{"x": 0, "y": 0, "tipo": 0}],
	}
	var fixtures := [
		{"tipo": PROTOCOLO.Tipo.HELLO, "datos": {"nombre": "Jugador"}},
		{"tipo": PROTOCOLO.Tipo.WELCOME, "datos": {
			"id": 1, "nombre": "Jugador", "pos": posicion, "mapa": mapa}},
		{"tipo": PROTOCOLO.Tipo.STATE, "datos": {"jugadores": [entidad]}},
		{"tipo": PROTOCOLO.Tipo.MOVE, "datos": {"dx": 1, "dy": 0}},
		{"tipo": PROTOCOLO.Tipo.ERROR, "datos": {"mensaje": "Movimiento rechazado"}},
		{"tipo": PROTOCOLO.Tipo.PING, "datos": {}},
		{"tipo": PROTOCOLO.Tipo.PONG, "datos": {}},
		{"tipo": PROTOCOLO.Tipo.GOODBYE, "datos": {}},
	]

	for fixture in fixtures:
		var paquete: PackedByteArray = PROTOCOLO.empaquetar(fixture.tipo, fixture.datos)
		assert(not paquete.is_empty())
		var resultado: Dictionary = PROTOCOLO.extraer(paquete)
		assert(resultado.error == "")
		assert(not resultado.incompleto)
		assert(resultado.buffer.is_empty())
		assert(resultado.mensajes.size() == 1)
		assert(resultado.mensajes[0].tipo == fixture.tipo)
		if resultado.mensajes[0].datos != fixture.datos:
			print("Round-trip mismatch opcode=%d sent=%s received=%s" % [
				fixture.tipo, JSON.stringify(fixture.datos),
				JSON.stringify(resultado.mensajes[0].datos)])
		assert(resultado.mensajes[0].datos == fixture.datos)

	var hello := PROTOCOLO.empaquetar(PROTOCOLO.Tipo.HELLO, {"nombre": "Fragmentado"})
	for corte in range(1, mini(7, hello.size())):
		var parcial: PackedByteArray = hello.slice(0, corte)
		var incompleto: Dictionary = PROTOCOLO.extraer(parcial)
		assert(incompleto.incompleto)
		assert(incompleto.error == "")
		assert(incompleto.mensajes.is_empty())
		assert(incompleto.buffer == parcial)
		var completo: Dictionary = PROTOCOLO.extraer(hello)
		assert(completo.mensajes.size() == 1)

	var concatenado := hello
	concatenado.append_array(PROTOCOLO.empaquetar(PROTOCOLO.Tipo.PING, {}))
	concatenado.append_array(PROTOCOLO.empaquetar(PROTOCOLO.Tipo.GOODBYE, {}))
	var varios: Dictionary = PROTOCOLO.extraer(concatenado)
	assert(varios.error == "")
	assert(varios.mensajes.size() == 3)
	assert(varios.buffer.is_empty())

	var sin_opcode := PackedByteArray([0, 0, 0, 0])
	assert(PROTOCOLO.extraer(sin_opcode).error == "PAQUETE_SIN_OPCODE")
	var demasiado_grande := PackedByteArray([1, 0, 1, 0])
	assert(PROTOCOLO.extraer(demasiado_grande).error == "PAQUETE_DEMASIADO_GRANDE")
	var desconocido := _frame(PackedByteArray([0xFF, 0x7B, 0x7D]))
	assert(PROTOCOLO.extraer(desconocido).error == "OPCODE_DESCONOCIDO")
	var json_invalido := _frame(PackedByteArray([PROTOCOLO.Tipo.PING, 0x7B]))
	assert(PROTOCOLO.extraer(json_invalido).error == "JSON_INVALIDO")
	var json_no_objeto := _frame(PackedByteArray([PROTOCOLO.Tipo.PING, 0x5B, 0x5D]))
	assert(PROTOCOLO.extraer(json_no_objeto).error == "JSON_NO_OBJETO")
	var movimiento_invalido := _frame(PackedByteArray([PROTOCOLO.Tipo.MOVE])
		+ "{\"dx\":1,\"dy\":1}".to_utf8_buffer())
	assert(PROTOCOLO.extraer(movimiento_invalido).error == "MENSAJE_INVALIDO")
	assert(not PROTOCOLO.validar_mensaje(PROTOCOLO.Tipo.MOVE, {"dx": 1, "dy": 1}).ok)

	print("Protocolo TVP3D self-test: OK")
	quit()


func _frame(body: PackedByteArray) -> PackedByteArray:
	var frame := PackedByteArray([
		body.size() & 0xFF,
		(body.size() >> 8) & 0xFF,
		(body.size() >> 16) & 0xFF,
		(body.size() >> 24) & 0xFF,
	])
	frame.append_array(body)
	return frame
