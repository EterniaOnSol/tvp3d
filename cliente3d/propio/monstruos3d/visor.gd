extends SceneTree

const CATALOGO := preload("res://propio/monstruos3d/catalogo.gd")
const SPRITES := preload("res://red/sprites772.gd")
const ENTRADA_VISOR := preload("res://propio/monstruos3d/entrada_visor.gd")
const ID_REFERENCIA_JUGADOR := -128
const OUTFIT_JUGADOR := 128
var modelos = CATALOGO.new()
var sprites = SPRITES.new()
var escena := Node3D.new()
var receptor_entrada = ENTRADA_VISOR.new()
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
var modo_prueba := false
var frames := 0
var salida := ""
var comparar := CheckButton.new()
var zoom_comparacion := 1.0
var grupo := Node3D.new()
var comparados: Array[Node3D] = []
var etiquetas: Array[Label3D] = []
var ids_comparados: Array[int] = []
var seleccionado := -1
var arrastrando := false
var offset_arrastre := Vector3.ZERO
var foco_comparacion := Vector3.ZERO
var tamano_comparacion := 8.0
var _revision := 0
var _ultima_revision := 0.0


func _initialize() -> void:
	call_deferred("_crear")


func _crear() -> void:
	root.title = "TVP3D - Monsters 3D"
	receptor_entrada.destino = Callable(self, "_procesar_entrada")
	root.add_child(receptor_entrada)
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
	selector.add_item("Personaje principal", ID_REFERENCIA_JUGADOR)
	var ids: Array = modelos.fichas.keys()
	ids.sort_custom(func(a,b): return str(modelos.fichas[a]["nombre"]) < str(modelos.fichas[b]["nombre"]))
	for id in ids:
		if not modelos.fichas[id].get("anatomia", false):
			continue
		selector.add_item(str(modelos.fichas[id]["nombre"]).split(" / ")[0], int(id))
	toolbar.add_child(selector)
	selector.item_selected.connect(func(i): _seleccionar_desde_lista(selector.get_item_id(i)))
	reproducir.text = "Animacion"
	reproducir.button_pressed = true
	toolbar.add_child(reproducir)
	girar.text = "Orbita"
	girar.button_pressed = true
	toolbar.add_child(girar)
	for nombre in ["North", "East", "South", "West"]:
		orientacion.add_item(nombre)
	orientacion.select(2)
	toolbar.add_child(orientacion)
	orientacion.item_selected.connect(func(_i): _actualizar_modelo())
	comparar.text = "Todos"
	toolbar.add_child(comparar)
	comparar.toggled.connect(func(activo):
		modelo.visible = not activo
		grupo.visible = activo
		imagen.visible = not activo
		selector.disabled = false
		orientacion.disabled = activo
		girar.button_pressed = false
		info.position = Vector2(20,65) if activo else Vector2(20,270)
		if activo:
			angulo = .12
			elevacion = .86
			if seleccionado < 0 and not comparados.is_empty():
				_seleccionar_indice(0)
			else:
				tipo = ids_comparados[seleccionado]
				_actualizar_info_seleccion()
		else:
			if tipo == ID_REFERENCIA_JUGADOR:
				tipo = _primer_id_monstruo()
			_elegir(tipo)
	)
	var enfocar := Button.new()
	enfocar.text = "Enfocar"
	enfocar.pressed.connect(_enfocar_seleccion)
	toolbar.add_child(enfocar)
	var ordenar := Button.new()
	ordenar.text = "Ordenar"
	ordenar.pressed.connect(_ordenar_comparados)
	toolbar.add_child(ordenar)
	var ayuda := Label.new()
	ayuda.position = Vector2(20,92)
	ayuda.text = "Izq: seleccionar/arrastrar | Der: orbitar | Centro/WASD: mover camara | Rueda: zoom | Flechas: mover monster | Q/E: girar | F: enfocar | R: ordenar"
	canvas.add_child(ayuda)
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
		if args[i] == "--self-test":
			modo_prueba = true
	_crear_comparacion()
	_elegir(tipo)
	comparar.button_pressed = "--tipo" not in args or "--comparar" in args or "--todos" in args
	if modo_prueba:
		_probar_visor.call_deferred()


func _crear_comparacion() -> void:
	if ids_comparados.is_empty():
		var claves: Array = modelos.fichas.keys()
		claves.sort_custom(func(a,b):
			return str(modelos.fichas[a]["nombre"]).naturalnocasecmp_to(
				str(modelos.fichas[b]["nombre"])) < 0)
		for clave in claves:
			var id := int(clave)
			if modelos.es_monstruo(0x40000001,id):
				ids_comparados.append(id)
	if not ids_comparados.has(ID_REFERENCIA_JUGADOR):
		ids_comparados.push_front(ID_REFERENCIA_JUGADOR)
	var columnas := ceili(sqrt(float(ids_comparados.size())))
	var filas := ceili(float(ids_comparados.size())/columnas)
	tamano_comparacion = maxf(7.0,maxf(columnas,filas)*2.65)
	for i in range(ids_comparados.size()):
		var id: int = ids_comparados[i]
		var nodo: Node3D
		if id == ID_REFERENCIA_JUGADOR:
			nodo = _crear_referencia_jugador()
		else:
			var volumen := MeshInstance3D.new()
			volumen.mesh = modelos.malla(id)
			nodo = volumen
		nodo.position = _posicion_ordenada(i,columnas,filas)
		nodo.set_meta("outfit_id",id)
		grupo.add_child(nodo)
		comparados.append(nodo)
		var etiqueta := Label3D.new()
		var caja := _aabb_comparado(nodo)
		etiqueta.text = "%s\n%.2f casillas de alto" % [
			_nombre_comparado(id),caja.size.y]
		etiqueta.font_size = 32
		etiqueta.pixel_size = .0026
		etiqueta.outline_size = 8
		etiqueta.no_depth_test = true
		etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		etiqueta.position = Vector3(0,caja.end.y+.18,0)
		nodo.add_child(etiqueta)
		etiquetas.append(etiqueta)
	var lineas := ImmediateMesh.new()
	lineas.surface_begin(Mesh.PRIMITIVE_LINES)
	for n in range(-30,31):
		lineas.surface_add_vertex(Vector3(n,-.012,-30))
		lineas.surface_add_vertex(Vector3(n,-.012,30))
		lineas.surface_add_vertex(Vector3(-30,-.012,n))
		lineas.surface_add_vertex(Vector3(30,-.012,n))
	lineas.surface_end()
	var rejilla := MeshInstance3D.new()
	rejilla.mesh = lineas
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("52616a")
	rejilla.material_override = material
	grupo.add_child(rejilla)


func _crear_referencia_jugador() -> Node3D:
	var jugador := Node3D.new()
	jugador.name = "PersonajePrincipalOutfit128"
	var cuerpo := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = .13
	capsula.height = .5
	cuerpo.mesh = capsula
	cuerpo.position = Vector3(0,.3,0)
	cuerpo.material_override = _material_jugador(Color(.72,.24,.22),.7)
	jugador.add_child(cuerpo)
	var cabeza := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = .095
	esfera.height = .19
	cabeza.mesh = esfera
	cabeza.position = Vector3(0,.625,0)
	cabeza.material_override = _material_jugador(Color(.88,.73,.58),.8)
	jugador.add_child(cabeza)
	var nariz := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(.05,.05,.09)
	nariz.mesh = caja
	nariz.position = Vector3(0,.625,-.10)
	nariz.material_override = _material_jugador(Color(.2,.2,.22),.8)
	jugador.add_child(nariz)
	jugador.set_meta("aabb_comparacion",
		AABB(Vector3(-.13,.05,-.145),Vector3(.26,.67,.29)))
	return jugador


func _material_jugador(color: Color,rugosidad: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rugosidad
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _aabb_comparado(nodo: Node3D) -> AABB:
	if nodo.has_meta("aabb_comparacion"):
		return nodo.get_meta("aabb_comparacion")
	var volumen := nodo as MeshInstance3D
	return volumen.mesh.get_aabb()


func _nombre_comparado(id: int) -> String:
	if id == ID_REFERENCIA_JUGADOR:
		return "Personaje principal [outfit %d]" % OUTFIT_JUGADOR
	return "%s [%d]" % [
		str(modelos.fichas[str(id)]["nombre"]).split(" / ")[0],id]


func _primer_id_monstruo() -> int:
	for id in ids_comparados:
		if int(id) != ID_REFERENCIA_JUGADOR:
			return int(id)
	return 34


func _posicion_ordenada(indice: int,columnas: int,filas: int) -> Vector3:
	return Vector3((indice%columnas-(columnas-1)*.5)*2.4,0,
		(floori(float(indice)/columnas)-(filas-1)*.5)*2.4)


func _ordenar_comparados() -> void:
	if comparados.is_empty():
		return
	var columnas := ceili(sqrt(float(comparados.size())))
	var filas := ceili(float(comparados.size())/columnas)
	for i in range(comparados.size()):
		comparados[i].position = _posicion_ordenada(i,columnas,filas)
		comparados[i].rotation.y = 0
	foco_comparacion = Vector3.ZERO
	tamano_comparacion = maxf(7.0,maxf(columnas,filas)*2.65)
	_actualizar_info_seleccion()


func _seleccionar_desde_lista(id: int) -> void:
	if not comparar.button_pressed:
		if id == ID_REFERENCIA_JUGADOR:
			comparar.button_pressed = true
		else:
			_elegir(id)
		return
	var indice := ids_comparados.find(id)
	if indice >= 0:
		_seleccionar_indice(indice)
		_enfocar_seleccion()


func _seleccionar_indice(indice: int) -> void:
	if indice < 0 or indice >= comparados.size():
		return
	if seleccionado >= 0:
		etiquetas[seleccionado].modulate = Color.WHITE
	seleccionado = indice
	etiquetas[seleccionado].modulate = Color("ffd866")
	tipo = ids_comparados[seleccionado]
	var item := selector.get_item_index(tipo)
	if item >= 0:
		selector.select(item)
	_actualizar_info_seleccion()


func _actualizar_info_seleccion() -> void:
	if not comparar.button_pressed:
		return
	if seleccionado < 0:
		info.text = "Todos: 40 monsters + personaje | selecciona uno para moverlo"
		return
	var nodo := comparados[seleccionado]
	info.text = "Todos: 40 monsters + personaje | Seleccion: %s | X %.2f Z %.2f" % [
		_nombre_comparado(tipo),nodo.position.x,nodo.position.z]


func _seleccionar_en_pantalla(posicion: Vector2) -> bool:
	var mejor := -1
	var mejor_distancia := INF
	var pixels_por_unidad := root.get_visible_rect().size.y/maxf(camara.size,.01)
	for i in range(comparados.size()):
		var nodo := comparados[i]
		var caja := _aabb_comparado(nodo)
		var centro := nodo.to_global(caja.get_center())
		if camara.is_position_behind(centro):
			continue
		var pantalla := camara.unproject_position(centro)
		var extension := caja.size
		var radio := maxf(20.0,maxf(extension.x,maxf(extension.y,extension.z))*pixels_por_unidad*.62)
		var distancia_click := posicion.distance_to(pantalla)
		if distancia_click <= radio and distancia_click < mejor_distancia:
			mejor = i
			mejor_distancia = distancia_click
	if mejor < 0:
		return false
	_seleccionar_indice(mejor)
	return true


func _punto_en_suelo(posicion: Vector2) -> Variant:
	var origen := camara.project_ray_origin(posicion)
	var direccion := camara.project_ray_normal(posicion)
	if absf(direccion.y) < .00001:
		return null
	var avance := -origen.y/direccion.y
	return origen+direccion*avance if avance >= 0 else null


func _mover_seleccionado(delta: Vector3) -> void:
	if seleccionado < 0:
		return
	comparados[seleccionado].position += delta
	comparados[seleccionado].position.y = 0
	_actualizar_info_seleccion()


func _enfocar_seleccion() -> void:
	if seleccionado < 0:
		return
	var nodo := comparados[seleccionado]
	foco_comparacion = nodo.position
	var medidas := _aabb_comparado(nodo).size
	tamano_comparacion = maxf(1.2,maxf(medidas.x,maxf(medidas.y,medidas.z))*2.1)


func _panear_camara(delta_pantalla: Vector2) -> void:
	var escala := camara.size/maxf(root.get_visible_rect().size.y,1.0)
	var derecha := Vector3(cos(angulo),0,-sin(angulo))
	var adelante := Vector3(-sin(angulo),0,-cos(angulo))
	foco_comparacion += derecha*(-delta_pantalla.x*escala)+adelante*(delta_pantalla.y*escala)


func _elegir(id: int) -> void:
	if id == ID_REFERENCIA_JUGADOR:
		if not comparar.button_pressed:
			comparar.button_pressed = true
		var indice := ids_comparados.find(ID_REFERENCIA_JUGADOR)
		if indice >= 0:
			_seleccionar_indice(indice)
		return
	tipo = id
	selector.select(selector.get_item_index(tipo))
	var ficha: Dictionary = modelos.fichas.get(str(tipo), {})
	var maximo: Array = ficha.get("max", [1,1,1])
	var minimo: Array = ficha.get("min", [-1,0,-1])
	distancia = maxf(.70, maxf(float(maximo[0])-float(minimo[0]), maxf(float(maximo[1]), float(maximo[2])-float(minimo[2])))) * 1.18
	_actualizar_modelo()


func _actualizar_modelo() -> void:
	var fase := int(reloj * 6.0)
	if tipo != ID_REFERENCIA_JUGADOR:
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
		_actualizar_info_seleccion()
		for i in range(comparados.size()):
			if ids_comparados[i] == ID_REFERENCIA_JUGADOR:
				continue
			var volumen := comparados[i] as MeshInstance3D
			volumen.mesh = modelos.malla(ids_comparados[i],fase)
			etiquetas[i].position.y = volumen.mesh.get_aabb().end.y+.18


func _process(delta: float) -> bool:
	if not is_instance_valid(modelo) or not modelo.is_inside_tree():
		return false
	if reproducir.button_pressed and not capturar:
		reloj += delta
	if girar.button_pressed and not capturar:
		angulo += delta*.3
	_ultima_revision += delta
	if _ultima_revision > 2.0 and not capturar and not comparar.button_pressed:
		_ultima_revision = 0.0
		var ruta := CATALOGO.CARPETA + str(modelos.fichas[str(tipo)]["archivo"])
		var revision := FileAccess.get_modified_time(ruta)
		if _revision != revision:
			_revision = revision
			modelos._cache.erase(tipo)
	_actualizar_modelo()
	var alto := modelo.mesh.get_aabb().size.y if modelo.mesh != null else 1.0
	var foco := Vector3(-distancia*.10,alto*.45,0)
	camara.size = distancia
	if comparar.button_pressed:
		foco = foco_comparacion+Vector3(0,.16,0)
		camara.size = tamano_comparacion*zoom_comparacion
		var dx := (1.0 if Input.is_key_pressed(KEY_D) else 0.0)-(1.0 if Input.is_key_pressed(KEY_A) else 0.0)
		var dy := (1.0 if Input.is_key_pressed(KEY_S) else 0.0)-(1.0 if Input.is_key_pressed(KEY_W) else 0.0)
		if not is_zero_approx(dx) or not is_zero_approx(dy):
			_panear_camara(Vector2(-dx,dy)*520.0*delta)
	camara.position = foco+Vector3(sin(angulo)*cos(elevacion),sin(elevacion),
		cos(angulo)*cos(elevacion))*20
	camara.look_at(foco)
	frames += 1
	if capturar and frames == 12:
		_capturar.call_deferred()
	return false


func _procesar_entrada(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and comparar.button_pressed and event.position.y > 115:
				if _seleccionar_en_pantalla(event.position):
					var punto = _punto_en_suelo(event.position)
					if punto != null:
						offset_arrastre = comparados[seleccionado].position-punto
						arrastrando = true
			elif not event.pressed:
				arrastrando = false
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if comparar.button_pressed:
				zoom_comparacion = maxf(.25,zoom_comparacion*.88)
			else:
				distancia = maxf(.5,distancia*.9)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if comparar.button_pressed:
				zoom_comparacion = minf(5.0,zoom_comparacion*1.14)
			else:
				distancia = minf(12,distancia*1.1)
	if event is InputEventMouseMotion:
		if arrastrando and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
			var punto = _punto_en_suelo(event.position)
			if punto != null:
				comparados[seleccionado].position = punto+offset_arrastre
				comparados[seleccionado].position.y = 0
				_actualizar_info_seleccion()
		elif event.button_mask&MOUSE_BUTTON_MASK_RIGHT:
			angulo -= event.relative.x*.01
			elevacion = clampf(elevacion+event.relative.y*.006,.12,1.45)
			girar.button_pressed = false
		elif comparar.button_pressed and event.button_mask&MOUSE_BUTTON_MASK_MIDDLE:
			_panear_camara(event.relative)
	if event is InputEventKey and event.pressed and not event.echo and comparar.button_pressed:
		match event.keycode:
			KEY_UP:
				_mover_seleccionado(Vector3(0,0,-.15))
			KEY_DOWN:
				_mover_seleccionado(Vector3(0,0,.15))
			KEY_LEFT:
				_mover_seleccionado(Vector3(-.15,0,0))
			KEY_RIGHT:
				_mover_seleccionado(Vector3(.15,0,0))
			KEY_Q:
				if seleccionado >= 0:
					comparados[seleccionado].rotation.y += PI/12
			KEY_E:
				if seleccionado >= 0:
					comparados[seleccionado].rotation.y -= PI/12
			KEY_F:
				_enfocar_seleccion()
			KEY_R:
				_ordenar_comparados()


func _probar_visor() -> void:
	var comprobaciones := 0
	var fallas := 0
	var esperados_monstruos := 0
	for clave in modelos.fichas:
		if modelos.es_monstruo(0x40000001,int(clave)):
			esperados_monstruos += 1
	var esperados := esperados_monstruos+1
	var condiciones := [
		comparados.size()==esperados,
		etiquetas.size()==esperados,
		ids_comparados.size()==esperados,
		esperados_monstruos==40,
		ids_comparados.has(ID_REFERENCIA_JUGADOR),
		selector.get_item_index(ID_REFERENCIA_JUGADOR) >= 0,
		_aabb_comparado(comparados[ids_comparados.find(ID_REFERENCIA_JUGADOR)]).size.y > .65,
		receptor_entrada.is_inside_tree(),
		receptor_entrada.destino.is_valid(),
	]
	for condicion in condiciones:
		comprobaciones += 1
		if not condicion:
			fallas += 1
	if not comparados.is_empty():
		var indice_jugador := ids_comparados.find(ID_REFERENCIA_JUGADOR)
		_seleccionar_indice(indice_jugador)
		comparar.button_pressed = false
		comprobaciones += 1
		if tipo == ID_REFERENCIA_JUGADOR or modelo.mesh == null:
			fallas += 1
		comparar.button_pressed = true
		comprobaciones += 1
		if tipo != ID_REFERENCIA_JUGADOR or seleccionado != indice_jugador:
			fallas += 1
		var posicion := comparados[0].position
		_mover_seleccionado(Vector3(.25,0,.5))
		comprobaciones += 1
		if comparados[0].position==posicion:
			fallas += 1
		_ordenar_comparados()
		comprobaciones += 1
		if comparados[0].position!=_posicion_ordenada(0,ceili(sqrt(float(comparados.size()))),
				ceili(float(comparados.size())/ceili(sqrt(float(comparados.size()))))):
			fallas += 1
		var zoom_antes := zoom_comparacion
		var rueda := InputEventMouseButton.new()
		rueda.button_index = MOUSE_BUTTON_WHEEL_UP
		rueda.pressed = true
		receptor_entrada._input(rueda)
		comprobaciones += 1
		if is_equal_approx(zoom_comparacion,zoom_antes):
			print("MONSTERS_VIEWER_FAIL: rueda no cambio zoom")
			fallas += 1
		var angulo_antes := angulo
		var orbita := InputEventMouseMotion.new()
		orbita.button_mask = MOUSE_BUTTON_MASK_RIGHT
		orbita.relative = Vector2(12,8)
		receptor_entrada._input(orbita)
		comprobaciones += 1
		if is_equal_approx(angulo,angulo_antes):
			print("MONSTERS_VIEWER_FAIL: arrastre derecho no cambio orbita")
			fallas += 1
		var foco := foco_comparacion
		var paneo := InputEventMouseMotion.new()
		paneo.button_mask = MOUSE_BUTTON_MASK_MIDDLE
		paneo.relative = Vector2(40,20)
		receptor_entrada._input(paneo)
		comprobaciones += 1
		if foco_comparacion==foco:
			print("MONSTERS_VIEWER_FAIL: arrastre central no cambio foco")
			fallas += 1
	print("MONSTERS_VIEWER: %d comprobaciones, %d fallas, %d modelos" % [
		comprobaciones,fallas,comparados.size()])
	quit(0 if fallas==0 else 1)


func _capturar() -> void:
	await RenderingServer.frame_post_draw
	var captura := root.get_texture().get_image()
	var err := captura.save_png(salida)
	print("MONSTERS_CAPTURE ", salida, " result=", err)
	quit(0 if err == OK else 1)
