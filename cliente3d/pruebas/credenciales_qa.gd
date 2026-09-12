extends RefCounted

# Carga de credenciales e identidades de prueba para los scripts de prueba
# viva de QA. QA-owned; vive en `cliente3d/pruebas/` a proposito y NO en
# `cliente3d/red/`, que pertenece a `protocolo-red`.
#
# ---------------------------------------------------------------------------
# POR QUE EXISTE
# ---------------------------------------------------------------------------
#
# Los 20 scripts de prueba viva anteriores al trabajo de paridad traian el
# numero de cuenta y la contrasena como constantes literales en el codigo
# versionado. En 7.72 el identificador numerico de cuenta es parte del juego de
# credenciales de autenticacion (el cliente lo manda como numero en el login),
# asi que publicarlo literal es publicar media credencial.
#
# Los 5 adaptadores de captura de paridad ya leian todo por entorno; esta
# pieza lleva la misma regla a los scripts legacy sin duplicar veinte veces la
# misma validacion.
#
# ---------------------------------------------------------------------------
# REGLAS
# ---------------------------------------------------------------------------
#
# 1. NUNCA hay un valor literal de credencial aca ni en quien la use.
# 2. NUNCA se imprime un valor. Los mensajes nombran la VARIABLE que falta,
#    que es material publicable, nunca su contenido.
# 3. NO hay valor por defecto para cuenta, contrasena ni nombre de personaje:
#    si falta, la prueba corta ANTES de intentar conectarse. Volver a un
#    literal previo seria reintroducir el problema en silencio.
# 4. `TVP772_HOST` y `TVP772_LOGIN_PORT` SI tienen defecto, porque no son
#    credenciales: son el destino local de siempre. Si no estan definidas, el
#    comportamiento es identico al que tenian estos scripts antes.
#
# ---------------------------------------------------------------------------
# VARIABLES
# ---------------------------------------------------------------------------
#
#   TVP772_ACCOUNT            identificador numerico de login
#   TVP772_PASSWORD           contrasena de esa cuenta
#   TVP772_PLAYER_CHARACTER   personaje normal de prueba
#   TVP772_GOD_CHARACTER      personaje operador con permisos de god
#   TVP772_PLAYER2_ACCOUNT    segunda cuenta (una cuenta normal no admite dos
#   TVP772_PLAYER2_PASSWORD   sesiones simultaneas)
#   TVP772_PLAYER2_CHARACTER
#   TVP772_GOD_ACCOUNT        cuenta del god, si vive aparte
#   TVP772_GOD_PASSWORD
#   TVP772_HOST               opcional, defecto 127.0.0.1
#   TVP772_LOGIN_PORT         opcional, defecto 7171
#
# Roles especificos de una sola prueba usan un nombre propio y descriptivo,
# por ejemplo `TVP772_LIFE_RING_CHARACTER`, para no obligar a que el personaje
# generico de prueba cumpla un requisito de inventario que no le corresponde.

const HOST_DEFECTO := "127.0.0.1"
const PUERTO_LOGIN_DEFECTO := 7171


## Una variable cuenta como presente si esta definida y no vacia. Las que
## nombran una cuenta o un puerto ademas tienen que ser un entero valido: una
## cuenta no numerica no llegaria al servidor y conviene cortar antes.
static func esta_definida(nombre: String) -> bool:
	var valor := OS.get_environment(nombre)
	if valor.is_empty():
		return false
	if nombre.ends_with("_ACCOUNT") or nombre.ends_with("_PORT"):
		return valor.is_valid_int()
	return true


## Nombre de la PRIMERA variable requerida que falta, o "" si estan todas.
## Devuelve el nombre de la variable, nunca su valor.
static func primera_faltante(requeridas: Array) -> String:
	for nombre in requeridas:
		if not esta_definida(str(nombre)):
			return str(nombre)
	return ""


## Guarda de arranque: si falta alguna variable requerida imprime el motivo
## nombrando SOLO la variable, cierra con codigo 2 y devuelve false para que
## quien llama pueda cortar sin intentar ninguna conexion.
static func exigir(nodo: Node, requeridas: Array) -> bool:
	var falta := primera_faltante(requeridas)
	if falta.is_empty():
		return true
	print("BLOCKED missing environment variable %s" % falta)
	if nodo != null and nodo.is_inside_tree():
		nodo.get_tree().quit(2)
	return false


static func texto(nombre: String) -> String:
	return OS.get_environment(nombre)


static func entero(nombre: String) -> int:
	var valor := OS.get_environment(nombre)
	if valor.is_empty() or not valor.is_valid_int():
		return 0
	return int(valor)


static func host() -> String:
	var valor := OS.get_environment("TVP772_HOST")
	if valor.is_empty():
		return HOST_DEFECTO
	return valor


static func puerto_login() -> int:
	var valor := OS.get_environment("TVP772_LOGIN_PORT")
	if valor.is_empty() or not valor.is_valid_int():
		return PUERTO_LOGIN_DEFECTO
	return int(valor)
