extends Node

## Muerte, logout 0x14 y reentrada al selector, sin servidor y sin ventana.
##
## Comprueba las dos mitades del recorrido con los bytes reales de la rama:
##
##  1. `EstadoMundo` solo declara muerte cuando el `0x6C` retira a `mi_id`
##     con las stats autoritativas en vida cero.
##  2. `mundo3d.gd` consume esa senal: bloquea intenciones, manda exactamente
##     un `0x14`, deja la pantalla de reentrada puesta cuando el servidor
##     cierra, y vuelve al selector solo cuando el jugador lo pide.
##
## No existe opcode de muerte en este servidor y la prueba no inventa ninguno.

const MUNDO := preload("res://mundo3d.gd")
const ESTADO_MUNDO := preload("res://red/estado_mundo.gd")
const MENSAJE := preload("res://red/mensaje.gd")
const MUERTE := preload("res://ui/muerte.gd")


class ConexionFalsa extends Node:
	## Mismo contrato de senales y metodos que usa mundo3d de conexion772.
	signal error_red(texto: String)
	signal lista_personajes(motd: String, personajes: Array)
	signal cerrada()
	signal paquete_juego(msg)

	var enviados: Array = []
	var cerrada_por_cliente := 0
	var pedidos_de_lista := 0

	func enviar_juego(carga: PackedByteArray) -> void:
		enviados.append(carga)

	func enviar_logout() -> void:
		enviar_juego(PackedByteArray([0x14]))

	func cerrar() -> void:
		cerrada_por_cliente += 1

	func pedir_personajes(_host: String, _puerto: int, _cuenta: int,
			_clave: String) -> void:
		pedidos_de_lista += 1

	func entrar_al_mundo(_host: String, _puerto: int, _cuenta: int,
			_nombre: String, _clave: String) -> void:
		pass


class VozFalsa:
	var detenida := 0

	func configurar_conexion(_con) -> void:
		pass

	func iniciar() -> void:
		pass

	func detener() -> void:
		detenida += 1


class PantallaFalsa extends CanvasLayer:
	var estados: Array = []
	var errores: Array = []
	var mostro_login := 0
	var listas := 0

	func mostrar_estado(texto: String) -> void:
		estados.append(texto)

	func mostrar_error(texto: String) -> void:
		errores.append(texto)

	func mostrar_login() -> void:
		mostro_login += 1

	func mostrar_personajes(_motd: String, _personajes: Array) -> void:
		listas += 1

	func esta_escribiendo() -> bool:
		return false


class MundoDePrueba extends MUNDO:
	## La conexion del recorrido de reentrada tampoco abre un socket.
	var conexiones: Array = []
	var avisos: Array = []

	func _nueva_conexion():
		var falsa := ConexionFalsa.new()
		conexiones.append(falsa)
		return falsa

	func _avisar(texto: String) -> void:
		avisos.append(texto)


var _fallas := 0


func _ready() -> void:
	_probar_senal_de_muerte()
	_probar_consumo_en_cliente()
	if _fallas == 0:
		print("Muerte y reentrada 7.72: OK")
	else:
		print("Muerte y reentrada 7.72: %d fallas" % _fallas)
	get_tree().quit(1 if _fallas > 0 else 0)


func _probar_senal_de_muerte() -> void:
	var id := 0x00ABCDEF
	var donde := Vector3i(32097, 32219, 7)

	var estado := ESTADO_MUNDO.new()
	estado.mi_id = id
	estado.adentro = true
	estado.criaturas[id] = {"pos": donde, "vida": 0}
	estado.casillas[donde] = [{"tipo": "criatura", "id": id}]
	var muertes: Array = []
	estado.jugador_muerto.connect(func(pos): muertes.append(pos))

	# Con vida positiva, el mismo retiro puede ser un teleport.
	estado.estadisticas = {"vida": 40}
	estado.procesar(_retiro(donde))
	_comprobar("retiro con vida positiva no es muerte",
		muertes.is_empty() and estado.adentro)

	# Con las stats autoritativas en cero, ese 0x6C es la muerte de la rama.
	estado.casillas[donde] = [{"tipo": "criatura", "id": id}]
	estado.estadisticas = {"vida": 0}
	var muerte := _retiro(donde)
	muerte.escribir_u8(0xB4)
	muerte.escribir_u8(0x16)
	muerte.escribir_texto("You are dead.")
	estado.procesar(muerte)
	_comprobar("0x6C de mi_id con vida cero emite muerte una vez",
		muertes == [donde])
	_comprobar("la muerte deja al jugador fuera del mundo", not estado.adentro)
	_comprobar("el paquete de muerte queda alineado", muerte.sin_leer() == 0)


func _probar_consumo_en_cliente() -> void:
	var mundo := MundoDePrueba.new()
	var estado := ESTADO_MUNDO.new()
	var conexion := ConexionFalsa.new()
	var interfaz := PantallaFalsa.new()
	var login := PantallaFalsa.new()
	var pantalla_muerte := MUERTE.new()
	# `mundo` se queda fuera del arbol a proposito: su `_ready` levantaria el
	# cliente entero. Las pantallas si entran al arbol para que armen sus
	# nodos igual que en una partida.
	add_child(conexion)
	add_child(interfaz)
	add_child(login)
	add_child(pantalla_muerte)
	mundo._estado = estado
	mundo._con = conexion
	mundo._interfaz = interfaz
	mundo._login = login
	mundo._muerte = pantalla_muerte
	mundo._voz = VozFalsa.new()
	# Identidad de RELLENO, a proposito. Esta prueba es offline y usa
	# `ConexionFalsa`, asi que no se autentica nada; `mundo3d` solo exige que
	# los dos campos no esten vacios (`mundo3d.gd:812,967`). Ninguna credencial
	# real vive en codigo versionado.
	mundo._cuenta_login = 1
	mundo._clave_login = "clave-de-prueba"
	estado.mi_id = 7
	estado.adentro = true
	interfaz.visible = true
	# Mismo cableado que arma `mundo3d._ready`.
	estado.jugador_muerto.connect(mundo._al_morir)
	pantalla_muerte.solicito_reentrada.connect(mundo.volver_desde_muerte)

	var donde := Vector3i(32097, 32219, 7)
	estado.criaturas[estado.mi_id] = {"pos": donde, "vida": 0}
	estado.casillas[donde] = [{"tipo": "criatura", "id": estado.mi_id}]
	estado.estadisticas = {"vida": 0}
	estado.procesar(_retiro(donde))

	_comprobar("la muerte bloquea las intenciones del cliente",
		mundo.esta_muerto())
	_comprobar("la muerte envia exactamente un logout 0x14",
		conexion.enviados == [PackedByteArray([0x14])])
	_comprobar("la muerte oculta la interfaz de juego", not interfaz.visible)
	_comprobar("la muerte muestra la pantalla de reentrada",
		pantalla_muerte.visible)
	_comprobar("la pantalla usa el texto del servidor",
		MUERTE.TEXTO_MUERTE == "You are dead.")
	_comprobar("la muerte no vuelve sola al formulario de cuenta",
		login.mostro_login == 0)

	# Un segundo 0x6C no puede mandar otro logout ni reabrir el recorrido.
	estado.adentro = true
	estado.casillas[donde] = [{"tipo": "criatura", "id": estado.mi_id}]
	estado.procesar(_retiro(donde))
	_comprobar("una segunda retirada no reenvia logout",
		conexion.enviados.size() == 1)

	# Un mensaje 0xB4 con la palabra logout no cancela una muerte.
	mundo._al_mensaje_servidor("You may not logout during a fight.")
	_comprobar("la muerte no se cancela con un mensaje de logout",
		mundo.esta_muerto() and pantalla_muerte.visible and not interfaz.visible)

	# El cierre del socket es la respuesta esperada al 0x14 tras la muerte.
	mundo._al_cerrarse()
	_comprobar("el cierre tras morir conserva la pantalla de reentrada",
		pantalla_muerte.visible and mundo.esta_muerto())
	_comprobar("el cierre tras morir suelta la conexion", mundo._con == null)
	_comprobar("el cierre tras morir limpia la sesion",
		not estado.adentro and estado.mi_id == 0 and estado.criaturas.is_empty())
	_comprobar("el cierre tras morir no muestra el formulario de cuenta",
		login.mostro_login == 0)

	# La reentrada la decide el jugador, con el boton real de la pantalla.
	var boton := pantalla_muerte.find_child("DeathReturn", true, false) as Button
	_comprobar("la pantalla de reentrada tiene su accion de volver",
		boton != null and boton.text == "Return to character list")
	if boton != null:
		boton.pressed.emit()
	_comprobar("la reentrada oculta la pantalla de muerte",
		not pantalla_muerte.visible)
	_comprobar("la reentrada devuelve el control", not mundo.esta_muerto())
	_comprobar("la reentrada vuelve al selector de personajes",
		login.visible and mundo.conexiones.size() == 1
		and mundo.conexiones[0].pedidos_de_lista == 1)
	_comprobar("la reentrada no reabre el formulario de cuenta",
		login.mostro_login == 0)

	mundo.queue_free()


func _retiro(posicion: Vector3i) -> RefCounted:
	## 0x6C exacto de protocolgame.cpp:2357-2366: opcode, posicion y pila.
	var msg := MENSAJE.new()
	msg.escribir_u8(0x6C)
	msg.escribir_u16(posicion.x)
	msg.escribir_u16(posicion.y)
	msg.escribir_u8(posicion.z)
	msg.escribir_u8(0)
	return msg


func _comprobar(nombre: String, correcto: bool) -> void:
	if correcto:
		print("  OK  " + nombre)
	else:
		print("  FAIL " + nombre)
		_fallas += 1
