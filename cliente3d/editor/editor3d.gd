extends Node3D

## Editor de mappings 3D sobre el mapa real importado.
##
## Este editor no modifica el OTBM ni los datos del servidor. Lee el mapa
## convertido que usa el cliente, permite seleccionar un SQM y guarda solo la
## capa visual editable en assets/mappings/items.json.

const DISCO := preload("res://red/mapa_disco.gd")
const CATALOGO := preload("res://red/mapa772.gd")
const SPRITES := preload("res://red/sprites772.gd")
const COORD := preload("res://comun/coordenadas_tibia.gd")

const ARCHIVO_MAPPING := "res://assets/mappings/items.json"
const LADO := COORD.SQM_WORLD_SIZE
const ALTO_PISO := COORD.FLOOR_WORLD_HEIGHT
const RADIO := 18
const ALTO_PARED_POR_DEFECTO := 1.05
const GROSOR_PARED_POR_DEFECTO := 0.20

const PRIMITIVAS := ["auto", "flat", "card", "wall", "box"]
const NOMBRES_PRIMITIVAS := ["Auto", "Suelo horizontal", "Sprite vertical", "Pared", "Caja"]

var _disco
var _catalogo
var _sprites
var _centro := Vector3i(32091, 32187, 7)
var _mapa_visible := {}
var _mappings := {}
var _mallas := {}
var _materiales := {}

var _mundo: Node3D
var _camara: Camera3D
var _luz: DirectionalLight3D
var _objetivo_camara := Vector3.ZERO
var _giro := deg_to_rad(38.0)
var _inclinacion := deg_to_rad(42.0)
var _distancia := 12.0
var _arrastrando := false

var _seleccionado_tile := Vector3i(-9999, -9999, -9999)
var _seleccionado_cid := 0

var _x_edit: LineEdit
var _y_edit: LineEdit
var _z_edit: LineEdit
var _items_select: OptionButton
var _primitiva_select: OptionButton
var _alto_spin: SpinBox
var _grosor_spin: SpinBox
var _sprite_preview: TextureRect
var _tile_info: Label
var _mapping_info: Label
var _estado: Label


func _ready() -> void:
	_disco = DISCO.new()
	_catalogo = CATALOGO.new()
	_sprites = SPRITES.new()
	_cargar_mappings()
	_armar_escena_3d()
	_armar_interfaz()
	_cargar_region(_centro)
	if "--self-test" in OS.get_cmdline_user_args():
		call_deferred("_terminar_self_test")
	if "--captura" in OS.get_cmdline_user_args():
		call_deferred("_capturar_editor")


func _terminar_self_test() -> void:
	print("Editor3D OK | casillas=%d | item=%d" % [
		_mapa_visible.size(), _seleccionado_cid])
	get_tree().quit(0)


func _capturar_editor() -> void:
	await get_tree().create_timer(1.0).timeout
	await get_tree().process_frame
	var imagen := get_viewport().get_texture().get_image()
	imagen.save_png("res://editor/captura_editor.png")
	print("Captura editor guardada | casillas=%d | item=%d" % [
		_mapa_visible.size(), _seleccionado_cid])
	get_tree().quit(0)


func _armar_escena_3d() -> void:
	_mundo = Node3D.new()
	_mundo.name = "MundoEditable"
	add_child(_mundo)

	_luz = DirectionalLight3D.new()
	_luz.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	_luz.light_energy = 1.15
	add_child(_luz)

	var ambiente := WorldEnvironment.new()
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color(0.055, 0.065, 0.09)
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.55, 0.57, 0.64)
	entorno.ambient_light_energy = 0.8
	ambiente.environment = entorno
	add_child(ambiente)

	_camara = Camera3D.new()
	_camara.fov = 55.0
	_camara.far = 300.0
	_camara.current = true
	add_child(_camara)


func _armar_interfaz() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 10
	add_child(capa)

	var panel := Panel.new()
	panel.position = Vector2(12, 12)
	panel.size = Vector2(330, 690)
	capa.add_child(panel)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 14)
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_right", 14)
	margen.add_theme_constant_override("margin_bottom", 12)
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 7)
	margen.add_child(columna)

	var titulo := Label.new()
	titulo.text = "TVP3D MAP EDITOR"
	titulo.add_theme_font_size_override("font_size", 20)
	columna.add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "Mapa real | mapping visual por itemId"
	subtitulo.modulate = Color(0.70, 0.74, 0.82)
	columna.add_child(subtitulo)

	columna.add_child(HSeparator.new())
	columna.add_child(_etiqueta("REGION"))
	var coordenadas := HBoxContainer.new()
	coordenadas.add_theme_constant_override("separation", 5)
	columna.add_child(coordenadas)
	_x_edit = _entrada("X", "32091")
	_y_edit = _entrada("Y", "32187")
	_z_edit = _entrada("Z", "7")
	coordenadas.add_child(_x_edit)
	coordenadas.add_child(_y_edit)
	coordenadas.add_child(_z_edit)
	var cargar := Button.new()
	cargar.text = "Cargar"
	cargar.tooltip_text = "Cargar la region real alrededor de X/Y/Z"
	cargar.pressed.connect(_cargar_region_desde_formulario)
	columna.add_child(cargar)

	_tile_info = Label.new()
	_tile_info.custom_minimum_size.y = 72
	_tile_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_tile_info)

	columna.add_child(HSeparator.new())
	columna.add_child(_etiqueta("ITEM DEL SQM"))
	_items_select = OptionButton.new()
	_items_select.tooltip_text = "Elegir ground o item del stack seleccionado"
	_items_select.item_selected.connect(_al_cambiar_item)
	columna.add_child(_items_select)

	_sprite_preview = TextureRect.new()
	_sprite_preview.custom_minimum_size = Vector2(160, 120)
	_sprite_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(_sprite_preview)

	_mapping_info = Label.new()
	_mapping_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_mapping_info)

	columna.add_child(_etiqueta("REPRESENTACION 3D"))
	_primitiva_select = OptionButton.new()
	for i in PRIMITIVAS.size():
		_primitiva_select.add_item(NOMBRES_PRIMITIVAS[i])
		_primitiva_select.set_item_metadata(i, PRIMITIVAS[i])
	_primitiva_select.tooltip_text = "Forma que se genera para este item"
	_primitiva_select.item_selected.connect(_al_cambiar_primitiva)
	columna.add_child(_primitiva_select)

	_alto_spin = _numero("Alto pared", 0.10, 3.0, 0.05, ALTO_PARED_POR_DEFECTO)
	_grosor_spin = _numero("Grosor pared", 0.05, 1.0, 0.05, GROSOR_PARED_POR_DEFECTO)
	columna.add_child(_alto_spin.get_meta("fila"))
	columna.add_child(_grosor_spin.get_meta("fila"))
	_alto_spin.value_changed.connect(_al_cambiar_parametro)
	_grosor_spin.value_changed.connect(_al_cambiar_parametro)

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 6)
	var guardar := Button.new()
	guardar.text = "Guardar mapping"
	guardar.tooltip_text = "Guardar la regla visual del itemId seleccionado"
	guardar.pressed.connect(_guardar_mapping_seleccionado)
	acciones.add_child(guardar)
	var recargar := Button.new()
	recargar.text = "Aplicar"
	recargar.tooltip_text = "Reconstruir la region con los mappings guardados"
	recargar.pressed.connect(_aplicar_mapping)
	acciones.add_child(recargar)
	columna.add_child(acciones)

	_estado = Label.new()
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado.modulate = Color(0.70, 0.82, 0.70)
	columna.add_child(_estado)

	var ayuda := Label.new()
	ayuda.text = "Click: seleccionar SQM\nClick derecho + arrastre: camara\nRueda: zoom"
	ayuda.modulate = Color(0.58, 0.62, 0.70)
	columna.add_spacer(false)
	columna.add_child(ayuda)


func _etiqueta(texto: String) -> Label:
	var label := Label.new()
	label.text = texto
	label.modulate = Color(0.58, 0.68, 0.84)
	return label


func _entrada(placeholder: String, valor: String) -> LineEdit:
	var entrada := LineEdit.new()
	entrada.placeholder_text = placeholder
	entrada.text = valor
	entrada.custom_minimum_size.x = 82
	entrada.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entrada.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return entrada


func _numero(nombre: String, minimo: float, maximo: float, paso: float,
		valor: float) -> SpinBox:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	var etiqueta := Label.new()
	etiqueta.text = nombre
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(etiqueta)
	var numero := SpinBox.new()
	numero.min_value = minimo
	numero.max_value = maximo
	numero.step = paso
	numero.value = valor
	numero.custom_minimum_size.x = 110
	fila.add_child(numero)
	numero.set_meta("fila", fila)
	return numero


func _cargar_mappings() -> void:
	var archivo := FileAccess.open(ARCHIVO_MAPPING, FileAccess.READ)
	if archivo == null:
		_mappings = {}
		return
	var datos = JSON.parse_string(archivo.get_as_text())
	if typeof(datos) == TYPE_DICTIONARY:
		_mappings = datos.get("items", datos)


func _guardar_mappings() -> bool:
	var dir := DirAccess.open("res://assets")
	if dir != null:
		dir.make_dir_recursive("mappings")
	var archivo := FileAccess.open(ARCHIVO_MAPPING, FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(JSON.stringify({
		"format": "tvp3d.item-mapping.v1",
		"items": _mappings,
	}, "\t"))
	return true


func _cargar_region_desde_formulario() -> void:
	var nuevo := Vector3i(int(_x_edit.text), int(_y_edit.text), int(_z_edit.text))
	_cargar_region(nuevo)


func _cargar_region(centro: Vector3i) -> void:
	_centro = centro
	_x_edit.text = str(centro.x)
	_y_edit.text = str(centro.y)
	_z_edit.text = str(centro.z)
	_mapa_visible = _disco.casillas_de(centro, RADIO)
	_reconstruir_mundo()
	_seleccionar_tile(centro)
	_estado.text = "Region cargada: %d casillas | %d trozos" % [
		_mapa_visible.size(), _disco.trozos_cargados()]


func _reconstruir_mundo() -> void:
	for hijo in _mundo.get_children():
		hijo.queue_free()
	_mallas.clear()
	_materiales.clear()

	var grupos := {}
	for donde_variant in _mapa_visible:
		var donde: Vector3i = donde_variant
		if donde.z != _centro.z:
			continue
		var ids: PackedInt32Array = _mapa_visible[donde]
		for cid_variant in ids:
			var cid := int(cid_variant)
			var primitiva := _primitiva_de(cid)
			if primitiva == "skip":
				continue
			var orientacion := _orientacion_de(cid, donde) if primitiva == "wall" else 0
			var clave := "%d_%s_%d" % [cid, primitiva, orientacion]
			if not grupos.has(clave):
				grupos[clave] = {"cid": cid, "primitiva": primitiva,
					"orientacion": orientacion, "posiciones": []}
			var posicion := COORD.tibia_a_mundo(donde, _centro, LADO, ALTO_PISO)
			var alto := _alto_de(cid, primitiva)
			if primitiva == "wall" or primitiva == "box" or primitiva == "card":
				posicion.y += alto * 0.5
			else:
				posicion.y += 0.02
			grupos[clave]["posiciones"].append(posicion)

	var claves: Array = grupos.keys()
	claves.sort()
	for clave in claves:
		_volcar_grupo(grupos[clave])
	_estado.text = "Region: %d grupos | selecciona un SQM" % grupos.size()


func _volcar_grupo(grupo: Dictionary) -> void:
	var cid: int = grupo["cid"]
	var primitiva: String = grupo["primitiva"]
	var orientacion: int = grupo["orientacion"]
	var posiciones: Array = grupo["posiciones"]
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _malla_de(cid, primitiva, orientacion)
	multimesh.instance_count = posiciones.size()
	for i in posiciones.size():
		multimesh.set_instance_transform(i, Transform3D(Basis(), posiciones[i]))
	var nodo := MultiMeshInstance3D.new()
	nodo.multimesh = multimesh
	nodo.material_override = _material_de(cid, primitiva)
	nodo.set_meta("item_id", cid)
	nodo.set_meta("primitiva", primitiva)
	_mundo.add_child(nodo)


func _primitiva_de(cid: int) -> String:
	var ficha = _mappings.get(str(cid), {})
	if typeof(ficha) == TYPE_DICTIONARY and ficha.has("primitive"):
		return String(ficha["primitive"])
	var info: Dictionary = _catalogo.info_item(cid)
	if info.is_empty() or not _sprites.tiene_item(cid):
		return "skip"
	var nombre := String(info.get("nombre", "")).to_lower()
	if nombre.contains("sewer") or nombre.contains("grate") \
		or nombre == "ladder" or nombre.contains("stairs") \
		or nombre.contains("stair") or nombre.contains("trapdoor") \
		or nombre.contains("hole") or nombre.contains("ramp") \
		or info.get("suelo", false) or nombre.contains("counter") \
		or nombre.contains("table") \
		or nombre.contains("roof") or nombre.contains("mountain") \
		or nombre.contains("cliff"):
		return "flat"
	if info.get("bloquea", false) and info.get("frena_vista", false):
		return "wall"
	return "card"


func _orientacion_de(cid: int, donde: Vector3i) -> int:
	var conecta_x := _hay_primitiva_en(donde + Vector3i(-1, 0, 0), "wall") \
		or _hay_primitiva_en(donde + Vector3i(1, 0, 0), "wall")
	var conecta_z := _hay_primitiva_en(donde + Vector3i(0, -1, 0), "wall") \
		or _hay_primitiva_en(donde + Vector3i(0, 1, 0), "wall")
	return 1 if conecta_z and not conecta_x else 0


func _hay_primitiva_en(donde: Vector3i, buscada: String) -> bool:
	for cid_variant in _mapa_visible.get(donde, PackedInt32Array()):
		if _primitiva_de(int(cid_variant)) == buscada:
			return true
	return false


func _alto_de(cid: int, primitiva: String) -> float:
	var ficha = _mappings.get(str(cid), {})
	if typeof(ficha) == TYPE_DICTIONARY and ficha.has("height"):
		return float(ficha["height"])
	if primitiva == "wall":
		return ALTO_PARED_POR_DEFECTO
	return float(_sprites.alto_en_casillas(cid))


func _grosor_de(cid: int) -> float:
	var ficha = _mappings.get(str(cid), {})
	if typeof(ficha) == TYPE_DICTIONARY and ficha.has("thickness"):
		return float(ficha["thickness"])
	return GROSOR_PARED_POR_DEFECTO


func _malla_de(cid: int, primitiva: String, orientacion: int) -> Mesh:
	var ancho: int = int(_sprites.ancho_en_casillas(cid))
	var alto: int = int(_sprites.alto_en_casillas(cid))
	var clave := "%d_%s_%d_%d_%d" % [cid, primitiva, orientacion, ancho, alto]
	if _mallas.has(clave):
		return _mallas[clave]
	var malla: Mesh
	match primitiva:
		"flat":
			var plano := PlaneMesh.new()
			plano.size = Vector2(ancho * LADO, alto * LADO)
			malla = plano
		"card":
			var tarjeta := QuadMesh.new()
			tarjeta.size = Vector2(ancho * LADO, alto * LADO)
			malla = tarjeta
		"wall":
			var pared := BoxMesh.new()
			var grosor := _grosor_de(cid)
			pared.size = Vector3(LADO, _alto_de(cid, primitiva), grosor)
			if orientacion == 1:
				pared.size = Vector3(grosor, _alto_de(cid, primitiva), LADO)
			malla = pared
		"box":
			var caja := BoxMesh.new()
			caja.size = Vector3(LADO * 0.8, _alto_de(cid, primitiva), LADO * 0.8)
			malla = caja
		_:
			var suelo := PlaneMesh.new()
			suelo.size = Vector2(LADO, LADO)
			malla = suelo
	_mallas[clave] = malla
	return malla


func _material_de(cid: int, primitiva: String) -> StandardMaterial3D:
	var ficha = _mappings.get(str(cid), {})
	var color := _color_de(cid, ficha)
	var clave := "%d_%s_%s" % [cid, primitiva, str(color)]
	if _materiales.has(clave):
		return _materiales[clave]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if primitiva == "flat" or primitiva == "card":
		var cuadro: Dictionary = _sprites.cuadro_item(cid, 0)
		if not cuadro.is_empty():
			material.albedo_texture = cuadro["lamina"]
			material.uv1_scale = cuadro["escala"]
			material.uv1_offset = cuadro["corrimiento"]
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.5
			if primitiva == "card":
				material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		else:
			material.albedo_color = Color(1.0, 0.0, 1.0)
	else:
		material.albedo_color = color
	_materiales[clave] = material
	return material


func _color_de(cid: int, ficha) -> Color:
	if typeof(ficha) == TYPE_DICTIONARY and ficha.has("color"):
		var rgb = ficha["color"]
		if typeof(rgb) == TYPE_ARRAY and rgb.size() >= 3:
			return Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
	var nombre := String(_catalogo.info_item(cid).get("nombre", "")).to_lower()
	if nombre.contains("grass") or nombre.contains("bamboo"):
		return Color(0.20, 0.42, 0.16)
	if nombre.contains("wood") or nombre.contains("framework"):
		return Color(0.48, 0.28, 0.12)
	if nombre.contains("brick"):
		return Color(0.48, 0.24, 0.16)
	if nombre.contains("sandstone"):
		return Color(0.66, 0.52, 0.31)
	return Color(0.34, 0.35, 0.37)


func _seleccionar_tile(donde: Vector3i) -> void:
	_seleccionado_tile = donde
	var ids: PackedInt32Array = _mapa_visible.get(donde, PackedInt32Array())
	_items_select.clear()
	for cid_variant in ids:
		var cid := int(cid_variant)
		var info: Dictionary = _catalogo.info_item(cid)
		_items_select.add_item("%d - %s" % [cid, info.get("nombre", "unknown")])
		_items_select.set_item_metadata(_items_select.item_count - 1, cid)
	if _items_select.item_count > 0:
		_items_select.select(0)
		_al_cambiar_item(0)
	else:
		_seleccionado_cid = 0
		_tile_info.text = "SQM (%d, %d, %d)\nVacio o fuera de la zona cargada." % [
			donde.x, donde.y, donde.z]
		_sprite_preview.texture = null
		_mapping_info.text = "Sin item seleccionado"


func _al_cambiar_item(indice: int) -> void:
	if indice < 0 or indice >= _items_select.item_count:
		return
	_seleccionado_cid = int(_items_select.get_item_metadata(indice))
	var info: Dictionary = _catalogo.info_item(_seleccionado_cid)
	_tile_info.text = "SQM (%d, %d, %d)\nItem %d: %s\nGround: %s | bloquea: %s | frena vista: %s" % [
		_seleccionado_tile.x, _seleccionado_tile.y, _seleccionado_tile.z,
		_seleccionado_cid, info.get("nombre", "unknown"),
		str(info.get("suelo", false)), str(info.get("bloquea", false)),
		str(info.get("frena_vista", false))]
	var cuadro: Dictionary = _sprites.cuadro_item(_seleccionado_cid, 0)
	_sprite_preview.texture = _atlas_texture(cuadro)
	var mapping = _mappings.get(str(_seleccionado_cid), {})
	var primitiva := String(mapping.get("primitive", "auto")) if typeof(mapping) == TYPE_DICTIONARY else "auto"
	var indice_prim := PRIMITIVAS.find(primitiva)
	_primitiva_select.select(maxi(0, indice_prim))
	_alto_spin.value = float(mapping.get("height", ALTO_PARED_POR_DEFECTO)) if typeof(mapping) == TYPE_DICTIONARY else ALTO_PARED_POR_DEFECTO
	_grosor_spin.value = float(mapping.get("thickness", GROSOR_PARED_POR_DEFECTO)) if typeof(mapping) == TYPE_DICTIONARY else GROSOR_PARED_POR_DEFECTO
	_mapping_info.text = "Mapping guardado: %s\nSe aplica por itemId y puede sobrescribirse." % primitiva


func _atlas_texture(cuadro: Dictionary) -> Texture2D:
	if cuadro.is_empty():
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = cuadro["lamina"]
	var textura: Texture2D = cuadro["lamina"]
	var origen := Vector2(cuadro["corrimiento"].x * textura.get_width(),
		cuadro["corrimiento"].y * textura.get_height())
	var tamano := Vector2(cuadro["escala"].x * textura.get_width(),
		cuadro["escala"].y * textura.get_height())
	atlas.region = Rect2(origen, tamano)
	return atlas


func _al_cambiar_primitiva(_indice: int) -> void:
	_mapping_info.text = "Cambio sin guardar. Pulsa Guardar mapping."


func _al_cambiar_parametro(_valor: float) -> void:
	if _seleccionado_cid != 0:
		_mapping_info.text = "Cambio sin guardar. Pulsa Guardar mapping."


func _guardar_mapping_seleccionado() -> void:
	if _seleccionado_cid == 0:
		return
	var indice := _primitiva_select.selected
	var primitiva := String(_primitiva_select.get_item_metadata(indice))
	_mappings[str(_seleccionado_cid)] = {
		"primitive": primitiva,
		"height": _alto_spin.value,
		"thickness": _grosor_spin.value,
		"source": "tvp3d-map-editor",
	}
	if _guardar_mappings():
		_mapping_info.text = "Mapping guardado para %d: %s" % [_seleccionado_cid, primitiva]
		_reconstruir_mundo()
	else:
		_mapping_info.text = "ERROR: no se pudo escribir " + ARCHIVO_MAPPING


func _aplicar_mapping() -> void:
	_cargar_mappings()
	_reconstruir_mundo()
	_al_cambiar_item(_items_select.selected)


func _process(delta: float) -> void:
	var offset := Vector3(
		sin(_giro) * cos(_inclinacion),
		sin(_inclinacion),
		cos(_giro) * cos(_inclinacion)) * _distancia
	var destino := _objetivo_camara + offset
	_camara.position = _camara.position.lerp(destino, clampf(delta * 8.0, 0.0, 1.0))
	_camara.look_at(_objetivo_camara, Vector3.UP)


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		if evento.button_index == MOUSE_BUTTON_RIGHT:
			_arrastrando = evento.pressed
		elif evento.button_index == MOUSE_BUTTON_WHEEL_UP and evento.pressed:
			_distancia = maxf(4.0, _distancia - 1.0)
		elif evento.button_index == MOUSE_BUTTON_WHEEL_DOWN and evento.pressed:
			_distancia = minf(36.0, _distancia + 1.0)
		elif evento.button_index == MOUSE_BUTTON_LEFT and evento.pressed:
			var tile = _tile_bajo_mouse(evento.position)
			if tile != null:
				_seleccionar_tile(tile)
	elif evento is InputEventMouseMotion and _arrastrando:
		_giro -= deg_to_rad(evento.relative.x * 0.45)
		_inclinacion = clampf(_inclinacion + deg_to_rad(evento.relative.y * 0.35), 0.18, 1.35)
	elif evento is InputEventKey and evento.pressed and evento.keycode == KEY_ESCAPE:
		get_tree().quit()


func _tile_bajo_mouse(posicion_mouse: Vector2):
	var origen := _camara.project_ray_origin(posicion_mouse)
	var direccion := _camara.project_ray_normal(posicion_mouse)
	var y := COORD.tibia_a_mundo(_centro, _centro, LADO, ALTO_PISO).y
	if absf(direccion.y) < 0.0001:
		return null
	var distancia := (y - origen.y) / direccion.y
	if distancia < 0.0:
		return null
	var punto := origen + direccion * distancia
	var tile := COORD.mundo_a_tibia(punto, _centro, LADO, ALTO_PISO)
	if absi(tile.x - _centro.x) > RADIO or absi(tile.y - _centro.y) > RADIO:
		return null
	return Vector3i(tile.x, tile.y, _centro.z)
