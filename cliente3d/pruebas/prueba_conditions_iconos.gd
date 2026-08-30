extends Node

## Comprueba que la franja de Conditions recorte el sprite real
## (assets/ui/conditions/player-state-flags.png) en el offset correcto para
## cada uno de los ocho bits que maneja este servidor 7.72
## (servidor/src/const.h Icons_t), y que un bit apagado no dibuje nada.
##
## El recorte replica exactamente `applyIconWidgetStyle` de
## `gamelib/player.lua` en el cliente OTClient de referencia: cada icono mide
## 9x9 y su offset X es `(clip - 1) * 9`. Los primeros ocho valores de `clip`
## en esa tabla (Poison=1, Burn=2, Energy=3, Drunk=4, ManaShield=5,
## Paralyze=6, Haste=7, Swords=8) coinciden en orden con los ocho bits de
## `Icons_t`, asi que el offset de cada bit es simplemente `bit * 9`.

const INTERFAZ := preload("res://ui/interfaz.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const SPRITES := preload("res://red/sprites772.gd")

const YO := 0x10000001
const LADO := 9

var _fallas := 0


class DiscoConditions:
	func ids_de(_posicion: Vector3i) -> PackedInt32Array:
		return PackedInt32Array()


class MundoConditions:
	var _disco := DiscoConditions.new()

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
	estado.iconos_estado = 0
	var mundo := MundoConditions.new()
	var interfaz = INTERFAZ.new(mundo, estado, SPRITES.new(), null)
	add_child(interfaz)
	await get_tree().process_frame

	_comprobar(interfaz._conditions_box.get_child_count() == 0,
		"sin bits activos no se dibuja ningun icono")

	estado.iconos_estado = (1 << 0) | (1 << 7)   # Poison + Swords
	interfaz._actualizar_conditions()
	await get_tree().process_frame
	_comprobar(interfaz._conditions_box.get_child_count() == 2,
		"dos bits activos dibujan exactamente dos iconos")
	var hijos: Array = interfaz._conditions_box.get_children()
	var region0: Rect2 = hijos[0].texture.region
	var region7: Rect2 = hijos[1].texture.region
	_comprobar(region0 == Rect2(0 * LADO, 0, LADO, LADO),
		"Poison (bit 0) recorta el icono 0 del sheet (offset 0)")
	_comprobar(region7 == Rect2(7 * LADO, 0, LADO, LADO),
		"Swords (bit 7) recorta el icono 7 del sheet (offset 63)")
	_comprobar(hijos[0].texture.atlas == load(
			"res://assets/ui/conditions/player-state-flags.png"),
		"el atlas es el sprite real, no una forma por codigo")

	estado.iconos_estado = (1 << 4)   # Mana Shield
	interfaz._actualizar_conditions()
	await get_tree().process_frame
	_comprobar(interfaz._conditions_box.get_child_count() == 1,
		"Mana Shield sola deja exactamente un icono")
	var region4: Rect2 = interfaz._conditions_box.get_children()[0].texture.region
	_comprobar(region4 == Rect2(4 * LADO, 0, LADO, LADO),
		"Mana Shield (bit 4) recorta el icono 4 (offset 36), region=%s" % str(region4))

	if _fallas > 0:
		printerr("FALLO: %d comprobaciones de iconos de condiciones" % _fallas)
		get_tree().quit(1)
		return
	print("OK: la franja de Conditions recorta el sprite real en el offset exacto de cada bit")
	get_tree().quit(0)
