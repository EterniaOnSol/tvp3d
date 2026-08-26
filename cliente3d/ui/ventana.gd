extends PanelContainer

## Marco reutilizable inspirado en las ventanas del cliente 2D de Tibia.
## El contenido se agrega a `cuerpo`; la barra permite plegar y mover la
## ventana sin acoplarla al layout del mundo 3D.

signal cerrar_solicitado

const FONDO := Color(0.055, 0.060, 0.065, 0.98)
const BORDE := Color(0.235, 0.250, 0.270, 1.0)
const BORDE_ACTIVO := Color(0.38, 0.70, 0.84, 1.0)
const TEXTO := Color(0.88, 0.89, 0.90, 1.0)
const TENUE := Color(0.60, 0.63, 0.66, 1.0)

var cuerpo: VBoxContainer
var _marco: StyleBoxFlat
var _titulo: Label
var _boton_plegar: Button
var _cuerpo_contenedor: VBoxContainer
var _plegada := false
var _arrastrando := false
var _agarre := Vector2.ZERO
var reordenable := false
signal pidio_reordenar(pos_global: Vector2)


func _init(texto: String = "Window", con_cerrar: bool = false) -> void:
	custom_minimum_size = Vector2(190, 40)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_marco = StyleBoxFlat.new()
	_marco.bg_color = FONDO
	_marco.border_color = BORDE
	_marco.set_border_width_all(1)
	_marco.set_corner_radius_all(1)
	_marco.content_margin_left = 5
	_marco.content_margin_right = 5
	_marco.content_margin_top = 3
	_marco.content_margin_bottom = 5
	add_theme_stylebox_override("panel", _marco)

	var exterior := VBoxContainer.new()
	exterior.add_theme_constant_override("separation", 3)
	add_child(exterior)

	var barra := Control.new()
	barra.custom_minimum_size.y = 16
	barra.mouse_filter = Control.MOUSE_FILTER_STOP
	barra.gui_input.connect(_al_input_de_barra)
	exterior.add_child(barra)

	var plegar := Button.new()
	plegar.text = "▾"
	plegar.flat = true
	plegar.position = Vector2(0, 0)
	plegar.size = Vector2(18, 16)
	plegar.add_theme_font_size_override("font_size", 10)
	plegar.pressed.connect(alternar_plegado)
	barra.add_child(plegar)
	_boton_plegar = plegar

	_titulo = Label.new()
	_titulo.text = texto
	_titulo.position = Vector2(20, 0)
	_titulo.size = Vector2(135, 16)
	_titulo.add_theme_font_size_override("font_size", 11)
	_titulo.add_theme_color_override("font_color", TEXTO)
	_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.add_child(_titulo)

	if con_cerrar:
		var cerrar := Button.new()
		cerrar.text = "X"
		cerrar.flat = true
		cerrar.position = Vector2(164, 0)
		cerrar.size = Vector2(18, 16)
		cerrar.add_theme_font_size_override("font_size", 10)
		cerrar.pressed.connect(func(): cerrar_solicitado.emit())
		barra.add_child(cerrar)

	_cuerpo_contenedor = VBoxContainer.new()
	_cuerpo_contenedor.add_theme_constant_override("separation", 4)
	exterior.add_child(_cuerpo_contenedor)
	cuerpo = _cuerpo_contenedor


func alternar_plegado() -> void:
	_plegada = not _plegada
	_cuerpo_contenedor.visible = not _plegada
	_boton_plegar.text = ">" if _plegada else "v"


func fijar_titulo(texto: String) -> void:
	if _titulo != null:
		_titulo.text = texto


func _al_input_de_barra(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		if evento.pressed:
			_arrastrando = true
			_agarre = evento.position
			_marco.border_color = BORDE_ACTIVO
			_marco.set_border_width_all(2)
			accept_event()
		else:
			_arrastrando = false
			_marco.border_color = BORDE
			_marco.set_border_width_all(1)
			accept_event()
	elif evento is InputEventMouseMotion and _arrastrando:
		if reordenable:
			pidio_reordenar.emit(get_global_mouse_position())
		else:
			position += evento.relative
		accept_event()


static func etiqueta(texto: String, tam: int = 11,
		color: Color = TEXTO) -> Label:
	var salida := Label.new()
	salida.text = texto
	salida.add_theme_font_size_override("font_size", tam)
	salida.add_theme_color_override("font_color", color)
	salida.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return salida


static func separador() -> HSeparator:
	var salida := HSeparator.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.22, 0.24, 0.26, 0.85)
	estilo.content_margin_top = 1
	estilo.content_margin_bottom = 1
	salida.add_theme_stylebox_override("separator", estilo)
	return salida
