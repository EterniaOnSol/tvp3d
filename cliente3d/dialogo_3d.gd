extends Label3D

## Burbuja de habla sobre una criatura. La conversacion completa sigue
## quedando en el chat; aqui solo mostramos el eco contextual del mapa.

const DURACION_POR_DEFECTO := 3.2
const ALTURA_SUBIDA := 0.28

var _desde := Vector3.ZERO
var _duracion := DURACION_POR_DEFECTO
var _tiempo := 0.0


static func crear(quien: String, texto: String, donde: Vector3, color: Color,
		padre: Node, duracion: float = DURACION_POR_DEFECTO) -> Label3D:
	var dialogo := new()
	var limpio := texto.strip_edges()
	if limpio.length() > 120:
		limpio = limpio.left(117) + "..."
	dialogo.text = "%s: %s" % [quien, limpio]
	dialogo.position = donde
	dialogo._desde = donde
	dialogo._duracion = maxf(1.0, duracion)
	dialogo.font_size = 64
	dialogo.pixel_size = 0.0042
	dialogo.modulate = color
	dialogo.outline_size = 10
	dialogo.outline_modulate = Color(0.02, 0.02, 0.02, 0.96)
	dialogo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dialogo.no_depth_test = true
	dialogo.render_priority = 2
	padre.add_child(dialogo)
	return dialogo


func _process(delta: float) -> void:
	_tiempo += delta
	var progreso := clampf(_tiempo / _duracion, 0.0, 1.0)
	position = _desde + Vector3.UP * (ALTURA_SUBIDA * progreso)
	modulate.a = 1.0 if progreso < 0.76 else 1.0 - ((progreso - 0.76) / 0.24)
	if _tiempo >= _duracion:
		queue_free()
