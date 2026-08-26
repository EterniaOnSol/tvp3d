extends Node

const IR_TROZOS := preload("res://red/ir_trozos.gd")
const INDICE := "res://generated/maps/rookgaard_100sqm_chunks/index.json"


func _ready() -> void:
	var lector := IR_TROZOS.new()
	if not lector.abrir(INDICE):
		print("[ir_trozos] FAIL: no se pudo abrir el indice")
		get_tree().quit(1)
		return

	var primera := lector.cargar_ventana(Vector3i(32080, 32210, 7), 4, 7, 7)
	var cache_primero := lector.chunks_cargados()
	if primera.is_empty() or cache_primero != 1:
		print("[ir_trozos] FAIL: primera ventana tiles=%d chunks=%d" % [
			primera.size(), cache_primero])
		get_tree().quit(1)
		return

	var segunda := lector.cargar_ventana(Vector3i(32110, 32250, 7), 4, 7, 7)
	var cache_segundo := lector.chunks_cargados()
	if segunda.is_empty() or cache_segundo != 1:
		print("[ir_trozos] FAIL: segunda ventana tiles=%d chunks=%d" % [
			segunda.size(), cache_segundo])
		get_tree().quit(1)
		return

	print("[ir_trozos] OK: ventanas=%d/%d tiles, cache=%d->%d chunks" % [
		primera.size(), segunda.size(), cache_primero, cache_segundo])
	get_tree().quit(0)
