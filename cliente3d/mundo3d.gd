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
const LOGIN := preload("res://ui/login.gd")
const MUERTE := preload("res://ui/muerte.gd")
const VENTANA_TEXTO := preload("res://ui/ventana_texto.gd")
const VOZ := preload("res://red/voz_proximidad.gd")
const GUION_MAGIC_WALL := preload("res://mundo/magic_wall_3d.gd")
const MODELO_OBJ := preload("res://mundo/modelo_obj.gd")
const GUION_NUMERO_DANO := preload("res://numero_dano_3d.gd")
const GUION_DIALOGO := preload("res://dialogo_3d.gd")

const ARCHIVO_MAPPING := "res://assets/mappings/items.json"
const ARCHIVO_INDICE_IR := "res://generated/maps/rookgaard_100sqm_chunks/index.json"
const ARCHIVO_CAMA := "res://assets/modelos/bed.obj"
const ARCHIVO_CAMA_PERSONA := "res://assets/modelos/bed-person.obj"
const ARCHIVO_TEXTURA_CAMA := "res://assets/modelos/bed-texture.png"
const ARCHIVO_TEXTURA_CAMA_PERSONA := "res://assets/modelos/bed-person-texture.png"
const ARCHIVO_LAMPARA := "res://assets/modelos/street-lamp.obj"
const ARCHIVO_TEXTURA_LAMPARA := "res://assets/modelos/street-lamp-texture.png"
const IDS_CAMA_PIE := [2488, 2494, 2496, 2498]
## Las piezas 4633-4644 son las transiciones de orilla que usa el mapa de
## Rookgaard. Su franja marron y su agua azul se conservan; las partes
## transparentes se rellenan con el mismo pasto 4515 del mapa para que no
## aparezca el fondo celeste.
const IDS_BORDES_AGUA := [4633, 4634, 4635, 4636, 4637, 4638, 4639,
	4640, 4641, 4642, 4643, 4644]
const ID_SPRITE_PASTO_BORDE := 4515
## El servidor traduce FLUID_BLOOD al color de liquido 2 antes de enviarlo.
## Este valor se usa solo para cambiar el aspecto del pool; los demas
## liquidos conservan su sprite y su material originales.
const COLOR_LIQUIDO_SANGRE := 2
## Estados visuales de la palanca 7.72. Son dos sprites existentes del
## cliente, no geometria nueva: el servidor transforma 1945 <-> 1946 y el
## traductor del mapa los entrega como 2772 <-> 2773.
const ESTADOS_PALANCA := {2772: 2773, 2773: 2772}
## El servidor 1497 llega por la red como el client id 2128. 2129 es la
## variante persistente; ambas comparten el muro animado de 3DTIBIA.
const IDS_MAGIC_WALL := [2128, 2129]
## Estas variantes de puerta tienen una condicion del mapa/servidor (llave,
## nivel, mision o sellado). No se les aplica el picking especial de la
## camara: conservan el flujo generico para no falsear sus parametros.
const IDS_PUERTAS_CON_PARAMETROS := [
	1628, 1631, 1642, 1644, 1646, 1647, 1648, 1649,
	1650, 1653, 1660, 1662, 1664, 1665, 1666, 1667,
	1668, 1671, 1674, 1676, 1678, 1679, 1680, 1681,
	1683, 1687, 1688, 1689, 1692, 1696, 1697, 1698,
	5006, 5007,
]
## Monedas que el servidor transforma al acuñar: oro -> platino -> cristal.
# El protocolo transporta client IDs, no los IDs internos del servidor.
const IDS_MONEDAS := [3031, 3035, 3043]
const ARCHIVO_CURSOR_USO := "res://assets/ui/cursor_uso.svg"
const HOST_LOCAL := "127.0.0.1"
const HOST_ENV := "TVP3D_HOST"
const PUERTO_LOGIN := 7171

const LADO := COORD.SQM_WORLD_SIZE
const ALTO_PISO := COORD.FLOOR_WORLD_HEIGHT
## Separacion vertical que usan las construcciones de los pisos superiores.
## El mapa logico sigue usando sus niveles normales; solo la arquitectura
## exterior se abre visualmente para que una casa tenga volumen real.
const ALTURA_PLANTA_VISUAL := ALTO_PISO * 2.0
## Las montanas ocupan todo el intervalo visual de un piso. La vista exterior
## tambien dibuja los niveles 0..6 sobre la superficie (z=7); si la meseta
## mide menos que esa separacion queda una franja de cielo y parece flotando.
## El lado exterior sigue siendo una pendiente, pero el volumen llega hasta
## la siguiente capa para que las montanas formen un relieve continuo.
const ALTURA_MONTANA_VISUAL := ALTURA_PLANTA_VISUAL
## Alturas visuales de las construcciones. No se derivan del alto del sprite:
## el DAT describe una imagen 2D, no la altura fisica de una pared.
const ALTO_MUEBLE := ALTO_PISO * 0.42
## Altura y espesor de los segmentos estructurales del pasamanos.
const ALTO_PASAMANOS := ALTO_PISO * 0.68
const GROSOR_PASAMANOS := LADO * 0.12
## Cuantas casillas se ven a la redonda. El mapa estatico cubre esta zona;
## los pisos superiores se filtran aparte para que puedan verse desde z=7.
const RADIO := 36
## Distancia usada para reconocer una sala/edificacion y para hacer el corte
## visual de sus muros cercanos cuando el jugador entra.
const RADIO_DETECCION_EDIFICIO := 12
const RADIO_CORTE_INTERIOR := 18
## Radio que se muestra primero cuando cambia el piso. El resto de la
## ventana se completa en segundo plano para que una escalera no deje al
## jugador esperando a que nazcan miles de instancias lejanas.
const RADIO_INMEDIATO := 16
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
## La palanca no tiene fases internas: 2772 y 2773 son sus dos dibujos de
## estado. Se muestran en una transicion corta al recibir el cambio real.
const DURACION_ANIMACION_PALANCA := 0.20

## Cada cuanto se puede mandar un paso (el servidor tiene su propio ritmo).
const ESPERA_ENTRE_PASOS := 0.25
const UMBRAL_ARRASTRE_MOUSE := 3.0
## Duracion visual base tomada de 3DTIBIA. La confirmacion de TVP sigue
## siendo la unica que cambia la posicion logica.
const DURACION_VISUAL_PASO := 0.26
const MULTIPLICADOR_DIAGONAL := 3.0
const ESCALA_JUGADOR := 0.5
## En el servidor los NPC usan el rango reservado 0x80000000+.
## No tienen que entrar al ciclo de ataque de los monsters.
const ID_MINIMO_NPC := 0x80000000
const RANGO_DIALOGO_NPC := 3
## La camara filtra posicion y objetivo con la misma señal. Mirar al nodo
## del jugador directamente hacia que el mundo tiemble al confirmar pasos.
const SUAVIDAD_CAMARA := 10.0
## El escenario se rearma fuera del hilo visual con un presupuesto pequeno
## por frame. El numero de casillas cambia mucho segun la zona; medir tiempo
## evita tanto la espera innecesaria como una tanda que congele la imagen.
const PRESUPUESTO_REARMADO_US := 4500

## Iluminacion visual. El servidor 7.72 no envia una hora de mundo, asi que
## mientras tanto la escena sigue el reloj local y aplica una transicion
## suave, pero muy visible, entre dia y noche.
const HORA_AMANECER := 6.0
const HORA_ATARDECER := 18.0
## La noche debe ser oscura, pero nunca una pantalla negra: el jugador debe
## distinguir suelo, agua y criaturas incluso en el visor sin servidor.
const BRILLO_NOCHE := 0.64
const BRILLO_DIA := 1.0

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

enum Forma { SUELO, ACOSTADA, CAJA, MUEBLE, PASAMANOS, LAMINA, PLACEHOLDER, MONTANA, PROTOTIPO }
enum OrientacionPared { EJE_X, EJE_Z, ESQUINA }

var _con
var _estado
var _disco
var _catalogo
var _interfaz
var _login
var _muerte
var _ventana_texto
var _voz
var _host_servidor := HOST_LOCAL
var _cuenta_login := 0
var _clave_login := ""
var _seleccion_automatica := false

var _piso_mundo: Node3D
var _piso_bichos: Node3D
var _indicador_objetivo: Node3D
var _material_objetivo: StandardMaterial3D
var _objetivo_visual_id := 0
var _tiempo_objetivo := 0.0
var _jugador_nodo: Node3D
var _jugador_malla: MeshInstance3D
var _jugador_visual: Node3D
var _jugador_cabeza: MeshInstance3D
var _jugador_nariz: MeshInstance3D
var _camara: Camera3D
var _sol: DirectionalLight3D
var _entorno: Environment
var _cartel: Label
var _capa_efectos: CanvasLayer
var _indicador_uso: Label
var _indicador_voz: Label
var _inspector_panel: PanelContainer
var _inspector_texto: Label

## Valores iniciales alineados con 3DTIBIA.
var _giro := 0.0
## Cuanto mira desde arriba. La arquitectura de los pisos superiores necesita
## una vista mas cenital para que los muros no ocupen toda la pantalla.
var _inclinacion := deg_to_rad(48.0)
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
var _criatura_clic_derecho := 0
var _consumido := false
var _camara_colocada := false
var _camara_foco := Vector3.ZERO
var _desde_ultimo_paso := 0.0
## Si el servidor ya dijo POR QUE nos echa, no lo tapamos con un
## "se corto la conexion" generico.
var _rechazados := false
## El servidor 7.72 cierra la conexion de login despues de entregar la lista.
## Ese cierre es normal y no debe reemplazar la lista por un mensaje de error.
var _lista_personajes_recibida := false
## Operacion de salida solicitada por el jugador: "personajes" vuelve a la
## lista de personajes y "login" vuelve al formulario de cuenta. La salida
## "muerte" no la pide el jugador: la dispara la muerte confirmada por el
## servidor y deja la pantalla de reentrada esperando su decision.
var _salida_pendiente := ""
## Muerte confirmada por `EstadoMundo.jugador_muerto`. Mientras esta puesto no
## sale ninguna intencion nueva del cliente. Esta rama no manda dialogo de
## muerte, asi que este es el unico estado de muerte que existe aca.
var _muerto := false
## Donde nos retiro el servidor al morir. Solo se guarda para el log.
var _pos_muerte := Vector3i.ZERO
## 0x64 es la descripcion completa que el servidor envia al entrar o al
## teletransportar. Se consume junto con `cambio`, antes de que el usuario
## pueda hacer otro map-click.
var _mapa_completo_pendiente := false

var _sprites
var _malla_losa: PlaneMesh
var _mallas := {}
var _mallas_cama := {}
var _malla_lampara: ArrayMesh
var _materiales := {}
var _mappings := {}
## Parametros editables durante la ejecucion. El modo de ajuste reconstruye
## solo la ventana visible para poder comparar sin reiniciar Godot.
## Las casas deben tener presencia junto al personaje authored de 3DTIBIA.
## Solo crece la geometria visual: la grilla, el bloqueo y la huella siguen
## siendo los mismos SQM del mapa.
## Una planta ocupa dos niveles visuales. Asi las casas y edificios ganan
## presencia vertical sin cambiar la grilla logica ni crear muros de varios
## pisos por cada planta.
var _alto_pared_visual := ALTURA_PLANTA_VISUAL
var _grosor_pared_visual := LADO * 0.28
var _ajuste_vivo := false
var _reloj_animacion := 0.0
var _tiempo_dia_noche := 0.0
var _animados: Array = []
var _animaciones_palanca: Array = []
var _animaciones_criaturas: Array = []
var _nodos_criaturas := {}
var _efectos_visuales: Array = []
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
var _npc_hablar_pendiente_id := 0
## Altura logica estable de la camara. No sigue el movimiento visual del
## sprite, porque eso haria que todo el mapa pareciera saltar.
var _jugador_y_estable := 0.0

var _centro_escenario := Vector3i(-9999, -9999, -9999)
var _dibujadas := 0
var _solo_mirar := false
var _rearmado_en_curso := false
var _centro_rearmado_pendiente := Vector3i(-9999, -9999, -9999)
var _destino_volcado: Node3D
var _animados_volcado: Array = []
var _animaciones_palanca_volcado: Array = []
var _construccion_activa := false
var _dibujadas_construccion := 0
var _desconocidos_construccion := 0
## Instancias base agrupadas por casilla. Permite ocultar solo el dibujo viejo
## cuando el servidor cambia un tile, sin reconstruir todo el mapa.
var _instancias_por_casilla := {}
var _instancias_en_construccion := {}
var _parches_casilla := {}
var _paredes_ocultas_interior := {}
var _monedas_por_casilla := {}
var _actualizando_casilla := false
var _ultimo_movimiento_acceso := {}
var _acceso_reintento_pos := Vector3i(-9999, -9999, -9999)
var _acceso_reintento_pendiente := false
var _ataque_pendiente_id := 0
## 0x78 se resuelve en la cola del servidor. Guardamos el siguiente paso
## localmente para que caminar no cancele un push o un drop todavía pendiente.
var _objeto_pendiente := {}
var _direccion_diferida := Vector2i.ZERO
var _objetivo_diferido := Vector3i(-9999, -9999, -9999)
## Runa o mana fluid seleccionada para la segunda mitad de un "Use With".
var _uso_con_pendiente := {}


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
	_host_servidor = _host_de_arranque()
	_voz = VOZ.new()
	add_child(_voz)
	_voz.estado_cambio.connect(_al_estado_voz)
	_voz.hablando_cambio.connect(_al_hablando_voz)
	_ir_trozos = IR_TROZOS.new()
	if not _ir_trozos.abrir(ARCHIVO_INDICE_IR):
		print("Inspector: no se pudo abrir " + ARCHIVO_INDICE_IR)
	# La precarga de los 576 trozos consume mas de 2 GB y no es necesaria para
	# jugar: el mapa_disco carga y libera los trozos segun la zona visible.
	# Se conserva como opt-in para herramientas que necesiten todo el mundo.
	if "--precargar-mapa" in OS.get_cmdline_user_args():
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
		_interfaz = INTERFAZ.new(self, _estado, _sprites, _catalogo)
		add_child(_interfaz)
		_rearmar_escenario(donde)
		_avisar("Map viewer - (%d, %d, %d)" % [donde.x, donde.y, donde.z])
		return

	_estado = ESTADO.new()
	_estado.cambio.connect(_al_cambiar)
	_estado.paso_cancelado.connect(_al_paso_cancelado)
	_estado.entramos.connect(_al_entramos)
	_estado.mapa_recibido.connect(_al_mapa_recibido)
	_estado.casilla_actualizada.connect(_al_casilla_actualizada)
	_estado.efecto_mapa.connect(_al_efecto_mapa)
	_estado.texto_animado.connect(_al_texto_animado)
	_estado.disparo_distancia.connect(_al_disparo_distancia)
	_estado.dialogo_recibido.connect(_al_dialogo_recibido)
	_estado.mensaje_pantalla.connect(_al_mensaje_pantalla)
	_estado.cuadrado_criatura.connect(_al_cuadrado_criatura)
	_estado.objetivo_cancelado.connect(_al_objetivo_cancelado)
	# Muerte: 0x6C de mi_id con vida autoritativa cero. No hay opcode propio.
	_estado.jugador_muerto.connect(_al_morir)
	# La ventana de texto la abre el servidor con el 0x96 al usar un cartel,
	# una carta o la etiqueta de una parcel.
	_estado.ventana_texto.connect(_al_ventana_texto)
	_estado.voz_recibida.connect(_voz.recibir_frame)
	# El servidor pregunta cada 5 segundos si seguimos vivos
	# (protocolgame.cpp:1628-1638). Hay que contestarle.
	_estado.pedido_ping.connect(func(): _con.enviar_juego(PackedByteArray([0x1E])))
	_estado.rechazados.connect(_al_ser_rechazados)
	_estado.mensaje_servidor.connect(_al_mensaje_servidor)
	_con = _nueva_conexion()
	add_child(_con)
	_voz.configurar_conexion(_con)
	_con.error_red.connect(_al_fallar)
	_con.lista_personajes.connect(_al_recibir_personajes)
	_con.cerrada.connect(_al_cerrarse)
	_interfaz = INTERFAZ.new(self, _estado, _sprites, _catalogo)
	_interfaz.visible = false
	add_child(_interfaz)
	_login = LOGIN.new()
	_login.solicito_login.connect(_solicitar_login)
	_login.solicito_personaje.connect(_seleccionar_personaje)
	add_child(_login)
	_muerte = MUERTE.new()
	_muerte.solicito_reentrada.connect(volver_desde_muerte)
	add_child(_muerte)
	_ventana_texto = VENTANA_TEXTO.new()
	_ventana_texto.escribio.connect(_al_escribir_texto)
	add_child(_ventana_texto)
	_login.mostrar_login()
	var credenciales := _credenciales_de_arranque()
	if not credenciales.is_empty():
		_seleccion_automatica = true
		_solicitar_login(int(credenciales["cuenta"]), str(credenciales["clave"]))
	else:
		_avisar("Log in to enter the world.")


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
	_armar_indicador_objetivo()

	_sol = DirectionalLight3D.new()
	_sol.rotation_degrees = Vector3(-55, -40, 0)
	add_child(_sol)

	var ambiente := WorldEnvironment.new()
	_entorno = Environment.new()
	_entorno.background_mode = Environment.BG_COLOR
	_entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Los sprites conservan sus materiales sin sombreado para no alterar sus
	# texturas. El ajuste de exposicion se aplica al frame completo y tambien
	# hace que dia/noche afecte a esos sprites.
	_entorno.adjustment_enabled = true
	# Una niebla del color del fondo para que el mundo se apague a lo
	# lejos en vez de cortarse de golpe en el borde de lo que cargamos.
	_entorno.fog_enabled = true
	_entorno.fog_depth_begin = RADIO * 0.55
	_entorno.fog_depth_end = RADIO * 1.0
	ambiente.environment = _entorno
	add_child(ambiente)
	_actualizar_dia_noche()

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
	_indicador_voz = Label.new()
	_indicador_voz.name = "IndicadorVoz"
	_indicador_voz.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_indicador_voz.offset_left = -330.0
	_indicador_voz.offset_top = 10.0
	_indicador_voz.offset_right = -14.0
	_indicador_voz.offset_bottom = 34.0
	_indicador_voz.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_indicador_voz.add_theme_font_size_override("font_size", 13)
	_indicador_voz.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	_indicador_voz.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.08))
	_indicador_voz.add_theme_constant_override("outline_size", 5)
	_indicador_voz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicador_voz.visible = false
	capa.add_child(_indicador_voz)
	_armar_inspector(capa)
	_capa_efectos = CanvasLayer.new()
	_capa_efectos.name = "EfectosCombate"
	_capa_efectos.layer = 20
	add_child(_capa_efectos)
	_indicador_uso = Label.new()
	_indicador_uso.name = "IndicadorUsoCon"
	_indicador_uso.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_indicador_uso.offset_top = 52.0
	_indicador_uso.offset_bottom = 82.0
	_indicador_uso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicador_uso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_indicador_uso.add_theme_font_size_override("font_size", 14)
	_indicador_uso.add_theme_color_override("font_color", Color(0.64, 1.0, 0.72))
	_indicador_uso.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.04))
	_indicador_uso.add_theme_constant_override("outline_size", 6)
	_indicador_uso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicador_uso.visible = false
	_capa_efectos.add_child(_indicador_uso)
	_actualizar_cursor_uso()


func _armar_indicador_objetivo() -> void:
	"""Cuadro rojo clasico de target, independiente del sprite de la criatura."""
	_indicador_objetivo = Node3D.new()
	_indicador_objetivo.name = "IndicadorObjetivo"
	_indicador_objetivo.visible = false
	add_child(_indicador_objetivo)

	_material_objetivo = StandardMaterial3D.new()
	_material_objetivo.albedo_color = Color(1.0, 0.06, 0.03, 0.92)
	_material_objetivo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_objetivo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_objetivo.no_depth_test = true
	_material_objetivo.cull_mode = BaseMaterial3D.CULL_DISABLED

	var segmentos := [
		{"tamano": Vector3(0.88, 0.045, 0.045), "posicion": Vector3(0, 0, -0.44)},
		{"tamano": Vector3(0.88, 0.045, 0.045), "posicion": Vector3(0, 0, 0.44)},
		{"tamano": Vector3(0.045, 0.045, 0.79), "posicion": Vector3(-0.44, 0, 0)},
		{"tamano": Vector3(0.045, 0.045, 0.79), "posicion": Vector3(0.44, 0, 0)},
	]
	for segmento in segmentos:
		var borde := MeshInstance3D.new()
		var malla := BoxMesh.new()
		malla.size = segmento["tamano"]
		borde.mesh = malla
		borde.position = segmento["posicion"]
		borde.material_override = _material_objetivo
		borde.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_indicador_objetivo.add_child(borde)


func fijar_objetivo_visual(id: int) -> void:
	if id <= 0:
		return
	_objetivo_visual_id = id
	_tiempo_objetivo = 0.0
	_actualizar_indicador_objetivo()


func limpiar_objetivo_visual() -> void:
	_objetivo_visual_id = 0
	if is_instance_valid(_indicador_objetivo):
		_indicador_objetivo.visible = false


func _al_objetivo_cancelado() -> void:
	limpiar_objetivo_visual()


func _actualizar_indicador_objetivo() -> void:
	if _indicador_objetivo == null or _estado == null \
			or _objetivo_visual_id == 0:
		return
	var criatura: Dictionary = _estado.criaturas.get(_objetivo_visual_id, {})
	if criatura.is_empty():
		limpiar_objetivo_visual()
		return
	var posicion: Vector3i = criatura.get("pos", Vector3i(-9999, -9999, -9999))
	if posicion.z != _estado.mi_pos.z \
			or absi(posicion.x - _estado.mi_pos.x) > RADIO \
			or absi(posicion.y - _estado.mi_pos.y) > RADIO:
		_indicador_objetivo.visible = false
		return
	var mundo := COORD.tibia_a_mundo(posicion, _centro_escenario,
		LADO, ALTO_PISO)
	_indicador_objetivo.position = mundo + Vector3(0.0, 0.07, 0.0)
	_indicador_objetivo.visible = true
	if _material_objetivo != null:
		var pulso := 0.62 + 0.30 * (0.5 + 0.5 * sin(_tiempo_objetivo * 8.0))
		_material_objetivo.albedo_color = Color(1.0, 0.06, 0.03, pulso)


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
func _credenciales_de_arranque() -> Dictionary:
	"""Permite pruebas automatizadas sin dejar una clave en el repositorio.

	En una partida normal las credenciales siempre vienen del formulario.
	Para una captura o QA se aceptan variables de entorno o argumentos de
	proceso, pero nunca se imprimen ni se guardan en disco.
	"""
	var cuenta_texto := OS.get_environment("TVP3D_ACCOUNT").strip_edges()
	var clave_texto := OS.get_environment("TVP3D_PASSWORD")
	var args := OS.get_cmdline_user_args()
	var i_cuenta := args.find("--cuenta")
	if i_cuenta >= 0 and i_cuenta + 1 < args.size():
		cuenta_texto = str(args[i_cuenta + 1]).strip_edges()
	var i_clave := args.find("--clave")
	if i_clave >= 0 and i_clave + 1 < args.size():
		clave_texto = str(args[i_clave + 1])
	if cuenta_texto.is_empty() or int(cuenta_texto) <= 0 or clave_texto.is_empty():
		return {}
	return {"cuenta": int(cuenta_texto), "clave": clave_texto}


func _host_de_arranque() -> String:
	"""El host se puede cambiar sin recompilar el cliente descargable.

	Orden: --host, variable TVP3D_HOST, archivo user://tvp3d_host.txt y
	finalmente localhost para conservar el modo de desarrollo actual.
	"""
	var host_configurado := OS.get_environment(HOST_ENV).strip_edges()
	var args := OS.get_cmdline_user_args()
	var indice_host := args.find("--host")
	if indice_host >= 0 and indice_host + 1 < args.size():
		host_configurado = str(args[indice_host + 1]).strip_edges()
	if not host_configurado.is_empty():
		return host_configurado
	var archivo := FileAccess.open("user://tvp3d_host.txt", FileAccess.READ)
	if archivo != null:
		var host_archivo := archivo.get_as_text().strip_edges()
		if not host_archivo.is_empty():
			return host_archivo
	return HOST_LOCAL


func _nueva_conexion():
	"""Punto unico donde nace la conexion 7.72.

	Existe para que una prueba headless pueda seguir el recorrido de muerte y
	reentrada sin abrir un socket real. El cliente normal siempre recibe el
	adaptador de verdad.
	"""
	return CONEXION.new()


func _solicitar_login(cuenta: int, clave: String) -> void:
	if cuenta <= 0 or clave.is_empty() or _estado.adentro:
		return
	_cuenta_login = cuenta
	_clave_login = clave
	_rechazados = false
	_lista_personajes_recibida = false
	_login.mostrar_estado("Connecting to account server...")
	if _con != null:
		_con.cerrar()
		_con.queue_free()
	_con = _nueva_conexion()
	add_child(_con)
	_voz.configurar_conexion(_con)
	_con.error_red.connect(_al_fallar)
	_con.lista_personajes.connect(_al_recibir_personajes)
	_con.cerrada.connect(_al_cerrarse)
	_con.pedir_personajes(_host_servidor, PUERTO_LOGIN, _cuenta_login, _clave_login)


func _al_recibir_personajes(motd: String, personajes: Array) -> void:
	_lista_personajes_recibida = true
	if personajes.is_empty():
		_login.mostrar_personajes(motd, personajes)
		_avisar("This account has no characters.")
		return
	_login.mostrar_personajes(motd, personajes)
	if not _seleccion_automatica:
		_avisar("Choose a character to enter the world.")
		return
	_seleccion_automatica = false
	_seleccionar_personaje(personajes[0])


func _pedir_lista_despues_de_logout() -> void:
	_lista_personajes_recibida = false
	_rechazados = false
	_con = _nueva_conexion()
	add_child(_con)
	_voz.configurar_conexion(_con)
	_con.error_red.connect(_al_fallar)
	_con.lista_personajes.connect(_al_recibir_personajes)
	_con.cerrada.connect(_al_cerrarse)
	_login.mostrar_estado("Loading characters...")
	_con.pedir_personajes(_host_servidor, PUERTO_LOGIN, _cuenta_login, _clave_login)


func _seleccionar_personaje(personaje: Dictionary) -> void:
	if _cuenta_login <= 0 or _clave_login.is_empty():
		return
	var p: Dictionary = personaje
	_lista_personajes_recibida = false
	if _con != null:
		_con.cerrar()
		_con.queue_free()
	_con = _nueva_conexion()
	add_child(_con)
	_voz.configurar_conexion(_con)
	_con.error_red.connect(_al_fallar)
	_con.paquete_juego.connect(_al_recibir_paquete)
	_con.cerrada.connect(_al_cerrarse)
	_login.mostrar_estado("Entering the world as %s..." % str(p.get("nombre", "Character")))
	_avisar("Entering the world as %s..." % p["nombre"])
	# El servidor 7.72 anuncia su IP configurada en la lista. Para una
	# instalacion casera suele ser 127.0.0.1; el host elegido por el jugador
	# es la autoridad para que el mismo cliente sirva en LAN o internet.
	_con.entrar_al_mundo(_host_servidor, p["puerto"], _cuenta_login,
		p["nombre"], _clave_login)


func _al_entramos() -> void:
	_salida_pendiente = ""
	_npc_hablar_pendiente_id = 0
	# Reentrar despues de morir devuelve el control: la muerte anterior no
	# puede seguir bloqueando la sesion nueva.
	_muerto = false
	if _muerte != null:
		_muerte.ocultar()
	if _login != null:
		_login.visible = false
	if _interfaz != null:
		_interfaz.visible = true
	if _con != null:
		# El cliente deja el modo ofensivo y el chase activos para que el
		# objetivo seleccionado por Battle dispare el ciclo de combate real.
		_con.enviar_modos_combate(1, 1, 1)
		if _con.has_method("enviar_pedir_canales"):
			_con.enviar_pedir_canales()
	if _voz != null:
		_voz.iniciar()
		_avisar("Connected. Select a creature in Battle, or click an NPC to talk.")


func solicitar_cambio_personaje() -> void:
	"""Ctrl+G: pide logout limpio y vuelve a la lista de personajes.

	La condicion de combate se lee del icono SWORDS que manda el servidor.
	La PZ y las zonas sin logout siguen siendo autoridad del servidor: dentro
	de PZ el 0x14 se acepta; si no corresponde, llega un cancel message.
	"""
	if _solo_mirar or _con == null or not _estado.adentro:
		return
	if _estado.en_combate:
		_avisar("You may not logout during or immediately after a fight!")
		return
	_iniciar_salida("personajes")


func solicitar_logout() -> void:
	"""Ctrl+Q/Ctrl+L: logout limpio y regreso al formulario de cuenta."""
	if _solo_mirar or _con == null or not _estado.adentro:
		return
	if _estado.en_combate:
		_avisar("You may not logout during or immediately after a fight!")
		return
	_iniciar_salida("login")


func _iniciar_salida(destino: String) -> void:
	if not _salida_pendiente.is_empty():
		return
	_salida_pendiente = destino
	_login.mostrar_estado("Logging out...")
	_login.visible = true
	_interfaz.visible = false
	_avisar("Logging out...")
	_con.enviar_logout()


func _al_ventana_texto(datos: Dictionary) -> void:
	"""El servidor abrio la ventana de texto de un item (0x96)."""
	if _ventana_texto != null:
		_ventana_texto.mostrar(datos)


func _al_escribir_texto(id_ventana: int, texto: String) -> void:
	"""El jugador acepto: se manda lo escrito y el servidor decide si vale."""
	if _con != null:
		_con.enviar_texto_ventana(id_ventana, texto)


func _al_morir(posicion: Vector3i) -> void:
	"""El servidor confirmo nuestra muerte y no hay dialogo que esperar.

	`EstadoMundo` emite esto solo cuando el `0x6C` retira a `mi_id` con la
	vida autoritativa en cero. Esta rama de TVP no tiene `sendDeath` ni
	`sendReLoginWindow`: `Creature::onDeath` deja el corpse, `Player::death`
	aplica las perdidas y `Game::removeCreature` nos saca de la casilla
	dejando la conexion abierta. Lo unico que corresponde hacer al cliente es
	dejar de pedir cosas, avisar y mandar el logout `0x14`, que
	`ProtocolGame::logout` (protocolgame.cpp:303-336) convierte en
	`disconnect()` porque el jugador ya fue removido.
	"""
	if _muerto:
		return   # una sola muerte por sesion, aunque llegue otro 0x6C
	_muerto = true
	_pos_muerte = posicion
	_salida_pendiente = "muerte"
	# Ninguna intencion a medio armar sobrevive a la muerte.
	_uso_con_pendiente.clear()
	_actualizar_cursor_uso()
	limpiar_objetivo_visual()
	_ataque_pendiente_id = 0
	_objeto_pendiente = {}
	_direccion_diferida = Vector2i.ZERO
	_objetivo_diferido = Vector3i(-9999, -9999, -9999)
	_acceso_reintento_pendiente = false
	_arrastrando_objeto = false
	_arrastre_objeto_pendiente = false
	_objeto_arrastre = {}
	if _interfaz != null:
		_interfaz.visible = false
	if _login != null:
		_login.visible = false
	if _muerte != null:
		_muerte.mostrar()
	_avisar("You are dead.")
	print("Muerte confirmada en (%d, %d, %d): se envia logout 0x14" % [
		posicion.x, posicion.y, posicion.z])
	if _con != null:
		_con.enviar_logout()


func volver_desde_muerte() -> void:
	"""El jugador acepto la muerte: se vuelve al selector de personajes."""
	if not _muerto:
		return
	_muerto = false
	_salida_pendiente = ""
	if _muerte != null:
		_muerte.ocultar()
	if _con != null:
		# Normalmente el servidor ya cerro al recibir el 0x14. Si todavia no
		# lo hizo, no dejamos una sesion colgada detras del selector.
		_con.cerrar()
		_con.queue_free()
		_con = null
	if _estado != null:
		_estado.reiniciar_sesion()
	if _interfaz != null:
		_interfaz.visible = false
	if _login != null:
		_login.visible = true
	if _cuenta_login <= 0 or _clave_login.is_empty():
		if _login != null:
			_login.mostrar_login()
		return
	_pedir_lista_despues_de_logout()


func esta_muerto() -> bool:
	return _muerto


func _al_mensaje_servidor(texto: String) -> void:
	# ProtocolGame usa el mismo 0xB4 para las respuestas de logout. Si el
	# servidor rechazo la solicitud, seguimos jugando con la misma conexion.
	# La muerte no se cancela: ya ocurrio en la autoridad del servidor.
	if _salida_pendiente != "muerte" and not _salida_pendiente.is_empty() \
			and texto.to_lower().contains("logout"):
		_salida_pendiente = ""
		_login.visible = false
		_interfaz.visible = true
		_avisar(texto)


func _actualizar_cursor_uso() -> void:
	"""Hace visible que una runa esta armada para el siguiente objetivo."""
	if _uso_con_pendiente.is_empty():
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		if _indicador_uso != null:
			_indicador_uso.visible = false
		return
	var cursor := load(ARCHIVO_CURSOR_USO) as Texture2D
	if cursor != null:
		Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, Vector2(4, 4))
	else:
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	if _indicador_uso != null:
		_indicador_uso.text = "USE WITH  •  %s  •  click target  •  Esc cancels" % \
			str(_uso_con_pendiente.get("nombre", "spell rune"))
		_indicador_uso.visible = true


func lanzar_hechizo(palabras: String) -> bool:
	"""Lanza las palabras exactas de un Spell definido por el servidor.

	La validacion de mana, nivel, vocacion, cooldown y efecto sigue en TVP
	7.72. El cliente solo envia el mismo texto que aceptaria el chat.
	"""
	if _solo_mirar or _con == null or not _estado.adentro:
		return false
	var limpio := palabras.strip_edges()
	if limpio.is_empty():
		return false
	_con.enviar_hablar(limpio)
	_avisar("Casting: " + limpio)
	return true


func _al_fallar(texto: String) -> void:
	if _estado != null and not _estado.adentro and _login != null:
		_login.mostrar_error(texto)
	_avisar(texto)


func _al_ser_rechazados(motivo: String) -> void:
	"""El servidor no nos dejo entrar y explico por que. Se muestra tal
	cual: es mucho mas util que un "se corto la conexion"."""
	_rechazados = true
	if _login != null:
		_login.mostrar_error(motivo)
	_avisar(motivo)
	print("El servidor no nos dejo entrar: %s" % motivo)


func _al_cerrarse() -> void:
	if _voz != null:
		_voz.detener()
	if _salida_pendiente == "muerte":
		# El servidor cerro despues del logout que mandamos al morir. La
		# pantalla de reentrada queda a la vista: volver al selector lo decide
		# el jugador, no el cierre del socket.
		_salida_pendiente = ""
		if _estado != null:
			_estado.reiniciar_sesion()
		if _con != null:
			_con.queue_free()
		_con = null
		if _interfaz != null:
			_interfaz.visible = false
		return
	if not _salida_pendiente.is_empty():
		var destino := _salida_pendiente
		_salida_pendiente = ""
		_estado.reiniciar_sesion()
		if _con != null:
			_con.queue_free()
		_con = null
		_uso_con_pendiente.clear()
		_actualizar_cursor_uso()
		_interfaz.visible = false
		_login.visible = true
		if destino == "personajes":
			_pedir_lista_despues_de_logout()
		else:
			_login.mostrar_login()
			_avisar("Logged out.")
		return
	if _rechazados:
		return   # el motivo de verdad ya esta en pantalla
	if _estado.adentro:
		# Una expulsión autoritativa (por ejemplo, al dormir en una cama) cierra
		# el socket sin enviar el flujo normal de logout. No dejamos el mundo
		# visible como si siguiera conectado: volvemos al selector y mostramos
		# una evidencia persistente en el chat.
		_estado.reiniciar_sesion()
		if _con != null:
			_con.queue_free()
		_con = null
		_uso_con_pendiente.clear()
		_actualizar_cursor_uso()
		_interfaz.visible = false
		_login.visible = true
		_login.mostrar_estado("Disconnected by server.")
		_avisar("Disconnected by server.")
		return
	if _lista_personajes_recibida:
		return   # el cierre del login despues de la lista es normal en 7.72
	if _login != null:
		_login.mostrar_error("The server closed the connection before we got in.")
		_avisar("The server closed the connection before we got in.\nIs it running?")
	else:
		_avisar("The server closed the connection before we got in.\nIs it running? Start the server and try again.")


func _al_recibir_paquete(msg) -> void:
	_estado.procesar(msg)


func _al_estado_voz(texto: String) -> void:
	if _indicador_voz == null:
		return
	_indicador_voz.text = texto
	_indicador_voz.visible = not texto.is_empty()


func _al_hablando_voz(activo: bool) -> void:
	if _indicador_voz == null or not activo:
		return
	_indicador_voz.text = "VOICE TALKING  |  release V"


func _al_efecto_mapa(posicion: Vector3i, tipo: int) -> void:
	if _capa_efectos == null or _camara == null \
			or _centro_escenario.x < -9000:
		return
	var cuadro: Dictionary = _sprites.cuadro_efecto(tipo, 0)
	if not cuadro.is_empty():
		var fases := maxi(1, _sprites.fases_de_efecto(tipo))
		var sprite := _crear_sprite_animado(cuadro, 64.0)
		_efectos_visuales.append({
			"tipo": "efecto",
			"nodo": sprite,
			"efecto": tipo,
			"posicion": posicion,
			"tiempo": 0.0,
			"duracion": maxf(0.30, float(fases) / FOTOGRAMAS_POR_SEGUNDO),
		})
		return
	# Si un servidor envia un ID que no existe en el DAT local, se mantiene
	# visible una marca discreta en vez de perder por completo el evento.
	var marca := Label.new()
	marca.text = "*"
	marca.add_theme_font_size_override("font_size", 30)
	marca.add_theme_color_override("font_color", _color_efecto(tipo))
	marca.add_theme_color_override("font_outline_color", Color.BLACK)
	marca.add_theme_constant_override("outline_size", 5)
	marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_efectos.add_child(marca)
	_efectos_visuales.append({
		"tipo": "marca",
		"nodo": marca,
		"posicion": posicion,
		"tiempo": 0.0,
		"duracion": 0.48,
	})


func _al_texto_animado(posicion: Vector3i, color: int, texto: String) -> void:
	if texto.strip_edges().is_empty() or _centro_escenario.x < -9000:
		return
	var donde := COORD.tibia_a_mundo(posicion, _centro_escenario,
		LADO, ALTO_PISO) + Vector3(0.0, 1.18, 0.0)
	GUION_NUMERO_DANO.crear(texto, donde, _color_texto_servidor(color, texto),
		self, 1.0)


func _color_texto_servidor(color: int, texto: String) -> Color:
	# TextColor_t de Tibia 7.72; el fallback mantiene legible cualquier color
	# que el servidor custom pueda enviar.
	match color:
		5:
			return Color(0.38, 0.67, 1.0)       # azul
		30:
			return Color(0.40, 1.0, 0.50)       # curacion
		35:
			return Color(0.44, 0.88, 1.0)
		108:
			return Color(0.62, 0.12, 0.10)
		129:
			return Color(0.80, 0.80, 0.82)
		180:
			return Color(1.0, 0.24, 0.18)       # dano
		198:
			return Color(1.0, 0.52, 0.18)
		210:
			return Color(1.0, 0.88, 0.28)
		215:
			return Color.WHITE
	return _color_texto_combate(texto)


func _al_dialogo_recibido(quien: String, texto: String,
		posicion: Vector3i, clase: int) -> void:
	if texto.strip_edges().is_empty() or _centro_escenario.x < -9000:
		return
	var donde_tibia := posicion
	if donde_tibia.x < -9000:
		for id in _estado.criaturas:
			var criatura: Dictionary = _estado.criaturas[id]
			if str(criatura.get("nombre", "")) == quien:
				donde_tibia = criatura.get("pos", donde_tibia)
				break
	if donde_tibia.x < -9000:
		return
	var donde := COORD.tibia_a_mundo(donde_tibia, _centro_escenario,
		LADO, ALTO_PISO) + Vector3(0.0, 1.56, 0.0)
	GUION_DIALOGO.crear(quien, texto, donde, _color_dialogo(clase), self)


func _color_dialogo(clase: int) -> Color:
	match clase:
		0x02:
			return Color(0.70, 0.88, 1.0)
		0x03, 0x10, 0x11:
			return Color(1.0, 0.54, 0.38)
		_:
			return Color(1.0, 0.92, 0.55)


func _al_mensaje_pantalla(texto: String, clase: int) -> void:
	if _capa_efectos == null or texto.strip_edges().is_empty():
		return
	var mensaje := Label.new()
	mensaje.text = texto
	mensaje.set_anchors_preset(Control.PRESET_TOP_WIDE)
	mensaje.offset_top = 88.0
	mensaje.offset_bottom = 122.0
	mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mensaje.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mensaje.add_theme_font_size_override("font_size", 18)
	mensaje.add_theme_color_override("font_color", _color_mensaje(clase))
	mensaje.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.96))
	mensaje.add_theme_constant_override("outline_size", 6)
	mensaje.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_efectos.add_child(mensaje)
	_efectos_visuales.append({
		"tipo": "mensaje_centro",
		"nodo": mensaje,
		"tiempo": 0.0,
		"duracion": 2.4,
	})


func _color_mensaje(clase: int) -> Color:
	match clase:
		0x12, 0x19:
			return Color(1.0, 0.30, 0.24)
		0x16:
			return Color(0.40, 1.0, 0.52)       # MESSAGE_INFO_DESCR: verde
		0x11:
			return Color(1.0, 0.60, 0.25)
		0x01, 0x04, 0x18:
			return Color(0.52, 0.78, 1.0)
		_:
			return Color(0.96, 0.96, 0.94)


func _al_cuadrado_criatura(id: int, color: int) -> void:
	var criatura: Dictionary = _estado.criaturas.get(id, {})
	var posicion: Vector3i = criatura.get("pos", Vector3i(-9999, -9999, -9999))
	if id == _estado.mi_id:
		posicion = _estado.mi_pos
	if posicion.x < -9000 or _centro_escenario.x < -9000:
		return
	var donde := COORD.tibia_a_mundo(posicion, _centro_escenario,
		LADO, ALTO_PISO) + Vector3(0.0, 1.22, 0.0)
	GUION_NUMERO_DANO.crear("!", donde, _color_texto_servidor(color, "!"),
		self, 0.48)


func _al_disparo_distancia(origen: Vector3i, destino: Vector3i, tipo: int) -> void:
	if _capa_efectos == null or _camara == null \
			or _centro_escenario.x < -9000:
		return
	var cuadro: Dictionary = _sprites.cuadro_proyectil(tipo, 0)
	if not cuadro.is_empty():
		var sprite := _crear_sprite_animado(cuadro, 42.0)
		_efectos_visuales.append({
			"tipo": "proyectil",
			"nodo": sprite,
			"proyectil": tipo,
			"origen": origen,
			"destino": destino,
			"tiempo": 0.0,
			"duracion": 0.22,
		})
		return
	var linea := Line2D.new()
	linea.width = 3.0
	linea.default_color = _color_efecto(tipo)
	linea.antialiased = false
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_efectos.add_child(linea)
	_efectos_visuales.append({
		"tipo": "disparo",
		"nodo": linea,
		"origen": origen,
		"destino": destino,
		"tiempo": 0.0,
		"duracion": 0.22,
	})


func _textura_de_cuadro(cuadro: Dictionary) -> Texture2D:
	if cuadro.is_empty() or not cuadro.has("lamina"):
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = cuadro["lamina"]
	var escala: Vector3 = cuadro.get("escala", Vector3.ONE)
	var corrimiento: Vector3 = cuadro.get("corrimiento", Vector3.ZERO)
	const LADO_LAMINA := 2048.0
	atlas.region = Rect2(corrimiento.x * LADO_LAMINA,
		corrimiento.y * LADO_LAMINA, escala.x * LADO_LAMINA,
		escala.y * LADO_LAMINA)
	return atlas


func _crear_sprite_animado(cuadro: Dictionary, tamano: float) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.texture = _textura_de_cuadro(cuadro)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.size = Vector2(tamano, tamano)
	sprite.custom_minimum_size = sprite.size
	sprite.pivot_offset = sprite.size * 0.5
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_efectos.add_child(sprite)
	return sprite


func _color_efecto(tipo: int) -> Color:
	var colores := [
		Color(1.0, 0.86, 0.30), Color(1.0, 0.35, 0.22),
		Color(0.35, 0.75, 1.0), Color(0.65, 0.35, 1.0),
		Color(0.35, 1.0, 0.45),
	]
	return colores[absi(tipo) % colores.size()]


func _color_texto_combate(texto: String) -> Color:
	if texto.begins_with("-"):
		return Color(1.0, 0.30, 0.22)
	if texto.is_valid_int():
		return Color(1.0, 0.88, 0.28)
	return Color(1.0, 1.0, 1.0)


func _al_paso_cancelado() -> void:
	_npc_hablar_pendiente_id = 0
	_avisar("Blocked.")


func detener_movimiento_para_uso() -> void:
	"""Corta el auto-walk al armar un objeto para usar con otro.

	El chat no llama a esta funcion: escribir permite que el auto-walk ya
	enviado termine. Para un objeto pendiente si detenemos el camino antes de
	seleccionar el objetivo, evitando que cambie la posicion entre ambos clics.
	0x69 es la orden oficial de detener solo ese camino.
	"""
	if _solo_mirar or _con == null or _estado == null or not _estado.adentro:
		return
	_uso_con_pendiente.clear()
	_actualizar_cursor_uso()
	_ataque_pendiente_id = 0
	_npc_hablar_pendiente_id = 0
	_direccion_diferida = Vector2i.ZERO
	_objetivo_diferido = Vector3i(-9999, -9999, -9999)
	_con.enviar_detener_auto_camino()


func preparar_uso_con(tipo: String, id_contenedor: int, slot: int,
		cosa: Dictionary) -> bool:
	"""Selecciona una runa o fluido para usarlo con un objetivo.

	El servidor 7.72 distingue 0x84 (Use With Creature) de 0x83 (Use With
	Item/tile). La primera mitad se guarda aqui; el destino se elige con el
	siguiente clic del jugador.
	"""
	if _solo_mirar or _con == null or _estado == null or not _estado.adentro:
		return false
	var cid := int(cosa.get("cid", 0))
	if cid <= 0 or slot < 0:
		return false
	if tipo == "contenedor" and id_contenedor < 0:
		return false
	detener_movimiento_para_uso()
	var origen := Vector3i(0xFFFF, slot, 0)
	if tipo == "contenedor":
		origen = Vector3i(0xFFFF, 0x40 | id_contenedor, slot)
	_uso_con_pendiente = {
		"origen": origen,
		"cid": cid,
		"nombre": str(cosa.get("nombre", "spell rune")),
		"es_fluido": bool(cosa.get("liquido", false)),
	}
	_actualizar_cursor_uso()
	var destino := "your character" \
		if bool(cosa.get("liquido", false)) \
		else "a creature or map tile"
	_avisar("Use with %s: click %s. Esc cancels." % [
		str(cosa.get("nombre", "spell rune")), destino])
	return true


func esta_esperando_uso_con() -> bool:
	return not _uso_con_pendiente.is_empty()


func cancelar_uso_con() -> void:
	if not _uso_con_pendiente.is_empty():
		_cancelar_accion()


func usar_con_criatura_pendiente(id: int) -> bool:
	if _uso_con_pendiente.is_empty() or _con == null or id <= 0:
		return false
	var criatura: Dictionary = _estado.criaturas.get(id, {})
	var es_fluido := bool(_uso_con_pendiente.get("es_fluido", false))
	if id == _estado.mi_id and es_fluido and criatura.is_empty():
		criatura = {"nombre": "your character"}
	if criatura.is_empty() or (id == _estado.mi_id and not es_fluido):
		return false
	var origen: Vector3i = _uso_con_pendiente.get("origen", Vector3i.ZERO)
	var cid := int(_uso_con_pendiente.get("cid", 0))
	var nombre := str(_uso_con_pendiente.get("nombre", "spell rune"))
	_con.enviar_usar_con_criatura(origen, cid, 0, id)
	_uso_con_pendiente.clear()
	_actualizar_cursor_uso()
	_avisar("Using %s with %s..." % [nombre, str(criatura.get("nombre", "creature"))])
	return true


func _usar_con_clic(posicion_mouse: Vector2) -> void:
	if _uso_con_pendiente.is_empty() or _con == null:
		return
	var posicion = _casilla_bajo_mouse(posicion_mouse)
	if posicion == null or posicion.z != _estado.mi_pos.z:
		_avisar("Choose a target inside the game map.")
		return
	# A mana fluid solo se puede beber sobre el personaje propio. El jugador
	# es un modelo 3D separado de estado.criaturas, por eso se detecta aqui
	# por su rectangulo proyectado antes de intentar el flujo generico.
	if bool(_uso_con_pendiente.get("es_fluido", false)):
		if _clic_sobre_jugador(posicion_mouse):
			if usar_con_criatura_pendiente(_estado.mi_id):
				return
		_avisar("Use the mana fluid on your character.")
		return
	var criatura_id := _criatura_bajo_mouse(posicion_mouse)
	if criatura_id == 0:
		criatura_id = _criatura_en_casilla(posicion)
	if criatura_id != 0 and usar_con_criatura_pendiente(criatura_id):
		return
	var destino := _item_para_usar_en_casilla(posicion)
	var destino_cid := 0
	var destino_pila := 0
	if not destino.is_empty():
		var cosa: Dictionary = destino.get("cosa", {})
		destino_cid = int(cosa.get("cid", 0))
		destino_pila = int(destino.get("stackpos", 0))
	var origen: Vector3i = _uso_con_pendiente.get("origen", Vector3i.ZERO)
	var cid := int(_uso_con_pendiente.get("cid", 0))
	var nombre := str(_uso_con_pendiente.get("nombre", "spell rune"))
	_con.enviar_usar_item_ex(origen, cid, 0, posicion, destino_cid, destino_pila)
	_uso_con_pendiente.clear()
	_actualizar_cursor_uso()
	_avisar("Using %s on (%d, %d, %d)..." % [
		nombre, posicion.x, posicion.y, posicion.z])


func _clic_sobre_jugador(posicion_mouse: Vector2) -> bool:
	"""Comprueba el cuerpo del modelo propio, no solo el suelo bajo el clic."""
	if _camara == null or not is_instance_valid(_jugador_nodo):
		return false
	var base_3d := _jugador_nodo.position + Vector3(0.0, 0.02, 0.0)
	var cabeza_3d := _jugador_nodo.position + Vector3(0.0,
		1.18 * ESCALA_JUGADOR, 0.0)
	var base := _camara.unproject_position(base_3d)
	var cabeza := _camara.unproject_position(cabeza_3d)
	var altura_pantalla := maxf(24.0, absf(base.y - cabeza.y))
	var ancho_pantalla := maxf(18.0, altura_pantalla * 0.40)
	return posicion_mouse.x >= base.x - ancho_pantalla \
		and posicion_mouse.x <= base.x + ancho_pantalla \
		and posicion_mouse.y >= minf(base.y, cabeza.y) - 8.0 \
		and posicion_mouse.y <= maxf(base.y, cabeza.y) + 8.0


# --------------------------------------------------------------------
#  Dibujo
# --------------------------------------------------------------------
func _al_cambiar() -> void:
	if not _estado.adentro:
		return
	_confirmar_objeto_pendiente()
	var aqui: Vector3i = _estado.mi_pos
	if not _inspector_fijado:
		_inspector_pos = aqui
	var rearmado := false
	var mapa_completo := _mapa_completo_pendiente
	_mapa_completo_pendiente = false
	if mapa_completo and _centro_escenario.x > -9000 \
			and (aqui.z != _centro_escenario.z
			or absi(aqui.x - _centro_escenario.x) >= PASOS_PARA_REARMAR
			or absi(aqui.y - _centro_escenario.y) >= PASOS_PARA_REARMAR):
		# Un teleport no es un paso normal: el origen del escenario cambia de
		# ciudad. Montamos el radio jugable ahora mismo para que teclado, mapa y
		# minimapa no queden apuntando a la zona anterior mientras se completa el
		# fondo.
		rearmado = _rearmar_escenario_teletransportado(aqui)
	elif (aqui.z != _centro_escenario.z
			or absi(aqui.x - _centro_escenario.x) >= PASOS_PARA_REARMAR
			or absi(aqui.y - _centro_escenario.y) >= PASOS_PARA_REARMAR):
		# Un salto grande puede venir de /gotohouse o de un comando de god sin
		# mapa completo. Dejar el ancla vieja durante la reconstruccion hace que
		# el clic se traduzca a las coordenadas de la ciudad anterior. En un
		# teletransporte la realineacion debe ser inmediata para que render e
		# interaccion compartan el mismo origen.
		rearmado = _rearmar_escenario_teletransportado(aqui)
	_actualizar_jugador_confirmado(aqui, rearmado)
	_intentar_ataque_pendiente()
	_intentar_hablar_npc_pendiente()
	_dibujar_criaturas()
	_actualizar_visibilidad_interior()
	_avisar("TVP3D   (%d, %d, %d)   %d things   %d creatures\nChunk %s   unmapped %d\nWASD/arrows/QE-ZC walk | left click auto-walk | right drag camera | wheel zoom" % [
		aqui.x, aqui.y, aqui.z, _dibujadas, _estado.criaturas.size(),
		str(COORD.chunk_de(aqui, 64)), _desconocidos])
	_actualizar_inspector()


func _al_mapa_recibido(_posicion: Vector3i) -> void:
	# El estado ya limpia y reemplaza la ventana antes de emitir esta señal.
	# Dejamos que `_al_cambiar` decida si es la entrada inicial o un teleport.
	_mapa_completo_pendiente = true


func _al_casilla_actualizada(posicion: Vector3i, _opcode: int) -> void:
	"""Refleja un cambio confirmado en un solo SQM.

	El servidor ya envio la casilla nueva cuando emite esta señal. El parche
	solo cambia la presentacion; no decide si el objeto pudo aparecer, moverse
	o transformarse.
	"""
	if not _estado.adentro or _centro_escenario.x < -9000:
		return
	if not _nivel_renderizable(posicion, _centro_escenario):
		return
	if absi(posicion.x - _centro_escenario.x) > RADIO \
			or absi(posicion.y - _centro_escenario.y) > RADIO:
		return
	_confirmar_objeto_pendiente(posicion)
	var monedas_anteriores: Array = _monedas_por_casilla.get(posicion, [])
	var monedas := _monedas_en_casilla(posicion)
	var moneda_animada: Dictionary = monedas[monedas.size() - 1] \
		if not monedas.is_empty() else (monedas_anteriores[monedas_anteriores.size() - 1] \
		if not monedas_anteriores.is_empty() else {})
	var moneda_cid := int(moneda_animada.get("cid", 0))
	if moneda_cid in IDS_MONEDAS:
		_mostrar_animacion_acunar(posicion, moneda_cid,
			int(moneda_animada.get("cantidad", 1)))
	_monedas_por_casilla[posicion] = monedas
	_actualizar_casilla_visual(posicion)
	_actualizar_visibilidad_interior()


func _monedas_en_casilla(posicion: Vector3i) -> Array:
	var monedas := []
	for cosa in _estado.casillas.get(posicion, []):
		if cosa.get("tipo") != "item":
			continue
		var cid := int(cosa.get("cid", 0))
		if cid in IDS_MONEDAS:
			monedas.append({"cid": cid,
				"cantidad": maxi(1, int(cosa.get("cantidad", 1)))})
	return monedas


func _mostrar_animacion_acunar(posicion: Vector3i, cid: int,
		cantidad: int = 1) -> void:
	if _capa_efectos == null or cid not in IDS_MONEDAS:
		return
	var brillo := Label.new()
	# La cantidad pertenece al item apilable que envio el servidor. Mostrarla
	# en el destello hace visible el cambio 1 -> 2 -> 3..., no solo el mismo
	# sprite de moneda acompanado de un brillo generico.
	brillo.text = str(maxi(1, cantidad))
	brillo.add_theme_font_size_override("font_size", 20)
	brillo.add_theme_color_override("font_color", _color_moneda(cid))
	brillo.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.01, 0.96))
	brillo.add_theme_constant_override("outline_size", 5)
	brillo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_efectos.add_child(brillo)
	_efectos_visuales.append({
		"tipo": "acuñar",
		"nodo": brillo,
		"posicion": posicion,
		"tiempo": 0.0,
		"duracion": 0.52,
	})


func _color_moneda(cid: int) -> Color:
	match cid:
		3031:
			return Color(1.0, 0.86, 0.22)       # gold
		3035:
			return Color(0.78, 0.86, 0.94)      # platinum
		3043:
			return Color(0.48, 0.96, 1.0)       # crystal
	return Color(1.0, 0.86, 0.22)


func _elementos_de_casilla(posicion: Vector3i) -> Array:
	"""Devuelve los items vivos sin perder datos del protocolo.

	El mapa estatico usa solo client IDs, pero el servidor agrega datos como el
	color de un liquido. Mantener los diccionarios hasta `_juntar_casilla`
	permite pintar un pool de sangre distinto de uno de agua aunque compartan
	el mismo sprite.
	"""
	var elementos: Array = []
	for cosa in _estado.casillas.get(posicion, []):
		if cosa.get("tipo") == "item":
			elementos.append(cosa)
	return elementos


func _nivel_renderizable(donde: Vector3i, centro: Vector3i) -> bool:
	if donde.z > centro.z:
		# Desde un piso alto se conserva la silueta vertical hasta la planta
		# baja (z=7), pero no se dibuja el contenido de esos pisos. Los niveles
		# subterraneos (z>7) nunca entran en la vista exterior.
		return centro.z < 7 and donde.z <= 7
	if donde.z < centro.z:
		# Desde z=7 se deben ver todos los niveles superiores, incluido z=0.
		# El recorte anterior empezaba en z=1 y hacia desaparecer el nivel mas
		# alto de las piramides y de algunos edificios de Ankrahmun.
		return centro.z <= 7 and donde.z >= 0
	return true


func _es_nivel_superior(donde: Vector3i, centro: Vector3i) -> bool:
	return donde.z < centro.z and centro.z <= 7


func _filtrar_construccion_superior(elementos) -> Array:
	"""Conserva la silueta de una casa de arriba sin duplicar su decoracion.

	Los pisos superiores se muestran como arquitectura: muros, pisos, techos,
	puertas, ventanas, escaleras y pasamanos. Criaturas, muebles, plantas y
	otros objetos quedan en su nivel real y no tapan el piso donde jugamos.
	"""
	var salida: Array = []
	for elemento in elementos:
		var cid := _cid_de_elemento(elemento)
		var info: Dictionary = _catalogo.info_item(cid)
		var nombre := String(info.get("nombre", "")).to_lower()
		var es_estructura := _es_puerta(info) or _es_pasamanos(info) \
				or nombre.contains("wall") \
				or nombre.contains("floor") \
				or nombre.contains("roof") \
				or nombre.contains("stair") \
				or nombre.contains("trapdoor") \
				or nombre.contains("window") \
				or nombre.contains("archway") \
				or nombre.contains("gate") \
				or nombre.contains("pillar") \
				or nombre.contains("column") \
				or (bool(info.get("bloquea", false)) \
				and bool(info.get("frena_vista", false)))
		if es_estructura:
			salida.append(elemento)
	return salida


func _filtrar_paredes_nivel_inferior(elementos, nivel: int) -> Array:
	"""Conserva las paredes del nivel inferior y descarta su contenido.

	Desde una terraza o una piramide se ve la fachada completa del edificio,
	pero no deben aparecer sus suelos, muebles, objetos ni criaturas flotando
	entre plantas. Las paredes siguen usando su altura y textura normales.
	"""
	var salida: Array = []
	for elemento in elementos:
		var cid := _cid_de_elemento(elemento)
		var info: Dictionary = _catalogo.info_item(cid)
		if _forma_de_item(cid, info, nivel) == Forma.CAJA:
			salida.append(elemento)
	return salida


func _elementos_visibles_por_nivel(elementos, donde: Vector3i,
		centro: Vector3i) -> Array:
	if _es_nivel_superior(donde, centro):
		return _filtrar_construccion_superior(elementos)
	if donde.z > centro.z:
		# z=7 es la planta baja/superficie. Desde una piramide hay que verla
		# completa: caminos, suelo, decoracion y sus paredes.
		if centro.z < 7 and donde.z == 7:
			return elementos
		# Los niveles intermedios solo aportan la silueta de sus paredes; sus
		# pisos y objetos no deben quedar suspendidos entre la piramide y la
		# ciudad.
		return _filtrar_paredes_nivel_inferior(elementos, donde.z)
	return elementos


func _es_pared_de_edificio(posicion: Vector3i) -> bool:
	"""Indica si un SQM contiene un muro/puerta estructural del edificio."""
	for cid in _ids_de_casilla(posicion):
		var info: Dictionary = _catalogo.info_item(int(cid))
		if _forma_de_item(int(cid), info, posicion.z) == Forma.CAJA:
			return true
	return false


func _esta_dentro_de_edificio(posicion: Vector3i) -> bool:
	"""Reconoce una sala o una casilla cubierta, sin alterar el bloqueo."""
	if _estado == null or _catalogo == null or _sprites == null:
		return false
	var direcciones := [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	]
	var paredes_direcciones := 0
	for direccion in direcciones:
		for distancia in range(1, RADIO_DETECCION_EDIFICIO + 1):
			if _es_pared_de_edificio(posicion + direccion * distancia):
				paredes_direcciones += 1
				break
	# Tres lados cerrados es suficiente para incluir habitaciones con puerta,
	# esquinas y pasillos interiores, sin ocultar muros por caminar junto a una
	# fachada exterior. Algunas salas tienen menos lados porque la cubierta
	# superior es la señal mas fiable de que estamos dentro.
	return paredes_direcciones >= 3 or _hay_cubierta_sobre(posicion)


func _es_cubierta(info: Dictionary) -> bool:
	var nombre := String(info.get("nombre", "")).to_lower()
	return nombre.contains("roof") or (nombre.contains("floor") \
		and bool(info.get("suelo", false)))


func _hay_cubierta_sobre(posicion: Vector3i) -> bool:
	# En Tibia z menor significa un piso superior. Revisar las tres plantas
	# inmediatas cubre edificios de varios pisos sin activar el modo interior
	# por una estructura demasiado lejana.
	if posicion.z > 7:
		return false
	for nivel in range(posicion.z - 1, maxi(-1, posicion.z - 4), -1):
		var encima := Vector3i(posicion.x, posicion.y, nivel)
		for cid in _ids_de_casilla(encima):
			if _es_cubierta(_catalogo.info_item(int(cid))):
				return true
	return false


func _clave_instancia_visual(nodo: MultiMeshInstance3D, indice: int) -> String:
	return "%d:%d" % [nodo.get_instance_id(), indice]


func _ocultar_pared_interior(referencia: Dictionary) -> String:
	# El nombre se conserva por compatibilidad con los parches dinamicos, pero
	# dentro de un edificio tambien se ocultan los pisos, techos y escaleras
	# del nivel superior. Las paredes del nivel actual nunca pasan por aqui.
	var nodo: MultiMeshInstance3D = referencia.get("nodo") as MultiMeshInstance3D
	var indice := int(referencia.get("indice", -1))
	if not is_instance_valid(nodo) or nodo.multimesh == null \
			or indice < 0 or indice >= nodo.multimesh.instance_count:
		return ""
	var clave := _clave_instancia_visual(nodo, indice)
	if not _paredes_ocultas_interior.has(clave):
		_paredes_ocultas_interior[clave] = {
			"nodo": nodo,
			"indice": indice,
			"transformacion": nodo.multimesh.get_instance_transform(indice),
		}
	var transformacion := nodo.multimesh.get_instance_transform(indice)
	transformacion.origin = Vector3(0.0, -10000.0, 0.0)
	nodo.multimesh.set_instance_transform(indice, transformacion)
	return clave


func _restaurar_pared_interior(clave: String) -> void:
	var registro = _paredes_ocultas_interior.get(clave, null)
	if registro == null:
		return
	var nodo: MultiMeshInstance3D = registro.get("nodo") as MultiMeshInstance3D
	var indice := int(registro.get("indice", -1))
	if is_instance_valid(nodo) and nodo.multimesh != null \
			and indice >= 0 and indice < nodo.multimesh.instance_count:
		nodo.multimesh.set_instance_transform(indice,
			registro.get("transformacion", Transform3D()))
	_paredes_ocultas_interior.erase(clave)


func _restaurar_todas_las_paredes_interior() -> void:
	for clave in _paredes_ocultas_interior.keys().duplicate():
		_restaurar_pared_interior(str(clave))


func _actualizar_visibilidad_interior() -> void:
	"""Oculta los pisos superiores solo mientras el jugador esta dentro."""
	if _estado == null or not _estado.adentro \
			or _centro_escenario.x < -9000:
		_restaurar_todas_las_paredes_interior()
		return
	var aqui: Vector3i = _estado.mi_pos
	var objetivo := {}
	if _esta_dentro_de_edificio(aqui):
		for posicion in _instancias_por_casilla.keys():
			if not posicion is Vector3i or posicion.z >= aqui.z \
				or absi(posicion.x - aqui.x) > RADIO_CORTE_INTERIOR \
				or absi(posicion.y - aqui.y) > RADIO_CORTE_INTERIOR:
				continue
			for referencia in _instancias_por_casilla[posicion]:
				var clave := _ocultar_pared_interior(referencia)
				if not clave.is_empty():
					objetivo[clave] = true
	for clave in _paredes_ocultas_interior.keys().duplicate():
		if not objetivo.has(clave):
			_restaurar_pared_interior(str(clave))


func _cid_de_elemento(elemento) -> int:
	return int(elemento.get("cid", 0)) if typeof(elemento) == TYPE_DICTIONARY \
		else int(elemento)


func _color_liquido_de_elemento(elemento) -> int:
	return int(elemento.get("color_liquido", 0)) \
		if typeof(elemento) == TYPE_DICTIONARY else 0


func _actualizar_casilla_visual(posicion: Vector3i) -> void:
	# Si un muro de este SQM estaba oculto por el modo interior, se restaura
	# antes de mover la instancia vieja fuera del mapa y crear el parche nuevo.
	_restaurar_paredes_interior_de_casilla(posicion)
	_ocultar_instancias_base(posicion)
	_anular_animacion_palanca(posicion)
	if _parches_casilla.has(posicion):
		var parche_anterior: Node3D = _parches_casilla[posicion]
		if is_instance_valid(parche_anterior):
			parche_anterior.free()
		_parches_casilla.erase(posicion)
	_instancias_por_casilla.erase(posicion)

	var grupos := {}
	var elementos := _elementos_de_casilla(posicion)
	elementos = _elementos_visibles_por_nivel(elementos, posicion,
		_centro_escenario)
	if elementos.is_empty():
		return

	var parche := Node3D.new()
	parche.name = "ParcheCasilla_%d_%d_%d" % [posicion.x, posicion.y, posicion.z]
	_piso_mundo.add_child(parche)
	var conteo_anterior := _dibujadas
	var desconocidos_anterior := _desconocidos
	_actualizando_casilla = true
	_destino_volcado = parche
	_animados_volcado = []
	_animaciones_palanca_volcado = []
	_juntar_casilla(grupos, posicion, elementos)
	var claves: Array = grupos.keys()
	claves.sort()
	for clave in claves:
		_volcar_grupo(clave, grupos[clave])
	_actualizando_casilla = false
	_destino_volcado = null
	_animados.append_array(_animados_volcado)
	_animaciones_palanca.append_array(_animaciones_palanca_volcado)
	_animados_volcado = []
	_animaciones_palanca_volcado = []
	_dibujadas = conteo_anterior
	_desconocidos = desconocidos_anterior
	_parches_casilla[posicion] = parche


func _restaurar_paredes_interior_de_casilla(posicion: Vector3i) -> void:
	for clave in _paredes_ocultas_interior.keys().duplicate():
		var registro = _paredes_ocultas_interior[clave]
		var nodo: MultiMeshInstance3D = registro.get("nodo") as MultiMeshInstance3D
		var indice := int(registro.get("indice", -1))
		var referencias: Array = _instancias_por_casilla.get(posicion, [])
		var pertenece := false
		for referencia in referencias:
			if referencia.get("nodo") == nodo \
					and int(referencia.get("indice", -1)) == indice:
				pertenece = true
				break
		if pertenece:
			_restaurar_pared_interior(str(clave))


func _ocultar_instancias_base(posicion: Vector3i) -> void:
	for referencia in _instancias_por_casilla.get(posicion, []):
		var nodo: Node3D = referencia.get("nodo")
		var indice := int(referencia.get("indice", -1))
		if not is_instance_valid(nodo):
			continue
		# Los objetos normales viven dentro de un MultiMesh. La Magic Wall
		# conserva un nodo propio para que cada instancia anime sus frames como
		# la version de 3DTIBIA.
		var multimalla := nodo as MultiMeshInstance3D
		if multimalla == null:
			nodo.visible = false
			continue
		if indice < 0 or indice >= multimalla.multimesh.instance_count:
			continue
		var transformacion := multimalla.multimesh.get_instance_transform(indice)
		transformacion.origin = Vector3(0.0, -10000.0, 0.0)
		multimalla.multimesh.set_instance_transform(indice, transformacion)


func _anular_animacion_palanca(posicion: Vector3i) -> void:
	var restantes: Array = []
	for animacion in _animaciones_palanca:
		if animacion.get("posicion", Vector3i(-9999, -9999, -9999)) != posicion:
			restantes.append(animacion)
	_animaciones_palanca = restantes


func _crear_jugador_visual() -> void:
	if is_instance_valid(_jugador_nodo):
		return
	_jugador_nodo = Node3D.new()
	_jugador_nodo.name = "JugadorVisual"
	add_child(_jugador_nodo)
	# Este es el mismo personaje authored que usaba 3DTIBIA: una capsula
	# para el cuerpo, una esfera para la cabeza y una nariz que marca la
	# direccion. El jugador no depende de un atlas 2D para verse completo.
	_jugador_visual = Node3D.new()
	_jugador_visual.name = "VisualPrincipal3DTibia"
	_jugador_visual.scale = Vector3.ONE * ESCALA_JUGADOR
	_jugador_nodo.add_child(_jugador_visual)

	_jugador_malla = MeshInstance3D.new()
	_jugador_malla.name = "Cuerpo"
	var cap := CapsuleMesh.new()
	cap.radius = 0.26
	cap.height = 1.0
	_jugador_malla.mesh = cap
	_jugador_malla.position = Vector3(0.0, 0.6, 0.0)
	_jugador_malla.material_override = _material_personaje(
		Color(0.72, 0.24, 0.22), 0.7)
	_jugador_visual.add_child(_jugador_malla)

	_jugador_cabeza = MeshInstance3D.new()
	_jugador_cabeza.name = "Cabeza"
	var esf := SphereMesh.new()
	esf.radius = 0.19
	esf.height = 0.38
	_jugador_cabeza.mesh = esf
	_jugador_cabeza.position = Vector3(0.0, 1.25, 0.0)
	_jugador_cabeza.material_override = _material_personaje(
		Color(0.88, 0.73, 0.58), 0.8)
	_jugador_visual.add_child(_jugador_cabeza)

	_jugador_nariz = MeshInstance3D.new()
	_jugador_nariz.name = "Nariz"
	var nm := BoxMesh.new()
	nm.size = Vector3(0.1, 0.1, 0.18)
	_jugador_nariz.mesh = nm
	_jugador_nariz.position = Vector3(0.0, 1.25, -0.2)
	_jugador_nariz.material_override = _material_personaje(
		Color(0.2, 0.2, 0.22), 0.8)
	_jugador_visual.add_child(_jugador_nariz)

	var ficha: Dictionary = _estado.criaturas.get(_estado.mi_id, {})
	_jugador_tipo = int(ficha.get("apariencia", 128))
	_jugador_direccion = int(ficha.get("direccion", 2))
	_actualizar_sprite_jugador(0)


func _material_personaje(color: Color, rugosidad: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rugosidad
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# El personaje debe seguir siendo legible cuando el modelo 3D de un techo
	# o piso superior queda delante de el. Es una prioridad de render, no de
	# colision: el servidor y la grilla siguen bloqueando el paso normalmente.
	material.no_depth_test = true
	material.render_priority = 100
	return material


func _actualizar_sprite_jugador(fase: int) -> void:
	if not is_instance_valid(_jugador_visual):
		return
	# Se conserva el nombre de la funcion porque tambien la llama el control
	# de giro, pero ya no cambia laminas: gira la nariz del modelo authored.
	_jugador_es_sprite = false
	_jugador_visual.rotation.y = -float(posmod(_jugador_direccion, 4)) * PI / 2.0


func _actualizar_jugador_confirmado(aqui: Vector3i, rearmado: bool) -> void:
	_crear_jugador_visual()
	var destino := _posicion_de_apoyo_jugador(aqui)
	_jugador_y_estable = destino.y
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
			_actualizar_sprite_jugador(0)
			_jugador_fase = -1
			_jugador_moviendose = true
	_jugador_pos_confirmada = aqui


func _posicion_de_apoyo_jugador(aqui: Vector3i) -> Vector3:
	"""Pone al personaje sobre la plataforma visual de una construccion.

	Las paredes visuales de los pisos elevados miden dos unidades y nacen en
	la base del SQM. El punto logico de Tibia sigue siendo el mismo, pero el
	personaje debe apoyar los pies en la parte superior de esa geometria cuando
	esta dentro de una piramide o edificio; de lo contrario queda a media altura
	dentro de sus paredes.
	"""
	var destino := _posicion_visual_de_casilla(aqui, _centro_escenario)
	if aqui.z >= 7 or not _hay_plataforma_visual(aqui):
		return destino
	destino.y += _alto_pared_visual
	return destino


func _hay_plataforma_visual(aqui: Vector3i) -> bool:
	"""Detecta una estructura cercana sin convertir el terreno en plataforma."""
	var direcciones := [
		Vector3i.ZERO, Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	]
	for direccion in direcciones:
		if _es_pared_de_edificio(aqui + direccion):
			return true
	# En el centro de una sala grande la pared puede quedar a mas de un SQM.
	# Reutilizar la misma deteccion que corta los pisos superiores evita que el
	# personaje vuelva a hundirse al alejarse del borde de la piramide.
	return _esta_dentro_de_edificio(aqui)


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
		if is_instance_valid(_jugador_visual):
			_jugador_visual.position.y = 0.0
		return
	if _jugador_moviendose:
		_jugador_t = minf(1.0, _jugador_t + delta / maxf(0.01, _jugador_duracion))
		var avance := _jugador_origen.lerp(_jugador_destino, _jugador_t)
		_jugador_nodo.position = avance
		if _jugador_t >= 1.0:
			_jugador_nodo.position = _jugador_destino
			_jugador_moviendose = false
	if is_instance_valid(_jugador_visual):
		_jugador_visual.position.y = sin(_reloj_animacion * PI * 2.0 * 2.5) * 0.035


func _rearmar_escenario(centro: Vector3i) -> bool:
	# La primera carga debe ser inmediata porque todavia no existe una escena
	# anterior que mostrar. Las solicitudes posteriores se preparan por
	# frames y devuelven false: el jugador sigue en el origen viejo hasta que
	# la nueva ventana puede entrar sin dejar un hueco visible.
	if _centro_escenario.x < -9000:
		_rearmar_escenario_inmediato(centro)
		return true
	if centro == _centro_escenario:
		_rearmar_escenario_inmediato(centro)
		return true
	_centro_rearmado_pendiente = centro
	if not _rearmado_en_curso:
		_rearmado_en_curso = true
		_construir_escenario_diferido.call_deferred(centro)
	return false


func _rearmar_escenario_teletransportado(centro: Vector3i) -> bool:
	"""Cambia de ciudad sin dejar el control sobre el centro anterior.

	El escenario completo puede tardar porque contiene miles de sprites. El
	radio inmediato cubre la camara y las primeras rutas; la reconstruccion
	diferida termina el radio largo usando la misma fuente del mapa.
	"""
	if _rearmado_en_curso:
		# No dejamos que una tarea anterior sea la que decida el centro final.
		# El siguiente ciclo lo retomara cuando termine su tanda actual.
		_centro_rearmado_pendiente = centro
		return false
	_rearmar_escenario_inmediato(centro, RADIO_INMEDIATO)
	_centro_rearmado_pendiente = Vector3i(-9999, -9999, -9999)
	_rearmado_en_curso = true
	_construir_escenario_diferido.call_deferred(centro)
	# El teleport debe recolocar la camara, no hacerla viajar desde la ciudad
	# anterior durante varios segundos.
	_camara_colocada = false
	return true


func _rearmar_escenario_inmediato(centro: Vector3i, radio: int = RADIO) -> void:
	_restaurar_todas_las_paredes_interior()
	_centro_escenario = centro
	_instancias_por_casilla.clear()
	_instancias_en_construccion.clear()
	for posicion in _parches_casilla:
		var parche: Node3D = _parches_casilla[posicion]
		if is_instance_valid(parche):
			parche.free()
	_parches_casilla.clear()
	for hijo in _piso_mundo.get_children():
		hijo.queue_free()
	_animados.clear()
	_animaciones_palanca.clear()
	_destino_volcado = null
	_animados_volcado.clear()
	_construccion_activa = false
	_dibujadas = 0
	_desconocidos = 0

	var delo_disco: Dictionary = _disco.casillas_de(centro, radio)
	# La misma ventana sirve para dibujar y para buscar rutas. Consultar el
	# archivo del mapa por cada vecino del algoritmo era lo que congelaba el
	# hilo principal al hacer clic.
	_mapa_visible = delo_disco
	_bloqueo_disco_cache.clear()

	# Los grupos: una entrada por (dibujo, forma). Adentro se juntan las
	# posiciones y al final cada grupo se vuelca en un MultiMesh.
	var grupos := {}

	for donde in delo_disco:
		# El servidor manda varios pisos, pero en la escena solo se conserva la
		# planta actual y, cuando corresponde, la arquitectura de pisos superiores.
		if not _nivel_renderizable(donde, centro):
			continue
		# Si el servidor ya nos hablo de esta casilla, mandan sus datos:
		# son los de AHORA. El disco es de cuando se guardo el mapa.
		if _estado.casillas.has(donde):
			continue
		var elementos_disco = delo_disco[donde]
		elementos_disco = _elementos_visibles_por_nivel(elementos_disco,
			donde, centro)
		_juntar_casilla(grupos, donde, elementos_disco)

	for donde in _estado.casillas:
		if not _nivel_renderizable(donde, centro):
			continue
		if absi(donde.x - centro.x) > radio or absi(donde.y - centro.y) > radio:
			continue
		var elementos_estado := _elementos_de_casilla(donde)
		elementos_estado = _elementos_visibles_por_nivel(elementos_estado,
			donde, centro)
		_juntar_casilla(grupos, donde, elementos_estado)

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
		var orden_a := _orden_de_grupo(ga)
		var orden_b := _orden_de_grupo(gb)
		if orden_a != orden_b:
			return orden_a < orden_b
		return int(ga["cid"]) < int(gb["cid"])
	)
	for clave in claves:
		_volcar_grupo(clave, grupos[clave])


func _construir_escenario_diferido(centro: Vector3i) -> void:
	"""Construye una ventana nueva sin borrar la que esta en pantalla.

	Primero agrupa y vuelca solo el radio inmediato, hace el commit para que el
	piso nuevo aparezca enseguida, y despues completa el fondo en el mismo nodo.
	Cada tanda respeta el presupuesto de tiempo para que ninguna fase congele
	la imagen.
	"""
	var disco_nuevo: Dictionary = _disco.casillas_de(centro, RADIO)
	var grupos_cercanos := {}
	_instancias_en_construccion.clear()
	var claves_disco: Array = disco_nuevo.keys()
	var indice := 0
	_construccion_activa = true
	_dibujadas_construccion = 0
	_desconocidos_construccion = 0

	# Las heuristicas de vecinos deben consultar la ventana que se esta
	# construyendo, pero el origen de coordenadas se pasa explicitamente para
	# no mover el mundo visible mientras el proceso duerme.
	_mapa_visible = disco_nuevo
	_bloqueo_disco_cache.clear()
	var inicio_tanda := Time.get_ticks_usec()
	while indice < claves_disco.size():
		var donde: Vector3i = claves_disco[indice]
		if _nivel_renderizable(donde, centro) \
				and absi(donde.x - centro.x) <= RADIO_INMEDIATO \
				and absi(donde.y - centro.y) <= RADIO_INMEDIATO \
				and not _estado.casillas.has(donde):
			var elementos_disco = disco_nuevo[donde]
			elementos_disco = _elementos_visibles_por_nivel(elementos_disco,
				donde, centro)
			_juntar_casilla(grupos_cercanos, donde, elementos_disco, centro)
		indice += 1
		if Time.get_ticks_usec() - inicio_tanda >= PRESUPUESTO_REARMADO_US:
			await get_tree().process_frame
			inicio_tanda = Time.get_ticks_usec()

	var claves_estado: Array = _estado.casillas.keys()
	indice = 0
	inicio_tanda = Time.get_ticks_usec()
	while indice < claves_estado.size():
		var donde: Vector3i = claves_estado[indice]
		if _estado.casillas.has(donde) \
				and _nivel_renderizable(donde, centro) \
				and absi(donde.x - centro.x) <= RADIO_INMEDIATO \
				and absi(donde.y - centro.y) <= RADIO_INMEDIATO:
			var elementos_estado := _elementos_de_casilla(donde)
			elementos_estado = _elementos_visibles_por_nivel(elementos_estado,
				donde, centro)
			_juntar_casilla(grupos_cercanos, donde, elementos_estado, centro)
		indice += 1
		if Time.get_ticks_usec() - inicio_tanda >= PRESUPUESTO_REARMADO_US:
			await get_tree().process_frame
			inicio_tanda = Time.get_ticks_usec()
	_construccion_activa = false

	var claves_cercanas: Array = grupos_cercanos.keys()
	claves_cercanas.sort_custom(func(a, b):
		var ga: Dictionary = grupos_cercanos[a]
		var gb: Dictionary = grupos_cercanos[b]
		var capa_a := _capa_de_forma(int(ga["forma"]))
		var capa_b := _capa_de_forma(int(gb["forma"]))
		if capa_a != capa_b:
			return capa_a < capa_b
		var orden_a := _orden_de_grupo(ga)
		var orden_b := _orden_de_grupo(gb)
		if orden_a != orden_b:
			return orden_a < orden_b
		return int(ga["cid"]) < int(gb["cid"])
	)

	var mundo_nuevo := Node3D.new()
	mundo_nuevo.name = "Mapa3D_Pendiente"
	_destino_volcado = mundo_nuevo
	_animados_volcado = []
	indice = 0
	inicio_tanda = Time.get_ticks_usec()
	while indice < claves_cercanas.size():
		var clave: String = claves_cercanas[indice]
		_volcar_grupo(clave, grupos_cercanos[clave])
		indice += 1
		if Time.get_ticks_usec() - inicio_tanda >= PRESUPUESTO_REARMADO_US:
			await get_tree().process_frame
			inicio_tanda = Time.get_ticks_usec()

	var animados_cercanos := _animados_volcado
	var dibujadas_cercanas := _dibujadas_construccion
	var desconocidos_cercanos := _desconocidos_construccion
	_destino_volcado = null
	_animados_volcado = []
	_construccion_activa = false
	_aplicar_escenario_rearmado(centro, mundo_nuevo, animados_cercanos,
		dibujadas_cercanas, desconocidos_cercanos, disco_nuevo)

	# El piso inmediato ya esta visible. Dejar que Godot lo presente antes de
	# preparar el fondo evita que la segunda fase parezca otro cambio de piso.
	await get_tree().process_frame

	var grupos_lejanos := {}
	var claves_lejanas_disco: Array = disco_nuevo.keys()
	indice = 0
	inicio_tanda = Time.get_ticks_usec()
	while indice < claves_lejanas_disco.size():
		var donde: Vector3i = claves_lejanas_disco[indice]
		if _nivel_renderizable(donde, centro) \
				and (absi(donde.x - centro.x) > RADIO_INMEDIATO \
				or absi(donde.y - centro.y) > RADIO_INMEDIATO) \
				and not _estado.casillas.has(donde):
			var elementos_disco = disco_nuevo[donde]
			elementos_disco = _elementos_visibles_por_nivel(elementos_disco,
				donde, centro)
			_juntar_casilla(grupos_lejanos, donde, elementos_disco, centro)
		indice += 1
		if Time.get_ticks_usec() - inicio_tanda >= PRESUPUESTO_REARMADO_US:
			await get_tree().process_frame
			inicio_tanda = Time.get_ticks_usec()

	var claves_estado_lejanas: Array = _estado.casillas.keys()
	indice = 0
	inicio_tanda = Time.get_ticks_usec()
	while indice < claves_estado_lejanas.size():
		var donde: Vector3i = claves_estado_lejanas[indice]
		if _nivel_renderizable(donde, centro) \
				and (absi(donde.x - centro.x) > RADIO_INMEDIATO \
				or absi(donde.y - centro.y) > RADIO_INMEDIATO) \
				and absi(donde.x - centro.x) <= RADIO \
				and absi(donde.y - centro.y) <= RADIO:
			var elementos_estado := _elementos_de_casilla(donde)
			elementos_estado = _elementos_visibles_por_nivel(elementos_estado,
				donde, centro)
			_juntar_casilla(grupos_lejanos, donde, elementos_estado, centro)
		indice += 1
		if Time.get_ticks_usec() - inicio_tanda >= PRESUPUESTO_REARMADO_US:
			await get_tree().process_frame
			inicio_tanda = Time.get_ticks_usec()

	var claves_lejanas: Array = grupos_lejanos.keys()
	claves_lejanas.sort_custom(func(a, b):
		var ga: Dictionary = grupos_lejanos[a]
		var gb: Dictionary = grupos_lejanos[b]
		var capa_a := _capa_de_forma(int(ga["forma"]))
		var capa_b := _capa_de_forma(int(gb["forma"]))
		if capa_a != capa_b:
			return capa_a < capa_b
		var orden_a := _orden_de_grupo(ga)
		var orden_b := _orden_de_grupo(gb)
		if orden_a != orden_b:
			return orden_a < orden_b
		return int(ga["cid"]) < int(gb["cid"])
	)
	indice = 0
	inicio_tanda = Time.get_ticks_usec()
	while indice < claves_lejanas.size():
		var clave: String = claves_lejanas[indice]
		_volcar_grupo(clave, grupos_lejanos[clave])
		indice += 1
		if Time.get_ticks_usec() - inicio_tanda >= PRESUPUESTO_REARMADO_US:
			await get_tree().process_frame
			inicio_tanda = Time.get_ticks_usec()

	_rearmado_en_curso = false

	# Si el jugador avanzo mientras se construia, se conserva la solicitud mas
	# reciente y se prepara otra ventana solo si ya salio del margen.
	var siguiente := _centro_rearmado_pendiente
	_centro_rearmado_pendiente = Vector3i(-9999, -9999, -9999)
	if siguiente.x > -9000 \
			and (absi(_estado.mi_pos.x - _centro_escenario.x) >= PASOS_PARA_REARMAR \
			or absi(_estado.mi_pos.y - _centro_escenario.y) >= PASOS_PARA_REARMAR \
			or _estado.mi_pos.z != _centro_escenario.z):
		_rearmar_escenario(siguiente)


func _aplicar_escenario_rearmado(centro: Vector3i, mundo_nuevo: Node3D,
		animados_nuevos: Array, dibujadas_nuevas: int,
		desconocidos_nuevos: int, mapa_nuevo: Dictionary) -> void:
	# COORD devuelve donde queda el nuevo ancla expresado en el origen viejo.
	# Restar ese vector a camara, jugador y animacion hace que el cambio de
	# origen sea matematicamente invisible.
	var desplazamiento := COORD.tibia_a_mundo(
		centro, _centro_escenario, LADO, ALTO_PISO)
	if is_instance_valid(_camara):
		_camara.position -= desplazamiento
	_camara_foco -= desplazamiento
	if is_instance_valid(_jugador_nodo):
		_jugador_nodo.position -= desplazamiento
		_jugador_origen -= desplazamiento
		_jugador_destino -= desplazamiento

	_centro_escenario = centro
	_instancias_por_casilla = _instancias_en_construccion.duplicate(true)
	_instancias_en_construccion.clear()
	_parches_casilla.clear()
	_mapa_visible = mapa_nuevo
	_bloqueo_disco_cache.clear()
	var mundo_viejo := _piso_mundo
	_restaurar_todas_las_paredes_interior()
	_piso_mundo = mundo_nuevo
	add_child(_piso_mundo)
	if is_instance_valid(mundo_viejo):
		mundo_viejo.queue_free()
	_animados = animados_nuevos
	_animaciones_palanca.clear()
	_dibujadas = dibujadas_nuevas
	_desconocidos = desconocidos_nuevos
	_dibujar_criaturas()
	_actualizar_visibilidad_interior()


func _juntar_casilla(grupos: Dictionary, donde: Vector3i, ids,
		ancla: Vector3i = Vector3i(-9999, -9999, -9999)) -> void:
	var apilado := 0
	var origen := _centro_escenario if ancla.x < -9000 else ancla
	var hay_acceso_de_piso := false
	for elemento_acceso in ids:
		var acceso_cid := _cid_de_elemento(elemento_acceso)
		if _es_acceso_de_piso(_catalogo.info_item(acceso_cid)):
			hay_acceso_de_piso = true
			break
	for elemento in ids:
		var cid: int = _cid_de_elemento(elemento)
		var color_liquido: int = _color_liquido_de_elemento(elemento)
		var info: Dictionary = _catalogo.info_item(cid)
		var forma: int = _forma_de_item(cid, info, donde.z)
		# Una cama del mapa esta formada por dos SQM: 2487/2488 y sus
		# variantes. El modelo authored ya contiene ambas mitades; solo se
		# dibuja desde la pieza de cabecera para no duplicarlo.
		if forma == Forma.MUEBLE and _es_pieza_pie_cama(cid):
			continue
		# En mapas antiguos el mismo SQM puede traer la escalera/trapdoor y
		# otro item bloqueante. El volumen que generamos para ese segundo item
		# tapa el acceso y deja un cubo sobre los escalones. La escalera sigue
		# visible como plano; las paredes de los SQM vecinos no se modifican.
		if hay_acceso_de_piso and forma == Forma.CAJA:
			continue
		var orientacion := OrientacionPared.EJE_X
		if forma == Forma.CAJA:
			orientacion = _orientacion_de_pared(donde, cid)
		elif forma == Forma.PASAMANOS:
			orientacion = _orientacion_de_pasamanos(donde, cid)
		elif forma == Forma.MONTANA:
			# El perfil depende de las cuatro casillas vecinas. Asi una
			# cordillera queda unida arriba y solo se inclinan sus bordes.
			orientacion = _perfil_de_montana(donde)
		var alto: int = _sprites.alto_en_casillas(cid)
		if forma == Forma.PLACEHOLDER:
			if _construccion_activa:
				_desconocidos_construccion += 1
			else:
				_desconocidos += 1
		var posicion_3d := _posicion_visual_de_casilla(donde, origen)
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
				var altura_mueble := ALTO_MUEBLE
				if _es_cama_modelo(cid):
					# El OBJ authored empieza en la base del piso; no usar la
					# media altura generica de los muebles porque la eleva.
					y += 0.01
				else:
					y += altura_mueble * 0.5 + apilado * 0.01
				apilado += 1
			Forma.PASAMANOS:
				y += ALTO_PASAMANOS * 0.5 + apilado * 0.01
				apilado += 1
			Forma.LAMINA:
				if _es_lampara_calle(info):
					# El modelo authored empieza en su base (Y=0). El sprite 2D
					# se centraba en el SQM y dejaba la lampara flotando.
					# Este origen queda justo sobre el piso.
					y += 0.01
				else:
					y += alto * 0.5 + apilado * 0.01
					apilado += 1
		y += float(_mapping_de(cid).get("vertical_offset", 0.0))

		# Dos pools con el mismo client ID pueden tener colores distintos
		# (agua, sangre, veneno). No deben compartir MultiMesh/material.
		var clave := "%d_%d_%d_%d" % [cid, forma, orientacion, color_liquido]
		var grupo = grupos.get(clave)
		if grupo == null:
			grupo = {"cid": cid, "forma": forma, "orientacion": orientacion,
				"color_liquido": color_liquido, "donde": [], "casillas": []}
			grupos[clave] = grupo
		grupo["donde"].append(Vector3(posicion_3d.x, y, posicion_3d.z))
		grupo["casillas"].append(donde)
		if _construccion_activa:
			_dibujadas_construccion += 1
		else:
			_dibujadas += 1


func _posicion_visual_de_casilla(donde: Vector3i, origen: Vector3i) -> Vector3:
	var posicion := COORD.tibia_a_mundo(donde, origen, LADO, ALTO_PISO)
	if donde.z < origen.z and origen.z <= 7:
		# z=7 sigue siendo la base. Solo ampliamos la distancia entre las
		# plantas que se ven desde la superficie; el nivel logico del servidor
		# y los pisos subterraneos no cambian.
		var plantas_arriba := origen.z - donde.z
		posicion.y = float(7 - origen.z) * ALTO_PISO \
				+ float(plantas_arriba) * ALTURA_PLANTA_VISUAL
	return posicion


func _forma_de_item(cid: int, info: Dictionary, nivel: int = -1) -> int:
	if not _sprites.tiene_item(cid):
		return Forma.PLACEHOLDER
	# Las street lamps son laminas altas que deben conservar su base en el
	# SQM y usar billboard fijo en Y. La regla explicita evita que una bandera
	# incompleta del DAT las convierta accidentalmente en muro o suelo.
	if _es_lampara_calle(info):
		return Forma.LAMINA
	# Una reja/pasamanos es una construccion del puente, no una decoracion
	# billboard. La regla semantica gana incluso si el DAT solo dice
	# bloquea=true, porque asi todos sus tramos reciben la misma geometria.
	if _es_pasamanos(info):
		return Forma.PASAMANOS
	# Las puertas son parte fija del mapa, no decorados billboard. Esto aplica
	# tanto a puertas simples como a las que tienen parametros: solo cambia su
	# representacion visual, no el flujo de uso del servidor.
	if _es_puerta(info):
		return Forma.CAJA
	# Holes, cuerpos y pools viven sobre el suelo. La regla es semantica para
	# que no dependan de que el DAT los haya marcado como suelo o decoracion.
	# En particular, un cuerpo muerto nunca debe quedar como billboard parado.
	if _es_hoyo(info) or _es_cuerpo_muerto(info) or _es_pool_de_liquido(info):
		return Forma.ACOSTADA
	var mapping := _mapping_de(cid)
	var primitiva := String(mapping.get("primitive", "auto"))
	if primitiva != "" and primitiva != "auto":
		return _forma_de_mapping(primitiva)
	# Las transiciones de shallow water tambien vienen marcadas como suelo en
	# el DAT. Deben ir acostadas para que el shader pueda poner pasto debajo de
	# su transparencia; el agua profunda sigue usando la forma de suelo.
	if _es_borde_agua(cid):
		return Forma.ACOSTADA
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
	if String(info.get("nombre", "")).to_lower() == "bed":
		# Las camas authored reemplazan el modelo provisional de una lamina.
		# Cada cama ocupa dos SQM y la pieza trasera se filtra en
		# `_juntar_casilla`.
		return Forma.MUEBLE
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
		or nombre.contains("lever") or nombre == "ladder" \
		or nombre.contains("stairs") \
		or nombre.contains("stair") or nombre.contains("trapdoor") \
		or nombre.contains("hole") or nombre.contains("ramp")


func _es_hoyo(info: Dictionary) -> bool:
	return String(info.get("nombre", "")).to_lower().contains("hole")


func _es_cuerpo_muerto(info: Dictionary) -> bool:
	var nombre := String(info.get("nombre", "")).to_lower()
	# Estos objetos contienen la palabra "dead", pero son decoracion vertical,
	# no cadaveres: conservar su representacion normal.
	if nombre.contains("dead tree") or nombre.contains("dead man's saddle"):
		return false
	return nombre.contains("corpse") or nombre.begins_with("dead ") \
		or nombre.begins_with("slain ") or nombre.contains("pile of bones")


func _es_pool_de_liquido(info: Dictionary) -> bool:
	return bool(info.get("liquido", false)) \
		and String(info.get("nombre", "")).to_lower() == "pool"


func _es_puerta(info: Dictionary) -> bool:
	return String(info.get("nombre", "")).to_lower().contains("door")


func _es_lampara_calle(info: Dictionary) -> bool:
	return String(info.get("nombre", "")).to_lower() == "street lamp"


func _casilla_tiene_paso_automatico(posicion: Vector3i) -> bool:
	# La categoria no se inventa en el cliente: la exporta
	# herramientas/tibia3d_map.py desde items.xml y queda en el IR.
	var ir_tile := _tile_ir(posicion)
	for item_variant in ir_tile.get("items", []):
		var item: Dictionary = item_variant
		var nombre_ir := String(item.get("name", "")).to_lower()
		if String(item.get("category", "")) == "STAIRS" \
				or nombre_ir.contains("trapdoor") \
				or nombre_ir.contains("ladder") \
				or nombre_ir.contains("sewer") \
				or nombre_ir.contains("grate") \
				or nombre_ir.contains("hole"):
			return true
	# Las casillas recibidas en vivo no siempre tienen la categoria IR. Usar
	# el catalogo de sprites como respaldo, en especial para trapdoors, que
	# son suelo en el DAT pero cambian de piso al pisarlos.
	for cid in _ids_de_casilla(posicion):
		if _es_acceso_de_piso(_catalogo.info_item(int(cid))):
			return true
	return false


func _considerar_reintento_acceso(aqui: Vector3i) -> void:
	"""Compatibilidad antigua; los cambios de piso los resuelve el servidor."""
	if _con == null or not _estado.adentro or _acceso_reintento_pendiente:
		return
	var movimiento: Dictionary = _estado.ultimo_movimiento
	if movimiento.is_empty() or movimiento == _ultimo_movimiento_acceso:
		return
	_ultimo_movimiento_acceso = movimiento.duplicate()
	var desde: Vector3i = movimiento.get("de", Vector3i(-9999, -9999, -9999))
	var hasta: Vector3i = movimiento.get("a", Vector3i(-9999, -9999, -9999))
	if hasta != aqui or desde.z != hasta.z:
		if hasta.z != aqui.z:
			_acceso_reintento_pos = Vector3i(-9999, -9999, -9999)
		return
	if _acceso_reintento_pos == hasta or not _casilla_tiene_paso_automatico(hasta):
		return
	var delta := Vector2i(hasta.x - desde.x, hasta.y - desde.y)
	if absi(delta.x) + absi(delta.y) != 1:
		return
	var opcode := _opcode_de_direccion(delta)
	if opcode == 0:
		return
	_acceso_reintento_pos = hasta
	_acceso_reintento_pendiente = true
	_reintentar_acceso.call_deferred(hasta, opcode)


func _reintentar_acceso(posicion: Vector3i, opcode: int) -> void:
	_acceso_reintento_pendiente = false
	if not _estado.adentro or _estado.mi_pos != posicion or _con == null:
		return
	_con.enviar_juego(PackedByteArray([opcode]))
	_desde_ultimo_paso = 0.0


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


func _orientacion_de_pared(donde: Vector3i, cid: int = -1) -> int:
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
		# En una esquina tienen que existir los dos brazos. Elegir un solo eje
		# deja un hueco o gira el tramo que cruza el perimetro.
		return OrientacionPared.ESQUINA
	if conecta_z:
		return OrientacionPared.EJE_Z
	# Un muro aislado no tiene vecinos que revelen su eje. El DAT conserva
	# esta informacion en las banderas vertical/horizontal del item.
	if cid >= 0:
		var info: Dictionary = _catalogo.info_item(cid)
		if bool(info.get("vertical", false)):
			return OrientacionPared.EJE_Z
		if bool(info.get("horizontal", false)):
			return OrientacionPared.EJE_X
	return OrientacionPared.EJE_X


func _orientacion_de_pasamanos(donde: Vector3i, cid: int) -> int:
	# Unimos los tramos segun otros pasamanos, no segun la camara. Cuando un
	# sprite queda solo, su footprint 2x1/1x2 mantiene la direccion original.
	var conecta_x := _hay_pasamanos_en(donde + Vector3i(-1, 0, 0)) \
		or _hay_pasamanos_en(donde + Vector3i(1, 0, 0))
	var conecta_z := _hay_pasamanos_en(donde + Vector3i(0, -1, 0)) \
		or _hay_pasamanos_en(donde + Vector3i(0, 1, 0))
	if conecta_z and not conecta_x:
		return OrientacionPared.EJE_Z
	if conecta_x:
		return OrientacionPared.EJE_X
	return OrientacionPared.EJE_X if _sprites.ancho_en_casillas(cid) >= \
		_sprites.alto_en_casillas(cid) else OrientacionPared.EJE_Z


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
		if _es_pasamanos(info) or (info.get("bloquea", false)
				and info.get("frena_vista", false)):
			return true
	return false


func _hay_pasamanos_en(donde: Vector3i) -> bool:
	for cid in _ids_de_casilla(donde):
		if _es_pasamanos(_catalogo.info_item(int(cid))):
			return true
	return false


func _es_pasamanos(info: Dictionary) -> bool:
	var nombre := String(info.get("nombre", "")).to_lower()
	return nombre.contains("railing") or nombre.ends_with(" rail") \
		or nombre.contains("handrail") or nombre.contains("guard rail")


func _es_pieza_vertical(info: Dictionary) -> bool:
	var nombre := String(info.get("nombre", "")).to_lower()
	return nombre.contains("door") or nombre.contains("window") \
		or nombre.contains("archway") or nombre.contains("gate") \
		or _es_pasamanos(info) or nombre.contains("bars") \
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
		Forma.PASAMANOS:
			return 4
		Forma.CAJA:
			return 5
		Forma.LAMINA:
			return 6
		_:
			return 6


func _orden_de_grupo(grupo: Dictionary) -> int:
	# El DAT ya distingue decoraciones always-on-top, lamparas y puertas.
	# Usarlo como segundo criterio hace determinista la pila visual cuando
	# varios sprites comparten la misma forma y capa.
	return int(_catalogo.info_item(int(grupo.get("cid", 0))).get("orden_arriba", 0))


func _es_pieza_pie_cama(cid: int) -> bool:
	return cid in IDS_CAMA_PIE


func _es_cama_modelo(cid: int) -> bool:
	if _es_pieza_pie_cama(cid):
		return false
	var nombre := String(_catalogo.info_item(cid).get("nombre", "")).to_lower()
	return nombre == "bed"


func _malla_cama_de(dormida: bool) -> ArrayMesh:
	var clave := "bed-person" if dormida else "bed"
	if _mallas_cama.has(clave):
		return _mallas_cama[clave]
	var ruta := ARCHIVO_CAMA_PERSONA if dormida else ARCHIVO_CAMA
	var malla: ArrayMesh = MODELO_OBJ.cargar(ruta)
	if malla != null:
		_mallas_cama[clave] = malla
	return malla


func _malla_lampara_de() -> ArrayMesh:
	if _malla_lampara != null:
		return _malla_lampara
	var malla: ArrayMesh = MODELO_OBJ.cargar(ARCHIVO_LAMPARA)
	if malla != null:
		_malla_lampara = malla
	return malla


func _material_lampara() -> StandardMaterial3D:
	var clave := "__modelo_lampara"
	if _materiales.has(clave):
		return _materiales[clave]
	var mat := StandardMaterial3D.new()
	var textura = load(ARCHIVO_TEXTURA_LAMPARA)
	if textura is Texture2D:
		mat.albedo_texture = textura
	else:
		push_warning("No se pudo cargar la textura de la street lamp: "
				+ ARCHIVO_TEXTURA_LAMPARA)
		mat.albedo_color = Color("#5f5a4d")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.82
	_materiales[clave] = mat
	return mat


func _volcar_lampara_grupo(grupo: Dictionary, malla: ArrayMesh) -> void:
	"""Dibuja las street lamps authored apoyadas en la base del SQM.

	El OBJ se comparte en un MultiMesh para no crear un nodo por lampara.
	La animacion de luz se agregara despues; por ahora el modelo conserva
	siempre su textura estatica y su posicion real.
	"""
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = malla
	var sitios: Array = grupo.get("donde", [])
	mm.instance_count = sitios.size()
	for indice in range(sitios.size()):
		mm.set_instance_transform(indice,
			Transform3D(Basis(), sitios[indice]))

	var nodo := MultiMeshInstance3D.new()
	nodo.name = "StreetLampAuthored_%d" % int(grupo.get("cid", 0))
	nodo.multimesh = mm
	nodo.material_override = _material_lampara()
	var destino: Node3D = _piso_mundo
	if is_instance_valid(_destino_volcado):
		destino = _destino_volcado
	destino.add_child(nodo)
	var tabla := _instancias_en_construccion if is_instance_valid(_destino_volcado) \
			else _instancias_por_casilla
	if _actualizando_casilla:
		tabla = _instancias_por_casilla
	var casillas: Array = grupo.get("casillas", [])
	for indice in range(casillas.size()):
		var posicion: Vector3i = casillas[indice]
		if not tabla.has(posicion):
			tabla[posicion] = []
		tabla[posicion].append({"nodo": nodo, "indice": indice,
			"forma": Forma.LAMINA})


func _altura_modelo_cama() -> float:
	var malla := _malla_cama_de(false)
	if malla == null:
		return ALTO_MUEBLE
	return maxf(ALTO_MUEBLE, malla.get_aabb().size.y)


func _ajuste_orientacion_cama(posicion: Vector3i) -> Dictionary:
	# En el OTBM de Rookgaard la cabecera mira hacia Y positivo. Las otras
	# tres comprobaciones permiten reutilizar el modelo si se agregan camas
	# giradas en otra zona del mapa.
	var vecinos := [
		{"delta": Vector3i(0, 1, 0), "desplazamiento": Vector3(0, 0, 0.5),
			"giro": 0.0},
		{"delta": Vector3i(0, -1, 0), "desplazamiento": Vector3(0, 0, -0.5),
			"giro": PI},
		{"delta": Vector3i(1, 0, 0), "desplazamiento": Vector3(0.5, 0, 0),
			"giro": PI * 0.5},
		{"delta": Vector3i(-1, 0, 0), "desplazamiento": Vector3(-0.5, 0, 0),
			"giro": -PI * 0.5},
	]
	for vecino in vecinos:
		var ids := _ids_de_casilla(posicion + vecino["delta"])
		for vecino_cid in ids:
			if _es_pieza_pie_cama(int(vecino_cid)):
				return vecino
	return {"desplazamiento": Vector3.ZERO, "giro": 0.0}


func _material_modelo_cama(dormida: bool = false) -> StandardMaterial3D:
	var clave := "__modelo_cama_persona" if dormida else "__modelo_cama"
	if _materiales.has(clave):
		return _materiales[clave]
	var mat := StandardMaterial3D.new()
	var ruta_textura := ARCHIVO_TEXTURA_CAMA_PERSONA if dormida \
			else ARCHIVO_TEXTURA_CAMA
	var textura = load(ruta_textura)
	if textura is Texture2D:
		mat.albedo_texture = textura
	else:
		# Respaldo para que el modelo no desaparezca si falta el PNG en una
		# exportacion incompleta.
		mat.albedo_color = Color("#9a5b47") if not dormida \
				else Color("#b77859")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.88
	_materiales[clave] = mat
	return mat


func _volcar_cama_grupo(grupo: Dictionary, malla: ArrayMesh) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = malla
	var sitios: Array = grupo.get("donde", [])
	var casillas: Array = grupo.get("casillas", [])
	mm.instance_count = sitios.size()
	for indice in range(sitios.size()):
		var ajuste := _ajuste_orientacion_cama(casillas[indice]) \
				if indice < casillas.size() else {"desplazamiento": Vector3.ZERO,
					"giro": 0.0}
		var base := Basis(Vector3.UP, float(ajuste.get("giro", 0.0)))
		var origen: Vector3 = sitios[indice] + ajuste.get(
			"desplazamiento", Vector3.ZERO)
		mm.set_instance_transform(indice, Transform3D(base, origen))

	var nodo := MultiMeshInstance3D.new()
	nodo.name = "CamaAuthored_%d" % int(grupo.get("cid", 0))
	nodo.multimesh = mm
	nodo.material_override = _material_modelo_cama(false)
	var destino: Node3D = _piso_mundo
	if is_instance_valid(_destino_volcado):
		destino = _destino_volcado
	destino.add_child(nodo)
	var tabla := _instancias_en_construccion if is_instance_valid(_destino_volcado) \
			else _instancias_por_casilla
	if _actualizando_casilla:
		tabla = _instancias_por_casilla
	for indice in range(casillas.size()):
		var posicion: Vector3i = casillas[indice]
		if not tabla.has(posicion):
			tabla[posicion] = []
		tabla[posicion].append({"nodo": nodo, "indice": indice,
			"forma": Forma.MUEBLE})


func _volcar_grupo(clave: String, grupo: Dictionary) -> void:
	var cid: int = grupo["cid"]
	var forma: int = grupo["forma"]
	var orientacion: int = grupo.get("orientacion", OrientacionPared.EJE_X)
	var color_liquido: int = int(grupo.get("color_liquido", 0))
	if forma == Forma.MUEBLE and _es_cama_modelo(cid):
		var malla_cama = _malla_cama_de(false)
		if malla_cama != null:
			_volcar_cama_grupo(grupo, malla_cama)
			return
	if forma == Forma.LAMINA and _es_lampara_calle(
			_catalogo.info_item(cid)):
		var malla_lampara := _malla_lampara_de()
		if malla_lampara != null:
			_volcar_lampara_grupo(grupo, malla_lampara)
			return
	if cid in IDS_MAGIC_WALL:
		_volcar_magic_wall_grupo(grupo)
		return

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
		elif forma == Forma.MUEBLE or forma == Forma.PASAMANOS:
			_aplicar_materiales_estructura(mm.mesh, cuadro, forma,
				_catalogo.info_item(cid))
		else:
			nodo.material_override = _material(cuadro, forma, cid, color_liquido)
	var destino: Node3D = _piso_mundo
	if is_instance_valid(_destino_volcado):
		destino = _destino_volcado
	destino.add_child(nodo)
	var tabla := _instancias_en_construccion if is_instance_valid(_destino_volcado) \
			else _instancias_por_casilla
	if _actualizando_casilla:
		tabla = _instancias_por_casilla
	var casillas_grupo: Array = grupo.get("casillas", [])
	for indice in range(casillas_grupo.size()):
		var posicion: Vector3i = casillas_grupo[indice]
		if not tabla.has(posicion):
			tabla[posicion] = []
		tabla[posicion].append({"nodo": nodo, "indice": indice,
			"forma": forma})
	if _actualizando_casilla and forma == Forma.ACOSTADA \
			and ESTADOS_PALANCA.has(cid):
		var casillas_palanca: Array = grupo.get("casillas", [])
		if not casillas_palanca.is_empty():
			_animaciones_palanca_volcado.append({
				"nodo": nodo,
				"cid": cid,
				"posicion": casillas_palanca[0],
				"tiempo": 0.0,
			})

	if forma != Forma.PLACEHOLDER and forma != Forma.CAJA \
			and forma != Forma.MONTANA \
			and _sprites.fases_de_item(cid) > 1:
		if is_instance_valid(_destino_volcado):
			_animados_volcado.append({"nodo": nodo, "cid": cid, "forma": forma,
				"color_liquido": color_liquido})
		else:
			_animados.append({"nodo": nodo, "cid": cid, "forma": forma,
				"color_liquido": color_liquido})


func _volcar_magic_wall_grupo(grupo: Dictionary) -> void:
	"""Vuelca la Magic Wall original de 3DTIBIA.

	La pared no se mete en el MultiMesh de estructuras porque su material
	cambia de textura cada 200 ms. Los muros suelen ser pocos y el nodo propio
	permite mantener exactamente el cubo 1x2x1 y el ciclo de tres frames del
	cliente anterior.
	"""
	var cid: int = grupo["cid"]
	var sitios: Array = grupo["donde"]
	var casillas: Array = grupo.get("casillas", [])
	var destino: Node3D = _piso_mundo
	if is_instance_valid(_destino_volcado):
		destino = _destino_volcado
	for indice in range(sitios.size()):
		var muro = GUION_MAGIC_WALL.new()
		muro.name = "MagicWall3D_%d_%d" % [cid, indice]
		muro.configurar(cid)
		var posicion_muro: Vector3 = sitios[indice]
		# `_juntar_casilla` centra las paredes normales segun su altura
		# configurable. El cubo heredado de 3DTIBIA mide siempre dos pisos y
		# quedaba apoyado con el centro exactamente en Y=1.0.
		posicion_muro.y += 1.0 - _alto_pared_visual * 0.5
		muro.position = posicion_muro
		destino.add_child(muro)
		if not _actualizando_casilla:
			var tabla := _instancias_en_construccion if is_instance_valid(_destino_volcado) \
					else _instancias_por_casilla
			var posicion: Vector3i = casillas[indice]
			if not tabla.has(posicion):
				tabla[posicion] = []
			tabla[posicion].append({"nodo": muro, "indice": -1})


func _altura_de(z: int) -> float:
	return COORD.tibia_a_mundo(Vector3i(0, 0, z), Vector3i(0, 0, 7), LADO, ALTO_PISO).y


func _malla_de(cid: int, forma: int, orientacion: int = OrientacionPared.EJE_X) -> Mesh:
	var ancho: int = _sprites.ancho_en_casillas(cid)
	var alto: int = _sprites.alto_en_casillas(cid)
	# Las cajas tienen materiales por item. No pueden compartir una malla cuyo
	# material de superficie se cambia al preparar el siguiente grupo.
	var clave := "%d_%d_%d_%d" % [forma, orientacion, ancho, alto]
	if forma == Forma.CAJA or forma == Forma.MUEBLE \
			or forma == Forma.PASAMANOS or forma == Forma.MONTANA:
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
		Forma.PASAMANOS:
			# Segmento 3D fijo: el sprite original queda en sus caras
			# principales y el volumen pequeno evita que el tramo parezca una
			# postal girando hacia la camara.
			var largo := LADO * float(maxi(ancho, alto))
			var tamano := Vector3(largo, ALTO_PASAMANOS, GROSOR_PASAMANOS)
			if orientacion == OrientacionPared.EJE_Z:
				tamano = Vector3(GROSOR_PASAMANOS, ALTO_PASAMANOS, largo)
			m = _malla_estructura(tamano, true, orientacion)
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
		return ALTO_PISO * 0.95
	if (cid >= 1081 and cid <= 1086) or (cid >= 1112 and cid <= 1122):
		return ALTURA_MONTANA_VISUAL
	if cid == 1127 or cid == 1128:
		# Son transiciones de montaña, pero en la vista 3D también deben cerrar
		# el intervalo completo entre z=7 y z=6. El sprite sigue siendo el mismo;
		# solo se corrige el volumen que lo sostiene.
		return ALTURA_MONTANA_VISUAL
	return ALTURA_MONTANA_VISUAL


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
	var familia_ankrahmun := _familia_pared_ankrahmun(cid, info) \
		if forma == Forma.CAJA else 0
	if familia_ankrahmun != 0:
		# Las tapas y los laterales estrechos deben tener el mismo acabado que
		# la cara principal; de lo contrario el muro cambia a marron al girar.
		estructura.surface_set_material(0,
			_material_pared_ankrahmun(familia_ankrahmun))
	else:
		estructura.surface_set_material(0, _material_estructura(forma, info))
	if forma == Forma.CAJA:
		if familia_ankrahmun != 0:
			# Las paredes authored son cajas, pero su cara visible conserva el
			# patron original de la pared de Tibia en vez de una paleta plana.
			estructura.surface_set_material(1,
				_material_pared_ankrahmun(familia_ankrahmun))
		else:
			estructura.surface_set_material(1, _material_estructura(forma, info, cid))
	else:
		estructura.surface_set_material(1, _material(cuadro, forma))


func _familia_pared_ankrahmun(cid: int, info: Dictionary) -> int:
	var nombre := String(info.get("nombre", "")).to_lower()
	if nombre != "sandstone wall":
		return 0
	if cid >= 1334 and cid <= 1340:
		return 2 # Arenisca gris de las piezas 1334-1340.
	if (cid >= 1305 and cid <= 1315) or (cid >= 1329 and cid <= 1333):
		return 1 # Arenisca dorada de las piezas principales de Ankrahmun.
	return 0


func _material_pared_ankrahmun(familia: int) -> ShaderMaterial:
	var clave := "__pared_ankrahmun_%d" % familia
	if _materiales.has(clave):
		return _materiales[clave]
	# 1316 contiene una baldosa de arenisca de 32x32 dentro de su cuadro de
	# 64x64. Usar solo esa zona opaca evita que el fondo transparente aparezca
	# como parches marrones y da una textura mas grande y limpia.
	var cid_muestra := 1316 if familia == 1 else 1334
	var cuadro: Dictionary = _sprites.cuadro_item(cid_muestra, 0)
	if cuadro.is_empty():
		return ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D pared_texture : source_color, filter_nearest;
uniform vec4 pared_region;
uniform vec2 repeticiones;
uniform vec3 color_base;

void fragment() {
    // La textura de suelo 1316 es un cuadrado opaco de arenisca, no un
    // sprite diagonal. Se repite pocas veces para que la pared conserve
    // detalle pixel-art sin convertir cada tramo en una tira de azulejos.
    vec2 uv = fract(UV * repeticiones);
    vec4 muestra = texture(pared_texture, pared_region.xy + uv * pared_region.zw);
    vec3 color = muestra.rgb;
    if (muestra.a < 0.5) {
        color = color_base;
    }
    // Sombra muy leve en el borde de cada bloque: da juntas de mamposteria
    // sin dibujar una cuadricula negra sobre el acabado original.
    float borde = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    color *= mix(0.86, 1.0, smoothstep(0.0, 0.07, borde));
    ALBEDO = color;
    ALPHA = 1.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("pared_texture", cuadro["lamina"])
	# sprites772 devuelve Vector3 (el tercer componente queda reservado para
	# la lamina); para el shader solo usamos los dos primeros componentes.
	var corrimiento: Vector3 = cuadro["corrimiento"]
	var escala: Vector3 = cuadro["escala"]
	var recorte := Vector4(0.0, 0.0, 0.5, 0.5) if familia == 1 else Vector4(
		31.0 / 64.0, 15.0 / 64.0, 16.0 / 64.0, 16.0 / 64.0)
	material.set_shader_parameter("pared_region", Vector4(
		corrimiento.x + escala.x * recorte.x,
		corrimiento.y + escala.y * recorte.y,
		escala.x * recorte.z, escala.y * recorte.w))
	material.set_shader_parameter("repeticiones",
		Vector2(1.0, 2.0) if familia == 1 else Vector2(1.0, 1.7))
	material.set_shader_parameter("color_base",
		Vector3(0.62, 0.48, 0.22) if familia == 1 else Vector3(0.40, 0.41, 0.42))
	_materiales[clave] = material
	return material


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


func _material(cuadro: Dictionary, forma: int, cid: int = -1,
		color_liquido: int = 0) -> Material:
	# Los pools son el liquido mismo y se pueden recolorear completos. Los
	# recipientes (viales) conservan su sprite: la UI pinta su contenido con
	# una mascara detras del recipiente, no con este material.
	if color_liquido > 0 and forma == Forma.ACOSTADA \
			and _es_pool_de_liquido(_catalogo.info_item(cid)):
		return _material_liquido(cuadro, forma, color_liquido)
	if forma == Forma.ACOSTADA and _es_borde_agua(cid):
		return _material_borde_agua(cuadro, forma)
	var clave: String = "%s_%d_%d" % [cuadro["clave"], forma, color_liquido]
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
	elif forma == Forma.CAJA or forma == Forma.MUEBLE \
			or forma == Forma.PASAMANOS:
		# Las caras estructurales se generan por separado y deben verse desde
		# cualquier giro de camara, igual que en la vista de la casa.
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materiales[clave] = mat
	return mat


func _material_liquido(cuadro: Dictionary, forma: int,
		color_liquido: int) -> ShaderMaterial:
	"""Recolorea un pool sin perder el alpha ni el pixel-art original.

	Los sprites base de los pools son azules porque el client ID es compartido
	por todos los FluidType. El servidor manda el color aparte; convertimos el
	brillo del sprite al color de ese byte y conservamos su silueta.
	"""
	var clave := "__liquido_%s_%d_%d" % [cuadro["clave"], forma, color_liquido]
	if _materiales.has(clave):
		return _materiales[clave]
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D liquido_texture : source_color, filter_nearest;
uniform vec4 liquido_region;
uniform vec3 tinte;

void fragment() {
	vec2 atlas_uv = liquido_region.xy + UV * liquido_region.zw;
	vec4 muestra = texture(liquido_texture, atlas_uv);
	float valor = max(max(muestra.r, muestra.g), muestra.b);
	ALBEDO = tinte * (0.35 + valor * 0.80);
	ALPHA = muestra.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("liquido_texture", cuadro["lamina"])
	material.set_shader_parameter("liquido_region", Vector4(
		cuadro["corrimiento"].x, cuadro["corrimiento"].y,
		cuadro["escala"].x, cuadro["escala"].y))
	var color := _color_de_liquido(color_liquido)
	material.set_shader_parameter("tinte", Vector3(color.r, color.g, color.b))
	_materiales[clave] = material
	return material


func _color_de_liquido(color_liquido: int) -> Color:
	# Es la misma paleta que usa la UI. El color 7 queda provisionalmente azul
	# de agua para mana fluid hasta definir la paleta final.
	match color_liquido:
		1: return Color(0.20, 0.58, 1.00, 1.0)
		2: return Color(1.00, 0.12, 0.08, 1.0)
		3: return Color(1.00, 0.67, 0.10, 1.0)
		4: return Color(0.18, 0.88, 0.24, 1.0)
		5: return Color(0.94, 0.86, 0.20, 1.0)
		6: return Color(0.96, 0.96, 1.00, 1.0)
		7: return Color(0.20, 0.58, 1.00, 1.0)
		_: return Color.WHITE


func _es_borde_agua(cid: int) -> bool:
	return cid in IDS_BORDES_AGUA


func _material_borde_agua(cuadro: Dictionary, forma: int) -> Material:
	"""Rellena la transparencia de una orilla con el sprite de grass 4515.

	Las piezas 4633-4644 traen solo la forma de la orilla: el area transparente
	se estaba mostrando como el color del cielo. El shader pone pasto debajo y
	encima conserva literalmente cada pixel opaco del sprite original, por lo
	que no cambia ni la franja marron ni el agua azul.
	"""
	var clave := "__borde_agua_pasto_%s_%d" % [cuadro["clave"], forma]
	if _materiales.has(clave):
		return _materiales[clave]
	var pasto: Dictionary = _sprites.cuadro_item(ID_SPRITE_PASTO_BORDE, 0)
	if pasto.is_empty():
		return _material(cuadro, forma)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D borde_texture : source_color, filter_nearest;
uniform sampler2D pasto_texture : source_color, filter_nearest;
uniform vec4 borde_region;
uniform vec4 pasto_region;

void fragment() {
	vec2 borde_uv = borde_region.xy + UV * borde_region.zw;
	vec2 pasto_uv = pasto_region.xy + UV * pasto_region.zw;
	vec4 borde = texture(borde_texture, borde_uv);
	vec4 pasto = texture(pasto_texture, pasto_uv);
	// La base siempre es pasto. Solo los pixeles opacos del sprite de orilla
	// lo reemplazan; asi el marron y el azul no se reinterpretan por color.
	vec4 resultado = mix(pasto, borde, step(0.5, borde.a));
	ALBEDO = resultado.rgb;
	ALPHA = resultado.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("borde_texture", cuadro["lamina"])
	material.set_shader_parameter("pasto_texture", pasto["lamina"])
	material.set_shader_parameter("borde_region", Vector4(
		cuadro["corrimiento"].x, cuadro["corrimiento"].y,
		cuadro["escala"].x, cuadro["escala"].y))
	material.set_shader_parameter("pasto_region", Vector4(
		pasto["corrimiento"].x, pasto["corrimiento"].y,
		pasto["escala"].x, pasto["escala"].y))
	_materiales[clave] = material
	return material


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
	# Las criaturas se actualizan con mucha mas frecuencia que el decorado.
	# Reutilizar sus mallas evita crear y destruir toda la escena en cada 0x6D;
	# esa reconstruccion era la causa del tiron cuando varios monsters caminaban.
	var visibles := {}
	var animaciones_nuevas: Array = []
	for id in _ids_criaturas_ordenados():
		# El jugador tiene una entidad visual propia para poder interpolar
		# entre confirmaciones del servidor sin duplicarlo como criatura.
		if int(id) == _estado.mi_id:
			continue
		var c: Dictionary = _estado.criaturas[id]
		# En el exterior alto la ventana visual abarca toda la ciudad de z=0 a
		# z=7: tambien deben verse los jugadores que caminan en la planta baja.
		# Bajo tierra se conserva la regla estricta del piso actual.
		if _estado.mi_pos.z <= 7:
			if c["pos"].z < 0 or c["pos"].z > 7:
				continue
		elif c["pos"].z != _estado.mi_pos.z:
			continue
		visibles[int(id)] = true
		# Monsters y NPCs son laminas verticales, como en Doom: se conserva el
		# recorte real del outfit y el material billboard gira la lamina hacia la
		# camara. No se modifica ni se genera ningun sprite nuevo.
		var tipo: int = c["apariencia"]
		var alto: float = clampf(_sprites.alto_de_outfit(tipo) * LADO * 0.72,
			LADO * 0.55, ALTO_PISO * 2.4)
		var direccion: int = int(c.get("direccion", 2))
		var cuadro: Dictionary = _sprites.cuadro_outfit(tipo, direccion, 0)
		var proporcion := 0.62
		if not cuadro.is_empty() and float(cuadro["escala"].y) > 0.0:
			proporcion = float(cuadro["escala"].x) / float(cuadro["escala"].y)
		var ancho := clampf(alto * proporcion, LADO * 0.45, LADO * 1.8)
		var m: MeshInstance3D = _nodos_criaturas.get(int(id))
		if not is_instance_valid(m):
			m = MeshInstance3D.new()
			m.set_meta("creature_id", int(id))
			_piso_bichos.add_child(m)
			_nodos_criaturas[int(id)] = m
		var lamina := m.mesh as QuadMesh
		if lamina == null or lamina.size != Vector2(ancho, alto):
			lamina = QuadMesh.new()
			lamina.size = Vector2(ancho, alto)
			m.mesh = lamina
		m.material_override = _material_de_criatura(cuadro) \
			if not cuadro.is_empty() else _material_cubo_criatura(c, cuadro)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.set_meta("creature_id", int(id))
		m.set_meta("server_name", str(c.get("nombre", "Creature")))
		var p: Vector3i = c["pos"]
		var posicion_3d := _posicion_visual_de_casilla(p, _centro_escenario)
		m.position = Vector3(posicion_3d.x, posicion_3d.y + alto * 0.5 + 0.02,
			posicion_3d.z)
		var fases: int = _sprites.fases_de_outfit(tipo, direccion)
		if fases > 1:
			animaciones_nuevas.append({"nodo": m, "id": int(id)})
	for id in _nodos_criaturas.keys():
		if not visibles.has(int(id)):
			var sobrante: Node = _nodos_criaturas[id]
			if is_instance_valid(sobrante):
				sobrante.free()
			_nodos_criaturas.erase(id)
	_animaciones_criaturas = animaciones_nuevas


func _ids_criaturas_ordenados() -> Array:
	"""Orden estable de composicion: piso, fila, columna e ID.

	El diccionario conserva el orden de llegada de los paquetes, no el orden
	visual del mapa. Ordenar aqui evita que un refresh cambie la composicion
	cuando varias criaturas ocupan o cruzan la misma zona.
	"""
	var ids: Array = _estado.criaturas.keys()
	ids.sort_custom(func(a, b):
		var ca: Dictionary = _estado.criaturas[a]
		var cb: Dictionary = _estado.criaturas[b]
		var pa: Vector3i = ca.get("pos", Vector3i.ZERO)
		var pb: Vector3i = cb.get("pos", Vector3i.ZERO)
		if pa.z != pb.z:
			return pa.z < pb.z
		if pa.y != pb.y:
			return pa.y < pb.y
		if pa.x != pb.x:
			return pa.x < pb.x
		return int(a) < int(b)
	)
	return ids


func _material_cubo_criatura(c: Dictionary, cuadro: Dictionary = {}) -> StandardMaterial3D:
	var tipo := int(c.get("apariencia", 0))
	var clave := "__criatura_cubo_%s" % (
		str(cuadro.get("clave", tipo)) if not cuadro.is_empty() else str(tipo))
	if _materiales.has(clave):
		return _materiales[clave]
	var mat := StandardMaterial3D.new()
	if cuadro.is_empty():
		mat.albedo_color = Color.from_hsv(fmod(float(tipo) * 0.137, 1.0), 0.64, 0.82)
	else:
		# BoxMesh usa el mismo recorte de atlas que las laminas del mapa:
		# cada cara del cubo conserva el sprite y no la lamina completa.
		mat.albedo_texture = cuadro["lamina"]
		mat.uv1_scale = cuadro["escala"]
		mat.uv1_offset = cuadro["corrimiento"]
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.texture_repeat = false
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
	mat.roughness = 0.82
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
				nodo.material_override = _material(cuadro, a["forma"],
					int(a["cid"]), int(a.get("color_liquido", 0)))


func _animar_criaturas() -> void:
	if _animaciones_criaturas.is_empty():
		return
	var fase := int(_reloj_animacion * FOTOGRAMAS_POR_SEGUNDO)
	for animacion in _animaciones_criaturas:
		var nodo: MeshInstance3D = animacion.get("nodo")
		if not is_instance_valid(nodo):
			continue
		var id := int(animacion.get("id", 0))
		var criatura: Dictionary = _estado.criaturas.get(id, {})
		if criatura.is_empty():
			continue
		var tipo := int(criatura.get("apariencia", 0))
		var direccion := int(criatura.get("direccion", 2))
		var cuadro: Dictionary = _sprites.cuadro_outfit(tipo, direccion, fase)
		if not cuadro.is_empty():
			nodo.material_override = _material_de_criatura(cuadro)


func _animar_efectos(delta: float) -> void:
	if _efectos_visuales.is_empty() or _camara == null \
			or _centro_escenario.x < -9000:
		return
	var restantes: Array = []
	for efecto in _efectos_visuales:
		var nodo = efecto.get("nodo")
		if not is_instance_valid(nodo):
			continue
		var tiempo := float(efecto.get("tiempo", 0.0)) + delta
		var duracion := maxf(0.05, float(efecto.get("duracion", 0.5)))
		efecto["tiempo"] = tiempo
		var progreso := clampf(tiempo / duracion, 0.0, 1.0)
		var tipo_visual := str(efecto.get("tipo", ""))
		if tipo_visual == "mensaje_centro":
			# El mensaje ya esta anclado al centro superior del viewport; no se
			# proyecta contra el mapa como los textos de combate.
			var entrada := clampf(progreso / 0.12, 0.0, 1.0)
			var salida := clampf((progreso - 0.68) / 0.32, 0.0, 1.0)
			nodo.modulate.a = lerpf(1.0, 0.0, salida)
			nodo.scale = Vector2.ONE * lerpf(0.94, 1.0, entrada)
		elif tipo_visual == "disparo" or tipo_visual == "proyectil":
			var desde: Vector3i = efecto.get("origen", Vector3i.ZERO)
			var hasta: Vector3i = efecto.get("destino", Vector3i.ZERO)
			var mundo_desde := COORD.tibia_a_mundo(desde, _centro_escenario,
				LADO, ALTO_PISO) + Vector3(0.0, 0.70, 0.0)
			var mundo_hasta := COORD.tibia_a_mundo(hasta, _centro_escenario,
				LADO, ALTO_PISO) + Vector3(0.0, 0.70, 0.0)
			var p_desde := _camara.unproject_position(mundo_desde)
			var p_hasta := _camara.unproject_position(mundo_hasta)
			var punto := p_desde.lerp(p_hasta, progreso)
			if tipo_visual == "proyectil":
				var fase_proyectil := int(tiempo * 12.0)
				var cuadro_proyectil: Dictionary = _sprites.cuadro_proyectil(
					int(efecto.get("proyectil", 0)), fase_proyectil)
				if not cuadro_proyectil.is_empty():
					nodo.texture = _textura_de_cuadro(cuadro_proyectil)
				nodo.position = punto - nodo.size * 0.5
				nodo.rotation = p_desde.angle_to_point(p_hasta)
			else:
				nodo.points = PackedVector2Array([p_desde, punto])
			nodo.modulate.a = 1.0 - progreso
		else:
			var posicion: Vector3i = efecto.get("posicion", Vector3i.ZERO)
			var mundo := COORD.tibia_a_mundo(posicion, _centro_escenario,
				LADO, ALTO_PISO) + Vector3(0.0, 0.78 + progreso * 0.42, 0.0)
			var pantalla := _camara.unproject_position(mundo)
			nodo.position = pantalla - Vector2(nodo.size.x * 0.5, nodo.size.y * 0.5)
			nodo.modulate.a = 1.0 - progreso
			if tipo_visual == "efecto":
				var fase_efecto := int(tiempo * FOTOGRAMAS_POR_SEGUNDO)
				var cuadro_efecto: Dictionary = _sprites.cuadro_efecto(
					int(efecto.get("efecto", 0)), fase_efecto)
				if not cuadro_efecto.is_empty():
					nodo.texture = _textura_de_cuadro(cuadro_efecto)
			elif tipo_visual == "marca":
				nodo.scale = Vector2.ONE * (0.70 + progreso * 0.70)
			elif tipo_visual == "acuñar":
				# Destello corto con rebote: funciona igual para oro, platino
				# y cristal porque el color viene del client id transformado.
				nodo.scale = Vector2.ONE * lerpf(0.72, 1.30, progreso)
				nodo.rotation = lerpf(-0.18, 0.18, progreso)
		if tiempo < duracion:
			restantes.append(efecto)
		else:
			nodo.queue_free()
	_efectos_visuales = restantes


func _animar_palancas(delta: float) -> void:
	if _animaciones_palanca.is_empty():
		return
	var restantes: Array = []
	for animacion in _animaciones_palanca:
		var nodo: MultiMeshInstance3D = animacion.get("nodo")
		if not is_instance_valid(nodo):
			continue
		var cid: int = int(animacion.get("cid", 0))
		var tiempo: float = float(animacion.get("tiempo", 0.0)) + delta
		animacion["tiempo"] = tiempo
		var estado_anterior: int = int(ESTADOS_PALANCA.get(cid, cid))
		var dibujo: int = estado_anterior \
				if tiempo < DURACION_ANIMACION_PALANCA * 0.45 else cid
		var cuadro: Dictionary = _sprites.cuadro_item(dibujo, 0)
		if not cuadro.is_empty():
			nodo.material_override = _material(cuadro, Forma.ACOSTADA, cid)
		if tiempo < DURACION_ANIMACION_PALANCA:
			restantes.append(animacion)
	_animaciones_palanca = restantes


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
		_avisar("Lower floors: hidden")
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
			_alto_pared_visual = ALTURA_PLANTA_VISUAL
			_grosor_pared_visual = LADO * 0.28
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
	_tiempo_dia_noche += delta
	if not _objeto_pendiente.is_empty():
		_objeto_pendiente["tiempo"] = float(_objeto_pendiente.get("tiempo", 0.0)) + delta
		if float(_objeto_pendiente["tiempo"]) >= 1.6:
			# El servidor no confirmó la operación. Se libera la entrada para
			# no dejar al jugador bloqueado por un objeto rechazado.
			_objeto_pendiente.clear()
			_liberar_movimiento_diferido()
	if _tiempo_dia_noche >= 0.5:
		_tiempo_dia_noche = 0.0
		_actualizar_dia_noche()
	_animar()
	_animar_criaturas()
	_tiempo_objetivo += delta
	_actualizar_indicador_objetivo()
	_animar_efectos(delta)
	_animar_palancas(delta)
	_animar_jugador(delta)
	_mover_camara(delta)
	_leer_teclas()


static func _factor_luz_dia(hora: float) -> float:
	"""Devuelve 0 de noche y 1 al mediodia, con amanecer/atardecer suaves."""
	var angulo := (hora - HORA_AMANECER) / (HORA_ATARDECER - HORA_AMANECER) * PI
	var factor := clampf(sin(angulo), 0.0, 1.0)
	# Suaviza solo la entrada/salida para que no haya un cambio de golpe.
	return factor * factor * (3.0 - 2.0 * factor)


static func _factor_luz_servidor(nivel: int) -> float:
	# El servidor 7.72 usa 51 como noche y 255 como dia.
	return clampf((float(nivel) - 51.0) / 204.0, 0.0, 1.0)


func _hora_local() -> float:
	var reloj: Dictionary = Time.get_time_dict_from_system()
	return float(reloj.get("hour", 12)) \
		+ float(reloj.get("minute", 0)) / 60.0 \
		+ float(reloj.get("second", 0)) / 3600.0


func _actualizar_dia_noche() -> void:
	if _sol == null or _entorno == null:
		return
	var dia: float
	var codigo_luz := 215
	if _estado != null and _estado.luz_mundo_recibida:
		# En el juego manda el 0x82 real del servidor. El reloj local solo
		# permite que el visor --mirar funcione sin levantar el servidor.
		dia = _factor_luz_servidor(int(_estado.luz_mundo_nivel))
		codigo_luz = int(_estado.luz_mundo_color)
	else:
		dia = _factor_luz_dia(_hora_local())
	_sol.light_energy = lerpf(0.14, 1.15, dia)
	var r := float(codigo_luz / 36) / 5.0
	var g := float((codigo_luz / 6) % 6) / 5.0
	var b := float(codigo_luz % 6) / 5.0
	var tinte_servidor := Color(clampf(r, 0.0, 1.0), clampf(g, 0.0, 1.0),
		clampf(b, 0.0, 1.0))
	_sol.light_color = Color(0.55, 0.65, 1.0).lerp(tinte_servidor, dia)
	_entorno.adjustment_brightness = lerpf(BRILLO_NOCHE, BRILLO_DIA, dia)
	_entorno.adjustment_contrast = lerpf(0.92, 1.0, dia)
	_entorno.adjustment_saturation = lerpf(0.82, 1.0, dia)
	_entorno.background_color = Color(0.025, 0.045, 0.09).lerp(
		Color(0.25, 0.42, 0.62), dia)
	_entorno.ambient_light_color = Color(0.16, 0.20, 0.34).lerp(
		Color(0.75, 0.78, 0.90), dia)
	_entorno.ambient_light_energy = lerpf(0.22, 0.90, dia)
	_entorno.fog_light_color = _entorno.background_color
	_entorno.fog_density = lerpf(0.025, 0.0, dia)


func _mover_camara(delta: float) -> void:
	if not _estado.adentro:
		return   # todavia no sabemos donde estamos parados
	var objetivo: Vector3
	if is_instance_valid(_jugador_nodo):
		objetivo = _jugador_nodo.position
		# El nodo del jugador puede estar interpolando entre casillas, pero la
		# camara no debe seguir ningun rebote visual. Solo acompana X/Z y usa
		# siempre la altura logica del piso.
		objetivo.y = _jugador_y_estable
	else:
		objetivo = COORD.tibia_a_mundo(_estado.mi_pos, _centro_escenario, LADO, ALTO_PISO)
		objetivo.y += 0.5
	var lejos := Vector3(
		sin(_giro) * cos(_inclinacion),
		sin(_inclinacion),
		cos(_giro) * cos(_inclinacion)) * _distancia
	var factor := 1.0 - exp(-SUAVIDAD_CAMARA * maxf(delta, 0.0))
	var destino := objetivo + lejos
	if not _camara_colocada:
		# La primera vez se pone en su lugar de una: si no, arranca en el
		# origen del mundo y viaja mil casillas cruzando todo el mapa.
		_camara_foco = objetivo
		destino = _camara_foco + lejos
		_camara.position = destino
		_camara_colocada = true
	else:
		# Filtrar tambien el punto al que mira evita que la rotacion siga el
		# paso confirmado de forma discreta aunque la posicion ya sea suave.
		_camara_foco = _camara_foco.lerp(objetivo, factor)
		destino = _camara_foco + lejos
		_camara.position = _camara.position.lerp(destino, factor)
	_camara.look_at(_camara_foco, Vector3.UP)


func _leer_teclas() -> void:
	if _solo_mirar or _muerto or not _estado.adentro \
			or (_interfaz != null and _interfaz.esta_escribiendo()) \
			or not _uso_con_pendiente.is_empty() \
			or _desde_ultimo_paso < ESPERA_ENTRE_PASOS:
		return
	# protocolgame.cpp:497-500 — norte, este, sur, oeste.
	if _con == null:
		return
	var direccion := _direccion_teclado()
	if direccion == Vector2i.ZERO:
		return
	if not _objeto_pendiente.is_empty():
		_direccion_diferida = direccion
		_objetivo_diferido = Vector3i(-9999, -9999, -9999)
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


func _cancelar_accion() -> void:
	_uso_con_pendiente.clear()
	_actualizar_cursor_uso()
	limpiar_objetivo_visual()
	if _solo_mirar or _con == null or not _estado.adentro:
		return
	_ataque_pendiente_id = 0
	_direccion_diferida = Vector2i.ZERO
	_objetivo_diferido = Vector3i(-9999, -9999, -9999)
	_acceso_reintento_pendiente = false
	_con.enviar_cancelar_accion()
	_avisar("Action cancelled.")


func _unhandled_input(evento: InputEvent) -> void:
	if _muerto:
		# Muerte confirmada: el mundo sigue dibujado detras de la pantalla de
		# reentrada, pero el cliente ya no pide nada mas.
		return
	if _interfaz != null and _interfaz.esta_escribiendo():
		if evento is InputEventKey and evento.pressed \
				and evento.keycode == KEY_ESCAPE:
			_interfaz.cancelar_chat()
			get_viewport().set_input_as_handled()
			return
		# El LineEdit consume sus propios clics por la fase GUI, pero los
		# eventos que ocurren sobre el mapa deben seguir llegando aca. Asi se
		# puede girar la camara con el boton derecho mientras se escribe.
	if evento is InputEventKey and evento.keycode == KEY_V:
		# V queda libre para el LineEdit del chat; fuera de él es pulsar-para-
		# hablar y debe recibir tanto el press como el release.
		if _interfaz != null and _interfaz.esta_escribiendo():
			return
		if _voz != null and _estado != null and _estado.adentro:
			_voz.procesar_tecla(evento)
			get_viewport().set_input_as_handled()
			return
	if not _uso_con_pendiente.is_empty():
		if evento is InputEventKey:
			if evento.pressed and not evento.echo and evento.keycode == KEY_ESCAPE:
				_cancelar_accion()
			get_viewport().set_input_as_handled()
			return
		if evento is InputEventMouseButton \
				and evento.button_index == MOUSE_BUTTON_RIGHT:
			if evento.pressed:
				_cancelar_accion()
			get_viewport().set_input_as_handled()
			return
		if evento is InputEventMouseButton \
				and evento.button_index == MOUSE_BUTTON_LEFT:
			if not evento.pressed:
				_usar_con_clic(evento.position)
			get_viewport().set_input_as_handled()
			return
		if evento is InputEventMouse:
			get_viewport().set_input_as_handled()
			return
	if evento is InputEventKey:
		if _procesar_ajuste_vivo(evento):
			return
		if evento.pressed and not evento.echo \
				and evento.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			if _interfaz != null:
				_interfaz.activar_chat()
				get_viewport().set_input_as_handled()
			return
		if evento.pressed and not evento.echo and evento.ctrl_pressed:
			match evento.keycode:
				KEY_G:
					solicitar_cambio_personaje()
				KEY_Q, KEY_L:
					solicitar_logout()
				KEY_K:
					if _interfaz != null and _estado.adentro:
						_interfaz.alternar_hotkeys()
				_:
					if _girar_en_sitio(evento.keycode):
						get_viewport().set_input_as_handled()
						return
			get_viewport().set_input_as_handled()
			return
		if evento.pressed and not evento.echo and evento.keycode == KEY_ESCAPE:
			_cancelar_accion()
			get_viewport().set_input_as_handled()
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
					_criatura_clic_derecho = 0
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
					_criatura_clic_derecho = _criatura_bajo_mouse(evento.position)
			else:
				var objetivo_derecho := _criatura_clic_derecho
				_boton_der = false
				_arrastrando = false
				if not _giro_movido and not _consumido:
					if objetivo_derecho != 0:
						atacar_criatura(objetivo_derecho)
					else:
						_usar_en_casilla(evento.position)
				_criatura_clic_derecho = 0
				_consumido = _boton_izq
		elif evento.button_index == MOUSE_BUTTON_WHEEL_UP and evento.pressed:
			if _interfaz != null and _interfaz.esta_sobre_interfaz():
				get_viewport().set_input_as_handled()
				return
			_distancia = maxf(4.0, _distancia - 1.5)
		elif evento.button_index == MOUSE_BUTTON_WHEEL_DOWN and evento.pressed:
			if _interfaz != null and _interfaz.esta_sobre_interfaz():
				get_viewport().set_input_as_handled()
				return
			_distancia = minf(40.0, _distancia + 1.5)
	elif evento is InputEventMouseMotion:
		if _arrastrando:
			if evento.relative.length() > UMBRAL_ARRASTRE_MOUSE:
				_giro_movido = true
				_criatura_clic_derecho = 0
			_giro -= deg_to_rad(evento.relative.x * 0.4)
			_inclinacion = clampf(_inclinacion + deg_to_rad(evento.relative.y * 0.3), 0.10, 1.45)
		elif _arrastre_objeto_pendiente and _boton_izq:
			var desplazamiento: float = evento.position.distance_to(_inicio_mouse_arrastre)
			if desplazamiento > UMBRAL_ARRASTRE_MOUSE:
				_arrastrando_objeto = true
				_arrastre_objeto_pendiente = false
				_consumido = true


func _input(evento: InputEvent) -> void:
	# El mapa es Node3D y no participa del drag-and-drop de Control. Capturamos
	# aqui el release cuando el destino es un slot del HUD.
	if not (_arrastrando_objeto and evento is InputEventMouseButton):
		return
	if evento.button_index != MOUSE_BUTTON_LEFT or evento.pressed:
		return
	if _interfaz == null or not _interfaz.recibir_objeto_del_mundo(
			evento.position, _origen_objeto, _objeto_arrastre):
		return
	_boton_izq = false
	_arrastrando_objeto = false
	_arrastre_objeto_pendiente = false
	_objeto_arrastre = {}
	_consumido = true
	get_viewport().set_input_as_handled()


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
	var destino = _casilla_visible_bajo_mouse(posicion_mouse)
	if destino == null:
		_avisar("You cannot throw there.")
		return
	if destino == origen:
		return
	var movimiento := _enviar_arrastre(origen, objeto, destino)
	if movimiento.is_empty():
		return
	print("[tvp3d] arrastrando client=%d stack=%d desde %s hacia %s" % [
		movimiento["client_id"], movimiento["stackpos"], origen, destino])
	if movimiento["criatura"]:
		_avisar("Pushing %s..." % str(movimiento["nombre"]))
	else:
		_avisar("Moving %s..." % str(movimiento["nombre"]))


func _enviar_arrastre(origen: Vector3i, objeto: Dictionary,
		destino: Vector3i) -> Dictionary:
	"""Convierte un drag en el 0x78 de 7.72.

	Para criaturas, Tibia usa client id 99 y cantidad 1. No se decide aca si
	la criatura es pushable: esa es una regla del servidor y puede variar por
	monster, NPC o permisos del personaje.
	"""
	if _con == null:
		return {}
	var cosa: Dictionary = objeto.get("cosa", {})
	var es_criatura: bool = cosa.get("tipo") == "criatura"
	var cid: int = 99 if es_criatura else int(cosa.get("cid", 0))
	var pila: int = int(objeto.get("stackpos", -1))
	if cid <= 0 or pila < 0:
		return {}
	var cantidad := 1 if es_criatura else int(cosa.get("cantidad", 1))
	_con.enviar_mover_cosa(origen, cid, pila, destino, cantidad)
	_objeto_pendiente = {
		"criatura": es_criatura,
		"id": int(cosa.get("id", 0)),
		"origen": origen,
		"destino": destino,
		"tiempo": 0.0,
	}
	return {
		"client_id": cid,
		"stackpos": pila,
		"cantidad": cantidad,
		"criatura": es_criatura,
		"nombre": str(cosa.get("nombre", "creature" if es_criatura else "item")),
	}


func recoger_objeto_en_ranura(origen: Vector3i, objeto: Dictionary,
		stackpos: int, tipo_destino: String, id_destino: int,
		ranura_destino: int, cantidad_override: int = -1) -> bool:
	"""Mueve un item del suelo a inventario/contenedor con el 0x78 real."""
	if _con == null or not _estado.adentro or stackpos < 0:
		return false
	var cosa: Dictionary = objeto.get("cosa", {})
	if cosa.get("tipo") != "item":
		return false
	var cid := int(cosa.get("cid", 0))
	if cid <= 0 or ranura_destino < 0:
		return false
	var destino := Vector3i(0xFFFF, ranura_destino, 0)
	if tipo_destino == "contenedor":
		if id_destino < 0:
			return false
		destino = Vector3i(0xFFFF, 0x40 | id_destino, ranura_destino)
	var total := clampi(int(cosa.get("cantidad", 1)), 1, 255)
	var cantidad := total if cantidad_override <= 0 else clampi(
		cantidad_override, 1, total)
	_con.enviar_mover_ubicacion(origen, cid, stackpos, destino, cantidad)
	_avisar("Picking up %s..." % str(cosa.get("nombre", "item")))
	return true


func soltar_inventario_en_mouse(posicion_mouse: Vector2, datos: Dictionary,
		cantidad_override: int = -1) -> void:
	"""Recibe un item de la interfaz y lo deja sobre el mundo."""
	if _con == null or not _estado.adentro:
		return
	var destino = _casilla_visible_bajo_mouse(posicion_mouse)
	if destino == null:
		_avisar("You cannot throw there.")
		return
	var cid := int(datos.get("cid", 0))
	var slot := int(datos.get("slot", -1))
	if cid <= 0 or slot < 0:
		return
	var total := clampi(int(datos.get("cantidad", 1)), 1, 255)
	var cantidad := total if cantidad_override <= 0 else clampi(
		cantidad_override, 1, total)
	var tipo: String = str(datos.get("tipo", "inventario"))
	if tipo == "contenedor":
		var id_contenedor := int(datos.get("contenedor", -1))
		if id_contenedor < 0:
			return
		_con.enviar_mover_ubicacion(Vector3i(0xFFFF, 0x40 | id_contenedor, slot),
			cid, 0, destino, cantidad)
	else:
		_con.enviar_mover_inventario(slot, cid, destino, cantidad)
	_avisar("Moving %s..." % str(datos.get("nombre", "item")))


func _objeto_movible_en_casilla(posicion: Vector3i) -> Dictionary:
	var cosas: Array = _estado.casillas.get(posicion, [])
	# La criatura se dibuja por encima de la pila del suelo. Si hay una rata
	# y ademas un objeto movible en la misma casilla, el cursor sobre el sprite
	# debe seleccionar la criatura para poder empujarla.
	for indice in range(cosas.size() - 1, -1, -1):
		var cosa: Dictionary = cosas[indice]
		if cosa.get("tipo") == "criatura":
			var id := int(cosa.get("id", 0))
			# El jugador tambien aparece en la pila del mapa, pero nunca se
			# puede iniciar un drag sobre si mismo.
			if id == _estado.mi_id or id <= 0:
				continue
			var criatura: Dictionary = _estado.criaturas.get(id, {})
			var arrastre := cosa.duplicate()
			arrastre["nombre"] = criatura.get("nombre", "creature")
			return {"cosa": arrastre, "stackpos": indice}
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


static func es_puerta_simple(cid: int, info: Dictionary) -> bool:
	if cid in IDS_PUERTAS_CON_PARAMETROS:
		return false
	var nombre := String(info.get("nombre", "")).to_lower()
	return nombre == "closed door" or nombre == "open door"


func _puerta_bajo_mouse(posicion_mouse: Vector2) -> Dictionary:
	"""Encuentra una puerta simple por su rectangulo vertical en pantalla.

	El map click tradicional proyecta el rayo contra el piso. Eso funciona para
	loseta y criaturas, pero la mitad superior de una puerta cae detras de ella
	y terminaba seleccionando la casilla vecina. Las puertas siguen siendo
	servidor-autoritativas; aqui solo elegimos la casilla y el stack correctos.
	"""
	if _camara == null or _centro_escenario.x < -9000 or not _estado.adentro:
		return {}

	# La vista estatica contiene el decorado y el estado vivo contiene las
	# transformaciones recientes. Un diccionario evita revisar dos veces una
	# casilla que esta en ambas fuentes.
	var posiciones := {}
	for donde in _mapa_visible.keys():
		if donde is Vector3i and _nivel_visible_para_interaccion(donde.z) \
				and absi(donde.x - _centro_escenario.x) <= RADIO \
				and absi(donde.y - _centro_escenario.y) <= RADIO:
			posiciones[donde] = true
	for donde in _estado.casillas.keys():
		if donde is Vector3i and _nivel_visible_para_interaccion(donde.z) \
				and absi(donde.x - _centro_escenario.x) <= RADIO \
				and absi(donde.y - _centro_escenario.y) <= RADIO:
			posiciones[donde] = true

	var elegido := {}
	var mejor_distancia := INF
	var mejor_profundidad := INF
	for donde in posiciones.keys():
		var ids: PackedInt32Array = _ids_de_casilla(donde)
		if ids.is_empty():
			continue
		if _estado.casillas.has(donde):
			var cosas: Array = _estado.casillas[donde]
			for indice in range(cosas.size() - 1, -1, -1):
				var cosa: Dictionary = cosas[indice]
				if cosa.get("tipo") != "item":
					continue
				var cid := int(cosa.get("cid", 0))
				var info: Dictionary = _catalogo.info_item(cid)
				if not es_puerta_simple(cid, info):
					continue
				var hit := _hit_puerta_en_pantalla(donde, cid, posicion_mouse)
				if hit.is_empty():
					continue
				var distancia := float(hit["distancia"])
				var profundidad := float(hit["profundidad"])
				if distancia < mejor_distancia \
						or (is_equal_approx(distancia, mejor_distancia) \
						and profundidad < mejor_profundidad):
					mejor_distancia = distancia
					mejor_profundidad = profundidad
					elegido = {"posicion": donde,
						"encontrado": {"cosa": cosa, "stackpos": indice}}
		else:
			for indice in range(ids.size() - 1, -1, -1):
				var cid := int(ids[indice])
				var info: Dictionary = _catalogo.info_item(cid)
				if not es_puerta_simple(cid, info):
					continue
				var hit := _hit_puerta_en_pantalla(donde, cid, posicion_mouse)
				if hit.is_empty():
					continue
				var distancia := float(hit["distancia"])
				var profundidad := float(hit["profundidad"])
				if distancia < mejor_distancia \
						or (is_equal_approx(distancia, mejor_distancia) \
						and profundidad < mejor_profundidad):
					mejor_distancia = distancia
					mejor_profundidad = profundidad
					var cosa: Dictionary = info.duplicate()
					cosa["tipo"] = "item"
					cosa["cid"] = cid
					cosa["cantidad"] = 1
					elegido = {"posicion": donde,
						"encontrado": {"cosa": cosa, "stackpos": indice}}
	return elegido


func _hit_puerta_en_pantalla(posicion: Vector3i, cid: int,
		posicion_mouse: Vector2) -> Dictionary:
	var mundo := _posicion_visual_de_casilla(posicion, _centro_escenario)
	var alto := maxf(float(_sprites.alto_en_casillas(cid)) * LADO, LADO * 0.80)
	var ancho := maxf(float(_sprites.ancho_en_casillas(cid)) * LADO, LADO * 0.70)
	var base := _camara.unproject_position(mundo + Vector3(0.0, 0.02, 0.0))
	var cima := _camara.unproject_position(mundo + Vector3(0.0, alto, 0.0))
	# La lamina usa BILLBOARD_FIXED_Y: uno de los dos ejes del mundo siempre
	# aporta el ancho horizontal visible. Tomamos el mayor para cubrir tambien
	# las vistas diagonales y el pequeno margen de textura transparente.
	var ancho_x := absf(_camara.unproject_position(
		mundo + Vector3(ancho * 0.5, 0.0, 0.0)).x - base.x)
	var ancho_z := absf(_camara.unproject_position(
		mundo + Vector3(0.0, 0.0, ancho * 0.5)).x - base.x)
	var ancho_pantalla := maxf(18.0, maxf(ancho_x, ancho_z) * 1.25)
	if posicion_mouse.x < base.x - ancho_pantalla \
			or posicion_mouse.x > base.x + ancho_pantalla \
			or posicion_mouse.y < minf(base.y, cima.y) - 8.0 \
			or posicion_mouse.y > maxf(base.y, cima.y) + 8.0:
		return {}
	var centro := _camara.unproject_position(mundo + Vector3(0.0, alto * 0.5, 0.0))
	var profundidad := -(_camara.global_transform.affine_inverse() \
			* (mundo + Vector3(0.0, alto * 0.5, 0.0))).z
	return {"distancia": posicion_mouse.distance_to(centro),
		"profundidad": profundidad}


func _usar_en_casilla(posicion_mouse: Vector2) -> void:
	var puerta := _puerta_bajo_mouse(posicion_mouse)
	var posicion = puerta.get("posicion", _casilla_bajo_mouse(posicion_mouse))
	if posicion == null or posicion.z != _estado.mi_pos.z or _con == null:
		return
	var encontrado: Dictionary = puerta.get("encontrado", {})
	if encontrado.is_empty():
		encontrado = _item_para_usar_en_casilla(posicion)
	if encontrado.is_empty():
		_avisar("There is nothing to use here.")
		return
	var cosa: Dictionary = encontrado["cosa"]
	var cid := int(cosa.get("cid", 0))
	var pila := int(encontrado["stackpos"])
	var indice := 0
	if bool(cosa.get("contenedor", false)):
		# El ultimo byte de 0x82 es el ID de la ventana. Usar siempre 0
		# reemplazaba la mochila del jugador al abrir un cadaver o cualquier
		# contenedor del mapa. Las aperturas nuevas deben ocupar un ID libre.
		indice = _indice_contenedor_libre()
		if indice < 0:
			_avisar("No more container windows available.")
			return
	print("[tvp3d] usando client=%d stack=%d en %s" % [cid, pila, posicion])
	_con.enviar_usar_item(posicion, cid, pila, indice)
	_avisar("Using %s..." % str(cosa.get("nombre", "item")))


func _indice_contenedor_libre() -> int:
	if _estado == null:
		return 0
	for indice in range(16):
		if not _estado.contenedores.has(indice):
			return indice
	return -1


func _mirar_en_casilla(posicion_mouse: Vector2) -> void:
	var criatura_id := _criatura_bajo_mouse(posicion_mouse)
	if criatura_id != 0:
		var criatura: Dictionary = _estado.criaturas.get(criatura_id, {})
		var posicion_criatura: Vector3i = criatura.get("pos",
			Vector3i(-9999, -9999, -9999))
		if posicion_criatura.x > -9000:
			_seleccionar_inspector(posicion_criatura)
			if _con != null and _estado.adentro:
				# STACKPOS_LOOK hace que el servidor elija la criatura visible de
				# esa casilla, incluso cuando esta en la planta baja z=7.
				_con.enviar_mirar(posicion_criatura, 0, 0)
				_avisar("Looking at %s (%d, %d, %d)..." % [
					str(criatura.get("nombre", "Creature")),
					posicion_criatura.x, posicion_criatura.y, posicion_criatura.z])
			return
	var puerta := _puerta_bajo_mouse(posicion_mouse)
	var posicion = puerta.get("posicion",
		_casilla_visible_bajo_mouse(posicion_mouse))
	if posicion == null:
		return
	_seleccionar_inspector(posicion)
	if _con != null and _estado.adentro:
		# 0x8C usa la casilla y el objeto visible que resuelve el servidor.
		# Para una puerta simple enviamos tambien su sprite/stackpos, igual que
		# el uso 0x82, para que el look siga el objeto vertical bajo el cursor.
		var client_id := 0
		var stackpos := 0
		if not puerta.is_empty():
			var encontrado: Dictionary = puerta.get("encontrado", {})
			var cosa: Dictionary = encontrado.get("cosa", {})
			client_id = int(cosa.get("cid", 0))
			stackpos = int(encontrado.get("stackpos", 0))
		_con.enviar_mirar(posicion, client_id, stackpos)
		_avisar("Looking at (%d, %d, %d)..." % [posicion.x, posicion.y, posicion.z])


func _caminar_a_casilla(posicion_mouse: Vector2) -> void:
	if _solo_mirar or _con == null or not _estado.adentro:
		return
	var criatura_clickeada := _criatura_bajo_mouse(posicion_mouse)
	if criatura_clickeada != 0:
		atacar_criatura(criatura_clickeada)
		return
	var objetivo = _casilla_bajo_mouse(posicion_mouse)
	if objetivo == null or objetivo.z != _estado.mi_pos.z:
		return
	var criatura_id := _criatura_en_casilla(objetivo)
	if criatura_id != 0:
		atacar_criatura(criatura_id)
		return
	_caminar_a_objetivo(objetivo)


func atacar_criatura(id: int) -> bool:
	"""Selecciona un monster con el protocolo real 0xA1.

	Los NPC comparten la estructura de criatura en el mapa, pero el servidor
	los reserva en el rango 0x80000000+. Para ellos un clic es una conversacion,
	no un ataque.

	Si esta fuera del rango que acepta el servidor, primero camina hasta la
	primera casilla caminable dentro de rango y envia el ataque al confirmarse
	ese paso. No se pisa la casilla ocupada por la criatura.
	"""
	if _solo_mirar or _con == null or not _estado.adentro:
		return false
	var criatura: Dictionary = _estado.criaturas.get(id, {})
	if criatura.is_empty() or int(id) == _estado.mi_id:
		return false
	if _es_npc(id):
		return hablar_con_npc(id)
	fijar_objetivo_visual(id)
	if _interfaz != null and _interfaz.has_method("mostrar_objetivo"):
		_interfaz.mostrar_objetivo(id)
	var posicion: Vector3i = criatura.get("pos", Vector3i(-9999, -9999, -9999))
	if _en_rango_ataque(_estado.mi_pos, posicion):
		_ataque_pendiente_id = 0
		_con.enviar_atacar(id)
		_avisar("Attacking %s..." % str(criatura.get("nombre", "Creature")))
		return true
	var camino := _buscar_ruta_hasta_rango(_estado.mi_pos, posicion)
	if camino.is_empty():
		_avisar("No reachable attack position.")
		return false
	_ataque_pendiente_id = id
	_con.enviar_auto_camino(camino)
	_avisar("Approaching %s..." % str(criatura.get("nombre", "Creature")))
	return true


func _es_npc(id: int) -> bool:
	return es_npc(id)


func es_npc(id: int) -> bool:
	return id >= ID_MINIMO_NPC


func hablar_con_npc(id: int) -> bool:
	"""Habla con el NPC usando el mismo SAY que acepta el cliente clasico.

	El servidor valida la distancia, el foco y el comportamiento Lua/NPC. Si
	esta fuera de rango, el cliente solo busca una casilla vecina caminable y
	manda `hi` despues de confirmar la llegada.
	"""
	if _solo_mirar or _con == null or not _estado.adentro or not _es_npc(id):
		return false
	var npc: Dictionary = _estado.criaturas.get(id, {})
	if npc.is_empty():
		return false
	var posicion: Vector3i = npc.get("pos", Vector3i(-9999, -9999, -9999))
	if posicion.z != _estado.mi_pos.z:
		_avisar("That NPC is on another floor.")
		return false
	fijar_objetivo_visual(id)
	if _interfaz != null and _interfaz.has_method("mostrar_objetivo"):
		_interfaz.mostrar_objetivo(id)
	if _en_rango_ataque(_estado.mi_pos, posicion, RANGO_DIALOGO_NPC):
		_npc_hablar_pendiente_id = 0
		_con.enviar_hablar("hi")
		_avisar("Talking to %s..." % str(npc.get("nombre", "NPC")))
		return true
	var camino := _buscar_ruta_hasta_rango(_estado.mi_pos, posicion,
		RANGO_DIALOGO_NPC)
	if camino.is_empty():
		_avisar("No reachable NPC.")
		return false
	_npc_hablar_pendiente_id = id
	_ataque_pendiente_id = 0
	_con.enviar_auto_camino(camino)
	_avisar("Approaching %s..." % str(npc.get("nombre", "NPC")))
	return true


func _intentar_ataque_pendiente() -> void:
	if _ataque_pendiente_id == 0 or _con == null:
		return
	var criatura: Dictionary = _estado.criaturas.get(_ataque_pendiente_id, {})
	if criatura.is_empty():
		_ataque_pendiente_id = 0
		return
	var posicion: Vector3i = criatura.get("pos", Vector3i(-9999, -9999, -9999))
	if not _en_rango_ataque(_estado.mi_pos, posicion):
		return
	var id := _ataque_pendiente_id
	_ataque_pendiente_id = 0
	_con.enviar_atacar(id)
	_avisar("Attacking %s..." % str(criatura.get("nombre", "Creature")))


func _intentar_hablar_npc_pendiente() -> void:
	if _npc_hablar_pendiente_id == 0 or _con == null:
		return
	var npc: Dictionary = _estado.criaturas.get(_npc_hablar_pendiente_id, {})
	if npc.is_empty():
		_npc_hablar_pendiente_id = 0
		return
	var posicion: Vector3i = npc.get("pos", Vector3i(-9999, -9999, -9999))
	if not _en_rango_ataque(_estado.mi_pos, posicion, RANGO_DIALOGO_NPC):
		return
	_npc_hablar_pendiente_id = 0
	_con.enviar_hablar("hi")
	_avisar("Talking to %s..." % str(npc.get("nombre", "NPC")))


static func _en_rango_ataque(origen: Vector3i, destino: Vector3i,
		rango: int = 8) -> bool:
	return origen.z == destino.z and absi(origen.x - destino.x) <= rango \
		and absi(origen.y - destino.y) <= rango


func _criatura_en_casilla(posicion: Vector3i) -> int:
	for id in _ids_criaturas_ordenados():
		if int(id) == _estado.mi_id:
			continue
		if _estado.criaturas[id].get("pos") == posicion:
			return int(id)
	return 0


func _criatura_bajo_mouse(posicion_mouse: Vector2) -> int:
	"""Detecta el cuerpo 3D antes de proyectar el clic al suelo.

	El rayo matematico del map click cruza el piso, asi que un clic sobre la
	 cabeza de un monster podia terminar en la casilla de atras. La posicion
	 sigue viniendo del estado del servidor; solo usamos su proyeccion para
	 elegir la criatura que el usuario realmente pulso.
	"""
	if _camara == null:
		return 0
	var elegido := 0
	var mejor_distancia := INF
	for id in _ids_criaturas_ordenados():
		if int(id) == _estado.mi_id:
			continue
		var criatura: Dictionary = _estado.criaturas[id]
		var posicion: Vector3i = criatura.get("pos", Vector3i(-9999, -9999, -9999))
		if not _nivel_visible_para_interaccion(posicion.z):
			continue
		var alto := clampf(_sprites.alto_de_outfit(int(criatura.get("apariencia", 0))) * LADO * 0.72,
			LADO * 0.55, ALTO_PISO * 2.4)
		var mundo := _posicion_visual_de_casilla(posicion, _centro_escenario)
		var base := _camara.unproject_position(mundo + Vector3(0.0, 0.02, 0.0))
		var cabeza := _camara.unproject_position(mundo + Vector3(0.0, alto, 0.0))
		var altura_pantalla := maxf(18.0, absf(base.y - cabeza.y))
		var ancho_pantalla := maxf(18.0, altura_pantalla * 0.42)
		if posicion_mouse.x < base.x - ancho_pantalla \
			or posicion_mouse.x > base.x + ancho_pantalla \
			or posicion_mouse.y < minf(base.y, cabeza.y) - 8.0 \
			or posicion_mouse.y > maxf(base.y, cabeza.y) + 8.0:
			continue
		var distancia := posicion_mouse.distance_to(Vector2(base.x, (base.y + cabeza.y) * 0.5))
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			elegido = int(id)
	return elegido


func caminar_a_casilla_desde_minimapa(celda: Vector2i) -> void:
	"""Entrada publica para el map click del minimapa clasico."""
	if _solo_mirar or _con == null or not _estado.adentro:
		return
	_caminar_a_objetivo(Vector3i(celda.x, celda.y, _estado.mi_pos.z))


func _caminar_a_objetivo(objetivo: Vector3i) -> void:
	if objetivo == _estado.mi_pos:
		return
	if not _objeto_pendiente.is_empty():
		_objetivo_diferido = objetivo
		_direccion_diferida = Vector2i.ZERO
		_avisar("Finishing object action...")
		return
	# Un map click expresa un destino, no una orden diagonal. El camino
	# ortogonal evita que el cliente envie diagonales que el jugador nunca
	# solicito; Q/E/Z/C y numpad conservan las diagonales explicitas.
	var camino := _buscar_ruta(_estado.mi_pos, objetivo, false)
	if camino.is_empty():
		_avisar("No path.")
		return
	_con.enviar_auto_camino(camino)
	_avisar("Walking to (%d, %d, %d)..." % [objetivo.x, objetivo.y, objetivo.z])


func _confirmar_objeto_pendiente(posicion: Vector3i = Vector3i(-9999, -9999, -9999)) -> void:
	if _objeto_pendiente.is_empty():
		return
	var origen: Vector3i = _objeto_pendiente.get("origen", Vector3i(-9999, -9999, -9999))
	var destino: Vector3i = _objeto_pendiente.get("destino", Vector3i(-9999, -9999, -9999))
	var confirmado := false
	if bool(_objeto_pendiente.get("criatura", false)):
		var id := int(_objeto_pendiente.get("id", 0))
		var criatura: Dictionary = _estado.criaturas.get(id, {})
		confirmado = not criatura.is_empty() \
				and criatura.get("pos", origen) == destino
	else:
		confirmado = posicion == destino
	if confirmado:
		_objeto_pendiente.clear()
		_liberar_movimiento_diferido()


func _liberar_movimiento_diferido() -> void:
	if _con == null or not _estado.adentro:
		_direccion_diferida = Vector2i.ZERO
		_objetivo_diferido = Vector3i(-9999, -9999, -9999)
		return
	var objetivo := _objetivo_diferido
	var direccion := _direccion_diferida
	_objetivo_diferido = Vector3i(-9999, -9999, -9999)
	_direccion_diferida = Vector2i.ZERO
	if objetivo.x > -9000:
		_caminar_a_objetivo(objetivo)
		return
	if direccion == Vector2i.ZERO:
		return
	var opcode := _opcode_de_direccion(direccion)
	if opcode != 0:
		_con.enviar_juego(PackedByteArray([opcode]))
		_desde_ultimo_paso = 0.0


func _buscar_ruta_hasta_rango(origen: Vector3i, objetivo: Vector3i,
		rango: int = 8) -> Array:
	if _en_rango_ataque(origen, objetivo, rango):
		return []
	var abiertos: Array = [origen]
	var cabeza := 0
	var anterior := {origen: origen}
	var margen := 12
	var min_x := mini(origen.x, objetivo.x) - margen
	var max_x := maxi(origen.x, objetivo.x) + margen
	var min_y := mini(origen.y, objetivo.y) - margen
	var max_y := maxi(origen.y, objetivo.y) + margen
	while cabeza < abiertos.size() and abiertos.size() <= MAX_CASILLAS_RUTA:
		var actual: Vector3i = abiertos[cabeza]
		cabeza += 1
		if actual != origen and _en_rango_ataque(actual, objetivo, rango):
			return _reconstruir_ruta(anterior, origen, actual)
		for delta in [Vector3i(0, -1, 0), Vector3i(1, 0, 0),
				Vector3i(0, 1, 0), Vector3i(-1, 0, 0)]:
			var vecino: Vector3i = actual + delta
			if vecino.x < min_x or vecino.x > max_x \
					or vecino.y < min_y or vecino.y > max_y:
				continue
			if anterior.has(vecino) or _casilla_bloqueada(vecino):
				continue
			anterior[vecino] = actual
			abiertos.append(vecino)
	return []


func _reconstruir_ruta(anterior: Dictionary, origen: Vector3i,
				destino: Vector3i) -> Array:
	var camino: Array = []
	var cursor := destino
	while cursor != origen:
		if not anterior.has(cursor):
			return []
		var padre: Vector3i = anterior[cursor]
		camino.push_front(Vector2i(cursor.x - padre.x, cursor.y - padre.y))
		cursor = padre
	return camino if camino.size() <= 128 else []


func _casilla_bajo_mouse(posicion_mouse: Vector2):
	if _camara == null or _centro_escenario.x < -9000 or not _estado.adentro:
		return null
	return _casilla_en_nivel_bajo_mouse(posicion_mouse, _estado.mi_pos.z)


func _nivel_visible_para_interaccion(nivel: int) -> bool:
	if _estado == null:
		return false
	# En la vista exterior de una piramide el mundo jugable visible es z=0..7.
	# Los pisos subterraneos no participan en look ni en throw.
	if _estado.mi_pos.z <= 7:
		return nivel >= 0 and nivel <= 7
	return nivel == _estado.mi_pos.z


func _casilla_en_nivel_bajo_mouse(posicion_mouse: Vector2, nivel: int):
	if _camara == null or _centro_escenario.x < -9000 or not _estado.adentro:
		return null
	if not _nivel_visible_para_interaccion(nivel):
		return null
	var origen := _camara.project_ray_origin(posicion_mouse)
	var direccion := _camara.project_ray_normal(posicion_mouse)
	var piso := _posicion_visual_de_casilla(Vector3i(_estado.mi_pos.x,
		_estado.mi_pos.y, nivel), _centro_escenario).y
	if absf(direccion.y) < 0.0001:
		return null
	var distancia := (piso - origen.y) / direccion.y
	if distancia < 0.0:
		return null
	var punto := origen + direccion * distancia
	# La altura ya esta fijada al piso del jugador. Convertir X/Z por
	# separado evita que un pequeno error vertical del rayo cambie tambien Z.
	var tile := Vector3i(
		_centro_escenario.x + floori(punto.x / LADO + 0.5),
		_centro_escenario.y + floori(punto.z / LADO + 0.5),
		nivel)
	if absi(tile.x - _centro_escenario.x) > RADIO or absi(tile.y - _centro_escenario.y) > RADIO:
		return null
	return tile


func _casilla_visible_bajo_mouse(posicion_mouse: Vector2):
	"""Resuelve un clic sobre cualquiera de los niveles visibles.

	El movimiento normal sigue usando la planta del jugador. Look y throw, en
	cambio, pueden apuntar al suelo de la ciudad cuando el jugador esta arriba.
	"""
	if _camara == null or _centro_escenario.x < -9000 or not _estado.adentro:
		return null
	var niveles: Array[int] = []
	# La interacción debe permanecer en el piso autoritativo del personaje.
	# Explorar visualmente pisos superiores es válido para el render, pero usar
	# su proyección para look/use hacía que una cama de Flat 01 resolviera la
	# puerta o cama homóloga de Flat 11/21.
	niveles.append(_estado.mi_pos.z)
	var elegido = null
	var mejor_distancia := INF
	for nivel in niveles:
		var tile = _casilla_en_nivel_bajo_mouse(posicion_mouse, nivel)
		if tile == null:
			continue
		var visual := _posicion_visual_de_casilla(tile, _centro_escenario)
		var pantalla := _camara.unproject_position(visual + Vector3(0.0, 0.03, 0.0))
		var distancia := posicion_mouse.distance_to(pantalla)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			elegido = tile
	return elegido


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
	return _ir_trozos.tile_en(posicion)


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
	if _mapa_visible.has(posicion):
		return _mapa_visible[posicion]
	# El minimapa puede apuntar a una casilla que aun no entro en la ventana
	# 3D (por ejemplo, mientras el refresco cercano termina). No convertir la
	# ausencia temporal de render en una pared: el mapa del disco es la fuente
	# estatica completa para rutas y conserva tambien los accesos de piso.
	if _disco != null:
		return _disco.ids_de(posicion)
	return PackedInt32Array()


func _casilla_bloqueada(posicion: Vector3i) -> bool:
	# Las casillas que el servidor ya describio tienen prioridad: pueden
	# contener cambios en vivo y no deben quedar en la cache del mapa.
	if not _estado.casillas.has(posicion) and _bloqueo_disco_cache.has(posicion):
		return _bloqueo_disco_cache[posicion]
	var ids := _ids_de_casilla(posicion)
	var bloqueada := ids.is_empty()
	var ir_tile := _tile_ir(posicion)
	var tiene_ir: bool = not _estado.casillas.has(posicion) \
			and (ir_tile.has("walkable") or ir_tile.has("queryadd_walkable"))
	if tiene_ir:
		# El IR conserva las dos decisiones que ya producen los scripts del
		# mapa: walkable descarta bloqueos solidos y queryadd_walkable descarta
		# el camino que Tile::queryAdd no acepta para pathfinding.
		bloqueada = false
		if ir_tile.has("walkable") and not bool(ir_tile.get("walkable", false)):
			bloqueada = true
		if ir_tile.has("queryadd_walkable"):
			if ir_tile.get("queryadd_walkable") == null \
					or not bool(ir_tile.get("queryadd_walkable", false)):
				bloqueada = true
		# walkable/queryadd_walkable describen el pathfinding del servidor y
		# excluyen los floorchange por diseno. Para una escalera, trapdoor o
		# alcantarilla la entrada normal si esta permitida; solo se excluye del
		# camino una vez que ya se convirtio en el destino final.
		if bloqueada and _casilla_tiene_paso_automatico(posicion):
			bloqueada = false
	else:
		for cid in ids:
			var info: Dictionary = _catalogo.info_item(cid)
			# En datos vivos o fuera de la region IR, usar las mismas banderas
			# de items como respaldo conservador.
			if info.get("block_pathfind", false) or info.get("bloquea", false):
				bloqueada = true
				break
		# Una escalera viva puede tener block_pathfind por el propio DAT, pero
		# el IR ya la identifica como el acceso que debe poder pisarse.
		if bloqueada and _casilla_tiene_paso_automatico(posicion):
			bloqueada = false
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
			# El acceso de piso puede ser un tramo intermedio de la ruta: el
			# servidor decide si el paso cambia de nivel o si solo deja al
			# personaje sobre la escalera/alcantarilla.
			if _casilla_bloqueada(siguiente):
				continue
			anterior[siguiente] = actual
			abiertos.append(siguiente)
	return []
