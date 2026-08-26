extends RefCounted

# =====================================================================
#  Un mensaje del protocolo de Tibia: los bytes crudos más un cursor.
#
#  Todo el protocolo son números pegados uno atrás del otro, en orden
#  "chico primero" (little endian), y textos con su largo adelante.
#  Esta clase es la que sabe leerlos y escribirlos; el resto del cliente
#  no toca bytes nunca.
#
#  Las posiciones del juego son (x, y, z) — ahí está la altura del mundo
#  que 3DTIBIA usa para dibujar en 3D.
# =====================================================================

var datos := PackedByteArray()
var cursor := 0


func _init(inicial: PackedByteArray = PackedByteArray()) -> void:
	datos = inicial.duplicate()


func sin_leer() -> int:
	return datos.size() - cursor


func tam() -> int:
	return datos.size()


# --------------------------------------------------------------------
#  Leer
# --------------------------------------------------------------------
func leer_u8() -> int:
	var v: int = datos[cursor]
	cursor += 1
	return v


func leer_u16() -> int:
	var v: int = datos[cursor] | (datos[cursor + 1] << 8)
	cursor += 2
	return v


func leer_u32() -> int:
	var v: int = datos[cursor] | (datos[cursor + 1] << 8) \
		| (datos[cursor + 2] << 16) | (datos[cursor + 3] << 24)
	cursor += 4
	return v


func leer_u64() -> int:
	var bajo := leer_u32()
	var alto := leer_u32()
	return bajo | (alto << 32)


func espiar_u16() -> int:
	"""Como leer_u16(), pero sin mover el cursor — para decidir qué viene
	antes de comprometerse a leerlo."""
	return datos[cursor] | (datos[cursor + 1] << 8)


func espiar_u8() -> int:
	return datos[cursor]


func leer_texto() -> String:
	var largo := leer_u16()
	var trozo := datos.slice(cursor, cursor + largo)
	cursor += largo
	return trozo.get_string_from_utf8()


func leer_posicion() -> Vector3i:
	"""(x, y, z). El z es el piso: 0 es la cima de la montaña, 15 el fondo."""
	var x := leer_u16()
	var y := leer_u16()
	var z := leer_u8()
	return Vector3i(x, y, z)


func saltar(n: int) -> void:
	cursor += n


# --------------------------------------------------------------------
#  Escribir
# --------------------------------------------------------------------
func escribir_u8(v: int) -> void:
	datos.append(v & 0xFF)


func escribir_u16(v: int) -> void:
	datos.append(v & 0xFF)
	datos.append((v >> 8) & 0xFF)


func escribir_u32(v: int) -> void:
	datos.append(v & 0xFF)
	datos.append((v >> 8) & 0xFF)
	datos.append((v >> 16) & 0xFF)
	datos.append((v >> 24) & 0xFF)


func escribir_texto(s: String) -> void:
	var b := s.to_utf8_buffer()
	escribir_u16(b.size())
	datos.append_array(b)


func escribir_bytes(b: PackedByteArray) -> void:
	datos.append_array(b)


func escribir_relleno(cuantos: int, valor: int = 0) -> void:
	for _i in range(cuantos):
		datos.append(valor)


func anteponer_u16(v: int) -> void:
	var nuevo := PackedByteArray([v & 0xFF, (v >> 8) & 0xFF])
	nuevo.append_array(datos)
	datos = nuevo


func anteponer_u32(v: int) -> void:
	var nuevo := PackedByteArray([
		v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF])
	nuevo.append_array(datos)
	datos = nuevo


func anteponer_u8(v: int) -> void:
	var nuevo := PackedByteArray([v & 0xFF])
	nuevo.append_array(datos)
	datos = nuevo
