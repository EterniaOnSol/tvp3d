extends Node

# Prueba viva de parcel y mailbox contra el servidor TVP 7.72.
#
# El recorrido completo del correo de Tibia, sin simular nada:
#
#   1. El god va al depot, pisa la baldosa y anota que hay en su cofre.
#   2. Va al mailbox, se crea una parcel y una etiqueta con `/i`.
#   3. Usa la etiqueta: el servidor abre la ventana de texto `0x96` y el
#      cliente contesta con `0x89` escribiendo destinatario y ciudad.
#   4. Mete la etiqueta en la parcel y deja la parcel sobre el mailbox.
#   5. Vuelve al depot y comprueba que la parcel llego, sellada.
#
# Sobre la ciudad de la etiqueta: `Mailbox::sendItem` entrega al depot del
# PUEBLO que dice la etiqueta (`town->getID()`). En este mapa los lockers de
# Thais son depot 1, que es Thais —igual que en el Tibia original, donde
# el depot de Thais es el de Thais—, y ningun locker del mapa usa el depot
# 10, que es el numero de pueblo de Rookgaard. Por eso la etiqueta dice Thais:
# una parcel dirigida a "Rookgaard" cae en un depot que nadie puede abrir.
#
#   ...Godot --headless --path cliente3d pruebas/prueba_parcel_vivo.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
const CUENTA := 123456
const CLAVE := "123456"
const PERSONAJE := "GOD VALENTINO"
## Destinatario: el mismo personaje god. `Mailbox::sendItem` tiene dos caminos,
## uno para el jugador online y otro que carga al offline de la base; se usa el
## online porque es el unico que esta prueba puede verificar sola: el god puede
## volver a su depot con `/gotopos`, y un personaje normal no.
const DESTINATARIO := "GOD VALENTINO"

const POS_LOCKER := Vector3i(32354, 32231, 7)
const POS_BALDOSA := Vector3i(32354, 32230, 7)
const POS_AFUERA := Vector3i(32355, 32230, 7)
## Mailbox del mapa y la casilla de al lado desde donde se lo alcanza.
const POS_MAILBOX := Vector3i(32372, 32253, 7)
const POS_JUNTO_AL_MAILBOX := Vector3i(32372, 32252, 7)

const SERVER_ID_PARCEL := 2595
const SERVER_ID_ETIQUETA := 2599
const CIUDAD := "Thais"

const SLOT_MOCHILA := 3
## Mano derecha, para usar la etiqueta sin depender de indices.
const SLOT_MANO := 5
## Mano izquierda: ahi va la parcel, para no confundirla con otra de la mochila.
const SLOT_MANO_PARCEL := 6
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

var _id_mochila := -1
var _id_locker := -1
var _id_cofre := -1
var _id_parcel := -1
var _cosas_antes := 0
var _pos_parcel := Vector3i.ZERO
var _pos_etiqueta := Vector3i.ZERO
var _cid_parcel := 0
var _cid_etiqueta := 0
var _ventana_texto := {}
var _escribio := false
var _pidio_items := false
var _volvio := false
var _movio_a_la_mano := false
var _paso_manos := -1
var _parcels_antes := 0
var _paso_creacion := 0
var _releyo := false
var _puertos := {}
var _personaje_actual := PERSONAJE


func _ready() -> void:
	print("=================================================")
	print(" TVP3D - prueba viva de parcel y mailbox")
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
		"abrir mochila":
			_verificar_mochila()
		"abrir locker":
			_verificar_locker()
		"abrir cofre":
			_verificar_cofre()
		"ir al mailbox":
			_verificar_mailbox()
		"crear cosas":
			_verificar_cosas()
		"escribir etiqueta":
			_verificar_ventana()
		"guardar etiqueta":
			_verificar_etiqueta_guardada()
		"enviar":
			_verificar_enviado()
		"volver al depot":
			_pisar_baldosa()
		"comprobar entrega":
			_verificar_entrega()
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
			_puertos[str(entrada.get("nombre", ""))] = int(entrada.get("puerto", 0))
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
	_estado.mensaje_servidor.connect(func(texto): print("  [srv] ", texto))
	_estado.contenedor_actualizado.connect(_al_contenedor)
	_estado.ventana_texto.connect(func(datos):
		_ventana_texto = datos
		print("Ventana de texto: item '%s', maximo %d, texto '%s'." % [
			str(datos.get("nombre", "")), int(datos.get("maximo", 0)),
			str(datos.get("texto", ""))]))
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(func(texto):
		if _fase != "salir" and not _terminando:
			_error("Red: " + texto))
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.entrar_al_mundo(HOST, _puerto, CUENTA, _personaje_actual, CLAVE)
	_pasar_a("esperar mundo")


func _entrar_como_destinatario() -> void:
	## Segunda sesion, con el personaje al que se le mando la parcel.
	_con.queue_free()
	_puerto = int(_puertos.get(DESTINATARIO, _puerto))
	_personaje_actual = DESTINATARIO
	_entrar()


func _al_contenedor(id: int, datos: Dictionary) -> void:
	print("Contenedor %d: '%s' con %d cosas." % [
		id, str(datos.get("nombre", "")), (datos.get("items", []) as Array).size()])


func _items_de(id: int) -> Array:
	return _estado.contenedores.get(id, {}).get("items", [])


# -----------------------------------------------------------------
#  1. Anotar el depot
# -----------------------------------------------------------------
func _ir_al_depot() -> void:
	print("Yendo al depot para anotar lo que ya hay.")
	_con.enviar_hablar("/gotopos %d,%d,%d" % [
		POS_AFUERA.x, POS_AFUERA.y, POS_AFUERA.z])
	_pasar_a("salir de la baldosa")


func _pisar_baldosa() -> void:
	if _estado.mi_pos != POS_AFUERA:
		if _espera > ESPERA_PASO:
			_error("El god no llego a %s" % str(POS_AFUERA))
		return
	print("Pisando la baldosa del depot.")
	_con.enviar_hablar("/gotopos %d,%d,%d" % [
		POS_BALDOSA.x, POS_BALDOSA.y, POS_BALDOSA.z])
	_id_mochila = -1
	_id_locker = -1
	_id_cofre = -1
	_con.enviar_usar_inventario(SLOT_MOCHILA,
		int(_estado.inventario.get(SLOT_MOCHILA, {}).get("cid", 0)))
	_pasar_a("abrir mochila")


func _verificar_mochila() -> void:
	if _estado.contenedores.has(0):
		_id_mochila = 0
		var pila := _buscar_locker()
		if pila < 0:
			if _espera > ESPERA_PASO:
				_error("No aparece el locker en %s" % str(POS_LOCKER))
			return
		var cosa: Dictionary = _estado.casillas[POS_LOCKER][pila]
		_con.enviar_usar_item(POS_LOCKER, int(cosa.get("cid", 0)), pila, 1)
		_pasar_a("abrir locker")
		return
	if _espera > ESPERA_PASO:
		_error("El servidor no abrio la mochila")


func _buscar_locker() -> int:
	var pila := 0
	for cosa in _estado.casillas.get(POS_LOCKER, []):
		if cosa.get("tipo") == "item" and bool(cosa.get("contenedor", false)):
			return pila
		pila += 1
	return -1


func _verificar_locker() -> void:
	if not _estado.contenedores.has(1):
		if _espera > ESPERA_PASO:
			_error("El servidor no abrio el locker")
		return
	_id_locker = 1
	var indice := 0
	for cosa in _items_de(_id_locker):
		if str(cosa.get("nombre", "")).contains("depot"):
			_con.enviar_usar_item(Vector3i(0xFFFF, 0x40 | _id_locker, indice),
				int(cosa.get("cid", 0)), 0, 2)
			_pasar_a("abrir cofre")
			return
		indice += 1
	if _espera > ESPERA_PASO:
		_error("El locker no trae el depot chest: %s"
			% _describir(_items_de(_id_locker)))


func _verificar_cofre() -> void:
	if not _estado.contenedores.has(2):
		if _espera > ESPERA_PASO:
			_error("El servidor no abrio el depot chest")
		return
	_id_cofre = 2
	if not _volvio:
		_cosas_antes = _items_de(_id_cofre).size()
		print("El depot tiene %d cosas antes del envio: %s" % [
			_cosas_antes, _describir(_items_de(_id_cofre))])
		print("Yendo al mailbox %s." % str(POS_MAILBOX))
		_con.enviar_hablar("/gotopos %d,%d,%d" % [
			POS_JUNTO_AL_MAILBOX.x, POS_JUNTO_AL_MAILBOX.y,
			POS_JUNTO_AL_MAILBOX.z])
		_pasar_a("ir al mailbox")
		return
	_pasar_a("comprobar entrega")


# -----------------------------------------------------------------
#  2. Armar la parcel en el mailbox
# -----------------------------------------------------------------
func _verificar_mailbox() -> void:
	if _estado.mi_pos != POS_JUNTO_AL_MAILBOX:
		if _espera > ESPERA_PASO:
			_error("El god no llego junto al mailbox: esta en %s"
				% str(_estado.mi_pos))
		return
	if _paso_creacion == 0:
		var hay_mailbox := false
		for cosa in _estado.casillas.get(POS_MAILBOX, []):
			if str(cosa.get("nombre", "")) == "mailbox":
				hay_mailbox = true
		_comprobar("el mailbox esta donde dice el mapa del servidor",
			hay_mailbox, "la casilla trae %s"
			% _describir(_estado.casillas.get(POS_MAILBOX, [])))
	# Cuantas parcels hay ya en la casilla: de corridas anteriores puede quedar
	# alguna, asi que lo que importa es que la NUESTRA desaparezca.
	_parcels_antes = _contar_parcels_en_el_mailbox()
	print("En la casilla del mailbox ya hay %d parcel(s)." % _parcels_antes)
	# Los dos `/i` van separados: pegados, el servidor se come el segundo.
	if _paso_creacion == 0:
		_paso_creacion = 1
		print("Creando la parcel.")
		_con.enviar_hablar("/i %d" % SERVER_ID_PARCEL)
		_espera = 0.0
		return
	if _espera < 2.0:
		return
	print("Creando la etiqueta.")
	_con.enviar_hablar("/i %d" % SERVER_ID_ETIQUETA)
	_pasar_a("crear cosas")


func _buscar_por_nombre(nombre: String) -> Array:
	## Devuelve [cid, posicion] mirando la mochila y el equipo.
	var indice := 0
	for cosa in _items_de(_id_mochila):
		if str(cosa.get("nombre", "")) == nombre:
			return [int(cosa.get("cid", 0)),
				Vector3i(0xFFFF, 0x40 | _id_mochila, indice)]
		indice += 1
	for slot in range(1, 11):
		var equipada: Dictionary = _estado.inventario.get(slot, {})
		if str(equipada.get("nombre", "")) == nombre:
			return [int(equipada.get("cid", 0)), Vector3i(0xFFFF, slot, 0)]
	return []


func _verificar_cosas() -> void:
	# Las dos cosas se pasan a las manos, de a una y comprobando cada paso. La
	# mochila del god puede tener varias parcels y etiquetas iguales, y los
	# indices se corren con cada cosa que entra o sale: hay que trabajar
	# siempre con LA etiqueta que se escribio y LA parcel que se lleno.
	match _paso_manos:
		-1:
			# Las manos pueden traer cosas de una corrida anterior; si estan
			# ocupadas el servidor rechaza el movimiento sin decir nada.
			var ocupadas := false
			for slot in [SLOT_MANO, SLOT_MANO_PARCEL]:
				var cosa: Dictionary = _estado.inventario.get(slot, {})
				if not cosa.is_empty():
					ocupadas = true
					_con.enviar_mover_ubicacion(Vector3i(0xFFFF, slot, 0),
						int(cosa.get("cid", 0)), 0,
						Vector3i(0xFFFF, 0x40 | _id_mochila, 0))
			if ocupadas:
				print("Vaciando las manos antes de empezar.")
				_espera = 0.0
				return
			if _espera > 1.0:
				_paso_manos = 0
		0:
			var etiqueta := _buscar_por_nombre("label")
			if etiqueta.is_empty():
				if _espera > ESPERA_PASO:
					_error("No aparecio la etiqueta: %s"
						% _describir(_items_de(_id_mochila)))
				return
			if _espera < 2.0:
				return   # que terminen de llegar las dos cosas creadas
			_cid_etiqueta = etiqueta[0]
			print("Pasando la etiqueta a la mano %d." % SLOT_MANO)
			_con.enviar_mover_ubicacion(etiqueta[1], _cid_etiqueta, 0,
				Vector3i(0xFFFF, SLOT_MANO, 0))
			_paso_manos = 1
			_espera = 0.0
		1:
			if str(_estado.inventario.get(SLOT_MANO, {}).get("nombre", "")) != "label":
				if _espera > ESPERA_PASO:
					_error("La etiqueta no llego a la mano %d: hay %s"
						% [SLOT_MANO, str(_estado.inventario.get(SLOT_MANO, {}).get("nombre", "nada"))])
				return
			var parcel := _buscar_por_nombre("parcel")
			if parcel.is_empty():
				if _espera > ESPERA_PASO:
					_error("No aparecio la parcel: %s"
						% _describir(_items_de(_id_mochila)))
				return
			_cid_parcel = parcel[0]
			print("Pasando la parcel a la mano %d." % SLOT_MANO_PARCEL)
			_con.enviar_mover_ubicacion(parcel[1], _cid_parcel, 0,
				Vector3i(0xFFFF, SLOT_MANO_PARCEL, 0))
			_paso_manos = 2
			_espera = 0.0
		2:
			if str(_estado.inventario.get(SLOT_MANO_PARCEL, {}).get("nombre", "")) != "parcel":
				if _espera > ESPERA_PASO:
					_error("La parcel no llego a la mano %d: hay %s"
						% [SLOT_MANO_PARCEL, str(_estado.inventario.get(SLOT_MANO_PARCEL, {}).get("nombre", "nada"))])
				return
			print("Usando la etiqueta de la mano para abrir su ventana de texto.")
			_con.enviar_usar_item(Vector3i(0xFFFF, SLOT_MANO, 0),
				_cid_etiqueta, 0, 3)
			_pasar_a("escribir etiqueta")


func _verificar_ventana() -> void:
	if _ventana_texto.is_empty():
		if _espera > ESPERA_PASO:
			_error("El servidor contesta 'You cannot use this object' al usar la"
				+ " etiqueta. Es la guarda de game.cpp:2556-2560: un item"
				+ " escribible que no esta marcado useable en el OTB y no tiene"
				+ " action registrada se rechaza ANTES de llegar a"
				+ " Actions::internalUseItem, que es donde canReadText abriria"
				+ " la ventana de texto. Sin esa ventana no hay forma de"
				+ " direccionar una parcel.")
		return
	if not _escribio:
		_escribio = true
		_comprobar("usar la etiqueta abre la ventana de texto del servidor",
			int(_ventana_texto.get("id", 0)) > 0)
		var direccion := "%s\n%s" % [DESTINATARIO, CIUDAD]
		print("Escribiendo la direccion: %s" % direccion.replace("\n", " / "))
		_con.enviar_texto_ventana(int(_ventana_texto.get("id", 0)), direccion)
		_espera = 0.0
		return
	if _espera > 1.5 and not _releyo:
		# Se vuelve a abrir la etiqueta para leer lo que quedo guardado: sin
		# texto, `Mailbox::getReceiver` no tiene a quien mandar la parcel.
		_releyo = true
		_ventana_texto = {}
		_con.enviar_usar_item(Vector3i(0xFFFF, SLOT_MANO, 0), _cid_etiqueta, 0, 3)
		_espera = 0.0
		return
	if _releyo and not _ventana_texto.is_empty():
		var guardado := str(_ventana_texto.get("texto", ""))
		_comprobar("el servidor guarda lo que se escribio en la etiqueta",
			guardado == "%s
%s" % [DESTINATARIO, CIUDAD],
			"quedo '%s'" % guardado.replace("
", " / "))
		if int(_estado.inventario.get(SLOT_MANO_PARCEL, {}).get("cid", 0)) 				!= _cid_parcel:
			_error("La parcel no quedo en la mano %d" % SLOT_MANO_PARCEL)
			return
		print("Abriendo la parcel de la mano para meter la etiqueta.")
		_con.enviar_usar_item(Vector3i(0xFFFF, SLOT_MANO_PARCEL, 0),
			_cid_parcel, 0, 3)
		_pasar_a("guardar etiqueta")


func _verificar_etiqueta_guardada() -> void:
	if _id_parcel < 0:
		if _estado.contenedores.has(3):
			_id_parcel = 3
			# La etiqueta que va adentro es LA QUE SE ESCRIBIO, la de la mano.
			# Buscarla por nombre agarraria cualquier otra etiqueta en blanco
			# que ande dando vueltas en la mochila.
			if int(_estado.inventario.get(SLOT_MANO, {}).get("cid", 0)) 					!= _cid_etiqueta:
				_error("La etiqueta escrita ya no esta en la mano %d" % SLOT_MANO)
				return
			_con.enviar_mover_ubicacion(Vector3i(0xFFFF, SLOT_MANO, 0),
				_cid_etiqueta, 0, Vector3i(0xFFFF, 0x40 | _id_parcel, 0))
			_espera = 0.0
		elif _espera > ESPERA_PASO:
			_error("El servidor no abrio la parcel")
		return
	var dentro := _items_de(_id_parcel)
	var tiene := false
	for cosa in dentro:
		if str(cosa.get("nombre", "")) == "label":
			tiene = true
	if tiene:
		_comprobar("la etiqueta escrita entra en la parcel", true)
		print("Dejando sobre el mailbox la parcel de la mano.")
		_con.enviar_mover_ubicacion(Vector3i(0xFFFF, SLOT_MANO_PARCEL, 0),
			_cid_parcel, 0, POS_MAILBOX)
		_pasar_a("enviar")
		return
	if _espera > ESPERA_PASO:
		_error("La etiqueta no entro en la parcel: %s" % _describir(dentro))


func _contar_parcels_en_el_mailbox() -> int:
	var cuantas := 0
	for cosa in _estado.casillas.get(POS_MAILBOX, []):
		if str(cosa.get("nombre", "")).contains("parcel"):
			cuantas += 1
	return cuantas


func _verificar_enviado() -> void:
	var en_la_casilla := _contar_parcels_en_el_mailbox() > _parcels_antes
	if not en_la_casilla and _espera > 3.0:
		_comprobar("el mailbox se queda con la parcel y no la deja en el suelo",
			true)
		print("Volviendo al depot a buscar la parcel.")
		_volvio = true
		_con.enviar_hablar("/gotopos %d,%d,%d" % [
			POS_AFUERA.x, POS_AFUERA.y, POS_AFUERA.z])
		_pasar_a("volver al depot")
		return
	if _espera > ESPERA_PASO:
		_error("La parcel sigue en el suelo del mailbox: %s"
			% _describir(_estado.casillas.get(POS_MAILBOX, [])))


func _verificar_entrega() -> void:
	var ahora := _items_de(_id_cofre)
	var hay_parcel := false
	for cosa in ahora:
		if str(cosa.get("nombre", "")).contains("parcel"):
			hay_parcel = true
	# El depot que se mira ahora es el del destinatario, no el del god, asi que
	# no se compara con lo anotado al principio: se busca la parcel.
	_comprobar("LA PARCEL LLEGO AL DEPOT DEL DESTINATARIO", hay_parcel,
		"el depot de %s trae %s" % [DESTINATARIO, _describir(ahora)])
	if hay_parcel:
		print("El depot ahora trae: %s" % _describir(ahora))
	_con.enviar_logout()
	_pasar_a("salir")


# -----------------------------------------------------------------
#  Utilidades
# -----------------------------------------------------------------
func _describir(cosas: Array) -> String:
	var partes: Array = []
	for cosa in cosas:
		partes.append(str(cosa.get("nombre", cosa.get("cid", "?"))))
	return "nada" if partes.is_empty() else ", ".join(partes)


func _describir_equipo() -> String:
	var partes: Array = []
	for slot in _estado.inventario:
		var cosa: Dictionary = _estado.inventario[slot]
		if not cosa.is_empty():
			partes.append("%d:%s" % [slot, str(cosa.get("nombre", "?"))])
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
	_comprobar("el correo de Tibia entrega la parcel en el depot",
		_fallas == 0)
	if _con != null:
		_con.cerrar()
	if _fallas == 0:
		print("Prueba viva de parcel y mailbox: OK")
	else:
		print("Prueba viva de parcel y mailbox: %d fallas" % _fallas)
	get_tree().quit(1 if _fallas > 0 else 0)
