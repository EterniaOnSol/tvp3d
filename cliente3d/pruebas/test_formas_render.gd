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

	print("Formas de render TVP3D: %d falla(s)" % _fallas)
	mundo.free()
	get_tree().quit(1 if _fallas > 0 else 0)


func _comprobar(nombre: String, correcto: bool) -> void:
	if correcto:
		print("  OK  " + nombre)
	else:
		print("  FAIL " + nombre)
		_fallas += 1
