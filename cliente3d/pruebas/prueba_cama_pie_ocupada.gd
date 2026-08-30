extends SceneTree

## Regresion del bug visto en vivo en Mill Avenue 1 (house 81): al aceptar la
## cama, el servidor transforma cabecera y pie a sus variantes "ocupadas"
## (servidor 1764/1765 -> client 2497/2498). `_es_cama_modelo` decide que
## casilla recibe la malla 3D grande de "persona durmiendo"; si el pie
## ocupado tambien calificaba, las dos mitades dibujaban la malla completa
## superpuesta -dos figuras cruzadas sobre una sola cama real.
##
## `_es_cama_dormida` (que textura usar) y `_es_cama_modelo` (que casilla
## recibe la malla grande) son preguntas distintas: un pie ocupado debe seguir
## "dormida" pero nunca "modelo".

const MUNDO := preload("res://mundo3d.gd")
const CATALOGO := preload("res://red/mapa772.gd")

## (cid, es_cabecera) para las dos parejas "bed" ocupadas confirmadas por
## catalogo (items772.json) y por el patron servidor+733 verificado en vivo
## con /tileinfo contra Mill Avenue 1: servidor 1764/1765 -> client 2497/2498.
## Solo el nombre "bed" recibe la malla 3D authored (bed.obj); "cot" siempre
## se dibuja como sprite plano aunque comparta el mismo mecanismo de pie/
## dormida, asi que sus cuatro cids se comprueban aparte.
const PARES_BED_OCUPADOS := [
	[2495, true], [2496, false],   # servidor 1762/1763 (Sunset Homes Flat 01)
	[2497, true], [2498, false],   # servidor 1764/1765 (Mill Avenue 1, house 81)
]
const IDS_COT_OCUPADOS := [2499, 2500, 2501, 2502]   # servidor 1766-1769


func _initialize() -> void:
	var mundo := MUNDO.new()
	mundo._catalogo = CATALOGO.new()

	for par in PARES_BED_OCUPADOS:
		var cid: int = par[0]
		var es_cabecera: bool = par[1]
		if not mundo._es_cama_dormida(cid):
			printerr("FALLO: %d deberia ser dormida (textura de ocupada)" % cid)
			quit(1)
			return
		var modelo := mundo._es_cama_modelo(cid)
		if modelo != es_cabecera:
			printerr("FALLO: _es_cama_modelo(%d) = %s, esperado %s (%s)" % [
				cid, str(modelo), str(es_cabecera),
				"cabecera" if es_cabecera else "pie"])
			quit(1)
			return
	print("OK: cada cabecera 'bed' ocupada recibe la malla grande y cada pie ocupado queda excluido")

	for cid in IDS_COT_OCUPADOS:
		if not mundo._es_cama_dormida(cid):
			printerr("FALLO: %d (cot) deberia ser dormida" % cid)
			quit(1)
			return
		if mundo._es_cama_modelo(cid):
			printerr("FALLO: %d (cot) no deberia calificar para la malla 3D de 'bed'" % cid)
			quit(1)
			return
		if not mundo._es_pieza_pie_cama(cid) and cid in [2500, 2502]:
			printerr("FALLO: el pie ocupado de cot %d salio de IDS_CAMA_PIE" % cid)
			quit(1)
			return
	print("OK: los cuatro cids de cot ocupado siguen fuera de la malla 3D de 'bed'")

	# La cabecera y el pie vacios de Mill Avenue 1 (2493/2494) no cambian con
	# este fix: 2493 sigue siendo modelo, 2494 sigue excluido.
	if not mundo._es_cama_modelo(2493) or mundo._es_cama_modelo(2494):
		printerr("FALLO: el par vacio de Mill Avenue 1 (2493/2494) cambio de clasificacion")
		quit(1)
		return
	print("OK: el par vacio de Mill Avenue 1 no se toco")

	mundo.free()
	quit(0)
