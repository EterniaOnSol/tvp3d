extends Node3D

# =====================================================================
#  El mundo en 3D.
#
#  DE DONDE SALE CADA COSA
#
#      del disco    -> el decorado: pisos, paredes, arboles. Es el mapa
#                      entero de Tibia, leido del mismo .otbm del
#                      servidor (red/mapa_disco.gd).
#      del servidor -> las criaturas y lo que cambia en vivo, en las
#                      18x14 casillas que manda (red/estado_mundo.gd).
#
#  Hace falta el disco porque el servidor NO manda mas que esa ventana:
#  es el protocolo (protocolgame.cpp:1699). Sin esto el mundo se corta a
#  ocho casillas de distancia y parece una balsa flotando en el vacio.
#
#  COMO SE DIBUJA CADA COSA
#
#      suelo                     -> una losa acostada con su textura
#      pared (tapa y no deja ver)-> una CAJA de verdad, con la textura
#                                   del dibujo en los cuatro costados
#      montaña                   -> terreno elevado con pendientes de roca
#      borde de suelo/counters    -> una losa acostada sobre el SQM
#      prototipos 3D             -> cubos solidos para criaturas y objetos
#                                    que luego recibiran un modelo authored
#      lo demas                  -> una lamina parada que gira siguiendo
#                                    a la camara, la tecnica de Doom
#
#  Las cajas son las que hacen que el mundo se vea 3D de verdad: una
#  pared con volumen se ve como una pared desde cualquier angulo, y una
#  lamina no.
#
#  POR QUE MULTIMESH
#
#  A 36 casillas a la redonda hay del orden de 6.000 cosas dibujadas. Un
#  nodo por cada una arrastra el cuadro por los suelos. Se agrupan por
#  dibujo y forma, y cada grupo va en un MultiMesh: la placa lo dibuja de
#  una sola vez. Quedan ~300 nodos en vez de 6.000.
# =====================================================================

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const SPRITES := preload("res://red/sprites772.gd")
const DISCO := preload("res://red/mapa_disco.gd")
const CATALOGO := preload("res://red/mapa772.gd")
const IR_TROZOS := preload("res://red/ir_trozos.gd")
const COORD := preload("res://comun/coordenadas_tibia.gd")
const INTERFAZ := preload("res://ui/interfaz.gd")

const ARCHIVO_MAPPING := "res://assets/mappings/items.json"
const ARCHIVO_INDICE_IR := "res://generated/maps/rookgaard_100sqm_chunks/index.json"
const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
## En 7.72 la cuenta es un NUMERO (protocollogin.cpp:156).
const CUENTA := 123456
const CLAVE := "123456"

const LADO := COORD.SQM_WORLD_SIZE
const ALTO_PISO := COORD.FLOOR_WORLD_HEIGHT
## Alturas visuales de las construcciones. No se derivan del alto del sprite:
## el DAT describe una imagen 2D, no la altura fisica de una pared.
const ALTO_MUEBLE := ALTO_PISO * 0.42

## Cuantas casillas se ven a la redonda. Subirlo se ve mejor y cuesta
## caro: el area crece con el cuadrado.
const RADIO := 36
## Pisos de abajo que se muestran junto al piso jugable.
##
## La vista normal debe ser estricta: una pared o escalera de Z+1 tiene
## altura visual y puede invadir por completo el piso actual. El piso
## inferior queda disponible solo como ayuda de depuracion con F6.
var _pisos_abajo_visibles := 0
## Cuanto hay que caminar para rearmar el decorado. Rearmarlo en cada
## paso no se nota en pantalla y cuesta medio segundo.
## El decorado se mantiene mientras caminamos dentro del margen del radio.
## Reconstruir miles de instancias cada pocos pasos produce un tiron visible.
const PASOS_PARA_REARMAR := 12

## La ruta se busca solo dentro de una caja alrededor del origen y destino.
## Asi un clic sobre una zona cerrada no puede recorrer todo el mapa.
const MAX_CASILLAS_RUTA := 8192

## Los items animados (agua, fuego, antorchas) cambian de dibujo a este
## ritmo. Es el mismo del cliente original.
const FOTOGRAMAS_POR_SEGUNDO := 5.0

## Cada cuanto se puede mandar un paso (el servidor tiene su propio ritmo).
const ESPERA_ENTRE_PASOS := 0.25
const UMBRAL_ARRASTRE_MOUSE := 3.0
## Duracion visual base tomada de 3DTIBIA. La confirmacion de TVP sigue
## siendo la unica que cambia la posicion logica.
const DURACION_VISUAL_PASO := 0.26
const MULTIPLICADOR_DIAGONAL := 3.0
const ESCALA_JUGADOR := 0.5

## Controles heredados de 3DTIBIA: ocho direcciones y movimiento relativo
## a la orientacion de la camara.
const TECLAS_DIRECCION := [
	[Vector2i(-1, -1), [KEY_Q, KEY_KP_7]],
	[Vector2i(1, -1), [KEY_E, KEY_KP_9]],
	[Vector2i(-1, 1), [KEY_Z, KEY_KP_1]],
	[Vector2i(1, 1), [KEY_C, KEY_KP_3]],
	[Vector2i(0, -1), [KEY_W, KEY_UP, KEY_KP_8]],
	[Vector2i(0, 1), [KEY_S, KEY_DOWN, KEY_KP_2]],
	[Vector2i(-1, 0), [KEY_A, KEY_LEFT, KEY_KP_4]],
	[Vector2i(1, 0), [KEY_D, KEY_RIGHT, KEY_KP_6]],
]

const OCTANTES := [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

enum Forma { SUELO, ACOSTADA, CAJA, MUEBLE, LAMINA, PLACEHOLDER, MONTANA, PROTOTIPO }
enum OrientacionPared { EJE_X, EJE_Z, ESQUINA }

var _con
var _estado
var _disco
var _catalogo

var _piso_mundo: Node3D
var _piso_bichos: Node3D
var _jugador_nodo: Node3D
var _jugador_malla: MeshInstance3D
var _camara: Camera3D
var _cartel: Label
var _inspector_panel: PanelContainer
var _inspector_texto: Label

## Valores iniciales alineados con 3DTIBIA.
var _giro := 0.0
## Cuanto mira desde arriba. Con dibujos planos parados conviene una
## camara baja: desde muy arriba se ven de canto y parecen laminas.
var _inclinacion := deg_to_rad(32.0)
var _distancia := 14.0
var _arrastrando := false
var _arrastrando_objeto := false
var _arrastre_objeto_pendiente := false
var _inicio_mouse_arrastre := Vector2.ZERO
var _origen_objeto := Vector3i.ZERO
var _objeto_arrastre := {}
var _boton_izq := false
var _boton_der := false
var _giro_movido := false
var _consumido := false
var _camara_colocada := false
var _desde_ultimo_paso := 0.0
## Si el servidor ya dijo POR QUE nos echa, no lo tapamos con un
## "se corto la conexion" generico.
var _rechazados := false

var _sprites
var _malla_losa: PlaneMesh
var _mallas := {}
var _materiales := {}
var _mappings := {}
## Parametros editables durante la ejecucion. El modo de ajuste reconstruye
## solo la ventana visible para poder comparar sin reiniciar Godot.
var _alto_pared_visual := ALTO_PISO * 1.05
var _grosor_pared_visual := LADO * 0.20
var _ajuste_vivo := false
var _reloj_animacion := 0.0
var _animados: Array = []
var _desconocidos := 0
var _mapa_visible := {}
var _bloqueo_disco_cache := {}
var _ir_trozos
var _inspector_pos := Vector3i(-9999, -9999, -9999)
var _inspector_fijado := false
var _jugador_tipo := 128
var _jugador_direccion := 2
var _jugador_fase := -1
var _jugador_pos_confirmada := Vector3i(-9999, -9999, -9999)
var _jugador_origen := Vector3.ZERO
var _jugador_destino := Vector3.ZERO
var _jugador_t := 1.0
var _jugador_duracion := DURACION_VISUAL_PASO
var _jugador_moviendose := false
var _jugador_es_sprite := false

var _centro_escenario := Vector3i(-9999, -9999, -9999)
var _dibujadas := 0
var _solo_mirar := false


func _pedido_de_mirar():
	"""Devuelve el Vector3i de --mirar X,Y,Z, o null si no vino."""
	var args := OS.get_cmdline_user_args()
	var i := args.find("--mirar")
	if i < 0 or i + 1 >= args.size():
		return null
	var partes: PackedStringArray = args[i + 1].split(",")
	if partes.size() != 3:
		return null
	return Vector3i(int(partes[0]), int(partes[1]), int(partes[2]))


func _ready() -> void:
	_armar_escena()
	_ir_trozos = IR_TROZOS.new()
	if not _ir_trozos.abrir(ARCHIVO_INDICE_IR):
		print("Inspector: no se pudo abrir " + ARCHIVO_INDICE_IR)
	_disco.cargar_completo()
	if "--captura" in OS.get_cmdline_user_args():
		_sacar_foto.call_deferred()

	# Modo de solo mirar: dibuja el mapa del disco en el punto que se le
	# pida, sin servidor y sin personaje. Sirve para revisar como se ve
	# cualquier rincon del mundo sin tener que caminar hasta ahi.
	#     ... main.tscn -- --mirar 32097,32219,7
	var args := OS.get_cmdline_user_args()
	var i_lejos := args.find("--lejos")
	if i_lejos >= 0 and i_lejos + 1 < args.size():
		_distancia = float(args[i_lejos + 1])
	var i_alto := args.find("--alto")
	if i_alto >= 0 and i_alto + 1 < args.size():
		_inclinacion = float(args[i_alto + 1])

	var donde = _pedido_de_mirar()
	if donde != null:
		_solo_mirar = true
		_estado = ESTADO.new()
		_estado.adentro = true
		_estado.mi_pos = donde
		# El visor local tambien monta el HUD: permite revisar la lectura
		# visual de casas y la interfaz sin levantar el servidor.
		add_child(INTERFAZ.new(self, _estado, _sprites, _catalogo))
		_rearmar_escenario(donde)
		_avisar("Map viewer - (%d, %d, %d)" % [donde.x, donde.y, donde.z])
		return

	_estado = ESTADO.new()
	_estado.cambio.connect(_al_cambiar)
	_estado.paso_cancelado.connect(_al_paso_cancelado)
	# El servidor pregunta cada 5 segundos si seguimos vivos
	# (protocolgame.cpp:1628-1638). Hay que contestarle.
	_estado.pedido_ping.connect(func(): _con.enviar_juego(PackedByteArray([0x1E])))
	_estado.rechazados.connect(_al_ser_rechazados)
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(_al_fallar)
	_con.lista_personajes.connect(_al_recibir_personajes)
	_con.cerrada.connect(_al_cerrarse)
	add_child(INTERFAZ.new(self, _estado, _sprites, _catalogo))
	_avisar("Connecting...")
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


# --------------------------------------------------------------------
#  Armado de la escena
# --------------------------------------------------------------------
func _armar_escena() -> void:
	_sprites = SPRITES.new()
	_disco = DISCO.new()
	_catalogo = CATALOGO.new()
	_cargar_mappings()
	_malla_losa = PlaneMesh.new()
	_malla_losa.size = Vector2(LADO, LADO)

	_piso_mundo = Node3D.new()
	add_child(_piso_mundo)
	_piso_bichos = Node3D.new()
	add_child(_piso_bichos)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55, -40, 0)
	sol.light_energy = 1.1
	add_child(sol)

	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.47, 0.55)
	env.ambient_light_energy = 0.7
	# Una niebla del color del fondo para que el mundo se apague a lo
	# lejos en vez de cortarse de golpe en el borde de lo que cargamos.
	env.fog_enabled = true
	env.fog_light_color = env.background_color
	env.fog_density = 0.0
	env.fog_depth_begin = RADIO * 0.55
	env.fog_depth_end = RADIO * 1.0
	ambiente.environment = env
	add_child(ambiente)

	_camara = Camera3D.new()
	_camara.fov = 60.0
	_camara.far = 400.0
	add_child(_camara)

	var capa := CanvasLayer.new()
	add_child(capa)
	_cartel = Label.new()
	_cartel.position = Vector2(270, 12)
	_cartel.add_theme_font_size_override("font_size", 15)
	_cartel.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	_cartel.add_theme_color_override("font_outline_color", Color.BLACK)
	_cartel.add_theme_constant_override("outline_size", 5)
	capa.add_child(_cartel)
	_armar_inspector(capa)


func _armar_inspector(capa: CanvasLayer) -> void:
	_inspector_panel = PanelContainer.new()
	_inspector_panel.name = "InspectorCasilla"
	_inspector_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_inspector_panel.offset_left = -390.0
	_inspector_panel.offset_top = 342.0
	_inspector_panel.offset_right = -12.0
	_inspector_panel.offset_bottom = 650.0
	capa.add_child(_inspector_panel)
	# El inspector es una herramienta de depuracion, no parte del HUD
	# permanente. F4 lo muestra cuando el jugador lo necesita.
	_inspector_panel.visible = false

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 12)
	margen.add_theme_constant_override("margin_top", 10)
	margen.add_theme_constant_override("margin_right", 12)
	margen.add_theme_constant_override("margin_bottom", 10)
	_inspector_panel.add_child(margen)
	_inspector_texto = Label.new()
	_inspector_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_texto.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_inspector_texto.add_theme_font_size_override("font_size", 13)
	_inspector_texto.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	margen.add_child(_inspector_texto)
	_inspector_texto.text = "TILE INSPECTOR\nWaiting for the live map..."


func _cargar_mappings() -> void:
	var archivo := FileAccess.open(ARCHIVO_MAPPING, FileAccess.READ)
	if archivo == null:
		return
	var datos = JSON.parse_string(archivo.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY:
		return
	var items = datos.get("items", {})
	if typeof(items) == TYPE_DICTIONARY:
		_mappings = items


func _sacar_foto() -> void:
	"""Solo para revisar el resultado sin estar mirando la pantalla:
	espera a que llegue el mundo, guarda una imagen y cierra."""
	await get_tree().create_timer(10.0).timeout
	# frame_post_draw no siempre se emite en el renderer headless. Dos
	# frames de proceso bastan para que CanvasLayer y MultiMesh terminen de
	# colocarse, y permiten capturar tambien el visor sin servidor.
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var nombre := "captura.png"
	var args := OS.get_cmdline_user_args()
	if "--captura-tvp" in args:
		nombre = "captura_tvp.png"
	elif "--captura-region" in args:
		nombre = "captura_region_texturizada.png"
	img.save_png("res://" + nombre)
	print("captura guardada: %s" % nombre)
	print("  cosas dibujadas   : %d" % _dibujadas)
	print("  grupos (nodos)    : %d" % _piso_mundo.get_child_count())
	print("  trozos de mapa    : %d" % _disco.trozos_cargados())
	print("  criaturas         : %d" % _piso_bichos.get_child_count())
	print("  cuadros por segundo: %.0f" % Engine.get_frames_per_second())
	var centro := COORD.tibia_a_mundo(_estado.mi_pos, _centro_escenario, LADO, ALTO_PISO)
	print("  camara a %.1f casillas del centro, fov %.0f" % [
		_camara.position.distance_to(centro), _camara.fov])
	get_tree().quit(0)


func _avisar(texto: String) -> void:
	if _cartel:
		_cartel.text = texto


# --------------------------------------------------------------------
#  Conexion
# --------------------------------------------------------------------
func _al_recibir_personajes(_motd: String, personajes: Array) -> void:
	if personajes.is_empty():
		_avisar("This account has no characters.")
		return
	var p: Dictionary = personajes[0]
	_con.cerrar()
	_con.queue_free()
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(_al_fallar)
	_con.paquete_juego.connect(_al_recibir_paquete)
	_con.cerrada.connect(_al_cerrarse)
	_avisar("Entering the world as %s..." % p["nombre"])
	_con.entrar_al_mundo(p["ip"], p["puerto"], CUENTA, p["nombre"], CLAVE)


func _al_fallar(texto: String) -> void:
	_avisar(texto)


func _al_ser_rechazados(motivo: String) -> void:
	"""El servidor no nos dejo entrar y explico por que. Se muestra tal
	cual: es mucho mas util que un "se corto la conexion"."""
	_rechazados = true
	_avisar(motivo)
	print("El servidor no nos dejo entrar: %s" % motivo)


func _al_cerrarse() -> void:
	if _rechazados:
		return   # el motivo de verdad ya esta en pantalla
	if _estado.adentro:
		_avisar("Connection lost.")
	else:
		_avisar("The server closed the connection before we got in.\nIs it running? Start the server and try again.")


func _al_recibir_paquete(msg) -> void:
	_estado.procesar(msg)


func _al_paso_cancelado() -> void:
	_avisar("Blocked.")


# --------------------------------------------------------------------
#  Dibujo
# --------------------------------------------------------------------
func _al_cambiar() -> void:
	if not _estado.adentro:
		return
	var aqui: Vector3i = _estado.mi_pos
	if not _inspector_fijado:
		_inspector_pos = aqui
	var rearmado := false
	if (aqui.z != _centro_escenario.z
			or absi(aqui.x - _centro_escenario.x) >= PASOS_PARA_REARMAR
			or absi(aqui.y - _centro_escenario.y) >= PASOS_PARA_REARMAR):
		_rearmar_escenario(aqui)
		rearmado = true
	_actualizar_jugador_confirmado(aqui, rearmado)
	_dibujar_criaturas()
	_avisar("TVP3D   (%d, %d, %d)   %d things   %d creatures\nChunk %s   unmapped %d\nWASD/arrows/QE-ZC walk | left click auto-walk | right drag camera | wheel zoom" % [
		aqui.x, aqui.y, aqui.z, _dibujadas, _estado.criaturas.size(),
		str(COORD.chunk_de(aqui, 64)), _desconocidos])
	_actualizar_inspector()


func _crear_jugador_visual() -> void:
	if is_instance_valid(_jugador_nodo):
		return
	_jugador_nodo = Node3D.new()
	_jugador_nodo.name = "JugadorVisual"
	add_child(_jugador_nodo)
	_jugador_malla = MeshInstance3D.new()
	_jugador_malla.name = "Outfit"
	_jugador_nodo.add_child(_jugador_malla)

	var ficha: Dictionary = _estado.criaturas.get(_estado.mi_id, {})
	_jugador_tipo = int(ficha.get("apariencia", 128))
	_jugador_direccion = int(ficha.get("direccion", 2))
	_actualizar_sprite_jugador(0)

	if not _jugador_es_sprite:
		var cuerpo := CapsuleMesh.new()
		cuerpo.radius = LADO * 0.18
		cuerpo.height = LADO * 0.75
		_jugador_malla.mesh = cuerpo
		_jugador_malla.position.y = LADO * 0.45
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.78, 0.24, 0.18)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_jugador_malla.material_override = material


func _actualizar_sprite_jugador(fase: int) -> void:
	if not is_instance_valid(_jugador_malla):
		return
	var cuadro: Dictionary = _sprites.cuadro_outfit(
		_jugador_tipo, _jugador_direccion, fase)
	if cuadro.is_empty():
		_jugador_es_sprite = false
		return
	_jugador_es_sprite = true
	var alto: int = _sprites.alto_de_outfit(_jugador_tipo)
	var q := QuadMesh.new()
	q.size = Vector2(LADO, alto * LADO)
	_jugador_malla.mesh = q
	_jugador_malla.scale = Vector3.ONE * ESCALA_JUGADOR
	_jugador_malla.position = Vector3(
		0.0, alto * LADO * ESCALA_JUGADOR * 0.5 + 0.02, 0.0)
	_jugador_malla.material_override = _material_de_criatura(cuadro)


func _actualizar_jugador_confirmado(aqui: Vector3i, rearmado: bool) -> void:
	_crear_jugador_visual()
	var destino := COORD.tibia_a_mundo(aqui, _centro_escenario, LADO, ALTO_PISO)
	var primera_posicion := _jugador_pos_confirmada.x < -9000
	if primera_posicion or rearmado or aqui.z != _jugador_pos_confirmada.z:
		_jugador_nodo.position = destino
		_jugador_origen = destino
		_jugador_destino = destino
		_jugador_t = 1.0
		_jugador_moviendose = false
	else:
		var delta := aqui - _jugador_pos_confirmada
		if delta != Vector3i.ZERO:
			_jugador_origen = _jugador_nodo.position
			_jugador_destino = destino
			_jugador_t = 0.0
			_jugador_duracion = DURACION_VISUAL_PASO
			if delta.x != 0 and delta.y != 0:
				_jugador_duracion *= MULTIPLICADOR_DIAGONAL
			_jugador_direccion = _direccion_de_movimiento(delta)
			_jugador_fase = -1
			_jugador_moviendose = true
	_jugador_pos_confirmada = aqui


func _direccion_de_movimiento(delta: Vector3i) -> int:
	if absi(delta.x) > absi(delta.y):
		return 1 if delta.x > 0 else 3
	if delta.y != 0:
		return 2 if delta.y > 0 else 0
	return _jugador_direccion


func _animar_jugador(delta: float) -> void:
	if not is_instance_valid(_jugador_nodo):
		return
	# El frame idle permanece fijo mientras el personaje esta quieto. La
	# animacion de caminar solo corre durante una interpolacion de movimiento
	# confirmada por el servidor.
	if not _jugador_moviendose:
		if _jugador_es_sprite and _jugador_fase != 0:
			_jugador_fase = 0
			_actualizar_sprite_jugador(0)
		return
	if _jugador_moviendose:
		_jugador_t = minf(1.0, _jugador_t + delta / maxf(0.01, _jugador_duracion))
		var avance := _jugador_origen.lerp(_jugador_destino, _jugador_t)
		avance.y += sin(_jugador_t * PI) * 0.06
		_jugador_nodo.position = avance
		if _jugador_t >= 1.0:
			_jugador_nodo.position = _jugador_destino
			_jugador_moviendose = false
	if _jugador_es_sprite:
		var fase := int(_reloj_animacion * FOTOGRAMAS_POR_SEGUNDO)
		if fase != _jugador_fase:
			_jugador_fase = fase
			_actualizar_sprite_jugador(fase)


func _rearmar_escenario(centro: Vector3i) -> void:
	_centro_escenario = centro
	for hijo in _piso_mundo.get_children():
		hijo.queue_free()
	_animados.clear()
	_dibujadas = 0
	_desconocidos = 0

	var delo_disco: Dictionary = _disco.casillas_de(centro, RADIO)
	# La misma ventana sirve para dibujar y para buscar rutas. Consultar el
	# archivo del mapa por cada vecino del algoritmo era lo que congelaba el
	# hilo principal al hacer clic.
	_mapa_visible = delo_disco
	_bloqueo_disco_cache.clear()

	# Los grupos: una entrada por (dibujo, forma). Adentro se juntan las
	# posiciones y al final cada grupo se vuelca en un MultiMesh.
	var grupos := {}

	for donde in delo_disco:
		# El servidor manda varios pisos, pero la vista jugable dibuja solo
		# el propio por defecto. En Tibia, un Z mayor esta mas abajo y sus
		# paredes/escaleras pueden invadir visualmente el piso actual.
		if donde.z < centro.z or donde.z > centro.z + _pisos_abajo_visibles:
			continue
		# Si el servidor ya nos hablo de esta casilla, mandan sus datos:
		# son los de AHORA. El disco es de cuando se guardo el mapa.
		if _estado.casillas.has(donde):
			continue
		_juntar_casilla(grupos, donde, delo_disco[donde])

	for donde in _estado.casillas:
		if donde.z < centro.z or donde.z > centro.z + _pisos_abajo_visibles:
			continue
		if absi(donde.x - centro.x) > RADIO or absi(donde.y - centro.y) > RADIO:
			continue
		var ids := PackedInt32Array()
		for cosa in _estado.casillas[donde]:
			if cosa["tipo"] == "item":
				ids.append(cosa["cid"])
		_juntar_casilla(grupos, donde, ids)

	# El orden de insercion del mapa depende de los trozos que se cargaron.
	# Ordenar por capa hace reproducible la composicion de casas y muebles.
	var claves: Array = grupos.keys()
	claves.sort_custom(func(a, b):
		var ga: Dictionary = grupos[a]
		var gb: Dictionary = grupos[b]
		var capa_a := _capa_de_forma(int(ga["forma"]))
		var capa_b := _capa_de_forma(int(gb["forma"]))
		if capa_a != capa_b:
			return capa_a < capa_b
		return int(ga["cid"]) < int(gb["cid"])
	)
	for clave in claves:
		_volcar_grupo(clave, grupos[clave])


func _juntar_casilla(grupos: Dictionary, donde: Vector3i, ids) -> void:
	var apilado := 0
	for cid in ids:
		var info: Dictionary = _catalogo.info_item(cid)
		var forma: int = _forma_de_item(cid, info, donde.z)
		var orientacion := OrientacionPared.EJE_X
		if forma == Forma.CAJA:
			orientacion = _orientacion_de_pared(donde)
		elif forma == Forma.MONTANA:
			# El perfil depende de las cuatro casillas vecinas. Asi una
			# cordillera queda unida arriba y solo se inclinan sus bordes.
			orientacion = _perfil_de_montana(donde)
		var alto: int = _sprites.alto_en_casillas(cid)
		if forma == Forma.PLACEHOLDER:
			_desconocidos += 1
		var posicion_3d := COORD.tibia_a_mundo(donde, _centro_escenario, LADO, ALTO_PISO)
		var y := posicion_3d.y
		match forma:
			Forma.SUELO:
				pass
			Forma.ACOSTADA:
				# El dibujo representa una pieza que vive sobre el piso,
				# no una pared. El pequeno desnivel evita z-fighting con
				# la losa de ground y conserva el orden de la pila.
				y += 0.02 + apilado * 0.01
				apilado += 1
			Forma.CAJA:
				y += _alto_pared_visual * 0.5
			Forma.MONTANA:
				# La malla nace en el nivel del suelo y sube desde ahi.
				pass
			Forma.PROTOTIPO:
				# Los objetos pendientes de modelado son volumenes reales desde
				# el primer dia; el cubo se apoya en el SQM y no queda enterrado.
				y += _altura_prototipo(cid) * 0.5 + apilado * 0.01
				apilado += 1
			Forma.MUEBLE:
				y += ALTO_MUEBLE * 0.5 + apilado * 0.01
				apilado += 1
			Forma.LAMINA:
				y += alto * 0.5 + apilado * 0.01
				apilado += 1
		y += float(_mapping_de(cid).get("vertical_offset", 0.0))

		var clave := "%d_%d_%d" % [cid, forma, orientacion]
		var grupo = grupos.get(clave)
		if grupo == null:
			grupo = {"cid": cid, "forma": forma, "orientacion": orientacion, "donde": []}
			grupos[clave] = grupo
		grupo["donde"].append(Vector3(posicion_3d.x, y, posicion_3d.z))
		_dibujadas += 1


func _forma_de_item(cid: int, info: Dictionary, nivel: int = -1) -> int:
	if not _sprites.tiene_item(cid):
		return Forma.PLACEHOLDER
	var mapping := _mapping_de(cid)
	var primitiva := String(mapping.get("primitive", "auto"))
	if primitiva != "" and primitiva != "auto":
		return _forma_de_mapping(primitiva)
	if _es_acceso_de_piso(info):
		return Forma.ACOSTADA
	if _es_relleno_alcantarilla(cid, info, nivel):
		# Earth 101 es el suelo marron de relleno del tunel. Aunque el DAT
		# marque que bloquea la vista, no debe convertirse en una pared 3D.
		return Forma.SUELO
	if _es_terreno_elevado(cid, info, nivel):
		# "mountain" y los stone wall 373-384 de la alcantarilla traen
		# bloquea/frena_vista en el DAT, pero no son paredes de construccion.
		# Ambos usan terreno con pendiente; la alcantarilla cambia solo la
		# paleta a ladrillo.
		return Forma.MONTANA
	if _es_objeto_prototipo(info):
		# Estos objetos tendran modelos 3D authored. Mientras tanto usamos
		# un bloque con paleta por categoria para que su volumen y posicion
		# ya sean correctos en el mundo.
		return Forma.PROTOTIPO
	var nombre := String(info.get("nombre", "")).to_lower()
	if nombre.contains("campfire"):
		# El campfire bloquea el click/path en el DAT, pero visualmente es
		# una decoracion sobre el suelo, no una pared ni una plataforma.
		return Forma.LAMINA
	# En el catalogo 7.72 algunos muros de piedra/tierra pertenecen al
	# grupo de suelo y tambien traen suelo=true. La propiedad decisiva para
	# el renderer es que bloquean la vista: deben ganar a suelo y convertirse
	# en una pared con altura, no en una losa acostada.
	if info.get("bloquea", false) and info.get("frena_vista", false):
		return Forma.CAJA
	if info.get("suelo", false):
		return Forma.SUELO
	if _debe_ir_acostado(cid, info):
		return Forma.ACOSTADA
	# Una cosa que bloquea pero deja pasar la vista es un mueble: counter,
	# mesa, silla, reja baja o barril. Se renderiza como volumen bajo y no
	# como una postal vertical.
	return Forma.LAMINA


func _mapping_de(cid: int) -> Dictionary:
	var mapping = _mappings.get(str(cid), {})
	return mapping if typeof(mapping) == TYPE_DICTIONARY else {}


func _forma_de_mapping(primitiva: String) -> int:
	match primitiva:
		"flat":
			return Forma.ACOSTADA
		"wall":
			return Forma.CAJA
		"box":
			return Forma.MUEBLE
		"card":
			return Forma.LAMINA
		_:
			return Forma.LAMINA


func _es_acceso_de_piso(info: Dictionary) -> bool:
	var nombre := String(info.get("nombre", "")).to_lower()
	return nombre.contains("sewer") or nombre.contains("grate") \
		or nombre == "ladder" or nombre.contains("stairs") \
		or nombre.contains("stair") or nombre.contains("trapdoor") \
		or nombre.contains("hole") or nombre.contains("ramp")


func _es_montana(info: Dictionary) -> bool:
	var nombre := String(info.get("nombre", "")).to_lower()
	return nombre.contains("mountain") or nombre.contains("cliff")


func _es_terreno_alcantarilla(cid: int, info: Dictionary,
		nivel: int = -1) -> bool:
	# En el DAT 7.72 estos doce stone wall son tiles de relieve del tunel
	# (grupo suelo), no las paredes estructurales 1294+ de las casas.
	var nombre := String(info.get("nombre", "")).to_lower()
	var pared_de_tunel := nombre == "stone wall" \
		and int(info.get("grupo", 0)) == 1 \
		and cid >= 373 and cid <= 384 and nivel >= 8
	return pared_de_tunel


func _es_relleno_alcantarilla(cid: int, info: Dictionary,
		nivel: int = -1) -> bool:
	return String(info.get("nombre", "")).to_lower() == "earth" \
		and cid == 101 and int(info.get("grupo", 0)) == 1 and nivel >= 8


func _es_terreno_elevado(cid: int, info: Dictionary,
		nivel: int = -1) -> bool:
	return _es_montana(info) or _es_terreno_alcantarilla(cid, info, nivel)


func _debe_ir_acostado(cid: int, info: Dictionary) -> bool:
	# Los containers siguen siendo objetos volumetricos aunque su sprite
	# sea bajo. Esta excepcion coincide con la regla de 3DTIBIA.
	if info.get("contenedor", false):
		return false
	# Estas banderas vienen del perfil visual 7.4 y son la fuente de verdad
	# para bordes de pasto, caminos y otras piezas que viven en el suelo.
	if _catalogo.es_borde_suelo(cid) or _catalogo.va_abajo(cid):
		return true
	var nombre := String(info.get("nombre", "")).to_lower()
	# Counters, mesas, pisos y techos se pintan sobre el SQM. Su bloqueo
	# sigue viniendo del catalogo, pero su representacion es horizontal.
	return nombre == "counter" or nombre == "table" \
		or nombre.ends_with(" table") or nombre.ends_with(" floor") \
		or nombre.contains("roof")


func _es_objeto_prototipo(info: Dictionary) -> bool:
	"""Objetos del mapa que el usuario quiere convertir primero en cubos.

	La regla usa nombres semanticos del catalogo 7.72, no rangos de ids:
	asi cubre todas las variantes de un arbol o arbusto y tambien los items
	que el servidor agregue dentro de la misma familia.
	"""
	var nombre := String(info.get("nombre", "")).to_lower()
	return nombre.contains("tree") or nombre.contains("bush") \
		or nombre.contains("shrub") or nombre.contains("fir tree") \
		or nombre == "firtree" \
		or nombre.contains("blueberry") or nombre.contains("mailbox") \
		or nombre == "sign" or nombre.ends_with(" sign")


func _orientacion_de_pared(donde: Vector3i) -> int:
	# La orientacion se deriva del mapa visible, no del angulo de la camara.
	# X conecta paredes este/oeste; Z conecta paredes norte/sur.
	var conecta_x := _hay_pared_en(donde + Vector3i(-1, 0, 0)) \
		or _hay_pared_en(donde + Vector3i(1, 0, 0))
	var conecta_z := _hay_pared_en(donde + Vector3i(0, -1, 0)) \
		or _hay_pared_en(donde + Vector3i(0, 1, 0))
	if conecta_x and conecta_z:
		# No rellenar el SQM completo: ese bloque tapa patios y produce
		# manchas cuadradas. La pieza de esquina L se añadira cuando el
		# catalogo visual tenga perfiles por familia de pared.
		return OrientacionPared.EJE_X
	if conecta_z:
		return OrientacionPared.EJE_Z
	return OrientacionPared.EJE_X


func _perfil_de_montana(donde: Vector3i) -> int:
	# Bits: north=1, east=2, south=4, west=8. Se reutiliza el entero de
	# orientacion solo como clave de MultiMesh/malla; no es una direccion de
	# pared. El perfil permite que los tiles contiguos compartan la meseta.
	var perfil := 0
	if _hay_montana_en(donde + Vector3i(0, -1, 0)):
		perfil |= 1
	if _hay_montana_en(donde + Vector3i(1, 0, 0)):
		perfil |= 2
	if _hay_montana_en(donde + Vector3i(0, 1, 0)):
		perfil |= 4
	if _hay_montana_en(donde + Vector3i(-1, 0, 0)):
		perfil |= 8
	return perfil


func _hay_montana_en(donde: Vector3i) -> bool:
	for cid in _ids_de_casilla(donde):
		var item_cid := int(cid)
		if _es_terreno_elevado(item_cid, _catalogo.info_item(item_cid), donde.z):
			return true
	return false


func _hay_pared_en(donde: Vector3i) -> bool:
	for cid in _ids_de_casilla(donde):
		var info: Dictionary = _catalogo.info_item(int(cid))
		if _es_terreno_elevado(int(cid), info, donde.z):
			continue
		if info.get("bloquea", false) and info.get("frena_vista", false):
			return true
	return false


func _es_pieza_vertical(info: Dictionary) -> bool:
	var nombre := String(info.get("nombre", "")).to_lower()
	return nombre.contains("door") or nombre.contains("window") \
		or nombre.contains("archway") or nombre.contains("gate") \
		or nombre.contains("railing") or nombre.contains("bars") \
		or nombre.contains("fence")


func _capa_de_forma(forma: int) -> int:
	match forma:
		Forma.SUELO:
			return 0
		Forma.MONTANA:
			return 1
		Forma.ACOSTADA:
			return 2
		Forma.MUEBLE:
			return 3
		Forma.CAJA:
			return 4
		Forma.LAMINA:
			return 5
		_:
			return 6


func _volcar_grupo(clave: String, grupo: Dictionary) -> void:
	var cid: int = grupo["cid"]
	var forma: int = grupo["forma"]
	var orientacion: int = grupo.get("orientacion", OrientacionPared.EJE_X)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _malla_de(cid, forma, orientacion)
	var sitios: Array = grupo["donde"]
	mm.instance_count = sitios.size()
	for i in range(sitios.size()):
		mm.set_instance_transform(i, Transform3D(Basis(), sitios[i]))

	var nodo := MultiMeshInstance3D.new()
	nodo.multimesh = mm
	if forma == Forma.PLACEHOLDER:
		nodo.material_override = _material_placeholder()
	elif forma == Forma.MONTANA:
		nodo.material_override = _material_montana(cid)
	elif forma == Forma.PROTOTIPO:
		nodo.material_override = _material_prototipo(cid,
		_catalogo.info_item(cid))
	else:
		var cuadro: Dictionary = _sprites.cuadro_item(cid, 0)
		if cuadro.is_empty():
			return
		if forma == Forma.CAJA:
			_aplicar_materiales_estructura(mm.mesh, cuadro, forma,
				_catalogo.info_item(cid), cid)
		elif forma == Forma.MUEBLE:
			_aplicar_materiales_estructura(mm.mesh, cuadro, forma,
				_catalogo.info_item(cid))
		else:
			nodo.material_override = _material(cuadro, forma)
	_piso_mundo.add_child(nodo)

	if forma != Forma.PLACEHOLDER and forma != Forma.CAJA \
			and forma != Forma.MONTANA \
			and _sprites.fases_de_item(cid) > 1:
		_animados.append({"nodo": nodo, "cid": cid, "forma": forma})


func _altura_de(z: int) -> float:
	return COORD.tibia_a_mundo(Vector3i(0, 0, z), Vector3i(0, 0, 7), LADO, ALTO_PISO).y


func _malla_de(cid: int, forma: int, orientacion: int = OrientacionPared.EJE_X) -> Mesh:
	var ancho: int = _sprites.ancho_en_casillas(cid)
	var alto: int = _sprites.alto_en_casillas(cid)
	# Las cajas tienen materiales por item. No pueden compartir una malla cuyo
	# material de superficie se cambia al preparar el siguiente grupo.
	var clave := "%d_%d_%d_%d" % [forma, orientacion, ancho, alto]
	if forma == Forma.CAJA or forma == Forma.MUEBLE or forma == Forma.MONTANA:
		clave = "%d_%d_%d_%d_%d" % [cid, forma, orientacion, ancho, alto]
	if _mallas.has(clave):
		return _mallas[clave]

	var m: Mesh
	match forma:
		Forma.SUELO:
			m = _malla_losa
		Forma.ACOSTADA:
			var plano := PlaneMesh.new()
			# PlaneMesh yace sobre X/Z; el tamano sigue el footprint del
			# sprite para que un counter 2x1 no se vuelva 1x1.
			plano.size = Vector2(ancho * LADO, alto * LADO)
			m = plano
		Forma.CAJA:
			# La pared es un segmento delgado. Su direccion sale de las paredes
			# vecinas, asi varios SQM forman un perimetro continuo en vez de una
			# fila de cubos completos.
			var tamano := Vector3(LADO, _alto_pared_visual, _grosor_pared_visual)
			if orientacion == OrientacionPared.EJE_Z:
				tamano = Vector3(_grosor_pared_visual, _alto_pared_visual, LADO)
			elif orientacion == OrientacionPared.ESQUINA:
				tamano = Vector3(LADO, _alto_pared_visual, LADO)
			m = _malla_estructura(tamano, true, orientacion)
		Forma.MONTANA:
			m = _malla_montana(cid, orientacion)
		Forma.PROTOTIPO:
			m = BoxMesh.new()
			var lado := maxf(LADO * 0.62, ancho * LADO * 0.72)
			(m as BoxMesh).size = Vector3(lado, _altura_prototipo(cid), lado)
		Forma.MUEBLE:
			# El footprint sigue el sprite; la altura es de mueble, no de muro.
			m = _malla_estructura(Vector3(ancho * LADO, ALTO_MUEBLE, alto * LADO), false)
		Forma.PLACEHOLDER:
			var cubo := BoxMesh.new()
			cubo.size = Vector3(LADO * 0.8, LADO * 0.8, LADO * 0.8)
			m = cubo
		_:
			# 3DTIBIA usa un plano vertical por decoracion. La orientacion
			# hacia la camara la resuelve el material billboard; cruzar dos
			# planos duplicaba las formas y producia triangulos visibles.
			var plano := QuadMesh.new()
			plano.size = Vector2(ancho * LADO, alto * LADO)
			m = plano
	_mallas[clave] = m
	return m


func _altura_montana(cid: int) -> float:
	# Los primeros grupos del DAT son los bordes de roca que bloquean la
	# vista; los dos tiles de suelo son una transicion mas baja.
	if cid >= 373 and cid <= 384:
		return ALTO_PISO * 0.38
	if (cid >= 1081 and cid <= 1086) or (cid >= 1112 and cid <= 1122):
		return ALTO_PISO * 0.60
	if cid == 1127 or cid == 1128:
		return ALTO_PISO * 0.36
	return ALTO_PISO * 0.46


func _malla_montana(cid: int, perfil: int) -> ArrayMesh:
	"""Terreno rocoso elevado, no una caja vertical.

	Cada tile tiene una meseta y cuatro pendientes. Cuando hay otra montaña
	al lado, la meseta llega al borde para que ambas formen una superficie
	continua; donde no la hay, la pendiente baja hasta el terreno.
	"""
	var hx := LADO * 0.5
	var hz := LADO * 0.5
	var h := _altura_montana(cid)
	var inset := LADO * 0.30
	# Los tiles vecinos deben tocarse exactamente. Ese cero evita que el
	# macizo parezca una cuadrícula de plataformas separadas.
	var union_borde := 0.0
	var borde_n := union_borde if (perfil & 1) != 0 else inset
	var borde_e := union_borde if (perfil & 2) != 0 else inset
	var borde_s := union_borde if (perfil & 4) != 0 else inset
	var borde_w := union_borde if (perfil & 8) != 0 else inset

	var b_nw := Vector3(-hx, 0.0, -hz)
	var b_ne := Vector3(hx, 0.0, -hz)
	var b_se := Vector3(hx, 0.0, hz)
	var b_sw := Vector3(-hx, 0.0, hz)
	var t_nw := Vector3(-hx + borde_w, h, -hz + borde_n)
	var t_ne := Vector3(hx - borde_e, h, -hz + borde_n)
	var t_se := Vector3(hx - borde_e, h, hz - borde_s)
	var t_sw := Vector3(-hx + borde_w, h, hz - borde_s)

	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var colores := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var color_arriba := Color(0.38, 0.39, 0.37, 1.0)
	var color_roca := Color(0.24, 0.25, 0.25, 1.0)
	var color_roca_oscura := Color(0.18, 0.19, 0.20, 1.0)

	# La cara superior va primero para que el perfil se lea como suelo alto.
	_agregar_cara_montana(vertices, normales, colores, uvs, indices,
		[t_nw, t_sw, t_se, t_ne], Vector3.UP, color_arriba)
	if borde_n > union_borde:
		_agregar_cara_montana(vertices, normales, colores, uvs, indices,
			[b_nw, b_ne, t_ne, t_nw], Vector3(0, -0.65, -0.76).normalized(), color_roca_oscura)
	if borde_e > union_borde:
		_agregar_cara_montana(vertices, normales, colores, uvs, indices,
			[b_ne, b_se, t_se, t_ne], Vector3(0.76, -0.65, 0).normalized(), color_roca)
	if borde_s > union_borde:
		_agregar_cara_montana(vertices, normales, colores, uvs, indices,
			[b_se, b_sw, t_sw, t_se], Vector3(0, -0.65, 0.76).normalized(), color_roca)
	if borde_w > union_borde:
		_agregar_cara_montana(vertices, normales, colores, uvs, indices,
			[b_sw, b_nw, t_nw, t_sw], Vector3(-0.76, -0.65, 0).normalized(), color_roca_oscura)
	# La base evita transparencias si la camara llega a ver desde abajo.
	_agregar_cara_montana(vertices, normales, colores, uvs, indices,
		[b_sw, b_se, b_ne, b_nw], Vector3.DOWN, color_roca_oscura)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_COLOR] = colores
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _agregar_cara_montana(vertices: PackedVector3Array,
		normales: PackedVector3Array, colores: PackedColorArray,
		uvs: PackedVector2Array, indices: PackedInt32Array,
		cara: Array, normal: Vector3,
		color: Color) -> void:
	var base := vertices.size()
	var uv_cara := [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
	for i in range(cara.size()):
		var punto = cara[i]
		vertices.append(punto)
		normales.append(normal)
		colores.append(color)
		uvs.append(uv_cara[i])
	indices.append_array([base, base + 1, base + 2,
		base, base + 2, base + 3])


func _malla_estructura(tamano: Vector3, textura_vertical: bool,
		orientacion: int = OrientacionPared.EJE_X) -> ArrayMesh:
	"""Caja con dos superficies: sprite en la cara util y laterales limpios.

	Las paredes usan textura en sus cuatro caras verticales y un techo neutro;
	los muebles usan textura solo arriba y laterales neutros. Asi un sprite
	2D no se deforma sobre el techo y no genera picos alrededor de la casa.
	"""
	var hx := tamano.x * 0.5
	var hy := tamano.y * 0.5
	var hz := tamano.z * 0.5
	var p000 := Vector3(-hx, -hy, -hz)
	var p001 := Vector3(-hx, -hy, hz)
	var p010 := Vector3(-hx, hy, -hz)
	var p011 := Vector3(-hx, hy, hz)
	var p100 := Vector3(hx, -hy, -hz)
	var p101 := Vector3(hx, -hy, hz)
	var p110 := Vector3(hx, hy, -hz)
	var p111 := Vector3(hx, hy, hz)

	var caras_lisas: Array
	var caras_textura: Array
	if textura_vertical:
		# La textura del parche de pared solo va en las caras anchas y
		# verticales. Las tapas quedan limpias para que cada tramo se lea
		# como una construccion y no como un sprite estirado por encima.
		caras_lisas = [
			[Vector3.DOWN, p000, p100, p101, p001],
			[Vector3.UP, p010, p011, p111, p110],
		]
		if orientacion == OrientacionPared.EJE_Z:
			caras_lisas.append([Vector3(0, 0, 1), p001, p011, p111, p101])
			caras_lisas.append([Vector3(0, 0, -1), p100, p110, p010, p000])
			caras_textura = [
				[Vector3(1, 0, 0), p101, p100, p110, p111],
				[Vector3(-1, 0, 0), p000, p001, p011, p010],
			]
		elif orientacion == OrientacionPared.ESQUINA:
			caras_textura = [
				[Vector3(1, 0, 0), p101, p100, p110, p111],
				[Vector3(-1, 0, 0), p000, p001, p011, p010],
				[Vector3(0, 0, 1), p001, p101, p111, p011],
				[Vector3(0, 0, -1), p100, p000, p010, p110],
			]
		else:
			caras_lisas.append([Vector3(1, 0, 0), p101, p111, p110, p100])
			caras_lisas.append([Vector3(-1, 0, 0), p000, p010, p011, p001])
			caras_textura = [
				[Vector3(0, 0, 1), p001, p101, p111, p011],
				[Vector3(0, 0, -1), p100, p000, p010, p110],
			]
	else:
		caras_lisas = [
			[Vector3.DOWN, p000, p100, p101, p001],
			[Vector3(0, 0, 1), p001, p011, p111, p101],
			[Vector3(0, 0, -1), p100, p110, p010, p000],
			[Vector3(1, 0, 0), p101, p111, p110, p100],
			[Vector3(-1, 0, 0), p000, p010, p011, p001],
		]
		caras_textura = [[Vector3.UP, p010, p011, p111, p110]]

	var mesh := ArrayMesh.new()
	_agregar_superficie_caja(mesh, caras_lisas)
	_agregar_superficie_caja(mesh, caras_textura)
	return mesh


func _agregar_superficie_caja(mesh: ArrayMesh, caras: Array) -> void:
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var uv_cara := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for cara in caras:
		var base := vertices.size()
		var normal: Vector3 = cara[0]
		for i in range(4):
			vertices.append(cara[i + 1])
			normales.append(normal)
			uvs.append(uv_cara[i])
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _material_estructura(forma: int, info: Dictionary,
		cid: int = -1) -> StandardMaterial3D:
	if forma == Forma.CAJA and cid >= 0:
		var ruta_pared := "res://assets/paredes/pared_%05d.png" % cid
		if ResourceLoader.exists(ruta_pared):
			var pared := StandardMaterial3D.new()
			pared.albedo_texture = load(ruta_pared)
			pared.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			pared.texture_repeat = true
			pared.uv1_scale = Vector3(2.0, 6.0, 1.0)
			pared.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pared.cull_mode = BaseMaterial3D.CULL_DISABLED
			return pared
	var nombre := String(info.get("nombre", "")).to_lower()
	var paleta := "gris"
	if nombre.contains("wood") or nombre.contains("wooden") or nombre.contains("framework") \
		or nombre.contains("table") or nombre.contains("counter") or nombre.contains("ship cabin"):
		paleta = "madera"
	elif nombre.contains("grass") or nombre.contains("bamboo") or nombre.contains("dirt"):
		paleta = "pasto"
	elif nombre.contains("brick") or nombre.contains("red") or nombre.contains("oriental"):
		paleta = "ladrillo"
	elif nombre.contains("sandstone") or nombre.contains("sand"):
		paleta = "arena"
	elif nombre.contains("stone") or nombre.contains("rock"):
		paleta = "piedra"
	var clave := "__estructura_%d_%s" % [forma, paleta]
	if _materiales.has(clave):
		return _materiales[clave]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if paleta == "madera":
		mat.albedo_color = Color(0.27, 0.16, 0.09, 1.0)
	elif paleta == "pasto":
		mat.albedo_color = Color(0.22, 0.34, 0.12, 1.0)
	elif paleta == "ladrillo":
		mat.albedo_color = Color(0.38, 0.20, 0.14, 1.0)
	elif paleta == "arena":
		mat.albedo_color = Color(0.58, 0.46, 0.28, 1.0)
	elif paleta == "piedra":
		mat.albedo_color = Color(0.28, 0.29, 0.30, 1.0)
	else:
		mat.albedo_color = Color(0.34, 0.34, 0.32, 1.0)
	_materiales[clave] = mat
	return mat


func _aplicar_materiales_estructura(mesh: Mesh, cuadro: Dictionary,
		forma: int, info: Dictionary, cid: int = -1) -> void:
	var estructura := mesh as ArrayMesh
	if estructura == null or estructura.get_surface_count() < 2:
		return
	estructura.surface_set_material(0, _material_estructura(forma, info))
	if forma == Forma.CAJA:
		estructura.surface_set_material(1, _material_estructura(forma, info, cid))
	else:
		estructura.surface_set_material(1, _material(cuadro, forma))


func _material_montana(cid: int = -1) -> StandardMaterial3D:
	var textura := "01128"
	if cid >= 373 and cid <= 384:
		textura = "01270"
	var clave := "__terreno_montana_" + textura
	if _materiales.has(clave):
		return _materiales[clave]
	var mat := StandardMaterial3D.new()
	# La malla aporta colores distintos para la meseta y cada pendiente, y
	# la textura de roca del cliente conserva el detalle pixel-art de Tibia.
	# La textura original es muy oscura porque fue pintada para la
	# iluminacion 2D de Tibia; este realce evita que el terreno se vuelva
	# negro bajo la luz direccional del mundo 3D.
	mat.albedo_color = Color(1.35, 1.35, 1.35, 1.0)
	var ruta := "res://assets/paredes/pared_%s.png" % textura
	if ResourceLoader.exists(ruta):
		mat.albedo_texture = load(ruta)
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.texture_repeat = true
	mat.roughness = 0.96
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materiales[clave] = mat
	return mat


func _material_placeholder() -> StandardMaterial3D:
	var clave := "__unmapped_item__"
	if _materiales.has(clave):
		return _materiales[clave]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 1.0, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materiales[clave] = mat
	return mat


func _altura_prototipo(cid: int) -> float:
	var ancho: int = _sprites.ancho_en_casillas(cid)
	var alto: int = _sprites.alto_en_casillas(cid)
	# El DAT describe el dibujo, no una altura fisica exacta. Conservamos
	# proporciones utiles para distinguir un arbusto de un arbol sin crear
	# torres desproporcionadas.
	return clampf(maxf(0.55, alto * 0.34) * LADO,
		LADO * 0.55, ALTO_PISO * 2.6)


func _material_prototipo(cid: int, info: Dictionary) -> StandardMaterial3D:
	var nombre := String(info.get("nombre", "")).to_lower()
	var categoria := "nature"
	if nombre.contains("mailbox"):
		categoria = "mailbox"
	elif nombre == "sign" or nombre.ends_with(" sign"):
		categoria = "sign"
	elif nombre.contains("blueberry"):
		categoria = "blueberry"
	elif nombre.contains("tree") or nombre.contains("fir"):
		categoria = "tree"
	elif nombre.contains("bush") or nombre.contains("shrub"):
		categoria = "bush"
	var clave := "__prototipo_" + categoria
	if _materiales.has(clave):
		return _materiales[clave]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.88
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	match categoria:
		"tree":
			mat.albedo_color = Color(0.20, 0.39, 0.12, 1.0)
		"bush":
			mat.albedo_color = Color(0.28, 0.52, 0.14, 1.0)
		"blueberry":
			mat.albedo_color = Color(0.18, 0.30, 0.10, 1.0)
		"mailbox":
			mat.albedo_color = Color(0.19, 0.30, 0.48, 1.0)
		"sign":
			mat.albedo_color = Color(0.58, 0.36, 0.12, 1.0)
		_:
			mat.albedo_color = Color(0.35, 0.48, 0.16, 1.0)
	_materiales[clave] = mat
	return mat


func _malla_cruz(ancho: float, alto: float) -> ArrayMesh:
	"""Dos planos cruzados en angulo recto, con el mismo dibujo en los dos.

	Es la forma clasica de poner vegetacion en un juego 3D, y aca resuelve
	un problema concreto: dentro de un MultiMesh el modo billboard de
	Godot no orienta bien cada copia y los arbustos y las columnas quedan
	tirados de costado. Una cruz no depende de la camara — se ve con
	volumen desde cualquier angulo, sin tener que rehacer nada al girar."""
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var mx := ancho * 0.5
	var my := alto * 0.5

	for plano in range(2):
		var base := v.size()
		if plano == 0:
			v.append_array([
				Vector3(-mx, -my, 0), Vector3(mx, -my, 0),
				Vector3(mx, my, 0), Vector3(-mx, my, 0)])
		else:
			v.append_array([
				Vector3(0, -my, -mx), Vector3(0, -my, mx),
				Vector3(0, my, mx), Vector3(0, my, -mx)])
		uv.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malla


func _material(cuadro: Dictionary, forma: int) -> StandardMaterial3D:
	var clave: String = "%s_%d" % [cuadro["clave"], forma]
	if _materiales.has(clave):
		return _materiales[clave]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = cuadro["lamina"]
	# El recorte de la lamina se hace aca, no con AtlasTexture: en 3D el
	# material ignora la region del atlas y estira la lamina entera.
	mat.uv1_scale = cuadro["escala"]
	mat.uv1_offset = cuadro["corrimiento"]
	# Los dibujos de Tibia ya vienen con su propia sombra pintada: si
	# ademas se les aplica la luz de la escena, los colores dejan de ser
	# los de Tibia.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Nada de suavizado: es arte de pixeles, se tiene que ver cuadrado.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Sin repetir: si no, el borde de un dibujo se lleva el del vecino.
	mat.texture_repeat = false
	# Recorte en vez de mezcla: asi el fondo transparente no se lleva
	# puesto el orden de dibujado y no hay que ordenar nada a mano.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	if forma == Forma.LAMINA:
		# Cada instancia gira hacia la camara, como los decorados de 3DTIBIA.
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.billboard_keep_scale = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif forma == Forma.CAJA or forma == Forma.MUEBLE:
		# Las caras estructurales se generan por separado y deben verse desde
		# cualquier giro de camara, igual que en la vista de la casa.
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materiales[clave] = mat
	return mat


func _material_de_criatura(cuadro: Dictionary) -> StandardMaterial3D:
	"""Las criaturas si van con billboard: son pocas, van en nodos sueltos
	(no en MultiMesh, que es donde el billboard falla) y deben mirarte
	siempre de frente, como en Doom."""
	var clave: String = "%s_bicho" % cuadro["clave"]
	if _materiales.has(clave):
		return _materiales[clave]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = cuadro["lamina"]
	mat.uv1_scale = cuadro["escala"]
	mat.uv1_offset = cuadro["corrimiento"]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.texture_repeat = false
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materiales[clave] = mat
	return mat


func _dibujar_criaturas() -> void:
	for hijo in _piso_bichos.get_children():
		hijo.queue_free()
	for id in _estado.criaturas:
		# El jugador tiene una entidad visual propia para poder interpolar
		# entre confirmaciones del servidor sin duplicarlo como criatura.
		if int(id) == _estado.mi_id:
			continue
		var c: Dictionary = _estado.criaturas[id]
		# Las criaturas fuera de la ventana vertical tampoco se dibujan:
		# una criatura de Z+1 puede quedar flotando dentro del piso actual.
		if c["pos"].z < _estado.mi_pos.z \
			or c["pos"].z > _estado.mi_pos.z + _pisos_abajo_visibles:
			continue
		# Los monsters que vienen del spawn arrancan como cubos 3D. El estado
		# de criatura conserva outfit/direccion para que sustituir este bloque
		# por una escena de monster no requiera cambiar red ni gameplay.
		var tipo: int = c["apariencia"]
		var alto: float = clampf(_sprites.alto_de_outfit(tipo) * LADO * 0.72,
			LADO * 0.55, ALTO_PISO * 2.4)
		var cubo := BoxMesh.new()
		var lado := LADO * (0.62 if alto < ALTO_PISO * 1.2 else 0.78)
		cubo.size = Vector3(lado, alto, lado)
		var m := MeshInstance3D.new()
		m.mesh = cubo
		m.material_override = _material_cubo_criatura(c)
		m.set_meta("creature_id", int(id))
		m.set_meta("server_name", str(c.get("nombre", "Creature")))
		var p: Vector3i = c["pos"]
		var posicion_3d := COORD.tibia_a_mundo(p, _centro_escenario, LADO, ALTO_PISO)
		m.position = Vector3(posicion_3d.x, posicion_3d.y + alto * 0.5 + 0.02,
			posicion_3d.z)
		_piso_bichos.add_child(m)


func _material_cubo_criatura(c: Dictionary) -> StandardMaterial3D:
	var tipo := int(c.get("apariencia", 0))
	var clave := "__criatura_cubo_%d" % tipo
	if _materiales.has(clave):
		return _materiales[clave]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(fmod(float(tipo) * 0.137, 1.0), 0.64, 0.82)
	mat.roughness = 0.82
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materiales[clave] = mat
	return mat


func _animar() -> void:
	if _animados.is_empty():
		return
	var fase := int(_reloj_animacion * FOTOGRAMAS_POR_SEGUNDO)
	for a in _animados:
		var nodo: MultiMeshInstance3D = a["nodo"]
		if not is_instance_valid(nodo):
			continue
		var cuadro: Dictionary = _sprites.cuadro_item(a["cid"], fase)
		if not cuadro.is_empty():
			if a["forma"] == Forma.MUEBLE:
				_aplicar_materiales_estructura(nodo.multimesh.mesh, cuadro,
					a["forma"], _catalogo.info_item(a["cid"]))
			else:
				nodo.material_override = _material(cuadro, a["forma"])


func _mostrar_ajuste_vivo() -> void:
		_avisar("LIVE TUNING\nWall: height %.2f | thickness %.2f\nF8/F9 height -/+   F10/F11 thickness -/+   F12 reset   F7 exit" % [
		_alto_pared_visual, _grosor_pared_visual])


func _reconstruir_ajuste_vivo() -> void:
	if _centro_escenario.x < -9000 or _estado == null:
		return
	_mallas.clear()
	_rearmar_escenario(_centro_escenario)
	_mostrar_ajuste_vivo()


func _procesar_ajuste_vivo(evento: InputEventKey) -> bool:
	if not evento.pressed or evento.echo:
		return false
	if evento.keycode == KEY_F6:
		_pisos_abajo_visibles = 1 if _pisos_abajo_visibles == 0 else 0
		if _centro_escenario.x > -9000:
			_rearmar_escenario(_centro_escenario)
		_avisar("Lower floors: %s (F6 to toggle)" % (
			"visible" if _pisos_abajo_visibles else "hidden"))
		return true
	if evento.keycode == KEY_F7:
		_ajuste_vivo = not _ajuste_vivo
		if _ajuste_vivo:
			_mostrar_ajuste_vivo()
		else:
			_avisar("Live tuning disabled")
		return true
	if evento.keycode == KEY_F4:
		_inspector_panel.visible = not _inspector_panel.visible
		if _inspector_panel.visible:
			_actualizar_inspector()
		else:
			_avisar("Inspector hidden (F4 to show)")
		return true
	if not _ajuste_vivo:
		return false
	match evento.keycode:
		KEY_F8:
			_alto_pared_visual = maxf(0.35, _alto_pared_visual - 0.10)
		KEY_F9:
			_alto_pared_visual = minf(2.50, _alto_pared_visual + 0.10)
		KEY_F10:
			_grosor_pared_visual = maxf(0.05, _grosor_pared_visual - 0.05)
		KEY_F11:
			_grosor_pared_visual = minf(0.80, _grosor_pared_visual + 0.05)
		KEY_F12:
			_alto_pared_visual = ALTO_PISO * 1.05
			_grosor_pared_visual = LADO * 0.20
		_:
			return false
	_reconstruir_ajuste_vivo()
	return true


# --------------------------------------------------------------------
#  Camara y controles
# --------------------------------------------------------------------
func _process(delta: float) -> void:
	_desde_ultimo_paso += delta
	_reloj_animacion += delta
	_animar()
	_animar_jugador(delta)
	_mover_camara(delta)
	_leer_teclas()


func _mover_camara(delta: float) -> void:
	if not _estado.adentro:
		return   # todavia no sabemos donde estamos parados
	var centro: Vector3
	if is_instance_valid(_jugador_nodo):
		centro = _jugador_nodo.position
	else:
		centro = COORD.tibia_a_mundo(_estado.mi_pos, _centro_escenario, LADO, ALTO_PISO)
	centro.y += 0.5
	var lejos := Vector3(
		sin(_giro) * cos(_inclinacion),
		sin(_inclinacion),
		cos(_giro) * cos(_inclinacion)) * _distancia
	var destino := centro + lejos
	if not _camara_colocada:
		# La primera vez se pone en su lugar de una: si no, arranca en el
		# origen del mundo y viaja mil casillas cruzando todo el mapa.
		_camara.position = destino
		_camara_colocada = true
	else:
		_camara.position = _camara.position.lerp(destino, clampf(delta * 6.0, 0.0, 1.0))
	_camara.look_at(centro, Vector3.UP)


func _leer_teclas() -> void:
	if _solo_mirar or not _estado.adentro or _desde_ultimo_paso < ESPERA_ENTRE_PASOS:
		return
	# protocolgame.cpp:497-500 — norte, este, sur, oeste.
	if _con == null:
		return
	var direccion := _direccion_teclado()
	if direccion == Vector2i.ZERO:
		return
	var opcode := _opcode_de_direccion(direccion)
	if opcode == 0:
		return
	_con.enviar_juego(PackedByteArray([opcode]))
	_desde_ultimo_paso = 0.0


func _direccion_teclado() -> Vector2i:
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT):
		return Vector2i.ZERO
	for entrada in TECLAS_DIRECCION:
		for tecla in entrada[1]:
			if Input.is_key_pressed(tecla):
				return _direccion_girada(entrada[0], rad_to_deg(_giro))
	return Vector2i.ZERO


func _girar_en_sitio(tecla: int) -> bool:
	"""Ctrl+WASD cambia solo el facing del personaje.

	La direccion local se interpreta con la misma orientacion de camara que
	usa el movimiento normal, pero se reduce a los cuatro facings del outfit
	7.72. No se envia opcode: es un giro visual en la casilla actual.
	"""
	var local := Vector2i.ZERO
	match tecla:
		KEY_W:
			local = Vector2i(0, -1)
		KEY_A:
			local = Vector2i(-1, 0)
		KEY_S:
			local = Vector2i(0, 1)
		KEY_D:
			local = Vector2i(1, 0)
		_:
			return false
	var diagonal := _direccion_girada(local, rad_to_deg(_giro))
	var indice := OCTANTES.find(diagonal)
	if indice < 0:
		return false
	# El DAT 7.72 tiene cuatro filas: N, E, S, W. En los empates
	# diagonales gana el eje dominante, igual que al confirmar un paso.
	if indice == 1 or indice == 2:
		_jugador_direccion = 1
	elif indice == 3 or indice == 4:
		_jugador_direccion = 2
	elif indice == 5 or indice == 6:
		_jugador_direccion = 3
	else:
		_jugador_direccion = 0
	if is_instance_valid(_jugador_malla):
		_jugador_fase = 0
		_actualizar_sprite_jugador(0)
	return true


static func _direccion_girada(direccion: Vector2i, angulo_grados: float) -> Vector2i:
	if direccion == Vector2i.ZERO:
		return direccion
	var vector := Vector3(direccion.x, 0.0, direccion.y).rotated(
		Vector3.UP, deg_to_rad(angulo_grados))
	var angulo := atan2(vector.x, -vector.z)
	var octante := roundi(angulo / (PI / 4.0))
	return OCTANTES[posmod(octante, 8)]


func _opcode_de_direccion(direccion: Vector2i) -> int:
	if direccion == Vector2i(0, -1): return 0x65
	if direccion == Vector2i(1, 0): return 0x66
	if direccion == Vector2i(0, 1): return 0x67
	if direccion == Vector2i(-1, 0): return 0x68
	if direccion == Vector2i(1, -1): return 0x6A
	if direccion == Vector2i(1, 1): return 0x6B
	if direccion == Vector2i(-1, 1): return 0x6C
	if direccion == Vector2i(-1, -1): return 0x6D
	return 0


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey:
		if _procesar_ajuste_vivo(evento):
			return
		if evento.pressed and not evento.echo and evento.ctrl_pressed:
			if _girar_en_sitio(evento.keycode):
				get_viewport().set_input_as_handled()
			return
		if evento.pressed and evento.keycode == KEY_ESCAPE:
			get_tree().quit()
		return
	if evento is InputEventMouseButton:
		if evento.button_index == MOUSE_BUTTON_LEFT:
			if evento.pressed:
				_boton_izq = true
				if Input.is_key_pressed(KEY_SHIFT):
					_consumido = true
					var inspeccionado = _casilla_bajo_mouse(evento.position)
					if inspeccionado != null:
						_seleccionar_inspector(inspeccionado)
				elif _boton_der:
					# Los dos botones juntos hacen look, como en 3DTIBIA.
					_consumido = true
					_arrastrando = false
					_arrastrando_objeto = false
					_arrastre_objeto_pendiente = false
					_objeto_arrastre = {}
					_mirar_en_casilla(evento.position)
				else:
					_consumido = false
					_iniciar_arrastre_objeto(evento.position)
			else:
				_boton_izq = false
				if _arrastrando_objeto:
					_terminar_arrastre_objeto(evento.position)
				else:
					# Un clic sin movimiento sigue siendo un clic normal: caminar.
					# El objeto pendiente solo se convierte en drag al superar el
					# umbral de movimiento, igual que ZonaSuelo en 3DTIBIA.
					_arrastre_objeto_pendiente = false
					_objeto_arrastre = {}
					if not _consumido:
						_caminar_a_casilla(evento.position)
					else:
						_consumido = _boton_der
		elif evento.button_index == MOUSE_BUTTON_RIGHT:
			if evento.pressed:
				_boton_der = true
				if _boton_izq:
					# Derecho + izquierdo: look; no es cámara ni arrastre.
					_consumido = true
					_arrastrando = false
					_arrastrando_objeto = false
					_arrastre_objeto_pendiente = false
					_objeto_arrastre = {}
					_mirar_en_casilla(evento.position)
				else:
					# El derecho se resuelve al soltar: moverlo gira cámara,
					# soltarlo quieto usa el objeto bajo el cursor.
					_consumido = false
					_arrastrando = true
					_giro_movido = false
			else:
				_boton_der = false
				_arrastrando = false
				if not _giro_movido and not _consumido:
					_usar_en_casilla(evento.position)
				_consumido = _boton_izq
		elif evento.button_index == MOUSE_BUTTON_WHEEL_UP and evento.pressed:
			_distancia = maxf(4.0, _distancia - 1.5)
		elif evento.button_index == MOUSE_BUTTON_WHEEL_DOWN and evento.pressed:
			_distancia = minf(40.0, _distancia + 1.5)
	elif evento is InputEventMouseMotion:
		if _arrastrando:
			if evento.relative.length() > UMBRAL_ARRASTRE_MOUSE:
				_giro_movido = true
			_giro -= deg_to_rad(evento.relative.x * 0.4)
			_inclinacion = clampf(_inclinacion + deg_to_rad(evento.relative.y * 0.3), 0.10, 1.45)
		elif _arrastre_objeto_pendiente and _boton_izq:
			var desplazamiento: float = evento.position.distance_to(_inicio_mouse_arrastre)
			if desplazamiento > UMBRAL_ARRASTRE_MOUSE:
				_arrastrando_objeto = true
				_arrastre_objeto_pendiente = false
				_consumido = true


func _iniciar_arrastre_objeto(posicion_mouse: Vector2) -> void:
	"""Deja un objeto listo; el drag empieza solo al mover el mouse."""
	_arrastrando_objeto = false
	_arrastre_objeto_pendiente = false
	_objeto_arrastre = {}
	var posicion = _casilla_bajo_mouse(posicion_mouse)
	if posicion == null or posicion.z != _estado.mi_pos.z:
		return
	var encontrado := _objeto_movible_en_casilla(posicion)
	if encontrado.is_empty():
		return
	_arrastre_objeto_pendiente = true
	_inicio_mouse_arrastre = posicion_mouse
	_origen_objeto = posicion
	_objeto_arrastre = encontrado


func _terminar_arrastre_objeto(posicion_mouse: Vector2) -> void:
	var origen := _origen_objeto
	var objeto: Dictionary = _objeto_arrastre
	_arrastrando_objeto = false
	_arrastre_objeto_pendiente = false
	_objeto_arrastre = {}
	_consumido = true
	var destino = _casilla_bajo_mouse(posicion_mouse)
	if destino == null or destino.z != _estado.mi_pos.z:
		_avisar("You cannot throw there.")
		return
	if destino == origen:
		return
	var cosa: Dictionary = objeto.get("cosa", {})
	var cid := int(cosa.get("cid", 0))
	var pila := int(objeto.get("stackpos", -1))
	if cid <= 0 or pila < 0 or _con == null:
		return
	print("[tvp3d] arrastrando client=%d stack=%d desde %s hacia %s" % [
		cid, pila, origen, destino])
	_con.enviar_mover_cosa(origen, cid, pila, destino,
		int(cosa.get("cantidad", 1)))
	_avisar("Moving %s..." % str(cosa.get("nombre", "item")))


func soltar_inventario_en_mouse(posicion_mouse: Vector2, datos: Dictionary) -> void:
	"""Recibe un item de la interfaz y lo deja sobre el mundo."""
	if _con == null or not _estado.adentro:
		return
	var destino = _casilla_bajo_mouse(posicion_mouse)
	if destino == null or destino.z != _estado.mi_pos.z:
		_avisar("You cannot throw there.")
		return
	var cid := int(datos.get("cid", 0))
	var slot := int(datos.get("slot", -1))
	if cid <= 0 or slot < 0:
		return
	var tipo: String = str(datos.get("tipo", "inventario"))
	if tipo == "contenedor":
		var id_contenedor := int(datos.get("contenedor", -1))
		if id_contenedor < 0:
			return
		_con.enviar_mover_ubicacion(Vector3i(0xFFFF, id_contenedor, slot),
			cid, 0, destino, int(datos.get("cantidad", 1)))
	else:
		_con.enviar_mover_inventario(slot, cid, destino,
			int(datos.get("cantidad", 1)))
	_avisar("Moving %s..." % str(_estado.inventario.get(slot, {}).get("nombre", "item")))


func _objeto_movible_en_casilla(posicion: Vector3i) -> Dictionary:
	var cosas: Array = _estado.casillas.get(posicion, [])
	for indice in range(cosas.size() - 1, -1, -1):
		var cosa: Dictionary = cosas[indice]
		if cosa.get("tipo") != "item":
			continue
		var info: Dictionary = _catalogo.info_item(int(cosa.get("cid", 0)))
		if bool(cosa.get("movible", info.get("movible", false))):
			return {"cosa": cosa, "stackpos": indice}
	return {}


func _item_para_usar_en_casilla(posicion: Vector3i) -> Dictionary:
	var cosas: Array = _estado.casillas.get(posicion, [])
	for indice in range(cosas.size() - 1, -1, -1):
		var cosa: Dictionary = cosas[indice]
		if cosa.get("tipo") == "item":
			return {"cosa": cosa, "stackpos": indice}
	return {}


func _usar_en_casilla(posicion_mouse: Vector2) -> void:
	var posicion = _casilla_bajo_mouse(posicion_mouse)
	if posicion == null or posicion.z != _estado.mi_pos.z or _con == null:
		return
	var encontrado := _item_para_usar_en_casilla(posicion)
	if encontrado.is_empty():
		_avisar("There is nothing to use here.")
		return
	var cosa: Dictionary = encontrado["cosa"]
	var cid := int(cosa.get("cid", 0))
	var pila := int(encontrado["stackpos"])
	print("[tvp3d] usando client=%d stack=%d en %s" % [cid, pila, posicion])
	_con.enviar_usar_item(posicion, cid, pila, 0)
	_avisar("Using %s..." % str(cosa.get("nombre", "item")))


func _mirar_en_casilla(posicion_mouse: Vector2) -> void:
	var posicion = _casilla_bajo_mouse(posicion_mouse)
	if posicion == null:
		return
	_seleccionar_inspector(posicion)


func _caminar_a_casilla(posicion_mouse: Vector2) -> void:
	if _solo_mirar or _con == null or not _estado.adentro:
		return
	var objetivo = _casilla_bajo_mouse(posicion_mouse)
	if objetivo == null or objetivo.z != _estado.mi_pos.z:
		return
	_caminar_a_objetivo(objetivo)


func caminar_a_casilla_desde_minimapa(celda: Vector2i) -> void:
	"""Entrada publica para el map click del minimapa clasico."""
	if _solo_mirar or _con == null or not _estado.adentro:
		return
	_caminar_a_objetivo(Vector3i(celda.x, celda.y, _estado.mi_pos.z))


func _caminar_a_objetivo(objetivo: Vector3i) -> void:
	# Un map click expresa un destino, no una orden diagonal. El camino
	# ortogonal evita que el cliente envie diagonales que el jugador nunca
	# solicito; Q/E/Z/C y numpad conservan las diagonales explicitas.
	var camino := _buscar_ruta(_estado.mi_pos, objetivo, false)
	if camino.is_empty():
		_avisar("No path.")
		return
	_con.enviar_auto_camino(camino)
	_avisar("Walking to (%d, %d, %d)..." % [objetivo.x, objetivo.y, objetivo.z])


func _casilla_bajo_mouse(posicion_mouse: Vector2):
	if _camara == null or _centro_escenario.x < -9000 or not _estado.adentro:
		return null
	var origen := _camara.project_ray_origin(posicion_mouse)
	var direccion := _camara.project_ray_normal(posicion_mouse)
	var piso := COORD.tibia_a_mundo(Vector3i(_estado.mi_pos.x, _estado.mi_pos.y,
		_estado.mi_pos.z), _centro_escenario, LADO, ALTO_PISO).y
	if absf(direccion.y) < 0.0001:
		return null
	var distancia := (piso - origen.y) / direccion.y
	if distancia < 0.0:
		return null
	var punto := origen + direccion * distancia
	var tile := COORD.mundo_a_tibia(punto, _centro_escenario, LADO, ALTO_PISO)
	if absi(tile.x - _centro_escenario.x) > RADIO or absi(tile.y - _centro_escenario.y) > RADIO:
		return null
	return tile


func _seleccionar_inspector(posicion: Vector3i) -> void:
	_inspector_pos = posicion
	_inspector_fijado = true
	_actualizar_inspector()
	_avisar("Inspecting (%d, %d, %d) | Shift+click selects | F4 toggles" % [
		posicion.x, posicion.y, posicion.z])


func _actualizar_inspector() -> void:
	if _inspector_texto == null or _estado == null:
		return
	if _inspector_pos.x < -9000:
		_inspector_pos = _estado.mi_pos
	var posicion := _inspector_pos
	var vivo: Array = _estado.casillas.get(posicion, [])
	var ir_tile := _tile_ir(posicion)
	var fuente := "Live TVP (received window)" if _estado.casillas.has(posicion) else "Static IR / disk"
	var lineas := [
		"TILE INSPECTOR",
		"(%d, %d, %d)" % [posicion.x, posicion.y, posicion.z],
		"Source: %s" % fuente,
	]
	if _estado.casillas.has(posicion):
		lineas.append("Live items: %d" % _items_vivos(vivo))
	else:
		lineas.append("IR items: %d" % ir_tile.get("items", []).size())

	var ground: Dictionary = ir_tile.get("ground", {})
	if ground.is_empty():
		lineas.append("Ground IR: none")
	else:
		lineas.append("Ground IR: server %s / client %s" % [
			str(ground.get("server_id", "?")), str(ground.get("client_id", "?"))])
	lineas.append("walkable=%s  queryadd=%s  blocking=%s" % [
		str(ir_tile.get("walkable", "n/d")),
		str(ir_tile.get("queryadd_walkable", "n/d")),
		str(ir_tile.get("blocking", "n/d"))])
	lineas.append("")
	lineas.append("STACK")
	if _estado.casillas.has(posicion):
		var indice := 0
		for cosa in vivo:
			lineas.append(_texto_item_vivo(indice, cosa))
			indice += 1
	else:
		var indice_ir := 0
		for item in ir_tile.get("items", []):
			lineas.append(_texto_item_ir(indice_ir, item))
			indice_ir += 1
		if indice_ir == 0:
			lineas.append("(no IR data in the current window)")
	lineas.append("")
	lineas.append("Shift+click: pin tile | F4: show/hide")
	_inspector_texto.text = "\n".join(lineas)


func _tile_ir(posicion: Vector3i) -> Dictionary:
	if _ir_trozos == null:
		return {}
	var ventana: Dictionary = _ir_trozos.cargar_ventana(posicion, 0, posicion.z, posicion.z)
	return ventana.get(posicion, {})


func _items_vivos(cosas: Array) -> int:
	var cantidad := 0
	for cosa in cosas:
		if cosa.get("tipo") == "item":
			cantidad += 1
	return cantidad


func _texto_item_vivo(indice: int, cosa: Dictionary) -> String:
	if cosa.get("tipo") == "criatura":
		return "%d. criatura id=%s" % [indice, str(cosa.get("id", "?"))]
	var cid := int(cosa.get("cid", 0))
	var info: Dictionary = _catalogo.info_item(cid)
	return "%d. cli %d x%d %s | suelo=%s bloquea=%s path=%s" % [
		indice, cid, int(cosa.get("cantidad", 1)), str(info.get("nombre", "unknown")),
		str(info.get("suelo", false)), str(info.get("bloquea", false)),
		str(info.get("block_pathfind", false))]


func _texto_item_ir(indice: int, item: Dictionary) -> String:
	return "%d. srv %s / cli %s x%s %s" % [
		indice, str(item.get("server_id", "?")), str(item.get("client_id", "?")),
		str(item.get("count", 1)), str(item.get("name", "unknown"))]


func _ids_de_casilla(posicion: Vector3i) -> PackedInt32Array:
	if _estado.casillas.has(posicion):
		var ids := PackedInt32Array()
		for cosa in _estado.casillas[posicion]:
			if cosa.get("tipo") == "item":
				ids.append(int(cosa.get("cid", 0)))
		return ids
	return _mapa_visible.get(posicion, PackedInt32Array())


func _casilla_bloqueada(posicion: Vector3i) -> bool:
	# Las casillas que el servidor ya describio tienen prioridad: pueden
	# contener cambios en vivo y no deben quedar en la cache del mapa.
	if not _estado.casillas.has(posicion) and _bloqueo_disco_cache.has(posicion):
		return _bloqueo_disco_cache[posicion]
	var ids := _ids_de_casilla(posicion)
	var bloqueada := ids.is_empty()
	for cid in ids:
		if _catalogo.info_item(cid).get("bloquea", false):
			bloqueada = true
			break
	for id in _estado.criaturas:
		if _estado.criaturas[id].get("pos") == posicion:
			return true
	if not _estado.casillas.has(posicion):
		_bloqueo_disco_cache[posicion] = bloqueada
	return bloqueada


func _buscar_ruta(origen: Vector3i, destino: Vector3i,
		permitir_diagonales: bool = true) -> Array:
	if origen == destino:
		return []
	# BFS con indice de cabeza: no usa pop_at(0) ni busca el minimo en toda
	# la lista abierta. Para este movimiento de SQM, todos los pasos valen.
	var abiertos: Array = [origen]
	var cabeza := 0
	var anterior := {origen: origen}
	var margen := 12
	var min_x := mini(origen.x, destino.x) - margen
	var max_x := maxi(origen.x, destino.x) + margen
	var min_y := mini(origen.y, destino.y) - margen
	var max_y := maxi(origen.y, destino.y) + margen
	var vecinos := [Vector3i(0, -1, 0), Vector3i(0, 1, 0),
		Vector3i(-1, 0, 0), Vector3i(1, 0, 0)]
	if permitir_diagonales:
		vecinos = [
			Vector3i(-1, -1, 0), Vector3i(1, -1, 0),
			Vector3i(-1, 1, 0), Vector3i(1, 1, 0),
			Vector3i(0, -1, 0), Vector3i(0, 1, 0),
			Vector3i(-1, 0, 0), Vector3i(1, 0, 0),
		]
	while cabeza < abiertos.size() and anterior.size() <= MAX_CASILLAS_RUTA:
		var actual: Vector3i = abiertos[cabeza]
		cabeza += 1
		if actual == destino:
			var camino: Array = []
			var cursor := destino
			while cursor != origen:
				camino.push_front(Vector2i(cursor.x - anterior[cursor].x,
					cursor.y - anterior[cursor].y))
				cursor = anterior[cursor]
			return camino if camino.size() <= 128 else []
		for delta_sin_tipo in vecinos:
			var delta: Vector3i = delta_sin_tipo
			var siguiente: Vector3i = actual + delta
			if siguiente.z != origen.z or siguiente in anterior:
				continue
			if siguiente.x < min_x or siguiente.x > max_x or siguiente.y < min_y or siguiente.y > max_y:
				continue
			if _casilla_bloqueada(siguiente):
				continue
			anterior[siguiente] = actual
			abiertos.append(siguiente)
	return []
