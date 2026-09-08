extends RefCounted
# Shared textured pose bank; blend weights belong to each MeshInstance3D.
var clips: Dictionary = {}
var cuadros: Array = []
var uv := PackedVector2Array()
var indices := PackedInt32Array()
var material := StandardMaterial3D.new()
var animada: ArrayMesh
var estaticas: Dictionary = {}

func cargar(ruta: String, ficha: Dictionary, textura: String) -> bool:
	var f := FileAccess.open(ruta,FileAccess.READ)
	if f == null or f.get_buffer(8).get_string_from_ascii() != "TVPVOL02":
		return false
	var cantidad := f.get_32()
	var n := f.get_32()
	var ni := f.get_32()
	if cantidad < 2 or cantidad > 32 or n < 3 or n > 1000000 or ni < 3 or ni%3 != 0 or ni > 3000000:
		return false
	if f.get_length() != 20+n*8+ni*4+cantidad*n*24:
		return false
	var datos_uv := f.get_buffer(n*8).to_float32_array()
	uv.resize(n)
	for i in range(n):
		uv[i] = Vector2(datos_uv[i*2],datos_uv[i*2+1])
	indices = f.get_buffer(ni*4).to_int32_array()
	for i in indices:
		if i < 0 or i >= n:
			return false
	for _fase in range(cantidad):
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _vectores(f.get_buffer(n*12).to_float32_array())
		arrays[Mesh.ARRAY_NORMAL] = _vectores(f.get_buffer(n*12).to_float32_array())
		cuadros.append(arrays)
	var imagen := Image.load_from_file(textura)
	if imagen == null or imagen.is_empty():
		return false
	material.albedo_texture = ImageTexture.create_from_image(imagen)
	material.roughness = .8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	clips = ficha.get("clips",{}).duplicate(true)
	for nombre in clips:
		var clip: Dictionary = clips[nombre]
		if int(clip.get("inicio",0)) < 1 or int(clip.get("fases",0)) < 2 or float(clip.get("duracion",0)) <= 0:
			return false
		if int(clip["inicio"])+int(clip["fases"]) > cantidad:
			return false
	animada = ArrayMesh.new()
	animada.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	var formas: Array[Array] = []
	for i in range(1,cuadros.size()):
		animada.add_blend_shape("pose_%d"%i)
		formas.append(cuadros[i])
	var base: Array = cuadros[0].duplicate()
	base[Mesh.ARRAY_TEX_UV] = uv
	base[Mesh.ARRAY_INDEX] = indices
	animada.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,base,formas)
	animada.surface_set_material(0,material)
	var minimo: Array = ficha["min"]
	var maximo: Array = ficha["max"]
	var origen := Vector3(minimo[0],minimo[1],minimo[2])
	animada.custom_aabb = AABB(origen,Vector3(maximo[0],maximo[1],maximo[2])-origen)
	return true

func _vectores(floats: PackedFloat32Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	result.resize(floats.size()/3)
	for i in range(result.size()):
		result[i] = Vector3(floats[i*3],floats[i*3+1],floats[i*3+2])
	return result

func pose(fase: int, clip: String = "caminar") -> ArrayMesh:
	if not clips.has(clip):
		return null
	var info: Dictionary = clips[clip]
	var index := int(info["inicio"])+posmod(fase,int(info["fases"]))
	if not estaticas.has(index):
		var arrays: Array = cuadros[index].duplicate()
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(0,material)
		estaticas[index] = mesh
	return estaticas[index]

func aplicar(nodo: MeshInstance3D, clip: String, tiempo: float) -> void:
	if not clips.has(clip):
		clip = "reposo"
	if nodo.mesh != animada:
		nodo.mesh = animada
		nodo.set_meta("mezcla_demon",{})
	var estado: Dictionary = nodo.get_meta("mezcla_demon",{})
	if str(estado.get("clip","")) != clip:
		estado["desde"] = estado.get("pesos",{}).duplicate()
		estado["inicio"] = tiempo
		estado["clip"] = clip
	var info: Dictionary = clips[clip]
	var fase := fposmod(tiempo,float(info["duracion"]))/float(info["duracion"])*int(info["fases"])
	var primero := int(info["inicio"])+int(fase)-1
	var segundo := int(info["inicio"])+posmod(int(fase)+1,int(info["fases"]))-1
	var pesos := {primero:1.0-fmod(fase,1.0),segundo:fmod(fase,1.0)}
	var desde: Dictionary = estado.get("desde",{})
	var mezcla := clampf((tiempo-float(estado.get("inicio",tiempo)))/.18,0,1)
	if not desde.is_empty() and mezcla < 1:
		for id in pesos:
			pesos[id] *= mezcla
		for id in desde:
			pesos[id] = float(pesos.get(id,0))+float(desde[id])*(1-mezcla)
	for i in range(animada.get_blend_shape_count()):
		nodo.set_blend_shape_value(i,float(pesos.get(i,0)))
	estado["pesos"] = pesos
	nodo.set_meta("mezcla_demon",estado)
	nodo.material_override = null
