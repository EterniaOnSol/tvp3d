extends Node

# Captura QA-owned en vivo: PERSISTENCIA DEL DEPOSITO PERSONAL a traves de una
# frontera de sesion real (Phase 2E). Fixture `PARITY-DEPOT-PERSISTENCE-001`.
#
# Adaptador NUEVO y SEPARADO. `prueba_depot_vivo.gd` es evidencia historica de
# implementacion y **no se toca ni se convierte** en el adaptador de paridad.
#
# Esta rama NO decide PASS/FAIL: lo hace `qa/parity/tools/replay.py` contra la
# `ParityExpectationV1` publicada. Este script solo observa y serializa.
#
# ---------------------------------------------------------------------------
# LA REGLA, VERIFICADA EN EL CODIGO VIGENTE DEL ORACLE
# ---------------------------------------------------------------------------
#
# 1. ACTIVACION POR ENTRADA A LA BALDOSA.
#    `servidor/data/scripts/movements/other/tiles.lua` (`moveeventStepIn`):
#
#        if Tile(position):hasFlag(TILESTATE_PROTECTIONZONE) then
#          ... busca un item de tipo depot en el 3x3 ...
#            creature:loadDepotLocker(getDepotId(depotItem:getUniqueId()))
#            ... si la posicion CAMBIO, manda
#                "Your depot contains N item(s)."
#
#    Es un evento `onStepIn`: **no se dispara si el personaje ya estaba parado
#    ahi** al conectarse. Ademas exige `creature:isPlayer()` y que NO este en
#    modo fantasma.
#
#    `Player::loadDepotLocker` (`servidor/src/player.cpp:763-777`) es lo que
#    deja `currentDepotItem` apuntando al locker de ESE jugador. Y el
#    `onStepOut` correspondiente llama `unloadDepotLocker`
#    (`player.cpp:779-789`), que lo vuelve a poner en null: salir de la
#    baldosa DESACTIVA de verdad.
#
# 2. DEPOSITO PERSONAL CONTRA MUEBLE DEL MAPA. Esta es la trampa del dominio.
#    `servidor/src/actions.cpp:221-234`:
#
#        if (container->getDepotLocker()) {
#            if (DepotLocker* myDepotLocker = player->currentDepotItem) {
#                openContainer = myDepotLocker;
#                if (myDepotLocker->getItemTypeCount(ITEM_DEPOT) == 0) {
#                    myDepotLocker->addItem(Item::CreateItem(ITEM_DEPOT, 1));
#                }
#            } else {
#                // Open depot as normal container
#                openContainer = container;
#            }
#        }
#
#    Sin activar, se abre **el mueble del mapa como contenedor comun**: se ve
#    igual y TAMBIEN acepta objetos, pero lo que se guarde ahi no es de nadie.
#    Por eso "se abrio un contenedor" NO alcanza como prueba, y este adaptador
#    exige las dos senales que solo existen con el deposito personal cargado:
#
#      a) el mensaje "Your depot contains ..." que manda el propio servidor
#         dentro de la MISMA rama que llama a `loadDepotLocker`;
#      b) que al abrir el mueble aparezca adentro el `depot chest`, que
#         `actions.cpp:225-227` crea solo sobre el locker personal.
#
# 3. DONDE VIVE LO GUARDADO. El cofre interno (`ITEM_DEPOT`) es el contenedor
#    real; el locker solo lo envuelve.
#
# 4. PERSISTENCIA. `IOLoginData` serializa el deposito DENTRO del archivo del
#    propio jugador, una linea `Depot = (<id>, { ... })` por locker
#    (`iologindata.cpp:767-784`), y lo vuelve a cargar con
#    `getDepotLocker(depotId, true)` al leer el archivo
#    (`iologindata.cpp:467-495`). Es persistencia POR JUGADOR.
#
# 5. EL GOD NO CAMBIA LA SEMANTICA. Lo unico que depende del grupo es la
#    CAPACIDAD: `Player::getMaxDepotItems` (`player.cpp:3876-3883`) usa
#    `group->maxDepotItems` solo si no es 0, y en
#    `servidor/data/XML/groups.xml` **todos** los grupos lo tienen en 0, asi
#    que todos caen al limite de `config.lua`. El camino de guardado y de
#    carga es identico para un jugador normal. Por eso el sujeto de esta
#    prueba es un PERSONAJE NORMAL de QA y el god solo lo posiciona.
#
# ---------------------------------------------------------------------------
# LA FRONTERA DE SESION TIENE QUE SER REAL
# ---------------------------------------------------------------------------
#
# No se simula nada. No se vacia el estado local, no se reabre el mismo
# contenedor y no se arma un segundo objeto de estado sobre la misma sesion.
# La primera sesion manda el logout legacy `0x14`, se espera a que el socket
# quede efectivamente cerrado, y recien entonces se abre una conexion de login
# y de juego COMPLETAMENTE NUEVA, con su propio `EstadoMundo`.
#
# Ademas, como el personaje queda parado sobre la baldosa al desconectarse, en
# la sesion nueva se sale y se vuelve a entrar: `onStepIn` no se dispara al
# conectarse, asi que sin ese paso la reactivacion no seria real.
#
# ---------------------------------------------------------------------------
# IDENTIDAD POR CANTIDADES, NUNCA POR NOMBRE SUELTO
# ---------------------------------------------------------------------------
#
# Todas las afirmaciones son RELACIONES antes/despues: +1 en el cofre, -1 en el
# cofre, +1 en la mochila. Asi la existencia de copias viejas del mismo tipo de
# objeto no puede producir un falso positivo. Ninguna cantidad absoluta, ningun
# id de item y ninguna coordenada entran al payload.
#
# ---------------------------------------------------------------------------
# ESTA CAPTURA NO PELEA Y NO CREA OBJETOS
# ---------------------------------------------------------------------------
#
# 0 ataques, 0 monstruos invocados, 0 muertes, 0 `/killall`. El objeto de
# prueba es uno que el sujeto YA POSEE; no se crea ninguno. Los unicos comandos
# del god son `/gotopos` y `/c`, auditables buscando `enviar_hablar`.
#
# ---------------------------------------------------------------------------
# CREDENCIALES: SOLO POR ENTORNO, NUNCA LITERALES, NUNCA IMPRESAS
# ---------------------------------------------------------------------------
#   TVP772_ACCOUNT            cuenta del DEPOT_SUBJECT
#   TVP772_PASSWORD
#   TVP772_PLAYER_CHARACTER   DEPOT_SUBJECT (personaje normal dedicado de QA)
#   TVP772_GOD_ACCOUNT        operador; solo posiciona, no toca objetos
#   TVP772_GOD_PASSWORD
#   TVP772_GOD_CHARACTER
# Opcionales:
#   TVP772_HOST, TVP772_LOGIN_PORT
#   TVP772_DEPOT_TEST_ITEM    nombre del objeto de prueba (def. "club")
#
#   ...Godot --headless --path cliente3d \
#       pruebas/prueba_parity_depot_persistence_capture.tscn

const CONEXION := preload("res://red/conexion772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const CREDENCIALES := preload("res://pruebas/credenciales_qa.gd")

## Geometria operativa del deposito de Thais, sacada del mapa del propio
## servidor y ya usada por la evidencia historica. Es METADATA DEL HARNESS:
## NUNCA entra al payload.
const POS_LOCKER := Vector3i(32354, 32231, 7)
const POS_BALDOSA := Vector3i(32354, 32230, 7)
## Casilla neutral para sacar al god del medio una vez que ya posiciono al
## sujeto: dos criaturas no comparten casilla y el sujeto tiene que poder
## caminar. Templo de Thais.
const POS_GOD_NEUTRAL := Vector3i(32369, 32241, 7)

## `CONST_SLOT_BACKPACK`.
const SLOT_MOCHILA := 3
## Ventanas de contenedor del CLIENTE. Son implementacion del harness y NO
## semantica de paridad: el fixture no congela ningun indice de ventana.
const VENTANA_MOCHILA := 0
const VENTANA_LOCKER := 1
const VENTANA_COFRE := 2

## Reintentos de una misma orden de caminata antes de darse por vencido.
const MAX_INTENTOS_CAMINATA := 6

const PAUSA_SESION := 8.0
const ESPERA_PASO := 25.0
const ESPERA_CORTA := 12.0
const LIMITE_TOTAL := 420.0

var _con_login
var _con_god
var _con
var _estado_god
var _estado
var _puerto_sujeto := 0
var _puerto_god := 0
var _fase := "login"
var _espera := 0.0
var _total := 0.0
var _terminando := false

var _cuenta := 0
var _clave := ""
var _cuenta_god := 0
var _clave_god := ""
var _nombre_sujeto := ""
var _nombre_god := ""
var _host := ""
var _puerto_login := 0
var _nombre_objeto := "club"

var _segunda_sesion := false
var _primera_cerrada := false
var _segunda_establecida := false

var _id_mochila := -1
var _id_locker := -1
var _id_cofre := -1
var _ids_vistos := {}
var _cofre_nombre := ""
var _locker_trae_cofre := false

## Mensaje autoritativo que el servidor manda DENTRO de la misma rama que
## llama a `loadDepotLocker`. El texto exacto no se congela: se normaliza al
## hecho booleano de que el deposito personal se cargo.
var _avisos_depot := 0
var _avisos_depot_sesion := 0

var _cid_objeto := 0
var _slot_origen := 0
var _antes_cofre := -1
var _antes_mochila := -1
var _antes_origen := -1

var _deposito_cargado := false
var _cofre_abierto := false
var _objeto_antes_de_guardar := false
var _guardado_mas_uno := false
var _origen_menos_uno := false
var _recargado := false
var _sigue_guardado := false
var _recuperado_cofre_menos_uno := false
var _recuperado_mochila_mas_uno := false

var _pidio_caminata := false
var _intentos_caminata := 0
var _indice_candidato := 0
var _pos_fuera := Vector3i.ZERO
var _obs := {}


func _ready() -> void:
	print("=========================================================")
	print(" TVP3D QA - captura en vivo: persistencia del deposito")
	print("=========================================================")
	var requeridas := ["TVP772_ACCOUNT", "TVP772_PASSWORD",
		"TVP772_PLAYER_CHARACTER", "TVP772_GOD_CHARACTER"]
	if not CREDENCIALES.exigir(self, requeridas):
		return
	_host = CREDENCIALES.host()
	_puerto_login = CREDENCIALES.puerto_login()
	_cuenta = CREDENCIALES.entero("TVP772_ACCOUNT")
	_clave = CREDENCIALES.texto("TVP772_PASSWORD")
	_nombre_sujeto = CREDENCIALES.texto("TVP772_PLAYER_CHARACTER")
	_nombre_god = CREDENCIALES.texto("TVP772_GOD_CHARACTER")
	# El god puede vivir en otra cuenta. Por defecto, la del sujeto.
	_cuenta_god = _cuenta
	_clave_god = _clave
	if CREDENCIALES.esta_definida("TVP772_GOD_ACCOUNT"):
		_cuenta_god = CREDENCIALES.entero("TVP772_GOD_ACCOUNT")
	if CREDENCIALES.esta_definida("TVP772_GOD_PASSWORD"):
		_clave_god = CREDENCIALES.texto("TVP772_GOD_PASSWORD")
	var item_env := CREDENCIALES.texto("TVP772_DEPOT_TEST_ITEM")
	if not item_env.is_empty():
		_nombre_objeto = item_env.to_lower()
	if _nombre_sujeto == _nombre_god:
		print("BLOCKED el sujeto del deposito y el operador no pueden ser el mismo personaje")
		get_tree().quit(2)
		return
	_abrir_login_sujeto()


func _process(delta: float) -> void:
	_total += delta
	_espera += delta
	if _terminando:
		return
	if _total > LIMITE_TOTAL:
		_fallar("FAIL tiempo agotado en la fase '%s'" % _fase)
		return
	match _fase:
		"esperar god":
			if _estado_god != null and _estado_god.adentro and _espera > 2.0:
				print("Operador dentro; abriendo la PRIMERA sesion del sujeto.")
				_abrir_sujeto()
				_pasar_a("esperar primera sesion")
		"esperar primera sesion":
			if _espera > ESPERA_PASO:
				_fallar("BLOCKED el sujeto no llego a entrar al mundo en la primera sesion")
		"esperar mundo nuevo":
			if _espera > ESPERA_PASO:
				_fallar("BLOCKED el sujeto no llego a entrar al mundo en la sesion nueva")
		"god al depot":
			_god_al_depot()
		"esperar god depot":
			if _cerca(_estado_god.mi_pos, POS_BALDOSA, 0):
				_traer_sujeto()
			elif _espera > ESPERA_CORTA:
				_fallar("BLOCKED el operador no llego a la casilla operativa")
		"esperar sujeto cerca":
			_esperar_sujeto_cerca()
		"apartar god":
			_apartar_god()
		"esperar god lejos":
			_esperar_god_lejos()
		"salir de la baldosa":
			_salir_de_la_baldosa()
		"entrar a la baldosa":
			_entrar_a_la_baldosa()
		"confirmar activacion":
			_confirmar_activacion()
		"abrir mochila":
			_abrir_mochila()
		"abrir locker":
			_abrir_locker()
		"abrir cofre":
			_abrir_cofre()
		"elegir objeto":
			_elegir_objeto()
		"verificar guardado":
			_verificar_guardado()
		"cerrar sesion":
			_cerrar_sesion()
		"pausa reingreso":
			if _espera >= PAUSA_SESION:
				_entrar_de_nuevo()
		"verificar persistencia":
			_verificar_persistencia()
		"recuperar":
			_recuperar()
		"verificar recuperado":
			_verificar_recuperado()
		"restaurar":
			_restaurar()


# -----------------------------------------------------------------
#  Sesiones
# -----------------------------------------------------------------
func _abrir_login_sujeto() -> void:
	_con_login = CONEXION.new()
	add_child(_con_login)
	_con_login.error_red.connect(func(t): _fallar("FAIL fallo de red en login del sujeto: %s" % t))
	_con_login.lista_personajes.connect(func(_m, lista):
		for entrada in lista:
			if str(entrada.get("nombre", "")) == _nombre_sujeto:
				_puerto_sujeto = int(entrada.get("puerto", 0))
		if _puerto_sujeto <= 0:
			_fallar("FAIL character configured by TVP772_PLAYER_CHARACTER was not found")
			return
		_con_login.cerrar()
		_abrir_login_god())
	_con_login.pedir_personajes(_host, _puerto_login, _cuenta, _clave)


func _abrir_login_god() -> void:
	var login = CONEXION.new()
	add_child(login)
	login.error_red.connect(func(t): _fallar("FAIL fallo de red en login del operador: %s" % t))
	login.lista_personajes.connect(func(_m, lista):
		for entrada in lista:
			if str(entrada.get("nombre", "")) == _nombre_god:
				_puerto_god = int(entrada.get("puerto", 0))
		if _puerto_god <= 0:
			_fallar("FAIL character configured by TVP772_GOD_CHARACTER was not found")
			return
		login.cerrar()
		_abrir_god())
	login.pedir_personajes(_host, _puerto_login, _cuenta_god, _clave_god)


func _abrir_god() -> void:
	_estado_god = ESTADO.new()
	_estado_god.pedido_ping.connect(func(): _con_god.enviar_juego(PackedByteArray([0x1E])))
	_estado_god.rechazados.connect(func(m): _fallar("FAIL el operador fue rechazado: %s" % m))
	_con_god = CONEXION.new()
	add_child(_con_god)
	_con_god.error_red.connect(func(t):
		if not _terminando: _fallar("FAIL fallo de red del operador: %s" % t))
	_con_god.paquete_juego.connect(func(m): _estado_god.procesar(m))
	_con_god.entrar_al_mundo(_host, _puerto_god, _cuenta_god, _nombre_god, _clave_god)
	_pasar_a("esperar god")


## Abre una sesion de juego COMPLETAMENTE NUEVA para el sujeto: conexion nueva
## y `EstadoMundo` nuevo. No se reutiliza nada de la sesion anterior.
func _abrir_sujeto() -> void:
	_estado = ESTADO.new()
	_estado.pedido_ping.connect(func(): _con.enviar_juego(PackedByteArray([0x1E])))
	_estado.rechazados.connect(func(m): _fallar("FAIL el sujeto fue rechazado: %s" % m))
	_estado.mensaje_servidor.connect(_al_mensaje)
	_estado.contenedor_actualizado.connect(_al_contenedor)
	_estado.entramos.connect(_al_entrar_al_mundo)
	_con = CONEXION.new()
	add_child(_con)
	_con.error_red.connect(func(t):
		if _fase != "cerrar sesion" and not _terminando:
			_fallar("FAIL fallo de red del sujeto: %s" % t))
	_con.paquete_juego.connect(func(m): _estado.procesar(m))
	_con.cerrada.connect(_al_cerrarse)
	_con.entrar_al_mundo(_host, _puerto_sujeto, _cuenta, _nombre_sujeto, _clave)


func _al_entrar_al_mundo() -> void:
	if not _segunda_sesion:
		print("Primera sesion del sujeto establecida.")
		_pasar_a("god al depot")
		return
	_segunda_establecida = true
	print("Sesion NUEVA establecida: el sujeto volvio a entrar al mundo.")
	_pasar_a("salir de la baldosa")


func _al_cerrarse() -> void:
	if _terminando:
		return
	if not _segunda_sesion:
		_segunda_sesion = true
		_primera_cerrada = true
		print("Primera sesion CERRADA de verdad: el socket de juego quedo cerrado.")
		_pasar_a("pausa reingreso")
		return


func _entrar_de_nuevo() -> void:
	if _con != null:
		_con.queue_free()
		_con = null
	_estado = null
	_id_mochila = -1
	_id_locker = -1
	_id_cofre = -1
	_ids_vistos = {}
	_avisos_depot_sesion = 0
	_locker_trae_cofre = false
	print("Abriendo una sesion de login y de juego COMPLETAMENTE NUEVA.")
	_abrir_sujeto()
	_pasar_a("esperar mundo nuevo")


func _al_mensaje(texto: String) -> void:
	print("  [srv] %s" % texto)
	# `tiles.lua` manda este aviso DENTRO de la misma rama que llama a
	# `loadDepotLocker`, asi que su llegada es prueba autoritativa de que el
	# servidor cargo el deposito PERSONAL de este jugador. El texto exacto no
	# se congela: se normaliza a un booleano.
	if texto.begins_with("Your depot contains"):
		_avisos_depot += 1
		_avisos_depot_sesion += 1


func _al_contenedor(id: int, datos: Dictionary) -> void:
	var nombre := str(datos.get("nombre", ""))
	var cantidad: int = (datos.get("items", []) as Array).size()
	if not _ids_vistos.has(id):
		_ids_vistos[id] = nombre
		print("  contenedor %d abierto: '%s' con %d cosas." % [id, nombre, cantidad])


# -----------------------------------------------------------------
#  Posicionamiento
# -----------------------------------------------------------------
func _god_al_depot() -> void:
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
		POS_BALDOSA.x, POS_BALDOSA.y, POS_BALDOSA.z])
	_pasar_a("esperar god depot")


func _traer_sujeto() -> void:
	print("El operador trae al sujeto al area del deposito.")
	_con_god.enviar_hablar("/c %s" % _nombre_sujeto)
	_pasar_a("esperar sujeto cerca")


func _esperar_sujeto_cerca() -> void:
	if _estado == null or not _estado.adentro:
		if _espera > ESPERA_PASO:
			_fallar("BLOCKED el sujeto no estaba en el mundo para posicionarlo")
		return
	if _cerca(_estado.mi_pos, POS_BALDOSA, 2) and _estado.mi_pos.z == POS_BALDOSA.z:
		_pasar_a("apartar god")
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED el sujeto no llego al area del deposito")


## El operador se aparta: dos criaturas no comparten casilla y el sujeto tiene
## que poder caminar hasta la baldosa por su cuenta.
func _apartar_god() -> void:
	_con_god.enviar_hablar("/gotopos %d,%d,%d" % [
		POS_GOD_NEUTRAL.x, POS_GOD_NEUTRAL.y, POS_GOD_NEUTRAL.z])
	_pasar_a("esperar god lejos")


## Y hay que ESPERAR a que se haya ido de verdad. Mandar la orden y empezar a
## caminar en el mismo instante hacia la casilla donde todavia esta parado el
## operador devuelve "There is not enough room": el servidor no deja dos
## criaturas en la misma casilla.
func _esperar_god_lejos() -> void:
	if _estado_god != null and not _cerca(_estado_god.mi_pos, POS_BALDOSA, 3):
		print("El operador ya se aparto del area del deposito.")
		_pasar_a("salir de la baldosa")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el operador no se aparto del area del deposito")


# -----------------------------------------------------------------
#  Activacion del deposito: SALIR y despues ENTRAR
# -----------------------------------------------------------------
## Si el sujeto ya esta sobre la baldosa, el evento de entrada NO se dispararia.
## Ademas `onStepOut` llama `unloadDepotLocker`, asi que salir desactiva de
## verdad y el paso siguiente es una activacion real, no una herencia.
func _salir_de_la_baldosa() -> void:
	if _estado == null or not _estado.adentro:
		if _espera > ESPERA_PASO:
			_fallar("BLOCKED el sujeto no esta en el mundo")
		return
	if _estado.mi_pos != POS_BALDOSA:
		# Ya esta afuera. La casilla donde esta parado es, por definicion, una
		# casilla donde el sujeto CABE: se la recuerda como punto de salida en
		# vez de insistir con una constante.
		_pos_fuera = _estado.mi_pos
		print("El sujeto NO esta sobre la baldosa; su casilla actual sirve como punto de salida.")
		_pasar_a("entrar a la baldosa")
		return
	# Esta sobre la baldosa y hay que sacarlo. Cual de las casillas vecinas es
	# caminable NO se adivina: se prueban por turno hasta que una funcione.
	#
	# La casilla contigua que usaba la evidencia historica NO sirve para esto:
	# alli se llegaba con `/gotopos` de un god, que teletransporta a cualquier
	# lado, y un personaje normal que intenta CAMINAR hasta ahi recibe
	# "There is not enough room". Aislado no es lo mismo que habitable.
	var candidatos := _candidatos_fuera()
	if _indice_candidato >= candidatos.size():
		_fallar("BLOCKED ninguna casilla vecina de la baldosa resulto caminable para el sujeto")
		return
	var destino: Vector3i = candidatos[_indice_candidato]
	if _reintentar_caminata(destino,
			"El sujeto esta sobre la baldosa: prueba salir hacia una casilla vecina."):
		return
	print("  esa vecina no era caminable; se prueba la siguiente.")
	_indice_candidato += 1
	_intentos_caminata = 0


## Vecinas de la baldosa, sin la del mueble, que esta ocupada por el propio
## deposito. Se prueban en este orden hasta que una resulte caminable.
func _candidatos_fuera() -> Array:
	return [
		POS_BALDOSA + Vector3i(-1, 0, 0),
		POS_BALDOSA + Vector3i(0, -1, 0),
		POS_BALDOSA + Vector3i(1, 0, 0),
		POS_BALDOSA + Vector3i(-1, -1, 0),
		POS_BALDOSA + Vector3i(1, -1, 0),
		POS_BALDOSA + Vector3i(-1, 1, 0),
		POS_BALDOSA + Vector3i(1, 1, 0),
	]


func _entrar_a_la_baldosa() -> void:
	if _estado.mi_pos == POS_BALDOSA:
		print("El sujeto ENTRO a la baldosa de activacion.")
		_pasar_a("confirmar activacion")
		return
	if _intentos_caminata == 0:
		_avisos_depot_sesion = 0
	if _reintentar_caminata(POS_BALDOSA, ""):
		return
	_fallar("BLOCKED el sujeto no pudo entrar a la baldosa de activacion")


## Primera de las dos senales de deposito PERSONAL: el aviso autoritativo que
## el servidor manda dentro de la misma rama que llama a `loadDepotLocker`.
func _confirmar_activacion() -> void:
	if _avisos_depot_sesion > 0:
		print("El servidor confirmo la carga del deposito PERSONAL del sujeto.")
		_pidio_caminata = false
		_pasar_a("abrir mochila")
		return
	if _espera > ESPERA_CORTA:
		_fallar("BLOCKED el servidor no confirmo la carga del deposito personal; sin eso el mueble abierto podria ser el contenedor del mapa")


# -----------------------------------------------------------------
#  Apertura de contenedores
# -----------------------------------------------------------------
func _abrir_mochila() -> void:
	if _id_mochila >= 0:
		_pasar_a("abrir locker")
		return
	if not _pidio_caminata:
		_pidio_caminata = true
		var mochila: Dictionary = _estado.inventario.get(SLOT_MOCHILA, {})
		if mochila.is_empty():
			_fallar("BLOCKED el sujeto no tiene mochila en la ranura de equipo esperada")
			return
		print("Abriendo la mochila del sujeto.")
		_con.enviar_usar_inventario(SLOT_MOCHILA, int(mochila.get("cid", 0)))
		return
	_id_mochila = _primer_id_nuevo([])
	if _id_mochila < 0 and _espera > ESPERA_CORTA:
		_fallar("BLOCKED el servidor no abrio la mochila del sujeto")


func _abrir_locker() -> void:
	if _id_locker >= 0:
		_pidio_caminata = false
		_pasar_a("abrir cofre")
		return
	if _pidio_caminata:
		_id_locker = _primer_id_nuevo([_id_mochila])
		if _id_locker < 0 and _espera > ESPERA_CORTA:
			_fallar("BLOCKED el servidor no abrio el mueble del deposito")
		return
	var pila := _buscar_locker()
	if pila < 0:
		if _espera > ESPERA_CORTA:
			_fallar("BLOCKED no aparece el mueble del deposito en la casilla operativa")
		return
	_pidio_caminata = true
	var cosa: Dictionary = _estado.casillas[POS_LOCKER][pila]
	print("Abriendo el mueble del deposito.")
	_con.enviar_usar_item(POS_LOCKER, int(cosa.get("cid", 0)), pila, VENTANA_LOCKER)


## Segunda senal de deposito PERSONAL: `actions.cpp:225-227` crea el
## `depot chest` DENTRO del locker solo cuando `currentDepotItem` esta puesto.
## Si se hubiera abierto el mueble del mapa, este cofre no estaria.
func _abrir_cofre() -> void:
	if _id_cofre >= 0:
		if not _cofre_abierto:
			_cofre_abierto = true
			_deposito_cargado = _avisos_depot_sesion > 0 and _locker_trae_cofre
			print("Cofre del deposito abierto: '%s'." % _cofre_nombre)
		_pidio_caminata = false
		if _segunda_sesion:
			_recargado = _avisos_depot_sesion > 0 and _locker_trae_cofre
			_pasar_a("verificar persistencia")
		else:
			_pasar_a("elegir objeto")
		return
	if _pidio_caminata:
		_id_cofre = _primer_id_nuevo([_id_mochila, _id_locker])
		if _id_cofre >= 0:
			_cofre_nombre = str(_ids_vistos.get(_id_cofre, ""))
			if not _cofre_nombre.to_lower().contains("depot"):
				_fallar("BLOCKED el contenedor interno no se identifica como el cofre del deposito")
		elif _espera > ESPERA_CORTA:
			_fallar("BLOCKED el servidor no abrio el cofre del deposito")
		return
	var indice := _indice_del_cofre()
	if indice < 0:
		if _espera > ESPERA_CORTA:
			_fallar("BLOCKED el mueble abierto no trae adentro el cofre del deposito; podria ser el contenedor del mapa y no el deposito personal")
		return
	_locker_trae_cofre = true
	_pidio_caminata = true
	var cofre: Dictionary = _items_de(_id_locker)[indice]
	print("El mueble trae adentro el cofre del deposito; abriendolo.")
	_con.enviar_usar_item(Vector3i(0xFFFF, 0x40 | _id_locker, indice),
		int(cofre.get("cid", 0)), 0, VENTANA_COFRE)


# -----------------------------------------------------------------
#  Objeto de prueba, guardado y frontera de sesion
# -----------------------------------------------------------------
## Se usa un objeto que el sujeto YA POSEE. No se crea ninguno.
func _elegir_objeto() -> void:
	for slot in range(1, 11):
		var cosa: Dictionary = _estado.inventario.get(slot, {})
		if str(cosa.get("nombre", "")).to_lower() == _nombre_objeto:
			_cid_objeto = int(cosa.get("cid", 0))
			_slot_origen = slot
			break
	if _cid_objeto == 0:
		if _espera > ESPERA_CORTA:
			_fallar("BLOCKED el sujeto no tiene el objeto de prueba configurado en una ranura de equipo")
		return
	_objeto_antes_de_guardar = true
	_antes_cofre = _items_de(_id_cofre).size()
	_antes_origen = 1
	print("Objeto de prueba propio del sujeto localizado. Cofre antes: %d cosas." % _antes_cofre)
	print("Guardando exactamente UN objeto en el cofre del deposito.")
	_con.enviar_mover_ubicacion(Vector3i(0xFFFF, _slot_origen, 0), _cid_objeto, 0,
		Vector3i(0xFFFF, 0x40 | _id_cofre, 0))
	_pasar_a("verificar guardado")


func _verificar_guardado() -> void:
	var ahora := _items_de(_id_cofre).size()
	var en_cofre := _indice_en(_id_cofre) >= 0
	var origen_vacio: bool = _estado.inventario.get(_slot_origen, {}).is_empty()
	if en_cofre and ahora == _antes_cofre + 1:
		_guardado_mas_uno = true
		_origen_menos_uno = origen_vacio
		print("Guardado OK: el cofre paso de %d a %d y el origen quedo %s."
			% [_antes_cofre, ahora, "vacio" if origen_vacio else "con algo"])
		if not origen_vacio:
			_fallar("FAIL el objeto aparecio en el cofre pero no salio de su origen")
			return
		_pasar_a("cerrar sesion")
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL el objeto no llego al cofre del deposito")


## Cierre REAL: logout legacy `0x14`. No se mata el socket como camino de exito.
func _cerrar_sesion() -> void:
	if _espera < 1.0:
		return
	if not _pidio_caminata:
		_pidio_caminata = true
		print("Cerrando la primera sesion con el logout legacy.")
		_con.enviar_logout()
		return
	if _espera > ESPERA_PASO:
		_fallar("BLOCKED el servidor no cerro la primera sesion; sin frontera de sesion real no hay nada que medir")


func _verificar_persistencia() -> void:
	if _espera < 1.0:
		return
	var ahora := _items_de(_id_cofre).size()
	_sigue_guardado = _indice_en(_id_cofre) >= 0 and ahora == _antes_cofre + 1
	print("Tras la frontera de sesion: el cofre trae %d cosas (antes de guardar habia %d)."
		% [ahora, _antes_cofre])
	if not _sigue_guardado:
		_fallar("FAIL el objeto guardado no sobrevivio a la frontera de sesion")
		return
	print("EL OBJETO SIGUE EN EL DEPOSITO DESPUES DE LA SESION NUEVA.")
	_antes_mochila = _items_de(_id_mochila).size()
	_pasar_a("recuperar")


func _recuperar() -> void:
	var indice := _indice_en(_id_cofre)
	if indice < 0:
		_fallar("FAIL el objeto dejo de estar en el cofre antes de recuperarlo")
		return
	print("Recuperando exactamente UN objeto del cofre hacia la mochila.")
	_con.enviar_mover_ubicacion(Vector3i(0xFFFF, 0x40 | _id_cofre, indice),
		_cid_objeto, 0, Vector3i(0xFFFF, 0x40 | _id_mochila, 0))
	_pasar_a("verificar recuperado")


func _verificar_recuperado() -> void:
	var en_cofre := _items_de(_id_cofre).size()
	var en_mochila := _items_de(_id_mochila).size()
	if en_cofre == _antes_cofre and en_mochila == _antes_mochila + 1 \
			and _indice_en(_id_cofre) < 0:
		_recuperado_cofre_menos_uno = true
		_recuperado_mochila_mas_uno = true
		print("Recuperado OK: el cofre volvio a %d y la mochila paso de %d a %d."
			% [en_cofre, _antes_mochila, en_mochila])
		_construir_observacion()
		_pidio_caminata = false
		_pasar_a("restaurar")
		return
	if _espera > ESPERA_PASO:
		_fallar("FAIL el objeto no volvio del cofre al inventario del sujeto")


## Limpieza, fuera de la medicion: el objeto vuelve a la ranura de equipo de
## donde salio, para que el entorno quede como estaba. Si no se puede, se
## declara honestamente y el objeto queda en la mochila del propio sujeto.
func _restaurar() -> void:
	if not _pidio_caminata:
		_pidio_caminata = true
		var indice := _indice_en(_id_mochila)
		if indice < 0:
			print("Aviso: el objeto no aparece en la mochila para restaurarlo; queda donde este, dentro del propio sujeto.")
			_emitir_observacion()
			return
		print("Restaurando el objeto a su ranura de equipo original.")
		_con.enviar_mover_ubicacion(Vector3i(0xFFFF, 0x40 | _id_mochila, indice),
			_cid_objeto, 0, Vector3i(0xFFFF, _slot_origen, 0))
		return
	if _espera > 3.0:
		var restaurado: bool = not _estado.inventario.get(_slot_origen, {}).is_empty()
		print("Restauracion del objeto a su ranura original: %s" % str(restaurado))
		_emitir_observacion()


# -----------------------------------------------------------------
#  Observacion
# -----------------------------------------------------------------
func _construir_observacion() -> void:
	_obs = {
		"initial_session": {
			"personal_depot_loaded": _deposito_cargado,
			"depot_chest_opened": _cofre_abierto,
		},
		"store": {
			"test_item_present_before_store": _objeto_antes_de_guardar,
			"depot_test_item_count_increased_by_one": _guardado_mas_uno,
		},
		"session_boundary": {
			"first_session_closed": _primera_cerrada,
			"new_session_established": _segunda_establecida,
		},
		"after_relogin": {
			"personal_depot_reloaded": _recargado,
			"stored_test_item_still_present": _sigue_guardado,
		},
		"recovery": {
			"depot_test_item_count_decreased_by_one": _recuperado_cofre_menos_uno,
			"inventory_test_item_count_increased_by_one": _recuperado_mochila_mas_uno,
		},
	}


func _emitir_observacion() -> void:
	## Ningun nombre, cuenta, coordenada, id de runtime, id de item, cantidad
	## absoluta, indice de ventana ni ruta de archivo. Solo relaciones.
	print("OBSERVATION_JSON: " + JSON.stringify(_obs))
	print("Captura de persistencia del deposito: OK")
	_terminar(0)


# -----------------------------------------------------------------
#  Utilidades
# -----------------------------------------------------------------
## Reintenta la caminata hacia `destino` hasta `MAX_INTENTOS_CAMINATA` veces,
## espaciadas. Devuelve true mientras quede margen para seguir intentando.
##
## Existe porque una unica orden perdida dejaba la fase esperando hasta el
## limite global: la casilla de destino puede estar ocupada un instante por
## otra criatura, y el servidor contesta "There is not enough room" sin mover a
## nadie. El contador se reinicia solo al cambiar de fase.
func _reintentar_caminata(destino: Vector3i, aviso: String) -> bool:
	if _intentos_caminata >= MAX_INTENTOS_CAMINATA:
		return false
	if _intentos_caminata > 0 and _espera < 3.0:
		return true
	_intentos_caminata += 1
	_espera = 0.0
	if not aviso.is_empty() and _intentos_caminata == 1:
		print(aviso)
	_caminar_hacia(destino)
	return true


func _caminar_hacia(destino: Vector3i) -> void:
	var pasos: Array = []
	var actual: Vector3i = _estado.mi_pos
	var x: int = actual.x
	var y: int = actual.y
	while (x != destino.x or y != destino.y) and pasos.size() < 8:
		var px: int = signi(destino.x - x)
		var py: int = signi(destino.y - y)
		pasos.append(Vector2i(px, py))
		x += px
		y += py
	if pasos.is_empty():
		return
	_con.enviar_auto_camino(pasos)


func _buscar_locker() -> int:
	var pila := 0
	for cosa in _estado.casillas.get(POS_LOCKER, []):
		if cosa.get("tipo") == "item" and bool(cosa.get("contenedor", false)):
			return pila
		pila += 1
	return -1


func _indice_del_cofre() -> int:
	var indice := 0
	for cosa in _items_de(_id_locker):
		if str(cosa.get("nombre", "")).to_lower().contains("depot"):
			return indice
		indice += 1
	return -1


func _primer_id_nuevo(excluidos: Array) -> int:
	for id in _ids_vistos:
		if int(id) in excluidos:
			continue
		return int(id)
	return -1


func _items_de(id: int) -> Array:
	if _estado == null:
		return []
	return _estado.contenedores.get(id, {}).get("items", [])


func _indice_en(id_contenedor: int) -> int:
	var indice := 0
	for cosa in _items_de(id_contenedor):
		if int(cosa.get("cid", 0)) == _cid_objeto:
			return indice
		indice += 1
	return -1


func _cerca(posicion: Vector3i, centro: Vector3i, radio: int) -> bool:
	return posicion.z == centro.z \
		and absi(posicion.x - centro.x) <= radio \
		and absi(posicion.y - centro.y) <= radio


## Cambiar de fase limpia SIEMPRE la marca de "ya lo pedi": cada fase decide
## por si misma si ya mando su orden, y arrastrar esa marca de una fase a otra
## era una fuente de ordenes que no se enviaban nunca.
func _pasar_a(fase: String) -> void:
	print("  [%.0fs] fase: %s" % [_total, fase])
	_fase = fase
	_espera = 0.0
	_pidio_caminata = false
	_intentos_caminata = 0


func _fallar(texto: String) -> void:
	print(texto)
	_terminar(1)


func _terminar(codigo: int) -> void:
	if _terminando:
		return
	_terminando = true
	if _con != null:
		_con.enviar_logout()
	await get_tree().create_timer(2.0).timeout
	if _con_god != null:
		_con_god.cerrar()
	if _con != null:
		_con.cerrar()
	get_tree().quit(codigo)
