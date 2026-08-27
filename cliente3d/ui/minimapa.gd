extends Control

## Minimap pixel-art basado en la misma regla de Tibia/3DTIBIA:
## un pixel por SQM, color del item visible mas alto y el jugador al centro.
## El mundo del cliente ya mantiene `_mapa_visible` desde mapa_disco.gd, por
## lo que no se vuelve a leer el archivo en cada repintado.

signal pidio_caminar(celda: Vector2i)

const ZOOMS := [1, 2, 3, 4, 6, 8]
const FONDO := Color(0.035, 0.040, 0.050, 1.0)
const SIN_EXPLORAR := Color(0.055, 0.060, 0.075, 1.0)
const COLOR_JUGADOR := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_CRIATURA := Color(1.0, 0.05, 0.85, 1.0)

var mundo
var estado
var catalogo
var radio := 9
var zoom := 2
var _centro := Vector2i.ZERO
var _piso := 7
var _rect_mapa := Rect2()


func _init(p_mundo, p_estado, p_catalogo) -> void:
	mundo = p_mundo
	estado = p_estado
	catalogo = p_catalogo
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(174, 174)
	tooltip_text = "Left click: walk here | Wheel: zoom"


func _ready() -> void:
	_centro = Vector2i(estado.mi_pos.x, estado.mi_pos.y)
	_piso = estado.mi_pos.z
	queue_redraw()


func refrescar() -> void:
	if estado != null:
		_centro = Vector2i(estado.mi_pos.x, estado.mi_pos.y)
		_piso = estado.mi_pos.z
	queue_redraw()


func _recalcular_rect_mapa() -> float:
	# El panel puede cambiar de tamano al terminar de cargar el HUD o al
	# arrastrar una ventana. El click debe usar exactamente el mismo rectangulo
	# que el dibujo de ese frame, no una medida vieja.
	var lado := minf(size.x - 6.0, size.y - 6.0)
	_rect_mapa = Rect2(Vector2((size.x - lado) * 0.5,
		(size.y - lado) * 0.5), Vector2(lado, lado))
	return lado


func acercar(mas: bool) -> bool:
	var antes := zoom
	var indice := ZOOMS.find(zoom)
	if indice < 0:
		indice = 1
	zoom = ZOOMS[clampi(indice + (1 if mas else -1), 0, ZOOMS.size() - 1)]
	if zoom != antes:
		queue_redraw()
		return true
	return false


func _draw() -> void:
	var marco := Rect2(Vector2.ZERO, size)
	draw_rect(marco, Color(0.025, 0.030, 0.040, 1.0), true)
	var lado := _recalcular_rect_mapa()
	draw_rect(_rect_mapa, FONDO, true)

	var casillas_por_lado := maxi(8, int(floor(lado / float(zoom))))
	var mitad := int(casillas_por_lado / 2)
	var paso := lado / float(casillas_por_lado)
	for fila in range(casillas_por_lado):
		for columna in range(casillas_por_lado):
			var posicion := Vector3i(
				_centro.x + columna - mitad,
				_centro.y + fila - mitad,
				_piso)
			var color := _color_de_casilla(posicion)
			var r := Rect2(_rect_mapa.position + Vector2(columna, fila) * paso,
				Vector2(paso + 0.5, paso + 0.5))
			draw_rect(r, color, true)

	# Los seres vivos se dibujan despues del terreno.
	if estado != null:
		for id in estado.criaturas:
			var criatura: Dictionary = estado.criaturas[id]
			var pos: Vector3i = criatura.get("pos", Vector3i.ZERO)
			if pos.z != _piso:
				continue
			var dx := pos.x - _centro.x + mitad
			var dy := pos.y - _centro.y + mitad
			if dx < 0 or dy < 0 or dx >= casillas_por_lado or dy >= casillas_por_lado:
				continue
			draw_rect(Rect2(_rect_mapa.position + Vector2(dx, dy) * paso,
				Vector2(paso, paso)), COLOR_CRIATURA, true)

	var punto_jugador := _rect_mapa.position + Vector2(mitad, mitad) * paso
	draw_rect(Rect2(punto_jugador, Vector2(paso, paso)), COLOR_JUGADOR, true)
	draw_line(punto_jugador + Vector2(paso * 0.5, 1),
		punto_jugador + Vector2(paso * 0.5, paso - 1), Color.BLACK, 1)
	draw_rect(_rect_mapa, Color(0.40, 0.44, 0.52, 1.0), false, 1.0)


func _color_de_casilla(posicion: Vector3i) -> Color:
	var ids: PackedInt32Array = _ids_de_casilla(posicion)
	# Tile::getMinimapColorByte recorre desde arriba: el primer item con
	# color gana; los items sin color no tapan el suelo.
	for indice in range(ids.size() - 1, -1, -1):
		var info: Dictionary = catalogo.info_item(int(ids[indice]))
		var color_indice := int(info.get("color_mapa", 0))
		if color_indice > 0:
			return _color_desde_indice(color_indice)
	return SIN_EXPLORAR


func _ids_de_casilla(posicion: Vector3i) -> PackedInt32Array:
	if estado != null and estado.casillas.has(posicion):
		var vivo := PackedInt32Array()
		for cosa in estado.casillas[posicion]:
			if cosa.get("tipo") == "item":
				vivo.append(int(cosa.get("cid", 0)))
		return vivo
	if mundo != null and mundo._disco != null:
		return mundo._disco.ids_de(posicion)
	return PackedInt32Array()


static func _color_desde_indice(indice: int) -> Color:
	if indice <= 0 or indice >= 216:
		return SIN_EXPLORAR
	return Color8(
		(indice / 36) % 6 * 51,
		(indice / 6) % 6 * 51,
		indice % 6 * 51)


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed:
		if evento.button_index == MOUSE_BUTTON_WHEEL_UP:
			acercar(true)
			accept_event()
			return
		if evento.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			acercar(false)
			accept_event()
			return
		if evento.button_index == MOUSE_BUTTON_LEFT:
			var celda := _casilla_en(evento.position)
			if celda != Vector2i(999999, 999999):
				pidio_caminar.emit(celda)
			accept_event()


func _casilla_en(punto: Vector2) -> Vector2i:
	var lado := _recalcular_rect_mapa()
	if lado <= 0.0 or not _rect_mapa.has_point(punto):
		return Vector2i(999999, 999999)
	var casillas_por_lado := maxi(8, int(floor(lado / float(zoom))))
	var paso := lado / float(casillas_por_lado)
	var columna := clampi(int(floor((punto.x - _rect_mapa.position.x) / paso)),
		0, casillas_por_lado - 1)
	var fila := clampi(int(floor((punto.y - _rect_mapa.position.y) / paso)),
		0, casillas_por_lado - 1)
	var mitad := int(casillas_por_lado / 2)
	return Vector2i(_centro.x + columna - mitad,
		_centro.y + fila - mitad)
