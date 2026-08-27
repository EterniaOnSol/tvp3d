extends Panel

## Ranura de equipo/inventario inspirada en 3DTIBIA.
## La ranura solo presenta el estado; las operaciones viajan por la conexion.

const LADO := 34

const DIBUJO_VACIA := {
	1: "head", 2: "neck", 3: "back", 4: "body", 5: "right-hand",
	6: "left-hand", 7: "legs", 8: "feet", 9: "finger", 10: "ammo",
}

var _interfaz
var _slot := 0
var _tipo := "inventario"
var _id_contenedor := -1
var _objeto: Dictionary = {}
var _icono: TextureRect
var _cantidad: Label
var _vacia: Texture2D


func _init(interfaz, slot: int, tipo: String = "inventario",
		id_contenedor: int = -1) -> void:
	_interfaz = interfaz
	_slot = slot
	_tipo = tipo
	_id_contenedor = id_contenedor
	custom_minimum_size = Vector2(LADO, LADO)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if tipo == "inventario":
		_vacia = _cargar_dibujo_vacio(slot)

	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.055, 0.060, 0.065, 0.98)
	fondo.border_color = Color(0.25, 0.27, 0.29)
	fondo.set_border_width_all(1)
	add_theme_stylebox_override("panel", fondo)

	_icono = TextureRect.new()
	_icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icono.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icono)

	_cantidad = Label.new()
	_cantidad.add_theme_font_size_override("font_size", 11)
	_cantidad.add_theme_color_override("font_color", Color.WHITE)
	_cantidad.add_theme_color_override("font_outline_color", Color.BLACK)
	_cantidad.add_theme_constant_override("outline_size", 4)
	_cantidad.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_cantidad.position = Vector2(-22, -17)
	_cantidad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cantidad)


func mostrar(cosa: Dictionary) -> void:
	_objeto = cosa.duplicate(true)
	if _objeto.is_empty():
		_icono.texture = _vacia
		_cantidad.text = ""
		tooltip_text = "Empty slot %d" % _slot
		return
	_icono.texture = _interfaz.icono_para_item(int(_objeto.get("cid", 0)))
	var cantidad := int(_objeto.get("cantidad", 1))
	_cantidad.text = str(cantidad) if cantidad > 1 else ""
	tooltip_text = str(_objeto.get("nombre", "item"))


static func _cargar_dibujo_vacio(slot: int) -> Texture2D:
	if not DIBUJO_VACIA.has(slot):
		return null
	var ruta := "res://assets/ui/slots/%s.png" % DIBUJO_VACIA[slot]
	return load(ruta) as Texture2D


func _get_drag_data(_pos: Vector2) -> Variant:
	if _objeto.is_empty() or not bool(_objeto.get("movible", false)):
		return null
	var vista := TextureRect.new()
	vista.texture = _icono.texture
	vista.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vista.custom_minimum_size = Vector2(LADO, LADO)
	vista.size = Vector2(LADO, LADO)
	vista.modulate.a = 0.85
	set_drag_preview(vista)
	return {"tipo": _tipo, "slot": _slot,
		"contenedor": _id_contenedor,
		"cid": int(_objeto.get("cid", 0)),
		"cantidad": int(_objeto.get("cantidad", 1)),
		"nombre": str(_objeto.get("nombre", "item"))}


func _can_drop_data(_pos: Vector2, datos: Variant) -> bool:
	return datos is Dictionary and datos.get("tipo", "") in [
		"inventario", "contenedor"]


func _drop_data(_pos: Vector2, datos: Variant) -> void:
	_interfaz.mover_a_ranura(datos, _tipo, _id_contenedor, _slot)


func _gui_input(evento: InputEvent) -> void:
	if _objeto.is_empty() or not (evento is InputEventMouseButton) \
			or not evento.pressed:
		return
	if evento.button_index == MOUSE_BUTTON_RIGHT:
		_interfaz.usar_inventario(_slot, _objeto)
		accept_event()
	elif evento.button_index == MOUSE_BUTTON_LEFT and evento.shift_pressed:
		_interfaz.mirar_inventario(_slot, _objeto)
		accept_event()
