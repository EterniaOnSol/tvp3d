extends SceneTree

## Reproduce el bug real de Mill Avenue 1 (house 81): la cama del servidor
## (server 1760/1761 -> client 2493/2494) tiene `tiene_alto=true`, asi que un
## clic sobre su respaldo alto, resuelto contra el plano del piso, caia en la
## casilla vecina (32395,32176,7), que en la ventana viva tenia un tramo de
## pared (client 1281, "framework wall"). El servidor rechazaba con
## "You cannot use this object" porque el spriteId no coincidia con lo que
## habia en esa casilla.
##
## Esta prueba no abre conexion de red: construye el estado vivo a mano, tal
## como lo dejaria un WELCOME/STATE real, y comprueba solo la resolucion de
## clic del cliente (`_cama_bajo_mouse`, usada por usar/mirar).

const MUNDO := preload("res://mundo3d.gd")
const SPRITES := preload("res://red/sprites772.gd")
const CATALOGO := preload("res://red/mapa772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const COORD := preload("res://comun/coordenadas_tibia.gd")

const POS_CABECERA := Vector3i(32393, 32176, 7)
const POS_PIE := Vector3i(32394, 32176, 7)
const POS_PARED_VECINA := Vector3i(32395, 32176, 7)
const CID_CABECERA := 2493
const CID_PIE := 2494
const CID_PARED := 1281


func _initialize() -> void:
	var mundo := MUNDO.new()
	mundo._sprites = SPRITES.new()
	mundo._catalogo = CATALOGO.new()
	mundo._estado = ESTADO.new()
	mundo._estado.adentro = true
	mundo._estado.mi_pos = Vector3i(32393, 32178, 7)
	mundo._centro_escenario = mundo._estado.mi_pos

	mundo._estado.casillas[POS_CABECERA] = [
		{"tipo": "item", "cid": CID_CABECERA, "nombre": "bed"}]
	mundo._estado.casillas[POS_PIE] = [
		{"tipo": "item", "cid": CID_PIE, "nombre": "bed"}]
	mundo._estado.casillas[POS_PARED_VECINA] = [
		{"tipo": "item", "cid": CID_PARED, "nombre": "framework wall"}]

	mundo._camara = Camera3D.new()
	mundo._camara.fov = 60.0
	mundo._camara.far = 400.0
	root.add_child(mundo._camara)
	# En headless, project_ray_origin/unproject_position exigen que la camara
	# ya haya entrado de verdad al arbol; add_child sola no alcanza dentro de
	# _initialize().
	await process_frame
	mundo._camara.current = true

	var objetivo := COORD.tibia_a_mundo(mundo._estado.mi_pos,
		mundo._centro_escenario, MUNDO.LADO, MUNDO.ALTO_PISO)
	var giro := 0.0
	var inclinacion := deg_to_rad(45.0)
	var lejos := Vector3(sin(giro) * cos(inclinacion), sin(inclinacion),
		cos(giro) * cos(inclinacion)) * 10.0
	mundo._camara.position = objetivo + lejos
	mundo._camara.look_at(objetivo, Vector3.UP)

	# --- 1) Mapeo de piezas de cama: 2493/2494 son cama, 1281 no lo es ----
	if not mundo._es_pieza_de_cama(CID_CABECERA):
		printerr("FALLO: %d (cabecera) no se reconoce como pieza de cama" % CID_CABECERA)
		quit(1)
		return
	if not mundo._es_pieza_de_cama(CID_PIE):
		printerr("FALLO: %d (pie) no se reconoce como pieza de cama" % CID_PIE)
		quit(1)
		return
	if mundo._es_pieza_de_cama(CID_PARED):
		printerr("FALLO: %d (pared) se reconoce como pieza de cama" % CID_PARED)
		quit(1)
		return
	print("OK: 2493/2494 se reconocen como cama y 1281 no")

	# --- 2) El clic sobre la parte alta del respaldo cae, por el plano del
	#        piso, en la casilla vecina. Esto reproduce el sintoma reportado
	#        antes de la correccion. --------------------------------------
	var visual_cabecera := mundo._posicion_visual_de_casilla(POS_CABECERA,
		mundo._centro_escenario)
	var alto := maxf(float(mundo._sprites.alto_en_casillas(CID_CABECERA)) * MUNDO.LADO,
		MUNDO.LADO * 0.80)
	var punto_alto := visual_cabecera + Vector3(0.0, alto * 0.75, 0.0)
	var clic_alto: Vector2 = mundo._camara.unproject_position(punto_alto)

	var tile_por_rayo = mundo._casilla_bajo_mouse(clic_alto)
	if tile_por_rayo == null or tile_por_rayo == POS_CABECERA:
		printerr("FALLO: el fixture no reproduce el desfase del rayo contra el piso (dio %s)" \
			% str(tile_por_rayo))
		quit(1)
		return
	print("OK: el rayo contra el piso por si solo cae en %s, no en la cabecera" \
		% str(tile_por_rayo))

	# --- 3) La resolucion de cama debe ignorar ese desfase y devolver la
	#        cabecera real con su client id real. ------------------------
	var resultado := mundo._cama_bajo_mouse(clic_alto)
	if resultado.is_empty():
		printerr("FALLO: no se detecto ninguna cama bajo el clic alto")
		quit(1)
		return
	if resultado.get("posicion") != POS_CABECERA:
		printerr("FALLO: la cama resuelta no es la cabecera real: %s" % str(resultado.get("posicion")))
		quit(1)
		return
	var cid_resuelto := int(resultado["encontrado"]["cosa"].get("cid", 0))
	if cid_resuelto != CID_CABECERA:
		printerr("FALLO: cid resuelto %d distinto de %d" % [cid_resuelto, CID_CABECERA])
		quit(1)
		return
	print("OK: el clic alto sobre la cabecera resuelve client=%d en %s, no la pared vecina" \
		% [cid_resuelto, str(POS_CABECERA)])

	# --- 4) Un clic lejos de cualquier cama no debe adivinar una por
	#        cercania (nada de vecindario ni offset fijo). ----------------
	var punto_lejano := visual_cabecera + Vector3(20.0, 0.0, 20.0)
	var clic_lejano: Vector2 = mundo._camara.unproject_position(punto_lejano)
	var vacio := mundo._cama_bajo_mouse(clic_lejano)
	if not vacio.is_empty():
		printerr("FALLO: se detecto una cama por cercania en un clic lejano: %s" % str(vacio))
		quit(1)
		return
	print("OK: un clic lejano no adivina una cama por cercania")

	# --- 5) El pie de la cama (2494) tambien se resuelve por su propio
	#        rectangulo, con su propia posicion y client id. --------------
	var visual_pie := mundo._posicion_visual_de_casilla(POS_PIE, mundo._centro_escenario)
	var clic_pie: Vector2 = mundo._camara.unproject_position(
		visual_pie + Vector3(0.0, 0.05, 0.0))
	var resultado_pie := mundo._cama_bajo_mouse(clic_pie)
	if resultado_pie.is_empty() or resultado_pie.get("posicion") != POS_PIE \
			or int(resultado_pie["encontrado"]["cosa"].get("cid", 0)) != CID_PIE:
		printerr("FALLO: el pie de la cama no se resuelve en su propia casilla: %s" \
			% str(resultado_pie))
		quit(1)
		return
	print("OK: el pie de la cama (client=%d) resuelve su propia casilla %s" \
		% [CID_PIE, str(POS_PIE)])

	mundo._camara.free()
	mundo.free()
	quit(0)
