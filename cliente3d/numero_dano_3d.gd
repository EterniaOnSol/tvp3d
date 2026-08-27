extends Label3D

## Numero de combate estilo Tibia: sube, hace un pequeno pop y desaparece.

const DURACION_POR_DEFECTO := 1.0
const ALTURA_SUBIDA := 1.15

var _desde := Vector3.ZERO
var _duracion := DURACION_POR_DEFECTO
var _tiempo := 0.0
var _escala_base := Vector3.ONE


static func crear(texto: String, donde: Vector3, color: Color, padre: Node,
		duracion: float = DURACION_POR_DEFECTO) -> Label3D:
	var numero := new()
	numero.text = texto
	numero.position = donde
	numero._desde = donde
	numero._duracion = maxf(0.25, duracion)
	numero.font_size = 100
	numero.pixel_size = 0.005
	numero.modulate = color
	numero.outline_size = 14
	numero.outline_modulate = Color(0.02, 0.02, 0.02, 0.96)
	numero.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	numero.no_depth_test = true
	numero.render_priority = 3
	numero._escala_base = numero.scale
	padre.add_child(numero)
	return numero


func _process(delta: float) -> void:
	_tiempo += delta
	var progreso := clampf(_tiempo / _duracion, 0.0, 1.0)
	position = _desde + Vector3.UP * (ALTURA_SUBIDA * progreso)
	var pop := 1.0
	if progreso < 0.18:
		pop = lerpf(0.82, 1.18, progreso / 0.18)
	elif progreso < 0.35:
		pop = lerpf(1.18, 1.0, (progreso - 0.18) / 0.17)
	scale = _escala_base * pop
	modulate.a = 1.0 if progreso < 0.58 else 1.0 - ((progreso - 0.58) / 0.42)
	if _tiempo >= _duracion:
		queue_free()
