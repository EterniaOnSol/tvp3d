extends RefCounted

# =====================================================================
#  XTEA — el cifrado de toda la partida.
#
#  Una vez que el RSA le pasó la llave al servidor, cada paquete que va
#  y viene está cifrado con esto. Es un algoritmo chiquito: 32 vueltas
#  de sumas y corrimientos sobre pares de números de 32 bits.
#
#  Godot trabaja con enteros de 64 bits con signo, así que después de
#  cada cuenta hay que recortar a 32 bits con & 0xFFFFFFFF. Si no, los
#  números crecen y el servidor recibe basura.
# =====================================================================

const DELTA := 0x9E3779B9
const M32 := 0xFFFFFFFF


static func cifrar(datos: PackedByteArray, llave: PackedInt64Array) -> PackedByteArray:
	"""El largo tiene que ser múltiplo de 8; el que llama se encarga del relleno."""
	var salida := datos.duplicate()
	var i := 0
	while i < salida.size():
		var v0 := _leer_u32(salida, i)
		var v1 := _leer_u32(salida, i + 4)
		var suma := 0
		for _vuelta in range(32):
			v0 = (v0 + (((((v1 << 4) ^ (v1 >> 5)) & M32) + v1) ^ (suma + llave[suma & 3]))) & M32
			suma = (suma + DELTA) & M32
			v1 = (v1 + (((((v0 << 4) ^ (v0 >> 5)) & M32) + v0) ^ (suma + llave[(suma >> 11) & 3]))) & M32
		_escribir_u32(salida, i, v0)
		_escribir_u32(salida, i + 4, v1)
		i += 8
	return salida


static func descifrar(datos: PackedByteArray, llave: PackedInt64Array) -> PackedByteArray:
	var salida := datos.duplicate()
	var i := 0
	while i < salida.size():
		var v0 := _leer_u32(salida, i)
		var v1 := _leer_u32(salida, i + 4)
		var suma := (DELTA * 32) & M32
		for _vuelta in range(32):
			v1 = (v1 - (((((v0 << 4) ^ (v0 >> 5)) & M32) + v0) ^ (suma + llave[(suma >> 11) & 3]))) & M32
			suma = (suma - DELTA) & M32
			v0 = (v0 - (((((v1 << 4) ^ (v1 >> 5)) & M32) + v1) ^ (suma + llave[suma & 3]))) & M32
		_escribir_u32(salida, i, v0)
		_escribir_u32(salida, i + 4, v1)
		i += 8
	return salida


static func llave_al_azar() -> PackedInt64Array:
	var k := PackedInt64Array()
	k.resize(4)
	for i in range(4):
		k[i] = randi() & M32
	return k


static func _leer_u32(b: PackedByteArray, i: int) -> int:
	return b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24)


static func _escribir_u32(b: PackedByteArray, i: int, v: int) -> void:
	b[i] = v & 0xFF
	b[i + 1] = (v >> 8) & 0xFF
	b[i + 2] = (v >> 16) & 0xFF
	b[i + 3] = (v >> 24) & 0xFF
