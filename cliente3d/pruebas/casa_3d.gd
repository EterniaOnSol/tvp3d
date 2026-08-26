extends Node3D

## Escena de validacion de modelos 3D sobre la casa Spiritkeep.

const MAPPER := preload("res://mundo/casa_mapper_3d.gd")

const HOUSE_ID := 1

var _mapper := MAPPER.new()
var _camara: Camera3D
var _hud: Label
var _giro := 0.72
var _inclinacion := 0.62
var _distancia := 14.0
var _arrastrando := false


func _ready() -> void:
	print("Spiritkeep 3D: starting mapper")
	add_child(_mapper)
	var cargada: bool = _mapper.cargar_casa(HOUSE_ID)
	print("Spiritkeep 3D: mapper result=%s objects=%d" % [cargada, _mapper.object_count()])
	if not cargada:
		push_error("Could not load Spiritkeep")
		return
	_armar_luces()
	_armar_hud()
	_actualizar_camara(0.0)
	_actualizar_hud()
	if "--captura" in OS.get_cmdline_user_args():
		_capturar.call_deferred()


func _armar_luces() -> void:
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sol.light_energy = 1.35
	add_child(sol)
	var relleno := DirectionalLight3D.new()
	relleno.rotation_degrees = Vector3(-20.0, 145.0, 0.0)
	relleno.light_energy = 0.35
	add_child(relleno)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#111720")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b7c8d8")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.environment = env
	add_child(ambiente)
	_camara = Camera3D.new()
	_camara.fov = 55.0
	_camara.far = 120.0
	add_child(_camara)


func _armar_hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(18, 16)
	_hud.add_theme_font_size_override("font_size", 16)
	_hud.add_theme_color_override("font_color", Color("#f2e6c9"))
	_hud.add_theme_color_override("font_outline_color", Color("#111111"))
	_hud.add_theme_constant_override("outline_size", 6)
	capa.add_child(_hud)


func _actualizar_hud() -> void:
	var info := _mapper.house_info()
	var categorias: Dictionary = _mapper.category_counts()
	_hud.text = "SPIRITKEEP 3D MODEL VALIDATION\n" \
		+ "House ID: %d  |  Entry: (%d, %d, %d)  |  Objects: %d\n" % [
			_mapper.house_id(), int(info.get("entry", {}).get("x", 0)),
			int(info.get("entry", {}).get("y", 0)), int(info.get("entry", {}).get("z", 7)),
			_mapper.object_count()] \
		+ "Floors: %s  |  Models: walls, doors, windows, stairs, furniture, nature\n" % str(info.get("floors", {})) \
		+ "Categories: " + str(categorias) + "\n" \
		+ "Left drag: orbit  |  Wheel: zoom  |  R: reset camera  |  ESC: quit"


func _actualizar_camara(delta: float) -> void:
	var centro := _mapper.world_center() + Vector3(0, 0.1, 0)
	var lejos := Vector3(sin(_giro) * cos(_inclinacion), sin(_inclinacion),
		cos(_giro) * cos(_inclinacion)) * _distancia
	var destino := centro + lejos
	if delta <= 0.0:
		_camara.position = destino
	else:
		_camara.position = _camara.position.lerp(destino, clampf(delta * 8.0, 0.0, 1.0))
	_camara.look_at(centro, Vector3.UP)


func _process(delta: float) -> void:
	_actualizar_camara(delta)


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		if evento.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif evento.keycode == KEY_R:
			_giro = 0.72
			_inclinacion = 0.62
			_distancia = 14.0
			_actualizar_camara(0.0)
	elif evento is InputEventMouseButton:
		if evento.button_index == MOUSE_BUTTON_LEFT:
			_arrastrando = evento.pressed
		elif evento.button_index == MOUSE_BUTTON_WHEEL_UP and evento.pressed:
			_distancia = maxf(5.0, _distancia - 1.0)
		elif evento.button_index == MOUSE_BUTTON_WHEEL_DOWN and evento.pressed:
			_distancia = minf(32.0, _distancia + 1.0)
	elif evento is InputEventMouseMotion and _arrastrando:
		_giro -= evento.relative.x * 0.012
		_inclinacion = clampf(_inclinacion + evento.relative.y * 0.010, 0.15, 1.25)


func _capturar() -> void:
	await get_tree().create_timer(1.0).timeout
	# En headless frame_post_draw no siempre se emite. Dos frames de proceso
	# bastan para que la camara y las mallas terminen de actualizarse.
	await get_tree().process_frame
	await get_tree().process_frame
	var textura := get_viewport().get_texture()
	if textura == null:
		print("Spiritkeep 3D capture skipped: headless renderer has no viewport texture")
		get_tree().quit(0)
		return
	var imagen := textura.get_image()
	if imagen == null:
		print("Spiritkeep 3D capture skipped: renderer returned no image")
		get_tree().quit(0)
		return
	imagen.save_png("res://casa_spiritkeep_3d.png")
	print("Spiritkeep 3D capture saved: %s" % ProjectSettings.globalize_path("res://casa_spiritkeep_3d.png"))
	print("objects=%d categories=%s" % [_mapper.object_count(), _mapper.category_counts()])
	get_tree().quit(0)
