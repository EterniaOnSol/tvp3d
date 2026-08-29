extends Node

# Prueba viva de la reacquisicion de objetivo de Monster.
#
# Un rat golpea a Valentino; el servidor mueve al jugador fuera de la ventana
# visible y lo devuelve enseguida. La prueba exige un golpe antes y otro
# despues del regreso. Ningun cliente decide posiciones ni dano: `/gotopos`,
# `/c`, `/m`, `/killall` y `omani` son ordenes del servidor para QA.

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const HOST := "127.0.0.1"
const PUERTO_LOGIN := 7171
const CUENTA := 123456
const CLAVE := "123456"
const PERSONAJE_GOD := "GOD VALENTINO"
const PERSONAJE := "Valentino"
const MONSTRUO := "cave rat"

# Las dos casillas existen en el OTBM, son del mismo piso, no son casa ni PZ
# y quedan a 39 SQM: suficiente para disparar leave/enter del spectator range.
const POS_CAMPO := Vector3i(32082, 32145, 6)
const POS_LEJOS := Vector3i(32083, 32184, 6)
const RADIO_LLEGADA := 2

const PAUSA_SESION := 6.0
const ESPERA_PASO := 15.0
const ESPERA_GOLPE := 45.0
const LIMITE_TOTAL := 180.0

var _con_login
var _con_god
var _con_personaje
var _estado_god
var _estado_personaje
var _puertos := {}
var _fase := "login"
var _espera := 0.0
var _total := 0.0
var _fallas := 0
var _terminando := false
var _ids_antes := {}
var _id_monstruo := 0
var _vida_inicial := -1
var _vida_primer_golpe := -1
var _vida_al_volver := -1
var _golpes_monstruo := 0
var _golpes_al_salir := 0
var _intentos_limpieza := 0


func _ready() -> void:
	print("=================================================")
	print(" TVP3D - reacquisicion viva de monstruo")
	print("=================================================")
	_abrir_login()


func _process(delta: float) -> void:
	_total += delta
	_espera += delta
	if _terminando:
		return
	if _total > LIMITE_TOTAL:
		_error("Tiempo agotado en la fase '%s'" % _fase)
		return
	match _fase:
		"esperar god":
			if _estado_god != null and _estado_god.adentro and _espera > 2.0:
				_pasar_a("pausa segundo cliente")
		"pausa segundo cliente":
			if _espera >= PAUSA_SESION:
				_abrir_personaje()
		"esperar personaje":
			if _estado_personaje != null and _estado_personaje.adentro \
					and _espera > 2.0:
				_preparar_campo()
		"esperar god en campo":
			_esperar_god_en(POS_CAMPO, "reunir en campo")
		"reunir en campo":
			_reunir_en(POS_CAMPO, "limpiar campo")
		"limpiar campo":
			if _espera > 2.0:
				_limpiar_campo()
		"invocar":
			if _espera > 2.0:
				_invocar()
		"esperar monstruo":
			_esperar_monstruo()
		"esperar primer golpe":
			_esperar_primer_golpe()
		"esperar god lejos":
			_esperar_god_en(POS_LEJOS, "reunir lejos")
		"reunir lejos":
			_reunir_en(POS_LEJOS, "volver god al campo")
		"volver god al campo":
			_con_god.enviar_hablar(_orden_gotopos(POS_CAMPO))
			_pasar_a("esperar god de vuelta")
		"esperar god de vuelta":
			_esperar_god_en(POS_CAMPO, "reunir de vuelta")
		"reunir de vuelta":
			_reunir_en(POS_CAMPO, "esperar segundo golpe")
		"esperar segundo golpe":
			_esperar_segundo_golpe()
		"limpiar":
			_acercar_limpieza()
		"esperar god para limpiar":
			_esperar_god_para_limpiar()
		"confirmar limpieza":
			_confirmar_limpieza()
		"devolver templo":
			_devolver_al_templo()
		"esperar salida campo":
			_esperar_salida_campo()


# -----------------------------------------------------------------
# Sesiones
# -----------------------------------------------------------------
func _abrir_login() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.error_red.connect(func(texto): _error("Login: " + texto))
	_con_login.lista_personajes.connect(_al_lista)
	_con_login.pedir_personajes(HOST, PUERTO_LOGIN, CUENTA, CLAVE)


func _al_lista(_motd: String, personajes: Array) -> void:
	for entrada in personajes:
		_puertos[str(entrada.get("nombre", ""))] = int(entrada.get("puerto", 0))
	if int(_puertos.get(PERSONAJE_GOD, 0)) <= 0 \
			or int(_puertos.get(PERSONAJE, 0)) <= 0:
		_error("La cuenta no tiene los dos personajes de la prueba")
		return
	_con_login.cerrar()
	_con_login.queue_free()
	_con_login = null
	_abrir_god()


func _abrir_god() -> void:
	_estado_god = ESTADO.new()
	_estado_god.pedido_ping.connect(func():
		_con_god.enviar_juego(PackedByteArray([0x1E])))
	_estado_god.mensaje_servidor.connect(func(texto): print("  [god] ", texto))
	_con_god = CONEXION.new()
	add_child(_con_god)
	_con_god.error_red.connect(func(texto):
		if not _terminando: _error("God: " + texto))
	_con_god.paquete_juego.connect(func(msg): _estado_god.procesar(msg))
	_con_god.entrar_al_mundo(HOST, int(_puertos[PERSONAJE_GOD]), CUENTA,
		PERSONAJE_GOD, CLAVE)
	_pasar_a("esperar god")


func _abrir_personaje() -> void:
	_estado_personaje = ESTADO.new()
	_estado_personaje.pedido_ping.connect(func():
		_con_personaje.enviar_juego(PackedByteArray([0x1E])))
	_estado_personaje.mensaje_servidor.connect(_al_mensaje_personaje)
	_con_personaje = CONEXION.new()
	add_child(_con_personaje)
	_con_personaje.error_red.connect(func(texto):
		if not _terminando: _error("%s: %s" % [PERSONAJE, texto]))
	_con_personaje.paquete_juego.connect(func(msg):
		_estado_personaje.procesar(msg))
	_con_personaje.entrar_al_mundo(HOST, int(_puertos[PERSONAJE]), CUENTA,
		PERSONAJE, CLAVE)
	_pasar_a("esperar personaje")


func _al_mensaje_personaje(texto: String) -> void:
	print("  [%s] " % PERSONAJE, texto)
	var normalizado := texto.to_lower()
	if normalizado.contains("attack by") and normalizado.contains(MONSTRUO):
		_golpes_monstruo += 1


# -----------------------------------------------------------------
# Recorrido vivo
# -----------------------------------------------------------------
func _preparar_campo() -> void:
	print("El servidor lleva al god al campo.")
	_con_god.enviar_hablar(_orden_gotopos(POS_CAMPO))
	_pasar_a("esperar god en campo")


func _esperar_god_en(destino: Vector3i, siguiente: String) -> void:
	if _estado_god.mi_pos == destino:
		_pasar_a(siguiente)
		return
	if _espera > ESPERA_PASO:
		_error("El god no llego a %s; quedo en %s" % [
			str(destino), str(_estado_god.mi_pos)])


func _reunir_en(destino: Vector3i, siguiente: String) -> void:
	if _cerca(_estado_personaje.mi_pos, destino):
		if siguiente == "esperar segundo golpe":
			_vida_al_volver = _vida()
			print("%s volvio con vida %d; esperando otro golpe." % [
				PERSONAJE, _vida_al_volver])
		_pasar_a(siguiente)
		return
	if _espera < 0.2:
		return
	if _espera < 0.5:
		_con_god.enviar_hablar("/c %s" % PERSONAJE)
	if _espera > ESPERA_PASO:
		_error("/c no llevo a %s cerca de %s; esta en %s" % [
			PERSONAJE, str(destino), str(_estado_personaje.mi_pos)])


func _limpiar_campo() -> void:
	print("Limpiando el cuadro antes de invocar.")
	_con_god.enviar_hablar("/killall")
	_pasar_a("invocar")


func _invocar() -> void:
	_ids_antes.clear()
	for id in _estado_personaje.criaturas:
		_ids_antes[int(id)] = true
	_vida_inicial = _vida()
	print("Campo listo con vida %d. Invocando %s." % [
		_vida_inicial, MONSTRUO])
	_con_god.enviar_hablar("/m %s" % MONSTRUO)
	_pasar_a("esperar monstruo")


func _esperar_monstruo() -> void:
	for id in _estado_personaje.criaturas:
		if _ids_antes.has(int(id)) or int(id) == _estado_personaje.mi_id:
			continue
		var criatura: Dictionary = _estado_personaje.criaturas[id]
		if str(criatura.get("nombre", "")).to_lower() == MONSTRUO:
			_id_monstruo = int(id)
			print("%s nuevo id %d visto por el personaje." % [
				MONSTRUO.capitalize(), _id_monstruo])
			_pasar_a("esperar primer golpe")
			return
	if _espera > ESPERA_PASO:
		_error("El %s invocado no aparecio para %s" % [MONSTRUO, PERSONAJE])


func _esperar_primer_golpe() -> void:
	var vida := _vida()
	if _golpes_monstruo > 0 and vida >= 0 and vida < _vida_inicial:
		_vida_primer_golpe = vida
		_golpes_al_salir = _golpes_monstruo
		_comprobar("el monstruo adquiere y golpea al jugador", true)
		print("Primer golpe: %d -> %d. Sacando al jugador de vista." % [
			_vida_inicial, _vida_primer_golpe])
		_con_god.enviar_hablar(_orden_gotopos(POS_LEJOS))
		_pasar_a("esperar god lejos")
		return
	if _espera > ESPERA_GOLPE:
		_error("El rat no golpeo: vida inicial %d, actual %d" % [
			_vida_inicial, vida])


func _esperar_segundo_golpe() -> void:
	var vida := _vida()
	if _golpes_monstruo > _golpes_al_salir \
			and vida >= 0 and vida < _vida_al_volver \
			and _monstruo_activo_cerca():
		_comprobar("el mismo monstruo reacquiere al jugador al volver", true)
		_comprobar("la reacquisicion conserva el id del monstruo",
			_estado_personaje.criaturas.has(_id_monstruo))
		print("Golpe tras volver: %d -> %d, %s id %d." % [
			_vida_al_volver, vida, MONSTRUO, _id_monstruo])
		_pasar_a("limpiar")
		return
	if _espera > ESPERA_GOLPE:
		_error("El jugador volvio pero el rat no retomo el ataque: vida %d" % vida)


func _acercar_limpieza() -> void:
	var criatura: Dictionary = _estado_personaje.criaturas.get(_id_monstruo, {})
	var posicion: Vector3i = criatura.get("pos", POS_CAMPO)
	print("Acercando el god al %s id %d en %s para limpiarlo." % [
		MONSTRUO, _id_monstruo, str(posicion)])
	_con_god.enviar_hablar(_orden_gotopos(posicion))
	_pasar_a("esperar god para limpiar")


func _esperar_god_para_limpiar() -> void:
	var criatura: Dictionary = _estado_personaje.criaturas.get(_id_monstruo, {})
	var posicion: Vector3i = criatura.get("pos", POS_CAMPO)
	if _cerca(_estado_god.mi_pos, posicion) or _espera > 3.0:
		print("Limpiando el %s en el cuadro del god." % MONSTRUO)
		_con_god.enviar_hablar("/killall")
		_pasar_a("confirmar limpieza")


func _confirmar_limpieza() -> void:
	if not _monstruo_activo():
		_comprobar("la limpieza retira al monstruo invocado", true)
		_pasar_a("devolver templo")
		return
	if _espera > 3.0:
		_intentos_limpieza += 1
		if _intentos_limpieza >= 3:
			_error("No se pudo retirar al %s id %d" % [MONSTRUO, _id_monstruo])
			return
		_pasar_a("limpiar")


func _devolver_al_templo() -> void:
	if _espera < 2.0:
		return
	print("Devolviendo a %s a su templo." % PERSONAJE)
	_con_god.enviar_hablar("omani %s" % PERSONAJE)
	_pasar_a("esperar salida campo")


func _esperar_salida_campo() -> void:
	if not _cerca(_estado_personaje.mi_pos, POS_CAMPO):
		_comprobar("la prueba deja al personaje fuera del campo", true)
		_terminar()
		return
	if _espera > ESPERA_PASO:
		_error("No se pudo devolver a %s al templo" % PERSONAJE)


# -----------------------------------------------------------------
# Utilidades
# -----------------------------------------------------------------
func _vida() -> int:
	return int(_estado_personaje.estadisticas.get("vida", -1))


func _monstruo_activo_cerca() -> bool:
	if not _monstruo_activo():
		return false
	var criatura: Dictionary = _estado_personaje.criaturas[_id_monstruo]
	var posicion: Vector3i = criatura.get("pos", Vector3i.ZERO)
	var jugador: Vector3i = _estado_personaje.mi_pos
	return posicion.z == jugador.z \
		and absi(posicion.x - jugador.x) <= 8 \
		and absi(posicion.y - jugador.y) <= 8


func _monstruo_activo() -> bool:
	return _estado_personaje.criaturas.has(_id_monstruo) \
		and int(_estado_personaje.criaturas[_id_monstruo].get("vida", 100)) > 0


func _cerca(posicion: Vector3i, centro: Vector3i) -> bool:
	return posicion.z == centro.z \
		and absi(posicion.x - centro.x) <= RADIO_LLEGADA \
		and absi(posicion.y - centro.y) <= RADIO_LLEGADA


func _orden_gotopos(posicion: Vector3i) -> String:
	return "/gotopos %d,%d,%d" % [posicion.x, posicion.y, posicion.z]


func _pasar_a(fase: String) -> void:
	print("  [%.0fs] fase: %s" % [_total, fase])
	_fase = fase
	_espera = 0.0


func _comprobar(nombre: String, correcto: bool) -> void:
	if correcto:
		print("  OK  " + nombre)
	else:
		_fallas += 1
		print("  FAIL " + nombre)


func _error(texto: String) -> void:
	print("  FAIL " + texto)
	_fallas += 1
	_terminar()


func _terminar() -> void:
	if _terminando:
		return
	_terminando = true
	# Limpieza defensiva: no deja un monstruo ni al personaje en el campo si
	# una asercion fallo a mitad del recorrido.
	if _con_god != null:
		_con_god.enviar_hablar("/killall")
		_con_god.enviar_hablar("omani %s" % PERSONAJE)
		_con_god.cerrar()
	if _con_personaje != null:
		_con_personaje.cerrar()
	if _fallas == 0:
		print("Prueba viva de reacquisicion de monstruo: OK")
	else:
		print("Prueba viva de reacquisicion de monstruo: %d fallas" % _fallas)
	get_tree().quit(1 if _fallas > 0 else 0)
