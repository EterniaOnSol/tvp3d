extends Node3D

## Cliente 3D propio de TVP3D.
## La escena usa geometria simple para la primera version; el editor y la
## importacion de sprites reemplazaran estos materiales por assets reales.

const PROTOCOLO := preload("res://comun/protocolo_tvp3d.gd")

const HOST := "127.0.0.1"
const PUERTO := 7277
const VELOCIDAD_PASO := 0.18

const SUELO := 0
const PARED := 1
const AGUA := 2
const ARBOL := 3
const ROCA := 4

var _peer := StreamPeerTCP.new()
var _buffer := PackedByteArray()
var _conectado := false
var _listo := false
var _reloj := 0.0
var _reloj_paso := VELOCIDAD_PASO
var _mi_id := 0
var _mi_pos := Vector3i.ZERO
var _origen := Vector3i.ZERO
var _mapa: Dictionary = {}
var _jugadores: Dictionary = {}

var _mapa_nodo: Node3D
var _jugadores_nodo: Node3D
var _camara: Camera3D
var _cartel: Label
var _materiales: Dictionary = {}


func _ready() -> void:
	_armar_escena()
	_actualizar_cartel("Conectando al servidor Godot propio...")
	var resultado := _peer.connect_to_host(HOST, PUERTO)
	if resultado != OK:
		_actualizar_cartel("No se pudo abrir 127.0.0.1:%d" % PUERTO)
		return


func _armar_escena() -> void:
	_mapa_nodo = Node3D.new()
	_mapa_nodo.name = "Mapa3D"
	add_child(_mapa_nodo)
	_jugadores_nodo = Node3D.new()
	_jugadores_nodo.name = "Jugadores"
	add_child(_jugadores_nodo)

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55, -35, 0)
	luz.light_energy = 1.2
	add_child(luz)
	var ambiente := WorldEnvironment.new()
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color("#17202b")
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color("#a8b7c7")
	entorno.ambient_light_energy = 0.8
	ambiente.environment = entorno
	add_child(ambiente)

	_camara = Camera3D.new()
	_camara.current = true
	_camara.fov = 55.0
	add_child(_camara)

	var capa := CanvasLayer.new()
	add_child(capa)
	_cartel = Label.new()
	_cartel.position = Vector2(18, 16)
	_cartel.add_theme_font_size_override("font_size", 18)
	_cartel.add_theme_color_override("font_color", Color("#f5f1df"))
	_cartel.add_theme_color_override("font_outline_color", Color("#111820"))
	_cartel.add_theme_constant_override("outline_size", 6)
	capa.add_child(_cartel)


func _process(delta: float) -> void:
	_reloj += delta
	_reloj_paso += delta
	_peer.poll()
	if _peer.get_status() == StreamPeerTCP.STATUS_ERROR \
			or _peer.get_status() == StreamPeerTCP.STATUS_NONE:
		if _conectado:
			_conectado = false
			_listo = false
			_actualizar_cartel("Conexion cerrada. Arranca el servidor propio.")
		return

	if not _conectado and _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_conectado = true
		_enviar(PROTOCOLO.Tipo.HELLO, {"nombre": "Aventurero"})
		_actualizar_cartel("Entrando al mundo...")

	_leer_red()
	if _listo:
		_leer_movimiento()
		_mover_camara(delta)


func _leer_red() -> void:
	var disponibles := _peer.get_available_bytes()
	if disponibles <= 0:
		return
	var recibido: Array = _peer.get_data(disponibles)
	if recibido[0] != OK:
		_actualizar_cartel("Error leyendo del servidor")
		return
	_buffer.append_array(recibido[1])

	var resultado: Dictionary = PROTOCOLO.extraer(_buffer)
	_buffer = resultado["buffer"]
	if resultado["error"] != "":
		_actualizar_cartel("Protocolo invalido: %s" % resultado["error"])
		return
	for mensaje in resultado["mensajes"]:
		_recibir(mensaje)


func _recibir(mensaje: Dictionary) -> void:
	match int(mensaje["tipo"]):
		PROTOCOLO.Tipo.WELCOME:
			var datos: Dictionary = mensaje["datos"]
			_mi_id = int(datos["id"])
			_mi_pos = PROTOCOLO.diccionario_a_posicion(datos["pos"])
			_mapa = datos.get("mapa", {})
			var origen_datos: Dictionary = _mapa.get("origen", {})
			_origen = Vector3i(
				int(origen_datos.get("x", 0)),
				int(origen_datos.get("y", 0)),
				int(origen_datos.get("z", 7)))
			_listo = true
			_renderizar_mapa()
			_actualizar_cartel("Mundo propio conectado. WASD/flechas para caminar.")
		PROTOCOLO.Tipo.STATE:
			var jugadores: Array = mensaje["datos"].get("jugadores", [])
			_jugadores.clear()
			for jugador in jugadores:
				var id := int(jugador["id"])
				var copia: Dictionary = jugador.duplicate(true)
				copia["pos"] = PROTOCOLO.diccionario_a_posicion(jugador["pos"])
				_jugadores[id] = copia
				if id == _mi_id:
					_mi_pos = copia["pos"]
			_renderizar_jugadores()
			_actualizar_cartel("TVP3D propio  |  posicion (%d, %d, %d)  |  jugadores %d\nWASD o flechas: caminar   ESC: salir" % [
				_mi_pos.x, _mi_pos.y, _mi_pos.z, _jugadores.size()])
		PROTOCOLO.Tipo.ERROR:
			_actualizar_cartel("Servidor: %s" % mensaje["datos"].get("mensaje", "error"))
		PROTOCOLO.Tipo.PONG:
			pass


func _leer_movimiento() -> void:
	if _reloj_paso < VELOCIDAD_PASO:
		return
	var dx := 0
	var dy := 0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dy = -1
	elif Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dx = 1
	elif Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dy = 1
	elif Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dx = -1
	if dx == 0 and dy == 0:
		return
	_enviar(PROTOCOLO.Tipo.MOVE, {"dx": dx, "dy": dy})
	_reloj_paso = 0.0


func _renderizar_mapa() -> void:
	for hijo in _mapa_nodo.get_children():
		hijo.queue_free()
	_materiales.clear()
	for celda in _mapa.get("celdas", []):
		var tipo := int(celda.get("tipo", SUELO))
		var x := int(celda.get("x", 0))
		var y := int(celda.get("y", 0))
		var columna := Node3D.new()
		columna.position = Vector3(x, 0, y)
		_mapa_nodo.add_child(columna)
		_agregar_cubo(columna, Vector3(1.0, 0.12, 1.0), Vector3(0, -0.06, 0), _color_de(SUELO))
		match tipo:
			PARED:
				_agregar_cubo(columna, Vector3(0.95, 1.5, 0.95), Vector3(0, 0.75, 0), _color_de(PARED))
			AGUA:
				_agregar_cubo(columna, Vector3(0.95, 0.08, 0.95), Vector3(0, 0.04, 0), _color_de(AGUA))
			ARBOL:
				_agregar_cubo(columna, Vector3(0.22, 0.9, 0.22), Vector3(0, 0.45, 0), Color("#704832"))
				_agregar_esfera(columna, Vector3(0, 1.05, 0), 0.52, _color_de(ARBOL))
			ROCA:
				_agregar_esfera(columna, Vector3(0, 0.32, 0), 0.38, _color_de(ROCA))


func _renderizar_jugadores() -> void:
	for hijo in _jugadores_nodo.get_children():
		hijo.queue_free()
	for id in _jugadores:
		var jugador: Dictionary = _jugadores[id]
		var posicion: Vector3i = jugador["pos"]
		var nodo := Node3D.new()
		nodo.position = _a_posicion_3d(posicion) + Vector3(0, 0.65, 0)
		_jugadores_nodo.add_child(nodo)
		var color := Color("#e6c85c") if int(id) == _mi_id else Color("#d86e63")
		_agregar_capsula(nodo, color)
		var nombre := Label3D.new()
		nombre.text = str(jugador.get("nombre", "Jugador"))
		nombre.position = Vector3(0, 1.05, 0)
		nombre.font_size = 32
		nombre.modulate = Color("#fff4c2")
		nombre.outline_size = 8
		nodo.add_child(nombre)


func _mover_camara(delta: float) -> void:
	var centro := _a_posicion_3d(_mi_pos) + Vector3(0, 0.45, 0)
	var destino := centro + Vector3(9.5, 10.5, 9.5)
	_camara.position = _camara.position.lerp(destino, clampf(delta * 6.0, 0.0, 1.0))
	_camara.look_at(centro, Vector3.UP)


func _a_posicion_3d(posicion: Vector3i) -> Vector3:
	return Vector3(posicion.x - _origen.x, 0, posicion.y - _origen.y)


func _agregar_cubo(padre: Node3D, tamano: Vector3, posicion: Vector3, color: Color) -> void:
	var malla := BoxMesh.new()
	malla.size = tamano
	var nodo := MeshInstance3D.new()
	nodo.mesh = malla
	nodo.position = posicion
	nodo.material_override = _material(color)
	padre.add_child(nodo)


func _agregar_esfera(padre: Node3D, posicion: Vector3, radio: float, color: Color) -> void:
	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2.0
	var nodo := MeshInstance3D.new()
	nodo.mesh = malla
	nodo.position = posicion
	nodo.material_override = _material(color)
	padre.add_child(nodo)


func _agregar_capsula(padre: Node3D, color: Color) -> void:
	var malla := CapsuleMesh.new()
	malla.radius = 0.28
	malla.height = 1.1
	var nodo := MeshInstance3D.new()
	nodo.mesh = malla
	nodo.material_override = _material(color)
	padre.add_child(nodo)


func _color_de(tipo: int) -> Color:
	match tipo:
		SUELO:
			return Color("#667052")
		PARED:
			return Color("#57504a")
		AGUA:
			return Color("#337b91")
		ARBOL:
			return Color("#3d7a4b")
		ROCA:
			return Color("#9a8d7b")
	return Color.WHITE


func _material(color: Color) -> StandardMaterial3D:
	var clave := color.to_html()
	if _materiales.has(clave):
		return _materiales[clave]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	_materiales[clave] = material
	return material


func _enviar(tipo: int, datos: Dictionary) -> void:
	if _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_peer.put_data(PROTOCOLO.empaquetar(tipo, datos))


func _actualizar_cartel(texto: String) -> void:
	if _cartel != null:
		_cartel.text = texto


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and evento.keycode == KEY_ESCAPE:
		_enviar(PROTOCOLO.Tipo.GOODBYE, {})
		get_tree().quit()
