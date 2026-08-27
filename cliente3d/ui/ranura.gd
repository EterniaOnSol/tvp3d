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

# El protocolo transporta client IDs, no los IDs internos del servidor.
const IDS_MONEDAS := [3031, 3035, 3043]


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
	var anterior := _objeto.duplicate(true)
	_objeto = cosa.duplicate(true)
	if _objeto.is_empty():
		_icono.texture = _vacia
		_cantidad.text = ""
		tooltip_text = "Empty slot %d" % _slot
		if _es_cambio_de_moneda(anterior, _objeto):
			animar_acunado()
		return
	_icono.texture = _interfaz.icono_para_item(int(_objeto.get("cid", 0)))
	var cantidad := int(_objeto.get("cantidad", 1))
	_cantidad.text = str(cantidad) if cantidad > 1 else ""
	tooltip_text = str(_objeto.get("nombre", "item"))
	if _es_cambio_de_moneda(anterior, _objeto):
		animar_acunado()


static func _es_moneda(cosa: Dictionary) -> bool:
	return int(cosa.get("cid", 0)) in IDS_MONEDAS


static func _es_cambio_de_moneda(anterior: Dictionary,
		nuevo: Dictionary) -> bool:
	if anterior.is_empty() or not _es_moneda(anterior):
		return false
	if nuevo.is_empty():
		return true
	return not _es_moneda(nuevo) or int(anterior.get("cid", 0)) != int(nuevo.get("cid", 0)) \
		or int(anterior.get("cantidad", 1)) != int(nuevo.get("cantidad", 1))


func animar_acunado() -> void:
	var brillo := ColorRect.new()
	brillo.color = Color(1.0, 0.82, 0.22, 0.62)
	brillo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brillo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(brillo)
	var tamano := size
	if tamano.x <= 0.0 or tamano.y <= 0.0:
		tamano = Vector2(LADO, LADO)
	pivot_offset = tamano * 0.5
	var escala_anterior := scale
	var tween := create_tween().set_parallel(true)
	tween.tween_property(brillo, "modulate:a", 0.0, 0.42)
	tween.tween_property(self, "scale", escala_anterior * 1.14, 0.10)
	tween.chain().tween_property(self, "scale", escala_anterior, 0.22)
	tween.finished.connect(brillo.queue_free)


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
		if evento.shift_pressed and bool(_objeto.get("contenedor", false)):
			_interfaz.abrir_contenedor_desde_ranura(
				_tipo, _id_contenedor, _slot, _objeto)
		else:
			_interfaz.usar_ranura(_tipo, _id_contenedor, _slot, _objeto)
		accept_event()
	elif evento.button_index == MOUSE_BUTTON_LEFT and evento.shift_pressed:
		_interfaz.mirar_ranura(_tipo, _id_contenedor, _slot, _objeto)
		accept_event()
