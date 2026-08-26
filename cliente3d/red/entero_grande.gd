extends RefCounted

# =====================================================================
#  Enteros gigantes — lo mínimo indispensable para el RSA de Tibia.
#
#  POR QUÉ EXISTE ESTE ARCHIVO
#    El servidor exige que el primer paquete del login venga cifrado con
#    RSA de 1024 bits (protocolgame.cpp:1249 -> "RSA Decrypt Failed").
#    Godot no sabe multiplicar números de 1024 bits, así que hay que
#    enseñarle. Es la única parte del cliente que es matemática pura.
#
#  CÓMO SE GUARDA UN NÚMERO
#    Un arreglo de "cifras" de 28 bits, la más chica primero.
#    ¿Por qué 28 y no 32? Porque al multiplicar dos cifras el resultado
#    ocupa el doble (56 bits) y tiene que seguir entrando en el entero
#    de 64 bits de Godot. Con 32 se desbordaría y daría cuentas mal.
#
#  NO HAY DIVISIÓN EN NINGÚN LADO
#    Dividir números gigantes es la parte fea de escribir esto. Se
#    esquiva usando multiplicación de Montgomery, que hace el "resto de
#    la división" con puros corrimientos y restas. Lo único que hay que
#    preparar antes es R² mod n, y eso sale duplicando de a uno.
# =====================================================================

const BITS_CIFRA := 28
const BASE := 1 << BITS_CIFRA          # 2^28
const MASCARA := BASE - 1


# --------------------------------------------------------------------
#  Construcción y conversión
# --------------------------------------------------------------------
static func ceros(cifras: int) -> PackedInt64Array:
	var x := PackedInt64Array()
	x.resize(cifras)
	x.fill(0)
	return x


static func desde_bytes(bytes: PackedByteArray, cifras: int) -> PackedInt64Array:
	"""Los bytes vienen del más significativo al menos, como los escribe RSA."""
	var x := ceros(cifras)
	var bit := 0
	for i in range(bytes.size() - 1, -1, -1):
		var b: int = bytes[i]
		var c: int = bit / BITS_CIFRA
		var desp: int = bit % BITS_CIFRA
		if c < cifras:
			x[c] |= (b << desp) & MASCARA
		if desp > BITS_CIFRA - 8 and c + 1 < cifras:
			x[c + 1] |= b >> (BITS_CIFRA - desp)
		bit += 8
	return x


static func a_bytes(x: PackedInt64Array, cuantos: int) -> PackedByteArray:
	"""Devuelve exactamente 'cuantos' bytes, del más significativo al menos."""
	var salida := PackedByteArray()
	salida.resize(cuantos)
	salida.fill(0)
	for i in range(cuantos):
		var bit := i * 8                       # i cuenta desde el byte más chico
		var c: int = bit / BITS_CIFRA
		var desp: int = bit % BITS_CIFRA
		var v := 0
		if c < x.size():
			v = (x[c] >> desp) & 0xFF
		if desp > BITS_CIFRA - 8 and c + 1 < x.size():
			v |= (x[c + 1] << (BITS_CIFRA - desp)) & 0xFF
		salida[cuantos - 1 - i] = v
	return salida


static func desde_decimal(texto: String, cifras: int) -> PackedInt64Array:
	"""Lee un número escrito en base 10. Se usa para la clave pública."""
	var x := ceros(cifras)
	for caracter in texto:
		# x = x * 10 + dígito
		var acarreo: int = caracter.unicode_at(0) - 48
		for i in range(cifras):
			var v: int = x[i] * 10 + acarreo
			x[i] = v & MASCARA
			acarreo = v >> BITS_CIFRA
	return x


# --------------------------------------------------------------------
#  Comparar, restar, duplicar
# --------------------------------------------------------------------
static func comparar(a: PackedInt64Array, b: PackedInt64Array) -> int:
	"""-1 si a<b, 0 si iguales, 1 si a>b. Los dos del mismo largo."""
	for i in range(a.size() - 1, -1, -1):
		if a[i] < b[i]:
			return -1
		if a[i] > b[i]:
			return 1
	return 0


static func restar_en_sitio(a: PackedInt64Array, b: PackedInt64Array) -> void:
	"""a = a - b. Da por sentado que a >= b."""
	var presta := 0
	for i in range(b.size()):
		var v: int = a[i] - b[i] - presta
		if v < 0:
			v += BASE
			presta = 1
		else:
			presta = 0
		a[i] = v
	var i := b.size()
	while presta != 0 and i < a.size():
		var v: int = a[i] - presta
		if v < 0:
			v += BASE
			presta = 1
		else:
			presta = 0
		a[i] = v
		i += 1


static func duplicar_mod(x: PackedInt64Array, n: PackedInt64Array) -> void:
	"""x = (x + x) mod n. Exige que x ya venga menor que n."""
	var acarreo := 0
	for i in range(x.size()):
		var v: int = (x[i] << 1) | acarreo
		x[i] = v & MASCARA
		acarreo = v >> BITS_CIFRA
	# 2x < 2n, así que con restar n una sola vez alcanza.
	if acarreo != 0 or comparar(x, n) >= 0:
		restar_en_sitio(x, n)


# --------------------------------------------------------------------
#  Montgomery: multiplicar módulo n sin dividir nunca
# --------------------------------------------------------------------
static func inverso_de_la_cifra(n0: int) -> int:
	"""Devuelve -n0^-1 mod 2^28. Newton: cada vuelta duplica los bits buenos."""
	var inv := 1
	for _i in range(5):                        # 1 -> 2 -> 4 -> 8 -> 16 -> 32 bits
		# Hay que recortar el paréntesis ANTES de multiplicar: sin eso da un
		# negativo enorme y el producto se pasa de los 64 bits de Godot.
		inv = (inv * ((2 - n0 * inv) & MASCARA)) & MASCARA
	return (BASE - inv) & MASCARA


static func mont_mul(a: PackedInt64Array, b: PackedInt64Array,
		n: PackedInt64Array, n0inv: int) -> PackedInt64Array:
	"""Multiplicación de Montgomery (método CIOS): devuelve a*b*R^-1 mod n."""
	var k := n.size()
	var t := ceros(k + 2)

	for i in range(k):
		# --- t = t + a[i]*b ---
		var ai: int = a[i]
		var acarreo := 0
		for j in range(k):
			var v: int = t[j] + ai * b[j] + acarreo
			t[j] = v & MASCARA
			acarreo = v >> BITS_CIFRA
		var v2: int = t[k] + acarreo
		t[k] = v2 & MASCARA
		t[k + 1] += v2 >> BITS_CIFRA

		# --- t = (t + m*n) / 2^28, elegido para que la cifra baja quede en 0 ---
		var m: int = (t[0] * n0inv) & MASCARA
		acarreo = 0
		for j in range(k):
			var v: int = t[j] + m * n[j] + acarreo
			t[j] = v & MASCARA
			acarreo = v >> BITS_CIFRA
		var v3: int = t[k] + acarreo
		t[k] = v3 & MASCARA
		t[k + 1] += v3 >> BITS_CIFRA

		for j in range(k + 1):                 # correr una cifra hacia abajo
			t[j] = t[j + 1]
		t[k + 1] = 0

	# El resultado puede quedar un pelo por encima de n.
	var r := ceros(k)
	for i in range(k):
		r[i] = t[i]
	if t[k] != 0 or comparar(r, n) >= 0:
		restar_en_sitio(r, n)
	return r


static func modpow_65537(m: PackedInt64Array, n: PackedInt64Array) -> PackedInt64Array:
	"""m^65537 mod n. RSA usa siempre ese exponente, y 65537 = 2^16 + 1,
	así que son 16 elevadas al cuadrado y una multiplicación. Nada más."""
	var k := n.size()
	var n0inv := inverso_de_la_cifra(n[0])

	# R² mod n, duplicando 2*k*28 veces desde 1. Reemplaza a la división.
	var r2 := ceros(k)
	r2[0] = 1
	for _i in range(2 * k * BITS_CIFRA):
		duplicar_mod(r2, n)

	var mm := mont_mul(m, r2, n, n0inv)        # entrar al dominio Montgomery
	var x := mm
	for _i in range(16):
		x = mont_mul(x, x, n, n0inv)
	x = mont_mul(x, mm, n, n0inv)

	var uno := ceros(k)
	uno[0] = 1
	return mont_mul(x, uno, n, n0inv)          # salir del dominio Montgomery
