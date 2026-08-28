extends Node

const MUNDO := preload("res://mundo3d.gd")
const MINIMAPA := preload("res://ui/minimapa.gd")
const CONEXION := preload("res://red/conexion772.gd")
const INTERFAZ := preload("res://ui/interfaz.gd")
const ESTADO_MUNDO := preload("res://red/estado_mundo.gd")
const MENSAJE := preload("res://red/mensaje.gd")
const MAPA772 := preload("res://red/mapa772.gd")

class EstadoRuta:
	var casillas: Dictionary = {}
	var criaturas: Dictionary = {}
	var mi_pos := Vector3i.ZERO
	var mi_id := 1
	var adentro := true


class InterfazEscribiendo:
	func esta_escribiendo() -> bool:
		return true


class CatalogoRuta:
	func info_item(_cid: int) -> Dictionary:
		if _cid == 1958:
			return {
				"nombre": "wooden stairs",
				"bloquea": false,
				"block_pathfind": false,
				"frena_vista": false,
			}
		if _cid == 99:
			return {"bloquea": true, "block_pathfind": false, "frena_vista": false}
		return {"bloquea": false}


class DiscoRuta:
	var casillas: Dictionary = {}
	var ir_tiles: Dictionary = {}

	func ids_de(posicion: Vector3i) -> PackedInt32Array:
		return casillas.get(posicion, PackedInt32Array())

	func tile_en(posicion: Vector3i) -> Dictionary:
		return ir_tiles.get(posicion, {})


class ConexionAtaque:
	var ataques: Array = []
	var caminos: Array = []
	var movimientos: Array = []
	var detenciones := 0
	var usos_criatura: Array = []
	var usos_item: Array = []

	func enviar_atacar(id: int) -> void:
		ataques.append(id)

	func enviar_auto_camino(camino: Array) -> void:
		caminos.append(camino)

	func enviar_detener_auto_camino() -> void:
		detenciones += 1

	func enviar_usar_con_criatura(origen: Vector3i, client_id: int,
			stackpos: int, id_criatura: int) -> void:
		usos_criatura.append({
			"origen": origen,
			"client_id": client_id,
			"stackpos": stackpos,
			"id": id_criatura,
		})

	func enviar_usar_item_ex(origen: Vector3i, client_id: int, stackpos: int,
			destino: Vector3i, destino_client_id: int,
			destino_stackpos: int) -> void:
		usos_item.append({
			"origen": origen,
			"client_id": client_id,
			"stackpos": stackpos,
			"destino": destino,
			"destino_client_id": destino_client_id,
			"destino_stackpos": destino_stackpos,
		})

	func enviar_mover_cosa(origen: Vector3i, client_id: int, stackpos: int,
			destino: Vector3i, cantidad: int) -> void:
		movimientos.append({
			"origen": origen,
			"client_id": client_id,
			"stackpos": stackpos,
			"destino": destino,
			"cantidad": cantidad,
		})

	func enviar_mover_ubicacion(origen: Vector3i, client_id: int, stackpos: int,
			destino: Vector3i, cantidad: int) -> void:
		enviar_mover_cosa(origen, client_id, stackpos, destino, cantidad)


class MundoClickDerecho extends MUNDO:
	var ataques_derecho: Array = []

	func _criatura_bajo_mouse(_posicion: Vector2) -> int:
		return 42

	func atacar_criatura(id: int) -> bool:
		ataques_derecho.append(id)
		return true


var _fallas := 0


func _ready() -> void:
	var mundo = MUNDO.new()
	_comprobar("8 entradas de teclado", MUNDO.TECLAS_DIRECCION.size() == 8)
	_comprobar("W sin giro es norte",
		MUNDO._direccion_girada(Vector2i(0, -1), 0.0) == Vector2i(0, -1))
	_comprobar("D sin giro es este",
		MUNDO._direccion_girada(Vector2i(1, 0), 0.0) == Vector2i(1, 0))
	_comprobar("W a 45 grados cae en octante noroeste",
		MUNDO._direccion_girada(Vector2i(0, -1), 45.0) == Vector2i(-1, -1))
	_comprobar("diagonal noroeste usa opcode 0x6D",
		mundo._opcode_de_direccion(Vector2i(-1, -1)) == 0x6D)
	_comprobar("diagonal sureste usa opcode 0x6B",
		mundo._opcode_de_direccion(Vector2i(1, 1)) == 0x6B)
	_comprobar("dia alcanza maxima luz al mediodia",
		is_equal_approx(MUNDO._factor_luz_dia(12.0), 1.0))
	_comprobar("noche queda con luz minima",
		MUNDO._factor_luz_dia(0.0) == 0.0 and MUNDO._factor_luz_dia(23.0) == 0.0)
	_comprobar("luz del servidor marca noche y dia",
		MUNDO._factor_luz_servidor(51) == 0.0
		and is_equal_approx(MUNDO._factor_luz_servidor(255), 1.0))
	_comprobar("map click calcula ruta sin diagonales", _probar_ruta_cardinal(mundo))
	_comprobar("map click permite llegar a escalera", _probar_acceso_de_piso(mundo))
	_comprobar("map click descarta casilla no caminable", _probar_bloqueo_ir(mundo))
	_comprobar("map click descarta solido aunque queryadd permita", _probar_bloqueo_solido_ir(mundo))
	_comprobar("map click descarta solido vivo", _probar_bloqueo_solido_vivo(mundo))
	_comprobar("map click consulta el mapa estatico", _probar_respaldo_disco(mundo))
	_comprobar("minimap centra el click en el jugador", _probar_click_minimapa())
	_comprobar("autowalk conserva el orden de una ruta", _probar_orden_autowalk(mundo))
	_comprobar("container usa posicion marcada 0x40", _probar_posicion_container())
	_comprobar("sprites de criaturas tienen orden estable", _probar_orden_criaturas(mundo))
	_comprobar("ataque directo envia el ID de la criatura", _probar_ataque_directo(mundo))
	_comprobar("ataque lejano se acerca por ruta caminable", _probar_ataque_a_distancia(mundo))
	_comprobar("clic derecho quieto ataca criatura", _probar_click_derecho_criatura())
	_comprobar("arrastre reconoce criatura y usa client id 99", _probar_arrastre_criatura(mundo))
	_comprobar("recoger item del suelo usa slot de inventario", _probar_recoger_item(mundo))
	_comprobar("moneda conserva cantidad de pila", _probar_items_protocolo())
	_comprobar("iconos de combate no desalinean el siguiente mensaje", _probar_iconos())
	_comprobar("movimiento de criatura conserva su stackpos", _probar_pila_criatura())
	_comprobar("runa detiene auto-walk y bloquea teclas", _probar_chat_detiene_movimiento(mundo))
	_comprobar("runa usa posicion de contenedor con criatura", _probar_uso_con_runa(mundo))
	_comprobar("puerta simple acepta closed/open door",
		MUNDO.es_puerta_simple(1629, {"nombre": "closed door"})
		and MUNDO.es_puerta_simple(1630, {"nombre": "open door"}))
	_comprobar("puerta con parametros queda fuera del picking",
		not MUNDO.es_puerta_simple(1628, {"nombre": "closed door"})
		and not MUNDO.es_puerta_simple(1646, {"nombre": "gate of expertise"}))
	print("Controles TVP3D: %d falla(s)" % _fallas)
	mundo.free()
	get_tree().quit(1 if _fallas > 0 else 0)


func _comprobar(nombre: String, correcto: bool) -> void:
	if correcto:
		print("  OK  " + nombre)
	else:
		print("  FAIL " + nombre)
		_fallas += 1


func _probar_ruta_cardinal(mundo) -> bool:
	var estado := EstadoRuta.new()
	mundo._estado = estado
	mundo._catalogo = CatalogoRuta.new()
	mundo._mapa_visible.clear()
	mundo._bloqueo_disco_cache.clear()
	for x in range(0, 4):
		for y in range(0, 3):
			mundo._mapa_visible[Vector3i(x, y, 7)] = PackedInt32Array([1])
	var ruta: Array = mundo._buscar_ruta(
		Vector3i(0, 0, 7), Vector3i(3, 2, 7), false)
	if ruta.size() != 5:
		return false
	for paso in ruta:
		if absi(paso.x) + absi(paso.y) != 1:
			return false
	return true


func _probar_acceso_de_piso(mundo) -> bool:
	var estado := EstadoRuta.new()
	mundo._estado = estado
	mundo._catalogo = CatalogoRuta.new()
	mundo._mapa_visible.clear()
	mundo._bloqueo_disco_cache.clear()
	for x in range(0, 4):
		mundo._mapa_visible[Vector3i(x, 0, 7)] = PackedInt32Array([1])
	mundo._mapa_visible[Vector3i(1, 0, 7)] = PackedInt32Array([1958])
	var ir := DiscoRuta.new()
	ir.ir_tiles[Vector3i(1, 0, 7)] = {
		"items": [{"category": "STAIRS"}],
		"walkable": true,
		"queryadd_walkable": false,
	}
	mundo._ir_trozos = ir
	var acceso := Vector3i(1, 0, 7)
	var ruta: Array = mundo._buscar_ruta(Vector3i(0, 0, 7),
		Vector3i(3, 0, 7), false)
	return not ruta.is_empty() and mundo._casilla_tiene_paso_automatico(acceso)


func _probar_bloqueo_ir(mundo) -> bool:
	var estado := EstadoRuta.new()
	mundo._estado = estado
	mundo._catalogo = CatalogoRuta.new()
	mundo._mapa_visible.clear()
	mundo._bloqueo_disco_cache.clear()
	var ir := DiscoRuta.new()
	var bloqueada := Vector3i(1, 0, 7)
	ir.ir_tiles[bloqueada] = {
		"items": [],
		"queryadd_walkable": false,
	}
	mundo._ir_trozos = ir
	mundo._mapa_visible[Vector3i(0, 0, 7)] = PackedInt32Array([1])
	mundo._mapa_visible[bloqueada] = PackedInt32Array([1])
	return mundo._casilla_bloqueada(bloqueada)


func _probar_bloqueo_solido_ir(mundo) -> bool:
	var estado := EstadoRuta.new()
	mundo._estado = estado
	mundo._catalogo = CatalogoRuta.new()
	mundo._mapa_visible.clear()
	mundo._bloqueo_disco_cache.clear()
	var ir := DiscoRuta.new()
	var bloqueada := Vector3i(2, 0, 7)
	ir.ir_tiles[bloqueada] = {
		"items": [],
		"walkable": false,
		"queryadd_walkable": true,
	}
	mundo._ir_trozos = ir
	mundo._mapa_visible[bloqueada] = PackedInt32Array([1])
	return mundo._casilla_bloqueada(bloqueada)


func _probar_bloqueo_solido_vivo(mundo) -> bool:
	var estado := EstadoRuta.new()
	estado.casillas[Vector3i(3, 0, 7)] = [{"tipo": "item", "cid": 99}]
	mundo._estado = estado
	mundo._catalogo = CatalogoRuta.new()
	mundo._mapa_visible.clear()
	mundo._bloqueo_disco_cache.clear()
	mundo._ir_trozos = null
	return mundo._casilla_bloqueada(Vector3i(3, 0, 7))


func _probar_respaldo_disco(mundo) -> bool:
	var estado := EstadoRuta.new()
	mundo._estado = estado
	mundo._catalogo = CatalogoRuta.new()
	mundo._mapa_visible.clear()
	mundo._bloqueo_disco_cache.clear()
	mundo._ir_trozos = null
	var disco := DiscoRuta.new()
	disco.casillas[Vector3i(4, 0, 7)] = PackedInt32Array([1])
	mundo._disco = disco
	return not mundo._casilla_bloqueada(Vector3i(4, 0, 7))


func _probar_click_minimapa() -> bool:
	var estado := EstadoRuta.new()
	estado.mi_pos = Vector3i(10, 20, 7)
	var minimapa := MINIMAPA.new(null, estado, CatalogoRuta.new())
	minimapa.size = Vector2(200, 200)
	minimapa._centro = Vector2i(10, 20)
	minimapa._piso = 7
	var lado: float = minimapa._recalcular_rect_mapa()
	var casillas_por_lado := maxi(8, int(floor(lado / float(minimapa.zoom))))
	var mitad := int(casillas_por_lado / 2)
	var paso := lado / float(casillas_por_lado)
	var centro_pixel := minimapa._rect_mapa.position + Vector2(
		(mitad + 0.5) * paso, (mitad + 0.5) * paso)
	var derecha_pixel := minimapa._rect_mapa.position + Vector2(
		(mitad + 1.5) * paso, (mitad + 0.5) * paso)
	var centro_ok := minimapa._casilla_en(centro_pixel) == Vector2i(10, 20)
	var derecha_ok := minimapa._casilla_en(derecha_pixel) == Vector2i(11, 20)
	minimapa.free()
	return centro_ok and derecha_ok


func _probar_orden_autowalk(_mundo) -> bool:
	# El servidor 7.72 lee el buffer desde el final y luego lo invierte.
	# Una ruta este-sur debe llegarle como [este, sur], no [sur, este].
	var conexion := CONEXION.new()
	var pasos := [Vector2i(1, 0), Vector2i(0, 1)]
	var paquete := conexion._paquete_auto_camino(pasos)
	conexion.free()
	return paquete == PackedByteArray([0x64, 2, 1, 7])


func _probar_posicion_container() -> bool:
	var interfaz = INTERFAZ.new(null, null, null, null)
	var posicion: Vector3i = interfaz._posicion_de_item("contenedor", 3, 2)
	interfaz.free()
	return posicion == Vector3i(0xFFFF, 0x43, 2)


func _probar_orden_criaturas(mundo) -> bool:
	var estado := EstadoRuta.new()
	estado.criaturas = {
		30: {"pos": Vector3i(4, 2, 7)},
		10: {"pos": Vector3i(2, 1, 7)},
		20: {"pos": Vector3i(2, 1, 7)},
		40: {"pos": Vector3i(1, 1, 6)},
	}
	mundo._estado = estado
	return mundo._ids_criaturas_ordenados() == [40, 10, 20, 30]


func _probar_ataque_directo(mundo) -> bool:
	var estado := EstadoRuta.new()
	estado.mi_pos = Vector3i(0, 0, 7)
	estado.criaturas = {42: {"pos": Vector3i(1, 0, 7), "nombre": "Rat"}}
	var conexion := ConexionAtaque.new()
	mundo._estado = estado
	mundo._con = conexion
	mundo._solo_mirar = false
	mundo._ataque_pendiente_id = 0
	var aceptado: bool = mundo.atacar_criatura(42)
	return aceptado and conexion.ataques == [42] and conexion.caminos.is_empty()


func _probar_ataque_a_distancia(mundo) -> bool:
	var estado := EstadoRuta.new()
	estado.mi_pos = Vector3i(0, 0, 7)
	estado.criaturas = {42: {"pos": Vector3i(10, 0, 7), "nombre": "Rat"}}
	var conexion := ConexionAtaque.new()
	mundo._estado = estado
	mundo._con = conexion
	mundo._solo_mirar = false
	mundo._ataque_pendiente_id = 0
	mundo._mapa_visible.clear()
	mundo._bloqueo_disco_cache.clear()
	mundo._ir_trozos = null
	mundo._disco = null
	for x in range(-1, 12):
		for y in range(-1, 2):
			mundo._mapa_visible[Vector3i(x, y, 7)] = PackedInt32Array([1])
	var aceptado: bool = mundo.atacar_criatura(42)
	if not aceptado or conexion.caminos.size() != 1 or conexion.caminos[0].is_empty():
		return false
	# Simula la confirmacion del paso final dentro del rango del servidor.
	estado.mi_pos = Vector3i(2, 0, 7)
	mundo._intentar_ataque_pendiente()
	return conexion.ataques == [42]


func _probar_click_derecho_criatura() -> bool:
	var mundo := MundoClickDerecho.new()
	mundo._estado = EstadoRuta.new()
	var presionar := InputEventMouseButton.new()
	presionar.button_index = MOUSE_BUTTON_RIGHT
	presionar.pressed = true
	mundo._unhandled_input(presionar)
	var soltar := InputEventMouseButton.new()
	soltar.button_index = MOUSE_BUTTON_RIGHT
	soltar.pressed = false
	mundo._unhandled_input(soltar)
	var correcto := mundo.ataques_derecho == [42] \
			and mundo._criatura_clic_derecho == 0
	mundo.free()
	return correcto


func _probar_arrastre_criatura(mundo) -> bool:
	var estado := EstadoRuta.new()
	var origen := Vector3i(5, 5, 7)
	var destino := Vector3i(6, 5, 7)
	estado.mi_id = 1
	estado.mi_pos = origen
	estado.casillas[origen] = [
		{"tipo": "item", "cid": 1, "suelo": true},
		{"tipo": "criatura", "id": 42},
		{"tipo": "item", "cid": 2, "movible": true},
	]
	estado.criaturas = {42: {"pos": origen, "nombre": "Rat"}}
	var conexion := ConexionAtaque.new()
	mundo._estado = estado
	mundo._con = conexion
	var encontrado: Dictionary = mundo._objeto_movible_en_casilla(origen)
	if encontrado.is_empty() or encontrado["cosa"].get("tipo") != "criatura":
		return false
	if int(encontrado["stackpos"]) != 1:
		return false
	var enviado: Dictionary = mundo._enviar_arrastre(origen, encontrado, destino)
	return not enviado.is_empty() \
		and enviado["client_id"] == 99 \
		and enviado["stackpos"] == 1 \
		and enviado["cantidad"] == 1 \
		and conexion.movimientos.size() == 1 \
		and conexion.movimientos[0]["destino"] == destino


func _probar_recoger_item(mundo) -> bool:
	var estado := EstadoRuta.new()
	estado.adentro = true
	estado.mi_pos = Vector3i(10, 10, 7)
	var conexion := ConexionAtaque.new()
	mundo._estado = estado
	mundo._con = conexion
	var datos := {
		"cosa": {"tipo": "item", "cid": 3031, "cantidad": 2,
			"nombre": "gold coin"},
		"stackpos": 2,
	}
	var correcto: bool = mundo.recoger_objeto_en_ranura(estado.mi_pos, datos, 2,
		"inventario", -1, 3)
	if not correcto or conexion.movimientos.size() != 1:
		return false
	var movimiento: Dictionary = conexion.movimientos[0]
	return movimiento["origen"] == estado.mi_pos \
		and movimiento["client_id"] == 3031 \
		and movimiento["stackpos"] == 2 \
		and movimiento["destino"] == Vector3i(0xFFFF, 3, 0) \
		and movimiento["cantidad"] == 2


func _probar_items_protocolo() -> bool:
	var mapa := MAPA772.new()
	var msg_moneda := MENSAJE.new(PackedByteArray([0xD7, 0x0B, 37]))
	var moneda: Dictionary = mapa.leer_cosa(msg_moneda, Vector3i.ZERO, [])
	var moneda_ok: bool = int(moneda.get("cid", 0)) == 3031 \
		and int(moneda.get("cantidad", 0)) == 37 \
		and msg_moneda.sin_leer() == 0
	var msg_mana := MENSAJE.new(PackedByteArray([0x3A, 0x0B, 7]))
	var mana: Dictionary = mapa.leer_cosa(msg_mana, Vector3i.ZERO, [])
	var mana_ok: bool = int(mana.get("cid", 0)) == 2874 \
		and bool(mana.get("liquido", false)) \
		and int(mana.get("color_liquido", 0)) == 7 \
		and mana.get("nombre", "") == "mana fluid" \
		and msg_mana.sin_leer() == 0
	mapa = null
	return moneda_ok and mana_ok


func _probar_chat_detiene_movimiento(mundo) -> bool:
	var estado := EstadoRuta.new()
	var conexion := ConexionAtaque.new()
	mundo._estado = estado
	mundo._con = conexion
	mundo._interfaz = InterfazEscribiendo.new()
	mundo._ataque_pendiente_id = 42
	mundo._direccion_diferida = Vector2i(1, 0)
	mundo._objetivo_diferido = Vector3i(4, 4, 7)
	mundo.detener_movimiento_para_uso()
	mundo._desde_ultimo_paso = 1.0
	mundo._leer_teclas()
	return conexion.detenciones == 1 \
		and mundo._ataque_pendiente_id == 0 \
		and mundo._direccion_diferida == Vector2i.ZERO \
		and mundo._objetivo_diferido == Vector3i(-9999, -9999, -9999)


func _probar_uso_con_runa(mundo) -> bool:
	var estado := EstadoRuta.new()
	estado.criaturas = {42: {"nombre": "Rat", "pos": Vector3i(11, 20, 7)}}
	var conexion := ConexionAtaque.new()
	mundo._estado = estado
	mundo._con = conexion
	var runa := {"cid": 3148, "nombre": "spell rune"}
	if not mundo.preparar_uso_con("contenedor", 3, 2, runa):
		return false
	if not mundo.usar_con_criatura_pendiente(42) or conexion.usos_criatura.size() != 1:
		return false
	var uso: Dictionary = conexion.usos_criatura[0]
	return uso["origen"] == Vector3i(0xFFFF, 0x43, 2) \
		and uso["client_id"] == 3148 \
		and uso["stackpos"] == 0 \
		and uso["id"] == 42


func _probar_iconos() -> bool:
	var estado := ESTADO_MUNDO.new()
	var msg := MENSAJE.new(PackedByteArray([
		0xA2, 0x80,
		0x84, 1, 0, 2, 0, 7, 1, 3, 0, 65, 66, 67]))
	estado.procesar(msg)
	return estado.en_combate and msg.sin_leer() == 0


func _probar_pila_criatura() -> bool:
	var estado = ESTADO_MUNDO.new()
	var pila_nueva := [
		{"tipo": "item", "cid": 1, "suelo": true},
		{"tipo": "item", "cid": 2, "movible": true},
	]
	estado._insertar_cosa_nueva(pila_nueva, {"tipo": "criatura", "id": 43})
	if pila_nueva[1].get("tipo") != "criatura":
		return false
	var vieja := Vector3i(5, 5, 7)
	var nueva := Vector3i(6, 5, 7)
	estado.criaturas = {42: {"pos": vieja, "direccion": 2}}
	estado.casillas[vieja] = [
		{"tipo": "item", "cid": 1, "suelo": true},
		{"tipo": "criatura", "id": 42},
	]
	estado.casillas[nueva] = [
		{"tipo": "item", "cid": 1, "suelo": true},
		{"tipo": "item", "cid": 2, "movible": true},
	]
	estado._mover_criatura_por_id(42, nueva)
	var pila: Array = estado.casillas[nueva]
	var pila_vieja: Array = estado.casillas[vieja]
	return pila_vieja.size() == 1 \
		and pila_vieja[0].get("tipo") == "item" \
		and pila.size() == 3 \
		and pila[1].get("tipo") == "criatura" \
		and int(pila[1].get("id", 0)) == 42 \
		and pila[2].get("tipo") == "item"
