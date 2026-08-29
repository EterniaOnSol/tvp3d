extends SceneTree

# Entra con un personaje, pisa la baldosa de su depot y muestra que hay dentro
# de su cofre. Es la forma de contestar "¿le llego la parcel?" sin suponer.
#
#   ...Godot --headless --path cliente3d --script res://red/diagnostico_depot_ajeno.gd

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
const CUENTA := 123456
const CLAVE := "123456"
const PERSONAJE := "Valentino"

const POS_LOCKER := Vector3i(32354, 32231, 7)
const POS_BALDOSA := Vector3i(32354, 32230, 7)
const POS_AFUERA := Vector3i(32355, 32230, 7)

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
	_estado.contenedor_actualizado.connect(func(id, datos):
		var partes: Array = []
		for cosa in datos.get("items", []):
			partes.append(str(cosa.get("nombre", cosa.get("cid", "?"))))
		print("Contenedor %d '%s': %s" % [id, str(datos.get("nombre", "")),
			"vacio" if partes.is_empty() else ", ".join(partes)]))
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.entrar_al_mundo(HOST, puerto, CUENTA, PERSONAJE, CLAVE)


func _process(delta: float) -> bool:
	_reloj += delta
	if _reloj > 60.0:
		printerr("tiempo agotado")
		return true
	if _estado == null or not _estado.adentro:
		return false
	match _paso:
		0:
			if _reloj > 3.0:
				_paso = 1
				_con.enviar_hablar("/gotopos %d,%d,%d" % [
					POS_AFUERA.x, POS_AFUERA.y, POS_AFUERA.z])
		1:
			if _reloj > 8.0:
				_paso = 2
				_con.enviar_hablar("/gotopos %d,%d,%d" % [
					POS_BALDOSA.x, POS_BALDOSA.y, POS_BALDOSA.z])
		2:
			if _reloj > 13.0:
				_paso = 3
				var pila := 0
				for cosa in _estado.casillas.get(POS_LOCKER, []):
					if cosa.get("tipo") == "item" \
							and bool(cosa.get("contenedor", false)):
						print("Abriendo el locker de %s." % PERSONAJE)
						_con.enviar_usar_item(POS_LOCKER,
							int(cosa.get("cid", 0)), pila, 1)
						return false
					pila += 1
				printerr("no aparece el locker")
				return true
		3:
			if _reloj > 17.0:
				_paso = 4
				var indice := 0
				for cosa in _estado.contenedores.get(1, {}).get("items", []):
					if str(cosa.get("nombre", "")).contains("depot"):
						_con.enviar_usar_item(
							Vector3i(0xFFFF, 0x40 | 1, indice),
							int(cosa.get("cid", 0)), 0, 2)
						return false
					indice += 1
				printerr("el locker no trae depot chest")
				return true
		4:
			if _reloj > 22.0:
				_con.cerrar()
				return true
	return false
