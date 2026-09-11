extends Node

# Regresion viva del parser legacy TVP 7.72: las identidades de criaturas
# conocidas deben sobrevivir a un refresco de mapa completo.
#
# QA-owned. NO es un oracle de paridad: no emite `OBSERVATION_JSON`, no usa
# `wrap_live_observation.py`, no crea `OracleObservationV1` ni ningun
# artefacto de paridad, y no toca
# `PARITY-MONSTER-REACQUISITION-001`.
#
# Que verifica exactamente
# ------------------------
# El defecto reparado en `78aaed5` era: el servidor mantiene su
# `knownCreatureSet` (`protocolgame.cpp:665-698`) y NO lo vacia cuando una
# criatura sale de la vista, pero `estado_mundo.gd` si vaciaba `criaturas`
# en cada `0x64`. Al reenviar la criatura como conocida (`0x62`, sin
# nombre), el cliente se quedaba sin de donde sacar el nombre y lo dejaba
# vacio.
#
# Esta prueba reproduce esa transicion con paquetes REALES:
#
#   1. el personaje aprende al god por primera vez  -> `0x61` CON nombre
#   2. un `/c` posterior fuerza un `0x64` de mapa completo, que vacia el
#      mundo visible del personaje
#   3. el servidor reenvia al god, que ya esta en su conjunto conocido, en
#      forma conocida SIN nombre                     -> `0x62`
#   4. el nombre debe seguir exacto y no vacio
#
# Por que el paso 3 es necesariamente forma conocida: `checkCreatureAsKnown`
# solo desaloja del conjunto conocido cuando este supera 150 entradas. La
# prueba comprueba que el conjunto se mantiene MUY por debajo de 150 y que
# nunca encoge, asi que no pudo haber desalojo y el segundo envio no pudo
# ser un `0x61` nuevo.
#
# Mutacion: solo `/gotopos` y `/c`. Sin invocar, sin atacar, sin `/killall`,
# sin muerte, sin tocar inventario ni persistencia.
#
# Credenciales: exclusivamente por entorno, nunca literales, nunca impresas:
#   TVP772_ACCOUNT
#   TVP772_PASSWORD
#   TVP772_GOD_CHARACTER
#   TVP772_PLAYER_CHARACTER
# Opcionales: TVP772_HOST, TVP772_LOGIN_PORT
#
#   ...Godot --headless --path cliente3d pruebas/prueba_known_creature_identity_live.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST_DEFECTO := "127.0.0.1"
const PUERTO_LOGIN_DEFECTO := 7171
## Par operativo aislado y colocable, probado en Phase 2C.2. Son coordenadas
## de operacion de QA: no entran en ningun artefacto de paridad.
const POS_A := Vector3i(32008, 32400, 7)
const POS_B := Vector3i(32008, 32339, 7)
const RADIO_LLEGADA := 2
## Tope del servidor antes de desalojar del conjunto conocido
## (`protocolgame.cpp:675`). Si el conjunto local nunca se acerca a esto, no
## pudo haber desalojo y un reenvio tiene que haber sido forma conocida.
const TOPE_CONOCIDOS_SERVIDOR := 150

const PAUSA_SESION := 6.0
const ESPERA_PASO := 20.0
const LIMITE_TOTAL := 240.0

var _con_login
var _con_god
var _con_jugador
var _estado_god
var _estado_jugador
var _puertos := {}
var _fase := "login"
var _espera := 0.0
var _total := 0.0
var _terminando := false
var _fallas := 0

var _cuenta := 0
var _clave := ""
var _personaje_god := ""
var _personaje_jugador := ""
var _host := HOST_DEFECTO
var _puerto_login := PUERTO_LOGIN_DEFECTO

var _god_id := 0
var _god_nombre := ""
var _jugador_id := 0
var _jugador_nombre := ""
var _mapas_completos := 0
var _mapas_al_aprender := 0
var _ausentes: Array = []
var _tam_conocidos_maximo := 0
var _tam_conocidos_al_aprender := 0
var _hubo_encogimiento := false
var _tam_conocidos_previo := 0


func _comprobar(nombre: String, correcto: bool) -> void:
	if correcto:
		print("  OK  " + nombre)
	else:
		print("  FAIL " + nombre)
		_fallas += 1


func _ready() -> void:
	print("=================================================")
	print(" TVP3D QA - regresion viva de identidades conocidas")
	print("=================================================")
	var falta := _resolver_credenciales()
	if not falta.is_empty():
		print("BLOCKED missing environment variable %s" % falta)
		get_tree().quit(2)
		return
	_abrir_login()


func _resolver_credenciales() -> String:
	var cuenta_texto := OS.get_environment("TVP772_ACCOUNT")
	if cuenta_texto.is_empty() or not cuenta_texto.is_valid_int():
		return "TVP772_ACCOUNT"
	_cuenta = int(cuenta_texto)
	_clave = OS.get_environment("TVP772_PASSWORD")
	if _clave.is_empty():
		return "TVP772_PASSWORD"
	_personaje_god = OS.get_environment("TVP772_GOD_CHARACTER")
	if _personaje_god.is_empty():
		return "TVP772_GOD_CHARACTER"
	_personaje_jugador = OS.get_environment("TVP772_PLAYER_CHARACTER")
	if _personaje_jugador.is_empty():
		return "TVP772_PLAYER_CHARACTER"
	var host_env := OS.get_environment("TVP772_HOST")
	if not host_env.is_empty():
		_host = host_env
	var puerto_env := OS.get_environment("TVP772_LOGIN_PORT")
	if not puerto_env.is_empty() and puerto_env.is_valid_int():
		_puerto_login = int(puerto_env)
	return ""


func _process(delta: float) -> void:
	_total += delta
	_espera += delta
	if _terminando:
		return
	if _total > LIMITE_TOTAL:
		_fallar("FAIL tiempo agotado en la fase '%s'" % _fase)
		return
	if _estado_jugador != null:
		var tam: int = _estado_jugador.identidades_conocidas.size()
		_tam_conocidos_maximo = maxi(_tam_conocidos_maximo, tam)
		if tam < _tam_conocidos_previo:
			_hubo_encogimiento = true
		_tam_conocidos_previo = tam
	match _fase:
		"esperar god":
			if _estado_god != null and _estado_god.adentro and _espera > 2.0:
				_pasar_a("pausa segundo cliente")
		"pausa segundo cliente":
			if _espera >= PAUSA_SESION:
				_abrir_jugador()
		"esperar jugador":
			if _estado_jugador != null and _estado_jugador.adentro and _espera > 2.0:
				_god_al_punto(POS_A, "esperar god en A")
		"esperar god en A":
			_esperar_god_en(POS_A, "reunir en A")
		"reunir en A":
			_reunir_en(POS_A, "aprender identidad")
		"aprender identidad":
			_aprender_identidad()
		"mover god a B":
			_god_al_punto(POS_B, "esperar god en B")
		"esperar god en B":
			_esperar_god_en(POS_B, "reunir en B")
		"reunir en B":
			_reunir_en(POS_B, "verificar tras refresco")
		"verificar tras refresco":
			_verificar_tras_refresco()
		"devolver templo":
			_devolver_al_templo()
		"esperar salida":
			_esperar_salida()


# -----------------------------------------------------------------
#  Sesiones
# -----------------------------------------------------------------
func _abrir_login() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.error_red.connect(func(t): _fallar("FAIL fallo de red en login: %s" % t))
	_con_login.lista_personajes.connect(_al_lista)
	_con_login.pedir_personajes(_host, _puerto_login, _cuenta, _clave)


func _al_lista(_motd: String, personajes: Array) -> void:
	for entrada in personajes:
		_puertos[str(entrada.get("nombre", ""))] = int(entrada.get("puerto", 0))
	if int(_puertos.get(_personaje_god, 0)) <= 0:
		_fallar("FAIL character configured by TVP772_GOD_CHARACTER was not found")
		return
	if int(_puertos.get(_personaje_jugador, 0)) <= 0:
		_fallar("FAIL character configured by TVP772_PLAYER_CHARACTER was not found")
		return
	_con_login.cerrar()
	_con_login.queue_free()
	_con_login = null
	_abrir_god()


func _abrir_god() -> void:
	_estado_god = ESTADO.new()
	_estado_god.pedido_ping.connect(func(): _con_god.enviar_juego(PackedByteArray([0x1E])))
	_estado_god.mensaje_servidor.connect(func(t): print("  [god] ", t))
	_estado_god.rechazados.connect(func(m): _fallar("FAIL el god fue rechazado: %s" % m))
	_con_god = CONEXION.new()
	add_child(_con_god)
	_con_god.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red del god: %s" % t))
	_con_god.paquete_juego.connect(func(m): _estado_god.procesar(m))
	_con_god.entrar_al_mundo(_host, int(_puertos[_personaje_god]), _cuenta, _personaje_god, _clave)
	_pasar_a("esperar god")


func _abrir_jugador() -> void:
	_estado_jugador = ESTADO.new()
	_estado_jugador.pedido_ping.connect(func(): _con_jugador.enviar_juego(PackedByteArray([0x1E])))
	_estado_jugador.rechazados.connect(func(m): _fallar("FAIL el personaje fue rechazado: %s" % m))
	## Cada `0x64` de mapa completo emite esto: es la prueba de que hubo un
	## refresco que vacia el mundo visible del personaje.
	_estado_jugador.mapa_recibido.connect(func(_pos): _mapas_completos += 1)
	## Si el parser recibe una forma conocida cuyo id no puede resolver,
	## avisa aca. En una corrida valida no debe dispararse nunca.
	_estado_jugador.identidad_conocida_ausente.connect(func(detalle):
		_ausentes.append({
			"id": int(detalle.get("id", 0)),
			"forma": str(detalle.get("forma", "?")),
		}))
	_con_jugador = CONEXION.new()
	add_child(_con_jugador)
	_con_jugador.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red del personaje: %s" % t))
	_con_jugador.paquete_juego.connect(func(m): _estado_jugador.procesar(m))
	_con_jugador.entrar_al_mundo(_host, int(_puertos[_personaje_jugador]), _cuenta,
		_personaje_jugador, _clave)
	_pasar_a("esperar jugador")


# -----------------------------------------------------------------
#  Recorrido
# -----------------------------------------------------------------
func _god_al_punto(destino: Vector3i, siguiente: String) -> void:
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [destino.x, destino.y, destino.z])
	_pasar_a(siguiente)


func _esperar_god_en(destino: Vector3i, siguiente: String) -> void:
	if _estado_god.mi_pos == destino:
		_pasar_a(siguiente)
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL el god no llego a %s a tiempo" % str(destino))


func _reunir_en(destino: Vector3i, siguiente: String) -> void:
	if _cerca(_estado_jugador.mi_pos, destino):
		_pasar_a(siguiente)
		return
	if _espera < 0.2:
		return
	if _espera < 0.5:
		_con_god.enviar_hablar("/c %s" % _personaje_jugador)
	if _espera > ESPERA_PASO:
		_fallar("FAIL /c no acerco al personaje a %s a tiempo" % str(destino))


## Primer aprendizaje: el personaje ve al god por primera vez, asi que el
## servidor lo manda como desconocido (`0x61`) CON nombre.
func _aprender_identidad() -> void:
	var id := _buscar_god_visible()
	if id == 0:
		if _espera > ESPERA_PASO:
			_fallar("FAIL el personaje nunca vio al god en A")
		return
	_god_id = id
	_god_nombre = str(_estado_jugador.criaturas[id].get("nombre", ""))
	_jugador_id = int(_estado_jugador.mi_id)
	if _estado_jugador.criaturas.has(_jugador_id):
		_jugador_nombre = str(_estado_jugador.criaturas[_jugador_id].get("nombre", ""))
	_mapas_al_aprender = _mapas_completos
	_tam_conocidos_al_aprender = _estado_jugador.identidades_conocidas.size()

	print("Identidad aprendida en A (id relacion-only, nombre no vacio=%s)."
		% str(_god_nombre != ""))
	_comprobar("el personaje aprendio el nombre del god con la forma completa",
		_god_nombre != "")
	_comprobar("la identidad quedo en el conjunto conocido del parser",
		_estado_jugador.identidades_conocidas.has(_god_id)
		and str(_estado_jugador.identidades_conocidas[_god_id]) == _god_nombre)
	if _fallas > 0:
		_terminar(1)
		return
	_pasar_a("mover god a B")


## Tras el refresco: el mundo visible del personaje se vacio con un `0x64` y
## el servidor reenvio al god, que YA estaba en su conjunto conocido, en
## forma conocida sin nombre.
func _verificar_tras_refresco() -> void:
	var id := _buscar_god_visible()
	if id == 0:
		if _espera > ESPERA_PASO:
			_fallar("FAIL el god no volvio a ser visible para el personaje tras el refresco")
		return

	var nombre := str(_estado_jugador.criaturas[id].get("nombre", ""))
	var hubo_refresco := _mapas_completos > _mapas_al_aprender

	print("Tras el refresco: mapas completos=%d (antes %d), nombre no vacio=%s"
		% [_mapas_completos, _mapas_al_aprender, str(nombre != "")])

	_comprobar("hubo al menos un refresco de mapa completo (0x64) despues de aprender",
		hubo_refresco)
	_comprobar("el mismo runtime id volvio a estar visible", id == _god_id)
	_comprobar("el nombre no quedo vacio tras el refresco", nombre != "")
	_comprobar("el nombre es exactamente el aprendido antes", nombre == _god_nombre)
	_comprobar("el conjunto conocido sigue mapeando ese id al mismo nombre",
		_estado_jugador.identidades_conocidas.get(_god_id, "") == _god_nombre)

	# Sin desalojo posible => el reenvio fue forma conocida, no un 0x61 nuevo.
	_comprobar("el conjunto conocido nunca se acerco al tope del servidor (%d)"
		% TOPE_CONOCIDOS_SERVIDOR,
		_tam_conocidos_maximo < TOPE_CONOCIDOS_SERVIDOR)
	_comprobar("el conjunto conocido nunca encogio: no hubo desalojo",
		not _hubo_encogimiento)

	# El propio personaje, si su parser lo representa como criatura.
	if _jugador_nombre != "":
		var propio := str(_estado_jugador.criaturas.get(_jugador_id, {}).get("nombre", ""))
		_comprobar("el propio personaje tampoco perdio su nombre",
			propio == _jugador_nombre)

	_comprobar("ningun aviso de identidad conocida ausente",
		_ausentes.is_empty())
	if not _ausentes.is_empty():
		print("  avisos: %s" % str(_ausentes))

	_pasar_a("devolver templo")


func _buscar_god_visible() -> int:
	for id in _estado_jugador.criaturas:
		if int(id) == _estado_jugador.mi_id:
			continue
		var criatura: Dictionary = _estado_jugador.criaturas[id]
		if _god_id != 0:
			if int(id) == _god_id:
				return int(id)
			continue
		# Primer aprendizaje: el god es la unica otra criatura esperada en
		# este terreno aislado, y debe llegar con nombre.
		if str(criatura.get("nombre", "")) != "":
			return int(id)
	return 0


func _devolver_al_templo() -> void:
	if _espera < 1.0:
		return
	_con_god.enviar_hablar("omani %s" % _personaje_jugador)
	_pasar_a("esperar salida")


func _esperar_salida() -> void:
	if not _cerca(_estado_jugador.mi_pos, POS_B):
		_terminar(1 if _fallas > 0 else 0)
		return
	if _espera > ESPERA_PASO:
		# No poder devolverlo no invalida la medicion del parser.
		print("  aviso: no se confirmo la salida del campo a tiempo")
		_terminar(1 if _fallas > 0 else 0)


# -----------------------------------------------------------------
#  Utilidades
# -----------------------------------------------------------------
func _cerca(posicion: Vector3i, centro: Vector3i) -> bool:
	return posicion.z == centro.z \
		and absi(posicion.x - centro.x) <= RADIO_LLEGADA \
		and absi(posicion.y - centro.y) <= RADIO_LLEGADA


func _pasar_a(fase: String) -> void:
	print("  [%.0fs] fase: %s" % [_total, fase])
	_fase = fase
	_espera = 0.0


func _fallar(texto: String) -> void:
	print(texto)
	_fallas += 1
	_terminar(1)


func _terminar(codigo: int) -> void:
	if _terminando:
		return
	_terminando = true
	if _con_god != null:
		_con_god.cerrar()
	if _con_jugador != null:
		_con_jugador.cerrar()
	if codigo == 0 and _fallas == 0:
		print("Regresion viva de identidades conocidas: OK")
	else:
		print("Regresion viva de identidades conocidas: %d fallas" % maxi(_fallas, 1))
	get_tree().quit(codigo)
