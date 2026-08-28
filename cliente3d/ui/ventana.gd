extends PanelContainer

## Marco reutilizable inspirado en las ventanas del cliente 2D de Tibia.
## El contenido se agrega a `cuerpo`; la barra permite plegar y mover la
## ventana sin acoplarla al layout del mundo 3D.

signal cerrar_solicitado
signal tamano_cambio(nuevo: Vector2)

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
var _minimo_expandido := Vector2.ZERO
var _tamano_expandido := Vector2.ZERO
var _arrastrando := false
var _agarre := Vector2.ZERO
var _redimensionando := false
var _tamano_redimension := Vector2.ZERO
var _mouse_redimension := Vector2.ZERO
var reordenable := false
signal pidio_reordenar(pos_global: Vector2)


func _init(texto: String = "Window", con_cerrar: bool = false) -> void:
	custom_minimum_size = Vector2(190, 40)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
	# El PanelContainer puede crecer al redimensionarse. El VBox exterior y,
	# sobre todo, el cuerpo deben recibir ese espacio para que sus ScrollContainer
	# muestren mas filas en vez de conservar solo su altura minima.
	exterior.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exterior.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(exterior)

	var barra := HBoxContainer.new()
	barra.custom_minimum_size.y = 16
	barra.mouse_filter = Control.MOUSE_FILTER_STOP
	barra.gui_input.connect(_al_input_de_barra)
	exterior.add_child(barra)

	var plegar := Button.new()
	plegar.text = "-"
	plegar.flat = true
	plegar.custom_minimum_size = Vector2(18, 16)
	plegar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plegar.add_theme_font_size_override("font_size", 10)
	plegar.pressed.connect(alternar_plegado)
	barra.add_child(plegar)
	_boton_plegar = plegar

	_titulo = Label.new()
	_titulo.text = texto
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_titulo.add_theme_font_size_override("font_size", 11)
	_titulo.add_theme_color_override("font_color", TEXTO)
	_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.add_child(_titulo)

	if con_cerrar:
		var cerrar := Button.new()
		cerrar.text = "X"
		cerrar.flat = true
		cerrar.custom_minimum_size = Vector2(18, 16)
		cerrar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cerrar.add_theme_font_size_override("font_size", 10)
		cerrar.pressed.connect(func(): cerrar_solicitado.emit())
		barra.add_child(cerrar)

	_cuerpo_contenedor = VBoxContainer.new()
	_cuerpo_contenedor.add_theme_constant_override("separation", 4)
	_cuerpo_contenedor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cuerpo_contenedor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	exterior.add_child(_cuerpo_contenedor)
	cuerpo = _cuerpo_contenedor

	# Todas las ventanas comparten este asa, incluidas las que viven dentro
	# de los docks. El minimo sigue evitando que el contenido desaparezca,
	# pero el jugador puede ampliar cada panel a su gusto.
	var pie := HBoxContainer.new()
	pie.alignment = BoxContainer.ALIGNMENT_END
	pie.custom_minimum_size.y = 9
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var asa := Control.new()
	asa.name = "AsaRedimension"
	asa.custom_minimum_size = Vector2(13, 9)
	asa.mouse_filter = Control.MOUSE_FILTER_STOP
	asa.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	asa.gui_input.connect(_al_input_de_asa)
	# Tres puntos visibles hacen descubrible el resize y no dependen de un
	# caracter Unicode que puede cambiar segun la fuente o la codificacion.
	for punto in [Vector2(9, 0), Vector2(6, 3), Vector2(3, 6)]:
		var marca := ColorRect.new()
		marca.position = punto
		marca.size = Vector2(2, 2)
		marca.color = Color(0.45, 0.50, 0.55, 0.90)
		marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
		asa.add_child(marca)
	pie.add_child(asa)
	exterior.add_child(pie)


func alternar_plegado() -> void:
	_plegada = not _plegada
	_cuerpo_contenedor.visible = not _plegada
	if _plegada:
		_minimo_expandido = custom_minimum_size
		_tamano_expandido = size
		custom_minimum_size = Vector2(custom_minimum_size.x, 40)
		size.y = 40
		_boton_plegar.text = "+"
	else:
		custom_minimum_size = _minimo_expandido if _minimo_expandido.y > 0 else Vector2(190, 40)
		size.y = maxf(_tamano_expandido.y, custom_minimum_size.y)
		_boton_plegar.text = "-"


func fijar_titulo(texto: String) -> void:
	if _titulo != null:
		_titulo.text = texto


func _al_input_de_asa(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		if evento.pressed:
			_redimensionando = true
			_tamano_redimension = size
			_mouse_redimension = get_global_mouse_position()
			_marco.border_color = BORDE_ACTIVO
			_marco.set_border_width_all(2)
			accept_event()
		else:
			_redimensionando = false
			_marco.border_color = BORDE
			_marco.set_border_width_all(1)
			accept_event()
	elif evento is InputEventMouseMotion and _redimensionando:
		var delta := get_global_mouse_position() - _mouse_redimension
		var nuevo := Vector2(
			clampf(_tamano_redimension.x + delta.x, 190.0, 360.0),
			clampf(_tamano_redimension.y + delta.y, 40.0, 520.0))
		custom_minimum_size = nuevo
		size = nuevo
		tamano_cambio.emit(nuevo)
		accept_event()


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
