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

const VERSION := 1
const MIN_BODY := 1
const MAX_PAQUETE := 64 * 1024
const MAX_NOMBRE := 24
const MAX_ERROR := 160


static func empaquetar(tipo: int, datos: Dictionary = {}) -> PackedByteArray:
	var validacion := validar_mensaje(tipo, datos)
	if not bool(validacion.get("ok", false)):
		push_error("No se puede empaquetar: %s" % validacion.get("error", "MENSAJE_INVALIDO"))
		return PackedByteArray()
	var cuerpo := PackedByteArray([tipo & 0xFF])
	cuerpo.append_array(JSON.stringify(datos).to_utf8_buffer())
	if cuerpo.size() > MAX_PAQUETE:
		push_error("No se puede empaquetar: PAYLOAD_EXCESIVO")
		return PackedByteArray()

	var paquete := PackedByteArray()
	_escribir_u32(paquete, cuerpo.size())
	paquete.append_array(cuerpo)
	return paquete


static func extraer(buffer: PackedByteArray) -> Dictionary:
	var mensajes: Array = []
	var resto := buffer

	while true:
		if resto.size() < 4:
			return {
				"buffer": resto,
				"mensajes": mensajes,
				"error": "",
				"incompleto": not resto.is_empty() or mensajes.is_empty(),
			}
		var largo := _leer_u32(resto, 0)
		if largo > MAX_PAQUETE:
			return {
				"buffer": PackedByteArray(),
				"mensajes": mensajes,
				"error": "PAQUETE_DEMASIADO_GRANDE",
			}
		if resto.size() < 4 + largo:
			return {
				"buffer": resto,
				"mensajes": mensajes,
				"error": "",
				"incompleto": true,
			}

		var cuerpo: PackedByteArray = resto.slice(4, 4 + largo)
		resto = resto.slice(4 + largo)
		if cuerpo.is_empty():
			return {
				"buffer": resto,
				"mensajes": mensajes,
				"error": "PAQUETE_SIN_OPCODE",
			}
		var tipo := int(cuerpo[0])
		if not es_tipo_valido(tipo):
			return {
				"buffer": resto,
				"mensajes": mensajes,
				"error": "OPCODE_DESCONOCIDO",
			}

		var datos: Variant = {}
		if cuerpo.size() > 1:
			var parser := JSON.new()
			var parse_error := parser.parse(cuerpo.slice(1).get_string_from_utf8())
			if parse_error != OK:
				return {
					"buffer": resto,
					"mensajes": mensajes,
					"error": "JSON_INVALIDO",
				}
			var decodificado: Variant = parser.data
			if typeof(decodificado) != TYPE_DICTIONARY:
				return {
					"buffer": resto,
					"mensajes": mensajes,
					"error": "JSON_NO_OBJETO",
				}
			datos = _normalizar_json(decodificado)

		var validacion := validar_mensaje(tipo, datos)
		if not bool(validacion.get("ok", false)):
			return {
				"buffer": resto,
				"mensajes": mensajes,
				"error": "MENSAJE_INVALIDO",
			}
		mensajes.append({"tipo": tipo, "datos": datos})

	return {"buffer": resto, "mensajes": mensajes, "error": "", "incompleto": false}


static func validar_mensaje(tipo: int, datos: Dictionary) -> Dictionary:
	if not es_tipo_valido(tipo):
		return {"ok": false, "error": "OPCODE_DESCONOCIDO"}
	match tipo:
		Tipo.HELLO:
			if not _texto_en_rango(datos.get("nombre", null), 1, MAX_NOMBRE):
				return {"ok": false, "error": "MENSAJE_INVALIDO"}
		Tipo.WELCOME:
			if int(datos.get("id", 0)) <= 0 \
					or not _texto_en_rango(datos.get("nombre", null), 1, MAX_NOMBRE) \
					or not _posicion_valida(datos.get("pos", null)) \
					or typeof(datos.get("mapa", null)) != TYPE_DICTIONARY:
				return {"ok": false, "error": "MENSAJE_INVALIDO"}
			var mapa: Dictionary = datos["mapa"]
			if int(mapa.get("version", -1)) != VERSION:
				return {"ok": false, "error": "PERFIL_INCOMPATIBLE"}
		Tipo.STATE:
			var jugadores: Variant = datos.get("jugadores", null)
			if typeof(jugadores) != TYPE_ARRAY:
				return {"ok": false, "error": "MENSAJE_INVALIDO"}
			for jugador in jugadores:
				if not _entidad_valida(jugador):
					return {"ok": false, "error": "MENSAJE_INVALIDO"}
		Tipo.MOVE:
			var dx: Variant = datos.get("dx", null)
			var dy: Variant = datos.get("dy", null)
			if typeof(dx) != TYPE_INT or typeof(dy) != TYPE_INT \
					or absi(int(dx)) > 1 or absi(int(dy)) > 1 \
					or absi(int(dx)) + absi(int(dy)) != 1:
				return {"ok": false, "error": "MOVIMIENTO_NO_CARDINAL"}
		Tipo.ERROR:
			if not _texto_en_rango(datos.get("mensaje", null), 1, MAX_ERROR):
				return {"ok": false, "error": "MENSAJE_INVALIDO"}
		Tipo.PING, Tipo.PONG, Tipo.GOODBYE:
			if not datos.is_empty():
				return {"ok": false, "error": "MENSAJE_INVALIDO"}
	return {"ok": true, "error": ""}


static func es_tipo_valido(tipo: int) -> bool:
	return tipo >= Tipo.HELLO and tipo <= Tipo.GOODBYE


static func _texto_en_rango(valor: Variant, minimo: int, maximo: int) -> bool:
	if typeof(valor) != TYPE_STRING:
		return false
	var texto := str(valor)
	return texto.length() >= minimo and texto.length() <= maximo


static func _posicion_valida(valor: Variant) -> bool:
	if typeof(valor) != TYPE_DICTIONARY:
		return false
	var posicion: Dictionary = valor
	if not posicion.has("x") or not posicion.has("y") or not posicion.has("z"):
		return false
	var z := int(posicion["z"])
	return z >= 0 and z <= 15


static func _entidad_valida(valor: Variant) -> bool:
	if typeof(valor) != TYPE_DICTIONARY:
		return false
	var entidad: Dictionary = valor
	if int(entidad.get("id", 0)) <= 0:
		return false
	if not _texto_en_rango(entidad.get("nombre", null), 1, MAX_NOMBRE):
		return false
	if not _posicion_valida(entidad.get("pos", null)):
		return false
	return str(entidad.get("direccion", "")) in ["norte", "este", "sur", "oeste"]


static func _normalizar_json(valor: Variant) -> Variant:
	if typeof(valor) == TYPE_ARRAY:
		var arreglo: Array = []
		for elemento in valor:
			arreglo.append(_normalizar_json(elemento))
		return arreglo
	if typeof(valor) == TYPE_DICTIONARY:
		var objeto: Dictionary = {}
		for clave in valor:
			objeto[clave] = _normalizar_json(valor[clave])
		return objeto
	if typeof(valor) == TYPE_FLOAT and is_equal_approx(float(valor), round(float(valor))):
		return roundi(float(valor))
	return valor


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
