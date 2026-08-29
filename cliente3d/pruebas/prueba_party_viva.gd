extends Node

# Prueba viva de party contra el servidor TVP 7.72, con dos sesiones reales.
#
# Esta rama no manda ningun paquete de party: lo unico observable es el escudo
# de cada criatura por el `0x91` (`servidor/src/party.cpp:39-268`). Por eso la
# prueba no comprueba una lista de miembros, que seria inventada, sino que los
# escudos de los DOS lados cuentan la misma party en cada paso.
#
#   1. Entran el god y el personaje, y el god trae al personaje con `/c`.
#   2. El god invita  (0xA3): el god ve escudo 2 en el otro, el otro ve 1.
#   3. El personaje se une (0xA4): el god queda lider (4) y el otro miembro (3).
#   4. El god pasa el liderazgo (0xA6): los dos escudos se dan vuelta.
#   5. El god sale (0xA7): la party queda deshecha y los escudos vuelven a 0.
#
# No mata a nadie, no mueve objetos y no le cuesta un nivel a ningun personaje.
#
#   ...Godot --headless --path cliente3d pruebas/prueba_party_viva.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
const CUENTA := 123456
const CLAVE := "123456"
const PERSONAJE_GOD := "GOD VALENTINO"
const PERSONAJE := "Valentino"

## `Ban::acceptConnection` (servidor/src/ban.cpp:13-45) bloquea a quien abre
## mas de cinco conexiones en cinco segundos desde la misma IP.
const PAUSA_SESION := 6.0
const LIMITE_TOTAL := 180.0
const ESPERA_PASO := 8.0

# Escudos de `PartyShields_t` (servidor/src/const.h:187-193).
const SIN_ESCUDO := 0
const INVITACION_RECIBIDA := 1   # SHIELD_WHITEYELLOW
const INVITACION_ENVIADA := 2    # SHIELD_WHITEBLUE
const MIEMBRO := 3               # SHIELD_BLUE
const LIDER := 4                 # SHIELD_YELLOW

var _con_login
var _con_god
var _con_personaje
var _estado_god
var _estado_personaje
var _puertos := {}
var _fase := "login"
var _espera := 0.0
var _total := 0.0
var _fallas := 0
var _terminando := false
var _id_personaje := 0
var _id_god := 0


func _ready() -> void:
	print("=================================================")
	print(" TVP3D - prueba viva de party con dos clientes")
	print("=================================================")
	_abrir_login()


func _process(delta: float) -> void:
	_total += delta
	_espera += delta
	if _terminando:
		return
	if _total > LIMITE_TOTAL:
		_error("Tiempo agotado en la fase '%s'" % _fase)
		_terminar()
		return
	match _fase:
		"esperar god":
			if _estado_god != null and _estado_god.adentro and _espera > 2.0:
				_pasar_a("pausa segundo cliente")
		"pausa segundo cliente":
			if _espera >= PAUSA_SESION:
				_abrir_personaje()
		"esperar personaje":
			if _estado_personaje != null and _estado_personaje.adentro \
					and _espera > 2.0:
				_reunir()
		"esperar reunion":
			_verificar_reunion()
		"esperar invitacion":
			_verificar_invitacion()
		"esperar union":
			_verificar_union()
		"esperar liderazgo":
			_verificar_liderazgo()
		"esperar salida":
			_verificar_salida()
		"salir":
			if _espera > 6.0:
				_espera = 0.0
				_con_god.enviar_logout()
				_con_personaje.enviar_logout()


# -----------------------------------------------------------------
#  Sesiones
# -----------------------------------------------------------------
func _abrir_login() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.error_red.connect(func(texto): _error("Login: " + texto))
	_con_login.lista_personajes.connect(_al_lista)
	_con_login.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _al_lista(_motd: String, personajes: Array) -> void:
	for entrada in personajes:
		_puertos[str(entrada.get("nombre", ""))] = int(entrada.get("puerto", 0))
	if int(_puertos.get(PERSONAJE_GOD, 0)) <= 0 \
			or int(_puertos.get(PERSONAJE, 0)) <= 0:
		_error("La cuenta no tiene los dos personajes de la prueba")
		_terminar()
		return
	_con_login.cerrar()
	_con_login.queue_free()
	_con_login = null
	_abrir_god()


func _abrir_god() -> void:
	_estado_god = ESTADO.new()
	_estado_god.pedido_ping.connect(func():
		_con_god.enviar_juego(PackedByteArray([0x1E])))
	_estado_god.mensaje_servidor.connect(func(texto): print("  [god] ", texto))
	_con_god = CONEXION.new()
	add_child(_con_god)
	_con_god.error_red.connect(func(texto): _error("God: " + texto))
	_con_god.paquete_juego.connect(func(msg): _estado_god.procesar(msg))
	_con_god.entrar_al_mundo(HOST, int(_puertos[PERSONAJE_GOD]), CUENTA,
		PERSONAJE_GOD, CLAVE)
	_pasar_a("esperar god")


func _abrir_personaje() -> void:
	_estado_personaje = ESTADO.new()
	_estado_personaje.pedido_ping.connect(func():
		_con_personaje.enviar_juego(PackedByteArray([0x1E])))
	_estado_personaje.mensaje_servidor.connect(func(texto):
		print("  [%s] " % PERSONAJE, texto))
	_con_personaje = CONEXION.new()
	add_child(_con_personaje)
	_con_personaje.error_red.connect(func(texto):
		_error("%s: %s" % [PERSONAJE, texto]))
	_con_personaje.paquete_juego.connect(func(msg):
		_estado_personaje.procesar(msg))
	_con_personaje.entrar_al_mundo(HOST, int(_puertos[PERSONAJE]), CUENTA,
		PERSONAJE, CLAVE)
	_pasar_a("esperar personaje")


# -----------------------------------------------------------------
#  Recorrido
# -----------------------------------------------------------------
func _reunir() -> void:
	# `/c` es del propio servidor: trae a la criatura a la casilla libre mas
	# cercana a quien lo dice. El cliente no camina ni decide nada.
	print("El god trae a %s con /c." % PERSONAJE)
	_con_god.enviar_hablar("/c %s" % PERSONAJE)
	_pasar_a("esperar reunion")


func _verificar_reunion() -> void:
	_id_personaje = _buscar_id(_estado_god, PERSONAJE)
	_id_god = _buscar_id(_estado_personaje, PERSONAJE_GOD)
	if _id_personaje > 0 and _id_god > 0:
		print("Se ven: %s es %d para el god, y el god es %d para %s." % [
			PERSONAJE, _id_personaje, _id_god, PERSONAJE])
		_comprobar("las dos sesiones ven a la otra criatura", true)
		_comprobar("nadie empieza con escudo de party",
			_escudo(_estado_god, _id_personaje) == SIN_ESCUDO
			and _escudo(_estado_personaje, _id_god) == SIN_ESCUDO)
		print("El god invita a %s (0xA3)." % PERSONAJE)
		_con_god.enviar_invitar_a_party(_id_personaje)
		_pasar_a("esperar invitacion")
		return
	if _espera > ESPERA_PASO:
		_error("Las dos sesiones no llegaron a verse: god ve %d, %s ve %d"
			% [_id_personaje, PERSONAJE, _id_god])


func _verificar_invitacion() -> void:
	var visto_por_god := _escudo(_estado_god, _id_personaje)
	var visto_por_otro := _escudo(_estado_personaje, _id_god)
	if visto_por_god == INVITACION_ENVIADA \
			and visto_por_otro == INVITACION_RECIBIDA:
		_comprobar("el que invita ve la invitacion enviada", true)
		_comprobar("el invitado ve la invitacion recibida", true)
		print("%s se une (0xA4)." % PERSONAJE)
		_con_personaje.enviar_unirse_a_party(_id_god)
		_pasar_a("esperar union")
		return
	if _espera > ESPERA_PASO:
		_error("La invitacion no llego a los escudos: god ve %d, %s ve %d"
			% [visto_por_god, PERSONAJE, visto_por_otro])


func _verificar_union() -> void:
	var god_ve_al_otro := _escudo(_estado_god, _id_personaje)
	var otro_ve_al_god := _escudo(_estado_personaje, _id_god)
	var god_se_ve := _escudo(_estado_god, _estado_god.mi_id)
	var otro_se_ve := _escudo(_estado_personaje, _estado_personaje.mi_id)
	if god_ve_al_otro == MIEMBRO and otro_ve_al_god == LIDER:
		_comprobar("el lider ve al otro como miembro", true)
		_comprobar("el miembro ve al otro como lider", true)
		_comprobar("el lider se ve a si mismo como lider",
			god_se_ve == LIDER, "se ve %d" % god_se_ve)
		_comprobar("el miembro se ve a si mismo como miembro",
			otro_se_ve == MIEMBRO, "se ve %d" % otro_se_ve)
		print("El god le pasa el liderazgo a %s (0xA6)." % PERSONAJE)
		_con_god.enviar_pasar_liderazgo_party(_id_personaje)
		_pasar_a("esperar liderazgo")
		return
	if _espera > ESPERA_PASO:
		_error("La union no llego a los escudos: god ve %d, %s ve %d"
			% [god_ve_al_otro, PERSONAJE, otro_ve_al_god])


func _verificar_liderazgo() -> void:
	var god_ve_al_otro := _escudo(_estado_god, _id_personaje)
	var otro_ve_al_god := _escudo(_estado_personaje, _id_god)
	if god_ve_al_otro == LIDER and otro_ve_al_god == MIEMBRO:
		_comprobar("pasar el liderazgo da vuelta los dos escudos", true)
		_comprobar("el que lo cedio se ve como miembro",
			_escudo(_estado_god, _estado_god.mi_id) == MIEMBRO)
		print("El god sale de la party (0xA7).")
		_con_god.enviar_salir_de_party()
		_pasar_a("esperar salida")
		return
	if _espera > ESPERA_PASO:
		_error("El liderazgo no cambio los escudos: god ve %d, %s ve %d"
			% [god_ve_al_otro, PERSONAJE, otro_ve_al_god])


func _verificar_salida() -> void:
	var god_ve_al_otro := _escudo(_estado_god, _id_personaje)
	var god_se_ve := _escudo(_estado_god, _estado_god.mi_id)
	var otro_se_ve := _escudo(_estado_personaje, _estado_personaje.mi_id)
	if god_ve_al_otro == SIN_ESCUDO and god_se_ve == SIN_ESCUDO \
			and otro_se_ve == SIN_ESCUDO:
		_comprobar("al salir el ultimo miembro la party se deshace", true)
		_comprobar("ninguno de los dos conserva escudo", true)
		_terminar()
		return
	if _espera > ESPERA_PASO:
		_error("Los escudos no volvieron a cero: god se ve %d y ve %d, %s se ve %d"
			% [god_se_ve, god_ve_al_otro, PERSONAJE, otro_se_ve])


# -----------------------------------------------------------------
#  Utilidades
# -----------------------------------------------------------------
func _buscar_id(estado, nombre: String) -> int:
	if estado == null:
		return 0
	for id in estado.criaturas:
		if int(id) == estado.mi_id:
			continue
		if str(estado.criaturas[id].get("nombre", "")) == nombre:
			return int(id)
	return 0


func _escudo(estado, id: int) -> int:
	if estado == null:
		return -1
	return int(estado.criaturas.get(id, {}).get("escudo_party", -1))


func _pasar_a(fase: String) -> void:
	print("  [%.0fs] fase: %s" % [_total, fase])
	_fase = fase
	_espera = 0.0


func _comprobar(nombre: String, correcto: bool, detalle: String = "") -> void:
	if correcto:
		print("  OK  %s" % nombre)
	else:
		_fallas += 1
		print("  FAIL %s%s" % [nombre, "" if detalle.is_empty() else ": " + detalle])


func _error(texto: String) -> void:
	print("  FAIL " + texto)
	_fallas += 1
	_terminar()


func _terminar() -> void:
	if _terminando:
		return
	_terminando = true
	print("--- resumen ---")
	_comprobar("la party se armo y se deshizo mirando solo los escudos",
		_fallas == 0)
	if _con_god != null:
		_con_god.enviar_salir_de_party()
		_con_god.cerrar()
	if _con_personaje != null:
		_con_personaje.enviar_salir_de_party()
		_con_personaje.cerrar()
	if _fallas == 0:
		print("Prueba viva de party: OK")
	else:
		print("Prueba viva de party: %d fallas" % _fallas)
	get_tree().quit(1 if _fallas > 0 else 0)
