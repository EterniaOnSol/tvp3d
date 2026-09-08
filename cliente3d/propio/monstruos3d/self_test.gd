extends SceneTree

const MODELOS := preload("res://propio/monstruos3d/catalogo.gd")
const SPRITES := preload("res://red/sprites772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
class MundoPrueba:
	extends "res://mundo3d.gd"
	func _ready() -> void:
		set_process(false)

var fallas := 0
var comprobaciones := 0


func _initialize() -> void:
	call_deferred("_probar")


func _ok(etiqueta: String, condicion: bool) -> void:
	comprobaciones += 1
	if not condicion:
		fallas += 1
		push_error(etiqueta)


func _probar() -> void:
	var catalogo := MODELOS.new()
	for tipo in [21,34,39,56,30,36,38,208,219,27,52,3,16,42,123,28,81,26,82,83,79,43,45,124,13,14,60,31,74,32,94,33,37,15,53,76,111,212,217,218,35]:
		_ok("catalogo y fases %d" % tipo, catalogo.es_monstruo(0x40000001, tipo) and catalogo.fases(tipo) == (12 if catalogo.tiene_clips(tipo) else (6 if tipo == 26 else (4 if tipo == 217 else 3))))
		var primera := catalogo.malla(tipo)
		_ok("malla compartida %d" % tipo, primera == catalogo.malla(tipo, catalogo.fases(tipo)))
		var total_bounds := AABB()
		for fase in range(catalogo.fases(tipo)):
			var malla := catalogo.malla(tipo,fase)
			var aabb := malla.get_aabb()
			total_bounds = aabb if fase == 0 else total_bounds.merge(aabb)
			_ok("volumen en tres ejes %d/%d" % [tipo,fase], aabb.size.x > .1 and aabb.size.y > .025 and aabb.size.z > .1)
			_ok("pies sobre suelo %d/%d" % [tipo,fase], aabb.position.y >= -.001 and aabb.position.y < .08)
			var material := malla.surface_get_material(0) as StandardMaterial3D
			_ok("sin billboard %d/%d" % [tipo,fase], material.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED and (material.albedo_texture != null if catalogo.tiene_clips(tipo) else material.vertex_color_use_as_albedo))
		_ok("animacion geometrica %d" % tipo, primera != catalogo.malla(tipo,1))
		if catalogo.tiene_clips(tipo):
			var banco = catalogo._banco_texturado(tipo)
			for clip in banco.clips:
				for fase_clip in range(int(banco.clips[clip]["fases"])):
					total_bounds = total_bounds.merge(banco.pose(fase_clip,clip).get_aabb())
		var objetivo := float(catalogo.fichas[str(tipo)]["escala"]["longitud_casillas"])
		_ok("escala real de todas las poses %d" % tipo, is_equal_approx(maxf(total_bounds.size.x,total_bounds.size.z),objetivo))
	_ok("experimentos no habilitados", not catalogo.es_monstruo(0x40000001, 25))
	_ok("tipo desconocido", catalogo.malla(999999) == null)
	_ok("ID jugador", not catalogo.es_monstruo(123,21))
	_ok("ID NPC", not catalogo.es_monstruo(0x80000001,21))
	var mundo := MundoPrueba.new()
	root.add_child(mundo)
	mundo._estado = ESTADO.new()
	mundo._sprites = SPRITES.new()
	mundo._estado.mi_id = 1
	mundo._estado.mi_pos = Vector3i(100,100,7)
	mundo._centro_escenario = mundo._estado.mi_pos
	mundo._piso_bichos = Node3D.new()
	mundo.add_child(mundo._piso_bichos)
	var id := 0x40000001
	mundo._estado.criaturas = {
		id: {"pos":Vector3i(101,100,7),"apariencia":21,"direccion":2,"nombre":"Rat"},
		2: {"pos":Vector3i(99,100,7),"apariencia":21,"direccion":2,"nombre":"Player"},
		0x80000001: {"pos":Vector3i(100,101,7),"apariencia":21,"direccion":2,"nombre":"NPC"},
	}
	var confirmado: Dictionary = mundo._estado.criaturas.duplicate(true)
	mundo._dibujar_criaturas()
	var nodo: MeshInstance3D = mundo._nodos_criaturas[id]
	_ok("monster usa volumen", nodo.mesh is ArrayMesh and nodo.position.is_equal_approx(Vector3(1,.02,0)))
	_ok("jugador conserva sprite", mundo._nodos_criaturas[2].mesh is QuadMesh)
	_ok("NPC conserva sprite", mundo._nodos_criaturas[0x80000001].mesh is QuadMesh)
	mundo._reloj_animacion = 1.0 / mundo.FOTOGRAMAS_POR_SEGUNDO
	var quieta := nodo.mesh
	mundo._animar_criaturas()
	_ok("cambia malla al animar", nodo.mesh != quieta and nodo.material_override == null)
	_ok("render no muta estado", mundo._estado.criaturas == confirmado)
	mundo._estado.criaturas[id]["direccion"] = 1
	mundo._dibujar_criaturas()
	_ok("giro este y reutilizacion", nodo == mundo._nodos_criaturas[id] and is_equal_approx(nodo.rotation.y, PI*.5))
	mundo._estado.criaturas[id]["apariencia"] = 34
	mundo._dibujar_criaturas()
	_ok("cambio outfit", nodo.mesh == mundo._modelos_monstruos.malla(34,1))
	for tipo_arana in [30,36,38,208,219,27,52,3,16,42,123,28,81,26,82,83,79,43,45,124,13,14,60,31,74,32,94,33,37,15,53,76,111,212,217,218,35]:
		mundo._estado.criaturas[id]["apariencia"] = tipo_arana
		for direccion in range(4):
			mundo._estado.criaturas[id]["direccion"] = direccion
			mundo._dibujar_criaturas()
			_ok("familia integrada %d/%d" % [tipo_arana,direccion], nodo.scale == Vector3.ONE and (nodo.mesh.get_blend_shape_count() == 24 if catalogo.tiene_clips(tipo_arana) else nodo.mesh == mundo._modelos_monstruos.malla(tipo_arana,1)) and is_equal_approx(nodo.rotation.y, MODELOS.GIROS[direccion]))
	mundo._estado.criaturas[id]["apariencia"] = 128
	mundo._dibujar_criaturas()
	_ok("vuelve a sprite", nodo.mesh is QuadMesh and nodo.rotation == Vector3.ZERO and nodo.material_override != null)
	mundo._estado.criaturas[id]["apariencia"] = 35
	mundo._dibujar_criaturas()
	_ok("regresa de sprite a volumen sin lamina",
		nodo.mesh is ArrayMesh and nodo.material_override == null
		and nodo.scale == Vector3.ONE
		and bool(nodo.get_meta("volumen_monstruo",false)))
	mundo._estado.criaturas[id]["pos"].z = 8
	mundo._dibujar_criaturas()
	_ok("piso oculto elimina nodo", not mundo._nodos_criaturas.has(id))
	mundo._estado.criaturas.clear()
	mundo._dibujar_criaturas()
	_ok("retirada limpia nodos", mundo._nodos_criaturas.is_empty() and mundo._animaciones_criaturas.is_empty())
	mundo.free()
	print("MONSTERS_3D: %d comprobaciones, %d fallas" % [comprobaciones,fallas])
	quit(0 if fallas == 0 else 1)
