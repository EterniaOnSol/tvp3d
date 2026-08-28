extends Node

const INTERFAZ := preload("res://ui/interfaz.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const SPRITES := preload("res://red/sprites772.gd")


class DiscoBattle:
	func ids_de(_posicion: Vector3i) -> PackedInt32Array:
		return PackedInt32Array()


class ConexionBattle:
	var ataques: Array = []
	var seguimientos: Array = []

	func enviar_atacar(id: int) -> void:
		ataques.append(id)

	func enviar_seguir(id: int) -> void:
		seguimientos.append(id)


class MundoBattle:
	var _disco := DiscoBattle.new()
	var _con := ConexionBattle.new()
	var _estado
	var ataques: Array = []
	var seguimientos: Array = []

	func solicitar_logout() -> void:
		pass

	func caminar_a_casilla_desde_minimapa(_celda: Vector2i) -> void:
		pass

	func lanzar_hechizo(_palabras: String) -> bool:
		return false

	func esta_esperando_uso_con() -> bool:
		return false

	func usar_con_criatura_pendiente(_id: int) -> bool:
		return false

	func atacar_criatura(id: int) -> bool:
		ataques.append(id)
		return true


func _ready() -> void:
	var estado := ESTADO.new()
	estado.adentro = true
	estado.mi_id = 100
	estado.mi_pos = Vector3i(32097, 32219, 7)
	estado.criaturas = {
		100: {
			"pos": estado.mi_pos,
			"nombre": "GOD VALENTINO",
			"vida": 100,
		},
		101: {
			"pos": estado.mi_pos + Vector3i(1, 0, 0),
			"nombre": "Rat",
			"apariencia": 21,
			"vida": 100,
		},
	}
	for id in range(102, 110):
		estado.criaturas[id] = {
			"pos": estado.mi_pos + Vector3i(id - 100, 0, 0),
			"nombre": "Rat %d" % id,
			"vida": 100,
		}
	estado.criaturas[109]["nombre"] = ""
	estado.criaturas[109]["apariencia"] = 33
	# Estas criaturas estan en el mismo piso, pero fuera del viewport 18x14.
	for id in range(110, 114):
		estado.criaturas[id] = {
			"pos": estado.mi_pos + Vector3i(id - 100, 0, 0),
			"nombre": "Rat %d" % id,
			"vida": 100,
		}
	estado.criaturas[113]["nombre"] = ""
	estado.criaturas[113]["apariencia"] = 33
	estado.criaturas[114] = {
		"pos": Vector3i(32097, 32219, 6),
		"nombre": "Rat below floor",
		"vida": 100,
	}
	var mundo := MundoBattle.new()
	var interfaz = INTERFAZ.new(mundo, estado, SPRITES.new(), null)
	add_child(interfaz)
	await get_tree().process_frame
	interfaz._refrescar()
	await get_tree().process_frame
	var visible: bool = bool(interfaz._battle_window.visible)
	var filas: int = interfaz._battle_box.get_child_count()
	var titulo: String = str(interfaz._battle_window._titulo.text)
	print("Battle List: visible=%s filas=%d titulo=%s" % [
		visible, filas, titulo])
	print("Battle layout: ventana=%s scroll=%s contenido=%s max_scroll=%s" % [
		str(interfaz._battle_window.size), str(interfaz._battle_scroll.size),
		str(interfaz._battle_box.size),
		str(interfaz._battle_scroll.get_v_scroll_bar().max_value)])
	if not visible or filas != 9 or titulo != "Battle (9)" \
			or interfaz._battle_scroll == null:
		printerr("FALLO: Battle List no filtra por viewport")
		get_tree().quit(1)
		return
	var sprite_rat: TextureRect = interfaz._battle_sprite_slots.get(101)
	var nombre_skeleton: Label = interfaz._battle_name_labels.get(109)
	if sprite_rat == null or sprite_rat.texture == null \
			or nombre_skeleton == null or nombre_skeleton.text != "Skeleton":
		printerr("FALLO: Battle no conserva sprite o nombre de criatura")
		get_tree().quit(1)
		return
	for moneda_cid in [3031, 3035, 3043, 2148, 2152, 2160]:
		if interfaz.icono_para_item(moneda_cid) == null:
			printerr("FALLO: no hay sprite para la moneda %d" % moneda_cid)
			get_tree().quit(1)
			return
	var altura_scroll_inicial: float = interfaz._battle_scroll.size.y
	interfaz._battle_window.custom_minimum_size = Vector2(190, 300)
	interfaz._battle_window.size = Vector2(190, 300)
	await get_tree().process_frame
	await get_tree().process_frame
	var altura_scroll_ampliada: float = interfaz._battle_scroll.size.y
	print("Battle resize: scroll_y=%s -> %s" % [
		str(altura_scroll_inicial), str(altura_scroll_ampliada),
		])
	if altura_scroll_ampliada <= altura_scroll_inicial:
		printerr("FALLO: al ampliar Battle no aparecen mas criaturas directamente")
		get_tree().quit(1)
		return
	var fila = interfaz._battle_box.get_child(0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	interfaz._input_battle(click, 101)
	await get_tree().process_frame
	if mundo.ataques != [101]:
		printerr("FALLO: el click izquierdo de Battle no ataca al Rat: %s" % str(mundo.ataques))
		get_tree().quit(1)
		return
	var fila_antes = interfaz._battle_rows[101]
	estado.criaturas[101]["vida"] = 50
	interfaz._refrescar()
	await get_tree().process_frame
	if interfaz._battle_rows.get(101) != fila_antes \
			or interfaz._battle_health_bars.get(101) == null:
		printerr("FALLO: un cambio de vida reconstruye la fila y parpadea")
		get_tree().quit(1)
		return
	estado.criaturas[101]["pos"] = estado.mi_pos + Vector3i(10, 0, 0)
	interfaz._refrescar()
	await get_tree().process_frame
	if interfaz._battle_rows.has(101) or interfaz._battle_ids.has(101) \
			or str(interfaz._battle_window._titulo.text) != "Battle (8)":
		printerr("FALLO: Battle conserva una criatura que salio de la vista")
		get_tree().quit(1)
		return
	print("OK: Battle List muestra Rat y el click izquierdo ataca")
	get_tree().quit(0)
