extends Node

# Prueba viva del depot contra el servidor TVP 7.72.
#
# Lo que se mide es la persistencia de verdad: un objeto guardado en el depot
# tiene que seguir ahi despues de cerrar la sesion y volver a entrar.
#
#   1. El god se para al lado del depot de Thais y abre su mochila.
#   2. Abre el locker con `0x82`: ese es el depot.
#   3. Mueve el primer objeto de la mochila al depot con `0x78`.
#   4. Sale con logout `0x14` y vuelve a entrar.
#   5. Abre el depot otra vez: el objeto tiene que estar.
#   6. Lo devuelve a la mochila y sale.
#
# No se asume ningun objeto en particular: se usa el primero que haya en la
# mochila, y si esta vacia el god se crea una etiqueta con `/i`. Al final todo
# queda como estaba.
#
# El depot de Thais salio del mapa del propio servidor
# (`servidor/data/world/map.otbm`): el locker server id 2589 esta en
# `(32354,32231,7)`, y `servidor/data/items/items.xml:6341-6345` lo declara
# `type=depot` con capacidad 30.
#
#   ...Godot --headless --path cliente3d pruebas/prueba_depot_vivo.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
const CUENTA := 123456
const CLAVE := "123456"
const PERSONAJE := "GOD VALENTINO"

## Locker del depot de Thais y la baldosa que hay que pisar.
##
## No alcanza con estar al lado: `data/scripts/movements/other/tiles.lua` carga
## el depot del jugador cuando pisa una de esas baldosas (item 426 aca) dentro
## de una zona de proteccion y con un item de tipo depot en el 3x3. Recien
## entonces `Player::currentDepotItem` apunta a su locker y `actions.cpp:218-234`
## abre el depot de verdad; si no, abre el mueble del mapa como un contenedor
## comun y lo que se guarde ahi no es de nadie.
const POS_LOCKER := Vector3i(32354, 32231, 7)
const POS_BALDOSA := Vector3i(32354, 32230, 7)
## Casilla de al lado, para salir y volver a pisar la baldosa: el evento es de
## entrada, asi que si ya estabamos parados ahi no se dispara.
const POS_AFUERA := Vector3i(32355, 32230, 7)
## Ranura de la mochila en el equipo (`CONST_SLOT_BACKPACK`).
const SLOT_MOCHILA := 3
## Server id de la etiqueta, por si la mochila estuviera vacia.
const SERVER_ID_ETIQUETA := 2599

const PAUSA_SESION := 6.0
const LIMITE_TOTAL := 240.0
const ESPERA_PASO := 12.0

var _con_login
var _con
var _estado
var _puerto := 0
var _fase := "login"
var _espera := 0.0
var _total := 0.0
var _fallas := 0
var _terminando := false
var _segunda_sesion := false
var _id_mochila := -1
var _id_depot := -1
var _id_cofre := -1
var _cid_objeto := 0
var _nombre_objeto := ""
var _pidio_etiqueta := false
## Cuantas cosas habia antes de mover, para no depender de que el objeto sea
## unico: la mochila del god puede tener dos parcels iguales.
var _antes_mochila := -1
var _antes_depot := -1
var _reabrio_depot := false
var _pos_origen := Vector3i.ZERO
var _aviso_depot := ""


func _ready() -> void:
	print("=================================================")
	print(" TVP3D - prueba viva del depot")
	print("=================================================")
	_abrir_login()


func _process(delta: float) -> void:
	_total += delta
	_espera += delta
	if _terminando:
		return
	if _total > LIMITE_TOTAL:
		_error("Tiempo agotado en la fase '%s'" % _fase)
		return
	match _fase:
		"esperar mundo":
			if _estado != null and _estado.adentro and _espera > 2.0:
				_ir_al_depot()
		"salir de la baldosa":
			_pisar_baldosa()
		"ir al depot":
			_verificar_llegada()
		"abrir cofre":
			_verificar_cofre()
		"abrir mochila":
			_verificar_mochila()
		"abrir depot":
			_verificar_depot()
		"guardar":
			_verificar_guardado()
		"pausa reingreso":
			if _espera >= PAUSA_SESION:
				_entrar_de_nuevo()
		"devolver":
			_verificar_devuelto()
		"salir":
			if _espera > 6.0:
				_espera = 0.0
				_con.enviar_logout()


# -----------------------------------------------------------------
#  Sesion
# -----------------------------------------------------------------
func _abrir_login() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.error_red.connect(func(texto): _error("Login: " + texto))
	_con_login.lista_personajes.connect(func(_motd, personajes):
		for entrada in personajes:
			if str(entrada.get("nombre", "")) == PERSONAJE:
				_puerto = int(entrada.get("puerto", 0))
		if _puerto <= 0:
			_error("La cuenta no tiene a %s" % PERSONAJE)
			return
		_con_login.cerrar()
		_con_login.queue_free()
		_con_login = null
		_entrar())
	_con_login.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _entrar() -> void:
	_estado = ESTADO.new()
	_estado.pedido_ping.connect(func():
		_con.enviar_juego(PackedByteArray([0x1E])))
	_estado.mensaje_servidor.connect(func(texto):
		print("  [srv] ", texto)
		if texto.begins_with("Your depot contains"):
			_aviso_depot = texto)
	_estado.contenedor_actualizado.connect(_al_contenedor)
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(func(texto):
		if _fase != "salir" and not _terminando:
			_error("Red: " + texto))
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.cerrada.connect(_al_cerrarse)
	_con.entrar_al_mundo(HOST, _puerto, CUENTA, PERSONAJE, CLAVE)
	_pasar_a("esperar mundo")


func _al_cerrarse() -> void:
	if _terminando:
		return
	if not _segunda_sesion:
		_segunda_sesion = true
		print("Sesion cerrada. Se vuelve a entrar para ver si el depot guardo.")
		_pasar_a("pausa reingreso")
		return
	_terminar()


func _entrar_de_nuevo() -> void:
	if _con != null:
		_con.queue_free()
	_id_mochila = -1
	_id_depot = -1
	_id_cofre = -1
	_aviso_depot = ""
	_entrar()


# -----------------------------------------------------------------
#  Recorrido
# -----------------------------------------------------------------
func _ir_al_depot() -> void:
	print("Yendo al depot de Thais %s." % str(POS_LOCKER))
	_con.enviar_hablar("/gotopos %d,%d,%d" % [
		POS_AFUERA.x, POS_AFUERA.y, POS_AFUERA.z])
	_pasar_a("salir de la baldosa")


func _pisar_baldosa() -> void:
	if _estado.mi_pos != POS_AFUERA:
		if _espera > ESPERA_PASO:
			_error("El god no llego a %s" % str(POS_AFUERA))
		return
	print("Pisando la baldosa del depot %s." % str(POS_BALDOSA))
	_con.enviar_hablar("/gotopos %d,%d,%d" % [
		POS_BALDOSA.x, POS_BALDOSA.y, POS_BALDOSA.z])
	_pasar_a("ir al depot")


func _verificar_llegada() -> void:
	if _estado.mi_pos != POS_BALDOSA:
		if _espera > ESPERA_PASO:
			_error("El god no llego a %s, sigue en %s"
				% [str(POS_BALDOSA), str(_estado.mi_pos)])
		return
	if not _estado.mapa_alineado:
		_error("El mapa llego desalineado: los indices de pila no valen")
		return
	if not _segunda_sesion:
		_comprobar("el depot esta donde dice el mapa del servidor",
			_buscar_locker() >= 0,
			"la casilla %s trae %s" % [str(POS_LOCKER), _describir(POS_LOCKER)])
	print("Abriendo la mochila del god.")
	_con.enviar_usar_inventario(SLOT_MOCHILA,
		int(_estado.inventario.get(SLOT_MOCHILA, {}).get("cid", 0)))
	_pasar_a("abrir mochila")


func _buscar_locker() -> int:
	## El locker es el item de la casilla que se abre como contenedor. No se
	## busca por client id fijo: el mapa habla en server ids y el cliente solo
	## conoce client ids, asi que se usa la bandera del catalogo.
	var pila := 0
	for cosa in _estado.casillas.get(POS_LOCKER, []):
		if cosa.get("tipo") == "item" and bool(cosa.get("contenedor", false)):
			return pila
		pila += 1
	return -1


func _al_contenedor(id: int, datos: Dictionary) -> void:
	print("Contenedor %d: '%s' con %d cosas." % [
		id, str(datos.get("nombre", "")), (datos.get("items", []) as Array).size()])
	if _id_mochila < 0:
		_id_mochila = id
	elif _id_depot < 0 and id != _id_mochila:
		_id_depot = id
	elif _id_cofre < 0 and id != _id_mochila and id != _id_depot:
		_id_cofre = id


func _items_de(id: int) -> Array:
	return _estado.contenedores.get(id, {}).get("items", [])


func _verificar_mochila() -> void:
	if _id_mochila < 0:
		if _espera > ESPERA_PASO:
			_error("El servidor no abrio la mochila del god")
		return
	# La prueba se crea su propio objeto en vez de usar lo que haya: asi no
	# depende del inventario del god ni toca sus cosas. La etiqueta sirve
	# porque no es apilable, y un apilable mediria otra cosa (el servidor
	# puede partir o juntar la pila).
	if not _pidio_etiqueta:
		_pidio_etiqueta = true
		_antes_mochila = _items_de(_id_mochila).size()
		print("El god se crea una etiqueta para la prueba.")
		_con.enviar_hablar("/i %d" % SERVER_ID_ETIQUETA)
		_espera = 0.0
		return
	if _cid_objeto == 0:
		# `player:addItem` deja el objeto donde entre: la mochila o cualquier
		# ranura libre del equipo. Se lo busca por nombre en los dos lados y se
		# recuerda de donde hay que moverlo.
		var indice := 0
		for cosa in _items_de(_id_mochila):
			if str(cosa.get("nombre", "")) == "label":
				_cid_objeto = int(cosa.get("cid", 0))
				_pos_origen = Vector3i(0xFFFF, 0x40 | _id_mochila, indice)
				break
			indice += 1
		if _cid_objeto == 0:
			for slot in range(1, 11):
				var equipada: Dictionary = _estado.inventario.get(slot, {})
				if str(equipada.get("nombre", "")) == "label":
					_cid_objeto = int(equipada.get("cid", 0))
					_pos_origen = Vector3i(0xFFFF, slot, 0)
					break
		if _cid_objeto == 0:
			if _espera > ESPERA_PASO:
				_error("La etiqueta no aparecio: mochila=%s, equipo=%s"
					% [_describir_items(_id_mochila), _describir_equipo()])
			return
		_nombre_objeto = "label"
		print("El objeto de la prueba es label (cid %d), en %s." % [
			_cid_objeto, str(_pos_origen)])
	print("Abriendo el locker del depot.")
	var pila := _buscar_locker()
	if pila < 0:
		_error("No aparece el locker en %s" % str(POS_LOCKER))
		return
	var cosa_locker: Dictionary = _estado.casillas[POS_LOCKER][pila]
	# El ultimo byte del `0x82` es la ventana de contenedor donde abrirlo
	# (`parseUseItem` -> `Game::playerUseItem`). Con 0 el servidor reemplaza la
	# mochila que ya estaba abierta ahi, asi que el depot va en la ventana 1.
	_con.enviar_usar_item(POS_LOCKER, int(cosa_locker.get("cid", 0)), pila, 1)
	_pasar_a("abrir depot")


func _verificar_depot() -> void:
	if _id_depot < 0:
		if _espera > ESPERA_PASO:
			_error("El servidor no abrio el locker")
		return
	# Dentro del locker esta el `depot chest`, que es donde viven las cosas
	# guardadas: `actions.cpp:222-231` lo crea al abrir el depot cargado.
	var indice_cofre := -1
	var indice := 0
	for cosa in _items_de(_id_depot):
		if str(cosa.get("nombre", "")).contains("depot"):
			indice_cofre = indice
			break
		indice += 1
	if indice_cofre < 0:
		if _espera > ESPERA_PASO:
			_error("El locker no tiene el depot chest adentro: %s"
				% _describir_items(_id_depot))
		return
	if _id_cofre < 0:
		var cofre: Dictionary = _items_de(_id_depot)[indice_cofre]
		print("Abriendo el depot chest que esta dentro del locker.")
		_con.enviar_usar_item(
			Vector3i(0xFFFF, 0x40 | _id_depot, indice_cofre),
			int(cofre.get("cid", 0)), 0, 2)
		_pasar_a("abrir cofre")
	return


func _verificar_cofre() -> void:
	if _id_cofre < 0:
		if _espera > ESPERA_PASO:
			_error("El servidor no abrio el depot chest")
		return
	if not _segunda_sesion:
		# Que dentro del locker haya un `depot chest` es la senal de que el
		# servidor cargo el depot de ESTE jugador al pisar la baldosa: si no,
		# `actions.cpp:218-234` abriria el mueble del mapa, que no lo tiene.
		_comprobar("pisar la baldosa carga el depot del jugador, con su cofre",
			true)
		_antes_depot = _items_de(_id_cofre).size()
		print("Guardando %s en el depot chest." % _nombre_objeto)
		_con.enviar_mover_ubicacion(_pos_origen, _cid_objeto, 0,
			Vector3i(0xFFFF, 0x40 | _id_cofre, 0))
		_pasar_a("guardar")
		return
	_comprobar("el depot vuelve a abrirse en la sesion nueva", true)
	var sigue := _indice_en(_id_cofre) >= 0
	_comprobar("EL OBJETO SIGUE EN EL DEPOT DESPUES DE RECONECTAR", sigue,
		"el depot chest trae %s" % _describir_items(_id_cofre))
	if not sigue:
		_terminar()
		return
	_antes_mochila = _items_de(_id_mochila).size()
	_antes_depot = _items_de(_id_cofre).size()
	print("Sacando %s del depot." % _nombre_objeto)
	_con.enviar_mover_ubicacion(
		Vector3i(0xFFFF, 0x40 | _id_cofre, _indice_en(_id_cofre)),
		_cid_objeto, 0, Vector3i(0xFFFF, 0x40 | _id_mochila, 0))
	_pasar_a("devolver")


func _verificar_guardado() -> void:
	var en_depot := _items_de(_id_cofre).size()
	if _indice_en(_id_cofre) >= 0 and en_depot == _antes_depot + 1:
		_comprobar("el objeto entra al depot", true)
		print("Cerrando la sesion para comprobar la persistencia.")
		_con.enviar_logout()
		_pasar_a("salir")
		return
	# Volver a usar el locker no sirve para mirar: `Game::playerUseItem` cierra
	# el contenedor que ya estaba abierto en esa ventana.
	if _espera > ESPERA_PASO:
		_error("El objeto no llego al depot: equipo=%s, cofre=%s"
			% [_describir_equipo(), _describir_items(_id_cofre)])


func _verificar_devuelto() -> void:
	var en_mochila := _items_de(_id_mochila).size()
	var en_depot := _items_de(_id_cofre).size()
	if en_mochila == _antes_mochila + 1 and en_depot == _antes_depot - 1:
		_comprobar("el objeto sale del depot y vuelve a la mochila",
			_indice_en(_id_cofre) < 0)
		_con.enviar_logout()
		_pasar_a("salir")
		return
	if _espera > ESPERA_PASO:
		_comprobar("el objeto sale del depot y vuelve a la mochila",
			false, "mochila=%s, cofre=%s"
			% [_describir_items(_id_mochila), _describir_items(_id_cofre)])
		_con.enviar_logout()
		_pasar_a("salir")


# -----------------------------------------------------------------
#  Utilidades
# -----------------------------------------------------------------
func _indice_en(id_contenedor: int) -> int:
	var indice := 0
	for cosa in _items_de(id_contenedor):
		if int(cosa.get("cid", 0)) == _cid_objeto:
			return indice
		indice += 1
	return -1


func _describir_equipo() -> String:
	var partes: Array = []
	for slot in _estado.inventario:
		var cosa: Dictionary = _estado.inventario[slot]
		if not cosa.is_empty():
			partes.append("%d:%s" % [slot, str(cosa.get("nombre", "?"))])
	return "nada" if partes.is_empty() else ", ".join(partes)


func _describir_items(id_contenedor: int) -> String:
	var partes: Array = []
	for cosa in _items_de(id_contenedor):
		partes.append(str(cosa.get("nombre", cosa.get("cid", "?"))))
	return "nada" if partes.is_empty() else ", ".join(partes)


func _describir(donde: Vector3i) -> String:
	var partes: Array = []
	for cosa in _estado.casillas.get(donde, []):
		partes.append(str(cosa.get("nombre", cosa.get("cid", "?"))))
	return "nada" if partes.is_empty() else ", ".join(partes)


func _pasar_a(fase: String) -> void:
	print("  [%.0fs] fase: %s" % [_total, fase])
	_fase = fase
	_espera = 0.0


func _comprobar(nombre: String, correcto: bool, detalle: String = "") -> void:
	if correcto:
		print("  OK  %s" % nombre)
	else:
		_fallas += 1
		print("  FAIL %s%s" % [nombre, "" if detalle.is_empty() else ": " + detalle])


func _error(texto: String) -> void:
	print("  FAIL " + texto)
	_fallas += 1
	_terminar()


func _terminar() -> void:
	if _terminando:
		return
	_terminando = true
	print("--- resumen ---")
	_comprobar("el depot guarda entre sesiones", _fallas == 0)
	if _con != null:
		_con.cerrar()
	if _fallas == 0:
		print("Prueba viva del depot: OK")
	else:
		print("Prueba viva del depot: %d fallas" % _fallas)
	get_tree().quit(1 if _fallas > 0 else 0)
