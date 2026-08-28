extends RefCounted

## Lector OBJ minimo para los modelos authored de TVP3D.
## Godot 4.7 no registra un loader OBJ en esta instalacion, pero los modelos
## de ASSETS3D solo necesitan vertices, UVs, normales y caras trianguladas.


static func cargar(ruta: String) -> ArrayMesh:
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		push_error("No se pudo abrir el modelo OBJ: " + ruta)
		return null

	var posiciones := PackedVector3Array()
	var normales := PackedVector3Array()
	var uvs := PackedVector2Array()
	var vertices := PackedVector3Array()
	var normales_finales := PackedVector3Array()
	var uvs_finales := PackedVector2Array()
	var indices := PackedInt32Array()
	var combinaciones := {}

	while not archivo.eof_reached():
		var linea := archivo.get_line().strip_edges()
		if linea.is_empty() or linea.begins_with("#"):
			continue
		var partes := linea.replace("\t", " ").split(" ", false)
		if partes.is_empty():
			continue
		match partes[0]:
			"v":
				if partes.size() >= 4:
					posiciones.append(Vector3(
						partes[1].to_float(), partes[2].to_float(),
						partes[3].to_float()))
			"vt":
				if partes.size() >= 3:
					# OBJ usa el origen UV abajo; Godot lo usa arriba.
					uvs.append(Vector2(partes[1].to_float(),
						1.0 - partes[2].to_float()))
			"vn":
				if partes.size() >= 4:
					normales.append(Vector3(
						partes[1].to_float(), partes[2].to_float(),
						partes[3].to_float()))
			"f":
				if partes.size() < 4:
					continue
				# Fan triangulation: sirve para las caras de cuatro vertices
				# que exporta Blender y conserva tambien triangulos simples.
				for indice_cara in range(2, partes.size() - 1):
					_agregar_vertice(partes[1], posiciones, uvs, normales,
						vertices, uvs_finales, normales_finales, indices,
						combinaciones)
					_agregar_vertice(partes[indice_cara], posiciones, uvs,
						normales, vertices, uvs_finales,
						normales_finales, indices, combinaciones)
					_agregar_vertice(partes[indice_cara + 1], posiciones, uvs,
						normales, vertices, uvs_finales,
						normales_finales, indices, combinaciones)

	archivo.close()
	if vertices.is_empty() or indices.is_empty():
		push_error("El modelo OBJ no contiene caras: " + ruta)
		return null

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales_finales
	arrays[Mesh.ARRAY_TEX_UV] = uvs_finales
	arrays[Mesh.ARRAY_INDEX] = indices
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malla


static func _agregar_vertice(token: String, posiciones: PackedVector3Array,
		uvs: PackedVector2Array, normales: PackedVector3Array,
		vertices: PackedVector3Array, uvs_finales: PackedVector2Array,
		normales_finales: PackedVector3Array, indices: PackedInt32Array,
		combinaciones: Dictionary) -> void:
	var partes := token.split("/")
	var indice_posicion := _indice_obj(int(partes[0]), posiciones.size())
	var indice_uv := _indice_obj(int(partes[1]), uvs.size()) \
			if partes.size() > 1 and not partes[1].is_empty() else -1
	var indice_normal := _indice_obj(int(partes[2]), normales.size()) \
			if partes.size() > 2 and not partes[2].is_empty() else -1
	var clave := "%d/%d/%d" % [indice_posicion, indice_uv, indice_normal]
	var indice: int
	if combinaciones.has(clave):
		indice = int(combinaciones[clave])
	else:
		indice = vertices.size()
		combinaciones[clave] = indice
		vertices.append(posiciones[indice_posicion] if indice_posicion >= 0 \
				and indice_posicion < posiciones.size() else Vector3.ZERO)
		uvs_finales.append(uvs[indice_uv] if indice_uv >= 0 \
				and indice_uv < uvs.size() else Vector2.ZERO)
		normales_finales.append(normales[indice_normal] if indice_normal >= 0 \
				and indice_normal < normales.size() else Vector3.UP)
	indices.append(indice)


static func _indice_obj(indice: int, cantidad: int) -> int:
	if indice > 0:
		return indice - 1
	if indice < 0:
		return cantidad + indice
	return -1
