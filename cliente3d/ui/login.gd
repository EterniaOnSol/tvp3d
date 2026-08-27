extends CanvasLayer

## Acceso 7.72: primero autentica la cuenta y luego deja elegir personaje.
## La escena no guarda credenciales; solo las mantiene en memoria mientras
## se completa el inicio de esta partida.

signal solicito_login(cuenta: int, clave: String)
signal solicito_personaje(personaje: Dictionary)

var _panel: PanelContainer
var _cuerpo: VBoxContainer
var _cuenta: LineEdit
var _clave: LineEdit
var _boton_login: Button
var _estado: Label
var _lista: VBoxContainer


func _ready() -> void:

	layer = 50
	_armar()


func _armar() -> void:

	_panel = PanelContainer.new()
	_panel.name = "LoginPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -210.0
	_panel.offset_top = -190.0
	_panel.offset_right = 210.0
	_panel.offset_bottom = 190.0
	add_child(_panel)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 24)
	margen.add_theme_constant_override("margin_top", 22)
	margen.add_theme_constant_override("margin_right", 24)
	margen.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margen)
	_cuerpo = VBoxContainer.new()
	_cuerpo.add_theme_constant_override("separation", 10)
	margen.add_child(_cuerpo)

	var titulo := Label.new()
	titulo.text = "TVP3D"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 28)
	_cuerpo.add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "Cuenta 7.72"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))
	_cuerpo.add_child(subtitulo)

	_cuerpo.add_child(_etiqueta("Account"))
	_cuenta = LineEdit.new()
	_cuenta.name = "Account"
	_cuenta.placeholder_text = "Account number"
	_cuenta.text = ""
	_cuenta.text_submitted.connect(func(_texto): _enviar_login())
	_cuerpo.add_child(_cuenta)

	_cuerpo.add_child(_etiqueta("Password"))
	_clave = LineEdit.new()
	_clave.name = "Password"
	_clave.placeholder_text = "Password"
	_clave.secret = true
	_clave.text_submitted.connect(func(_texto): _enviar_login())
	_cuerpo.add_child(_clave)

	_boton_login = Button.new()
	_boton_login.text = "Log in"
	_boton_login.custom_minimum_size.y = 34
	_boton_login.pressed.connect(_enviar_login)
	_cuerpo.add_child(_boton_login)

	_estado = Label.new()
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estado.custom_minimum_size.y = 42
	_cuerpo.add_child(_estado)

	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 5)
	_cuerpo.add_child(_lista)


func _etiqueta(texto: String) -> Label:

	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84))
	return etiqueta


func _enviar_login() -> void:

	var cuenta_texto := _cuenta.text.strip_edges()
	var clave_texto := _clave.text
	if cuenta_texto.is_empty() or int(cuenta_texto) <= 0:
		mostrar_error("Enter a valid account number.")
		return
	if clave_texto.is_empty():
		mostrar_error("Enter your password.")
		return
	_boton_login.disabled = true
	_estado.text = "Connecting to account server..."
	_lista.visible = false
	solicito_login.emit(int(cuenta_texto), clave_texto)


func mostrar_estado(texto: String) -> void:

	_panel.visible = true
	_boton_login.disabled = true
	_estado.text = texto


func mostrar_error(texto: String) -> void:

	_panel.visible = true
	_boton_login.disabled = false
	_lista.visible = false
	_estado.text = texto


func mostrar_personajes(motd: String, personajes: Array) -> void:

	_panel.visible = true
	_boton_login.disabled = false
	_lista.visible = true
	_estado.text = motd if not motd.is_empty() else "Choose a character."
	for hijo in _lista.get_children():
		hijo.queue_free()
	if personajes.is_empty():
		_lista.add_child(_etiqueta("This account has no characters."))
		return
	for personaje in personajes:
		var p: Dictionary = personaje
		var boton := Button.new()
		boton.text = "%s  —  %s" % [str(p.get("nombre", "Character")),
			str(p.get("mundo", "World"))]
		boton.custom_minimum_size.y = 32
		boton.pressed.connect(func(): solicito_personaje.emit(p))
		_lista.add_child(boton)


func mostrar_login() -> void:

	_panel.visible = true
	_boton_login.disabled = false
	_lista.visible = false
	_estado.text = ""
