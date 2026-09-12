extends Node

## Paridad de una ventana estatica del IR contra el mapa vivo 7.72.
##
## La prueba usa la misma conexion y EstadoMundo que el cliente. Compara
## un radio pequeno en el piso actual despues del 0x64 inicial:
##   IR item -> (client_id, count)
##   mapa vivo -> (cid, cantidad)
## Las criaturas se excluyen porque son estado dinamico del servidor.

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

var HOST := CREDENCIALES.HOST_DEFECTO
var PUERTO_LOGIN := CREDENCIALES.PUERTO_LOGIN_DEFECTO
var CUENTA := 0
var CLAVE := ""
const RADIO := 4
const IR_PATH := "res://generated/maps/rookgaard_100sqm.json"
const REPORT_PATH := "res://generated/reports/live_parity_window.json"

var _con
var _estado
var _ir_tiles := {}
var _reloj := 0.0
var _comparando := false
var _terminado := false


func _ready() -> void:
	# Credenciales e identidades de prueba: SOLO por entorno, nunca literales.
	# Si falta alguna, corta aca y no intenta ninguna conexion.
	if not CREDENCIALES.exigir(self, ["TVP772_ACCOUNT", "TVP772_PASSWORD"]):
		return
	HOST = CREDENCIALES.host()
	PUERTO_LOGIN = CREDENCIALES.puerto_login()
	CUENTA = CREDENCIALES.entero("TVP772_ACCOUNT")
	CLAVE = CREDENCIALES.texto("TVP772_PASSWORD")
	if not _cargar_ir():
		_fallo("no se pudo cargar " + IR_PATH)
		return

	_estado = ESTADO.new()
	_con = CONEXION.new()
	add_child(_con)
	_con.lista_personajes.connect(_al_recibir_personajes)
	_con.paquete_juego.connect(_al_recibir_paquete)
	_con.error_red.connect(_fallo)
	_con.cerrada.connect(func():
		if not _terminado:
			_fallo("conexion cerrada"))
	print("[paridad] cargadas %d tiles del IR" % _ir_tiles.size())
	print("[paridad] pidiendo login")
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _process(delta: float) -> void:
	_reloj += delta
	if not _terminado and _reloj > 30.0:
		_fallo("timeout esperando el mapa vivo")


func _cargar_ir() -> bool:
	var archivo := FileAccess.open(IR_PATH, FileAccess.READ)
	if archivo == null:
		return false
	var datos = JSON.parse_string(archivo.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY:
		return false
	for tile in datos.get("tiles", []):
		var posicion: Dictionary = tile.get("position", {})
		if not posicion.has_all(["x", "y", "z"]):
			continue
		var donde := Vector3i(int(posicion["x"]), int(posicion["y"]), int(posicion["z"]))
		_ir_tiles[donde] = tile
	return not _ir_tiles.is_empty()


func _al_recibir_personajes(_motd: String, personajes: Array) -> void:
	if personajes.is_empty():
		_fallo("cuenta sin personajes")
		return
	var personaje: Dictionary = personajes[0]
	_con.cerrar()
	_con.queue_free()
	_con = CONEXION.new()
	add_child(_con)
	_con.paquete_juego.connect(_al_recibir_paquete)
	_con.error_red.connect(_fallo)
	_con.cerrada.connect(func():
		if not _terminado:
			_fallo("conexion de juego cerrada"))
	var ip: String = personaje.get("ip", HOST)
	if ip == "0.0.0.0" or ip == "":
		ip = HOST
	_con.entrar_al_mundo(ip, int(personaje["puerto"]), CUENTA,
		personaje["nombre"], CLAVE)


func _al_recibir_paquete(msg) -> void:
	_estado.procesar(msg)
	if _comparando or not _estado.adentro or _estado.casillas.is_empty():
		return
	_comparando = true
	# Dejamos que se procese cualquier paquete inicial pegado al 0x64.
	_comparar_deferred.call_deferred()


func _comparar_deferred() -> void:
	await get_tree().create_timer(0.5).timeout
	if _terminado:
		return
	var reporte := _comparar_ventana()
	_guardar_reporte(reporte)
	_terminado = true
	var resumen: Dictionary = reporte["summary"]
	print("[paridad] centro=%s radio=%d piso=%d" % [
		reporte["window"]["center"], RADIO, _estado.mi_pos.z])
	print("[paridad] tiles=%d matches=%d mismatches=%d criaturas_ignoradas=%d" % [
		resumen["tiles_compared"], resumen["matches"],
		resumen["mismatches"], resumen["creatures_ignored"]])
	if resumen["mismatches"] == 0:
		print("[paridad] OK: IR y estado vivo coinciden")
		get_tree().quit(0)
	else:
		print("[paridad] FAIL: revisar " + REPORT_PATH)
		get_tree().quit(1)


func _comparar_ventana() -> Dictionary:
	var centro: Vector3i = _estado.mi_pos
	var mismatches := []
	var posiciones := {}
	var criaturas_ignoradas := 0
	for dx in range(-RADIO, RADIO + 1):
		for dy in range(-RADIO, RADIO + 1):
			posiciones[Vector3i(centro.x + dx, centro.y + dy, centro.z)] = true

	for donde in posiciones:
		var ir_tile = _ir_tiles.get(donde)
		var vivo: Array = _estado.casillas.get(donde, [])
		var vivo_items := []
		for cosa in vivo:
			if cosa.get("tipo") == "criatura":
				criaturas_ignoradas += 1
				continue
			vivo_items.append([
				int(cosa.get("cid", 0)),
				int(cosa.get("cantidad", 1)),
			])

		var ir_items := []
		if ir_tile != null:
			for item in ir_tile.get("items", []):
				if item.get("client_id") == null:
					ir_items.append([-1, int(item.get("count", 1))])
				else:
					ir_items.append([
						int(item.get("client_id")),
						int(item.get("count", 1)),
					])

		if ir_items == vivo_items:
			continue
		mismatches.append({
			"position": _posicion_json(donde),
			"ir_items": ir_items,
			"live_items": vivo_items,
			"live_creatures": _criaturas_en(vivo),
			"kind": "missing_ir" if ir_tile == null else (
				"missing_live" if vivo.is_empty() else "items_differ"),
		})

	return {
		"version": 1,
		"window": {
			"center": _posicion_json(centro),
			"radius": RADIO,
			"z": centro.z,
		},
		"source": {
			"ir": IR_PATH,
			"live_protocol": "TVP 7.72 map description 0x64",
			"state_parser": "red/estado_mundo.gd",
		},
		"summary": {
			"tiles_compared": (2 * RADIO + 1) * (2 * RADIO + 1),
			"matches": (2 * RADIO + 1) * (2 * RADIO + 1) - mismatches.size(),
			"mismatches": mismatches.size(),
			"creatures_ignored": criaturas_ignoradas,
		},
		"mismatches": mismatches,
	}


func _criaturas_en(cosas: Array) -> int:
	var cantidad := 0
	for cosa in cosas:
		if cosa.get("tipo") == "criatura":
			cantidad += 1
	return cantidad


func _posicion_json(posicion: Vector3i) -> Dictionary:
	return {"x": posicion.x, "y": posicion.y, "z": posicion.z}


func _guardar_reporte(reporte: Dictionary) -> void:
	var archivo := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo escribir " + REPORT_PATH)
		return
	archivo.store_string(JSON.stringify(reporte, "\t"))


func _fallo(motivo: String) -> void:
	if _terminado:
		return
	_terminado = true
	print("[paridad] FAIL: " + motivo)
	get_tree().quit(1)
