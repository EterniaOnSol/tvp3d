extends Node

# Captura QA-owned en vivo, solo corpse de monstruo (Phase 2B.2, endurecida
# en Phase 2B.2.1).
#
# Reemplaza al modo `--solo-loot` de `prueba_muerte_loot_vivo.gd` con un
# camino narrow que no toca al personaje normal, no arma ningun duelo y no
# depende de la precondicion de muerte/reentrada. Conecta solo con la sesion
# god, invoca una rata de prueba, la mata, abre su corpse y emite en stdout
# UNA linea machine-readable con los hechos normalizados observados.
#
# Endurecido en Phase 2B.2.1 contra cuatro defectos de la primera version:
# el nombre de corpse observado ya no se fuerza a minusculas antes de
# serializarse; `/killall` no se emite si otra criatura viva distinta de la
# rata de esta corrida esta dentro de su area real (AREA_SQUARE1X1, 3x3,
# radio Chebyshev 1 sobre la posicion del god); y un fallo de personaje god
# ya no enumera los demas nombres de personaje de la cuenta.
#
# Esta rama NO decide PASS/FAIL: eso lo hace exclusivamente
# `qa/parity/tools/replay.py` comparando esta observacion contra la
# `ParityExpectationV1` ya publicada. Este script solo observa y serializa.
#
# Credenciales: exclusivamente por variable de entorno, nunca literal en este
# archivo:
#   TVP772_ACCOUNT         (numero de cuenta)
#   TVP772_PASSWORD        (clave)
#   TVP772_GOD_CHARACTER   (nombre del personaje god)
# Opcionales:
#   TVP772_HOST            (por defecto 127.0.0.1)
#   TVP772_LOGIN_PORT      (por defecto 7171)
#
#   ...Godot --headless --path cliente3d pruebas/prueba_parity_monster_corpse_capture.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST_DEFECTO := "127.0.0.1"
const PUERTO_LOGIN_DEFECTO := 7171
## Misma casilla de campo ya documentada como fuera de zona de proteccion en
## docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md. Es navegacion interna del capturador,
## nunca aparece en el payload normalizado emitido.
const POS_CAMPO := Vector3i(32082, 32145, 6)
const MONSTRUO := "rat"

const LIMITE_TOTAL := 180.0
const ESPERA_ORDEN := 3.0
const ESPERA_TELEPORT := 20.0
const ESPERA_CORPSE := 90.0

var _con
var _estado
var _fase := "conectar"
var _reloj := 0.0
var _espera := 0.0
var _paso := 0
var _puerto_juego := 0

var _cuenta := 0
var _clave := ""
var _personaje_god := ""
var _host := HOST_DEFECTO
var _puerto_login := PUERTO_LOGIN_DEFECTO

var _id_monstruo := 0
var _pos_monstruo := Vector3i.ZERO
var _corpse_monstruo := {}
var _nombre_corpse := ""
var _ids_previos := {}
var _corpses_previos := {}
var _intentos_invocar := 0
var _intentos_limpieza := 0
var _terminando := false


func _ready() -> void:
	print("=================================================")
	print(" TVP3D QA - captura en vivo: corpse de monstruo")
	print("=================================================")

	var falta := _resolver_credenciales()
	if not falta.is_empty():
		print("BLOCKED missing environment variable %s" % falta)
		get_tree().quit(2)
		return

	_conectar_login()


func _resolver_credenciales() -> String:
	var cuenta_texto := OS.get_environment("TVP772_ACCOUNT")
	if cuenta_texto.is_empty():
		return "TVP772_ACCOUNT"
	if not cuenta_texto.is_valid_int():
		return "TVP772_ACCOUNT"
	_cuenta = int(cuenta_texto)

	_clave = OS.get_environment("TVP772_PASSWORD")
	if _clave.is_empty():
		return "TVP772_PASSWORD"

	_personaje_god = OS.get_environment("TVP772_GOD_CHARACTER")
	if _personaje_god.is_empty():
		return "TVP772_GOD_CHARACTER"

	var host_env := OS.get_environment("TVP772_HOST")
	if not host_env.is_empty():
		_host = host_env

	var puerto_env := OS.get_environment("TVP772_LOGIN_PORT")
	if not puerto_env.is_empty() and puerto_env.is_valid_int():
		_puerto_login = int(puerto_env)

	return ""


func _process(delta: float) -> void:
	_reloj += delta
	_espera += delta
	if _reloj > LIMITE_TOTAL:
		_fallar("FAIL tiempo agotado en la fase '%s'" % _fase)
		return
	if _estado == null:
		return
	match _fase:
		"ir al campo":
			_ir_al_campo()
		"limpiar y invocar":
			_limpiar_y_invocar()
		"matar":
			_vigilar_al_monstruo()
		"acercarse al corpse":
			_acercarse_al_corpse()


func _conectar_login() -> void:
	_fase = "lista personajes"
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(func(texto): _fallar("FAIL fallo de red: %s" % texto))
	_con.lista_personajes.connect(_al_recibir_personajes)
	_con.pedir_personajes(_host, _puerto_login, _cuenta, _clave)


func _al_recibir_personajes(_motd: String, personajes: Array) -> void:
	var puerto := 0
	for p in personajes:
		if str(p.get("nombre", "")) == _personaje_god:
			puerto = int(p.get("puerto", 0))
			break
	if puerto <= 0:
		_fallar("FAIL character configured by TVP772_GOD_CHARACTER was not found")
		return
	_puerto_juego = puerto
	_entrar_al_mundo()


func _entrar_al_mundo() -> void:
	_fase = "entrar al mundo"
	_estado = ESTADO.new()
	_estado.entramos.connect(_al_entramos)
	_estado.rechazados.connect(func(motivo): _fallar("FAIL rechazado: %s" % motivo))
	_estado.mapa_desalineado.connect(func(detalle): _registrar_mapa_desalineado(detalle))
	_estado.contenedor_actualizado.connect(_al_contenedor)
	_estado.mensaje_servidor.connect(func(texto): print("  [srv] ", texto))
	_estado.pedido_ping.connect(func(): _con.enviar_juego(PackedByteArray([0x1E])))
	_con.paquete_juego.connect(func(msg): _estado.procesar(msg))
	_con.cerrada.connect(func():
		if not _terminando:
			_fallar("FAIL el servidor corto la conexion antes de terminar"))
	_con.entrar_al_mundo(_host, _puerto_juego, _cuenta, _personaje_god, _clave)


func _al_entramos() -> void:
	print("Dentro con la sesion god.")
	_pasar_a("ir al campo")


func _pasar_a(fase: String) -> void:
	_fase = fase
	_espera = 0.0
	_paso = 0


func _ir_al_campo() -> void:
	if _en_el_campo(_estado.mi_pos):
		print("God en el campo: %s." % str(_estado.mi_pos))
		_pasar_a("limpiar y invocar")
		return
	if _paso == 0 or _espera > ESPERA_ORDEN:
		_paso += 1
		_espera = 0.0
		_con.enviar_hablar("/gotopos %d,%d,%d" % [POS_CAMPO.x, POS_CAMPO.y, POS_CAMPO.z])
	if _espera > ESPERA_TELEPORT and _paso > 1:
		_fallar("FAIL el god no llego al campo de prueba a tiempo")


func _en_el_campo(posicion: Vector3i) -> bool:
	return posicion.z == POS_CAMPO.z \
		and absi(posicion.x - POS_CAMPO.x) <= 2 \
		and absi(posicion.y - POS_CAMPO.y) <= 2


func _limpiar_y_invocar() -> void:
	if _espera < ESPERA_ORDEN and _paso > 0:
		return
	_espera = 0.0
	_paso += 1
	match _paso:
		1:
			_ids_previos.clear()
			for id in _estado.criaturas:
				_ids_previos[int(id)] = true
			_corpses_previos.clear()
			for donde in _estado.casillas:
				if not _contenedor_en(donde).is_empty():
					_corpses_previos[donde] = true
			print("Invocando %s para el corpse." % MONSTRUO)
			_con.enviar_hablar("/m %s" % MONSTRUO)
		2:
			if not _buscar_monstruo():
				_intentos_invocar += 1
				if _intentos_invocar > 4:
					_fallar("FAIL el servidor no invoco %s en %s" % [MONSTRUO, str(_estado.mi_pos)])
					return
				_paso = 1
				return
			_pasar_a("matar")


func _buscar_monstruo() -> bool:
	for id in _estado.criaturas:
		if int(id) == _estado.mi_id or _ids_previos.has(int(id)):
			continue
		var criatura: Dictionary = _estado.criaturas[id]
		if str(criatura.get("nombre", "")).to_lower() != MONSTRUO:
			continue
		_id_monstruo = int(id)
		_pos_monstruo = criatura.get("pos", Vector3i.ZERO)
		print("Invocado %s con id %d." % [MONSTRUO, _id_monstruo])
		_con.enviar_modos_combate(1, 1, 0)
		_con.enviar_atacar(_id_monstruo)
		return true
	return false


func _contenedor_en(posicion: Vector3i) -> Dictionary:
	for cosa in _estado.casillas.get(posicion, []):
		var c: Dictionary = cosa
		if c.get("tipo") == "item" and bool(c.get("contenedor", false)) \
				and not bool(c.get("suelo", false)) \
				and str(c.get("nombre", "")).to_lower().begins_with("dead "):
			return c
	return {}


## `/killall` (servidor/data/scripts/talkactions/god/kill_creatures.lua)
## ejecuta un Combat con AREA_SQUARE1X1 centrado en la posicion propia de
## quien lo dice (servidor/data/scripts/spells/areas.lua: matriz 3x3, radio
## Chebyshev 1) y mata a todo monstruo dentro de esa area, no solo al
## objetivo. Antes de emitirlo hay que confirmar que ninguna otra criatura
## viva distinta de la rata de esta corrida esta dentro de esa misma area.
func _area_de_killall_segura(centro: Vector3i) -> bool:
	for id in _estado.criaturas:
		if int(id) == _estado.mi_id or int(id) == _id_monstruo:
			continue
		var criatura: Dictionary = _estado.criaturas[id]
		if int(criatura.get("vida", 100)) <= 0:
			continue
		var pos: Vector3i = criatura.get("pos", Vector3i.ZERO)
		if pos.z != centro.z:
			continue
		if absi(pos.x - centro.x) <= 1 and absi(pos.y - centro.y) <= 1:
			return false
	return true


func _vigilar_al_monstruo() -> void:
	if _estado.criaturas.has(_id_monstruo) \
			and int(_estado.criaturas[_id_monstruo].get("vida", 100)) > 0:
		_pos_monstruo = _estado.criaturas[_id_monstruo].get("pos", _pos_monstruo)
		if _espera > 6.0:
			_espera = 0.0
			if _area_de_killall_segura(_estado.mi_pos):
				_con.enviar_hablar("/killall")
			else:
				print("  otra criatura viva esta dentro del area de /killall (AREA_SQUARE1X1, radio 1 sobre %s); no se emite para evitar dano colateral" % str(_estado.mi_pos))
		return
	if _corpse_monstruo.is_empty():
		for donde in _estado.casillas:
			if _corpses_previos.has(donde):
				continue
			var cosa := _contenedor_en(donde)
			if not cosa.is_empty() \
					and str(cosa.get("nombre", "")).to_lower().contains(MONSTRUO):
				_corpse_monstruo = cosa
				_pos_monstruo = donde
				break
	if _corpse_monstruo.is_empty():
		if not _estado.mapa_alineado:
			_fallar("FAIL mapa desalineado antes de poder certificar el corpse del monstruo")
			return
		return
	print("Corpse encontrado en %s: %s" % [str(_pos_monstruo), str(_corpse_monstruo.get("nombre", ""))])
	if absi(_estado.mi_pos.x - _pos_monstruo.x) > 1 \
			or absi(_estado.mi_pos.y - _pos_monstruo.y) > 1 \
			or _estado.mi_pos.z != _pos_monstruo.z:
		_con.enviar_hablar("/gotopos %d,%d,%d" % [_pos_monstruo.x, _pos_monstruo.y, _pos_monstruo.z])
		_pasar_a("acercarse al corpse")
		return
	_pasar_a("saquear")
	_abrir_corpse()


func _acercarse_al_corpse() -> void:
	if _espera < ESPERA_ORDEN:
		return
	_pasar_a("saquear")
	_abrir_corpse()


func _abrir_corpse() -> void:
	var cosa := _contenedor_en(_pos_monstruo)
	if not cosa.is_empty():
		_corpse_monstruo = cosa
	var pila := 0
	for elemento in _estado.casillas.get(_pos_monstruo, []):
		if elemento == _corpse_monstruo:
			break
		pila += 1
	_con.enviar_usar_item(_pos_monstruo, int(_corpse_monstruo.get("cid", 0)), pila)


func _al_contenedor(_id: int, datos: Dictionary) -> void:
	_nombre_corpse = str(datos.get("nombre", ""))
	if _nombre_corpse.is_empty():
		_fallar("FAIL el corpse no se abrio como contenedor real")
		return
	print("Corpse abierto como contenedor: '%s'." % _nombre_corpse)
	_emitir_observacion()


func _emitir_observacion() -> void:
	## `_nombre_corpse` se serializa TAL CUAL lo emitio el servidor: la
	## comparacion en minusculas (`.to_lower()`) solo se usa como logica de
	## descubrimiento en `_buscar_monstruo`/`_contenedor_en` para localizar el
	## corpse; el hecho observado versionado nunca se normaliza aca. Si TVP
	## emitiera una capitalizacion distinta de "dead rat", esta observacion la
	## preserva y es `qa/parity/tools/replay.py` quien decide PASS/FAIL contra
	## la expectativa publicada, sin que la captura oculte la diferencia.
	var payload := {
		"monster_kind": MONSTRUO,
		"corpse": {
			"present": true,
			"name": _nombre_corpse,
			"openable_container": true,
		},
	}
	var linea := "OBSERVATION_JSON: " + JSON.stringify(payload)
	print(linea)
	print("Prueba de captura en vivo (monster corpse): OK")
	_terminar(0)


func _registrar_mapa_desalineado(detalle: Dictionary) -> void:
	print("  MAPA DESALINEADO: %s" % str(detalle))


func _fallar(texto: String) -> void:
	print(texto)
	_terminar(1)


func _terminar(codigo: int) -> void:
	_terminando = true
	if _con != null:
		_con.cerrar()
	get_tree().quit(codigo)
