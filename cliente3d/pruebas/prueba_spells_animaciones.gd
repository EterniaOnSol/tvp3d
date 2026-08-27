extends Node

const ESTADO := preload("res://red/estado_mundo.gd")
const MENSAJE := preload("res://red/mensaje.gd")
const MUNDO := preload("res://mundo3d.gd")
const SPRITES := preload("res://red/sprites772.gd")


class EstadoSpell:
	var adentro := true


class ConexionSpell:
	var textos: Array = []

	func enviar_hablar(texto: String) -> void:
		textos.append(texto)


var _fallas := 0


func _ready() -> void:
	var sprites := SPRITES.new()
	_comprobar("indice de sprites carga", sprites.listo())
	_comprobar("outfit 128 conserva sus fases",
		sprites.tiene_outfit(128)
		and sprites.fases_de_outfit(128, 0) >= 2
		and not sprites.cuadro_outfit(128, 0, 0).is_empty())
	_comprobar("efecto 1 conserva sus fases",
		sprites.fases_de_efecto(1) >= 2
		and sprites.cuadro_efecto(1, 0).has("lamina")
		and sprites.cuadro_efecto(1, sprites.fases_de_efecto(1)).has("lamina"))
	_comprobar("proyectil 1 tiene dibujo importado",
		sprites.fases_de_proyectil(1) >= 1
		and sprites.cuadro_proyectil(1, 0).has("lamina"))
	_comprobar("catalogo de spells es legible", _catalogo_de_spells_valido())
	_comprobar("efectos 0x83-0x85 conservan el siguiente mensaje",
		_probar_eventos_y_alineacion())
	_comprobar("cambio 0x8E actualiza el outfit confirmado",
		_probar_cambio_de_outfit())
	_comprobar("lanzamiento envia las palabras exactas al servidor",
		_probar_lanzamiento())
	print("Spells y animaciones TVP3D: %d falla(s)" % _fallas)
	get_tree().quit(1 if _fallas > 0 else 0)


func _comprobar(nombre: String, correcto: bool) -> void:
	if correcto:
		print("  OK  " + nombre)
	else:
		print("  FAIL " + nombre)
		_fallas += 1


func _catalogo_de_spells_valido() -> bool:
	var archivo := FileAccess.open("res://assets/spells772.json", FileAccess.READ)
	if archivo == null:
		return false
	var datos = JSON.parse_string(archivo.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY or int(datos.get("protocol", 0)) != 772:
		return false
	var hechizos = datos.get("spells", [])
	return typeof(hechizos) == TYPE_ARRAY and not hechizos.is_empty()


func _probar_eventos_y_alineacion() -> bool:
	var estado := ESTADO.new()
	var vistos := {
		"efecto": null,
		"texto": null,
		"disparo": null,
		"mensaje": "",
	}
	estado.efecto_mapa.connect(func(posicion, tipo):
		vistos["efecto"] = [posicion, tipo])
	estado.texto_animado.connect(func(posicion, color, texto):
		vistos["texto"] = [posicion, color, texto])
	estado.disparo_distancia.connect(func(origen, destino, tipo):
		vistos["disparo"] = [origen, destino, tipo])
	estado.mensaje_servidor.connect(func(texto): vistos["mensaje"] = texto)

	var mensaje := MENSAJE.new()
	mensaje.escribir_u8(0x83)
	_escribir_posicion(mensaje, Vector3i(32097, 32219, 7))
	mensaje.escribir_u8(5)
	mensaje.escribir_u8(0x84)
	_escribir_posicion(mensaje, Vector3i(32098, 32219, 7))
	mensaje.escribir_u8(180)
	mensaje.escribir_texto("-12")
	mensaje.escribir_u8(0x85)
	_escribir_posicion(mensaje, Vector3i(32097, 32219, 7))
	_escribir_posicion(mensaje, Vector3i(32100, 32219, 7))
	mensaje.escribir_u8(3)
	# Este mensaje posterior detecta un salto de longitud en cualquiera de
	# los tres eventos visuales anteriores.
	mensaje.escribir_u8(0xA2)
	mensaje.escribir_u8(0x80)
	mensaje.escribir_u8(0xB4)
	mensaje.escribir_u8(0x01)
	mensaje.escribir_texto("aligned")
	estado.procesar(mensaje)

	return mensaje.sin_leer() == 0 \
		and vistos["efecto"] == [Vector3i(32097, 32219, 7), 5] \
		and vistos["texto"] == [Vector3i(32098, 32219, 7), 180, "-12"] \
		and vistos["disparo"] == [
			Vector3i(32097, 32219, 7), Vector3i(32100, 32219, 7), 3] \
		and vistos["mensaje"] == "aligned" \
		and estado.iconos_estado == 0x80 \
		and estado.en_combate


func _probar_lanzamiento() -> bool:
	var estado := EstadoSpell.new()
	var conexion := ConexionSpell.new()
	var mundo := MUNDO.new()
	mundo._estado = estado
	mundo._con = conexion
	var aceptado: bool = mundo.lanzar_hechizo("  exura  ")
	mundo.free()
	return aceptado and conexion.textos == ["exura"]


func _probar_cambio_de_outfit() -> bool:
	var estado := ESTADO.new()
	estado.criaturas[42] = {
		"pos": Vector3i(32097, 32219, 7),
		"nombre": "Rat",
		"apariencia": 128,
		"direccion": 2,
		"vida": 100,
	}
	var siguiente := {"texto": ""}
	estado.mensaje_servidor.connect(func(texto): siguiente["texto"] = texto)
	var mensaje := MENSAJE.new()
	mensaje.escribir_u8(0x8E)
	mensaje.escribir_u32(42)
	# AddOutfit de protocolgame.cpp: lookType + cuatro colores.
	mensaje.escribir_u16(131)
	mensaje.escribir_u8(1)
	mensaje.escribir_u8(2)
	mensaje.escribir_u8(3)
	mensaje.escribir_u8(4)
	mensaje.escribir_u8(0xB4)
	mensaje.escribir_u8(0x01)
	mensaje.escribir_texto("outfit-aligned")
	estado.procesar(mensaje)
	return mensaje.sin_leer() == 0 \
		and int(estado.criaturas[42].get("apariencia", 0)) == 131 \
		and siguiente["texto"] == "outfit-aligned"


func _escribir_posicion(mensaje, posicion: Vector3i) -> void:
	mensaje.escribir_u16(posicion.x)
	mensaje.escribir_u16(posicion.y)
	mensaje.escribir_u8(posicion.z)
