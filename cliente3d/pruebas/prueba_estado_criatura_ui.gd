extends Node

## Comprueba que la UI representa la velocidad, la calavera y el escudo de party
## que `protocolo-red` 1.1.0 conserva, sin inventar ninguno de los tres.
##
## Las fuentes son las mismas que usa el juego: `EstadoMundo.criaturas` para las
## marcas de cada criatura y el estado de criatura de `mi_id` para la velocidad,
## porque el `0xA0` de stats de 7.72 no transporta velocidad.

const INTERFAZ := preload("res://ui/interfaz.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const SPRITES := preload("res://red/sprites772.gd")
const MARCA := preload("res://ui/marca_criatura.gd")

var _fallas := 0


class DiscoMarcas:
	func ids_de(_posicion: Vector3i) -> PackedInt32Array:
		return PackedInt32Array()


class ConexionMarcas:
	func enviar_atacar(_id: int) -> void:
		pass

	func enviar_seguir(_id: int) -> void:
		pass


class MundoMarcas:
	var _disco := DiscoMarcas.new()
	var _con := ConexionMarcas.new()
	var _estado

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
		printerr("  FALLA %s" % texto)


func _marca(interfaz, id: int, clase: String):
	var marcas: Dictionary = interfaz._battle_marcas.get(id, {})
	return marcas.get(clase, null)


func _texto_speed(interfaz) -> String:
	var valor = interfaz._skills_box.find_child("Speed", true, false)
	return "" if valor == null else str(valor.text)


func _ready() -> void:
	var estado := ESTADO.new()
	estado.adentro = true
	estado.mi_id = 100
	estado.mi_pos = Vector3i(32097, 32219, 7)
	estado.estadisticas = {"vida": 155, "vida_max": 155, "mana": 60,
		"mana_max": 60, "nivel": 8, "nivel_pct": 40, "capacidad": 400}
	estado.criaturas = {
		# Nosotros: la velocidad vive aqui, no en las stats.
		100: {"pos": estado.mi_pos, "nombre": "Guuille", "vida": 100,
			"velocidad": 220, "calavera": 0, "escudo_party": 0},
		# Red skull y lider de party confirmados por el servidor.
		101: {"pos": estado.mi_pos + Vector3i(1, 0, 0), "nombre": "Killer",
			"vida": 100, "velocidad": 240, "calavera": 4, "escudo_party": 4},
		# White skull y miembro de party.
		102: {"pos": estado.mi_pos + Vector3i(2, 0, 0), "nombre": "Partner",
			"vida": 80, "velocidad": 220, "calavera": 3, "escudo_party": 3},
		# Un monstruo normal: sin calavera ni escudo.
		103: {"pos": estado.mi_pos + Vector3i(3, 0, 0), "nombre": "Rat",
			"apariencia": 21, "vida": 100, "velocidad": 200},
	}
	var mundo := MundoMarcas.new()
	var interfaz = INTERFAZ.new(mundo, estado, SPRITES.new(), null)
	add_child(interfaz)
	await get_tree().process_frame
	interfaz._refrescar()
	await get_tree().process_frame

	print("Marcas de criatura en Battle:")
	var calavera_roja = _marca(interfaz, 101, MARCA.CALAVERA)
	var escudo_lider = _marca(interfaz, 101, MARCA.ESCUDO)
	_comprobar(calavera_roja != null and calavera_roja.visible
		and calavera_roja.valor == 4,
		"la calavera roja de Killer se dibuja")
	_comprobar(calavera_roja != null
		and calavera_roja.tooltip_text == "Red Skull",
		"la calavera roja se nombra Red Skull")
	_comprobar(escudo_lider != null and escudo_lider.visible
		and escudo_lider.valor == 4
		and escudo_lider.tooltip_text == "Party leader",
		"el escudo amarillo de Killer dice Party leader")
	var calavera_blanca = _marca(interfaz, 102, MARCA.CALAVERA)
	var escudo_miembro = _marca(interfaz, 102, MARCA.ESCUDO)
	_comprobar(calavera_blanca != null and calavera_blanca.valor == 3
		and calavera_blanca.tooltip_text == "White Skull",
		"la calavera blanca de Partner se distingue de la roja")
	_comprobar(escudo_miembro != null and escudo_miembro.valor == 3
		and escudo_miembro.tooltip_text == "Party member",
		"el escudo azul de Partner dice Party member")
	var calavera_rata = _marca(interfaz, 103, MARCA.CALAVERA)
	var escudo_rata = _marca(interfaz, 103, MARCA.ESCUDO)
	_comprobar(calavera_rata != null and not calavera_rata.visible
		and escudo_rata != null and not escudo_rata.visible,
		"una criatura sin calavera ni escudo no muestra marcas inventadas")

	print("Velocidad propia en Skills:")
	_comprobar(_texto_speed(interfaz) == "220",
		"Speed muestra la velocidad de mi_id, no un cero de stats")

	print("Cambios en vivo (0x90, 0x91 y 0x8F):")
	var fila_antes = interfaz._battle_rows.get(101)
	estado._actualizar_estado_criatura(101, {"calavera": 1})
	estado._actualizar_estado_criatura(101, {"escudo_party": 2})
	estado._actualizar_estado_criatura(100, {"velocidad": 320})
	interfaz._refrescar()
	await get_tree().process_frame
	_comprobar(interfaz._battle_rows.get(101) == fila_antes,
		"un cambio de calavera no reconstruye la fila del Battle")
	_comprobar(calavera_roja.valor == 1
		and calavera_roja.tooltip_text == "Yellow Skull",
		"el 0x90 amarillo reemplaza la calavera roja")
	_comprobar(escudo_lider.valor == 2
		and escudo_lider.tooltip_text == "Party invitation sent",
		"el 0x91 cambia el escudo a la invitacion enviada")
	_comprobar(_texto_speed(interfaz) == "320",
		"el 0x8F actualiza la velocidad mostrada en Skills")

	print("Marcas en el panel Target:")
	_comprobar(interfaz.mostrar_objetivo(102),
		"el Target acepta a Partner como objetivo")
	var calavera_target = interfaz._target_marcas.get(MARCA.CALAVERA)
	var escudo_target = interfaz._target_marcas.get(MARCA.ESCUDO)
	_comprobar(calavera_target != null and calavera_target.visible
		and calavera_target.valor == 3,
		"el Target repite la calavera blanca de Partner")
	_comprobar(escudo_target != null and escudo_target.visible
		and escudo_target.valor == 3,
		"el Target repite el escudo azul de Partner")
	interfaz.mostrar_objetivo(103)
	await get_tree().process_frame
	_comprobar(not calavera_target.visible and not escudo_target.visible,
		"al cambiar a la Rat el Target no conserva marcas del objetivo anterior")

	print("Tablas de dominio:")
	_comprobar(MARCA.CALAVERAS.keys() == [1, 2, 3, 4],
		"la tabla de calaveras cubre Skulls_t 1..4 sin SKULL_NONE")
	_comprobar(MARCA.ESCUDOS.keys() == [1, 2, 3, 4],
		"la tabla de escudos cubre PartyShields_t 1..4 sin SHIELD_NONE")
	_comprobar(not MARCA.CALAVERAS.has(5) and not MARCA.ESCUDOS.has(5),
		"un valor fuera de la tabla no tiene marca que dibujar")
	calavera_roja.mostrar(5)
	_comprobar(not calavera_roja.visible and calavera_roja.tooltip_text == "",
		"una calavera desconocida se oculta en vez de adivinar un color")

	if _fallas > 0:
		printerr("FALLO: %d comprobaciones de estado de criatura en la UI" % _fallas)
		get_tree().quit(1)
		return
	print("OK: la UI representa velocidad, calavera y escudo de party")
	get_tree().quit(0)
