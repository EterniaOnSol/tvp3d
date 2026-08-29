extends SceneTree

const ESTADO := preload("res://red/estado_mundo.gd")
const MAPA := preload("res://red/mapa772.gd")
const MENSAJE := preload("res://red/mensaje.gd")


func _init() -> void:
	var estado := ESTADO.new()
	var mapa := MAPA.new()
	var id := 0x10203040
	var posicion := Vector3i(32097, 32219, 7)

	# AddCreature completo, byte por byte como ProtocolGame::AddCreature.
	var spawn := MENSAJE.new()
	spawn.escribir_u16(0x61)
	spawn.escribir_u32(0)
	spawn.escribir_u32(id)
	spawn.escribir_texto("Knight")
	spawn.escribir_u8(87)
	spawn.escribir_u8(2)
	spawn.escribir_u16(128)
	spawn.escribir_u8(10)
	spawn.escribir_u8(20)
	spawn.escribir_u8(30)
	spawn.escribir_u8(40)
	spawn.escribir_u8(6)
	spawn.escribir_u8(215)
	spawn.escribir_u16(180)
	spawn.escribir_u8(1)
	spawn.escribir_u8(2)
	var nuevas := []
	mapa.leer_cosa(spawn, posicion, nuevas)
	assert(spawn.sin_leer() == 0)
	estado._absorber({"casillas": {}, "criaturas": nuevas})
	var inicial: Dictionary = estado.criaturas[id]
	assert(inicial.luz_nivel == 6)
	assert(inicial.luz_color == 215)
	assert(inicial.velocidad == 180)
	assert(inicial.calavera == 1)
	assert(inicial.escudo_party == 2)

	var actualizaciones := []
	estado.estado_criatura_actualizado.connect(
		func(id_recibido, datos):
			actualizaciones.append({"id": id_recibido, "datos": datos}))
	var textos := []
	estado.mensaje_servidor.connect(func(texto): textos.append(texto))

	# Los cuatro mensajes variables deben dejar intacto el siguiente opcode.
	var msg := MENSAJE.new()
	msg.escribir_u8(0x8D)
	msg.escribir_u32(id)
	msg.escribir_u8(9)
	msg.escribir_u8(210)
	msg.escribir_u8(0x8F)
	msg.escribir_u32(id)
	msg.escribir_u16(220)
	msg.escribir_u8(0x90)
	msg.escribir_u32(id)
	msg.escribir_u8(3)
	msg.escribir_u8(0x91)
	msg.escribir_u32(id)
	msg.escribir_u8(4)
	msg.escribir_u8(0xB4)
	msg.escribir_u8(0x16)
	msg.escribir_texto("aligned")
	estado.procesar(msg)
	var actualizado: Dictionary = estado.criaturas[id]
	assert(actualizado.luz_nivel == 9)
	assert(actualizado.luz_color == 210)
	assert(actualizado.velocidad == 220)
	assert(actualizado.calavera == 3)
	assert(actualizado.escudo_party == 4)
	assert(actualizaciones.size() == 4)
	assert(actualizaciones.all(func(evento): return evento.id == id))
	assert(textos.back() == "aligned")
	assert(msg.sin_leer() == 0)

	# El marcador corto de giro conserva todos los campos que no transporta.
	estado._absorber({"casillas": {}, "criaturas": [{
		"id": id,
		"nombre": "",
		"apariencia": 0,
		"direccion": 3,
		"vida": 100,
		"donde": Vector3i(32098, 32219, 7),
	}]})
	var despues_giro: Dictionary = estado.criaturas[id]
	assert(despues_giro.vida == 87)
	assert(despues_giro.velocidad == 220)
	assert(despues_giro.calavera == 3)
	assert(despues_giro.escudo_party == 4)

	# Un payload fijo truncado no mueve el cursor ni inventa ceros.
	for bytes in [
		PackedByteArray([0x8D, 1, 2, 3, 4, 5]),
		PackedByteArray([0x8F, 1, 2, 3, 4, 5]),
		PackedByteArray([0x90, 1, 2, 3, 4]),
		PackedByteArray([0x91, 1, 2, 3, 4]),
	]:
		var truncado := MENSAJE.new(bytes)
		estado.procesar(truncado)
		assert(truncado.cursor == 0)

	# Un id desconocido se consume, pero no fabrica una criatura.
	var desconocido := MENSAJE.new()
	desconocido.escribir_u8(0x8F)
	desconocido.escribir_u32(99)
	desconocido.escribir_u16(777)
	desconocido.escribir_u8(0xB4)
	desconocido.escribir_u8(0x16)
	desconocido.escribir_texto("still aligned")
	estado.procesar(desconocido)
	assert(not estado.criaturas.has(99))
	assert(textos.back() == "still aligned")
	assert(desconocido.sin_leer() == 0)

	# Retirar al jugador con vida positiva puede ser teleport, no muerte.
	estado.mi_id = id
	estado.adentro = true
	estado.estadisticas = {"vida": 50}
	estado.casillas[posicion] = [{"tipo": "criatura", "id": id}]
	var muertes := []
	estado.jugador_muerto.connect(func(pos): muertes.append(pos))
	var teleport: RefCounted = _retiro(posicion, 0)
	estado.procesar(teleport)
	assert(muertes.is_empty())
	assert(estado.adentro)

	# Con HP autoritativo cero, el mismo 0x6C es la muerte de esta rama.
	estado.criaturas[id] = inicial
	estado.casillas[posicion] = [{"tipo": "criatura", "id": id}]
	estado.estadisticas = {"vida": 0}
	var muerte: RefCounted = _retiro(posicion, 0)
	muerte.escribir_u8(0xB4)
	muerte.escribir_u8(0x16)
	muerte.escribir_texto("death packet aligned")
	estado.procesar(muerte)
	assert(muertes == [posicion])
	assert(not estado.adentro)
	assert(textos.back() == "death packet aligned")
	assert(muerte.sin_leer() == 0)

	# La muerte real del 2026-08-29: el catalogo de items no alcanzo para leer
	# el mapa, la pila local quedo corrida y el indice del 0x6C apunto a otra
	# cosa. La muerte igual tiene que emitirse, porque la casilla del mensaje
	# es la del jugador y la vida autoritativa es cero.
	estado.adentro = true
	estado.mi_pos = posicion
	estado.estadisticas = {"vida": 0}
	estado.casillas[posicion] = [
		{"tipo": "item", "cid": 1234, "nombre": "fire"},
	]
	muertes.clear()
	var muerte_pila_corrida: RefCounted = _retiro(posicion, 1)
	estado.procesar(muerte_pila_corrida)
	assert(muertes == [posicion])
	assert(not estado.adentro)
	assert(muerte_pila_corrida.sin_leer() == 0)

	# Con la pila corrida pero vida positiva sigue sin haber muerte: eso es
	# teleport, refresh o un item que desaparecio de nuestra casilla.
	estado.adentro = true
	estado.estadisticas = {"vida": 120}
	estado.casillas[posicion] = [
		{"tipo": "item", "cid": 1234, "nombre": "fire"},
	]
	muertes.clear()
	var retiro_vivo: RefCounted = _retiro(posicion, 1)
	estado.procesar(retiro_vivo)
	assert(muertes.is_empty())
	assert(estado.adentro)

	# Una retirada en otra casilla nunca es nuestra muerte, ni con vida cero.
	estado.adentro = true
	estado.estadisticas = {"vida": 0}
	muertes.clear()
	var retiro_ajeno: RefCounted = _retiro(posicion + Vector3i(1, 0, 0), 0)
	estado.procesar(retiro_ajeno)
	assert(muertes.is_empty())
	assert(estado.adentro)

	# El mapa se declara desalineado si el jugador no aparece en su casilla.
	assert(estado.mapa_alineado)
	estado.casillas.clear()
	estado._revisar_alineacion()
	assert(not estado.mapa_alineado)

	print("Estado criatura TVP 7.72 self-test: OK")
	quit()


func _retiro(posicion: Vector3i, pila: int) -> RefCounted:
	var msg := MENSAJE.new()
	msg.escribir_u8(0x6C)
	msg.escribir_u16(posicion.x)
	msg.escribir_u16(posicion.y)
	msg.escribir_u8(posicion.z)
	msg.escribir_u8(pila)
	return msg
