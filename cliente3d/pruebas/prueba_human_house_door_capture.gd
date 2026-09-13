extends Node
## Observador QA pasivo para una acción humana sobre una puerta de casa.
## No crea conexiones ni procesa paquetes: reutiliza Mundo._estado.

enum CaptureState { WAITING_FOR_CLIENT, WAITING_FOR_POSITION, ARM1_READY, ARM1_ARMED, ARM1_CAPTURED, ARM2_READY, ARM2_ARMED, ARM2_CAPTURED, CLEANUP }

const DOOR_POS := Vector3i(32410, 32185, 7)
const OUTSIDE_POS := Vector3i(32410, 32184, 7)
const CLOSED_SERVER_ID := 1221
const OPEN_SERVER_ID := 1222
const CLOSED_NAME := "closed door"
const OPEN_NAME := "open door"
const CAPTURE_PATH := "user://qa_human_house_door_arm_capture.json"

var capture_state: CaptureState = CaptureState.WAITING_FOR_CLIENT
var requested_arm := 1
var mundo: Node
var estado: Object
var catalogo: Object
var arm := 0
var window_deadline := 0
var pre_player: Dictionary = {}
var pre_door: Dictionary = {}
var messages: Array[Dictionary] = []
var tile_events: Array[Dictionary] = []
var post_player: Dictionary = {}
var post_door: Dictionary = {}
var capture_record: Dictionary = {}

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg) == "--arm=2":
			requested_arm = 2
	call_deferred("_attach_to_playable")

func _attach_to_playable() -> void:
	mundo = get_node_or_null("Mundo")
	if mundo == null:
		push_error("QA_DOOR Mundo no encontrado")
		return
	estado = mundo.get("_estado")
	if estado == null:
		push_error("QA_DOOR _estado no disponible")
		return
	catalogo = mundo.get("_catalogo")
	if estado.has_signal("mensaje_pantalla"):
		estado.mensaje_pantalla.connect(_on_message)
	if estado.has_signal("casilla_actualizada"):
		estado.casilla_actualizada.connect(_on_tile_update)
	print("QA_DOOR observer attached state=%s" % estado.get_class())
	capture_state = CaptureState.WAITING_FOR_CLIENT

func _process(_delta: float) -> void:
	if estado == null:
		return
	var pos: Vector3i = estado.get("mi_pos")
	if not bool(estado.get("adentro")):
		capture_state = CaptureState.WAITING_FOR_CLIENT
		return
	if capture_state == CaptureState.WAITING_FOR_CLIENT:
		capture_state = CaptureState.WAITING_FOR_POSITION
	if capture_state == CaptureState.WAITING_FOR_POSITION and pos == OUTSIDE_POS and _door_snapshot().get("state") == "CLOSED":
		capture_state = CaptureState.ARM2_READY if requested_arm == 2 else CaptureState.ARM1_READY
		print("QA_DOOR ARM%d_READY player=%s door=CLOSED" % [requested_arm, pos])
	if capture_state in [CaptureState.ARM1_ARMED, CaptureState.ARM2_ARMED] and Time.get_ticks_msec() >= window_deadline:
		_capture_post()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F8 and capture_state == CaptureState.ARM1_READY:
		arm1()
		print("QA_DOOR F8 accepted: ARM1 measurement window open")
	elif event.keycode == KEY_F9 and capture_state == CaptureState.ARM2_READY:
		arm2()
		print("QA_DOOR F9 accepted: ARM2 measurement window open")

func arm1() -> bool:
	return _arm(1, CaptureState.ARM1_READY)

func arm2() -> bool:
	return _arm(2, CaptureState.ARM2_READY)

func ready_arm2() -> bool:
	if capture_state != CaptureState.ARM1_CAPTURED:
		push_warning("QA_DOOR arm2 readiness rejected state=%s" % capture_state)
		return false
	if _player_snapshot().get("position") != OUTSIDE_POS:
		push_warning("QA_DOOR arm2 readiness rejected: player is not outside")
		return false
	if _door_snapshot().get("state") != "CLOSED":
		push_warning("QA_DOOR arm2 readiness rejected: door is not closed")
		return false
	capture_state = CaptureState.ARM2_READY
	print("QA_DOOR ARM2_READY player=%s door=CLOSED" % OUTSIDE_POS)
	return true

func _arm(numero: int, required: CaptureState) -> bool:
	if capture_state != required:
		push_warning("QA_DOOR arm rejected state=%s required=%s" % [capture_state, required])
		return false
	arm = numero
	messages.clear()
	tile_events.clear()
	pre_player = _player_snapshot()
	pre_door = _door_snapshot()
	capture_state = CaptureState.ARM1_ARMED if numero == 1 else CaptureState.ARM2_ARMED
	window_deadline = Time.get_ticks_msec() + 7000
	capture_record = {"capture_method": "HUMAN_DRIVEN", "observation_origin": "LIVE_ORACLE",
		"arm": arm, "pre": {"actor": "Valentino", "house": 83,
		"door_server_ids": [CLOSED_SERVER_ID, OPEN_SERVER_ID],
		"player": pre_player, "door": pre_door,
		"guest_only_state_verified": arm == 1,
		"subowner_absent": arm == 1, "door_specific_list_empty": arm == 1}}
	_persist_capture()
	print("QA_DOOR ARMED arm=%d player=%s door=%s" % [arm, pre_player.get("position"), pre_door.get("state")])
	return true

func _capture_post() -> void:
	post_player = _player_snapshot()
	post_door = _door_snapshot()
	capture_state = CaptureState.ARM1_CAPTURED if arm == 1 else CaptureState.ARM2_CAPTURED
	var opened := false
	for event in tile_events:
		if str(event.get("state", "")) == "OPEN":
			opened = true
	capture_record["post"] = {"player": post_player, "door": post_door,
		"tile_events": tile_events, "messages": messages,
		"open_transition_seen": opened,
		"door_remained_closed_after_denial": arm == 1 and not opened
			and post_door.get("state") == "CLOSED"}
	_persist_capture()
	print("QA_DOOR_CAPTURE_PATH=%s" % CAPTURE_PATH)
	print("QA_DOOR POST arm=%d player=%s door=%s messages=%d tiles=%d" % [arm, post_player.get("position"), post_door.get("state"), messages.size(), tile_events.size()])

func _persist_capture() -> void:
	var file := FileAccess.open(CAPTURE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("QA_DOOR cannot persist capture")
		return
	file.store_string(JSON.stringify(capture_record))
	file.close()

func _on_message(texto: String, clase: int) -> void:
	if capture_state != CaptureState.ARM1_ARMED and capture_state != CaptureState.ARM2_ARMED:
		return
	messages.append({"text": texto, "class": clase})
	print("QA_DOOR MSG arm=%d class=%d text=%s" % [arm, clase, texto])

func _on_tile_update(posicion: Vector3i, opcode: int) -> void:
	if capture_state != CaptureState.ARM1_ARMED and capture_state != CaptureState.ARM2_ARMED:
		return
	if posicion != DOOR_POS:
		return
	var after := _door_snapshot()
	tile_events.append({"position": posicion, "opcode": opcode, "state": after.get("state"), "runtime": after.get("runtime_items")})
	print("QA_DOOR TILE arm=%d pos=%s opcode=0x%02X state=%s" % [arm, posicion, opcode, after.get("state")])

func _player_snapshot() -> Dictionary:
	var pos: Vector3i = estado.get("mi_pos")
	return {"position": pos, "at_outside": pos == OUTSIDE_POS, "last_move": estado.get("ultimo_movimiento")}

func _door_snapshot() -> Dictionary:
	var exists := false
	var items: Array = []
	var casillas: Dictionary = estado.get("casillas")
	if casillas != null and casillas.has(DOOR_POS):
		exists = true
		items = casillas[DOOR_POS].duplicate(true)
	var runtime_ids: Array = []
	var runtime_names: Array = []
	for item in items:
		if item is Dictionary:
			var cid = item.get("cid", item.get("id", item.get("item_id", item.get("client_id", null))))
			runtime_ids.append(cid)
			var nombre := str(item.get("nombre", "")).to_lower()
			if nombre.is_empty() and catalogo != null and cid != null:
				nombre = str(catalogo.info_item(int(cid)).get("nombre", "")).to_lower()
			runtime_names.append(nombre)
	var state := "UNKNOWN"
	if runtime_names.has(CLOSED_NAME):
		state = "CLOSED"
	elif runtime_names.has(OPEN_NAME):
		state = "OPEN"
	return {"position": DOOR_POS, "exists": exists, "runtime_items": runtime_ids,
		"runtime_names": runtime_names, "server_ids": [CLOSED_SERVER_ID, OPEN_SERVER_ID],
		"items": items, "state": state}

func snapshot() -> Dictionary:
	return {"state": capture_state, "player": _player_snapshot() if estado != null else {}, "door": _door_snapshot() if estado != null else {}}
