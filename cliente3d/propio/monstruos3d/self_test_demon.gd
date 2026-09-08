extends SceneTree
const CATALOGO := preload("res://propio/monstruos3d/catalogo.gd")
const ESTADO := preload("res://red/estado_mundo.gd")
const SPRITES := preload("res://red/sprites772.gd")
class MundoPrueba:
	extends "res://mundo3d.gd"
	func _ready() -> void:
		set_process(false)
var pruebas := 0
var fallas := 0
func _initialize() -> void:
	call_deferred("probar")
func verificar(nombre: String, bien: bool) -> void:
	pruebas += 1
	if not bien:
		fallas += 1
		push_error(nombre)
func probar() -> void:
	var catalogo := CATALOGO.new()
	var primero := MeshInstance3D.new()
	var segundo := MeshInstance3D.new()
	catalogo.aplicar_clip(primero,35,.10,"reposo")
	catalogo.aplicar_clip(segundo,35,.25,"caminar")
	verificar("malla compartida GPU",primero.mesh == segundo.mesh)
	verificar("24 formas interpoladas",primero.mesh.get_blend_shape_count()==24)
	verificar("textura original",primero.mesh.surface_get_material(0).albedo_texture.get_width()==2048)
	verificar("UV original",primero.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV].size()>20000)
	var pesos1: Dictionary = primero.get_meta("mezcla_demon")["pesos"].duplicate()
	var pesos2: Dictionary = segundo.get_meta("mezcla_demon")["pesos"].duplicate()
	verificar("clips independientes",pesos1 != pesos2)
	catalogo.aplicar_clip(segundo,35,.375,"caminar")
	verificar("no muta otro demon",primero.get_meta("mezcla_demon")["pesos"]==pesos1)
	var suma := 0.0
	for i in range(segundo.mesh.get_blend_shape_count()):
		suma += segundo.get_blend_shape_value(i)
	verificar("pesos normalizados",is_equal_approx(suma,1))
	verificar("interpolacion entre poses",segundo.get_meta("mezcla_demon")["pesos"].values().all(func(v): return is_equal_approx(float(v),.5)))
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
	mundo._estado.criaturas = {id:{"pos":Vector3i(101,100,7),"apariencia":35,"direccion":2,"nombre":"Demon"}}
	var confirmado: Dictionary = mundo._estado.criaturas.duplicate(true)
	mundo._dibujar_criaturas()
	var nodo: MeshInstance3D = mundo._nodos_criaturas[id]
	verificar("spawn en reposo",nodo.get_meta("mezcla_demon")["clip"]=="reposo")
	mundo._reloj_animacion=.25
	mundo._animar_criaturas()
	verificar("respira quieto",nodo.get_meta("mezcla_demon")["clip"]=="reposo")
	verificar("sin autoridad cliente",mundo._estado.criaturas==confirmado)
	mundo._estado.criaturas[id]["pos"].x+=1
	mundo._reloj_animacion=.3
	mundo._dibujar_criaturas()
	verificar("paso confirmado camina",nodo.get_meta("mezcla_demon")["clip"]=="caminar")
	var inicio: float = nodo.get_meta("mezcla_demon")["inicio"]
	mundo._reloj_animacion=.4
	mundo._dibujar_criaturas()
	verificar("redibujar conserva transicion",is_equal_approx(nodo.get_meta("mezcla_demon")["inicio"],inicio))
	mundo._reloj_animacion=1.0
	mundo._animar_criaturas()
	verificar("detener vuelve a reposo",nodo.get_meta("mezcla_demon")["clip"]=="reposo")
	mundo._estado.criaturas[id]["pos"].x+=30
	mundo._dibujar_criaturas()
	verificar("teleport no inventa pasos",nodo.get_meta("mezcla_demon")["clip"]=="reposo")
	mundo._estado.criaturas[id]["apariencia"]=21
	mundo._dibujar_criaturas()
	verificar("limpia estado al cambiar apariencia",not nodo.has_meta("mezcla_demon") and not nodo.has_meta("paso_demon"))
	verificar("rat sin deformacion heredada",nodo.mesh.get_blend_shape_count()==0)
	mundo._estado.criaturas[id]["apariencia"]=128
	mundo._dibujar_criaturas()
	verificar("fallback intacto",nodo.mesh is QuadMesh)
	mundo._estado.criaturas[id]["apariencia"]=35
	mundo._dibujar_criaturas()
	verificar("retorno 3D con textura",nodo.mesh is ArrayMesh and nodo.mesh.get_blend_shape_count()==24 and nodo.material_override==null)
	verificar("retorno reinicia reposo",nodo.get_meta("mezcla_demon")["clip"]=="reposo")
	primero.free()
	segundo.free()
	mundo.free()
	print("DEMON_ANIMADO: %d comprobaciones, %d fallas"%[pruebas,fallas])
	quit(0 if fallas==0 else 1)
