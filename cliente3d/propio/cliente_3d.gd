extends Node3D

## Cliente 3D propio de TVP3D.
## La escena usa geometria simple para la primera version; el editor y la
## importacion de sprites reemplazaran estos materiales por assets reales.

const PROTOCOLO := preload("res://comun/protocolo_tvp3d.gd")
const MAPA := preload("res://comun/mapa_tvp3d.gd")

const HOST := "127.0.0.1"
const PUERTO := 7277
const VELOCIDAD_PASO := 0.18
const REINTENTO_CONEXION := 1.0
const HOST_ENV := "TVP3D_HOST"
const PUERTO_ENV := "TVP3D_PUERTO"
const NOMBRE_ENV := "TVP3D_NOMBRE"
const SUPERFICIE_Z := 7

const SUELO := 0
const PARED := 1
const AGUA := 2
const ARBOL := 3
const ROCA := 4
const DECORACION := 5
const ESCALERA := 6

var _peer := StreamPeerTCP.new()
var _buffer := PackedByteArray()
var _conectado := false
var _listo := false
var _hello_enviado := false
var _estado_conexion := "DESCONECTADO"
var _reloj := 0.0
var _reloj_paso := VELOCIDAD_PASO
var _reloj_reconexion := REINTENTO_CONEXION
var _mi_id := 0
var _mi_pos := Vector3i.ZERO
var _origen := Vector3i.ZERO
var _mapa: Dictionary = {}
var _mapa_valido := false
var _jugadores: Dictionary = {}
var _host := HOST
var _puerto := PUERTO
var _nombre := "Aventurero"

var _mapa_nodo: Node3D
var _jugadores_nodo: Node3D
var _camara: Camera3D
var _cartel: Label
var _materiales: Dictionary = {}


func _ready() -> void:
	_cargar_configuracion()
	_armar_escena()
	_actualizar_cartel("Conectando al servidor Godot propio...")
	_conectar()


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
	if _estado_conexion == "DESCONECTADO":
		_reloj_reconexion += delta
		if _reloj_reconexion >= REINTENTO_CONEXION:
			_conectar()
		return
	_peer.poll()
	if _peer.get_status() == StreamPeerTCP.STATUS_ERROR \
			or _peer.get_status() == StreamPeerTCP.STATUS_NONE:
		_manejar_desconexion("CONEXION_PERDIDA")
		return

	if not _hello_enviado and _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_estado_conexion = "CONECTANDO"
		_conectado = true
		_hello_enviado = true
		_enviar(PROTOCOLO.Tipo.HELLO, {"nombre": _nombre})
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
		_manejar_desconexion("PROTOCOLO_INVALIDO: %s" % resultado["error"])
		return
	for mensaje in resultado["mensajes"]:
		_recibir(mensaje)


func _recibir(mensaje: Dictionary) -> void:
	match int(mensaje["tipo"]):
		PROTOCOLO.Tipo.WELCOME:
			var datos: Dictionary = mensaje["datos"]
			if not _validar_welcome(datos):
				_manejar_desconexion("MAPA_RECIBIDO_INVALIDO")
				return
			_mi_id = int(datos["id"])
			_mi_pos = PROTOCOLO.diccionario_a_posicion(datos["pos"])
			_mapa = datos.get("mapa", {})
			_mapa_valido = true
			var origen_datos: Dictionary = _mapa.get("origen", {})
			_origen = Vector3i(
				int(origen_datos.get("x", 0)),
				int(origen_datos.get("y", 0)),
				int(origen_datos.get("z", 7)))
			_listo = true
			_estado_conexion = "EN_MUNDO"
			_renderizar_mapa()
			_actualizar_cartel("Mundo propio conectado. WASD/flechas para caminar.")
		PROTOCOLO.Tipo.STATE:
			if not _listo:
				return
			var jugadores: Array = mensaje["datos"].get("jugadores", [])
			_jugadores.clear()
			var encontre_mi_entidad := false
			for jugador in jugadores:
				var id := int(jugador["id"])
				var copia: Dictionary = jugador.duplicate(true)
				copia["pos"] = PROTOCOLO.diccionario_a_posicion(jugador["pos"])
				_jugadores[id] = copia
				if id == _mi_id:
					_mi_pos = copia["pos"]
					encontre_mi_entidad = true
			if not encontre_mi_entidad:
				_manejar_desconexion("STATE_SIN_JUGADOR_LOCAL")
				return
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
			DECORACION:
				_agregar_cubo(columna, Vector3(0.48, 0.48, 0.48), Vector3(0, 0.24, 0), _color_de(DECORACION))
			ESCALERA:
				_agregar_cubo(columna, Vector3(0.9, 0.18, 0.28), Vector3(-0.25, 0.09, -0.28), _color_de(ESCALERA))
				_agregar_cubo(columna, Vector3(0.9, 0.36, 0.28), Vector3(0.0, 0.18, 0.0), _color_de(ESCALERA))
				_agregar_cubo(columna, Vector3(0.9, 0.54, 0.28), Vector3(0.25, 0.27, 0.28), _color_de(ESCALERA))


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
	return Vector3(
		posicion.x - _origen.x,
		float(SUPERFICIE_Z - posicion.z),
		posicion.y - _origen.y)


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
		DECORACION:
			return Color("#c28a55")
		ESCALERA:
			return Color("#a97845")
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


func _cargar_configuracion() -> void:
	var host_configurado := OS.get_environment(HOST_ENV).strip_edges()
	if not host_configurado.is_empty():
		_host = host_configurado
	var puerto_configurado := OS.get_environment(PUERTO_ENV).strip_edges()
	if not puerto_configurado.is_empty():
		var puerto_configurado_int := int(puerto_configurado)
		if puerto_configurado_int > 0 and puerto_configurado_int <= 65535:
			_puerto = puerto_configurado_int
	var nombre_configurado := OS.get_environment(NOMBRE_ENV).strip_edges()
	if not nombre_configurado.is_empty():
		_nombre = nombre_configurado.left(24)


func _conectar() -> void:
	if _estado_conexion == "CONECTANDO" or _estado_conexion == "EN_MUNDO":
		return
	_peer = StreamPeerTCP.new()
	_buffer = PackedByteArray()
	_hello_enviado = false
	_conectado = false
	_listo = false
	_estado_conexion = "CONECTANDO"
	_reloj_reconexion = 0.0
	var resultado := _peer.connect_to_host(_host, _puerto)
	if resultado != OK:
		_manejar_desconexion("CONEXION_RECHAZADA")


func _manejar_desconexion(motivo: String) -> void:
	_conectado = false
	_listo = false
	_hello_enviado = false
	_estado_conexion = "DESCONECTADO"
	_reloj_reconexion = 0.0
	_buffer = PackedByteArray()
	_mi_id = 0
	_mi_pos = Vector3i.ZERO
	_origen = Vector3i.ZERO
	_mapa.clear()
	_mapa_valido = false
	_jugadores.clear()
	_limpiar_vista()
	if _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED \
			or _peer.get_status() == StreamPeerTCP.STATUS_CONNECTING:
		_peer.disconnect_from_host()
	_actualizar_cartel("%s. Reintentando..." % motivo)


func _limpiar_vista() -> void:
	if _mapa_nodo != null:
		for hijo in _mapa_nodo.get_children():
			hijo.queue_free()
	if _jugadores_nodo != null:
		for hijo in _jugadores_nodo.get_children():
			hijo.queue_free()


func _validar_welcome(datos: Dictionary) -> bool:
	if int(datos.get("id", 0)) <= 0:
		return false
	var nombre: Variant = datos.get("nombre", null)
	if typeof(nombre) != TYPE_STRING or str(nombre).length() < 1 \
			or str(nombre).length() > 24:
		return false
	if not _posicion_valida(datos.get("pos", null)):
		return false
	var mapa_valor: Variant = datos.get("mapa", null)
	if typeof(mapa_valor) != TYPE_DICTIONARY:
		return false
	var mapa: Dictionary = mapa_valor
	if int(mapa.get("version", -1)) != PROTOCOLO.VERSION:
		return false
	var origen_valor: Variant = mapa.get("origen", null)
	if not _posicion_valida(origen_valor):
		return false
	var ancho := int(mapa.get("ancho", -1))
	var alto := int(mapa.get("alto", -1))
	if ancho < 3 or ancho > 128 or alto < 3 or alto > 128:
		return false
	var celdas_valor: Variant = mapa.get("celdas", null)
	if typeof(celdas_valor) != TYPE_ARRAY or celdas_valor.is_empty():
		return false
	var vistas: Dictionary = {}
	for celda_valor in celdas_valor:
		if typeof(celda_valor) != TYPE_DICTIONARY:
			return false
		var celda: Dictionary = celda_valor
		var x := int(celda.get("x", -1))
		var y := int(celda.get("y", -1))
		var tipo := int(celda.get("tipo", -1))
		if x < 0 or x >= ancho or y < 0 or y >= alto:
			return false
		if not MAPA.es_tipo_valido(tipo):
			return false
		var clave := "%d,%d" % [x, y]
		if vistas.has(clave):
			return false
		vistas[clave] = true
	return true


func _posicion_valida(valor: Variant) -> bool:
	if typeof(valor) != TYPE_DICTIONARY:
		return false
	var posicion: Dictionary = valor
	if typeof(posicion.get("x", null)) != TYPE_INT \
			or typeof(posicion.get("y", null)) != TYPE_INT \
			or typeof(posicion.get("z", null)) != TYPE_INT:
		return false
	return int(posicion["z"]) >= 0 and int(posicion["z"]) <= 15


func _enviar(tipo: int, datos: Dictionary) -> void:
	if _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var paquete := PROTOCOLO.empaquetar(tipo, datos)
		if paquete.is_empty():
			return
		if _peer.put_data(paquete) != OK:
			_manejar_desconexion("CONEXION_PERDIDA")


func _actualizar_cartel(texto: String) -> void:
	if _cartel != null:
		_cartel.text = texto


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and evento.keycode == KEY_ESCAPE:
		_estado_conexion = "CERRANDO"
		_enviar(PROTOCOLO.Tipo.GOODBYE, {})
		if _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			_peer.disconnect_from_host()
		get_tree().quit()
