extends Node

## Comprueba el panel de combate (fight mode, chase, marcados) que agrega el
## boton "Combat" a la barra de Actions.
##
## Este servidor no contesta nada para el `0xA0` (a diferencia de party o
## trade), asi que el panel no espera confirmacion: solo refleja su propio
## ultimo envio. La prueba verifica que ese envio use exactamente el formato
## de `ProtocolGame::parseFightModes` (1/2/3 ofensivo-equilibrado-defensivo,
## 0/1 standing/chase, 0/1 solo-marcados/cualquiera) y que el estado inicial
## coincida con los valores por defecto de `Player` (`fightMode=ATTACK`,
## `chaseMode=false`, `secureMode=false`).

const INTERFAZ := preload("res://ui/interfaz.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const SPRITES := preload("res://red/sprites772.gd")

const YO := 0x10000001

var _fallas := 0


class ConexionCombate:
	var ordenes: Array = []

	func enviar_modos_combate(ofensivo: int, perseguir: int, marcados: int) -> void:
		ordenes.append([ofensivo, perseguir, marcados])


class DiscoCombate:
	func ids_de(_posicion: Vector3i) -> PackedInt32Array:
		return PackedInt32Array()


class MundoCombate:
	var _disco := DiscoCombate.new()
	var _con := ConexionCombate.new()

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

	func atacar_criatura(_id: int) -> bool:
		return true


func _comprobar(condicion: bool, texto: String) -> void:
	if condicion:
		print("  OK   %s" % texto)
	else:
		_fallas += 1
		printerr("  FALLO %s" % texto)


func _ready() -> void:
	var estado := ESTADO.new()
	estado.adentro = true
	estado.mi_id = YO
	estado.mi_pos = Vector3i(32097, 32219, 7)
	estado.criaturas = {YO: {"pos": estado.mi_pos, "nombre": "Guuille",
		"vida": 100}}
	var mundo := MundoCombate.new()
	var interfaz = INTERFAZ.new(mundo, estado, SPRITES.new(), null)
	add_child(interfaz)
	await get_tree().process_frame

	var con: ConexionCombate = mundo._con

	print("Estado inicial igual al default de Player en bed.cpp/player.h:")
	_comprobar(interfaz._modo_ataque == 1,
		"fight mode arranca en 1 (FIGHTMODE_ATTACK, default del servidor)")
	_comprobar(interfaz._modo_perseguir == false,
		"chase arranca apagado (chaseMode=false en Player)")
	_comprobar(interfaz._modo_marcados == false,
		"marcados arranca en solo-marcados (secureMode=false en Player)")
	_comprobar(interfaz._combate_botones_modo[1].button_pressed
			and not interfaz._combate_botones_modo[2].button_pressed
			and not interfaz._combate_botones_modo[3].button_pressed,
		"el boton de Full Attack es el unico presionado al armar el panel")

	print("Elegir un modo de ataque manda exactamente [modo, chase, marcados]:")
	con.ordenes.clear()
	interfaz._combate_botones_modo[3].pressed.emit()
	_comprobar(con.ordenes == [[3, 0, 0]],
		"Full Defense manda ofensivo=3 sin tocar chase ni marcados")
	_comprobar(interfaz._combate_botones_modo[3].button_pressed
			and not interfaz._combate_botones_modo[1].button_pressed,
		"el grupo de botones deja presionado solo el nuevo modo")

	con.ordenes.clear()
	interfaz._combate_botones_modo[2].pressed.emit()
	_comprobar(con.ordenes == [[2, 0, 0]], "Balanced manda ofensivo=2")

	print("Chase y marcados son independientes del modo de ataque:")
	con.ordenes.clear()
	interfaz._combate_boton_perseguir.pressed.emit()
	_comprobar(con.ordenes == [[2, 1, 0]],
		"activar chase manda perseguir=1 conservando el modo actual (2)")
	_comprobar(interfaz._combate_boton_perseguir.text.contains("Chase"),
		"el texto del boton cambia a Chase Opponent")

	con.ordenes.clear()
	interfaz._combate_boton_marcados.pressed.emit()
	_comprobar(con.ordenes == [[2, 1, 1]],
		"activar marcados manda marcados=1 conservando modo y chase")
	_comprobar(interfaz._combate_boton_marcados.text.contains("Unmarked"),
		"el texto del boton cambia a Attack Unmarked Players")

	con.ordenes.clear()
	interfaz._combate_boton_perseguir.pressed.emit()
	_comprobar(con.ordenes == [[2, 0, 1]],
		"desactivar chase vuelve a mandar perseguir=0 sin tocar marcados")
	_comprobar(interfaz._combate_boton_perseguir.text.contains("Stand"),
		"el texto del boton vuelve a Stand While Fighting")

	if _fallas > 0:
		printerr("FALLO: %d comprobaciones del panel de combate" % _fallas)
		get_tree().quit(1)
		return
	print("OK: el panel de combate manda 0xA0 exacto y no se adelanta a ninguna confirmacion")
	get_tree().quit(0)
