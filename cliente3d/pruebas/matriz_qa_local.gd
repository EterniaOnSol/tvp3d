extends SceneTree

const RUTA_REPORTE := "res://generated/reports/qa_matrix_local.json"


func _init() -> void:
	var casos := [
		{
			"nombre": "coordenadas",
			"argumentos": PackedStringArray(["--headless", "--path", _raiz(),
				"pruebas/test_coordenadas.tscn"]),
		},
		{
			"nombre": "controles",
			"argumentos": PackedStringArray(["--headless", "--path", _raiz(),
				"pruebas/test_controles.tscn"]),
		},
		{
			"nombre": "formas_render",
			"argumentos": PackedStringArray(["--headless", "--path", _raiz(),
				"pruebas/test_formas_render.tscn"]),
		},
		{
			"nombre": "spells_animaciones",
			"argumentos": PackedStringArray(["--headless", "--path", _raiz(),
				"pruebas/prueba_spells_animaciones.tscn"]),
		},
		{
			"nombre": "magic_wall",
			"argumentos": PackedStringArray(["--headless", "--path", _raiz(),
				"pruebas/prueba_magic_wall.tscn"]),
		},
		{
			"nombre": "muerte_reentrada",
			"argumentos": PackedStringArray(["--headless", "--path", _raiz(),
				"pruebas/prueba_muerte_reentrada.tscn"]),
		},
		{
			"nombre": "estado_criatura_ui",
			"argumentos": PackedStringArray(["--headless", "--path", _raiz(),
				"pruebas/prueba_estado_criatura_ui.tscn"]),
		},
		{
			"nombre": "estado_criatura_protocolo",
			"argumentos": PackedStringArray(["--headless", "--path", _raiz(),
				"--script", "red/estado_criatura_self_test.gd"]),
		},
		{
			"nombre": "mapa772_protocolo",
			"argumentos": PackedStringArray(["--headless", "--path", _raiz(),
				"--script", "red/mapa_self_test.gd"]),
		},
		{
			"nombre": "eventos_visuales",
			"argumentos": PackedStringArray(["--headless", "--path", _raiz(),
				"pruebas/prueba_eventos_visuales.tscn"]),
		},
		{
			"nombre": "ir_trozos",
			"argumentos": PackedStringArray(["--headless", "--path", _raiz(),
				"pruebas/test_ir_trozos.tscn"]),
		},
		{
			"nombre": "proyecto_editor",
			"argumentos": PackedStringArray(["--headless", "--path", _raiz(),
				"--script", "editor/proyecto_self_test.gd"]),
		},
		{
			"nombre": "escena_editor",
			"argumentos": PackedStringArray(["--headless", "--path", _raiz(),
				"editor/editor3d.tscn", "--", "--self-test"]),
		},
	]
	var resultados: Array = []
	var fallas := 0
	for caso in casos:
		var salida: Array[String] = []
		var codigo := OS.execute(OS.get_executable_path(), caso["argumentos"], salida, true)
		var texto := "\n".join(salida)
		var correcto := codigo == 0
		if not correcto:
			fallas += 1
		print("[qa] %s: %s (codigo=%d)" % [
			caso["nombre"], "OK" if correcto else "FALLO", codigo])
		resultados.append({
			"nombre": caso["nombre"],
			"ok": correcto,
			"codigo": codigo,
			"salida": texto,
		})
	var reporte := {
		"format": "tvp3d.qa.matrix.v1",
		"scope": "local",
		"results": resultados,
		"passed": resultados.size() - fallas,
		"failed": fallas,
	}
	_guardar_reporte(reporte)
	print("[qa] matriz local: %d/%d OK" % [resultados.size() - fallas, resultados.size()])
	quit(1 if fallas > 0 else 0)


func _raiz() -> String:
	return ProjectSettings.globalize_path("res://")


func _guardar_reporte(reporte: Dictionary) -> void:
	var ruta_absoluta := ProjectSettings.globalize_path(RUTA_REPORTE)
	var directorio := ruta_absoluta.get_base_dir()
	DirAccess.make_dir_recursive_absolute(directorio)
	var archivo := FileAccess.open(ruta_absoluta, FileAccess.WRITE)
	if archivo == null:
		printerr("[qa] no se pudo escribir el reporte: %s" % ruta_absoluta)
		return
	archivo.store_string(JSON.stringify(reporte, "\t"))
