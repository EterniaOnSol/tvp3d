extends RefCounted

const TEXTURADA := preload("res://propio/monstruos3d/animacion_texturada.gd")
var _texturadas: Dictionary = {}

const CARPETA := "res://propio/monstruos3d/mallas/"
const GIROS := [PI, PI * .5, 0.0, -PI * .5]
var fichas: Dictionary = {}
var _cache: Dictionary = {}
var _material: StandardMaterial3D


func _init() -> void:
	if FileAccess.file_exists(CARPETA + "catalogo.json"):
		var datos = JSON.parse_string(FileAccess.get_file_as_string(CARPETA + "catalogo.json"))
		if datos is Dictionary and datos.get("version") == 1:
			fichas = datos.get("monstruos", {})
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 1.0
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func tiene(tipo: int) -> bool:
	return fichas.has(str(tipo))


func es_monstruo(id: int, tipo: int) -> bool:
	return id >= 0x40000000 and id < 0x80000000 and tiene(tipo) \
		and bool(fichas[str(tipo)].get("anatomia", false))


func fases(tipo: int) -> int:
	return int(fichas.get(str(tipo), {}).get("fases", 1))


func malla(tipo: int, fase: int = 0) -> ArrayMesh:
	if tiene_clips(tipo):
		var banco = _banco_texturado(tipo)
		return banco.pose(fase) if banco != null else null
	if not tiene(tipo):
		return null
	if not _cache.has(tipo):
		_cache[tipo] = _cargar(tipo)
	var lista: Array = _cache[tipo]
	return lista[posmod(fase, lista.size())] if not lista.is_empty() else null


func _cargar(tipo: int) -> Array:
	var archivo := FileAccess.open(CARPETA + str(fichas[str(tipo)]["archivo"]), FileAccess.READ)
	if archivo == null or archivo.get_buffer(8).get_string_from_ascii() != "TVPVOL01":
		push_warning("Malla de monstruo ausente o invalida: %d" % tipo)
		return []
	var cantidad := archivo.get_32()
	if cantidad < 1 or cantidad > 32:
		return []
	var resultado: Array = []
	for fase in range(cantidad):
		var n := archivo.get_32()
		if n < 3 or n > 1000000 or n % 3 != 0 or archivo.get_length() - archivo.get_position() < n * 27:
			return []
		var posiciones := archivo.get_buffer(n * 12).to_float32_array()
		var normales := archivo.get_buffer(n * 12).to_float32_array()
		var rgb := archivo.get_buffer(n * 3)
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var colores := PackedColorArray()
		vertices.resize(n)
		normals.resize(n)
		colores.resize(n)
		for i in range(n):
			var j := i * 3
			vertices[i] = Vector3(posiciones[j], posiciones[j+1], posiciones[j+2])
			normals[i] = Vector3(normales[j], normales[j+1], normales[j+2])
			colores[i] = Color8(rgb[j], rgb[j+1], rgb[j+2])
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colores
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, _material)
		resultado.append(mesh)
	return resultado


func tiene_clips(tipo: int) -> bool:
	return fichas.get(str(tipo),{}).get("formato","") == "TVPVOL02"

func _banco_texturado(tipo: int):
	if not _texturadas.has(tipo):
		var ficha: Dictionary = fichas[str(tipo)]
		var banco = TEXTURADA.new()
		if not banco.cargar(CARPETA+str(ficha["archivo"]),ficha,CARPETA+str(ficha["textura"])):
			push_warning("Demon texturado invalido: %d"%tipo)
			return null
		_texturadas[tipo] = banco
	return _texturadas[tipo]

func aplicar_clip(nodo: MeshInstance3D, tipo: int, tiempo: float, clip: String = "caminar") -> void:
	if not tiene_clips(tipo):
		return
	var banco = _banco_texturado(tipo)
	if banco != null:
		banco.aplicar(nodo,clip,tiempo)

func animar_confirmado(nodo: MeshInstance3D, tipo: int, tiempo: float, posicion: Vector3i) -> void:
	if not tiene_clips(tipo):
		return
	var estado: Dictionary = nodo.get_meta("paso_demon",{})
	if int(estado.get("tipo",-1)) != tipo:
		estado = {"tipo":tipo,"pos":posicion,"hasta":-1.0}
	elif estado["pos"] != posicion:
		var anterior: Vector3i = estado["pos"]
		# A teleport is a new placement, not an invented walking sequence.
		var distancia := absi(anterior.x-posicion.x)+absi(anterior.y-posicion.y)
		estado["hasta"] = tiempo+.45 if anterior.z==posicion.z and distancia<=2 else -1.0
		estado["pos"] = posicion
	nodo.set_meta("paso_demon",estado)
	aplicar_clip(nodo,tipo,tiempo,"caminar" if tiempo<float(estado["hasta"]) else "reposo")

func invalidar(tipo: int) -> void:
	_cache.erase(tipo)
	_texturadas.erase(tipo)
