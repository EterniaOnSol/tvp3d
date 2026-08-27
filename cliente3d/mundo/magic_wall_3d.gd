extends MeshInstance3D

class_name MagicWall3D

## Adaptacion directa del MagicWall3D que ya usaba 3DTIBIA. Las texturas
## siguen siendo los PNG originales de motor3d/assets/items_74.
const CARPETA := "res://assets/magic_wall_74/"
const ARCHIVO_INDICE := CARPETA + "_indice.json"
const FPS_POR_DEFECTO := 5.0

var id_item := 2128
var fases := 1
var fps := FPS_POR_DEFECTO
var fase := 0
var reloj := 0.0
var material_muro: StandardMaterial3D
var textura_fase: Texture2D


func configurar(iid: int = 2128) -> void:
	id_item = iid
	var indice := _leer_indice()
	var ficha: Dictionary = indice.get(str(id_item), {})
	fases = maxi(int(ficha.get("fases", 1)), 1)
	fps = maxf(float(ficha.get("fps", FPS_POR_DEFECTO)), 0.1)
	var caja := BoxMesh.new()
	# Igual que 3DTIBIA: un SQM de ancho, dos pisos de alto y un SQM de fondo.
	caja.size = Vector3(1.0, 2.0, 1.0)
	mesh = caja
	# El muro es una caja completamente opaca, igual que el cubo animado de
	# 3DTIBIA. Cada fase original se coloca sobre las seis caras del BoxMesh;
	# asi se conserva el volumen y el relampago cambia de dibujo sin recortes
	# ni una segunda geometria superpuesta.
	material_muro = StandardMaterial3D.new()
	material_muro.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material_muro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_muro.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_muro.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material_muro.albedo_color = Color.WHITE
	material_muro.emission_enabled = true
	material_muro.emission = Color.WHITE
	material_muro.emission_energy_multiplier = 0.35
	material_override = material_muro
	_cargar_fase()


func _leer_indice() -> Dictionary:
	var f := FileAccess.open(ARCHIVO_INDICE, FileAccess.READ)
	if f == null:
		return {}
	var datos = JSON.parse_string(f.get_as_text())
	f.close()
	return datos if datos is Dictionary else {}


func _ruta_fase() -> String:
	if fase <= 0:
		return CARPETA + "item_%05d.png" % id_item
	return CARPETA + "item_%05d_f%02d.png" % [id_item, fase]


func _cargar_fase() -> void:
	if material_muro == null:
		return
	var ruta := _ruta_fase()
	var imagen := Image.new()
	if imagen.load(ruta) != OK:
		fase = 0
		ruta = _ruta_fase()
		imagen = Image.new()
		if imagen.load(ruta) != OK:
			push_warning("No se pudo cargar la Magic Wall: " + ruta)
			return
	textura_fase = ImageTexture.create_from_image(imagen)
	material_muro.albedo_texture = textura_fase


func _process(delta: float) -> void:
	if fases <= 1:
		return
	reloj += delta
	if reloj < 1.0 / fps:
		return
	reloj = 0.0
	fase = (fase + 1) % fases
	_cargar_fase()
