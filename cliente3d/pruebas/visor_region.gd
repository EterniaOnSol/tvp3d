extends Node3D

## Visor de validacion del IR exportado desde el OTBM real.
##
## Este no sustituye al cliente conectado al TVP. Es una herramienta de
## comprobacion: consume cliente3d/generated/maps/*.json y deja visible la
## correspondencia SQM -> geometria, bloqueo, chunks y items sin mapping.

const COORD := preload("res://comun/coordenadas_tibia.gd")
const IR_TROZOS := preload("res://red/ir_trozos.gd")

const REGION_FILE := "res://generated/maps/rookgaard_100sqm.json"
const CHUNK_INDEX_FILE := "res://generated/maps/rookgaard_100sqm_chunks/index.json"
const SPAWN := Vector3i(32097, 32219, 7)
const CHUNK_SIZE := 32

var _ancla := SPAWN
var _tiles: Dictionary = {}
var _region := {}
var _ir_trozos
var _grupos: Dictionary = {}
var _mallas: Dictionary = {}
var _materiales: Dictionary = {}
var _nodos_region := Node3D.new()
var _nodo_debug := Node3D.new()
var _jugador := Node3D.new()
var _camara: Camera3D
var _hud: Label
var _seleccion: Vector3i = Vector3i(-1, -1, -1)
var _pos_jugador := SPAWN
var _arrastrando := false
var _giro := 0.65
var _inclinacion := 0.70
var _distancia := 13.0
var _camara_libre := false
var _mostrar_rejilla := true
var _mostrar_bloqueo := false
var _mostrar_chunks := false
var _franjas := 0


func _ready() -> void:
	print("Region validator: loading IR")
	if not _cargar_region():
		return
	print("Region validator: loaded %d tiles" % _tiles.size())
	add_child(_nodos_region)
	add_child(_nodo_debug)
	_armar_luz_y_camara()
	print("Region validator: building geometry")
	_construir_region()
	print("Region validator: geometry ready (%d groups)" % _grupos.size())
	_crear_jugador()
	_crear_hud()
	_actualizar_hud()
	if "--captura" in OS.get_cmdline_user_args():
		_capturar.call_deferred()


func _cargar_region() -> bool:
	_ir_trozos = IR_TROZOS.new()
	if _ir_trozos.abrir(CHUNK_INDEX_FILE):
		_region = _ir_trozos.region()
		var min_z := int(_region.get("min_z", SPAWN.z))
		var max_z := int(_region.get("max_z", SPAWN.z))
		_tiles = _ir_trozos.cargar_ventana(_ancla, 128, min_z, max_z)
		print("Region validator: streamed %d chunks" % _ir_trozos.chunks_cargados())
		return not _tiles.is_empty()

	print("Region validator: chunk index missing, using full IR fallback")
	var archivo := FileAccess.open(REGION_FILE, FileAccess.READ)
	if archivo == null:
		push_error("Falta el IR exportado: " + REGION_FILE)
		return false
	var datos = JSON.parse_string(archivo.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY or not datos.has("tiles"):
		push_error("El IR no tiene el formato esperado")
		return false
	_region = datos.get("region", {})
	for fila in datos["tiles"]:
		var p: Dictionary = fila["position"]
		var pos := Vector3i(int(p["x"]), int(p["y"]), int(p["z"]))
		_tiles[pos] = fila
	return true


func _armar_luz_y_camara() -> void:
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sol.light_energy = 1.1
	add_child(sol)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.065, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.58)
	env.ambient_light_energy = 0.8
	ambiente.environment = env
	add_child(ambiente)
	_camara = Camera3D.new()
	_camara.far = 180.0
	add_child(_camara)


func _construir_region() -> void:
	var cantidades := {"tiles": 0, "items": 0, "unmapped": 0, "blocked": 0}
	for pos in _tiles:
		var tile: Dictionary = _tiles[pos]
		cantidades["tiles"] += 1
		if not bool(tile.get("walkable", true)):
			cantidades["blocked"] += 1
		var items: Array = tile.get("items", [])
		cantidades["items"] += items.size()
		for item in items:
			var kind := _kind_of(item)
			if kind == "unmapped":
				cantidades["unmapped"] += 1
			_add_item(pos, item)
	print("Region validator: groups collected (%d)" % _grupos.size())
	_build_groups()
	print("Region validator: groups built")
	_crear_rejilla()
	_crear_cartel_escena(cantidades)


func _kind_of(item: Dictionary) -> String:
	if not bool(item.get("mapped", true)):
		return "unmapped"
	var category := str(item.get("category", "UNKNOWN")).to_upper()
	if category == "WATER":
		return "water"
	if category == "VEGETATION":
		return "vegetation"
	if category == "WALL" or category == "DOOR":
		return "wall"
	if category == "STAIRS":
		return "stairs"
	if category == "GROUND":
		return "ground"
	return "decoration"


func _add_item(pos: Vector3i, item: Dictionary) -> void:
	var kind := _kind_of(item)
	_add_to_group(kind, pos, item)


func _add_to_group(kind: String, pos: Vector3i, item: Dictionary) -> void:
	var key := "%s_%d_%d" % [kind, COORD.chunk_de(pos, CHUNK_SIZE).x,
		COORD.chunk_de(pos, CHUNK_SIZE).y]
	if not _grupos.has(key):
		_grupos[key] = {"kind": kind, "transforms": []}
	var world := COORD.tibia_a_mundo(pos, _ancla)
	var height := 0.08
	var y := world.y - 0.04
	if kind == "wall":
		height = 0.90
		y = world.y + height * 0.5
	elif kind == "vegetation":
		height = 1.15
		y = world.y + height * 0.5
	elif kind == "stairs":
		height = 0.45
		y = world.y + height * 0.5
	elif kind == "decoration":
		height = 0.35
		y = world.y + height * 0.5
	elif kind == "unmapped":
		height = 0.70
		y = world.y + height * 0.5
	_grupos[key]["transforms"].append({
		"position": Vector3(world.x, y, world.z),
		"height": height,
		"source": {"position": pos, "server_id": int(item.get("server_id", 0)),
			"client_id": item.get("client_id", null)},
	})


func _build_groups() -> void:
	for key in _grupos:
		var grupo: Dictionary = _grupos[key]
		var kind: String = grupo["kind"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh_for(kind)
		var transforms: Array = grupo["transforms"]
		mm.instance_count = transforms.size()
		for index in range(transforms.size()):
			var entry: Dictionary = transforms[index]
			var pos: Vector3 = entry["position"]
			var scale := Vector3(1.0, float(entry["height"]) / _mesh_height(kind), 1.0)
			mm.set_instance_transform(index, Transform3D(Basis().scaled(scale), pos))
		var instancia := MultiMeshInstance3D.new()
		instancia.multimesh = mm
		instancia.material_override = _material_for(kind)
		_nodos_region.add_child(instancia)


func _mesh_height(kind: String) -> float:
	if kind == "ground" or kind == "water":
		return 0.08
	return 1.0


func _mesh_for(kind: String) -> Mesh:
	if _mallas.has(kind):
		return _mallas[kind]
	var mesh: Mesh
	if kind == "vegetation":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.32
		cylinder.bottom_radius = 0.42
		cylinder.height = 1.0
		mesh = cylinder
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.92, _mesh_height(kind), 0.92)
		mesh = box
	_mallas[kind] = mesh
	return mesh


func _material_for(kind: String) -> StandardMaterial3D:
	if _materiales.has(kind):
		return _materiales[kind]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness = 1.0
	var color := Color(0.35, 0.45, 0.28)
	match kind:
		"ground": color = Color(0.28, 0.42, 0.24)
		"water": color = Color(0.08, 0.35, 0.68)
		"wall": color = Color(0.48, 0.48, 0.50)
		"vegetation": color = Color(0.12, 0.55, 0.20)
		"stairs": color = Color(0.72, 0.54, 0.26)
		"decoration": color = Color(0.62, 0.43, 0.22)
		"unmapped": color = Color(1.0, 0.0, 1.0)
	mat.albedo_color = color
	_materiales[kind] = mat
	return mat


func _crear_rejilla() -> void:
	var min_x := int(_region.get("min_x", _ancla.x))
	var max_x := int(_region.get("max_x", _ancla.x))
	var min_y := int(_region.get("min_y", _ancla.y))
	var max_y := int(_region.get("max_y", _ancla.y))
	var floor_y := COORD.tibia_a_mundo(Vector3i(_ancla.x, _ancla.y, _ancla.z), _ancla).y + 0.015
	var vertices := PackedVector3Array()
	for x in range(min_x, max_x + 2):
		var a := COORD.tibia_a_mundo(Vector3i(x, min_y, _ancla.z), _ancla)
		var b := COORD.tibia_a_mundo(Vector3i(x, max_y + 1, _ancla.z), _ancla)
		vertices.append(Vector3(a.x, floor_y, a.z))
		vertices.append(Vector3(b.x, floor_y, b.z))
	for y in range(min_y, max_y + 2):
		var a := COORD.tibia_a_mundo(Vector3i(min_x, y, _ancla.z), _ancla)
		var b := COORD.tibia_a_mundo(Vector3i(max_x + 1, y, _ancla.z), _ancla)
		vertices.append(Vector3(a.x, floor_y, a.z))
		vertices.append(Vector3(b.x, floor_y, b.z))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.85, 0.55, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = mat
	node.visible = _mostrar_rejilla
	_nodo_debug.add_child(node)


func _crear_cartel_escena(cantidades: Dictionary) -> void:
	var etiqueta := Label3D.new()
	etiqueta.text = "REAL OTBM / IR\n%d tiles  %d items\n%d unmapped" % [
		cantidades["tiles"], cantidades["items"], cantidades["unmapped"]]
	etiqueta.position = Vector3(0, 2.0, 0)
	etiqueta.font_size = 32
	etiqueta.modulate = Color(0.95, 0.95, 0.80)
	_nodo_debug.add_child(etiqueta)


func _crear_jugador() -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.9
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material_for("player")
	_jugador.add_child(visual)
	add_child(_jugador)
	_actualizar_jugador()


func _crear_hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_color", Color(0.95, 0.95, 0.90))
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 5)
	capa.add_child(_hud)


func _actualizar_jugador() -> void:
	var world := COORD.tibia_a_mundo(_pos_jugador, _ancla)
	_jugador.position = world + Vector3(0, 0.55, 0)


func _actualizar_hud() -> void:
	if _hud == null:
		return
	var world := COORD.tibia_a_mundo(_pos_jugador, _ancla)
	var tile: Dictionary = _tiles.get(_seleccion, {})
	var selected_text := "none"
	if not tile.is_empty():
		var ids: Array = tile.get("items", []).map(func(item): return str(item.get("server_id", 0)))
		selected_text = "(%d,%d,%d) ground=%s items=%s walkable=%s" % [
			_seleccion.x, _seleccion.y, _seleccion.z,
			str(tile.get("ground", {}).get("server_id", "none")),
			",".join(ids), str(tile.get("walkable", true))]
	_hud.text = "TVP3D REGION VALIDATOR\n" + \
		"Player Tibia: (%d, %d, %d)  World: (%.1f, %.1f, %.1f)\n" % [
			_pos_jugador.x, _pos_jugador.y, _pos_jugador.z,
			world.x, world.y, world.z] + \
		"Chunk: %s  Tiles: %d  Groups: %d\n" % [
			str(COORD.chunk_de(_pos_jugador, CHUNK_SIZE)), _tiles.size(), _grupos.size()] + \
		"Grid[G]: %s  Blocking[B]: %s  Chunks[C]: %s  Free camera[F]: %s\n" % [
			str(_mostrar_rejilla), str(_mostrar_bloqueo), str(_mostrar_chunks), str(_camara_libre)] + \
		"Selected tile: " + selected_text + "\n" + \
		"Arrows/WASD move SQM | PageUp/PageDown use stair connector | drag + wheel camera"


func _process(delta: float) -> void:
	if not _camara_libre:
		var centro := _jugador.position + Vector3(0, 0.2, 0)
		var lejos := Vector3(sin(_giro) * cos(_inclinacion), sin(_inclinacion),
			cos(_giro) * cos(_inclinacion)) * _distancia
		_camara.position = _camara.position.lerp(centro + lejos, clampf(delta * 8.0, 0.0, 1.0))
		_camara.look_at(centro, Vector3.UP)
	_actualizar_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			_mostrar_rejilla = not _mostrar_rejilla
			if _nodo_debug.get_child_count() > 0:
				_nodo_debug.get_child(0).visible = _mostrar_rejilla
		elif event.keycode == KEY_B:
			_mostrar_bloqueo = not _mostrar_bloqueo
		elif event.keycode == KEY_C:
			_mostrar_chunks = not _mostrar_chunks
		elif event.keycode == KEY_F:
			_camara_libre = not _camara_libre
		elif event.keycode == KEY_PAGEUP:
			_mover_vertical(-1)
		elif event.keycode == KEY_PAGEDOWN:
			_mover_vertical(1)
		else:
			_mover_por_tecla(event.keycode)
		_actualizar_hud()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_arrastrando = event.pressed
			if event.pressed:
				_inspeccionar(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_distancia = maxf(4.0, _distancia - 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_distancia = minf(45.0, _distancia + 1.0)
	elif event is InputEventMouseMotion and _arrastrando:
		_giro -= event.relative.x * 0.01
		_inclinacion = clampf(_inclinacion + event.relative.y * 0.01, 0.15, 1.35)


func _mover_por_tecla(keycode: Key) -> void:
	var delta := Vector3i.ZERO
	match keycode:
		KEY_UP, KEY_W: delta = Vector3i(0, -1, 0)
		KEY_DOWN, KEY_S: delta = Vector3i(0, 1, 0)
		KEY_RIGHT, KEY_D: delta = Vector3i(1, 0, 0)
		KEY_LEFT, KEY_A: delta = Vector3i(-1, 0, 0)
		_: return
	_intentar_mover(_pos_jugador + delta)


func _mover_vertical(delta_z: int) -> void:
	var destino := Vector3i(_pos_jugador.x, _pos_jugador.y, _pos_jugador.z + delta_z)
	var actual: Dictionary = _tiles.get(_pos_jugador, {})
	var siguiente: Dictionary = _tiles.get(destino, {})
	if _tiene_conector(actual) or _tiene_conector(siguiente):
		_intentar_mover(destino)


func _tiene_conector(tile: Dictionary) -> bool:
	for item in tile.get("items", []):
		if str(item.get("category", "")).to_upper() == "STAIRS":
			return true
	return false


func _intentar_mover(destino: Vector3i) -> void:
	var tile: Dictionary = _tiles.get(destino, {})
	if tile.is_empty() or not bool(tile.get("walkable", false)):
		print("Movimiento rechazado por OTBM: (%d,%d,%d)" % [destino.x, destino.y, destino.z])
		return
	_pos_jugador = destino
	_actualizar_jugador()


func _inspeccionar(mouse_position: Vector2) -> void:
	if _camara == null:
		return
	var origen := _camara.project_ray_origin(mouse_position)
	var direccion := _camara.project_ray_normal(mouse_position)
	var piso := COORD.tibia_a_mundo(Vector3i(_ancla.x, _ancla.y, _pos_jugador.z), _ancla).y
	if absf(direccion.y) < 0.0001:
		return
	var distancia := (piso - origen.y) / direccion.y
	if distancia < 0.0:
		return
	var punto := origen + direccion * distancia
	_seleccion = COORD.mundo_a_tibia(punto, _ancla)


func _capturar() -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://region_capture.png")
	print("Region capture saved: %s" % ProjectSettings.globalize_path("res://region_capture.png"))
	print("tiles=%d groups=%d" % [_tiles.size(), _grupos.size()])
	get_tree().quit(0)
