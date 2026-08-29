extends SceneTree

# Recorre una captura real del mensaje de entrada y traza el mapa casilla por
# casilla, sin servidor. Sirve para encontrar el punto exacto donde el lector
# deja de coincidir con lo que describio el servidor.
#
# La pista que se usa como oracle es una regla del propio Tibia: en una casilla
# descrita por el servidor, lo primero siempre es su suelo. Si aparece una
# casilla cuya primera cosa no es suelo, la lectura ya venia corrida.
#
#   ...Godot --headless --path cliente3d --script res://red/analizar_captura.gd

const MAPA := preload("res://red/mapa772.gd")
const MENSAJE := preload("res://red/mensaje.gd")

const RUTA := "res://generated/capturas/entrada_mundo.bin"
const ANCHO := 18
const ALTO := 14


func _initialize() -> void:
	var f := FileAccess.open(RUTA, FileAccess.READ)
	if f == null:
		printerr("falta la captura %s" % RUTA)
		quit(1)
		return
	var bytes := f.get_buffer(f.get_length())
	f.close()
	print("captura de %d bytes" % bytes.size())

	var msg = MENSAJE.new(bytes)
	var mapa = MAPA.new()
	# Encabezado del mensaje de entrada hasta el 0x64.
	var opcode: int = msg.leer_u8()
	print("primer opcode: 0x%02X" % opcode)
	if opcode == 0x0A:
		msg.leer_u32()          # id del jugador
		msg.leer_u16()          # beat
		msg.leer_u8()           # can report bugs
		opcode = msg.leer_u8()
	if opcode != 0x64:
		printerr("la captura no empieza con un mapa: 0x%02X" % opcode)
		quit(1)
		return
	var mi_pos: Vector3i = msg.leer_posicion()
	print("mi_pos del servidor: %s" % str(mi_pos))

	var cursor_mapa: int = msg.cursor
	# Ninguna variante de la regla de saltos alinea la captura, asi que el
	# ancho de algun item es el que no cuadra. Se busca cual: se reparsea
	# consumiendo un byte extra despues del item numero N y se mira si con eso
	# el jugador aparece en su casilla y el mensaje cierra justo.
	var sin_extra := _probar_con_extra(bytes, cursor_mapa, mi_pos, -1)
	print("sin byte extra -> alineado=%s, sobran=%d, items=%d" % [
		str(sin_extra["alineado"]), int(sin_extra["sobran"]),
		int(sin_extra["items"])])
	for delta in [1, -1]:
		var culpables: Array = []
		for objetivo in range(int(sin_extra["items"])):
			var salida := _probar_con_extra(bytes, cursor_mapa, mi_pos,
				objetivo, delta)
			if bool(salida["alineado"]) and int(salida["sobran"]) == 0:
				culpables.append({"indice": objetivo, "cid": salida["cid"],
					"nombre": salida["nombre"], "donde": salida["donde"]})
		print("items que alinean la captura con %+d byte: %d" % [
			delta, culpables.size()])
		for c in culpables.slice(0, 8):
			print("   item #%d cid %d '%s' en %s" % [int(c["indice"]),
				int(c["cid"]), str(c["nombre"]), str(c["donde"])])

	msg.cursor = cursor_mapa
	_trazar(msg, mapa, mi_pos)
	quit(0)


func _probar_con_extra(bytes: PackedByteArray, cursor_mapa: int,
		mi_pos: Vector3i, objetivo: int, delta: int = 1) -> Dictionary:
	## Reparsea la captura consumiendo un byte extra despues del item numero
	## `objetivo`. Con `objetivo < 0` no consume ninguno.
	var msg = MENSAJE.new(bytes)
	msg.cursor = cursor_mapa
	var mapa = MAPA.new()
	var x0: int = mi_pos.x - 8
	var y0: int = mi_pos.y - 6
	var z0: int = mi_pos.z
	var salto := 0
	var menos_uno := true
	var alineado := false
	var items := 0
	var cid_objetivo := 0
	var nombre_objetivo := ""
	var donde_objetivo := Vector3i.ZERO
	for piso in range(7, -1, -1):
		var desfase: int = z0 - piso
		for x in range(x0 + desfase, x0 + ANCHO + desfase):
			for y in range(y0 + desfase, y0 + ALTO + desfase):
				if salto > 0:
					salto -= 1
					continue
				if msg.sin_leer() < 2:
					return {"alineado": alineado, "sobran": -1, "items": items,
						"cid": cid_objetivo, "nombre": nombre_objetivo,
						"donde": donde_objetivo}
				if msg.espiar_u16() >= 0xFF00:
					var marca: int = msg.leer_u16()
					var vacios: int
					if marca == 0xFFFF:
						vacios = 255 + (1 if menos_uno else 0)
						menos_uno = true
					else:
						vacios = (marca & 0xFF) + (1 if menos_uno else 0)
						menos_uno = false
					if vacios > 0:
						salto = vacios - 1
						continue
				menos_uno = false
				var criaturas: Array = []
				var donde := Vector3i(x, y, piso)
				for _i in range(10):
					if msg.sin_leer() < 2 or msg.espiar_u16() >= 0xFF00:
						break
					var cosa: Dictionary = mapa.leer_cosa(msg, donde, criaturas)
					if donde == mi_pos and cosa.get("tipo") == "criatura":
						alineado = true
					if cosa.get("tipo") != "item":
						continue
					if items == objetivo:
						cid_objetivo = int(cosa.get("cid", 0))
						nombre_objetivo = str(cosa.get("nombre", "?"))
						donde_objetivo = donde
						msg.cursor = maxi(0, msg.cursor + delta)
					items += 1
	return {"alineado": alineado, "sobran": msg.sin_leer(), "items": items,
		"cid": cid_objetivo, "nombre": nombre_objetivo, "donde": donde_objetivo}


func _trazar(msg, mapa, mi_pos: Vector3i) -> void:
	var x0: int = mi_pos.x - 8
	var y0: int = mi_pos.y - 6
	var z0: int = mi_pos.z

	var pisos: Array = []
	if z0 > 7:
		var z := z0 - 2
		while z <= mini(15, z0 + 2):
			pisos.append(z)
			z += 1
	else:
		var z := 7
		while z >= 0:
			pisos.append(z)
			z -= 1

	var salto := 0
	var menos_uno := true
	var sospechosas := 0
	var ultimo_item := ""
	for z in pisos:
		var desfase: int = z0 - z
		for x in range(x0 + desfase, x0 + ANCHO + desfase):
			for y in range(y0 + desfase, y0 + ALTO + desfase):
				if salto > 0:
					salto -= 1
					continue
				if msg.sin_leer() < 2:
					print("se acabaron los bytes en %s" % str(Vector3i(x, y, z)))
					return
				if msg.espiar_u16() >= 0xFF00:
					var marca: int = msg.leer_u16()
					var vacios: int
					if marca == 0xFFFF:
						vacios = 255 + (1 if menos_uno else 0)
						menos_uno = true
					else:
						vacios = (marca & 0xFF) + (1 if menos_uno else 0)
						menos_uno = false
					if vacios > 0:
						salto = vacios - 1
						continue
				menos_uno = false
				var criaturas: Array = []
				var donde := Vector3i(x, y, z)
				var cosas: Array = []
				for _i in range(10):
					if msg.sin_leer() < 2:
						break
					if msg.espiar_u16() >= 0xFF00:
						break
					var cosa: Dictionary = mapa.leer_cosa(msg, donde, criaturas)
					cosas.append(cosa)
				if cosas.is_empty():
					continue
				var primera: Dictionary = cosas[0]
				var es_suelo: bool = primera.get("tipo") == "item" \
					and bool(primera.get("suelo", false))
				if not es_suelo and sospechosas < 6:
					sospechosas += 1
					print("SOSPECHA en %s: la casilla empieza con %s" % [
						str(donde), _describir(primera)])
					print("   casilla completa: %s" % _describir_todas(cosas))
					print("   ultimo item de la casilla anterior: %s" % ultimo_item)
				if donde == mi_pos:
					var tiene_criatura := false
					for cosa in cosas:
						if cosa.get("tipo") == "criatura":
							tiene_criatura = true
					print("casilla propia %s -> %s (criatura: %s)" % [
						str(donde), _describir_todas(cosas), str(tiene_criatura)])
				ultimo_item = _describir(cosas[cosas.size() - 1])
	print("sobran %d bytes despues del mapa" % msg.sin_leer())
	if msg.sin_leer() > 0:
		var siguiente: int = msg.espiar_u8()
		print("el byte siguiente seria el opcode 0x%02X" % siguiente)


func _describir(cosa: Dictionary) -> String:
	if cosa.get("tipo") == "criatura":
		return "criatura(%d)" % int(cosa.get("id", 0))
	var extra := ""
	if bool(cosa.get("apilable", false)):
		extra = "[apilable x%d]" % int(cosa.get("cantidad", 1))
	elif bool(cosa.get("liquido", false)):
		extra = "[liquido %d]" % int(cosa.get("color_liquido", 0))
	return "%s(cid %d)%s%s" % [str(cosa.get("nombre", "?")),
		int(cosa.get("cid", 0)), "[suelo]" if bool(cosa.get("suelo", false)) else "",
		extra]


func _describir_todas(cosas: Array) -> String:
	var partes: Array = []
	for cosa in cosas:
		partes.append(_describir(cosa))
	return " | ".join(partes)
