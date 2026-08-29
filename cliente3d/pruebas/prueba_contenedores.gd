extends Node

## Prueba de paridad del protocolo real de inventario/contenedores 7.72.
##
## El buffer imita exactamente ProtocolGame::sendContainer,
## sendAddContainerItem, sendUpdateContainerItem, sendRemoveContainerItem,
## sendInventoryItem y sendTextMessage. Al dejar otro mensaje al final se
## verifica que ningún item de largo variable haya desalineado el paquete.

const ESTADO := preload("res://red/estado_mundo.gd")
const MENSAJE := preload("res://red/mensaje.gd")

var _fallas := 0
var _actualizaciones := []
var _cerrado := false
var _pantalla := {}
var _canal_abierto := {}
var _canal_cerrado := 0


func _ready() -> void:
	var dialogo_prueba := ConfirmationDialog.new()
	add_child(dialogo_prueba)
	_comprobar("el selector de cantidad usa el dialogo nativo de Godot",
		dialogo_prueba is ConfirmationDialog)
	dialogo_prueba.queue_free()

	var estado := ESTADO.new()
	estado.contenedor_actualizado.connect(func(id, datos):
		_actualizaciones.append({"id": id, "datos": datos.duplicate(true)}))
	estado.contenedor_cerrado.connect(func(_id): _cerrado = true)
	estado.mensaje_pantalla.connect(func(texto, clase):
		_pantalla = {"texto": texto, "clase": clase})
	estado.canal_abierto.connect(func(id, nombre):
		_canal_abierto = {"id": id, "nombre": nombre})
	estado.canal_cerrado.connect(func(id): _canal_cerrado = id)

	var msg := MENSAJE.new()
	# ProtocolGame::sendContainer(cid=3, backpack=2854, name, capacity,
	# hasParent, item count, items). 3031/3035 son stackables y por eso
	# addItem agrega su byte de cantidad.
	msg.escribir_u8(0x6E)
	msg.escribir_u8(3)
	msg.escribir_u16(2854)
	msg.escribir_texto("Backpack")
	msg.escribir_u8(40)
	msg.escribir_u8(0)
	msg.escribir_u8(2)
	_escribir_item_apilable(msg, 3031, 25)
	_escribir_item_apilable(msg, 3035, 3)

	# Container::addItemFront -> sendAddContainerItem: el nuevo item entra
	# adelante, en la ranura 0.
	msg.escribir_u8(0x70)
	msg.escribir_u8(3)
	_escribir_item_apilable(msg, 3043, 1)

	# Container::onUpdateContainerItem.
	msg.escribir_u8(0x71)
	msg.escribir_u8(3)
	msg.escribir_u8(1)
	_escribir_item_apilable(msg, 3031, 100)

	# Container::onRemoveContainerItem desplaza el resto hacia adelante.
	msg.escribir_u8(0x72)
	msg.escribir_u8(3)
	msg.escribir_u8(0)

	# Inventario: el byte extra de un liquid es el color enviado por
	# NetworkMessage::addItem, no el FluidType interno.
	msg.escribir_u8(0x78)
	msg.escribir_u8(3)
	msg.escribir_u16(2874)
	msg.escribir_u8(1)
	msg.escribir_u8(0x79)
	msg.escribir_u8(4)

	# La lista y apertura de canales son mensajes variables del mismo
	# protocolo. Se dejan concatenados para detectar cualquier desalineacion.
	msg.escribir_u8(0xAB)
	msg.escribir_u8(2)
	msg.escribir_u16(3)
	msg.escribir_texto("Help")
	msg.escribir_u16(8)
	msg.escribir_texto("Trade")
	msg.escribir_u8(0xAC)
	msg.escribir_u16(3)
	msg.escribir_texto("Help")
	msg.escribir_u8(0xB2)
	msg.escribir_u16(99)
	msg.escribir_texto("Private Alice")

	# Mensaje posterior: si cualquier lectura anterior queda corrida, esta
	# clase/clase y el texto fallan o el parser deja bytes pendientes.
	msg.escribir_u8(0xB4)
	msg.escribir_u8(0x16)
	msg.escribir_texto("container packet complete")
	estado.procesar(msg)

	var contenedor: Dictionary = estado.contenedores.get(3, {})
	var apertura: Dictionary = _actualizaciones[0]["datos"] \
		if not _actualizaciones.is_empty() else {}
	var items: Array = apertura.get("items", [])
	_comprobar("abre el contenedor anunciado por el servidor",
		contenedor.get("nombre") == "Backpack"
		and int(contenedor.get("capacidad", 0)) == 40
		and int(contenedor.get("item", {}).get("cid", 0)) == 2854
		and bool(contenedor.get("item", {}).get("contenedor", false)))
	_comprobar("lee el contenido inicial y cantidades apilables",
		items.size() == 2
		and int(items[0].get("cid", 0)) == 3031
		and int(items[0].get("cantidad", 0)) == 25
		and int(items[1].get("cid", 0)) == 3035
		and int(items[1].get("cantidad", 0)) == 3)
	_comprobar("addItemFront ocupa la ranura cero",
		_actualizaciones.size() >= 1
		and int(estado.contenedores[3]["items"][0].get("cid", 0)) == 3031
		and int(estado.contenedores[3]["items"][0].get("cantidad", 0)) == 100)
	_comprobar("update y remove desplazan como Container",
		estado.contenedores[3]["items"].size() == 2
		and int(estado.contenedores[3]["items"][0].get("cid", 0)) == 3031
		and int(estado.contenedores[3]["items"][1].get("cid", 0)) == 3035)
	_comprobar("lee liquid del inventario con su byte de color",
		int(estado.inventario.get(3, {}).get("cid", 0)) == 2874
		and bool(estado.inventario.get(3, {}).get("liquido", false))
		and int(estado.inventario.get(3, {}).get("color_liquido", 0)) == 1)
	_comprobar("borra la ranura de inventario con 0x79",
		not estado.inventario.has(4))
	_comprobar("lee la lista y apertura de canales 7.72",
		estado.canales.get(3, "") == "Help"
		and estado.canales.get(8, "") == "Trade"
		and estado.canales_abiertos.get(3, "") == "Help"
		and _canal_abierto == {"id": 99, "nombre": "Private Alice"})
	_comprobar("el mensaje posterior queda intacto",
		_pantalla.get("texto") == "container packet complete"
		and int(_pantalla.get("clase", 0)) == 0x16
		and msg.sin_leer() == 0)

	# El servidor envia 0x6F sin datos variables. Se prueba aparte para no
	# confundir el estado final del ciclo anterior.
	var cierre := MENSAJE.new()
	cierre.escribir_u8(0x6F)
	cierre.escribir_u8(3)
	estado.procesar(cierre)
	_comprobar("cierra el contenedor con 0x6F", _cerrado
		and not estado.contenedores.has(3)
		and cierre.sin_leer() == 0)
	var cierre_canal := MENSAJE.new()
	cierre_canal.escribir_u8(0xB3)
	cierre_canal.escribir_u16(99)
	estado.procesar(cierre_canal)
	_comprobar("cierra el canal privado con 0xB3",
		_canal_cerrado == 99
		and not estado.canales_abiertos.has(99)
		and cierre_canal.sin_leer() == 0)

	print("Contenedores TVP3D: %d falla(s)" % _fallas)
	get_tree().quit(1 if _fallas > 0 else 0)


func _escribir_item_apilable(msg, cid: int, cantidad: int) -> void:
	msg.escribir_u16(cid)
	msg.escribir_u8(cantidad)


func _comprobar(nombre: String, correcto: bool) -> void:
	if correcto:
		print("  OK  " + nombre)
	else:
		print("  FAIL " + nombre)
		_fallas += 1
