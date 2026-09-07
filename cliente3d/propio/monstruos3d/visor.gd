extends SceneTree

const CATALOGO := preload("res://propio/monstruos3d/catalogo.gd")
const SPRITES := preload("res://red/sprites772.gd")
var modelos = CATALOGO.new()
var sprites = SPRITES.new()
var escena := Node3D.new()
var camara := Camera3D.new()
var modelo := MeshInstance3D.new()
var selector := OptionButton.new()
var imagen := TextureRect.new()
var reproducir := CheckButton.new()
var girar := CheckButton.new()
var orientacion := OptionButton.new()
var info := Label.new()
var reloj := 0.0
var angulo := .65
var elevacion := .55
var distancia := 3.0
var tipo := 34
var capturar := false
var frames := 0
var salida := ""
var comparar := CheckButton.new()
var zoom_comparacion := 1.0
var grupo := Node3D.new()
var comparados: Array[MeshInstance3D] = []
var ids_comparados := [21,83,79,38,27,34]
var _revision := 0
var _ultima_revision := 0.0


func _initialize() -> void:
	call_deferred("_crear")


func _crear() -> void:
	root.title = "TVP3D - Monsters 3D"
	root.add_child(escena)
	var entorno := WorldEnvironment.new()
	entorno.environment = Environment.new()
	entorno.environment.background_mode = Environment.BG_COLOR
	entorno.environment.background_color = Color("171e25")
	entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.environment.ambient_light_color = Color.WHITE
	entorno.environment.ambient_light_energy = .55
	escena.add_child(entorno)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55, -30, 0)
	luz.light_energy = 1.15
	luz.shadow_enabled = true
	escena.add_child(luz)
	var relleno := DirectionalLight3D.new()
	relleno.rotation_degrees = Vector3(-30, 135, 0)
	relleno.light_color = Color(0.70, 0.83, 1.0)
	relleno.light_energy = .45
	escena.add_child(relleno)
	var piso := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(200,200)
	piso.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("202a30")
	mat.roughness = 1.0
	piso.material_override = mat
	piso.position.y = -.025
	escena.add_child(piso)
	escena.add_child(modelo)
	escena.add_child(grupo)
	grupo.visible = false
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	escena.add_child(camara)
	camara.current = true
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var toolbar := HBoxContainer.new()
	toolbar.position = Vector2(20,16)
	toolbar.add_theme_constant_override("separation", 18)
	canvas.add_child(toolbar)
	selector.custom_minimum_size.x = 200
	var ids: Array = modelos.fichas.keys()
	ids.sort_custom(func(a,b): return str(modelos.fichas[a]["nombre"]) < str(modelos.fichas[b]["nombre"]))
	for id in ids:
		if not modelos.fichas[id].get("anatomia", false):
			continue
		selector.add_item(str(modelos.fichas[id]["nombre"]).split(" / ")[0], int(id))
	toolbar.add_child(selector)
	selector.item_selected.connect(func(i): _elegir(selector.get_item_id(i)))
	reproducir.text = "Animation"
	reproducir.button_pressed = true
	toolbar.add_child(reproducir)
	girar.text = "Orbit"
	girar.button_pressed = true
	toolbar.add_child(girar)
	for nombre in ["North", "East", "South", "West"]:
		orientacion.add_item(nombre)
	orientacion.select(2)
	toolbar.add_child(orientacion)
	orientacion.item_selected.connect(func(_i): _actualizar_modelo())
	comparar.text = "Comparar tamanos"
	toolbar.add_child(comparar)
	comparar.toggled.connect(func(activo):
		modelo.visible = not activo
		grupo.visible = activo
		imagen.visible = not activo
		selector.disabled = activo
		orientacion.disabled = activo
		girar.button_pressed = false
		info.position = Vector2(20,65) if activo else Vector2(20,270)
		if activo:
			angulo = .12
			elevacion = .86
		else:
			_elegir(tipo)
	)
	imagen.position = Vector2(20,80)
	imagen.size = Vector2(176,176)
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.add_child(imagen)
	info.position = Vector2(20,270)
	canvas.add_child(info)
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--tipo" and i+1 < args.size():
			tipo = int(args[i+1])
		if args[i] == "--captura" and i+1 < args.size():
			capturar = true
			salida = args[i+1]
		if args[i] == "--angulo" and i+1 < args.size():
			angulo = float(args[i+1])
		if args[i] == "--fase" and i+1 < args.size():
			reloj = float(args[i+1]) / 6.0
		if args[i] == "--elevacion" and i+1 < args.size():
			elevacion = float(args[i+1])
		if args[i] == "--grupo" and i+1 < args.size():
			ids_comparados.clear()
			for id in args[i+1].split(","):
				if modelos.es_monstruo(0x40000001,int(id)):
					ids_comparados.append(int(id))
	_crear_comparacion()
	_elegir(tipo)
	comparar.button_pressed = "--comparar" in args


func _crear_comparacion() -> void:
	if ids_comparados.is_empty():
		ids_comparados = [21,83,79,38,27,34]
	var columnas := mini(3, ids_comparados.size())
	var filas := ceili(float(ids_comparados.size()) / columnas)
	for i in range(ids_comparados.size()):
		var id: int = ids_comparados[i]
		var nodo := MeshInstance3D.new()
		nodo.mesh = modelos.malla(id)
		nodo.position = Vector3((i % columnas - (columnas-1)*.5)*3.2,0,(floori(float(i)/columnas)-(filas-1)*.5)*3.1)
		grupo.add_child(nodo)
		comparados.append(nodo)
		var etiqueta := Label3D.new()

		etiqueta.text = "%s\n%.2f casillas" % [str(modelos.fichas[str(id)]["nombre"]).split(" / ")[0],float(modelos.fichas[str(id)]["escala"]["longitud_casillas"])]
		etiqueta.font_size = 36
		etiqueta.pixel_size = .0028
		etiqueta.outline_size = 8
		etiqueta.no_depth_test = true
		etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		etiqueta.position = nodo.position + Vector3(0,.12,1.28)
		grupo.add_child(etiqueta)
	var lineas := ImmediateMesh.new()
	lineas.surface_begin(Mesh.PRIMITIVE_LINES)
	for x in range(-6,7):
		lineas.surface_add_vertex(Vector3(x,-.012,-5))
		lineas.surface_add_vertex(Vector3(x,-.012,5))
	for z in range(-5,6):
		lineas.surface_add_vertex(Vector3(-6,-.012,z))
		lineas.surface_add_vertex(Vector3(6,-.012,z))
	lineas.surface_end()
	var rejilla := MeshInstance3D.new()
	rejilla.mesh = lineas
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("52616a")
	rejilla.material_override = material
	grupo.add_child(rejilla)


func _elegir(id: int) -> void:
	tipo = id
	selector.select(selector.get_item_index(tipo))
	var ficha: Dictionary = modelos.fichas.get(str(tipo), {})
	var maximo: Array = ficha.get("max", [1,1,1])
	var minimo: Array = ficha.get("min", [-1,0,-1])
	distancia = maxf(.70, maxf(float(maximo[0])-float(minimo[0]), maxf(float(maximo[1]), float(maximo[2])-float(minimo[2])))) * 1.18
	_actualizar_modelo()


func _actualizar_modelo() -> void:
	var fase := int(reloj * 6.0)
	modelo.mesh = modelos.malla(tipo, fase)
	modelo.rotation.y = CATALOGO.GIROS[orientacion.selected]
	var cuadro: Dictionary = sprites.cuadro_outfit(tipo, orientacion.selected, fase)
	if not cuadro.is_empty():
		var tex := AtlasTexture.new()
		tex.atlas = cuadro["lamina"]
		var tamano := tex.atlas.get_size()
		tex.region = Rect2(Vector2(cuadro["corrimiento"].x, cuadro["corrimiento"].y) * tamano,
			Vector2(cuadro["escala"].x, cuadro["escala"].y) * tamano)
		imagen.texture = tex
	var medidas := modelo.mesh.get_aabb().size
	info.text = "Detalle (zoom ajustado)\nOutfit %d | Pose %d / %d\nAncho %.2f | Alto %.2f | Largo %.2f casillas" % [tipo, posmod(fase, modelos.fases(tipo))+1, modelos.fases(tipo),medidas.x,medidas.y,medidas.z]
	if comparar.button_pressed:
		info.text = "Escala comun | Cuadricula: 1 casilla | Tamano incluye patas, cola y mandibulas"
		for i in range(comparados.size()):
			comparados[i].mesh = modelos.malla(ids_comparados[i],fase)


func _process(delta: float) -> bool:
	if not is_instance_valid(modelo) or not modelo.is_inside_tree():
		return false
	if reproducir.button_pressed and not capturar:
		reloj += delta
	if girar.button_pressed and not capturar:
		angulo += delta * .3
	_ultima_revision += delta
	if _ultima_revision > 2.0 and not capturar:
		_ultima_revision = 0.0
		var ruta := CATALOGO.CARPETA + str(modelos.fichas[str(tipo)]["archivo"])
		var revision := FileAccess.get_modified_time(ruta)
		if _revision != revision:
			_revision = revision
			modelos._cache.erase(tipo)
	_actualizar_modelo()
	var alto := modelo.mesh.get_aabb().size.y if modelo.mesh != null else 1.0
	var foco := Vector3(-distancia*.10, alto*.45, 0)
	camara.size = distancia
	if comparar.button_pressed:
		foco = Vector3(0,.16,0)
		camara.size = maxf(3.5,ceili(ids_comparados.size()/3.0)*3.1)*zoom_comparacion
	camara.position = foco + Vector3(sin(angulo)*cos(elevacion), sin(elevacion), cos(angulo)*cos(elevacion)) * 8
	camara.look_at(foco)
	frames += 1
	if capturar and frames == 12:
		_capturar.call_deferred()
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		angulo -= event.relative.x * .01
		elevacion = clampf(elevacion + event.relative.y * .006, .12, 1.45)
		girar.button_pressed = false
	if event is InputEventMouseButton and event.pressed:
		if comparar.button_pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_comparacion = maxf(.5,zoom_comparacion*.9)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_comparacion = minf(2.,zoom_comparacion*1.1)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distancia = maxf(.5, distancia * .9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distancia = minf(12, distancia * 1.1)


func _capturar() -> void:
	await RenderingServer.frame_post_draw
	var captura := root.get_texture().get_image()
	var err := captura.save_png(salida)
	print("MONSTERS_CAPTURE ", salida, " result=", err)
	quit(0 if err == OK else 1)
