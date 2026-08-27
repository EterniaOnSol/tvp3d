extends Node

const INTERFAZ := preload("res://ui/interfaz.gd")
const ESTADO := preload("res://red/estado_mundo.gd")


class DiscoBattle:
	func ids_de(_posicion: Vector3i) -> PackedInt32Array:
		return PackedInt32Array()


class MundoBattle:
	var _disco := DiscoBattle.new()
	var _con = null
	var _estado

	func solicitar_logout() -> void:
		pass

	func caminar_a_casilla_desde_minimapa(_celda: Vector2i) -> void:
		pass

	func lanzar_hechizo(_palabras: String) -> bool:
		return false

	func atacar_criatura(_id: int) -> bool:
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
			"vida": 100,
		},
	}
	var mundo := MundoBattle.new()
	var interfaz = INTERFAZ.new(mundo, estado, null, null)
	add_child(interfaz)
	await get_tree().process_frame
	interfaz._refrescar()
	await get_tree().process_frame
	var visible: bool = bool(interfaz._battle_window.visible)
	var filas: int = interfaz._battle_box.get_child_count()
	var titulo: String = str(interfaz._battle_window._titulo.text)
	print("Battle List: visible=%s filas=%d titulo=%s" % [
		visible, filas, titulo])
	if not visible or filas != 1 or titulo != "Battle (1)":
		printerr("FALLO: Battle List no muestra el monster")
		get_tree().quit(1)
		return
	print("OK: Battle List muestra Rat")
	get_tree().quit(0)
