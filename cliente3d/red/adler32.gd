extends RefCounted

# =====================================================================
#  Adler32 — la "firma" que lleva cada paquete.
#
#  PyOT calcula esta cuenta sobre los bytes del paquete y compara
#  (protocolbase.py:63-69). Si no coincide, corta la conexión sin decir
#  nada. Godot no lo trae, son diez líneas.
#
#  El 15.25 de 3DTIBIA NO usa esto: usa un contador de secuencia. Por eso
#  este archivo es nuevo y no copiado.
# =====================================================================

const BASE := 65521


static func calcular(datos: PackedByteArray) -> int:
	var a := 1
	var b := 0
	for byte in datos:
		a = (a + byte) % BASE
		b = (b + a) % BASE
	return ((b << 16) | a) & 0xFFFFFFFF
