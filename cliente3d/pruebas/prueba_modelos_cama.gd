extends SceneTree

const MODELO_OBJ := preload("res://mundo/modelo_obj.gd")
const MUNDO := preload("res://mundo3d.gd")
const SPRITES := preload("res://red/sprites772.gd")
const CATALOGO := preload("res://red/mapa772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const RUTAS := [
	"res://assets/modelos/bed.obj",
	"res://assets/modelos/bed-person.obj",
	"res://assets/modelos/street-lamp.obj",
]


func _init() -> void:
	for ruta in RUTAS:
		var malla := MODELO_OBJ.cargar(ruta)
		if malla == null or malla.get_surface_count() != 1 \
				or malla.get_aabb().size.y <= 0.0:
			printerr("FALLO: no se pudo convertir " + ruta)
			quit(1)
			return
		print("OK: %s -> ArrayMesh %s" % [ruta, str(malla.get_aabb().size)])
	var mundo := MUNDO.new()
	mundo._sprites = SPRITES.new()
	mundo._catalogo = CATALOGO.new()
	var info: Dictionary = mundo._catalogo.info_item(2487)
	if mundo._forma_de_item(2487, info) != MUNDO.Forma.MUEBLE:
		printerr("FALLO: el item 2487 no se clasifica como cama authored")
		quit(1)
		return
	print("OK: item 2487 se clasifica como mueble authored")
	mundo._estado = ESTADO.new()
	mundo._piso_mundo = Node3D.new()
	var grupo := {
		"cid": 2487,
		"donde": [Vector3(0.0, 0.01, 0.0)],
		"casillas": [Vector3i(32063, 32224, 7)],
	}
	mundo._volcar_cama_grupo(grupo, MODELO_OBJ.cargar(RUTAS[0]))
	if mundo._piso_mundo.get_child_count() != 1:
		printerr("FALLO: el renderer no creo la instancia 3D de la cama")
		quit(1)
		return
	var nodo_cama := mundo._piso_mundo.get_child(0) as MultiMeshInstance3D
	var base_modelo_y := nodo_cama.multimesh.mesh.get_aabb().position.y
	if absf(base_modelo_y) > 0.002:
		printerr("FALLO: la base de la cama no queda apoyada en el piso")
		quit(1)
		return
	print("OK: el renderer crea la instancia 3D de la cama")
	var info_lampara: Dictionary = mundo._catalogo.info_item(2109)
	if mundo._forma_de_item(2109, info_lampara) != MUNDO.Forma.LAMINA:
		printerr("FALLO: el item 2109 no se clasifica como street lamp")
		quit(1)
		return
	var grupo_lampara := {
		"cid": 2109,
		"forma": MUNDO.Forma.LAMINA,
		"orientacion": 0,
		"donde": [Vector3(2.0, 0.01, 0.0)],
		"casillas": [Vector3i(32064, 32224, 7)],
	}
	mundo._volcar_grupo("street-lamp", grupo_lampara)
	if mundo._piso_mundo.get_child_count() != 2:
		printerr("FALLO: el renderer no creo la street lamp authored")
		quit(1)
		return
	var nodo_lampara := mundo._piso_mundo.get_child(1) as MultiMeshInstance3D
	if nodo_lampara == null or nodo_lampara.multimesh == null \
			or nodo_lampara.multimesh.mesh.get_aabb().size.y < 1.0:
		printerr("FALLO: la street lamp no tiene una malla vertical valida")
		quit(1)
		return
	print("OK: el renderer crea la street lamp authored apoyada en el SQM")
	mundo._piso_mundo.free()
	mundo.free()
	quit(0)
