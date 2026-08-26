extends SceneTree

const PROYECTO := preload("res://editor/proyecto_tvp3d.gd")
const RUTA_PRUEBA := "user://tvp3d_editor_self_test.json"
const RUTA_EXPORTACION := "user://tvp3d_editor_self_export.json"

func _init() -> void:
	var proyecto = PROYECTO.new()
	proyecto.configurar_fuente("res://generated/maps/rookgaard_100sqm.json", Vector3i(32091, 32187, 7), 18)

	if not bool(proyecto.editar_tile(Vector3i(32091, 32187, 7), 1).get("ok", false)):
		_fallar("no pudo editar tile")
		return
	if not bool(proyecto.editar_perfil(123, "box", 1.5, 0.25).get("ok", false)):
		_fallar("no pudo editar perfil")
		return
	if proyecto.tipo_en(Vector3i(32091, 32187, 7)) != 1:
		_fallar("tipo de tile incorrecto")
		return
	if proyecto.perfil_en(123).get("primitive", "") != "box":
		_fallar("perfil incorrecto")
		return

	if not bool(proyecto.deshacer().get("ok", false)):
		_fallar("no pudo deshacer perfil")
		return
	if not proyecto.perfil_en(123).is_empty() or proyecto.tipo_en(Vector3i(32091, 32187, 7)) != 1:
		_fallar("deshacer perfil altero tile")
		return
	if not bool(proyecto.deshacer().get("ok", false)) or proyecto.tipo_en(Vector3i(32091, 32187, 7)) != -1:
		_fallar("no pudo deshacer tile")
		return
	if not bool(proyecto.rehacer().get("ok", false)) or proyecto.tipo_en(Vector3i(32091, 32187, 7)) != 1:
		_fallar("no pudo rehacer tile")
		return
	if not bool(proyecto.rehacer().get("ok", false)) or proyecto.perfil_en(123).get("height", 0.0) != 1.5:
		_fallar("no pudo rehacer perfil")
		return

	if not bool(proyecto.guardar(RUTA_PRUEBA).get("ok", false)):
		_fallar("no pudo guardar proyecto")
		return
	var cargado = PROYECTO.cargar_validado(RUTA_PRUEBA)
	if not bool(cargado.get("ok", false)):
		_fallar("no pudo cargar proyecto: %s" % cargado.get("error", ""))
		return
	var proyecto_cargado = cargado["proyecto"]
	if proyecto_cargado.a_diccionario() != proyecto.a_diccionario():
		_fallar("guardar/cargar no es determinista")
		return
	if not bool(proyecto_cargado.exportar(RUTA_EXPORTACION).get("ok", false)):
		_fallar("no pudo exportar proyecto")
		return

	if bool(proyecto.editar_tile(Vector3i(32091, 32187, 16), 1).get("ok", false)):
		_fallar("acepto z fuera de rango")
		return
	if bool(proyecto.editar_tile(Vector3i(32091, 32187, 7), 7).get("ok", false)):
		_fallar("acepto tipo fuera de rango")
		return

	_limpiar()
	print("Proyecto editor self-test: OK")
	quit(0)

func _fallar(mensaje: String) -> void:
	_limpiar()
	printerr("Proyecto editor self-test: FALLO: %s" % mensaje)
	quit(1)

func _limpiar() -> void:
	for ruta in [RUTA_PRUEBA, RUTA_EXPORTACION]:
		var absoluto := ProjectSettings.globalize_path(ruta)
		if FileAccess.file_exists(absoluto):
			DirAccess.remove_absolute(absoluto)
