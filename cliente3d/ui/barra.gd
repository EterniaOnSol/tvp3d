extends Control

## Barra compacta de vida, mana o progreso. El texto queda dentro de la
## barra, como en el cliente clasico, para que no dependa del ancho de la
## ventana.

class_name BarraTVP

const ALTO := 13

var _marco: ColorRect
var _relleno: ColorRect
var _izq: Label
var _der: Label
var _pct := 0.0


func _init(color: Color = Color(0.6, 0.2, 0.2), etiqueta: String = "",
		alto: int = ALTO) -> void:
	custom_minimum_size = Vector2(0, alto)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_marco = ColorRect.new()
	_marco.color = Color(0.05, 0.05, 0.05, 0.85)
	_marco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marco)

	_relleno = ColorRect.new()
	_relleno.color = color
	_relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relleno.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_relleno)

	_izq = _texto(etiqueta, HORIZONTAL_ALIGNMENT_LEFT)
	_izq.offset_left = 3
	add_child(_izq)
	_der = _texto("", HORIZONTAL_ALIGNMENT_RIGHT)
	_der.offset_right = -3
	add_child(_der)
	resized.connect(_reajustar)


func fijar(proporcion: float, texto: String = "") -> void:
	if _relleno == null:
		return
	_pct = clampf(proporcion, 0.0, 1.0)
	_der.text = texto
	_reajustar()


func fijar_color(color: Color) -> void:
	_relleno.color = color


func _texto(texto: String, alineacion: int) -> Label:
	var salida := Label.new()
	salida.text = texto
	salida.horizontal_alignment = alineacion
	salida.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	salida.add_theme_font_size_override("font_size", 9)
	salida.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	salida.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	salida.add_theme_constant_override("outline_size", 3)
	salida.set_anchors_preset(Control.PRESET_FULL_RECT)
	salida.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return salida


func _reajustar() -> void:
	if _relleno != null:
		_relleno.offset_right = -size.x * (1.0 - _pct)
