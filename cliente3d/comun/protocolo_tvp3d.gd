class_name ProtocoloTVP3D
extends RefCounted

## Protocolo pequeno y propio para el servidor Godot.
##
## Cada paquete usa un marco fijo de 4 bytes little-endian con el tamano
## del cuerpo, seguido por un opcode y un diccionario JSON. JSON se usa en
## esta primera rebanada para que los mensajes sean faciles de inspeccionar;
## el marco queda preparado para cambiar a binario sin tocar el transporte.

enum Tipo {
	HELLO = 1,
	WELCOME = 2,
	STATE = 3,
	MOVE = 4,
	ERROR = 5,
	PING = 6,
	PONG = 7,
	GOODBYE = 8,
}

const MAX_PAQUETE := 64 * 1024


static func empaquetar(tipo: int, datos: Dictionary = {}) -> PackedByteArray:
	var cuerpo := PackedByteArray([tipo & 0xFF])
	cuerpo.append_array(JSON.stringify(datos).to_utf8_buffer())

	var paquete := PackedByteArray()
	_escribir_u32(paquete, cuerpo.size())
	paquete.append_array(cuerpo)
	return paquete


static func extraer(buffer: PackedByteArray) -> Dictionary:
	var mensajes: Array = []
	var resto := buffer

	while resto.size() >= 4:
		var largo := _leer_u32(resto, 0)
		if largo > MAX_PAQUETE:
			return {
				"buffer": PackedByteArray(),
				"mensajes": mensajes,
				"error": "Paquete demasiado grande: %d bytes" % largo,
			}
		if resto.size() < 4 + largo:
			break

		var cuerpo: PackedByteArray = resto.slice(4, 4 + largo)
		resto = resto.slice(4 + largo)
		if cuerpo.is_empty():
			return {
				"buffer": resto,
				"mensajes": mensajes,
				"error": "Paquete sin opcode",
			}

		var datos: Variant = {}
		if cuerpo.size() > 1:
			var decodificado: Variant = JSON.parse_string(
				cuerpo.slice(1).get_string_from_utf8())
			if decodificado == null or typeof(decodificado) != TYPE_DICTIONARY:
				return {
					"buffer": resto,
					"mensajes": mensajes,
					"error": "JSON invalido en el paquete",
				}
			datos = decodificado

		mensajes.append({"tipo": int(cuerpo[0]), "datos": datos})

	return {"buffer": resto, "mensajes": mensajes, "error": ""}


static func posicion_a_diccionario(posicion: Vector3i) -> Dictionary:
	return {"x": posicion.x, "y": posicion.y, "z": posicion.z}


static func diccionario_a_posicion(datos: Dictionary) -> Vector3i:
	return Vector3i(
		int(datos.get("x", 0)),
		int(datos.get("y", 0)),
		int(datos.get("z", 7)))


static func _escribir_u32(destino: PackedByteArray, valor: int) -> void:
	destino.append(valor & 0xFF)
	destino.append((valor >> 8) & 0xFF)
	destino.append((valor >> 16) & 0xFF)
	destino.append((valor >> 24) & 0xFF)


static func _leer_u32(origen: PackedByteArray, offset: int) -> int:
	return int(origen[offset]) \
		| (int(origen[offset + 1]) << 8) \
		| (int(origen[offset + 2]) << 16) \
		| (int(origen[offset + 3]) << 24)
