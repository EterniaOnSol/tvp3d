extends Node

# =====================================================================
#  Prueba real contra TVP, de punta a punta:
#    1. pedir la lista de personajes
#    2. entrar al mundo
#    3. CAMINAR — y ver si el servidor contesta
#
#  Cómo correrla (con ARRANCAR SERVIDOR.bat ya andando):
#
#    "C:\Users\dell\3DTIBIA\herramientas\godot\Godot_v4.7.2-stable_win64_console.exe" ^
#      --headless --path cliente3d pruebas/prueba_login.tscn
# =====================================================================

const CONEXION := preload("res://red/conexion772.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
## En 7.72 la cuenta es un NUMERO, no un texto (protocollogin.cpp:156).
const CUENTA := 123456
const CLAVE := "123456"

## protocolgame.cpp:497-500 — lo que el cliente manda para dar un paso.
const PASOS := {
	"norte": 0x65,
	"este": 0x66,
	"sur": 0x67,
	"oeste": 0x68,
}

## Lo que el servidor manda de vuelta cuando alguien se mueve de verdad.
const RESPUESTAS_DE_MOVIMIENTO := {
	0x6D: "una criatura se movio de casillero",
	0x65: "fila nueva de mapa por el norte",
	0x66: "columna nueva de mapa por el este",
	0x67: "fila nueva de mapa por el sur",
	0x68: "columna nueva de mapa por el oeste",
	0x6A: "apareció algo nuevo en el mapa",
	0x6C: "desapareció algo del mapa",
	0xB5: "el servidor CANCELO el paso (chocaste con algo)",
}

const SEGUNDOS_A_ESPERAR := 40.0

var _con
var _reloj := 0.0
var _paquetes := 0
var _fase := "login"
var _escuchando_pasos := false
var _respuestas: Array = []


func _ready() -> void:
	print("=========================================")
	print(" TVP3D - prueba de conexion contra TVP")
	print("=========================================")
	print("")
	print("[1] Pidiendo la lista de personajes a %s:%d ..." % [HOST, PUERTO_LOGIN])

	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(_al_fallar)
	_con.lista_personajes.connect(_al_recibir_personajes)
	_con.paquete_juego.connect(_al_recibir_paquete)
	_con.cerrada.connect(_al_cerrarse)
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _process(delta: float) -> void:
	_reloj += delta
	if _reloj > SEGUNDOS_A_ESPERAR:
		print("")
		print("Se acabo el tiempo en la fase '%s'." % _fase)
		_terminar(1)


func _al_recibir_personajes(motd: String, personajes: Array) -> void:
	print("    OK. Mensaje del dia: \"%s\"" % motd)
	print("    Personajes en la cuenta: %d" % personajes.size())
	for p in personajes:
		print("      - %s  (mundo \"%s\", %s:%d)" % [p["nombre"], p["mundo"], p["ip"], p["puerto"]])

	if personajes.is_empty():
		print("")
		print("La cuenta no tiene personajes. Nada mas que probar.")
		_terminar(1)
		return

	var elegido: Dictionary = personajes[0]
	_fase = "entrar al mundo"
	print("")
	print("[2] Entrando al mundo con \"%s\" por %s:%d ..." % [elegido["nombre"], elegido["ip"], elegido["puerto"]])

	# El servidor anuncia la IP de config.lua (127.0.0.1); vale igual, pero
	# si alguna vez dice 0.0.0.0 hay que caer al host que ya funcionó.
	var ip: String = elegido["ip"]
	if ip == "0.0.0.0" or ip == "":
		ip = HOST

	_con.cerrar()
	_con.queue_free()
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(_al_fallar)
	_con.paquete_juego.connect(_al_recibir_paquete)
	_con.cerrada.connect(_al_cerrarse)
	_con.entrar_al_mundo(ip, elegido["puerto"], CUENTA, elegido["nombre"], CLAVE)


func _al_recibir_paquete(msg) -> void:
	_paquetes += 1
	var tipo: int = msg.espiar_u8()

	if _paquetes == 1:
		print("    ENTRAMOS. El servidor esta hablando (%d bytes de mundo en el primer mensaje)." % msg.tam())
		_probar_pasos.call_deferred()

	if _escuchando_pasos and RESPUESTAS_DE_MOVIMIENTO.has(tipo):
		_respuestas.append(tipo)


func _probar_pasos() -> void:
	_fase = "caminar"
	# Le damos un respiro al servidor para que termine de mandar el mundo.
	await get_tree().create_timer(2.0).timeout

	print("")
	print("[3] Probando caminar. Un paso para cada lado, esperando 1,5s entre cada uno.")
	print("")

	for direccion in PASOS:
		_respuestas.clear()
		_escuchando_pasos = true

		var paso := PackedByteArray([PASOS[direccion]])
		_con.enviar_juego(paso)
		print("    -> paso hacia el %s (opcode 0x%02X)" % [direccion, PASOS[direccion]])

		await get_tree().create_timer(1.5).timeout
		_escuchando_pasos = false

		if _respuestas.is_empty():
			print("       <- NADA. El servidor lo ignoro.")
		else:
			var vistos := {}
			for t in _respuestas:
				vistos[t] = vistos.get(t, 0) + 1
			for t in vistos:
				print("       <- 0x%02X x%d : %s" % [t, vistos[t], RESPUESTAS_DE_MOVIMIENTO[t]])

	_terminar(0)


func _al_fallar(texto: String) -> void:
	print("")
	print("FALLO en la fase '%s': %s" % [_fase, texto])
	_terminar(1)


func _al_cerrarse() -> void:
	if _paquetes > 0:
		return   # ya habiamos entrado; el cierre es normal
	print("")
	print("El servidor cerro la conexion en la fase '%s'." % _fase)
	print("(Mira que dice el servidor con VER SERVIDOR.bat.)")
	_terminar(1)


func _terminar(codigo: int) -> void:
	print("")
	print("=========================================")
	if codigo == 0:
		print(" Login OK, mundo OK, %d mensajes recibidos." % _paquetes)
	else:
		print(" RESULTADO: no llego hasta el final.")
	print("=========================================")
	get_tree().quit(codigo)
