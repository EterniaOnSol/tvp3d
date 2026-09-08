extends SceneTree

const PERSONAJES := preload("res://propio/personajes3d/catalogo.gd")
const SPRITES := preload("res://red/sprites772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
class MundoPrueba:
	extends "res://mundo3d.gd"
	func _ready() -> void:
		set_process(false)

var catalogo := PERSONAJES.new()
var comprobaciones := 0
var fallas := 0


func _initialize() -> void:
	call_deferred("_probar")


func _ok(condicion: bool) -> void:
	comprobaciones += 1
	if not condicion:
		fallas += 1


func _probar() -> void:
	_ok(PERSONAJES.TIPOS.size()==14)
	_ok(catalogo.color_outfit(0).is_equal_approx(Color.WHITE))
	_ok(catalogo.color_outfit(132).is_equal_approx(Color(.5,0,0)))
	for tipo in PERSONAJES.TIPOS:
		_ok(catalogo.tiene(tipo))
		_ok(not catalogo.nombre(tipo).is_empty())
		var quieto := catalogo.crear(tipo,[78,94,115,40],2,0)
		root.add_child(quieto)
		var caja: AABB = quieto.get_meta("aabb_comparacion")
		_ok(caja.size.y >= .90 and caja.size.y <= 1.20)
		_ok(caja.size.x > .25 and caja.size.z > .15)
		var pierna := quieto.get_node_or_null("PiernaIzquierda") as Node3D
		var reposo := pierna.rotation.x
		catalogo.aplicar_pose(quieto,1)
		_ok(not is_equal_approx(pierna.rotation.x,reposo))
		quieto.free()
	_ok(catalogo.crear(999)==null)
	_probar_runtime()
	print("PERSONAJES_3D: %d comprobaciones, %d fallas" % [
		comprobaciones,fallas])
	quit(0 if fallas==0 else 1)


func _probar_runtime() -> void:
	var mundo := MundoPrueba.new()
	root.add_child(mundo)
	mundo._estado = ESTADO.new()
	mundo._sprites = SPRITES.new()
	mundo._estado.mi_id = 1
	mundo._estado.mi_pos = Vector3i(100,100,7)
	mundo._centro_escenario = mundo._estado.mi_pos
	mundo._piso_bichos = Node3D.new()
	mundo.add_child(mundo._piso_bichos)
	mundo._estado.criaturas = {
		1: {"pos":Vector3i(100,100,7),"apariencia":128,"direccion":2,
			"nombre":"Local","colores":[78,94,115,40]},
		2: {"pos":Vector3i(101,100,7),"apariencia":139,"direccion":1,
			"nombre":"Remote","colores":[10,20,30,40]},
	}
	var confirmado: Dictionary = mundo._estado.criaturas.duplicate(true)
	mundo._crear_jugador_visual()
	_ok(mundo._jugador_visual.name=="OutfitJugador3D")
	_ok(mundo._jugador_visual.get_meta("tipo_outfit")==128)
	var torso_local := mundo._jugador_visual.get_node("Torso") as MeshInstance3D
	var material_local := torso_local.material_override as StandardMaterial3D
	_ok(material_local.no_depth_test and material_local.render_priority==100)
	mundo._dibujar_criaturas()
	var remoto := mundo._nodos_criaturas[2] as MeshInstance3D
	var visual_remoto := remoto.get_node_or_null("OutfitHumano3D") as Node3D
	_ok(remoto.mesh==null and visual_remoto!=null)
	_ok(bool(remoto.get_meta("volumen_personaje",false)))
	_ok(is_equal_approx(remoto.rotation.y,PERSONAJES.GIROS[1]))
	_ok(remoto.position.is_equal_approx(Vector3(1,.02,0)))
	var pierna := visual_remoto.get_node("PiernaIzquierda") as Node3D
	var pose_inicial := pierna.rotation.x
	mundo._reloj_animacion = 1.0/mundo.FOTOGRAMAS_POR_SEGUNDO
	mundo._animar_criaturas()
	_ok(not is_equal_approx(pierna.rotation.x,pose_inicial))
	var visual_anterior := visual_remoto
	mundo._estado.criaturas[2]["colores"] = [11,21,31,41]
	mundo._dibujar_criaturas()
	visual_remoto = remoto.get_node_or_null("OutfitHumano3D") as Node3D
	_ok(visual_remoto!=visual_anterior)
	_ok(mundo._estado.criaturas[2]["colores"]==[11,21,31,41])
	mundo._estado.criaturas[2]["apariencia"] = 135
	mundo._dibujar_criaturas()
	_ok(remoto.mesh is QuadMesh and remoto.get_node_or_null("OutfitHumano3D")==null)
	_ok(confirmado[1]==mundo._estado.criaturas[1])
	mundo.free()
