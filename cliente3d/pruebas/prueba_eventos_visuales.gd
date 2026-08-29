extends Node

const ESTADO := preload("res://red/estado_mundo.gd")
const MENSAJE := preload("res://red/mensaje.gd")

var _fallas := 0
var _dialogo := {}
var _mensaje := {}
var _cuadrado := {}
var _comercio := []
var _comercio_cerro := false


func _ready() -> void:
	var estado := ESTADO.new()
	estado.dialogo_recibido.connect(func(quien, texto, posicion, clase):
		_dialogo = {"quien": quien, "texto": texto,
			"posicion": posicion, "clase": clase})
	estado.mensaje_pantalla.connect(func(texto, clase):
		_mensaje = {"texto": texto, "clase": clase})
	estado.cuadrado_criatura.connect(func(id, color):
		_cuadrado = {"id": id, "color": color})
	estado.comercio_actualizado.connect(func(nombre, propio, items):
		_comercio.append({"nombre": nombre, "propio": propio, "items": items}))
	estado.comercio_cerrado.connect(func(): _comercio_cerro = true)

	var msg := MENSAJE.new()
	msg.escribir_u8(0xAA)
	msg.escribir_u32(7)
	msg.escribir_texto("Rat")
	msg.escribir_u8(0x11)
	msg.escribir_u16(32097)
	msg.escribir_u16(32219)
	msg.escribir_u8(7)
	msg.escribir_texto("Hiss!")
	msg.escribir_u8(0xB4)
	msg.escribir_u8(0x16)
	msg.escribir_texto("You see a rat.")
	msg.escribir_u8(0x86)
	msg.escribir_u32(42)
	msg.escribir_u8(180)
	msg.escribir_u8(0x7D)
	msg.escribir_texto("Alice")
	msg.escribir_u8(1)
	msg.escribir_u16(3031)
	msg.escribir_u8(25)
	msg.escribir_u8(0x7E)
	msg.escribir_texto("Alice")
	msg.escribir_u8(1)
	msg.escribir_u16(3035)
	msg.escribir_u8(3)
	msg.escribir_u8(0x7F)
	estado.procesar(msg)

	_comprobar("dialogo conserva nombre, posicion y clase",
		_dialogo.get("quien") == "Rat"
		and _dialogo.get("texto") == "Hiss!"
		and _dialogo.get("posicion") == Vector3i(32097, 32219, 7)
		and int(_dialogo.get("clase", 0)) == 0x11)
	_comprobar("mensaje conserva clase verde",
		_mensaje.get("texto") == "You see a rat."
		and int(_mensaje.get("clase", 0)) == 0x16)
	_comprobar("cuadrado conserva criatura y color",
		int(_cuadrado.get("id", 0)) == 42
		and int(_cuadrado.get("color", 0)) == 180)
	_comprobar("trade conserva las dos ofertas",
		_comercio.size() == 2
		and _comercio[0].get("nombre") == "Alice"
		and bool(_comercio[0].get("propio", false))
		and int(_comercio[0].get("items", [])[0].get("cid", 0)) == 3031
		and not bool(_comercio[1].get("propio", true))
		and int(_comercio[1].get("items", [])[0].get("cid", 0)) == 3035)
	_comprobar("trade cierra su estado",
		_comercio_cerro and not estado.comercio.get("activo", true))
	_comprobar("los eventos no desalinean el paquete", msg.sin_leer() == 0)
	print("Eventos visuales TVP3D: %d falla(s)" % _fallas)
	get_tree().quit(1 if _fallas > 0 else 0)


func _comprobar(nombre: String, correcto: bool) -> void:
	if correcto:
		print("  OK  " + nombre)
	else:
		print("  FAIL " + nombre)
		_fallas += 1
