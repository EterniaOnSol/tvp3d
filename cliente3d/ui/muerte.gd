extends CanvasLayer

## Pantalla de reentrada despues de morir.
##
## Esta rama de TVP 7.72 no envia ningun dialogo de muerte: no existe
## `sendDeath` ni `sendReLoginWindow` en `servidor/src/protocolgame.cpp`. Lo
## unico que llega es el `0x6C` que retira al jugador con la vida en cero, y
## el texto `You are dead.` de
## `servidor/data/scripts/creaturescripts/playerdeath.lua:12`.
##
## Por eso esta pantalla se arma en el cliente y no promete nada que el
## servidor no haya dicho: no muestra perdidas, no habla del templo y no
## revive a nadie. Solo confirma la muerte y ofrece volver al selector de
## personajes; lo que realmente paso se ve al reingresar.

signal solicito_reentrada()

## Mismo texto que el servidor manda por 0xB4 al morir.
const TEXTO_MUERTE := "You are dead."

var _panel: PanelContainer
var _titulo: Label
var _detalle: Label
var _boton: Button


func _ready() -> void:

	# Por encima del login (50) para que nunca quede tapada mientras el
	# cliente vuelve al selector.
	layer = 60
	_armar()
	visible = false


func _armar() -> void:

	var fondo := ColorRect.new()
	fondo.name = "Velo"
	fondo.color = Color(0.0, 0.0, 0.0, 0.55)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)

	_panel = PanelContainer.new()
	_panel.name = "DeathPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -220.0
	_panel.offset_top = -120.0
	_panel.offset_right = 220.0
	_panel.offset_bottom = 120.0
	add_child(_panel)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 26)
	margen.add_theme_constant_override("margin_top", 24)
	margen.add_theme_constant_override("margin_right", 26)
	margen.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margen)

	var cuerpo := VBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 14)
	margen.add_child(cuerpo)

	_titulo = Label.new()
	_titulo.name = "DeathTitle"
	_titulo.text = TEXTO_MUERTE
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_font_size_override("font_size", 30)
	_titulo.add_theme_color_override("font_color", Color(0.86, 0.30, 0.28))
	cuerpo.add_child(_titulo)

	_detalle = Label.new()
	_detalle.name = "DeathDetail"
	_detalle.text = "You have been logged out of the world."
	_detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84))
	cuerpo.add_child(_detalle)

	_boton = Button.new()
	_boton.name = "DeathReturn"
	_boton.text = "Return to character list"
	_boton.custom_minimum_size.y = 36
	_boton.pressed.connect(_al_pulsar)
	cuerpo.add_child(_boton)


func mostrar(detalle: String = "") -> void:
	"""Deja la pantalla a la vista y habilita la reentrada."""

	if _titulo != null:
		_titulo.text = TEXTO_MUERTE
	if _detalle != null and not detalle.is_empty():
		_detalle.text = detalle
	if _boton != null:
		_boton.disabled = false
		_boton.grab_focus()
	visible = true


func ocultar() -> void:

	visible = false


func _al_pulsar() -> void:

	if _boton != null:
		# Un solo regreso por muerte: el segundo clic no puede pedir dos veces
		# la lista de personajes.
		_boton.disabled = true
	solicito_reentrada.emit()
