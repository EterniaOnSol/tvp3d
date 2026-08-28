extends RefCounted

# =====================================================================
#  Lo que el cliente cree que esta pasando en el mundo. Protocolo 7.72.
#
#  Junta los mensajes que van llegando y mantiene tres cosas: que hay en
#  cada casilla, donde esta cada criatura, y donde estamos nosotros.
#  No dibuja nada — de eso se encarga mundo3d.gd. Asi las pruebas pueden
#  usar exactamente este mismo codigo sin abrir una ventana.
#
#  POR QUE HAY QUE SABER EL TAMANYO DE TODOS LOS MENSAJES
#
#  El servidor pega varios mensajes en un mismo paquete: cada
#  `writeToOutputBuffer` agrega al mismo buffer y recien se manda todo
#  junto. Entonces un paquete es una fila de mensajes pegados, sin
#  separador ni largo por mensaje. Si el cliente no sabe cuanto ocupa
#  uno, no puede saltearlo: hay que abandonar el resto del paquete, y ahi
#  se pierde lo que venga despues — por ejemplo un movimiento.
#
#  Los tamanyos de aca estan sacados uno por uno del servidor
#  (`src/protocolgame.cpp`), con el numero de linea al lado.
# =====================================================================

const MAPA := preload("res://red/mapa772.gd")
const OPCODE_VOZ_PROXIMIDAD := 0xF1

signal cambio()
signal cambio_piso(opcode: int, posicion: Vector3i)
signal mapa_recibido(posicion: Vector3i)
signal casilla_actualizada(posicion: Vector3i, opcode: int)
signal paso_cancelado()
signal mensaje_servidor(texto: String)
signal habla_recibida(quien: String, texto: String, clase: int)
## Variante rica de los textos del servidor: conserva la posicion del habla
## para poder dibujar el dialogo sobre la criatura en el mundo 3D.
signal dialogo_recibido(quien: String, texto: String, posicion: Vector3i, clase: int)
## 0xB4 trae una clase de mensaje que el cliente clasico pinta en pantalla.
signal mensaje_pantalla(texto: String, clase: int)
signal inventario_actualizado(slot: int, cosa: Dictionary)
signal contenedor_actualizado(id: int, datos: Dictionary)
signal contenedor_cerrado(id: int)
signal estadisticas_actualizadas(datos: Dictionary)
signal habilidades_actualizadas(datos: Dictionary)
signal entramos()
signal pedido_ping()             ## el servidor pregunta si seguimos vivos
signal rechazados(motivo: String)  ## el servidor no nos deja entrar
signal iconos_actualizados(iconos: int)
signal efecto_mapa(posicion: Vector3i, tipo: int)
signal texto_animado(posicion: Vector3i, color: int, texto: String)
signal disparo_distancia(origen: Vector3i, destino: Vector3i, tipo: int)
## 0x86: cuadrado de color temporal sobre una criatura.
signal cuadrado_criatura(id: int, color: int)
## El servidor cancelo el objetivo de combate (0xA3).
signal objetivo_cancelado()
signal voz_recibida(orador_id: int, trama: PackedByteArray)

var casillas := {}     ## Vector3i -> Array de cosas
var criaturas := {}    ## id -> {pos, nombre, apariencia}
var inventario := {}   ## slot -> cosa
var contenedores := {} ## id -> {nombre, capacidad, items, tiene_padre}
var estadisticas := {}
var habilidades := {}
## Luz global enviada por el servidor (0x82). El cliente 3D la usa para
## que dia/noche siga el mismo reloj del mundo y no otro ciclo inventado.
var luz_mundo_nivel := 255
var luz_mundo_color := 215
var luz_mundo_recibida := false
var mi_id := 0
var mi_pos := Vector3i.ZERO
var adentro := false
var iconos_estado := 0
var en_combate := false

## Ultimo movimiento informado por el servidor, para poder verificarlo.
var ultimo_movimiento := {}

var _mapa
var _desconocidos := {}
## De donde veniamos en el ultimo paso. Los mensajes de cambio de piso
## calculan las franjas con la posicion VIEJA, no con la nueva.
var _pos_anterior := Vector3i.ZERO
## 0 = nada, 1 = acabamos de subir, 2 = acabamos de bajar. Mientras esta
## puesto, las dos franjas que siguen usan las formulas del cambio de piso.
var _cambio_piso := 0


func _init() -> void:
	_mapa = MAPA.new()


func procesar(msg) -> void:
	_leer_mensajes(msg)


func opcodes_desconocidos() -> Dictionary:
	return _desconocidos


func _leer_mensajes(msg) -> void:
	var hubo_cambio := false
	while msg.sin_leer() > 0:
		var opcode: int = msg.espiar_u8()
		match opcode:
			# ---------------------------------------------------------
			#  Entrada al mundo
			# ---------------------------------------------------------
			0x0A:   # somos nosotros (protocolgame.cpp:1844-1854)
				msg.leer_u8()
				mi_id = msg.leer_u32()
				msg.leer_u16()      # duracion del "beat", siempre 50
				msg.leer_u8()       # si podemos reportar errores
				adentro = true
				entramos.emit()

			0x0B:   # derechos de gamemaster (protocolgame.cpp:1863-1898)
				# Un byte por cada derecho del 18 al 49: 32 bytes.
				# Solo llega si el personaje es GOD.
				msg.saltar(1 + 32)

			# ---------------------------------------------------------
			#  El mapa
			# ---------------------------------------------------------
			0x64:   # el mapa entero (protocolgame.cpp:1694-1701)
				msg.leer_u8()
				mi_pos = msg.leer_posicion()
				_pos_anterior = mi_pos
				casillas.clear()
				criaturas.clear()
				_absorber(_mapa.leer_descripcion(
					msg, mi_pos.x - 8, mi_pos.y - 6, mi_pos.z, 18, 14))
				mapa_recibido.emit(mi_pos)
				hubo_cambio = true

			# Las franjas NO traen coordenadas: vienen pegadas al 0x6D de
			# mas arriba, que si las trae (protocolgame.cpp:1974-1988).
			# Por eso aca NO se toca mi_pos: ya la actualizo el 0x6D.
			# Sumarla de nuevo seria contar cada paso dos veces.
			0x65:   # fila nueva por el norte
				msg.leer_u8()
				if _cambio_piso == 1:
					# protocolgame.cpp:2416-2417 — con la X y la Y VIEJAS.
					_absorber(_mapa.leer_descripcion(
						msg, _pos_anterior.x - 8, _pos_anterior.y - 6, mi_pos.z, 18, 1))
					_cambio_piso = 0
				else:
					_absorber(_mapa.leer_descripcion(
						msg, _pos_anterior.x - 8, mi_pos.y - 6, mi_pos.z, 18, 1))
				hubo_cambio = true

			0x66:   # columna nueva por el este
				msg.leer_u8()
				if _cambio_piso == 2:
					# protocolgame.cpp:2454-2455
					_absorber(_mapa.leer_descripcion(
						msg, _pos_anterior.x + 9, _pos_anterior.y - 7, mi_pos.z, 1, 14))
				else:
					_absorber(_mapa.leer_descripcion(
						msg, mi_pos.x + 9, mi_pos.y - 6, mi_pos.z, 1, 14))
				hubo_cambio = true

			0x67:   # fila nueva por el sur
				msg.leer_u8()
				if _cambio_piso == 2:
					# protocolgame.cpp:2458-2459
					_absorber(_mapa.leer_descripcion(
						msg, _pos_anterior.x - 8, _pos_anterior.y + 7, mi_pos.z, 18, 1))
					_cambio_piso = 0
				else:
					_absorber(_mapa.leer_descripcion(
						msg, _pos_anterior.x - 8, mi_pos.y + 7, mi_pos.z, 18, 1))
				hubo_cambio = true

			0x68:   # columna nueva por el oeste
				msg.leer_u8()
				if _cambio_piso == 1:
					# protocolgame.cpp:2412-2413 — ojo: aca la Y va con -5,
					# no con -6 como en el caminar normal.
					_absorber(_mapa.leer_descripcion(
						msg, _pos_anterior.x - 8, _pos_anterior.y - 5, mi_pos.z, 1, 14))
				else:
					_absorber(_mapa.leer_descripcion(
						msg, mi_pos.x - 8, mi_pos.y - 6, mi_pos.z, 1, 14))
				hubo_cambio = true

			0xBE:   # subimos un piso (protocolgame.cpp:2377-2418)
				msg.leer_u8()
				_absorber(_leer_pisos_de_cambio(msg, true))
				_cambio_piso = 1
				cambio_piso.emit(0xBE, mi_pos)
				hubo_cambio = true

			0xBF:   # bajamos un piso (protocolgame.cpp:2420-2460)
				msg.leer_u8()
				_absorber(_leer_pisos_de_cambio(msg, false))
				_cambio_piso = 2
				cambio_piso.emit(0xBF, mi_pos)
				hubo_cambio = true

			# ---------------------------------------------------------
			#  Cosas que aparecen, cambian o se van
			# ---------------------------------------------------------
			0x69:   # una casilla entera de nuevo (protocolgame.cpp:1774-1793)
				msg.leer_u8()
				var donde_nueva: Vector3i = msg.leer_posicion()
				var recien_ahi := []
				var cosas: Array = _mapa.leer_casilla_suelta(msg, donde_nueva, recien_ahi)
				if cosas.is_empty():
					casillas.erase(donde_nueva)
				else:
					casillas[donde_nueva] = cosas
				_absorber({"casillas": {}, "criaturas": recien_ahi})
				casilla_actualizada.emit(donde_nueva, 0x69)
				hubo_cambio = true

			0x6A:   # aparecio algo nuevo (protocolgame.cpp:1703-1717)
				# OJO: el byte de "lugar en la pila" SOLO se manda a los
				# OTClient (linea 1712). Nosotros decimos ser Windows, asi
				# que aca NO viene. Leerlo de mas desalinea todo.
				msg.leer_u8()
				var donde: Vector3i = msg.leer_posicion()
				var recien := []
				var cosa: Dictionary = _mapa.leer_cosa(msg, donde, recien)
				if not casillas.has(donde):
					casillas[donde] = []
				_insertar_cosa_nueva(casillas[donde], cosa)
				_absorber({"casillas": {}, "criaturas": recien})
				casilla_actualizada.emit(donde, 0x6A)
				hubo_cambio = true

			0x6B:   # cambio algo que ya estaba (protocolgame.cpp:1719-1731)
				msg.leer_u8()
				var donde_cambio: Vector3i = msg.leer_posicion()
				var pila_cambio: int = msg.leer_u8()  # su lugar en la pila
				var descartar := []
				var reemplazo: Dictionary = _mapa.leer_cosa(msg, donde_cambio, descartar)
				_poner_en_pila(donde_cambio, pila_cambio, reemplazo)
				_absorber({"casillas": {}, "criaturas": descartar})
				casilla_actualizada.emit(donde_cambio, 0x6B)
				hubo_cambio = true

			0x6C:   # desaparecio algo (protocolgame.cpp:2357-2366)
				msg.leer_u8()
				var donde_menos: Vector3i = msg.leer_posicion()
				var pila: int = msg.leer_u8()
				_sacar_de_casilla(donde_menos, pila)
				casilla_actualizada.emit(donde_menos, 0x6C)
				hubo_cambio = true

			0x6D:   # alguien cambio de casillero (protocolgame.cpp:1957-1966)
				msg.leer_u8()
				var vieja := Vector3i.ZERO
				if msg.espiar_u16() == 0xFFFF:
					# Variante para criaturas que estaban muy abajo en la
					# pila: en vez de la casilla vieja viene su id.
					msg.leer_u16()
					var quien: int = msg.leer_u32()
					var adonde: Vector3i = msg.leer_posicion()
					_mover_criatura_por_id(quien, adonde)
					hubo_cambio = true
					continue
				vieja = msg.leer_posicion()
				msg.leer_u8()          # su lugar en la pila
				var nueva: Vector3i = msg.leer_posicion()
				# Solo nos interesa anotar el movimiento si es el NUESTRO:
				# los monstruos caminan solos todo el tiempo y sus 0x6D se
				# mezclan con los propios.
				if vieja == mi_pos:
					ultimo_movimiento = {"de": vieja, "a": nueva}
					_pos_anterior = vieja
				_mover_criatura(vieja, nueva)
				hubo_cambio = true

			# ---------------------------------------------------------
			#  Contenedores e inventario
			# ---------------------------------------------------------
			0x6E:   # se abrio un contenedor: es de largo variable
				# protocolgame.cpp:1439-1461:
				# id, item de la ventana, nombre, capacidad, padre, cantidad
				if msg.sin_leer() < 8:
					return
				msg.leer_u8()
				var id_contenedor: int = msg.leer_u8()
				var recien_contenedor := []
				var item_contenedor: Dictionary = _mapa.leer_cosa(
					msg, Vector3i.ZERO, recien_contenedor)
				var nombre_contenedor: String = msg.leer_texto()
				var capacidad_contenedor: int = msg.leer_u8()
				var tiene_padre: bool = msg.leer_u8() != 0
				var cantidad_items: int = msg.leer_u8()
				var items_contenedor := []
				for _i in range(cantidad_items):
					if msg.sin_leer() < 2:
						return
					items_contenedor.append(_mapa.leer_cosa(
						msg, Vector3i.ZERO, []))
				contenedores[id_contenedor] = {
					"nombre": nombre_contenedor,
					"capacidad": capacidad_contenedor,
					"tiene_padre": tiene_padre,
					"item": item_contenedor,
					"items": items_contenedor,
				}
				contenedor_actualizado.emit(id_contenedor,
					contenedores[id_contenedor])
				hubo_cambio = true
			0x6F:   # se cerro un contenedor
				msg.leer_u8()
				var id_cerrado: int = msg.leer_u8()
				contenedores.erase(id_cerrado)
				contenedor_cerrado.emit(id_cerrado)
				hubo_cambio = true
			0x70:   # entro algo a un contenedor
				msg.leer_u8()
				var id_agregado: int = msg.leer_u8()
				if contenedores.has(id_agregado):
					var agregado: Dictionary = _mapa.leer_cosa(msg, Vector3i.ZERO, [])
					var lista_agregada: Array = contenedores[id_agregado]["items"]
					# Container::addThing/addItemFront inserta en la posicion 0.
					lista_agregada.push_front(agregado)
					var capacidad_agregada := int(contenedores[id_agregado].get("capacidad", 0))
					if capacidad_agregada > 0 and lista_agregada.size() > capacidad_agregada:
						lista_agregada.pop_back()
					contenedor_actualizado.emit(id_agregado, contenedores[id_agregado])
				else:
					_mapa.leer_cosa(msg, Vector3i.ZERO, [])
				hubo_cambio = true
			0x71:   # cambio algo adentro de un contenedor
				msg.leer_u8()
				var id_actualizado: int = msg.leer_u8()
				var ranura_contenedor: int = msg.leer_u8()
				var actualizado: Dictionary = _mapa.leer_cosa(msg, Vector3i.ZERO, [])
				if contenedores.has(id_actualizado):
					var lista_actualizada: Array = contenedores[id_actualizado]["items"]
					while lista_actualizada.size() <= ranura_contenedor:
						lista_actualizada.append({})
					lista_actualizada[ranura_contenedor] = actualizado
					contenedor_actualizado.emit(id_actualizado, contenedores[id_actualizado])
				hubo_cambio = true
			0x72:   # salio algo de un contenedor
				msg.leer_u8()
				var id_quitado: int = msg.leer_u8()
				var ranura_quitada: int = msg.leer_u8()
				if contenedores.has(id_quitado):
					var lista_quitada: Array = contenedores[id_quitado]["items"]
					if ranura_quitada < lista_quitada.size():
						# El servidor borra la entrada y desplaza las siguientes.
						lista_quitada.remove_at(ranura_quitada)
					contenedor_actualizado.emit(id_quitado, contenedores[id_quitado])
				hubo_cambio = true
			0x78:   # una casilla del inventario (protocolgame.cpp:2018-2029)
				msg.leer_u8()
				var ranura: int = msg.leer_u8()
				var recien_inventario := []
				var cosa_inventario: Dictionary = _mapa.leer_cosa(
					msg, Vector3i.ZERO, recien_inventario)
				inventario[ranura] = cosa_inventario
				inventario_actualizado.emit(ranura, cosa_inventario)
				hubo_cambio = true
			0x79:   # una casilla del inventario que quedo vacia
				msg.leer_u8()
				var ranura_vacia: int = msg.leer_u8()
				inventario.erase(ranura_vacia)
				inventario_actualizado.emit(ranura_vacia, {})
				hubo_cambio = true
			0xF0:   # TVP3D: duracion restante del anillo equipado
				msg.leer_u8()
				var ranura_duracion: int = msg.leer_u8()
				var duracion_ms: int = msg.leer_u32()
				if inventario.has(ranura_duracion):
					var cosa_duracion: Dictionary = inventario[ranura_duracion]
					if duracion_ms > 0:
						cosa_duracion["duracion_ms"] = duracion_ms
					else:
						cosa_duracion.erase("duracion_ms")
					inventario[ranura_duracion] = cosa_duracion
					inventario_actualizado.emit(ranura_duracion, cosa_duracion)
				hubo_cambio = true

			# ---------------------------------------------------------
			#  Efectos y luces
			# ---------------------------------------------------------
			0x82:   # luz del mundo (protocolgame.cpp:2339-2343)
				msg.leer_u8()
				luz_mundo_nivel = msg.leer_u8()
				luz_mundo_color = msg.leer_u8()
				luz_mundo_recibida = true
			0x83:   # efecto magico (protocolgame.cpp:1663-1667)
				msg.leer_u8()
				var posicion_efecto: Vector3i = msg.leer_posicion()
				var tipo_efecto: int = msg.leer_u8()
				efecto_mapa.emit(posicion_efecto, tipo_efecto)
			0x84:   # texto que sale flotando (protocolgame.cpp:1370-1375)
				msg.leer_u8()
				var posicion_texto: Vector3i = msg.leer_posicion()
				var color_texto: int = msg.leer_u8()
				var texto: String = msg.leer_texto()
				texto_animado.emit(posicion_texto, color_texto, texto)
			0x85:   # un tiro a distancia (protocolgame.cpp:1649-1654)
				msg.leer_u8()
				var origen_disparo: Vector3i = msg.leer_posicion()
				var destino_disparo: Vector3i = msg.leer_posicion()
				var tipo_disparo: int = msg.leer_u8()
				disparo_distancia.emit(origen_disparo, destino_disparo, tipo_disparo)
			0x86:   # a alguien se le puso un color encima
				if msg.sin_leer() < 6:
					return
				msg.leer_u8()
				var id_cuadrado: int = msg.leer_u32()
				var color_cuadrado: int = msg.leer_u8()
				cuadrado_criatura.emit(id_cuadrado, color_cuadrado)
			0x8C:   # cambio de vida de una criatura (id + porcentaje)
				if msg.sin_leer() < 6:
					return
				msg.leer_u8()
				var id_vida: int = msg.leer_u32()
				var vida_porcentaje: int = msg.leer_u8()
				if criaturas.has(id_vida):
					criaturas[id_vida]["vida"] = vida_porcentaje
				hubo_cambio = true
			0x8D:   # luz de una criatura
				msg.saltar(1 + 4 + 1 + 1)
			0x8E:   # una criatura cambio de aspecto (protocolgame.cpp:1225-1227)
				msg.leer_u8()
				var id_aspecto: int = msg.leer_u32()
				var aspecto_nuevo := _leer_aspecto(msg)
				if criaturas.has(id_aspecto):
					# La animacion se resuelve en mundo3d a partir del lookType
					# confirmado. No se cambia la posicion ni se inventan colores.
					criaturas[id_aspecto]["apariencia"] = aspecto_nuevo
					hubo_cambio = true
			0x8F:   # cambio de velocidad
				msg.saltar(1 + 4 + 2)
			0x90:   # calavera de una criatura
				msg.saltar(1 + 4 + 1)
			0x91:   # escudo de party de una criatura
				msg.saltar(1 + 4 + 1)

			# ---------------------------------------------------------
			#  Nosotros
			# ---------------------------------------------------------
			0xA0:   # vida, mana, nivel, capacidad... (protocolgame.cpp:2282-2313)
				# 2+2+2+4+2+1+2+2+1+1+1 = 20
				if msg.sin_leer() < 21:
					return
				msg.leer_u8()
				estadisticas = {
					"vida": msg.leer_u16(),
					"vida_max": msg.leer_u16(),
					"capacidad": msg.leer_u16(),
					"experiencia": msg.leer_u32(),
					"nivel": msg.leer_u16(),
					"nivel_pct": msg.leer_u8(),
					"mana": msg.leer_u16(),
					"mana_max": msg.leer_u16(),
					"magia": msg.leer_u8(),
					"magia_pct": msg.leer_u8(),
					"alma": msg.leer_u8(),
				}
				estadisticas_actualizadas.emit(estadisticas)
				hubo_cambio = true
			0xA1:   # las 7 habilidades, 2 bytes cada una (protocolgame.cpp:2315-2322)
				if msg.sin_leer() < 15:
					return
				msg.leer_u8()
				var nombres_habilidad := ["puno", "garrote", "espada", "hacha",
					"distancia", "escudo", "pesca"]
				habilidades = {}
				for nombre in nombres_habilidad:
					habilidades[nombre] = {
						"nivel": msg.leer_u8(),
						"porcentaje": msg.leer_u8(),
					}
				habilidades_actualizadas.emit(habilidades)
				hubo_cambio = true
			0xA2:   # iconos de estado — UN byte (protocolgame.cpp:1431-1436)
				# El match solo inspecciona el opcode: sendIcons() agrega el
				# opcode y un unico byte de mascara. Consumimos ambos.
				msg.leer_u8()
				iconos_estado = msg.leer_u8()
				en_combate = (iconos_estado & (1 << 7)) != 0
				iconos_actualizados.emit(iconos_estado)
			0xA3:   # se cancelo el objetivo
				msg.saltar(1)
				objetivo_cancelado.emit()
			0xA7:   # modos de pelea (protocolgame.cpp:1796-1803)
				msg.saltar(1 + 3)

			# ---------------------------------------------------------
			#  Texto
			# ---------------------------------------------------------
			0x32:   # canal extendido; TVP3D usa 0xF1 para voz binaria
				if msg.sin_leer() < 3:
					return
				msg.leer_u8()
				var opcode_extendido: int = msg.leer_u8()
				var largo_extendido: int = msg.leer_u16()
				if largo_extendido > msg.sin_leer():
					return
				var datos_extendidos: PackedByteArray = msg.leer_bytes(largo_extendido)
				if opcode_extendido == OPCODE_VOZ_PROXIMIDAD:
					if datos_extendidos.size() < 4:
						return
					var id_orador: int = datos_extendidos[0] \
						| (datos_extendidos[1] << 8) \
						| (datos_extendidos[2] << 16) \
						| (datos_extendidos[3] << 24)
					voz_recibida.emit(id_orador, datos_extendidos.slice(4))

			0x14:   # el servidor nos echa Y DICE POR QUE
				# protocolgame.cpp:434-441. Sin esto el cliente solo puede
				# decir "se corto la conexion", que no ayuda a nadie: el
				# motivo real viene aca escrito.
				msg.leer_u8()
				rechazados.emit(msg.leer_texto())
				return

			0x15:   # cartel de aviso
				msg.leer_u8()
				msg.leer_texto()
			0xAA:   # alguien hablo
				# Hay TRES variantes del mismo mensaje y se distinguen por el
				# byte de tipo (const.h:61-77):
				#   en el mapa (protocolgame.cpp:1535) -> trae la casilla
				#   en un canal (protocolgame.cpp:1554)-> trae el canal
				#   en privado (protocolgame.cpp:1577) -> no trae nada
				msg.leer_u8()
				msg.leer_u32()     # numero de la frase
				var quien_habla: String = msg.leer_texto()
				var como: int = msg.leer_u8()
				var posicion_habla := Vector3i(-9999, -9999, -9999)
				if como in [0x01, 0x02, 0x03, 0x10, 0x11]:
					posicion_habla = msg.leer_posicion()
				elif como in [0x05, 0x06, 0x0A, 0x0C, 0x0E]:
					# Ojo: el canal de denuncias manda 4 bytes de fecha en vez
					# del numero de canal (protocolgame.cpp:1568-1572).
					msg.leer_u16()
				var texto_habla: String = msg.leer_texto()
				habla_recibida.emit(quien_habla, texto_habla, como)
				dialogo_recibido.emit(quien_habla, texto_habla,
					posicion_habla, como)
			0xB3:   # se cerro un canal privado
				msg.saltar(1 + 2)
			0xB4:   # un texto en la pantalla (protocolgame.cpp:1355-1361)
				msg.leer_u8()
				var clase_pantalla: int = msg.leer_u8()
				var texto_pantalla: String = msg.leer_texto()
				mensaje_servidor.emit(texto_pantalla)
				mensaje_pantalla.emit(texto_pantalla, clase_pantalla)
			0xB5:   # el servidor cancelo el paso (protocolgame.cpp:1613-1618)
				msg.leer_u8()
				msg.leer_u8()      # para donde quedamos mirando
				paso_cancelado.emit()

			# ---------------------------------------------------------
			#  Amigos y latido
			# ---------------------------------------------------------
			0xD2:   # un amigo de la lista (protocolgame.cpp:2184-2191)
				msg.leer_u8()
				msg.leer_u32()
				msg.leer_texto()
				msg.leer_u8()
			0xD3, 0xD4:   # un amigo se conecto o se fue
				msg.saltar(1 + 4)

			0x1E:   # "seguis ahi?" (protocolgame.cpp:1628-1638)
				msg.leer_u8()
				pedido_ping.emit()
			0x1D:   # respuesta a un ping nuestro
				msg.leer_u8()

			_:
				_desconocidos[opcode] = _desconocidos.get(opcode, 0) + 1
				if hubo_cambio:
					cambio.emit()
				return

	if hubo_cambio:
		cambio.emit()


# --------------------------------------------------------------------
#  Cambios de piso
# --------------------------------------------------------------------
func _leer_pisos_de_cambio(msg, subiendo: bool) -> Dictionary:
	"""Los pisos que manda el servidor al cambiar de altura. La lista de
	pisos NO es la del mapa normal (protocolgame.cpp:2377-2460)."""
	var pisos := []
	if subiendo:
		if mi_pos.z == 7:
			# Salimos a la superficie: manda los pisos 5 a 0.
			for i in range(5, -1, -1):
				pisos.append([i, 8 - i])
		elif mi_pos.z > 7:
			# Seguimos bajo tierra: un solo piso.
			pisos.append([mi_pos.z - 2, 3])
	else:
		if mi_pos.z == 8:
			# Entramos bajo tierra: tres pisos.
			for i in range(0, 3):
				pisos.append([mi_pos.z + i, -i - 1])
		elif mi_pos.z > 8 and mi_pos.z < 14:
			pisos.append([mi_pos.z + 2, -3])

	if pisos.is_empty():
		return {"casillas": {}, "criaturas": []}
	return _mapa.leer_pisos(
		msg, _pos_anterior.x - 8, _pos_anterior.y - 6, 18, 14, pisos)


func _leer_aspecto(msg) -> int:
	# protocolgame.cpp:2325-2337
	var tipo: int = msg.leer_u16()
	if tipo != 0:
		msg.saltar(4)
	else:
		msg.leer_u16()
	return tipo


# --------------------------------------------------------------------
#  El mundo que vamos armando
# --------------------------------------------------------------------
func _absorber(mundo: Dictionary) -> void:
	for donde in mundo["casillas"]:
		casillas[donde] = mundo["casillas"][donde]
	for bicho in mundo["criaturas"]:
		var id: int = bicho["id"]
		var nombre: String = bicho["nombre"]
		if nombre == "" and criaturas.has(id):
			nombre = criaturas[id]["nombre"]
		var apariencia: int = bicho.get("apariencia", 0)
		if apariencia == 0 and criaturas.has(id):
			# El caso corto (0x63) no manda el aspecto; se conserva el que ya
			# sabiamos, si no la criatura desaparece al girar.
			apariencia = criaturas[id]["apariencia"]
		var vida := int(bicho.get("vida", 100))
		if apariencia == 0 and criaturas.has(id):
			# Los mensajes cortos de criatura traen 100 como valor de relleno;
			# no deben curar visualmente al monster mientras se mueve.
			vida = int(criaturas[id].get("vida", vida))
		criaturas[id] = {
			"pos": bicho["donde"],
			"nombre": nombre,
			"apariencia": apariencia,
			"direccion": bicho.get("direccion", 2),
			"vida": vida,
		}


func reiniciar_sesion() -> void:
	"""Limpia el estado del personaje antes de volver al login."""
	casillas.clear()
	criaturas.clear()
	inventario.clear()
	contenedores.clear()
	estadisticas.clear()
	habilidades.clear()
	ultimo_movimiento.clear()
	mi_id = 0
	mi_pos = Vector3i.ZERO
	adentro = false
	iconos_estado = 0
	en_combate = false
	luz_mundo_recibida = false


func _sacar_de_casilla(donde: Vector3i, pila: int) -> void:
	if not casillas.has(donde):
		return
	var cosas: Array = casillas[donde]
	if pila < 0 or pila >= cosas.size():
		return
	var cosa: Dictionary = cosas[pila]
	if cosa.get("tipo") == "criatura":
		criaturas.erase(cosa.get("id"))
	cosas.remove_at(pila)
	if cosas.is_empty():
		casillas.erase(donde)


func _insertar_cosa_nueva(cosas: Array, cosa: Dictionary) -> void:
	"""Replica el orden de Tile::getThing() para el 0x6A de Windows.

	El servidor envia el 0x6A sin stackpos a clientes Windows. En el mapa
	visible, el orden es: suelo, objetos siempre arriba, criaturas y objetos
	de abajo. Tile::addThing inserta un objeto de abajo al inicio de su bloque,
	por eso no alcanza con hacer append().
	"""
	if cosa.get("tipo") != "item":
		# GetTileDescription manda las criaturas antes del bloque de objetos
		# inferiores. Mantener ese orden hace que el indice completo coincida
		# con Tile::getThing(index) cuando luego se empuja la criatura.
		var insercion_criatura := cosas.size()
		for indice_criatura in range(cosas.size()):
			var actual_criatura: Dictionary = cosas[indice_criatura]
			if actual_criatura.get("tipo") == "item" \
					and not bool(actual_criatura.get("suelo", false)) \
					and not bool(actual_criatura.get("siempre_arriba", false)):
				insercion_criatura = indice_criatura
				break
		cosas.insert(insercion_criatura, cosa)
		return

	if bool(cosa.get("suelo", false)):
		cosas.push_front(cosa)
		return

	var indice := 0
	if bool(cosa.get("siempre_arriba", false)):
		var orden_nuevo := int(cosa.get("orden_arriba", 0))
		while indice < cosas.size():
			var actual: Dictionary = cosas[indice]
			if actual.get("tipo") == "criatura":
				break
			if actual.get("tipo") != "item":
				break
			if bool(actual.get("suelo", false)):
				indice += 1
				continue
			if not bool(actual.get("siempre_arriba", false)):
				break
			if int(actual.get("orden_arriba", 0)) >= orden_nuevo:
				break
			indice += 1
		cosas.insert(indice, cosa)
		return

	# El nuevo objeto de abajo va despues del suelo, los top items y las
	# criaturas, pero antes del bloque de objetos de abajo ya existente.
	while indice < cosas.size():
		var actual: Dictionary = cosas[indice]
		if actual.get("tipo") == "criatura":
			indice += 1
			continue
		if actual.get("tipo") != "item":
			break
		if bool(actual.get("suelo", false)) or bool(actual.get("siempre_arriba", false)):
			indice += 1
			continue
		break
	cosas.insert(indice, cosa)


func _poner_en_pila(donde: Vector3i, pila: int, reemplazo: Dictionary) -> void:
	if pila < 0:
		return
	if not casillas.has(donde):
		casillas[donde] = []
	var cosas: Array = casillas[donde]
	if pila < cosas.size():
		var anterior: Dictionary = cosas[pila]
		if anterior.get("tipo") == "criatura":
			criaturas.erase(anterior.get("id"))
		cosas[pila] = reemplazo
	else:
		cosas.append(reemplazo)


func _mover_criatura(vieja: Vector3i, nueva: Vector3i) -> void:
	# El mensaje no dice QUIEN se movio, solo de donde a donde; hay que
	# reconocerlo por la casilla de origen.
	if vieja == mi_pos:
		mi_pos = nueva
	for id in criaturas:
		if criaturas[id]["pos"] == vieja:
			criaturas[id]["pos"] = nueva
			criaturas[id]["direccion"] = _direccion_de(nueva - vieja)
			_mover_criatura_en_pila(int(id), vieja, nueva)
			return


func _direccion_de(delta: Vector3i) -> int:
	"""El mensaje de movimiento no dice para donde quedo mirando la
	criatura; se deduce del paso. 0 norte, 1 este, 2 sur, 3 oeste."""
	if absi(delta.x) > absi(delta.y):
		return 1 if delta.x > 0 else 3
	if delta.y != 0:
		return 2 if delta.y > 0 else 0
	return 2


func _mover_criatura_por_id(quien: int, adonde: Vector3i) -> void:
	var vieja := Vector3i(-9999, -9999, -9999)
	if criaturas.has(quien):
		vieja = criaturas[quien]["pos"]
	if quien == mi_id:
		_pos_anterior = mi_pos
		mi_pos = adonde
	if criaturas.has(quien):
		criaturas[quien]["pos"] = adonde
		criaturas[quien]["direccion"] = _direccion_de(adonde - vieja)
		_mover_criatura_en_pila(quien, vieja, adonde)


func _mover_criatura_en_pila(id: int, vieja: Vector3i, nueva: Vector3i) -> void:
	"""Mantiene casillas alineado con criaturas despues de un 0x6D.

	El servidor construye el stack como suelo, top-items, criaturas y
	down-items. El stackpos que necesita 0x78 es ese indice completo, no el
	indice dentro del diccionario de criaturas.
	"""
	if vieja != Vector3i(-9999, -9999, -9999) and casillas.has(vieja):
		var antiguas: Array = casillas[vieja]
		for indice in range(antiguas.size() - 1, -1, -1):
			var cosa: Dictionary = antiguas[indice]
			if cosa.get("tipo") == "criatura" and int(cosa.get("id", 0)) == id:
				antiguas.remove_at(indice)
				break
		if antiguas.is_empty():
			casillas.erase(vieja)
	if nueva == Vector3i(-9999, -9999, -9999):
		return
	if not casillas.has(nueva):
		casillas[nueva] = []
	var nuevas: Array = casillas[nueva]
	for cosa_existente in nuevas:
		if cosa_existente.get("tipo") == "criatura" \
				and int(cosa_existente.get("id", 0)) == id:
			return
	var nueva_criatura := {"tipo": "criatura", "id": id}
	var insercion := nuevas.size()
	for indice in range(nuevas.size()):
		var cosa: Dictionary = nuevas[indice]
		if cosa.get("tipo") == "item" \
				and not bool(cosa.get("suelo", false)) \
				and not bool(cosa.get("siempre_arriba", false)):
			insercion = indice
			break
	nuevas.insert(insercion, nueva_criatura)
