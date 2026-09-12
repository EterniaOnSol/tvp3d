extends Node

# =====================================================================
#  Prueba del lector de mapa: entra al mundo, arma el mapa que manda el
#  servidor, lo dibuja en la consola y despues camina.
#
#  UN MAPA MAL LEIDO NO SE NOTA MIRANDO EL DIBUJO. Se nota en otras dos
#  cosas, y las dos hay que comprobarlas (las dos, no una):
#
#    (a) que despues del mapa siga un opcode que reconocemos. Si el
#        lector se comio un byte de mas, ahi aparece basura.
#    (b) que nuestro propio personaje caiga en una casilla que existe.
#        Esta es la que atrapa los corrimientos de casillas enteras, que
#        la (a) no ve: la cantidad de BYTES puede dar bien igual.
#
#    "C:\Users\dell\3DTIBIA\herramientas\godot\Godot_v4.7.2-stable_win64_console.exe" ^
#      --headless --path cliente3d pruebas/prueba_mapa.tscn
# =====================================================================

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

var HOST := CREDENCIALES.HOST_DEFECTO
var PUERTO_LOGIN := CREDENCIALES.PUERTO_LOGIN_DEFECTO
var CUENTA := 0
var CLAVE := ""

const ANCHO := 18
const ALTO := 14

## protocolgame.cpp:497-500
const PASOS := {"este": 0x66, "sur": 0x67, "oeste": 0x68, "norte": 0x65}
const HACIA := {
	"norte": Vector3i(0, -1, 0), "este": Vector3i(1, 0, 0),
	"sur": Vector3i(0, 1, 0), "oeste": Vector3i(-1, 0, 0),
}

var _con
var _mundo
var _reloj := 0.0
var _dibujado := false
var _fallas := 0


func _ready() -> void:
	# Credenciales e identidades de prueba: SOLO por entorno, nunca literales.
	# Si falta alguna, corta aca y no intenta ninguna conexion.
	if not CREDENCIALES.exigir(self, ["TVP772_ACCOUNT", "TVP772_PASSWORD"]):
		return
	HOST = CREDENCIALES.host()
	PUERTO_LOGIN = CREDENCIALES.puerto_login()
	CUENTA = CREDENCIALES.entero("TVP772_ACCOUNT")
	CLAVE = CREDENCIALES.texto("TVP772_PASSWORD")
	print("==============================================")
	print(" TVP3D - leyendo el mapa que manda el servidor")
	print("==============================================")
	print("")
	_mundo = ESTADO.new()
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(_al_fallar)
	_con.lista_personajes.connect(_al_recibir_personajes)
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _process(delta: float) -> void:
	_reloj += delta
	if _reloj > 40.0:
		print("Se acabo el tiempo.")
		get_tree().quit(1)


func _al_recibir_personajes(_motd: String, personajes: Array) -> void:
	if personajes.is_empty():
		print("No hay personajes en la cuenta.")
		get_tree().quit(1)
		return
	var p: Dictionary = personajes[0]
	_con.cerrar()
	_con.queue_free()
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(_al_fallar)
	_con.paquete_juego.connect(_al_recibir_paquete)
	_mundo.cambio.connect(_al_cambiar)
	_mundo.pedido_ping.connect(_al_pedir_ping)
	_con.entrar_al_mundo(p["ip"], p["puerto"], CUENTA, p["nombre"], CLAVE)


func _al_recibir_paquete(msg) -> void:
	_mundo.procesar(msg)


func _al_pedir_ping() -> void:
	_con.enviar_juego(PackedByteArray([0x1E]))


func _al_cambiar() -> void:
	if _dibujado or not _mundo.adentro or _mundo.casillas.is_empty():
		return
	_dibujado = true

	var pos: Vector3i = _mundo.mi_pos
	print("Personaje numero %d, parado en (%d, %d) piso %d" % [
		_mundo.mi_id, pos.x, pos.y, pos.z])
	print("Casillas con algo encima: %d" % _mundo.casillas.size())
	print("Criaturas a la vista: %d" % _mundo.criaturas.size())
	for id in _mundo.criaturas:
		var c: Dictionary = _mundo.criaturas[id]
		var d: Vector3i = c["pos"]
		print("   - \"%s\"  en (%d, %d, %d)" % [
			c["nombre"] if c["nombre"] != "" else "(ya conocida)", d.x, d.y, d.z])

	_dibujar(pos)
	_comprobar("(a) todos los mensajes del paquete se entendieron",
		_mundo.opcodes_desconocidos().is_empty())
	_comprobar("(b) nuestra casilla existe en el mapa que leimos",
		_mundo.casillas.has(pos))

	var llenas := 0
	for donde in _mundo.casillas:
		if donde.z == pos.z:
			llenas += 1
	# La ventana es de 18x14 = 252 casillas. En Rookgaard, al aire libre,
	# practicamente todas tienen suelo.
	_comprobar("(c) el piso donde estamos vino casi entero (%d de 252)" % llenas,
		llenas > 200)

	_caminar.call_deferred()


func _caminar() -> void:
	print("")
	print("Caminando, y comprobando que el mapa siga cuadrando:")
	print("")
	for direccion in PASOS:
		var antes: Vector3i = _mundo.mi_pos
		_mundo.ultimo_movimiento = {}
		_con.enviar_juego(PackedByteArray([PASOS[direccion]]))
		await get_tree().create_timer(1.2).timeout

		var ahora: Vector3i = _mundo.mi_pos
		if ahora == antes:
			print("   %-6s : el servidor no nos dejo (pared). Va bien igual." % direccion)
			continue

		var esperada: Vector3i = antes + HACIA[direccion]
		if ahora != esperada:
			print("   %-6s : MAL. Creiamos ir a (%d,%d) y quedamos en (%d,%d)." % [
				direccion, esperada.x, esperada.y, ahora.x, ahora.y])
			_fallas += 1
			continue
		if not _mundo.casillas.has(ahora):
			print("   %-6s : MAL. Caminamos a (%d,%d) y ahi no hay casilla." % [
				direccion, ahora.x, ahora.y])
			_fallas += 1
			continue
		print("   %-6s : ok, ahora en (%d,%d), la franja nueva llego bien." % [
			direccion, ahora.x, ahora.y])

	_terminar()


func _terminar() -> void:
	var raros: Dictionary = _mundo.opcodes_desconocidos()
	print("")
	if raros.is_empty():
		print("No quedo ni un mensaje sin entender.")
	else:
		print("Mensajes que no supimos leer (cortan el resto del paquete):")
		for op in raros:
			print("   0x%02X  x%d" % [op, raros[op]])
		_fallas += 1

	print("")
	print("==============================================")
	if _fallas == 0:
		print(" El mapa se leyo entero, alineado, y camina.")
	else:
		print(" HAY %d PROBLEMA(S). Mirar arriba." % _fallas)
	print("==============================================")
	get_tree().quit(1 if _fallas > 0 else 0)


func _comprobar(que: String, bien: bool) -> void:
	print("   %s  %s" % ["OK  " if bien else "MAL ", que])
	if not bien:
		_fallas += 1


func _dibujar(pos: Vector3i) -> void:
	var ocupadas := {}
	for id in _mundo.criaturas:
		ocupadas[_mundo.criaturas[id]["pos"]] = true

	print("")
	print("Piso %d, visto desde arriba (# pared, . piso, @ vos, M bicho):" % pos.z)
	print("")
	var x0: int = pos.x - 8
	var y0: int = pos.y - 6
	for y in range(y0, y0 + ALTO):
		var linea := "    "
		for x in range(x0, x0 + ANCHO):
			var donde := Vector3i(x, y, pos.z)
			var ch := " "
			if _mundo.casillas.has(donde):
				ch = "."
				for cosa in _mundo.casillas[donde]:
					if cosa["tipo"] == "item" and cosa["bloquea"] and cosa["frena_vista"]:
						ch = "#"
			if ocupadas.has(donde):
				ch = "M"
			if x == pos.x and y == pos.y:
				ch = "@"
			linea += ch
		print(linea)


func _al_fallar(texto: String) -> void:
	print("FALLO: %s" % texto)
	get_tree().quit(1)
