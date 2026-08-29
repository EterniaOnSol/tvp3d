extends SceneTree

# Le pregunta al servidor que ve en la casilla del mailbox, usando la
# talkaction de diagnostico `/tileinfo`. No cambia nada del mundo.
#
#   ...Godot --headless --path cliente3d --script res://red/diagnostico_mailbox.gd

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
const CUENTA := 123456
const CLAVE := "123456"
const PERSONAJE := "GOD VALENTINO"
const POS_MAILBOX := Vector3i(32372, 32253, 7)
const POS_JUNTO := Vector3i(32372, 32252, 7)

var _con
var _estado
var _reloj := 0.0
var _paso := 0


func _initialize() -> void:
	_con = CONEXION.new()
	root.add_child(_con)
	_con.error_red.connect(func(t): printerr("red: ", t))
	_con.lista_personajes.connect(func(_m, personajes):
		for p in personajes:
			if str(p.get("nombre", "")) == PERSONAJE:
				_entrar(int(p.get("puerto", 0)))
				return)
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _entrar(puerto: int) -> void:
	_estado = ESTADO.new()
	_estado.pedido_ping.connect(func(): _con.enviar_juego(PackedByteArray([0x1E])))
	_estado.mensaje_servidor.connect(func(texto): print("  [srv] ", texto))
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.entrar_al_mundo(HOST, puerto, CUENTA, PERSONAJE, CLAVE)


func _process(delta: float) -> bool:
	_reloj += delta
	if _reloj > 45.0:
		return true
	if _estado == null or not _estado.adentro:
		return false
	if _paso == 0 and _reloj > 2.0:
		_paso = 1
		_con.enviar_hablar("/reload scripts")
		return false
	if _paso == 1 and _reloj > 6.0:
		_paso = 2
		_con.enviar_hablar("/gotopos %d,%d,%d" % [
			POS_JUNTO.x, POS_JUNTO.y, POS_JUNTO.z])
		return false
	if _paso == 2 and _reloj > 9.0:
		_paso = 3
		print("Limpiando los objetos que dejaron las pruebas:")
		_con.enviar_hablar("/limpiarpruebas")
		_con.enviar_hablar("/tileinfo %d,%d,%d" % [
			POS_MAILBOX.x, POS_MAILBOX.y, POS_MAILBOX.z])
		return false
	if _paso == 3 and _reloj > 14.0:
		_con.cerrar()
		return true
	return false
