extends Node

const MAGIC_WALL := preload("res://mundo/magic_wall_3d.gd")
const MUNDO := preload("res://mundo3d.gd")

var _fallas := 0


func _ready() -> void:
	var muro = MAGIC_WALL.new()
	add_child(muro)
	muro.configurar(2128)
	var caja := muro.mesh as BoxMesh
	_comprobar("usa el cubo 1x2x1 de 3DTIBIA",
		caja != null and caja.size == Vector3(1.0, 2.0, 1.0))
	_comprobar("usa una sola superficie maciza animada",
		muro.material_muro is StandardMaterial3D and muro.textura_fase != null
		and muro.material_muro.albedo_texture == muro.textura_fase)
	_comprobar("carga las tres fases originales",
		muro.fases == 3 and muro.fps == 5.0
		and muro.textura_fase != null)
	var textura_inicial = muro.textura_fase
	await get_tree().create_timer(0.23).timeout
	_comprobar("anima a 5 FPS",
		muro.fase == 1 and muro.textura_fase != textura_inicial)
	muro.configurar(2129)
	_comprobar("la variante persistente comparte la Magic Wall",
		muro.fases == 3 and muro.textura_fase != null)
	muro.queue_free()
	_comprobar("el renderer la registra como objeto dinamico",
		_probar_integracion_renderer())
	print("Magic Wall 3DTIBIA: %d falla(s)" % _fallas)
	get_tree().quit(1 if _fallas > 0 else 0)


func _comprobar(nombre: String, correcto: bool) -> void:
	if correcto:
		print("  OK  " + nombre)
	else:
		print("  FAIL " + nombre)
		_fallas += 1


func _probar_integracion_renderer() -> bool:
	var mundo := MUNDO.new()
	var piso := Node3D.new()
	mundo._piso_mundo = piso
	mundo.add_child(piso)
	var posicion := Vector3i(32097, 32219, 7)
	mundo._volcar_magic_wall_grupo({
		"cid": 2128,
		"donde": [Vector3(0.0, 1.0, 0.0)],
		"casillas": [posicion],
	})
	var muro = piso.get_child(0) if piso.get_child_count() == 1 else null
	var registrado: bool = mundo._instancias_por_casilla.get(posicion, []).size() == 1
	var visible_antes: bool = muro != null and muro.visible
	var centrado_como_3dtibia: bool = muro != null \
			and is_equal_approx(float(muro.position.y), 1.0)
	mundo._ocultar_instancias_base(posicion)
	var oculto_durante_parche: bool = muro != null and not muro.visible
	var resultado: bool = muro != null and visible_antes and centrado_como_3dtibia \
			and oculto_durante_parche and registrado
	mundo.free()
	return resultado
