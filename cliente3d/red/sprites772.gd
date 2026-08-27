extends RefCounted

# =====================================================================
#  Los dibujos del cliente 7.72, listos para usar en 3D.
#
#  No hay un PNG por item: estan todos pegados en unas pocas laminas de
#  2048x2048 y `indice.json` dice en que lamina y en que rectangulo quedo
#  cada uno.
#
#  OJO CON AtlasTexture: en 2D recorta bien, pero un material 3D lo IGNORA
#  y estira la lamina entera sobre cada cara. El sintoma es inconfundible:
#  cada casilla del piso muestra el mosaico completo de miles de dibujos.
#  La forma que si anda en 3D es pasar la lamina entera como textura y
#  mover el recorte con uv1_scale / uv1_offset del material. Por eso aca
#  se devuelve el rectangulo y no una textura ya recortada.
#
#  Todo esto lo genera herramientas/extraer_sprites772.py a partir del
#  Tibia.dat y el Tibia.spr oficiales de 7.72 que estan en
#  assets/cliente772/.
# =====================================================================

const CARPETA := "res://assets/sprites772/"

var _laminas: Array[Texture2D] = []
var _items := {}
var _outfits := {}
var _efectos := {}
var _proyectiles := {}
var _cache := {}
var _lado_lamina := 2048
var _listo := false


func _init() -> void:
	var f := FileAccess.open(CARPETA + "indice.json", FileAccess.READ)
	if f == null:
		push_error("Faltan los sprites. Corre herramientas/extraer_sprites772.py")
		return
	var datos = JSON.parse_string(f.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY:
		push_error("El indice de sprites no se entiende")
		return

	_items = datos.get("items", {})
	_outfits = datos.get("outfits", {})
	_efectos = datos.get("efectos", {})
	_proyectiles = datos.get("proyectiles", {})
	_lado_lamina = int(datos.get("lado_lamina", 2048))
	for n in range(int(datos.get("laminas", 0))):
		var ruta := CARPETA + "lamina_%02d.png" % n
		var tex := load(ruta)
		if tex == null:
			push_error("Falta " + ruta)
			return
		_laminas.append(tex)
	_listo = _laminas.size() > 0


func listo() -> bool:
	return _listo


func tiene_item(cid: int) -> bool:
	return _items.has(str(cid))


func alto_en_casillas(cid: int) -> int:
	var ficha = _items.get(str(cid))
	return int(ficha["alto"]) if ficha else 1


func ancho_en_casillas(cid: int) -> int:
	var ficha = _items.get(str(cid))
	return int(ficha["ancho"]) if ficha else 1


func fases_de_item(cid: int) -> int:
	var ficha = _items.get(str(cid))
	return ficha["c"].size() if ficha else 1


func cuadro_item(cid: int, fase: int = 0) -> Dictionary:
	"""Devuelve {"lamina": Texture2D, "escala": Vector3, "corrimiento": Vector3}
	para armar el material, o {} si el item no tiene dibujo."""
	var ficha = _items.get(str(cid))
	if ficha == null:
		return {}
	var cuadros: Array = ficha["c"]
	return _recorte(cuadros[fase % cuadros.size()])


func tiene_outfit(tipo: int) -> bool:
	return _outfits.has(str(tipo))


func alto_de_outfit(tipo: int) -> int:
	var ficha = _outfits.get(str(tipo))
	return int(ficha["alto"]) if ficha else 1


func fases_de_outfit(tipo: int, direccion: int = 0) -> int:
	var ficha = _outfits.get(str(tipo))
	if ficha == null:
		return 1
	var por_dir: Array = ficha["c"]
	if por_dir.is_empty():
		return 1
	return por_dir[direccion % por_dir.size()].size()


func cuadro_outfit(tipo: int, direccion: int, fase: int = 0) -> Dictionary:
	"""La direccion es la del servidor: 0 norte, 1 este, 2 sur, 3 oeste
	(el mismo orden que en el .dat)."""
	var ficha = _outfits.get(str(tipo))
	if ficha == null:
		return {}
	var por_dir: Array = ficha["c"]
	var fila: Array = por_dir[direccion % por_dir.size()]
	return _recorte(fila[fase % fila.size()])


func fases_de_efecto(tipo: int) -> int:
	var ficha = _efectos.get(str(tipo))
	return int(ficha.get("fases", ficha.get("c", []).size())) if ficha else 1


func cuadro_efecto(tipo: int, fase: int = 0) -> Dictionary:
	var ficha = _efectos.get(str(tipo))
	if ficha == null or ficha.get("c", []).is_empty():
		return {}
	var cuadros: Array = ficha["c"]
	return _recorte(cuadros[fase % cuadros.size()])


func fases_de_proyectil(tipo: int) -> int:
	var ficha = _proyectiles.get(str(tipo))
	return int(ficha.get("fases", ficha.get("c", []).size())) if ficha else 1


func cuadro_proyectil(tipo: int, fase: int = 0) -> Dictionary:
	var ficha = _proyectiles.get(str(tipo))
	if ficha == null or ficha.get("c", []).is_empty():
		return {}
	var cuadros: Array = ficha["c"]
	return _recorte(cuadros[fase % cuadros.size()])


func _recorte(sitio: Dictionary) -> Dictionary:
	var clave := "%d_%d_%d_%d_%d" % [
		sitio["l"], sitio["x"], sitio["y"], sitio["w"], sitio["h"]]
	if _cache.has(clave):
		return _cache[clave]
	var lado: float = float(_lado_lamina)
	var r := {
		"lamina": _laminas[int(sitio["l"])],
		"escala": Vector3(sitio["w"] / lado, sitio["h"] / lado, 1.0),
		"corrimiento": Vector3(sitio["x"] / lado, sitio["y"] / lado, 0.0),
		"clave": clave,
	}
	_cache[clave] = r
	return r
