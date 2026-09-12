extends Node

# ---------------------------------------------------------------------------
# TVP3D QA - RECONOCIMIENTO DE UN LIMITE DE CASA (solo lectura)
# ---------------------------------------------------------------------------
#
# Herramienta de CALIFICACION, no de medicion. No afirma nada de paridad y no
# produce ninguna observacion: solo pregunta al servidor que ve en un area, y
# lo imprime, para poder ELEGIR con datos una casa de sandbox y su limite.
#
# Nace de un tropiezo concreto y repetido: en `PARITY-DEPOT-PERSISTENCE-001` la
# casilla historica resulto no ser caminable para un jugador normal, y en
# `PARITY-HOUSE-ACCESS-001` el limite de la casa se busco a ciegas, probando
# vecinas una por una hasta que alguna contestara. Las dos veces se gastaron
# intentos en aprender geografia que el servidor podia contestar de una.
#
# ---------------------------------------------------------------------------
# POR QUE ES SEGURA
# ---------------------------------------------------------------------------
#
# Usa `/tileinfo x,y,z` (`data/scripts/talkactions/god/tile_info.lua`), que es
# un diagnostico de SOLO LECTURA: mira la casilla y manda texto de vuelta. No
# mueve, no crea, no borra y no cambia propiedad ni listas. El operador ni
# siquiera se desplaza, porque `/tileinfo` acepta la posicion por parametro.
#
# 0 mutaciones, 0 items, 0 muertes, 0 combate, 0 monstruos.
#
# ---------------------------------------------------------------------------
# QUE CONTESTA, Y POR QUE IMPORTA
# ---------------------------------------------------------------------------
#
#   house=<id>|no   si la casilla pertenece a una casa, y a CUAL. El cliente
#                   no puede saberlo: esa pertenencia no viaja por la red.
#   flagPZ          si es zona de proteccion, que es lo que hace segura la
#                   corrida (sin combate posible).
#   items=<n>       cuantos items hay encima. Sirve para elegir una casa cuyo
#                   interior no tenga objetos sueltos, porque al devolver la
#                   casa a "sin dueno" el servidor manda los objetos
#                   recogibles del interior al deposito del dueno saliente
#                   (`House::transferToDepot`, `house.cpp:257`).
#
# Con eso se elige un par (casilla EXTERIOR, casilla de la CASA) contiguo y
# verificado, en vez de adivinarlo.
#
# ---------------------------------------------------------------------------
# VARIABLES DE ENTORNO
# ---------------------------------------------------------------------------
#   TVP772_GOD_ACCOUNT / _PASSWORD / _CHARACTER   operador (solo lee)
#   TVP772_RECON_CENTROS   "x,y,z;x,y,z;..." centros a inspeccionar
# Opcionales:
#   TVP772_RECON_RADIO     radio en casillas alrededor de cada centro, def. 2
#   TVP772_HOST, TVP772_LOGIN_PORT
#
#   ...Godot --headless --path cliente3d \
#       pruebas/prueba_casa_reconocer_limite.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

## Ritmo entre consultas. El servidor castiga el habla en rafaga, y una
## consulta perdida por silenciamiento se leeria como "no hay casilla".
const PASO_CONSULTA := 0.45
const LIMITE_TOTAL := 420.0

var _con_login
var _con
var _estado
var _puerto := 0
var _fase := "login"
var _espera := 0.0
var _total := 0.0
var _terminando := false

var _cuenta := 0
var _clave := ""
var _nombre := ""
var _host := ""
var _puerto_login := 0
var _radio := 2

var _consultas: Array = []
var _indice := 0
var _respuestas: Array = []


func _ready() -> void:
	print("=========================================================")
	print(" TVP3D QA - reconocimiento de limite de casa (solo lectura)")
	print("=========================================================")
	var requeridas := ["TVP772_GOD_ACCOUNT", "TVP772_GOD_PASSWORD",
		"TVP772_GOD_CHARACTER", "TVP772_RECON_CENTROS"]
	if not CREDENCIALES.exigir(self, requeridas):
		return
	_host = CREDENCIALES.host()
	_puerto_login = CREDENCIALES.puerto_login()
	_cuenta = CREDENCIALES.entero("TVP772_GOD_ACCOUNT")
	_clave = CREDENCIALES.texto("TVP772_GOD_PASSWORD")
	_nombre = CREDENCIALES.texto("TVP772_GOD_CHARACTER")
	if CREDENCIALES.esta_definida("TVP772_RECON_RADIO"):
		_radio = CREDENCIALES.entero("TVP772_RECON_RADIO")
	if not _armar_consultas():
		return
	print("Casillas a consultar: %d" % _consultas.size())
	_abrir_login()


## Un centro por cada casa candidata; alrededor de cada uno, un cuadrado de
## lado (2*radio+1). El orden es estable para que dos corridas se puedan
## comparar linea a linea.
func _armar_consultas() -> bool:
	var crudo := CREDENCIALES.texto("TVP772_RECON_CENTROS")
	for trozo in crudo.split(";", false):
		var partes: PackedStringArray = str(trozo).strip_edges().split(",")
		if partes.size() != 3:
			print("BLOCKED TVP772_RECON_CENTROS debe ser x,y,z separados por ;")
			get_tree().quit(2)
			return false
		var cx := int(partes[0])
		var cy := int(partes[1])
		var cz := int(partes[2])
		for dy in range(-_radio, _radio + 1):
			for dx in range(-_radio, _radio + 1):
				_consultas.append(Vector3i(cx + dx, cy + dy, cz))
	if _consultas.is_empty():
		print("BLOCKED TVP772_RECON_CENTROS no trajo ningun centro")
		get_tree().quit(2)
		return false
	return true


func _process(delta: float) -> void:
	_total += delta
	_espera += delta
	if _terminando:
		return
	if _total > LIMITE_TOTAL:
		_fallar("BLOCKED tiempo agotado durante el reconocimiento")
		return
	match _fase:
		"esperar mundo":
			if _estado != null and _estado.adentro and _espera > 2.0:
				_fase = "consultar"
				_espera = PASO_CONSULTA
		"consultar":
			_consultar()


func _abrir_login() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.error_red.connect(func(t): _fallar("BLOCKED fallo de red en login: %s" % t))
	_con_login.lista_personajes.connect(func(_m, lista):
		for e in lista:
			if str(e.get("nombre", "")) == _nombre:
				_puerto = int(e.get("puerto", 0))
		if _puerto <= 0:
			_fallar("BLOCKED character configured by TVP772_GOD_CHARACTER was not found")
			return
		_con_login.cerrar()
		_abrir_mundo())
	_con_login.pedir_personajes(_host, _puerto_login, _cuenta, _clave)


func _abrir_mundo() -> void:
	_estado = ESTADO.new()
	_estado.pedido_ping.connect(func(): _con.enviar_juego(PackedByteArray([0x1E])))
	_estado.rechazados.connect(func(m): _fallar("BLOCKED el operador fue rechazado: %s" % m))
	_estado.mensaje_servidor.connect(_al_mensaje)
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(func(t):
		if not _terminando: _fallar("BLOCKED fallo de red: %s" % t))
	_con.paquete_juego.connect(func(m): _estado.procesar(m))
	_con.entrar_al_mundo(_host, _puerto, _cuenta, _nombre, _clave)
	_fase = "esperar mundo"
	_espera = 0.0


## Solo interesan las lineas del diagnostico: la cabecera de la casilla y el
## detalle de los items que hay encima. Saber QUE item es importa tanto como
## saber cuantos: un item de decoracion no estorba el paso y una pared si, y
## esa diferencia decide si una casilla sirve como limite medible.
func _al_mensaje(texto: String) -> void:
	if texto.begins_with("tileinfo ") or texto.begins_with("  item ") \
			or texto.begins_with("    dentro: "):
		_respuestas.append(texto)
		print("  %s" % texto)


func _consultar() -> void:
	if _espera < PASO_CONSULTA:
		return
	_espera = 0.0
	if _indice >= _consultas.size():
		_resumir()
		return
	var p: Vector3i = _consultas[_indice]
	_indice += 1
	_con.enviar_hablar("/tileinfo %d,%d,%d" % [p.x, p.y, p.z])


## El resumen agrupa por casa para poder leer de un vistazo que casillas son
## de que casa, cuales estan libres de objetos y cuales son zona de proteccion.
func _resumir() -> void:
	print("---------------------------------------------------------")
	print("Respuestas recibidas: %d de %d consultas" % [_respuestas.size(), _consultas.size()])
	print("RECON_JSON: " + JSON.stringify(_respuestas))
	print("Reconocimiento: OK")
	_terminar(0)


func _fallar(texto: String) -> void:
	print(texto)
	_terminar(2)


func _terminar(codigo: int) -> void:
	if _terminando:
		return
	_terminando = true
	if _con != null:
		_con.cerrar()
	await get_tree().create_timer(1.0).timeout
	print("EXITCODE=%d" % codigo)
	get_tree().quit(codigo)
