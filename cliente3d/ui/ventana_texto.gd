extends CanvasLayer

## Ventana de texto de carteles, cartas y etiquetas.
##
## La abre el servidor con el `0x96` cuando el jugador usa un item escribible o
## legible, y la respuesta vuelve por el `0x89` (`protocolo-red` 1.6.0). El
## paquete no dice si el item se puede escribir: manda un maximo de caracteres
## y, si no correspondia, el servidor rechaza el envio con un `0xB4`. Por eso
## esta ventana siempre deja escribir y no adivina permisos.
##
## Lo que se ve es lo que mando el servidor: el nombre del item, quien lo
## escribio y el texto actual. El cliente no inventa nada.

signal escribio(id_ventana: int, texto: String)

var _panel: PanelContainer
var _titulo: Label
var _autor: Label
var _caja: TextEdit
var _contador: Label
var _id_ventana := 0
var _maximo := 0


func _ready() -> void:
	# Debajo de la pantalla de muerte (60) y encima del juego.
	layer = 55
	_armar()
	visible = false


func _armar() -> void:
	var fondo := ColorRect.new()
	fondo.name = "Velo"
	fondo.color = Color(0.0, 0.0, 0.0, 0.45)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)

	_panel = PanelContainer.new()
	_panel.name = "TextWindow"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -230.0
	_panel.offset_top = -150.0
	_panel.offset_right = 230.0
	_panel.offset_bottom = 150.0
	var marco := StyleBoxFlat.new()
	marco.bg_color = Color(0.055, 0.060, 0.065, 0.98)
	marco.border_color = Color(0.235, 0.250, 0.270, 1.0)
	marco.set_border_width_all(1)
	marco.content_margin_left = 18
	marco.content_margin_right = 18
	marco.content_margin_top = 14
	marco.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", marco)
	add_child(_panel)

	var caja_vertical := VBoxContainer.new()
	caja_vertical.add_theme_constant_override("separation", 8)
	_panel.add_child(caja_vertical)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 15)
	_titulo.add_theme_color_override("font_color", Color(0.90, 0.86, 0.72))
	caja_vertical.add_child(_titulo)

	_autor = Label.new()
	_autor.add_theme_font_size_override("font_size", 11)
	_autor.add_theme_color_override("font_color", Color(0.60, 0.63, 0.66))
	caja_vertical.add_child(_autor)

	_caja = TextEdit.new()
	_caja.custom_minimum_size = Vector2(420, 180)
	_caja.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_caja.text_changed.connect(_al_cambiar_texto)
	caja_vertical.add_child(_caja)

	var pie := HBoxContainer.new()
	pie.add_theme_constant_override("separation", 10)
	caja_vertical.add_child(pie)

	_contador = Label.new()
	_contador.add_theme_font_size_override("font_size", 11)
	_contador.add_theme_color_override("font_color", Color(0.60, 0.63, 0.66))
	_contador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pie.add_child(_contador)

	var cancelar := Button.new()
	cancelar.text = "Cancel"
	cancelar.custom_minimum_size = Vector2(90, 26)
	cancelar.pressed.connect(cerrar)
	pie.add_child(cancelar)

	var aceptar := Button.new()
	aceptar.text = "Ok"
	aceptar.custom_minimum_size = Vector2(90, 26)
	aceptar.pressed.connect(_al_aceptar)
	pie.add_child(aceptar)


func mostrar(datos: Dictionary) -> void:
	"""Abre la ventana con lo que mando el servidor."""
	_id_ventana = int(datos.get("id", 0))
	_maximo = int(datos.get("maximo", 0))
	var nombre := str(datos.get("nombre", ""))
	_titulo.text = "You read: %s" % nombre if not nombre.is_empty() \
		else "You read:"
	var autor := str(datos.get("autor", ""))
	_autor.text = "Written by %s" % autor if not autor.is_empty() \
		else "Nothing is written on it."
	_caja.text = str(datos.get("texto", ""))
	_caja.editable = _maximo > 0
	_actualizar_contador()
	visible = true
	_caja.grab_focus()


func cerrar() -> void:
	visible = false
	_id_ventana = 0


func _al_aceptar() -> void:
	if _id_ventana > 0:
		escribio.emit(_id_ventana, _caja.text)
	cerrar()


func _al_cambiar_texto() -> void:
	# El maximo lo pone el servidor; pasarse solo consigue que rechace el
	# envio, asi que se corta aca y se avisa cuanto queda.
	if _maximo > 0 and _caja.text.length() > _maximo:
		var cursor := _caja.get_caret_column()
		_caja.text = _caja.text.substr(0, _maximo)
		_caja.set_caret_column(mini(cursor, _maximo))
	_actualizar_contador()


func _actualizar_contador() -> void:
	if _maximo > 0:
		_contador.text = "%d / %d characters" % [_caja.text.length(), _maximo]
	else:
		_contador.text = ""


func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento is InputEventKey and evento.pressed \
			and evento.keycode == KEY_ESCAPE:
		cerrar()
		get_viewport().set_input_as_handled()
