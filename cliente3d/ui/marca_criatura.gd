extends Control

## Calavera y escudo de party de una criatura.
##
## Las dos tablas son dato de dominio copiado de `servidor/src/const.h:179-193`
## (`Skulls_t` y `PartyShields_t`). La marca no decide nada ni interpreta el
## combate: solo pinta el valor que el servidor confirmo en `AddCreature` o en
## los cambios `0x90` y `0x91`, tal como los conserva `protocolo-red` 1.1.0.
##
## El significado del escudo esta escrito desde el punto de vista del jugador
## que mira, que es como lo calcula `Player::getPartyShield`
## (`servidor/src/player.cpp:3742-3767`): el servidor ya resuelve quien invito a
## quien y el cliente solo muestra el resultado.

const CALAVERAS := {
	1: {"nombre": "Yellow Skull", "color": Color(0.96, 0.82, 0.16)},
	2: {"nombre": "Green Skull", "color": Color(0.30, 0.78, 0.32)},
	3: {"nombre": "White Skull", "color": Color(0.94, 0.94, 0.94)},
	4: {"nombre": "Red Skull", "color": Color(0.88, 0.15, 0.13)},
}

const ESCUDOS := {
	1: {"nombre": "Party invitation received",
		"color": Color(0.96, 0.82, 0.16), "contorno": true},
	2: {"nombre": "Party invitation sent",
		"color": Color(0.30, 0.48, 0.94), "contorno": true},
	3: {"nombre": "Party member",
		"color": Color(0.30, 0.48, 0.94), "contorno": false},
	4: {"nombre": "Party leader",
		"color": Color(0.96, 0.82, 0.16), "contorno": false},
}

const CALAVERA := "calavera"
const ESCUDO := "escudo_party"
const CONTORNO := Color(0.02, 0.02, 0.03, 0.95)

var clase: String = CALAVERA
var valor := 0


func _init(p_clase: String = CALAVERA, lado: float = 11.0) -> void:
	clase = p_clase
	custom_minimum_size = Vector2(lado, lado)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS
	visible = false


func tabla() -> Dictionary:
	return CALAVERAS if clase == CALAVERA else ESCUDOS


func mostrar(nuevo: int) -> void:
	"""Aplica el valor autoritativo. Un valor fuera de la tabla no se dibuja."""
	valor = nuevo
	var entrada: Dictionary = tabla().get(nuevo, {})
	visible = not entrada.is_empty()
	tooltip_text = str(entrada.get("nombre", ""))
	queue_redraw()


func _draw() -> void:
	var entrada: Dictionary = tabla().get(valor, {})
	if entrada.is_empty():
		return
	var lado: float = minf(size.x, size.y)
	if lado <= 0.0:
		lado = minf(custom_minimum_size.x, custom_minimum_size.y)
	if clase == CALAVERA:
		_dibujar_calavera(lado, entrada["color"])
	else:
		_dibujar_escudo(lado, entrada["color"], bool(entrada["contorno"]))


func _dibujar_calavera(lado: float, color: Color) -> void:
	var centro := Vector2(lado * 0.5, lado * 0.42)
	draw_circle(centro, lado * 0.38, color)
	# Mandibula: un rectangulo bajo el craneo, como la calavera del cliente 2D.
	draw_rect(Rect2(Vector2(lado * 0.28, lado * 0.62),
		Vector2(lado * 0.44, lado * 0.26)), color)
	var ojo := lado * 0.10
	draw_circle(Vector2(lado * 0.36, lado * 0.40), ojo, CONTORNO)
	draw_circle(Vector2(lado * 0.64, lado * 0.40), ojo, CONTORNO)
	draw_rect(Rect2(Vector2(lado * 0.44, lado * 0.66),
		Vector2(lado * 0.12, lado * 0.16)), CONTORNO)


func _dibujar_escudo(lado: float, color: Color, contorno_claro: bool) -> void:
	var puntos := PackedVector2Array([
		Vector2(lado * 0.12, lado * 0.10),
		Vector2(lado * 0.88, lado * 0.10),
		Vector2(lado * 0.88, lado * 0.58),
		Vector2(lado * 0.50, lado * 0.92),
		Vector2(lado * 0.12, lado * 0.58),
	])
	draw_colored_polygon(puntos, color)
	var borde := puntos.duplicate()
	borde.append(puntos[0])
	# El blanco distingue las dos invitaciones (`SHIELD_WHITEYELLOW` y
	# `SHIELD_WHITEBLUE`) del party ya formado, sin cambiar el color base.
	draw_polyline(borde,
		Color(1.0, 1.0, 1.0, 0.95) if contorno_claro else CONTORNO,
		1.5 if contorno_claro else 1.0)
