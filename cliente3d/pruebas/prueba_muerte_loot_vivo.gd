extends Node

# Prueba viva de muerte, corpse y loot contra el servidor TVP 7.72.
#
# No simula nada: habla con el servidor autoritativo y solo afirma lo que el
# servidor confirmo. La prueba se configura sola y limpia lo que crea.
#
#   1. DUELO    entra con el personaje normal y se queda dentro. En paralelo
#               entra el personaje god por su propia conexion, va al campo
#               con `/gotopos`, trae al personaje normal con `/c` y deja un
#               demon con `/m`. El personaje normal nunca camina: el que lo
#               mueve es el servidor.
#   2. MUERTE   el personaje normal no envia ninguna intencion. Se comprueba
#               la cadena exacta de esta rama: vida autoritativa 0, corpse
#               del jugador en la casilla, `0x6C` que lo retira,
#               `jugador_muerto`, logout `0x14` del cliente y cierre de la
#               sesion por parte del servidor. Esta rama no tiene opcode de
#               muerte y la prueba no espera ninguno.
#   3. REENTRADA comprueba que el reingreso devuelve un personaje vivo fuera
#               del sitio de la muerte.
#   4. LOOT     con el personaje god: `/killall` retira al demon (limpieza),
#               `/m` invoca un monstruo, se lo mata y se abre su corpse con
#               `0x82` para leer el loot que puso `Monster::dropLoot`.
#
# Requisito vivo: el servidor en 7171/7172. La precondicion de pelear fuera de
# una zona de proteccion ya no es manual: la resuelve el propio servidor con
# `/c` (`data/scripts/talkactions/god/teleport_creature_here.lua`), que mueve
# al personaje a la casilla libre mas cercana al god. Ver
# `docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md`.
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
## servidor no deja invocar monstruos ni permite que ataquen, asi que tanto el
## duelo como la mitad de corpse y loot se hacen siempre aca.
const POS_CAMPO := Vector3i(32082, 32145, 6)
## `/c` deja al personaje en la casilla libre mas cercana al god, no encima.
const RADIO_CAMPO := 2

const LIMITE_TOTAL := 600.0
const ESPERA_ORDEN := 3.0
## Si nadie nos pega en este tiempo, el sitio del duelo no sirve.
const ESPERA_PRIMER_GOLPE := 30.0
## Si el `/c` no mueve al personaje en este tiempo, la precondicion fallo.
const ESPERA_TELEPORT := 20.0
## Margen para que el verdugo invocado llegue a alguna de las dos sesiones.
const ESPERA_VERDUGO := 12.0
## `Ban::acceptConnection` (servidor/src/ban.cpp:13-45) bloquea tres segundos a
## la IP que abre mas de cinco conexiones dentro de una ventana de cinco
## segundos, y cada intento bloqueado alarga el castigo. La prueba abre varias
## sesiones, asi que las separa en vez de hacerse cortar por el servidor.
const PAUSA_SESION := 6.0
## Margen para que el corpse del monstruo llegue al cliente antes de fallar.
const ESPERA_CORPSE := 90.0

var _con
var _estado
var _etapa := "duelo"
var _fase := "lista personajes"
var _reloj := 0.0
var _espera := 0.0
var _paso := 0
var _fallas := 0
var _puerto_juego := 7172
## Puerto de juego por personaje, aprendido en el unico login de la corrida.
var _puertos := {}
var _pendiente := ""

var _pos_duelo := Vector3i.ZERO
## Vida al entrar al duelo, para detectar que nadie nos puede pegar.
var _vida_al_llegar := -1

# --- sesion paralela del god que arma el duelo ---
var _con_god
var _estado_god
var _god_dentro := false
var _god_saliendo := false
var _pos_antes_del_campo := Vector3i.ZERO

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
## Momento en que empezo la caza, para no esperar el corpse hasta el limite.
var _inicio_matar := 0.0
var _god_fue_al_corpse := false
var _intentos_limpieza := 0
## Ids de criatura y casillas con corpse anteriores a esta caza. El campo es
## campo abierto: hay ratas salvajes y restos de corridas viejas, y la prueba
## solo puede afirmar algo del monstruo que ella misma invoco.
var _ids_previos := {}
var _corpses_previos := {}
## Modo de media prueba: solo corpse y loot con el personaje god.
var _solo_loot := false
## Modo de precondicion: arma el campo, comprueba el verdugo y lo retira antes
## de que mate a nadie. Repetible sin costarle un nivel al personaje.
var _solo_campo := false
var _intentos_invocar := 0
## Evidencia de mapas que no conservan al jugador en su propia casilla. Una
## pila desalineada no sirve para afirmar que el servidor omitio un corpse.
var _mapas_desalineados: Array = []


func _ready() -> void:
	print("=================================================")
	print(" TVP3D - prueba viva de muerte, corpse y loot")
	print("=================================================")
	if "--solo-campo" in OS.get_cmdline_user_args():
		# Solo la precondicion: llevar al personaje fuera de zona de proteccion
		# y comprobar que ahi si aparece el verdugo. No se deja morir a nadie.
		_solo_campo = true
		_conectar_login(PERSONAJE)
		return
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
		"esperar sesion":
			_esperar_sesion()
		"llevar al campo":
			_llevar_al_campo()
		"confirmar campo":
			_confirmar_campo()
		"invocar verdugo":
			_invocar_verdugo()
		"verificar campo limpio":
			_verificar_campo_limpio()
		"devolver al templo":
			_devolver_al_templo()
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
		"acercarse al corpse":
			_acercarse_al_corpse()


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
	for p in personajes:
		_puertos[str(p.get("nombre", ""))] = int(p.get("puerto", 0))
	var puerto := _puerto_de(personajes, personaje)
	if puerto <= 0:
		_error("La cuenta no tiene el personaje %s" % personaje)
		return
	_puerto_juego = puerto
	_entrar_al_mundo(personaje)


func _pedir_sesion(personaje: String) -> void:
	"""Encola una sesion nueva respetando la pausa entre conexiones."""
	_pendiente = personaje
	_pasar_a("esperar sesion")


func _esperar_sesion() -> void:
	if _espera < PAUSA_SESION:
		return
	var personaje := _pendiente
	_pendiente = ""
	if int(_puertos.get(personaje, 0)) > 0:
		# El puerto ya se sabe: se entra directo y se ahorra una conexion.
		_puerto_juego = int(_puertos[personaje])
		_entrar_al_mundo(personaje)
	else:
		_conectar_login(personaje)


func _puerto_de(personajes: Array, personaje: String) -> int:
	for p in personajes:
		if str(p.get("nombre", "")) == personaje:
			return int(p.get("puerto", 0))
	return 0


func _entrar_al_mundo(personaje: String) -> void:
	_fase = "entrar al mundo con %s" % personaje
	_estado = ESTADO.new()
	_estado.entramos.connect(_al_entramos)
	_estado.rechazados.connect(func(motivo): _error("Rechazado: " + motivo))
	_estado.jugador_muerto.connect(_al_morir)
	_estado.mapa_desalineado.connect(func(detalle):
		_registrar_mapa_desalineado(personaje, detalle))
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
		"duelo":
			print("Dentro con %s. No se envia ninguna intencion." % PERSONAJE)
			_pasar_a("llevar al campo")
			_abrir_sesion_god()
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
		"duelo":
			_servidor_corto = true
			print("El servidor corto la conexion despues del logout 0x14.")
			_comprobar("el logout tras morir termina la sesion",
				_logout_enviado and _servidor_corto)
			_etapa = "reentrada"
			_pedir_sesion(PERSONAJE)
		"reentrada":
			_etapa = "loot"
			_pedir_sesion(PERSONAJE_GOD)
		"final":
			_terminar()


func _insistir_con_el_logout() -> void:
	# El servidor puede rechazar el logout mientras dura el in-fight. Se pide
	# de nuevo en vez de cortar el socket a mano.
	if _paso == 0 or _espera > 6.0:
		_paso += 1
		_espera = 0.0
		_con.enviar_logout()


# -----------------------------------------------------------------
#  1. Duelo: el god arma el campo por su propia conexion
# -----------------------------------------------------------------
func _abrir_sesion_god() -> void:
	## Segunda sesion simultanea. No pasa por `_nueva_conexion()` para no
	## reemplazar la conexion del personaje normal, que sigue dentro del mundo
	## esperando el duelo.
	_estado_god = ESTADO.new()
	_estado_god.entramos.connect(func():
		_god_dentro = true
		print("Dentro con %s para armar el campo." % PERSONAJE_GOD))
	_estado_god.rechazados.connect(func(motivo):
		_error("El god fue rechazado: " + motivo))
	_estado_god.mensaje_servidor.connect(func(texto): print("  [god] ", texto))
	_estado_god.mapa_desalineado.connect(func(detalle):
		_registrar_mapa_desalineado(PERSONAJE_GOD, detalle))
	_con_god = CONEXION.new()
	add_child(_con_god)
	_estado_god.pedido_ping.connect(func():
		_con_god.enviar_juego(PackedByteArray([0x1E])))
	_con_god.error_red.connect(func(texto):
		if not _god_saliendo:
			_error("Fallo de red del god: " + texto))
	_con_god.paquete_juego.connect(func(msg): _estado_god.procesar(msg))
	_con_god.cerrada.connect(func():
		_god_dentro = false
		print("El god salio; el campo queda armado."))
	# El puerto del god ya vino en el unico login de la corrida, asi que su
	# sesion entra directo y no gasta otra conexion contra `Ban`.
	var puerto := int(_puertos.get(PERSONAJE_GOD, 0))
	if puerto > 0:
		_con_god.entrar_al_mundo(HOST, puerto, CUENTA, PERSONAJE_GOD, CLAVE)
		return
	_con_god.lista_personajes.connect(func(_motd, personajes):
		var puerto_god := _puerto_de(personajes, PERSONAJE_GOD)
		if puerto_god <= 0:
			_error("La cuenta no tiene el personaje %s" % PERSONAJE_GOD)
			return
		_con_god.entrar_al_mundo(HOST, puerto_god, CUENTA, PERSONAJE_GOD, CLAVE))
	_con_god.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _llevar_al_campo() -> void:
	if _pos_antes_del_campo == Vector3i.ZERO:
		# La casilla de entrada se conoce con el `0x64`, que llega despues de
		# `entramos`. Sin ella no hay con que comparar el teleport.
		if _estado.mi_pos == Vector3i.ZERO:
			return
		_pos_antes_del_campo = _estado.mi_pos
		print("%s entro en %s." % [PERSONAJE, str(_pos_antes_del_campo)])
	if not _god_dentro:
		if _espera > 60.0:
			_error("%s no entro al mundo para armar el campo" % PERSONAJE_GOD)
		return
	if _espera < ESPERA_ORDEN and _paso > 0:
		return
	_espera = 0.0
	_paso += 1
	match _paso:
		1:
			_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
				POS_CAMPO.x, POS_CAMPO.y, POS_CAMPO.z])
		2:
			_comprobar("el god llego al campo fuera de zona de proteccion",
				_estado_god.mi_pos == POS_CAMPO)
			# `/c` es la orden del propio servidor: mueve a la criatura a la
			# casilla libre mas cercana al god. El cliente no camina ni decide
			# a donde; solo mira donde lo dejo el servidor.
			print("Trayendo a %s al campo con /c." % PERSONAJE)
			_con_god.enviar_hablar("/c %s" % PERSONAJE)
			_pasar_a("confirmar campo")


func _confirmar_campo() -> void:
	## La confirmacion la da la sesion del propio personaje: su posicion
	## autoritativa, no la del god ni un supuesto de la prueba.
	if _en_el_campo(_estado.mi_pos):
		_pos_duelo = _estado.mi_pos
		print("El servidor movio a %s de %s a %s." % [
			PERSONAJE, str(_pos_antes_del_campo), str(_pos_duelo)])
		# Que la casilla sea o no zona de proteccion lo decide el servidor y el
		# cliente no lo recibe. La prueba afirma solo lo que si puede ver: que
		# el personaje esta en el campo, junto al god que lo llamo. Si esa
		# casilla dejara de servir, la etapa del duelo lo dice al no haber
		# golpes. La comprobacion no depende de donde estuviera antes: el
		# personaje puede haber quedado en el campo de una corrida anterior.
		_comprobar("el personaje esta en el campo del duelo, junto al god",
			_en_el_campo(_pos_duelo))
		_pasar_a("invocar verdugo")
		return
	if _espera > ESPERA_TELEPORT:
		_error(("El /c no llevo a %s al campo %s: sigue en %s."
			% [PERSONAJE, str(POS_CAMPO), str(_estado.mi_pos)])
			+ " Sin esa casilla no hay duelo posible.")


func _en_el_campo(posicion: Vector3i) -> bool:
	return posicion.z == POS_CAMPO.z \
		and absi(posicion.x - POS_CAMPO.x) <= RADIO_CAMPO \
		and absi(posicion.y - POS_CAMPO.y) <= RADIO_CAMPO


func _invocar_verdugo() -> void:
	if _paso == 0:
		_paso = 1
		_espera = 0.0
		print("Invocando %s en %s." % [VERDUGO, str(_estado_god.mi_pos)])
		_con_god.enviar_hablar("/m %s" % VERDUGO)
		return
	if _paso > 1:
		return
	# El spawn no es instantaneo y cada sesion lo ve cuando el servidor se lo
	# manda, asi que se espera en vez de mirar una sola vez.
	var visto := _verdugo_a_la_vista()
	if not visto and _espera < ESPERA_VERDUGO:
		return
	_comprobar("el servidor invoco al %s en el campo" % VERDUGO, visto)
	if not visto:
		_listar_criaturas()
	_paso = 2
	_espera = 0.0
	if _solo_campo:
		_cerrar_el_campo()
		return
	# El god se va: el demon no puede atacarlo —`Player::isAttackable` lo
	# rechaza por su flag de grupo— y su presencia no debe influir en lo que la
	# prueba mide.
	_god_saliendo = true
	_con_god.enviar_logout()
	_pasar_a("esperar la muerte")
	print("Campo listo. %s espera el duelo sin enviar nada." % PERSONAJE)


func _verdugo_a_la_vista() -> bool:
	## Las dos sesiones miran el mismo mundo autoritativo; alcanza con que una
	## haya recibido al verdugo.
	return _hay_criatura(VERDUGO, _estado_god) or _hay_criatura(VERDUGO, _estado)


func _listar_criaturas() -> void:
	print("  el god ve: %s" % str(_nombres_vistos(_estado_god)))
	print("  %s ve: %s" % [PERSONAJE, str(_nombres_vistos(_estado))])


func _nombres_vistos(estado) -> Array:
	var nombres: Array = []
	for id in estado.criaturas:
		nombres.append(str(estado.criaturas[id].get("nombre", "?")))
	return nombres


func _cerrar_el_campo() -> void:
	## Modo `--solo-campo`: se retira al verdugo antes de que mate a nadie.
	print("Modo precondicion: se retira al %s sin dejar morir a nadie." % VERDUGO)
	_con_god.enviar_hablar("/killall")
	_pasar_a("verificar campo limpio")


func _verificar_campo_limpio() -> void:
	if _espera < ESPERA_ORDEN:
		return
	_comprobar("la limpieza retira al %s antes del duelo" % VERDUGO,
		not _verdugo_a_la_vista())
	# El campo es campo abierto: ahi tambien hay bichos del mapa. El modo de
	# precondicion devuelve al personaje a su templo con `omani`, que es la
	# misma orden de servidor, en vez de dejarlo peleando afuera.
	print("Devolviendo a %s a su templo con omani." % PERSONAJE)
	_con_god.enviar_hablar("omani %s" % PERSONAJE)
	_pasar_a("devolver al templo")


func _devolver_al_templo() -> void:
	if _en_el_campo(_estado.mi_pos) and _espera <= ESPERA_TELEPORT:
		return
	print("%s quedo en %s." % [PERSONAJE, str(_estado.mi_pos)])
	_comprobar("el personaje sale del campo al terminar la precondicion",
		not _en_el_campo(_estado.mi_pos))
	_god_saliendo = true
	_con_god.enviar_logout()
	_etapa = "final"
	_terminar()


func _hay_criatura(nombre: String, estado = null) -> bool:
	var donde = _estado if estado == null else estado
	for id in donde.criaturas:
		if int(id) == donde.mi_id:
			continue
		var criatura: Dictionary = donde.criaturas[id]
		# Una criatura con vida autoritativa cero ya murio: puede seguir en el
		# diccionario porque salio del viewport antes de que la retiraran.
		if int(criatura.get("vida", 100)) <= 0:
			continue
		if str(criatura.get("nombre", "")).to_lower() == nombre:
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
	elif _fase == "matar":
		# El corpse aparece donde el monstruo termino de caminar, que no tiene
		# por que ser su ultima posicion conocida. Se acepta el que llega en un
		# evento de casilla de esta misma etapa y lleva el nombre del monstruo,
		# asi un corpse viejo del campo no se confunde con el de esta corrida.
		if _corpses_previos.has(posicion):
			return
		var cosa_m := _contenedor_en(posicion)
		if not cosa_m.is_empty() \
				and str(cosa_m.get("nombre", "")).to_lower().contains(MONSTRUO):
			_corpse_monstruo = cosa_m
			_pos_monstruo = posicion


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
	if not _estado.mapa_alineado:
		_comprobar("el mapa del personaje queda alineado para certificar su corpse",
			false)
	else:
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
		_error(("Nadie ataca a %s en %s, que es el campo al que lo llevo el"
			% [PERSONAJE, str(_estado.mi_pos)])
			+ " servidor. Revisa si esa casilla dejo de estar fuera de zona"
			+ " de proteccion o si el %s no llego a invocarse." % VERDUGO)


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
			# El duelo y la mitad de loot ocurren en la misma casilla de campo.
			_con.enviar_hablar("/gotopos %d,%d,%d" % [
				POS_CAMPO.x, POS_CAMPO.y, POS_CAMPO.z])
		2:
			if _solo_loot:
				return   # no hay verdugo que limpiar en la media prueba
			_demon_visible = _hay_criatura(VERDUGO)
			print("Limpiando el %s invocado para la prueba." % VERDUGO)
			_con.enviar_hablar("/killall")
		3:
			if not _solo_loot:
				# `/killall` solo alcanza el cuadro alrededor del god; si el
				# verdugo se movio, se insiste antes de darlo por fallado.
				if _hay_criatura(VERDUGO) and _intentos_limpieza < 3:
					_intentos_limpieza += 1
					_con.enviar_hablar("/killall")
					_paso = 2
					return
				if not _estado.mapa_alineado:
					_comprobar("el mapa del god queda alineado para certificar la limpieza",
						false)
				else:
					_comprobar("la limpieza retira al %s invocado" % VERDUGO,
						not _hay_criatura(VERDUGO))
			_ids_previos.clear()
			for id in _estado.criaturas:
				_ids_previos[int(id)] = true
			_corpses_previos.clear()
			for donde in _estado.casillas:
				if not _contenedor_en(donde).is_empty():
					_corpses_previos[donde] = true
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
			_inicio_matar = _reloj
			_pasar_a("matar")


func _buscar_monstruo() -> bool:
	for id in _estado.criaturas:
		if int(id) == _estado.mi_id or _ids_previos.has(int(id)):
			continue   # las ratas salvajes del campo no son la nuestra
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
	# `EstadoMundo` conserva a las criaturas que salen del viewport —por eso el
	# Battle List filtra por vista—, asi que un monstruo que huyo y murio lejos
	# se queda en el diccionario con su ultima vida autoritativa. Vida cero es
	# dato del servidor: ya no hay a quien rematar.
	if _estado.criaturas.has(_id_monstruo) \
			and int(_estado.criaturas[_id_monstruo].get("vida", 100)) > 0:
		_pos_monstruo = _estado.criaturas[_id_monstruo].get("pos", _pos_monstruo)
		if _reloj - _inicio_matar > ESPERA_CORPSE:
			_error("El %s sigue vivo en %s despues de %d segundos" % [
				MONSTRUO, str(_pos_monstruo), int(ESPERA_CORPSE)])
			return
		if _espera > 6.0:
			# El personaje god pega con los punyos; si tarda se remata con la
			# misma orden de servidor que ya limpio al verdugo, y se insiste
			# porque `/killall` solo alcanza el cuadro alrededor de quien lo
			# dice (`AREA_SQUARE1X1`) y el rat huye al quedar debil. El god no
			# se teletransporta encima del monstruo: ese empujon deja la
			# casilla en un estado que la prueba no sabe leer.
			_espera = 0.0
			print("Rematando al %s en %s: god en %s, vida %d%%." % [
				MONSTRUO, str(_pos_monstruo), str(_estado.mi_pos),
				int(_estado.criaturas[_id_monstruo].get("vida", -1))])
			_con.enviar_hablar("/killall")
		return
	if _corpse_monstruo.is_empty():
		# El monstruo pudo caminar antes de morir, asi que su corpse se busca
		# por nombre en todo lo que el cliente tiene a la vista: el campo
		# acumula restos de otras corridas y un `dead spider` no es el corpse
		# que esta prueba mide.
		for donde in _estado.casillas:
			if _corpses_previos.has(donde):
				continue   # resto de una corrida vieja, no el de esta caza
			var cosa := _contenedor_en(donde)
			if not cosa.is_empty() \
					and str(cosa.get("nombre", "")).to_lower().contains(MONSTRUO):
				_corpse_monstruo = cosa
				_pos_monstruo = donde
				break
	if _corpse_monstruo.is_empty() and not _god_fue_al_corpse \
			and _reloj - _inicio_matar > 25.0:
		# El monstruo pudo morir fuera de la vista del god. Se lo acerca a su
		# ultima posicion confirmada para que el servidor le mande esa casilla;
		# ahi ya no hay criatura que empujar, solo el corpse.
		_god_fue_al_corpse = true
		print("Acercando el god a %s para ver el corpse." % str(_pos_monstruo))
		_con.enviar_hablar("/gotopos %d,%d,%d" % [
			_pos_monstruo.x, _pos_monstruo.y, _pos_monstruo.z])
		return
	if _corpse_monstruo.is_empty():
		if _reloj - _inicio_matar > ESPERA_CORPSE:
			_error("El %s murio y no aparecio ningun corpse suyo a la vista"
				% MONSTRUO)
			return
		if _espera > 8.0:
			_espera = 0.0
			print("  sin corpse todavia cerca de %s" % str(_pos_monstruo))
			for cosa in _estado.casillas.get(_pos_monstruo, []):
				print("    pila: ", str(cosa.get("nombre", cosa.get("cid", "?"))))
		return
	print("El monstruo murio y dejo corpse en %s: %s" % [
		str(_pos_monstruo), str(_corpse_monstruo.get("nombre", ""))])
	_comprobar("el monstruo muerto deja un corpse contenedor",
		bool(_corpse_monstruo.get("contenedor", false)))
	# Usar un item del suelo exige estar al lado: si no, el servidor contesta
	# "Sorry, not possible.". El corpse no es criatura, asi que el god puede
	# pararse encima sin empujar a nadie.
	if absi(_estado.mi_pos.x - _pos_monstruo.x) > 1 \
			or absi(_estado.mi_pos.y - _pos_monstruo.y) > 1 \
			or _estado.mi_pos.z != _pos_monstruo.z:
		print("Acercando el god al corpse en %s." % str(_pos_monstruo))
		_con.enviar_hablar("/gotopos %d,%d,%d" % [
			_pos_monstruo.x, _pos_monstruo.y, _pos_monstruo.z])
		_pasar_a("acercarse al corpse")
		return
	_fase = "saquear"
	_abrir_corpse()


func _acercarse_al_corpse() -> void:
	if _espera < ESPERA_ORDEN:
		return
	_fase = "saquear"
	_abrir_corpse()


func _abrir_corpse() -> void:
	## La pila se recalcula: el 0x64 del acercamiento reescribe la casilla.
	var cosa := _contenedor_en(_pos_monstruo)
	if not cosa.is_empty():
		_corpse_monstruo = cosa
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


func _registrar_mapa_desalineado(personaje: String, detalle: Dictionary) -> void:
	var evidencia := {
		"personaje": personaje,
		"detalle": detalle.duplicate(true),
	}
	_mapas_desalineados.append(evidencia)
	print("  MAPA DESALINEADO %s: %s" % [personaje, str(detalle)])


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
	if _solo_campo:
		_comprobar("el servidor llevo al personaje al campo sin intervencion",
			_pos_duelo != Vector3i.ZERO and _en_el_campo(_pos_duelo))
	else:
		if not _solo_loot:
			_comprobar("el servidor emitio la muerte del jugador", _muerte_emitida)
			_comprobar("el cliente respondio con logout 0x14", _logout_enviado)
			_comprobar("el servidor corto la sesion tras el logout", _servidor_corto)
			_comprobar("el reingreso devolvio un personaje vivo",
				_vida_reentrada > 0)
		_comprobar("se abrio el corpse de un monstruo con su loot",
			not _nombre_corpse.is_empty())
	if _con != null:
		_con.cerrar()
	if _con_god != null:
		_god_saliendo = true
		_con_god.cerrar()
	if _fallas == 0:
		print("Prueba viva de muerte, corpse y loot: OK")
	else:
		print("Prueba viva de muerte, corpse y loot: %d fallas" % _fallas)
	get_tree().quit(1 if _fallas > 0 else 0)
