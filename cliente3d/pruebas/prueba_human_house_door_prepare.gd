extends Node
## Preparador reversible del fixture humano de puerta de House 83.
## Usa un unico cliente GOD y exclusivamente las APIs semanticas de Conexion772.
## No acciona la puerta como actor B ni produce fixture, QACase u observacion.

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

const HOUSE_ID := 83
const HOUSE_NAME := "Mill Avenue 3"
const TEMP_OWNER := "Guillermo Knight"
const ACTOR_B := "Valentino"
const DOOR_POS := Vector3i(32410, 32185, 7)
const DOOR_SIDE := Vector3i(32410, 32186, 7)
const CLOSED_SERVER_ID := 1221
const OPEN_SERVER_ID := 1222
const SPELL_GUEST := "aleta sio"
const SPELL_SUBOWNER := "aleta som"
const SPELL_DOOR := "aleta grav"
const ACTION_TIMEOUT := 15.0
const TOTAL_TIMEOUT := 240.0

var _login
var _con
var _estado
var _port := 0
var _mode := ""
var _plan: Array[Dictionary] = []
var _index := -1
var _action_elapsed := 0.0
var _total := 0.0
var _sent := false
var _finish_after := -1.0
var _ending := false
var _tile_seen := false
var _tile_lines: Array[String] = []


func _ready() -> void:
	_mode = _read_mode()
	if not _mode in ["inspect", "arm1", "arm2", "cleanup"]:
		_fail("BLOCKED use --mode=inspect|arm1|arm2|cleanup")
		return
	if not CREDENCIALES.exigir(self, ["TVP772_GOD_ACCOUNT",
			"TVP772_GOD_PASSWORD", "TVP772_GOD_CHARACTER"]):
		return
	print("QA_HOUSE_DOOR_PREP mode=%s house=%d name=%s" % [_mode, HOUSE_ID, HOUSE_NAME])
	_open_login()


func _read_mode() -> String:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--mode="):
			return str(arg).trim_prefix("--mode=").to_lower()
	return ""


func _process(delta: float) -> void:
	if _ending:
		return
	_total += delta
	if _total > TOTAL_TIMEOUT:
		_fail("BLOCKED preparer total timeout")
		return
	if _index < 0:
		return
	_action_elapsed += delta
	if _finish_after >= 0.0 and _action_elapsed >= _finish_after:
		_advance()
		return
	if _action_elapsed > ACTION_TIMEOUT:
		_fail("BLOCKED action timeout kind=%s label=%s" % [
			_current().get("kind", ""), _current().get("label", "")])
		return
	if not _sent:
		_start_current()
		return
	if _current().get("kind") == "goto":
		var wanted: Vector3i = _current()["pos"]
		if _estado != null and _estado.mi_pos == wanted and _action_elapsed > 0.5:
			_advance()


func _open_login() -> void:
	_login = CONEXION.new()
	add_child(_login)
	_login.error_red.connect(func(t): _fail("BLOCKED login network error: %s" % t))
	_login.lista_personajes.connect(_on_characters)
	_login.pedir_personajes(CREDENCIALES.host(), CREDENCIALES.puerto_login(),
		CREDENCIALES.entero("TVP772_GOD_ACCOUNT"),
		CREDENCIALES.texto("TVP772_GOD_PASSWORD"))


func _on_characters(_motd, characters: Array) -> void:
	var wanted := CREDENCIALES.texto("TVP772_GOD_CHARACTER")
	for entry in characters:
		if str(entry.get("nombre", "")) == wanted:
			_port = int(entry.get("puerto", 0))
	if _port <= 0:
		_fail("BLOCKED TVP772_GOD_CHARACTER not found")
		return
	_login.cerrar()
	_estado = ESTADO.new()
	_estado.pedido_ping.connect(func(): _con.enviar_respuesta_ping())
	_estado.rechazados.connect(func(m): _fail("BLOCKED GOD rejected: %s" % m))
	_estado.mensaje_servidor.connect(_on_message)
	_estado.ventana_casa.connect(_on_house_window)
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(func(t):
		if not _ending:
			_fail("BLOCKED game network error: %s" % t))
	_con.paquete_juego.connect(func(m): _estado.procesar(m))
	_con.entrar_al_mundo(CREDENCIALES.host(), _port,
		CREDENCIALES.entero("TVP772_GOD_ACCOUNT"), wanted,
		CREDENCIALES.texto("TVP772_GOD_PASSWORD"))
	await get_tree().create_timer(2.0).timeout
	if not _estado.adentro:
		_fail("BLOCKED GOD did not enter world")
		return
	_build_plan()
	_index = 0


func _build_plan() -> void:
	var empty: Array[String] = []
	var actor: Array[String] = [ACTOR_B]
	_plan = [_goto(DOOR_SIDE)]
	if _mode == "inspect":
		_plan.append_array([_tile_any("inspect"), _list("guest", SPELL_GUEST), _list("subowner", SPELL_SUBOWNER),
			_turn_north(), _list("door", SPELL_DOOR)])
	elif _mode == "arm1":
		_plan.append_array([
			_close_door(), _tile_closed("arm1 baseline normalized"),
			_owner_set(),
			_list("guest preflight", SPELL_GUEST, empty),
			_list("subowner preflight", SPELL_SUBOWNER, empty),
			_turn_north(), _list("door preflight", SPELL_DOOR, empty),
			_list_set("guest set", SPELL_GUEST, actor),
			_list("guest verify", SPELL_GUEST, actor),
			_list_set("subowner clear", SPELL_SUBOWNER, empty),
			_list("subowner verify", SPELL_SUBOWNER, empty),
			_turn_north(), _list_set("door clear", SPELL_DOOR, empty),
			_turn_north(), _list("door verify", SPELL_DOOR, empty),
			_tile_closed("arm1 final")])
	elif _mode == "arm2":
		_plan.append_array([
			_tile_closed("arm2 baseline"),
			_list("guest preflight", SPELL_GUEST, actor),
			_list("subowner preflight", SPELL_SUBOWNER, empty),
			_turn_north(), _list("door preflight", SPELL_DOOR, empty),
			_list_set("subowner set", SPELL_SUBOWNER, actor),
			_list("guest verify", SPELL_GUEST, actor),
			_list("subowner verify", SPELL_SUBOWNER, actor),
			_turn_north(), _list("door verify", SPELL_DOOR, empty),
			_tile_closed("arm2 final")])
	else:
		_plan.append_array([
			_list("guest before cleanup", SPELL_GUEST),
			_list("subowner before cleanup", SPELL_SUBOWNER),
			_turn_north(), _list("door before cleanup", SPELL_DOOR),
			_turn_north(), _list_set("door clear", SPELL_DOOR, empty),
			_list_set("subowner clear", SPELL_SUBOWNER, empty),
			_list_set("guest clear", SPELL_GUEST, empty),
			_close_door(), _tile_closed("cleanup door"),
			_owner_none(),
			_list("guest cleanup verify", SPELL_GUEST, empty),
			_list("subowner cleanup verify", SPELL_SUBOWNER, empty),
			_turn_north(), _list("door cleanup verify", SPELL_DOOR, empty),
			_tile_closed("cleanup final")])


func _goto(pos: Vector3i) -> Dictionary:
	return {"kind": "goto", "pos": pos}

func _turn_north() -> Dictionary:
	return {"kind": "turn", "label": "north"}

func _tile_closed(label: String) -> Dictionary:
	return {"kind": "tile", "label": label}

func _tile_any(label: String) -> Dictionary:
	return {"kind": "tile", "label": label, "allow_open": true}

func _list(label: String, spell: String, expected = null) -> Dictionary:
	return {"kind": "list", "label": label, "spell": spell, "expected": expected}

func _list_set(label: String, spell: String, entries: Array[String]) -> Dictionary:
	return {"kind": "list", "label": label, "spell": spell,
		"expected": null, "write": entries}

func _close_door() -> Dictionary:
	return {"kind": "close_door", "label": "close"}

func _owner_none() -> Dictionary:
	return {"kind": "owner_none", "label": "owner 0"}

func _owner_set() -> Dictionary:
	return {"kind": "owner_set", "label": "owner 4"}

func _current() -> Dictionary:
	return _plan[_index]


func _start_current() -> void:
	_sent = true
	var action := _current()
	match str(action.get("kind", "")):
		"goto":
			var p: Vector3i = action["pos"]
			_con.enviar_hablar("/gotopos %d,%d,%d" % [p.x, p.y, p.z])
		"turn":
			_con.enviar_giro_norte()
			_finish_after = 1.2
		"tile":
			_tile_seen = false
			_tile_lines.clear()
			_con.enviar_hablar("/tileinfo %d,%d,%d" % [DOOR_POS.x, DOOR_POS.y, DOOR_POS.z])
		"list":
			_con.enviar_hablar(str(action["spell"]))
		"close_door":
			_start_close_door()
		"owner_none":
			_con.enviar_hablar("/owner none")
			_finish_after = 2.0
		"owner_set":
			_con.enviar_hablar("/owner %s" % TEMP_OWNER)
			_finish_after = 2.0


func _on_house_window(data: Dictionary) -> void:
	if _index < 0 or _current().get("kind") != "list":
		return
	var action := _current()
	var text := str(data.get("texto", ""))
	var actual := _entries(text)
	print("QA_HOUSE_LIST label=%s entries=%s" % [action.get("label"), JSON.stringify(actual)])
	var expected = action.get("expected")
	if expected != null and not _same_entries(actual, expected):
		_fail("BLOCKED unexpected live list label=%s expected=%s actual=%s" % [
			action.get("label"), JSON.stringify(expected), JSON.stringify(actual)])
		return
	if action.has("write"):
		var window_id := int(data.get("id", 0))
		if window_id <= 0:
			_fail("BLOCKED unusable house window id")
			return
		var replacement := _text_with_entries(text, action["write"])
		_con.enviar_lista_acceso_casa(window_id, replacement)
		print("QA_HOUSE_LIST_WRITE semantic_api=true label=%s" % action.get("label"))
	_finish_after = 2.2


func _entries(text: String) -> Array[String]:
	var result: Array[String] = []
	for raw in text.split("\n", false):
		var line := str(raw).strip_edges()
		if not line.is_empty() and not line.begins_with("#"):
			result.append(line)
	return result


func _same_entries(left: Array[String], right: Array) -> bool:
	if left.size() != right.size():
		return false
	for i in left.size():
		if left[i].to_lower() != str(right[i]).to_lower():
			return false
	return true


func _text_with_entries(base: String, entries: Array) -> String:
	var lines: Array[String] = []
	for raw in base.split("\n", false):
		var line := str(raw).strip_edges()
		if line.begins_with("#"):
			lines.append(line)
	for entry in entries:
		lines.append(str(entry))
	return "\n".join(lines) + "\n"


func _on_message(text: String) -> void:
	if _index < 0 or _current().get("kind") != "tile":
		return
	var prefix := "tileinfo %d,%d,%d:" % [DOOR_POS.x, DOOR_POS.y, DOOR_POS.z]
	if text.begins_with(prefix):
		_tile_seen = true
		_tile_lines = [text]
		_finish_after = 1.0
	elif _tile_seen and text.begins_with("  item "):
		_tile_lines.append(text)


func _validate_tile() -> bool:
	var joined := "\n".join(_tile_lines)
	if not joined.contains("house=%d" % HOUSE_ID):
		_fail("BLOCKED door tile is not House 83")
		return false
	if bool(_current().get("allow_open", false)):
		if joined.contains("item %d " % CLOSED_SERVER_ID):
			print("QA_HOUSE_DOOR_TILE label=%s house=83 server_item=1221 state=CLOSED" % _current().get("label"))
			return true
		if joined.contains("item %d " % OPEN_SERVER_ID):
			print("QA_HOUSE_DOOR_TILE label=%s house=83 server_item=1222 state=OPEN" % _current().get("label"))
			return true
		_fail("BLOCKED door tile has neither server item 1221 nor 1222")
		return false
	if not joined.contains("item %d " % CLOSED_SERVER_ID) or not joined.contains("closed door"):
		_fail("BLOCKED door is not server item 1221 closed door")
		return false
	if joined.contains("item %d " % OPEN_SERVER_ID):
		_fail("BLOCKED open server item 1222 still present")
		return false
	print("QA_HOUSE_DOOR_TILE label=%s house=83 server_item=1221 state=CLOSED" % _current().get("label"))
	return true


func _start_close_door() -> void:
	var things: Array = _estado.casillas.get(DOOR_POS, [])
	for i in range(things.size() - 1, -1, -1):
		var thing: Dictionary = things[i]
		if thing.get("tipo") != "item" or bool(thing.get("suelo", false)):
			continue
		var name := str(thing.get("nombre", "")).to_lower()
		if name == "closed door":
			_finish_after = 0.2
			return
		if name == "open door":
			_con.enviar_usar_item(DOOR_POS, int(thing.get("cid", 0)), i)
			_finish_after = 2.0
			return
	_fail("BLOCKED client cannot identify door for cleanup")


func _advance() -> void:
	if _current().get("kind") == "tile" and not _validate_tile():
		return
	_index += 1
	_action_elapsed = 0.0
	_sent = false
	_finish_after = -1.0
	if _index >= _plan.size():
		print("QA_HOUSE_DOOR_PREP_OK mode=%s actor=%s" % [_mode, ACTOR_B])
		_end(0)


func _fail(message: String) -> void:
	print(message)
	_end(2)


func _end(code: int) -> void:
	if _ending:
		return
	_ending = true
	if _con != null:
		_con.enviar_logout()
		await get_tree().create_timer(1.0).timeout
		_con.cerrar()
	print("EXITCODE=%d" % code)
	get_tree().quit(code)
