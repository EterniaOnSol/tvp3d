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
var _relleno_liquido: Polygon2D
var _cantidad: Label
var _duracion: Label
var _duracion_fondo: PanelContainer
var _vacia: Texture2D
var _combo_mirar := false
var _derecho_shift := false
var _duracion_ms := 0
var _duracion_inicio_ms := 0

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

	# El vial es un recipiente transparente: el contenido debe quedar detras
	# del sprite, dentro del cuerpo, y nunca colorear el vidrio ni el tapon.
	_relleno_liquido = Polygon2D.new()
	var escala_mascara := float(LADO) / 32.0
	_relleno_liquido.polygon = PackedVector2Array([
		Vector2(15.0, 14.0) * escala_mascara,
		Vector2(21.5, 14.0) * escala_mascara,
		Vector2(23.5, 16.0) * escala_mascara,
		Vector2(23.5, 21.5) * escala_mascara,
		Vector2(21.0, 22.8) * escala_mascara,
		Vector2(16.5, 21.8) * escala_mascara,
		Vector2(14.5, 18.0) * escala_mascara,
	])
	_relleno_liquido.visible = false
	add_child(_relleno_liquido)

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

	_duracion_fondo = PanelContainer.new()
	_duracion_fondo.position = Vector2(1, LADO - 15)
	_duracion_fondo.size = Vector2(LADO - 2, 14)
	_duracion_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fondo_duracion := StyleBoxFlat.new()
	fondo_duracion.bg_color = Color(0.015, 0.018, 0.025, 0.88)
	fondo_duracion.border_color = Color(0.80, 0.58, 0.18, 0.95)
	fondo_duracion.set_border_width_all(1)
	fondo_duracion.set_corner_radius_all(2)
	_duracion_fondo.add_theme_stylebox_override("panel", fondo_duracion)
	add_child(_duracion_fondo)

	_duracion = Label.new()
	_duracion.add_theme_font_size_override("font_size", 9)
	_duracion.add_theme_color_override("font_color", Color(1.0, 0.90, 0.48))
	_duracion.add_theme_color_override("font_outline_color", Color.BLACK)
	_duracion.add_theme_constant_override("outline_size", 3)
	_duracion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_duracion.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_duracion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_duracion_fondo.add_child(_duracion)
	_duracion_fondo.visible = false


func mostrar(cosa: Dictionary) -> void:
	var anterior := _objeto.duplicate(true)
	var cid_anterior := int(anterior.get("cid", 0))
	var duracion_anterior := int(anterior.get("duracion_ms", 0))
	_objeto = cosa.duplicate(true)
	if _objeto.is_empty():
		_icono.texture = _vacia
		_icono.modulate = Color.WHITE
		_relleno_liquido.visible = false
		_cantidad.text = ""
		_duracion_ms = 0
		_duracion_inicio_ms = 0
		_duracion.text = ""
		_duracion_fondo.visible = false
		tooltip_text = "Empty slot %d" % _slot
		if _es_cambio_de_moneda(anterior, _objeto):
			animar_acunado(int(anterior.get("cantidad", 1)))
		return
	_icono.texture = _interfaz.icono_para_item(int(_objeto.get("cid", 0)))
	# El sprite del vial es comun a todos los fluidos. El color viaja en el
	# byte adicional del objeto y se aplica sin alterar los sprites de criaturas.
	var color_liquido := int(_objeto.get("color_liquido", 0))
	_icono.modulate = Color.WHITE
	_relleno_liquido.color = _interfaz.color_para_liquido(color_liquido)
	_relleno_liquido.visible = bool(_objeto.get("liquido", false)) \
		and color_liquido > 0
	var cantidad := int(_objeto.get("cantidad", 1))
	_cantidad.text = str(cantidad) if cantidad > 1 else ""
	var cid_actual := int(_objeto.get("cid", 0))
	var duracion_nueva := maxi(0, int(_objeto.get("duracion_ms", 0)))
	if cid_actual != cid_anterior or duracion_nueva != duracion_anterior:
		_duracion_inicio_ms = Time.get_ticks_msec()
	_duracion_ms = duracion_nueva
	_actualizar_duracion_visual()
	tooltip_text = str(_objeto.get("nombre", "item"))
	if _es_cambio_de_moneda(anterior, _objeto):
		animar_acunado(cantidad)


func _process(_delta: float) -> void:
	if _duracion_ms > 0:
		_actualizar_duracion_visual()


func _actualizar_duracion_visual() -> void:
	if _duracion_ms <= 0:
		_duracion.text = ""
		_duracion_fondo.visible = false
		return
	_duracion_fondo.visible = true
	var restante := maxi(0, _duracion_ms - (Time.get_ticks_msec() - _duracion_inicio_ms))
	var total_segundos := maxi(0, int(ceili(float(restante) / 1000.0)))
	var minutos := total_segundos / 60
	var segundos := total_segundos % 60
	_duracion.text = "%d:%02d" % [minutos, segundos]
	tooltip_text = "%s\nRemaining: %d:%02d" % [
		str(_objeto.get("nombre", "item")), minutos, segundos]


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


func animar_acunado(cantidad: int = -1) -> void:
	if cantidad < 0:
		cantidad = int(_objeto.get("cantidad", 1))
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
	var etiqueta := Label.new()
	etiqueta.text = str(maxi(1, cantidad))
	etiqueta.add_theme_font_size_override("font_size", 14)
	etiqueta.add_theme_color_override("font_color", Color(1.0, 0.92, 0.30))
	etiqueta.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.0, 0.98))
	etiqueta.add_theme_constant_override("outline_size", 4)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.position = Vector2(0.0, -13.0)
	etiqueta.size = Vector2(LADO, 20.0)
	add_child(etiqueta)
	var tween_numero := create_tween().set_parallel(true)
	tween_numero.tween_property(etiqueta, "position:y", -25.0, 0.42)
	tween_numero.tween_property(etiqueta, "modulate:a", 0.0, 0.42)
	tween.finished.connect(brillo.queue_free)
	tween_numero.finished.connect(etiqueta.queue_free)


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
		"apilable": bool(_objeto.get("apilable", false)),
		"nombre": str(_objeto.get("nombre", "item"))}


func _can_drop_data(_pos: Vector2, datos: Variant) -> bool:
	return datos is Dictionary and datos.get("tipo", "") in [
		"inventario", "contenedor"]


func _drop_data(_pos: Vector2, datos: Variant) -> void:
	_interfaz.mover_a_ranura(datos, _tipo, _id_contenedor, _slot)


func _otro_boton_apretado(boton: int) -> bool:
	"""Si el otro boton esta apretado DE VERDAD, ahora mismo.

	Antes esto se llevaba en dos banderas propias, y bastaba con que un soltar
	se perdiera fuera del slot —al arrastrar, al abrir una ventana o al salir
	del control— para que quedaran trabadas: desde ahi, cada clic derecho se
	interpretaba como el combo de mirar y ya no se podia usar nada."""
	return Input.is_mouse_button_pressed(boton)


func _gui_input(evento: InputEvent) -> void:
	if not (evento is InputEventMouseButton):
		return

	if evento.button_index == MOUSE_BUTTON_LEFT:
		if _objeto.is_empty():
			return
		if evento.pressed and _otro_boton_apretado(MOUSE_BUTTON_RIGHT):
			# Tibia usa ambos botones a la vez para mirar el objeto. Se
			# comprueba en los dos sentidos: izquierdo->derecho y
			# derecho->izquierdo.
			_combo_mirar = true
			_interfaz.mirar_ranura(_tipo, _id_contenedor, _slot, _objeto)
			accept_event()
		elif evento.pressed and evento.shift_pressed:
			_interfaz.mirar_ranura(_tipo, _id_contenedor, _slot, _objeto)
			accept_event()
		elif not evento.pressed and _combo_mirar:
			accept_event()
		return

	if evento.button_index != MOUSE_BUTTON_RIGHT:
		return

	if evento.pressed:
		if _interfaz.cancelar_uso_con():
			# El derecho cancela Use with incluso si el cursor esta sobre
			# otra runa o sobre el mismo slot.
			_combo_mirar = true
			accept_event()
			return
		if _objeto.is_empty():
			return
		_derecho_shift = evento.shift_pressed
		if _otro_boton_apretado(MOUSE_BUTTON_LEFT):
			_combo_mirar = true
			_interfaz.mirar_ranura(_tipo, _id_contenedor, _slot, _objeto)
		accept_event()
		return

	if not _objeto.is_empty() and not _combo_mirar:
		if _derecho_shift and bool(_objeto.get("contenedor", false)):
			_interfaz.abrir_contenedor_desde_ranura(
				_tipo, _id_contenedor, _slot, _objeto)
		else:
			_interfaz.usar_ranura(_tipo, _id_contenedor, _slot, _objeto)
	accept_event()
	_combo_mirar = false
