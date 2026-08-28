extends SceneTree

const MODELO_OBJ := preload("res://mundo/modelo_obj.gd")
const MUNDO := preload("res://mundo3d.gd")
const SPRITES := preload("res://red/sprites772.gd")
const CATALOGO := preload("res://red/mapa772.gd")
const ESTADO := preload("res://red/estado_mundo.gd")

const RUTAS := [
	"res://assets/modelos/bed.obj",
	"res://assets/modelos/bed-person.obj",
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
		"donde": [Vector3(0.0, 0.42, 0.0)],
		"casillas": [Vector3i(32063, 32224, 7)],
	}
	mundo._volcar_cama_grupo(grupo, MODELO_OBJ.cargar(RUTAS[0]))
	if mundo._piso_mundo.get_child_count() != 1:
		printerr("FALLO: el renderer no creo la instancia 3D de la cama")
		quit(1)
		return
	print("OK: el renderer crea la instancia 3D de la cama")
	mundo._piso_mundo.free()
	mundo.free()
	quit(0)
