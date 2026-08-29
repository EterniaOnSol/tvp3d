extends Node

## Prueba viva de permisos y ciclo de cama contra TVP 7.72.
## La casa 6 (Sunset Homes, Flat 01) tiene camas reales en z7.

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const HOST := "127.0.0.1"
const CUENTA := 123456
const CLAVE := "123456"
const GOD := "GOD VALENTINO"
const JUGADOR := GOD
const CASA := 6
const ENTRADA := Vector3i(32333, 32232, 7)
const INTERIOR := Vector3i(32331, 32230, 7)
const CAMA := Vector3i(32329, 32230, 7)

var _login
var _con
var _estado
var _puerto := 0
var _fase := "login god"
var _tiempo := 0.0
var _espera := 0.0
var _fallas := 0
var _terminando := false
var _durmio := false
var _desperto := false
var _limpio := false

func _ready() -> void:
	_abrir_login(GOD)

func _process(delta: float) -> void:
	_tiempo += delta
	_espera += delta
	if _terminando:
		return
	if _tiempo > 180.0:
		_fallar("timeout en fase %s" % _fase)

func _abrir_login(nombre: String) -> void:
	_login = CONEXION.new()
	add_child(_login)
	_login.error_red.connect(func(t): _fallar("login: " + t))
	_login.lista_personajes.connect(func(_motd, personajes):
		_puerto = 0
		for p in personajes:
			if str(p.get("nombre", "")) == nombre:
				_puerto = int(p.get("puerto", 0))
		if _puerto <= 0:
			_fallar("no encontre %s" % nombre)
			return
		_login.cerrar()
		_login.queue_free()
		_login = null
		_entrar(nombre))
	_login.pedir_personajes(HOST, 7171, CUENTA, CLAVE)

func _entrar(nombre: String) -> void:
	_estado = ESTADO.new()
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(func(t): _fallar("red: " + t))
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.cerrada.connect(_al_cerrarse)
	_estado.entramos.connect(func(): _con.enviar_modos_combate(1, 1, 1))
	_estado.mapa_recibido.connect(_al_mapa)
	_estado.cambio.connect(func(): _al_mapa(_estado.mi_pos))
	_estado.mensaje_servidor.connect(func(t): print("  [srv] ", t))
	_con.entrar_al_mundo(HOST, _puerto, CUENTA, nombre, CLAVE)
	_espera = 0.0

func _al_mapa(_pos: Vector3i) -> void:
	print("MAPA fase=%s pos=%s casillas=%d" % [_fase, _estado.mi_pos, _estado.casillas.size()])
	if _fase == "login god":
		_fase = "ir god casa"
		_con.enviar_hablar("/gotohouse %d" % CASA)
		if _estado.mi_pos.distance_to(ENTRADA) <= 2.0:
			_enviar_interior_despues()
		return
	if _fase == "ir god casa":
		if _estado.mi_pos.distance_to(ENTRADA) > 2.0:
			return
		_fase = "asignar casa"
		_enviar_interior_despues()
		return
	if _fase == "entrar jugador":
		_fase = "ir jugador casa"
		_con.enviar_hablar("/gotohouse %d" % CASA)
		return
	if _fase == "ir jugador casa":
		if not _estado.casillas.has(CAMA):
			return
		var pila := 0
		var cama_cid := 0
		for item in _estado.casillas[CAMA]:
			if str(item.get("nombre", "")).to_lower() == "bed":
				cama_cid = int(item.get("cid", 0))
				break
			pila += 1
		if cama_cid == 0:
			_fallar("la cama no tiene client id: %s" % _estado.casillas[CAMA])
			return
		print("Usando cama real en %s (cid %d, pila %d)." % [CAMA, cama_cid, pila])
		_con.enviar_usar_item(CAMA, cama_cid, pila, 0)
		_fase = "esperar sueño"
		_espera = 0.0
		return
	if _fase == "despertar jugador":
		_desperto = _estado.mi_pos == ENTRADA or _estado.mi_pos.distance_to(ENTRADA) <= 1.0
		_comprobar("reconectar despierta y vuelve a la entrada", _desperto,
			"posicion=%s entrada=%s" % [_estado.mi_pos, ENTRADA])
		_fase = "salir jugador"
		_con.enviar_logout()
		return
	if _fase == "limpiar god":
		_fase = "ir limpieza casa"
		_con.enviar_hablar("/gotohouse %d" % CASA)
		return
	if _fase == "ir limpieza casa":
		if _estado.mi_pos.distance_to(ENTRADA) > 2.0:
			return
		_fase = "limpiar casa"
		_con.enviar_hablar("/gotopos %d,%d,%d" % [INTERIOR.x, INTERIOR.y, INTERIOR.z])
		_limpiar_owner_despues()
		return

func _al_cerrarse() -> void:
	if _terminando:
		return
	if _fase == "asignar casa":
		# Cierre despues de asignar: abrir al propietario.
		_con.queue_free()
		_con = null
		_fase = "entrar jugador"
		_abrir_login(JUGADOR)
		return
	if _fase == "esperar sueño":
		_durmio = true
		print("Servidor expulso al personaje dormido; reconectando.")
		_con.queue_free()
		_con = null
		_fase = "despertar jugador"
		_abrir_login(JUGADOR)
		return
	if _fase == "salir jugador":
		_con.queue_free()
		_con = null
		_fase = "limpiar god"
		_abrir_login(GOD)
		return
	if _fase == "salir limpieza":
		_terminar()

func _enviar_owner_despues() -> void:
	await get_tree().create_timer(1.0).timeout
	if _terminando:
		return
	_fase = "asignar casa"
	_con.enviar_hablar("/addpremiumdays %s,1" % JUGADOR)
	await get_tree().create_timer(1.0).timeout
	if _terminando:
		return
	_con.enviar_hablar("/owner %s" % JUGADOR)
	await get_tree().create_timer(1.0).timeout
	if _terminando:
		return
	_con.enviar_logout()

func _enviar_interior_despues() -> void:
	await get_tree().create_timer(1.0).timeout
	if _terminando:
		return
	_con.enviar_hablar("/gotopos %d,%d,%d" % [INTERIOR.x, INTERIOR.y, INTERIOR.z])
	await get_tree().create_timer(1.0).timeout
	if _terminando:
		return
	_enviar_owner_despues()

func _limpiar_owner_despues() -> void:
	await get_tree().create_timer(1.0).timeout
	if _terminando:
		return
	_con.enviar_hablar("/owner none")
	_fase = "salir limpieza"
	_con.enviar_logout()

func _physics_process(_delta: float) -> void:
	if _terminando:
		return
	if _fase == "ir jugador casa" and _espera > 20.0:
		_fallar("el jugador no recibio mapa")
	elif _fase == "despertar jugador" and _espera > 20.0:
		_fallar("el jugador no reconecto")

func _unhandled_key_input(_event: InputEvent) -> void:
	pass

func _fallar(texto: String) -> void:
	if _terminando:
		return
	_fallas += 1
	printerr("FALLO [%s]: %s" % [_fase, texto])
	_terminar()

func _comprobar(nombre: String, ok: bool, detalle: String = "") -> void:
	if ok:
		print("  OK  %s" % nombre)
	else:
		_fallas += 1
		print("  FAIL %s: %s" % [nombre, detalle])

func _terminar() -> void:
	if _terminando:
		return
	_terminando = true
	if _con != null:
		_con.cerrar()
	if _fallas == 0 and _durmio and _desperto:
		print("Prueba viva de casa y cama: OK")
	else:
		print("Prueba viva de casa y cama: %d fallas" % _fallas)
	get_tree().quit(1 if _fallas > 0 else 0)
