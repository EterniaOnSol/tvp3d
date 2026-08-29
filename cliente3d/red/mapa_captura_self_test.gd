extends SceneTree

# Regresion con bytes reales: el `0x64` que el servidor mando el 2026-08-29 en
# `(32082,32145,6)` y que el lector interpretaba corrido.
#
# La captura esta versionada en `generated/capturas/entrada_mundo.bin` y se
# saca con `red/diagnostico_pila_viva.gd`. Lo que se comprueba no es una
# corazonada, son tres hechos del propio mensaje:
#
#   1. El servidor siempre describe al jugador dentro de su casilla.
#   2. Ningun item llega con un client id que el catalogo no conozca; los ids
#      imposibles solo aparecen cuando la lectura ya venia corrida.
#   3. Detras del mapa siguen opcodes de verdad —en esta captura un `0xA2` de
#      iconos y un `0x6B` que gira al propio jugador—, asi que `EstadoMundo`
#      consume el mensaje entero sin sobras.
#
# El fallo original: una casilla que existe pero no tiene nada que describir
# ocupa cero bytes, asi que el servidor deja dos marcas de salto pegadas. El
# lector se salteaba ese casillero y perdia un lugar por cada uno.

const MAPA := preload("res://red/mapa772.gd")
const MENSAJE := preload("res://red/mensaje.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const RUTA := "res://generated/capturas/entrada_mundo.bin"
const ANCHO := 18
const ALTO := 14

var _fallas := 0


func _initialize() -> void:
	var f := FileAccess.open(RUTA, FileAccess.READ)
	if f == null:
		printerr("FALLA: falta la captura %s" % RUTA)
		quit(1)
		return
	var bytes := f.get_buffer(f.get_length())
	f.close()

	var msg = MENSAJE.new(bytes)
	var opcode: int = msg.leer_u8()
	if opcode != 0x64:
		printerr("FALLA: la captura no empieza con un mapa: 0x%02X" % opcode)
		quit(1)
		return
	var mi_pos: Vector3i = msg.leer_posicion()
	print("Captura real del mapa en %s (%d bytes)" % [str(mi_pos), bytes.size()])

	var mapa = MAPA.new()
	var salida: Dictionary = mapa.leer_descripcion(
		msg, mi_pos.x - 8, mi_pos.y - 6, mi_pos.z, ANCHO, ALTO)
	var casillas: Dictionary = salida["casillas"]

	var hay_criatura := false
	for cosa in casillas.get(mi_pos, []):
		if cosa.get("tipo") == "criatura":
			hay_criatura = true
			break
	_comprobar("el jugador aparece descrito en su propia casilla", hay_criatura,
		"la casilla %s trajo %d cosas" % [str(mi_pos),
			(casillas.get(mi_pos, []) as Array).size()])
	_comprobar("ningun item llega con un client id fuera del catalogo",
		mapa.items_sin_datos() == 0,
		"%d items, ids %s" % [mapa.items_sin_datos(),
			str(mapa.cids_sin_datos())])
	print("casillas leidas: %d" % casillas.size())

	# El mismo mensaje, ahora por el camino real del cliente: si el mapa se
	# leyera corrido, los opcodes de atras se interpretarian como basura.
	var estado = ESTADO.new()
	var completo = MENSAJE.new(bytes)
	estado.procesar(completo)
	_comprobar("EstadoMundo consume el mensaje entero, mapa y opcodes de atras",
		completo.sin_leer() == 0, "sobran %d bytes" % completo.sin_leer())
	_comprobar("el estado deja al jugador con su casilla poblada",
		(estado.casillas.get(estado.mi_pos, []) as Array).size() > 0)

	if _fallas > 0:
		printerr("Captura real del mapa: %d falla(s)" % _fallas)
		quit(1)
		return
	print("Captura real del mapa: OK")
	quit(0)


func _comprobar(nombre: String, correcto: bool, detalle: String = "") -> void:
	if correcto:
		print("  OK   %s" % nombre)
	else:
		_fallas += 1
		printerr("  FALLA %s%s" % [nombre, "" if detalle.is_empty() else ": " + detalle])
