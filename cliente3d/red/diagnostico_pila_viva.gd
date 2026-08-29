extends SceneTree

# Diagnostico de protocolo: que trae la pila de la casilla propia y de sus
# vecinas despues del `0x64`. No modifica nada del mundo ni pelea con nadie:
# entra, mira y sale.
#
#   ...Godot --headless --path cliente3d --script res://red/diagnostico_pila_viva.gd

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
const CUENTA := 123456
const CLAVE := "123456"
const PERSONAJE := "GOD VALENTINO"

var _con
var _estado
var _reloj := 0.0
var _listo := false
var _terminado := false
var _capturado := false
var _pedido_teleport := false

## El desalineamiento aparece en campo abierto, no en el templo, asi que el
## diagnostico se lleva al personaje ahi con una orden del propio servidor.
const POS_CAMPO := Vector3i(32082, 32145, 6)

## Los bytes exactos del mensaje de entrada, para reproducir el mapa sin
## servidor en `red/mapa_captura_self_test.gd`.
const RUTA_CAPTURA := "res://generated/capturas/entrada_mundo.bin"


func _initialize() -> void:
	_con = CONEXION.new()
	root.add_child(_con)
	_con.error_red.connect(func(texto):
		printerr("red: ", texto)
		_terminado = true)
	_con.lista_personajes.connect(func(_motd, personajes):
		for p in personajes:
			if str(p.get("nombre", "")) == PERSONAJE:
				_entrar(int(p.get("puerto", 0)))
				return
		printerr("no existe el personaje")
		_terminado = true)
	_con.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _entrar(puerto: int) -> void:
	_estado = ESTADO.new()
	_estado.entramos.connect(func(): _listo = true)
	_estado.pedido_ping.connect(func():
		_con.enviar_juego(PackedByteArray([0x1E])))
	_con.paquete_juego.connect(func(msg):
		# La captura se guarda ANTES de procesar: son los bytes exactos que
		# mando el servidor, para poder reproducir el caso sin servidor.
		if _pedido_teleport and not _capturado and msg.datos.size() > 800:
			_capturar(msg.datos)
		_estado.procesar(msg))
	_con.entrar_al_mundo(HOST, puerto, CUENTA, PERSONAJE, CLAVE)


func _capturar(bytes: PackedByteArray) -> void:
	_capturado = true
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(RUTA_CAPTURA.get_base_dir()))
	var f := FileAccess.open(RUTA_CAPTURA, FileAccess.WRITE)
	if f == null:
		printerr("no se pudo escribir la captura")
		return
	f.store_buffer(bytes)
	f.close()
	print("captura de %d bytes en %s" % [bytes.size(), RUTA_CAPTURA])


func _process(delta: float) -> bool:
	_reloj += delta
	if _terminado:
		return true
	if _reloj > 40.0:
		printerr("tiempo agotado")
		return true
	if not _listo or _estado.mi_pos == Vector3i.ZERO or _reloj < 3.0:
		return false
	if not _pedido_teleport:
		_pedido_teleport = true
		print("templo: mi_pos=%s alineado=%s" % [
			str(_estado.mi_pos), str(_estado.mapa_alineado)])
		_con.enviar_hablar("/gotopos %d,%d,%d" % [
			POS_CAMPO.x, POS_CAMPO.y, POS_CAMPO.z])
		return false
	if _reloj < 8.0:
		return false
	print("mi_id=%d mi_pos=%s" % [_estado.mi_id, str(_estado.mi_pos)])
	print("casillas conocidas: %d" % _estado.casillas.size())
	print("items sin catalogo: %d, ids: %s" % [
		_estado._mapa.items_sin_datos(),
		str(_estado._mapa.cids_sin_datos())])
	print("primer item sin catalogo: %s" % str(_estado._mapa._primer_desconocido))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var donde: Vector3i = _estado.mi_pos + Vector3i(dx, dy, 0)
			var partes: Array = []
			var indice := 0
			for cosa in _estado.casillas.get(donde, []):
				if cosa.get("tipo") == "criatura":
					partes.append("%d:criatura(%d)%s" % [indice,
						int(cosa.get("id", 0)),
						"<-YO" if int(cosa.get("id", 0)) == _estado.mi_id else ""])
				else:
					partes.append("%d:%s" % [indice,
						str(cosa.get("nombre", cosa.get("cid", "?")))])
				indice += 1
			print("%s%s -> %s" % [str(donde),
				"  (yo)" if donde == _estado.mi_pos else "",
				"VACIA" if partes.is_empty() else " | ".join(partes)])
	_con.cerrar()
	return true
