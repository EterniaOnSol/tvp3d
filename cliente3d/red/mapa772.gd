extends RefCounted

# =====================================================================
#  El mapa que manda el servidor, traducido a casillas. Protocolo 7.72.
#
#  Todo esto sale de leer el C++ del servidor:
#
#    src/protocolgame.cpp:616  GetMapDescription   -> los pisos
#    src/protocolgame.cpp:641  GetFloorDescription -> los saltos
#    src/protocolgame.cpp:566  GetTileDescription  -> una casilla
#    src/protocolgame.cpp:2243 AddCreature         -> una criatura
#    src/protocolgame.cpp:2325 AddOutfit           -> como se ve
#    src/networkmessage.cpp:95 addItem             -> un item
#
#  COMO VIENE EL MAPA
#
#  Se recorren los pisos de arriba hacia abajo (del 7 al 0) y, en cada
#  piso, casillero por casillero: primero todas las Y de una X, despues
#  la X siguiente (protocolgame.cpp:643-644). Cada casillero es una de
#  dos cosas:
#
#    - "salto": dos bytes donde el segundo es 0xFF. El primero dice
#      cuantos casilleros vacios hubo.
#    - una casilla de verdad: hasta 10 cosas, una atras de la otra.
#
#  LA TRAMPA DEL CONTADOR (protocolgame.cpp:618, `int32_t skip = -1`)
#
#  El contador de vacios arranca en -1 y no en 0, y vuelve a -1 cada vez
#  que completa una tanda de 255 (linea 657). Eso hace que la PRIMERA
#  marca despues de cada reinicio cuente uno menos que los vacios que
#  realmente hubo. Sin esta correccion el mapa entero sale corrido — y el
#  sintoma enganya, porque la cantidad de BYTES da bien.
#
#  LO OTRO QUE HAY QUE SABER DE ANTES
#
#  Cuantos bytes ocupa un item depende de sus banderas: los apilables
#  traen un byte de cantidad y los liquidos uno de color
#  (networkmessage.cpp:101-105). No hay ninguna marca que lo avise. Por
#  eso hace falta assets/items772.json, que sale del propio servidor con
#  herramientas/extraer_items772.py.
# =====================================================================

const ARCHIVO_ITEMS := "res://assets/items772.json"
const ARCHIVO_RENDER_FLAGS := "res://assets/items772_flags.json"

## Marcas que ocupan el lugar de un id de item (protocolgame.cpp:2248-2251).
const CRIATURA_DESCONOCIDA := 0x61
const CRIATURA_CONOCIDA := 0x62
const CRIATURA_YA_VISTA := 0x63

## La ventana que ve el cliente: maxClientViewportX/Y = 8 y 6 (map.h:181),
## y el servidor manda (8*2)+2 x (6*2)+2 (protocolgame.cpp:1699).
const ANCHO := 18
const ALTO := 14

var _items := {}
var _render_flags := {}
var _sin_datos := 0   ## items que llegaron y no estaban en el catalogo

# --- estado mientras se lee una descripcion de mapa ---
var _salto := 0
var _menos_uno := true


func _init() -> void:
	var f := FileAccess.open(ARCHIVO_ITEMS, FileAccess.READ)
	if f == null:
		push_error("Falta %s. Corre herramientas/extraer_items772.py" % ARCHIVO_ITEMS)
		return
	var datos = JSON.parse_string(f.get_as_text())
	if typeof(datos) == TYPE_DICTIONARY:
		_items = datos

	var ff := FileAccess.open(ARCHIVO_RENDER_FLAGS, FileAccess.READ)
	if ff != null:
		var banderas = JSON.parse_string(ff.get_as_text())
		if typeof(banderas) == TYPE_DICTIONARY:
			var por_item = banderas.get("items", banderas)
			if typeof(por_item) == TYPE_DICTIONARY:
				_render_flags = por_item


func info_item(cid: int) -> Dictionary:
	return _items.get(str(cid), {})


func puede_leer_cosa(msg) -> bool:
	"""Valida el tamaño de un item serializado por NetworkMessage::addItem.

	En 7.72 todos los items empiezan con client id. Solo los apilables y los
	liquids llevan un byte adicional, y esa bandera sale del catálogo generado
	desde el servidor. No se debe leer un item incompleto porque el siguiente
	opcode quedaría interpretado como cantidad/color.
	"""
	if msg.sin_leer() < 2:
		return false
	var cid: int = msg.espiar_u16()
	var info := info_item(cid)
	var extra := 1 if bool(info.get("apilable", false)) \
		or bool(info.get("liquido", false)) else 0
	return msg.sin_leer() >= 2 + extra


func es_borde_suelo(cid: int) -> bool:
	return bool(_render_flags.get(str(cid), {}).get("borde_suelo", false))


func va_abajo(cid: int) -> bool:
	return bool(_render_flags.get(str(cid), {}).get("abajo", false))


# --------------------------------------------------------------------
#  Una tanda de casillas
# --------------------------------------------------------------------
func leer_descripcion(msg, x0: int, y0: int, z0: int, ancho: int, alto: int) -> Dictionary:
	var casillas := {}
	var criaturas := []

	# protocolgame.cpp:621-629 — de que piso a que piso, y en que sentido.
	var desde := 7
	var hasta := 0
	var paso := -1
	if z0 > 7:
		desde = z0 - 2
		hasta = mini(15, z0 + 2)
		paso = 1

	var pisos := []
	var z := desde
	while true:
		pisos.append([z, z0 - z])
		if z == hasta:
			break
		z += paso

	return leer_pisos(msg, x0, y0, ancho, alto, pisos)


func leer_pisos(msg, x0: int, y0: int, ancho: int, alto: int, pisos: Array) -> Dictionary:
	"""Lee varios pisos seguidos COMPARTIENDO el contador de vacios, que es
	como los manda el servidor: `skip` se declara una sola vez y se pasa por
	referencia a cada piso (protocolgame.cpp:618-633). Los cambios de piso
	(0xBE / 0xBF) mandan una lista de pisos distinta a la normal, por eso
	esto esta separado."""
	var casillas := {}
	var criaturas := []

	_salto = 0
	_menos_uno = true
	for piso in pisos:
		_leer_piso(msg, x0, y0, piso[0], ancho, alto, piso[1], casillas, criaturas)

	# Al final el servidor cierra con un ultimo "salto" si le quedo uno
	# pendiente (protocolgame.cpp:635-638). Puede haberlo consumido el bucle
	# o no, asi que se mira antes de tocarlo.
	if msg.sin_leer() >= 2 and msg.espiar_u16() >= 0xFF00:
		msg.leer_u16()

	return {"casillas": casillas, "criaturas": criaturas}


func _leer_piso(msg, x0: int, y0: int, z: int, ancho: int, alto: int,
		desfase: int, casillas: Dictionary, criaturas: Array) -> void:
	# El desfase es la perspectiva: los pisos de arriba se dibujan corridos
	# una casilla por piso, porque en Tibia la camara mira en diagonal
	# (protocolgame.cpp:645, el `+ offset` va en la X y en la Y).
	for x in range(x0 + desfase, x0 + ancho + desfase):
		for y in range(y0 + desfase, y0 + alto + desfase):
			if _salto > 0:
				_salto -= 1
				continue
			if msg.sin_leer() < 2:
				return

			if msg.espiar_u16() >= 0xFF00:
				var marca: int = msg.leer_u16()
				var vacios: int
				if marca == 0xFFFF:
					# Tanda completa (protocolgame.cpp:654-657). Son 255
					# vacios si el contador venia de 0, y 256 si venia de -1.
					# Despues el servidor lo deja de nuevo en -1.
					vacios = 255 + (1 if _menos_uno else 0)
					_menos_uno = true
				else:
					vacios = (marca & 0xFF) + (1 if _menos_uno else 0)
					_menos_uno = false
				if vacios > 0:
					_salto = vacios - 1   # este casillero ya es uno de los vacios
					continue
				# vacios == 0: no hubo ninguno, la casilla viene aca nomas.

			_menos_uno = false
			var cosas := _leer_casilla(msg, Vector3i(x, y, z), criaturas)
			if not cosas.is_empty():
				casillas[Vector3i(x, y, z)] = cosas


func _leer_casilla(msg, donde: Vector3i, criaturas: Array) -> Array:
	var cosas := []
	# Nunca mas de 10 por casilla (protocolgame.cpp:582, 599, 609).
	for _i in range(10):
		if msg.sin_leer() < 2:
			break
		var marca: int = msg.espiar_u16()
		if marca >= 0xFF00:
			break   # empieza el proximo casillero
		cosas.append(leer_cosa(msg, donde, criaturas))
	return cosas


func leer_casilla_suelta(msg, donde: Vector3i, criaturas: Array) -> Array:
	"""Una casilla que el servidor manda sola, fuera del mapa (mensaje 0x69).
	Termina con dos bytes que hay que consumir: 0x00 0xFF si la casilla
	existe, 0x01 0xFF si esta vacia (protocolgame.cpp:1784-1791)."""
	var cosas := _leer_casilla(msg, donde, criaturas)
	if msg.sin_leer() >= 2 and msg.espiar_u16() >= 0xFF00:
		msg.leer_u16()
	return cosas


func leer_cosa(msg, donde: Vector3i, criaturas: Array) -> Dictionary:
	"""Una sola cosa de una casilla: un item o una criatura. Se usa tanto
	al leer el mapa entero como cuando el servidor avisa que aparecio algo
	nuevo (mensaje 0x6A)."""
	var marca: int = msg.espiar_u16()
	if marca == CRIATURA_DESCONOCIDA or marca == CRIATURA_CONOCIDA or marca == CRIATURA_YA_VISTA:
		var bicho := _leer_criatura(msg)
		bicho["donde"] = donde
		criaturas.append(bicho)
		return {"tipo": "criatura", "id": bicho["id"]}
	return _leer_item(msg)


func _leer_item(msg) -> Dictionary:
	var cid: int = msg.leer_u16()
	var info := info_item(cid)
	if info.is_empty():
		_sin_datos += 1
	# networkmessage.cpp:101-105 — el byte extra es cantidad para apilables
	# y color para liquidos. En 7.72 no hay byte de animacion. El color no
	# es el FluidType interno: el servidor lo traduce antes de enviarlo.
	var es_apilable := bool(info.get("apilable", false))
	var es_liquido := bool(info.get("liquido", false))
	var cantidad := 1
	var color_liquido := 0
	if es_apilable:
		cantidad = msg.leer_u8()
	elif es_liquido:
		color_liquido = msg.leer_u8()
	return {
		"tipo": "item",
		"cid": cid,
		"cantidad": cantidad,
		"apilable": es_apilable,
		"liquido": es_liquido,
		"color_liquido": color_liquido,
		"suelo": info.get("suelo", false),
		"bloquea": info.get("bloquea", false),
		"frena_vista": info.get("frena_vista", false),
		"movible": info.get("movible", false),
		"levantable": info.get("levantable", false),
		"contenedor": info.get("contenedor", false),
		"siempre_arriba": info.get("siempre_arriba", false),
		"orden_arriba": info.get("orden_arriba", 0),
		"color_mapa": info.get("color_mapa", 0),
		"nombre": _nombre_item_recibido(cid, info, color_liquido),
	}


static func _nombre_item_recibido(cid: int, info: Dictionary,
		color_liquido: int) -> String:
	var nombre := str(info.get("nombre", ""))
	# 2006/vial con FluidType=10 (mana) llega por el protocolo como color 7.
	# El servidor no manda el subtipo interno, por eso el client id y el color
	# son la única información disponible para presentar el nombre correcto.
	if cid == 2874 and color_liquido == 7:
		return "mana fluid"
	return nombre


func _leer_criatura(msg) -> Dictionary:
	# protocolgame.cpp:2243-2280
	var marca: int = msg.leer_u16()
	var bicho := {"nombre": "", "conocida": true}

	if marca == CRIATURA_YA_VISTA:
		# Caso corto: solo id y para donde mira. No viene adentro del mapa,
		# sino en el mensaje 0x6B de "esa criatura giro"
		# (protocolgame.cpp:1526-1531).
		bicho["id"] = msg.leer_u32()
		bicho["direccion"] = msg.leer_u8()
		bicho["vida"] = 100
		bicho["apariencia"] = 0
		return bicho

	if marca == CRIATURA_DESCONOCIDA:
		msg.leer_u32()                   # id de la criatura a olvidar
		bicho["id"] = msg.leer_u32()
		bicho["nombre"] = msg.leer_texto()
		bicho["conocida"] = false
	else:
		bicho["id"] = msg.leer_u32()

	bicho["vida"] = msg.leer_u8()        # porcentaje
	bicho["direccion"] = msg.leer_u8()
	_leer_apariencia(msg, bicho)
	msg.leer_u8()                        # nivel de luz
	msg.leer_u8()                        # color de luz
	bicho["velocidad"] = msg.leer_u16()
	msg.leer_u8()                        # calavera
	msg.leer_u8()                        # escudo de party
	# Y se acabo. En 7.72 NO viene el emblema de guild ni el byte de "se
	# puede caminar por encima": los dos son de 8.x en adelante.
	return bicho


func _leer_apariencia(msg, bicho: Dictionary) -> void:
	# protocolgame.cpp:2325-2337. Sin addons y sin montura: en 7.72 no
	# existe ninguna de las dos cosas.
	var tipo: int = msg.leer_u16()
	bicho["apariencia"] = tipo
	if tipo != 0:
		bicho["colores"] = [msg.leer_u8(), msg.leer_u8(), msg.leer_u8(), msg.leer_u8()]
	else:
		# Criatura que se ve como un objeto (un pilar, un barril).
		bicho["item"] = msg.leer_u16()


func items_sin_datos() -> int:
	return _sin_datos
