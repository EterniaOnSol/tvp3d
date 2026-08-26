extends RefCounted

# =====================================================================
#  RSA — el candado del primer paquete del login.
#
#  El cliente arma un bloque de 128 bytes con la llave XTEA adentro y lo
#  cifra con la clave PÚBLICA del servidor. Sólo el servidor, que tiene
#  la privada, puede abrirlo. De ahí en adelante toda la partida viaja
#  cifrada con XTEA, que es mucho más rápido.
#
#  OJO: no es el RSA "con relleno" de los navegadores. Tibia usa RSA
#  crudo: el bloque son 128 bytes tal cual, y el primero tiene que ser 0
#  (protocol.cpp:216 -> "return (msg.getByte() == 0)"). Por eso no sirve
#  la clase Crypto de Godot y hay que hacerlo a mano.
#
#  La clave es la pública clásica de OpenTibia, la misma que trae el
#  servidor en key.pem. Es pública a propósito: cifrar con ella es lo
#  que se espera que haga cualquier cliente.
# =====================================================================

const GRANDE := preload("res://red/entero_grande.gd")

const TAMANO := 128        # 1024 bits

const MODULO_DECIMAL := \
	"109120132967399429278860960508995541528237502902798129123468757937266291492576" + \
	"446330739696001110603907230888610072655818825358503429057592827629436413108566" + \
	"029093628212635953836686562675849720620786279431090218017681061521755056710823" + \
	"876476444260558147179707119674283982419152118103759076030616683978566631413"

var _n: PackedInt64Array


func _init() -> void:
	# 1024 bits en cifras de 28 -> 37 cifras (37*28 = 1036, sobra lugar).
	_n = GRANDE.desde_decimal(MODULO_DECIMAL, 37)


func cifrar(bloque: PackedByteArray) -> PackedByteArray:
	"""Cifra exactamente 128 bytes. El primero debe ser 0 para que el
	número quede por debajo del módulo y el servidor lo acepte."""
	assert(bloque.size() == TAMANO, "el bloque RSA tiene que ser de 128 bytes")
	var m := GRANDE.desde_bytes(bloque, 37)
	var c := GRANDE.modpow_65537(m, _n)
	return GRANDE.a_bytes(c, TAMANO)
