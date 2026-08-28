extends Node

const MUNDO := preload("res://mundo3d.gd")
const CATALOGO := preload("res://red/mapa772.gd")
const SPRITES := preload("res://red/sprites772.gd")

var _fallas := 0


func _ready() -> void:
	var mundo = MUNDO.new()
	mundo._catalogo = CATALOGO.new()
	mundo._sprites = SPRITES.new()

	var pasto: Dictionary = mundo._catalogo.info_item(4531)
	_comprobar("borde de pasto usa forma acostada",
		mundo._debe_ir_acostado(4531, pasto))
	_comprobar("bandera borde_suelo se carga",
		mundo._catalogo.es_borde_suelo(4531))
	_comprobar("orilla de agua detecta sus sprites reales",
		mundo._es_borde_agua(4633) and mundo._es_borde_agua(4644)
		and not mundo._es_borde_agua(4597) and not mundo._es_borde_agua(622))
	var material_orilla = mundo._material(
		mundo._sprites.cuadro_item(4633), MUNDO.Forma.ACOSTADA, 4633)
	_comprobar("orilla de agua usa material del sprite de pasto",
		material_orilla is ShaderMaterial)
	_comprobar("orilla de agua queda acostada sobre el pasto",
		mundo._forma_de_item(4633, mundo._catalogo.info_item(4633))
		== MUNDO.Forma.ACOSTADA)
	_comprobar("hole usa su sprite acostado",
		mundo._es_hoyo(mundo._catalogo.info_item(385))
		and mundo._forma_de_item(385, mundo._catalogo.info_item(385))
		== MUNDO.Forma.ACOSTADA)
	_comprobar("dead body usa su sprite acostado",
		mundo._es_cuerpo_muerto(mundo._catalogo.info_item(3987))
		and mundo._forma_de_item(3987, mundo._catalogo.info_item(3987))
		== MUNDO.Forma.ACOSTADA)
	_comprobar("pool liquido queda acostado",
		mundo._es_pool_de_liquido(mundo._catalogo.info_item(2886))
		and mundo._forma_de_item(2886, mundo._catalogo.info_item(2886))
		== MUNDO.Forma.ACOSTADA)
	_comprobar("pool de sangre usa material rojo",
		mundo._material(mundo._sprites.cuadro_item(2886),
			MUNDO.Forma.ACOSTADA, 2886, MUNDO.COLOR_LIQUIDO_SANGRE)
		is ShaderMaterial)

	var counter: Dictionary = mundo._catalogo.info_item(2317)
	_comprobar("counter usa forma acostada",
		mundo._forma_de_item(2317, counter) == MUNDO.Forma.ACOSTADA)
	_comprobar("counter conserva bloqueo",
		bool(counter.get("bloquea", false)))

	_comprobar("big table usa forma acostada",
		mundo._forma_de_item(2302, mundo._catalogo.info_item(2302)) == MUNDO.Forma.ACOSTADA)
	_comprobar("table usa forma acostada",
		mundo._forma_de_item(2322, mundo._catalogo.info_item(2322)) == MUNDO.Forma.ACOSTADA)

	_comprobar("pared de casa usa volumen de pared",
		mundo._forma_de_item(1585, mundo._catalogo.info_item(1585)) == MUNDO.Forma.CAJA)
	_comprobar("wooden railing usa pasamanos fijo",
		mundo._forma_de_item(2154, mundo._catalogo.info_item(2154)) == MUNDO.Forma.PASAMANOS)
	_comprobar("stone railing usa pasamanos fijo",
		mundo._forma_de_item(2162, mundo._catalogo.info_item(2162)) == MUNDO.Forma.PASAMANOS)
	_comprobar("campfire no se convierte en plataforma",
		mundo._forma_de_item(2002, mundo._catalogo.info_item(2002)) == MUNDO.Forma.LAMINA)
	_comprobar("sewer grate queda horizontal",
		mundo._forma_de_item(435, mundo._catalogo.info_item(435)) == MUNDO.Forma.ACOSTADA)
	_comprobar("lever levantado queda pintado en el suelo",
		mundo._forma_de_item(2772, mundo._catalogo.info_item(2772)) == MUNDO.Forma.ACOSTADA)
	_comprobar("lever bajado conserva la misma forma de suelo",
		mundo._forma_de_item(2773, mundo._catalogo.info_item(2773)) == MUNDO.Forma.ACOSTADA)
	var nodo_palanca := MultiMeshInstance3D.new()
	var malla_palanca := MultiMesh.new()
	malla_palanca.mesh = PlaneMesh.new()
	malla_palanca.instance_count = 1
	nodo_palanca.multimesh = malla_palanca
	mundo._animaciones_palanca = [{
		"nodo": nodo_palanca,
		"cid": 2773,
		"posicion": Vector3i(1, 1, 7),
		"tiempo": 0.0,
	}]
	mundo._animar_palancas(0.05)
	_comprobar("lever usa una transicion con los sprites de estado",
		mundo._animaciones_palanca.size() == 1
		and nodo_palanca.material_override != null)
	mundo._animar_palancas(0.20)
	_comprobar("lever termina en el sprite confirmado",
		mundo._animaciones_palanca.is_empty()
		and nodo_palanca.material_override != null)
	nodo_palanca.free()
	_comprobar("stairs queda horizontal",
		mundo._forma_de_item(437, mundo._catalogo.info_item(437)) == MUNDO.Forma.ACOSTADA)
	_comprobar("ladder queda horizontal",
		mundo._forma_de_item(1948, mundo._catalogo.info_item(1948)) == MUNDO.Forma.ACOSTADA)
	_comprobar("tree usa prototipo cubico 3D",
		mundo._forma_de_item(3614, mundo._catalogo.info_item(3614)) == MUNDO.Forma.PROTOTIPO)
	_comprobar("small fir tree usa prototipo cubico 3D",
		mundo._forma_de_item(3682, mundo._catalogo.info_item(3682)) == MUNDO.Forma.PROTOTIPO)
	_comprobar("blueberry bush usa prototipo cubico 3D",
		mundo._forma_de_item(3699, mundo._catalogo.info_item(3699)) == MUNDO.Forma.PROTOTIPO)
	_comprobar("mailbox usa prototipo cubico 3D",
		mundo._forma_de_item(3501, mundo._catalogo.info_item(3501)) == MUNDO.Forma.PROTOTIPO)
	_comprobar("sign usa prototipo cubico 3D",
		mundo._forma_de_item(2012, mundo._catalogo.info_item(2012)) == MUNDO.Forma.PROTOTIPO)
	var centro_superficie := Vector3i(100, 100, 7)
	_comprobar("piso superior queda renderizable desde nivel 0",
		mundo._nivel_renderizable(Vector3i(100, 100, 6), centro_superficie))
	_comprobar("piso subterraneo no aparece como piso superior",
		not mundo._nivel_renderizable(Vector3i(100, 100, 7), Vector3i(100, 100, 8)))
	var piso_base := mundo._posicion_visual_de_casilla(
		Vector3i(100, 100, 7), centro_superficie)
	var primer_piso := mundo._posicion_visual_de_casilla(
		Vector3i(100, 100, 6), centro_superficie)
	var segundo_piso := mundo._posicion_visual_de_casilla(
		Vector3i(100, 100, 5), centro_superficie)
	_comprobar("pisos superiores se separan visualmente 2.0 SQM",
		is_equal_approx(primer_piso.y - piso_base.y, 2.0)
		and is_equal_approx(segundo_piso.y - primer_piso.y, 2.0))
	var estructura_superior: Array = mundo._filtrar_construccion_superior(
		[1585, 408, 3614])
	_comprobar("pisos superiores conservan arquitectura y omiten decoracion",
		estructura_superior.has(1585) and estructura_superior.has(408)
		and not estructura_superior.has(3614))
	var material_jugador: StandardMaterial3D = mundo._material_personaje(
		Color.WHITE, 0.8)
	_comprobar("personaje queda visible sobre techos y pisos",
		material_jugador.no_depth_test and material_jugador.render_priority >= 100)

	print("Formas de render TVP3D: %d falla(s)" % _fallas)
	mundo.free()
	get_tree().quit(1 if _fallas > 0 else 0)


func _comprobar(nombre: String, correcto: bool) -> void:
	if correcto:
		print("  OK  " + nombre)
	else:
		print("  FAIL " + nombre)
		_fallas += 1
