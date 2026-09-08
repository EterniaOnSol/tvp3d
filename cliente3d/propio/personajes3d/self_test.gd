extends SceneTree

const PERSONAJES := preload("res://propio/personajes3d/catalogo.gd")
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
	print("PERSONAJES_3D: %d comprobaciones, %d fallas" % [
		comprobaciones,fallas])
	quit(0 if fallas==0 else 1)
