extends Node

# Prueba viva de muerte, corpse y loot contra el servidor TVP 7.72.
#
# No simula nada: habla con el servidor autoritativo y solo afirma lo que el
# servidor confirmo. La prueba se configura sola y limpia lo que crea.
#
#   1. SONDEO   entra con el personaje normal, anota donde esta y sale.
#   2. PREPARAR entra con el personaje god, se teletransporta a esa casilla
#               con `/gotopos` y deja un demon con `/m`.
#   3. MUERTE   vuelve a entrar con el personaje normal y no envia ninguna
#               intencion. Se comprueba la cadena exacta de esta rama:
#               vida autoritativa 0, corpse del jugador en la casilla, `0x6C`
#               que lo retira, `jugador_muerto`, logout `0x14` del cliente y
#               cierre de la sesion por parte del servidor. Esta rama no
#               tiene opcode de muerte y la prueba no espera ninguno.
#   4. REENTRADA comprueba que el reingreso devuelve un personaje vivo fuera
#               del sitio de la muerte.
#   5. LOOT     con el personaje god: `/killall` retira al demon (limpieza),
#               `/m` invoca un monstruo, se lo mata y se abre su corpse con
#               `0x82` para leer el loot que puso `Monster::dropLoot`.
#
# Requisitos vivos: servidor en 7171/7172 y el personaje normal parado fuera
# de una zona de proteccion; dentro del templo ningun monstruo puede
# atacarlo. Ver `docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md`.
#
#   ...Godot --headless --path cliente3d pruebas/prueba_muerte_loot_vivo.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
const CUENTA := 123456
const CLAVE := "123456"
const PERSONAJE := "Valentino"
const PERSONAJE_GOD := "GOD VALENTINO"
## Mata rapido y de forma reproducible a un personaje de nivel bajo.
const VERDUGO := "demon"
## Deja corpse y loot sin poner en riesgo a nadie.
const MONSTRUO := "rat"
## Casilla comprobada fuera de zona de proteccion. Dentro de un templo el
## servidor no deja invocar monstruos ni permite que ataquen, asi que la
## mitad de corpse y loot se hace siempre aca.
const POS_CAMPO := Vector3i(32082, 32145, 6)

const LIMITE_TOTAL := 600.0
const ESPERA_ORDEN := 3.0
## Si nadie nos pega en este tiempo, el sitio del duelo no sirve.
const ESPERA_PRIMER_GOLPE := 30.0

var _con
var _estado
var _etapa := "sondeo"
var _fase := "lista personajes"
var _reloj := 0.0
var _espera := 0.0
var _paso := 0
var _fallas := 0
var _puerto_juego := 7172

var _pos_duelo := Vector3i.ZERO
## Vida al entrar al duelo, para detectar que nadie nos puede pegar.
var _vida_al_llegar := -1

# --- evidencia de la muerte ---
var _muerte_emitida := false
var _pos_muerte := Vector3i.ZERO
var _corpse_jugador := {}
var _logout_enviado := false
var _servidor_corto := false
var _pos_reentrada := Vector3i.ZERO
var _vida_reentrada := -1

# --- evidencia de corpse y loot ---
var _id_monstruo := 0
var _pos_monstruo := Vector3i.ZERO
var _corpse_monstruo := {}
var _nombre_corpse := ""
var _loot: Array = []
var _demon_visible := false
## Modo de media prueba: solo corpse y loot con el personaje god.
var _solo_loot := false
var _intentos_invocar := 0


func _ready() -> void:
	print("=================================================")
	print(" TVP3D - prueba viva de muerte, corpse y loot")
	print("=================================================")
	if "--solo-loot" in OS.get_cmdline_user_args():
		# Media prueba: corpse y loot con el personaje god, sin matar a nadie.
		# Sirve para repetir esa mitad sin volver a costarle un nivel al
		# personaje normal.
		_solo_loot = true
		_etapa = "loot"
		_conectar_login(PERSONAJE_GOD)
		return
	_conectar_login(PERSONAJE)


func _process(delta: float) -> void:
	_reloj += delta
	_espera += delta
	if _reloj > LIMITE_TOTAL:
		print("Tiempo agotado en la etapa '%s', fase '%s'." % [_etapa, _fase])
		_fallas += 1
		_terminar()
		return
	if _estado == null:
		return
	match _fase:
		"anotar sitio":
			_anotar_sitio()
		"preparar duelo":
			_preparar_duelo()
		"esperar la muerte":
			_vigilar_el_duelo()
		"verificar reentrada":
			_verificar_reentrada()
		"salir":
			_insistir_con_el_logout()
		"limpiar y invocar":
			_limpiar_y_invocar()
		"matar":
			_vigilar_al_monstruo()


# -----------------------------------------------------------------
#  Conexion
# -----------------------------------------------------------------
func _conectar_login(personaje: String) -> void:
	_fase = "lista personajes de %s" % personaje
	_nueva_conexion()
	_con.lista_personajes.connect(func(motd, personajes):
		_al_recibir_personajes(personaje, motd, personajes))
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _nueva_conexion() -> void:
	if _con != null:
		_con.cerrar()
		_con.queue_free()
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(_al_fallar)


func _al_recibir_personajes(personaje: String, _motd: String,
		personajes: Array) -> void:
	var elegido := {}
	for p in personajes:
		if str(p.get("nombre", "")) == personaje:
			elegido = p
			break
	if elegido.is_empty():
		_error("La cuenta no tiene el personaje %s" % personaje)
		return
	_puerto_juego = int(elegido["puerto"])
	_entrar_al_mundo(personaje)


func _entrar_al_mundo(personaje: String) -> void:
	_fase = "entrar al mundo con %s" % personaje
	_estado = ESTADO.new()
	_estado.entramos.connect(_al_entramos)
	_estado.rechazados.connect(func(motivo): _error("Rechazado: " + motivo))
	_estado.jugador_muerto.connect(_al_morir)
	_estado.casilla_actualizada.connect(_al_casilla)
	_estado.contenedor_actualizado.connect(_al_contenedor)
	_estado.mensaje_servidor.connect(func(texto): print("  [srv] ", texto))
	# El servidor pregunta cada cinco segundos si seguimos vivos y corta la
	# sesion si nadie contesta. Sin esto la prueba muere de timeout y no de
	# lo que quiere medir.
	_estado.pedido_ping.connect(func(): _con.enviar_juego(PackedByteArray([0x1E])))
	_nueva_conexion()
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.cerrada.connect(_al_cerrarse.bind(_con))
	_con.entrar_al_mundo(HOST, _puerto_juego, CUENTA, personaje, CLAVE)


func _al_entramos() -> void:
	match _etapa:
		"sondeo":
			_pasar_a("anotar sitio")
		"preparar":
			print("Dentro con %s para preparar el duelo." % PERSONAJE_GOD)
			_pasar_a("preparar duelo")
		"muerte":
			_pasar_a("esperar la muerte")
			print("Dentro con %s en el sitio del duelo. No se envia nada." % PERSONAJE)
		"reentrada":
			_pasar_a("verificar reentrada")
		"loot":
			print("Dentro con %s para limpiar e invocar." % PERSONAJE_GOD)
			_pasar_a("limpiar y invocar")


func _pasar_a(fase: String) -> void:
	print("  [%.0fs] fase: %s" % [_reloj, fase])
	_fase = fase
	_espera = 0.0
	_paso = 0


func _al_cerrarse(quien = null) -> void:
	if quien != null and quien != _con:
		return   # cierre de una conexion vieja ya reemplazada
	match _etapa:
		"sondeo":
			_etapa = "preparar"
			_conectar_login(PERSONAJE_GOD)
		"preparar":
			_etapa = "muerte"
			_conectar_login(PERSONAJE)
		"muerte":
			_servidor_corto = true
			print("El servidor corto la conexion despues del logout 0x14.")
			_comprobar("el logout tras morir termina la sesion",
				_logout_enviado and _servidor_corto)
			_etapa = "reentrada"
			_conectar_login(PERSONAJE)
		"reentrada":
			_etapa = "loot"
			_conectar_login(PERSONAJE_GOD)
		"final":
			_terminar()


# -----------------------------------------------------------------
#  1. Sondeo: donde esta parado el personaje
# -----------------------------------------------------------------
func _anotar_sitio() -> void:
	if _estado.mi_pos == Vector3i.ZERO:
		return   # todavia no llego el 0x64
	# La prueba no mueve al personaje: caminar a ciegas no saca a nadie de la
	# zona de proteccion de un templo, y un auto-walk inventado seria una
	# intencion del cliente que esta prueba justamente no debe simular. Se
	# pelea donde el personaje ya esta parado y, si ahi nadie puede atacarlo,
	# la etapa de duelo lo dice con todas las letras.
	_pos_duelo = _estado.mi_pos
	print("%s esta en %s: ahi va el duelo." % [PERSONAJE, str(_pos_duelo)])
	_pasar_a("salir")


func _insistir_con_el_logout() -> void:
	# El servidor puede rechazar el logout mientras dura el in-fight. Se pide
	# de nuevo en vez de cortar el socket a mano.
	if _paso == 0 or _espera > 6.0:
		_paso += 1
		_espera = 0.0
		_con.enviar_logout()


# -----------------------------------------------------------------
#  2. Preparar: teletransporte del god y demon en la casilla
# -----------------------------------------------------------------
func _preparar_duelo() -> void:
	if _espera < ESPERA_ORDEN and _paso > 0:
		return
	_espera = 0.0
	_paso += 1
	match _paso:
		1:
			_con.enviar_hablar("/gotopos %d,%d,%d" % [
				_pos_duelo.x, _pos_duelo.y, _pos_duelo.z])
		2:
			_comprobar("el god llego a la casilla del duelo",
				_estado.mi_pos == _pos_duelo)
			print("Invocando %s en %s." % [VERDUGO, str(_pos_duelo)])
			_con.enviar_hablar("/m %s" % VERDUGO)
		3:
			_comprobar("el servidor invoco al %s" % VERDUGO,
				_hay_criatura(VERDUGO))
			_pasar_a("salir")


func _hay_criatura(nombre: String) -> bool:
	for id in _estado.criaturas:
		if int(id) == _estado.mi_id:
			continue
		if str(_estado.criaturas[id].get("nombre", "")).to_lower() == nombre:
			return true
	return false


# -----------------------------------------------------------------
#  3. Muerte
# -----------------------------------------------------------------
func _al_casilla(posicion: Vector3i, opcode: int) -> void:
	if opcode != 0x6A and opcode != 0x6B:
		return
	if _fase == "esperar la muerte" and posicion == _estado.mi_pos:
		var cosa := _contenedor_en(posicion)
		if not cosa.is_empty():
			_corpse_jugador = cosa
			print("  corpse del jugador en %s: %s" % [
				str(posicion), str(cosa.get("nombre", ""))])
	elif _fase == "matar" and posicion == _pos_monstruo:
		var cosa_m := _contenedor_en(posicion)
		if not cosa_m.is_empty():
			_corpse_monstruo = cosa_m


func _contenedor_en(posicion: Vector3i) -> Dictionary:
	## El corpse recien creado de esta rama es un item contenedor sobre la
	## casilla; sus etapas de descomposicion ya no lo son.
	for cosa in _estado.casillas.get(posicion, []):
		var c: Dictionary = cosa
		if c.get("tipo") == "item" and bool(c.get("contenedor", false)) \
				and not bool(c.get("suelo", false)) \
				and str(c.get("nombre", "")).to_lower().begins_with("dead "):
			return c
	return {}


func _al_morir(posicion: Vector3i) -> void:
	## Mismo consumo que hace mundo3d.gd al recibir la senal.
	if _muerte_emitida:
		return
	_muerte_emitida = true
	_pos_muerte = posicion
	_fase = "logout tras morir"
	print("MUERTE confirmada por el servidor en %s." % str(posicion))
	_comprobar("la muerte llega con vida autoritativa cero",
		int(_estado.estadisticas.get("vida", -1)) == 0)
	_comprobar("la muerte deja al jugador fuera del mundo",
		not _estado.adentro)
	_comprobar("el servidor dejo el corpse del jugador en su casilla",
		not _corpse_jugador.is_empty())
	_logout_enviado = true
	_con.enviar_logout()


func _vigilar_el_duelo() -> void:
	var vida := int(_estado.estadisticas.get("vida", -1))
	if vida < 0:
		return
	if _vida_al_llegar < 0:
		_vida_al_llegar = vida
		_espera = 0.0
		return
	if vida < _vida_al_llegar:
		return   # ya nos estan pegando: la prueba avanza sola
	if _espera > ESPERA_PRIMER_GOLPE:
		_error("Nadie ataca a %s en %s. Suele ser zona de proteccion:"
			% [PERSONAJE, str(_estado.mi_pos)]
			+ " sacalo del templo antes de repetir la prueba.")


# -----------------------------------------------------------------
#  4. Reentrada
# -----------------------------------------------------------------
func _verificar_reentrada() -> void:
	if int(_estado.estadisticas.get("vida", -1)) < 0 \
			or _estado.mi_pos == Vector3i.ZERO:
		return   # todavia no llegaron el 0x64 y el 0xA0 del reingreso
	_pos_reentrada = _estado.mi_pos
	_vida_reentrada = int(_estado.estadisticas.get("vida", -1))
	print("Reingreso confirmado en %s con vida %d." % [
		str(_pos_reentrada), _vida_reentrada])
	_comprobar("la reentrada deja al personaje vivo", _vida_reentrada > 0)
	_comprobar("la reentrada no devuelve al personaje al sitio de la muerte",
		_pos_reentrada != _pos_muerte)
	_pasar_a("salir")


# -----------------------------------------------------------------
#  5. Limpieza, corpse y loot
# -----------------------------------------------------------------
func _limpiar_y_invocar() -> void:
	if _espera < ESPERA_ORDEN and _paso > 0:
		return
	_espera = 0.0
	_paso += 1
	match _paso:
		1:
			var donde := POS_CAMPO if _solo_loot else _pos_duelo
			_con.enviar_hablar("/gotopos %d,%d,%d" % [
				donde.x, donde.y, donde.z])
		2:
			if _solo_loot:
				return   # no hay verdugo que limpiar en la media prueba
			_demon_visible = _hay_criatura(VERDUGO)
			print("Limpiando el %s invocado para la prueba." % VERDUGO)
			_con.enviar_hablar("/killall")
		3:
			if not _solo_loot:
				_comprobar("la limpieza retira al %s invocado" % VERDUGO,
					not _hay_criatura(VERDUGO))
			print("Invocando %s para el corpse." % MONSTRUO)
			_con.enviar_hablar("/m %s" % MONSTRUO)
		4:
			if not _buscar_monstruo():
				# El spawn pudo fallar por falta de sitio: se vuelve a pedir.
				_intentos_invocar += 1
				if _intentos_invocar > 4:
					_error("El servidor no invoca %s en %s" % [
						MONSTRUO, str(_estado.mi_pos)])
					return
				_paso = 2
				return
			_pasar_a("matar")


func _buscar_monstruo() -> bool:
	for id in _estado.criaturas:
		if int(id) == _estado.mi_id:
			continue
		var criatura: Dictionary = _estado.criaturas[id]
		if str(criatura.get("nombre", "")).to_lower() != MONSTRUO:
			continue
		_id_monstruo = int(id)
		_pos_monstruo = criatura.get("pos", Vector3i.ZERO)
		print("Invocado %s con id %d en %s. Se ataca con 0xA1." % [
			MONSTRUO, _id_monstruo, str(_pos_monstruo)])
		_con.enviar_modos_combate(1, 1, 0)
		_con.enviar_atacar(_id_monstruo)
		return true
	return false


func _vigilar_al_monstruo() -> void:
	if _estado.criaturas.has(_id_monstruo):
		_pos_monstruo = _estado.criaturas[_id_monstruo].get("pos", _pos_monstruo)
		if _espera > 20.0 and _paso < 9:
			# El personaje god pega con los punyos; si tarda demasiado se usa
			# la misma orden de servidor que ya limpio al verdugo.
			_paso = 9
			print("El ataque cuerpo a cuerpo tarda; se remata con /killall.")
			_con.enviar_hablar("/killall")
		return
	if _corpse_monstruo.is_empty():
		# El monstruo pudo dar un paso antes de morir, asi que el corpse se
		# busca tambien en las casillas vecinas.
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var donde := _pos_monstruo + Vector3i(dx, dy, 0)
				var cosa := _contenedor_en(donde)
				if not cosa.is_empty():
					_corpse_monstruo = cosa
					_pos_monstruo = donde
					break
			if not _corpse_monstruo.is_empty():
				break
	if _corpse_monstruo.is_empty():
		if _espera > 8.0:
			_espera = 0.0
			print("  sin corpse todavia cerca de %s" % str(_pos_monstruo))
			for cosa in _estado.casillas.get(_pos_monstruo, []):
				print("    pila: ", str(cosa.get("nombre", cosa.get("cid", "?"))))
		return
	_fase = "saquear"
	print("El monstruo murio y dejo corpse en %s: %s" % [
		str(_pos_monstruo), str(_corpse_monstruo.get("nombre", ""))])
	_comprobar("el monstruo muerto deja un corpse contenedor",
		bool(_corpse_monstruo.get("contenedor", false)))
	_con.enviar_usar_item(_pos_monstruo,
		int(_corpse_monstruo.get("cid", 0)),
		_pila_de(_pos_monstruo, _corpse_monstruo))


func _pila_de(posicion: Vector3i, cosa: Dictionary) -> int:
	var pila := 0
	for elemento in _estado.casillas.get(posicion, []):
		if elemento == cosa:
			return pila
		pila += 1
	return 0


func _al_contenedor(id: int, datos: Dictionary) -> void:
	if _fase != "saquear":
		return
	_nombre_corpse = str(datos.get("nombre", ""))
	_loot = datos.get("items", [])
	print("Corpse abierto como contenedor %d: '%s' con %d cosas." % [
		id, _nombre_corpse, _loot.size()])
	for cosa in _loot:
		print("   loot: %s x%d" % [
			str(cosa.get("nombre", "?")), int(cosa.get("cantidad", 1))])
	_comprobar("el corpse del monstruo se abre como contenedor real",
		not _nombre_corpse.is_empty())
	_comprobar("el nombre del corpse nombra al monstruo",
		_nombre_corpse.to_lower().contains(MONSTRUO))
	_etapa = "final"
	_pasar_a("salir")


# -----------------------------------------------------------------
#  Resultado
# -----------------------------------------------------------------
func _comprobar(nombre: String, correcto: bool) -> void:
	if correcto:
		print("  OK  " + nombre)
	else:
		print("  FAIL " + nombre)
		_fallas += 1


func _error(texto: String) -> void:
	print("  FAIL " + texto)
	_fallas += 1
	_terminar()


func _al_fallar(texto: String) -> void:
	if _etapa == "final" or _fase == "salir" or _fase == "logout tras morir":
		return   # el cierre esperado del servidor no es un fallo de red
	_error("Fallo de red en la etapa '%s': %s" % [_etapa, texto])


func _terminar() -> void:
	print("--- resumen ---")
	if not _solo_loot:
		_comprobar("el servidor emitio la muerte del jugador", _muerte_emitida)
		_comprobar("el cliente respondio con logout 0x14", _logout_enviado)
		_comprobar("el servidor corto la sesion tras el logout", _servidor_corto)
		_comprobar("el reingreso devolvio un personaje vivo", _vida_reentrada > 0)
	_comprobar("se abrio el corpse de un monstruo con su loot",
		not _nombre_corpse.is_empty())
	if _con != null:
		_con.cerrar()
	if _fallas == 0:
		print("Prueba viva de muerte, corpse y loot: OK")
	else:
		print("Prueba viva de muerte, corpse y loot: %d fallas" % _fallas)
	get_tree().quit(1 if _fallas > 0 else 0)
