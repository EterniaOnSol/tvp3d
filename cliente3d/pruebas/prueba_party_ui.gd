extends Node

## Comprueba el menu de criatura y las ordenes de party de la interfaz.
##
## La party de esta rama no llega en ningun paquete propio: el servidor solo
## manda el escudo de cada criatura por el `0x91`. Por eso el menu se arma
## unicamente con esos escudos confirmados, y cada opcion manda su opcode y
## nada mas: la interfaz no se adelanta al resultado.

const INTERFAZ := preload("res://ui/interfaz.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const SPRITES := preload("res://red/sprites772.gd")

const YO := 0x10000001
const OTRO := 0x10000002
const MONSTRUO := 0x40000001

var _fallas := 0


class DiscoParty:
	func ids_de(_posicion: Vector3i) -> PackedInt32Array:
		return PackedInt32Array()


class ConexionParty:
	var ordenes: Array = []

	func enviar_atacar(_id: int) -> void:
		pass

	func enviar_seguir(id: int) -> void:
		ordenes.append(["seguir", id])

	func enviar_invitar_a_party(id: int) -> void:
		ordenes.append(["invitar", id])

	func enviar_unirse_a_party(id: int) -> void:
		ordenes.append(["unirse", id])

	func enviar_revocar_invitacion_party(id: int) -> void:
		ordenes.append(["revocar", id])

	func enviar_pasar_liderazgo_party(id: int) -> void:
		ordenes.append(["liderazgo", id])

	func enviar_salir_de_party() -> void:
		ordenes.append(["salir", 0])


class MundoParty:
	var _disco := DiscoParty.new()
	var _con := ConexionParty.new()
	var _estado
	var ataques: Array = []

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


func _comprobar(condicion: bool, texto: String) -> void:
	if condicion:
		print("  OK   %s" % texto)
	else:
		_fallas += 1
		printerr("  FALLA %s" % texto)


func _acciones(interfaz, id: int) -> Array:
	var salida: Array = []
	for accion in interfaz.acciones_de_criatura(id):
		salida.append(str(accion[0]))
	return salida


func _fijar_escudos(estado, mio: int, suyo: int) -> void:
	estado.criaturas[YO]["escudo_party"] = mio
	estado.criaturas[OTRO]["escudo_party"] = suyo


func _ready() -> void:
	var estado := ESTADO.new()
	estado.adentro = true
	estado.mi_id = YO
	estado.mi_pos = Vector3i(32097, 32219, 7)
	estado.criaturas = {
		YO: {"pos": estado.mi_pos, "nombre": "Guuille", "vida": 100,
			"velocidad": 220, "calavera": 0, "escudo_party": 0},
		OTRO: {"pos": estado.mi_pos + Vector3i(1, 0, 0), "nombre": "Partner",
			"vida": 100, "velocidad": 220, "calavera": 0, "escudo_party": 0},
		MONSTRUO: {"pos": estado.mi_pos + Vector3i(2, 0, 0), "nombre": "Rat",
			"apariencia": 21, "vida": 100},
	}
	var mundo := MundoParty.new()
	var interfaz = INTERFAZ.new(mundo, estado, SPRITES.new(), null)
	add_child(interfaz)
	await get_tree().process_frame

	print("A quien se le puede ofrecer party:")
	_comprobar(interfaz.es_jugador(OTRO) and not interfaz.es_jugador(MONSTRUO),
		"solo los ids de jugador cuentan como jugador")
	_comprobar(_acciones(interfaz, MONSTRUO) == ["atacar", "seguir"],
		"a un monstruo no se lo invita a una party")
	_comprobar(_acciones(interfaz, YO) == ["atacar", "seguir"],
		"uno no se invita a si mismo")

	print("El menu sale de los escudos confirmados:")
	_fijar_escudos(estado, 0, 0)
	_comprobar(_acciones(interfaz, OTRO) == ["atacar", "seguir", "invitar"],
		"sin party de por medio se ofrece invitar")

	_fijar_escudos(estado, 0, 1)
	_comprobar(_acciones(interfaz, OTRO) == ["atacar", "seguir", "unirse"],
		"si nos invitaron se ofrece unirse")

	_fijar_escudos(estado, 0, 2)
	_comprobar(_acciones(interfaz, OTRO) == ["atacar", "seguir", "revocar"],
		"si lo invitamos se ofrece revocar")

	_fijar_escudos(estado, 4, 3)
	_comprobar(_acciones(interfaz, OTRO)
			== ["atacar", "seguir", "liderazgo", "salir"],
		"el lider puede pasar el liderazgo a un miembro y salir")

	_fijar_escudos(estado, 3, 4)
	_comprobar(_acciones(interfaz, OTRO) == ["atacar", "seguir", "salir"],
		"un miembro no manda sobre el lider, pero puede salir")

	_fijar_escudos(estado, 3, 0)
	_comprobar(_acciones(interfaz, OTRO) == ["atacar", "seguir", "salir"],
		"un miembro que no es lider no invita a nadie")

	_fijar_escudos(estado, 4, 0)
	_comprobar(_acciones(interfaz, OTRO)
			== ["atacar", "seguir", "invitar", "salir"],
		"el lider si puede invitar a alguien de afuera")

	print("Cada opcion manda su orden y nada mas:")
	var con = mundo._con
	con.ordenes.clear()
	_fijar_escudos(estado, 0, 0)
	interfaz.ejecutar_accion_criatura("invitar", OTRO)
	interfaz.ejecutar_accion_criatura("unirse", OTRO)
	interfaz.ejecutar_accion_criatura("revocar", OTRO)
	interfaz.ejecutar_accion_criatura("liderazgo", OTRO)
	interfaz.ejecutar_accion_criatura("salir", OTRO)
	_comprobar(con.ordenes == [
			["invitar", OTRO], ["unirse", OTRO], ["revocar", OTRO],
			["liderazgo", OTRO], ["salir", 0]],
		"las cinco ordenes llegan con el id correcto")
	_comprobar(int(estado.criaturas[YO]["escudo_party"]) == 0
			and int(estado.criaturas[OTRO]["escudo_party"]) == 0,
		"mandar una orden no cambia ningun escudo por su cuenta")

	print("El menu tambien conserva atacar y seguir:")
	interfaz.ejecutar_accion_criatura("atacar", OTRO)
	_comprobar(mundo.ataques == [OTRO], "atacar sigue disponible en el menu")
	interfaz.ejecutar_accion_criatura("seguir", OTRO)
	_comprobar(con.ordenes.back() == ["seguir", OTRO],
		"seguir sigue disponible en el menu")

	if _fallas > 0:
		printerr("FALLO: %d comprobaciones del menu de party" % _fallas)
		get_tree().quit(1)
		return
	print("OK: el menu de party se arma con los escudos del servidor")
	get_tree().quit(0)
