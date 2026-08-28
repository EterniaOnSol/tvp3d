extends SceneTree

const ESTADO := preload("res://red/estado_mundo.gd")
const MENSAJE := preload("res://red/mensaje.gd")


func _init() -> void:
	var estado = ESTADO.new()
	var recibida := {}
	estado.voz_recibida.connect(func(orador_id: int, trama: PackedByteArray):
		recibida["id"] = orador_id
		recibida["trama"] = trama
	)

	var trama := PackedByteArray([1, 1, 0x2A, 0x00])
	for _i in range(160):
		trama.append(0)
	var mensaje = MENSAJE.new()
	mensaje.escribir_u8(0x32)
	mensaje.escribir_u8(0xF1)
	var payload := PackedByteArray([0x78, 0x56, 0x34, 0x12])
	payload.append_array(trama)
	mensaje.escribir_u16(payload.size())
	mensaje.escribir_bytes(payload)
	estado.procesar(mensaje)

	var ok: bool = recibida.get("id", 0) == 0x12345678 \
		and recibida.get("trama", PackedByteArray()).size() == 164 \
		and recibida["trama"][4] == 0 \
		and estado.opcodes_desconocidos().is_empty()
	print("[voz] protocolo: %s" % ("OK" if ok else "FALLO"))
	quit(0 if ok else 1)
