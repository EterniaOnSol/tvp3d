extends RefCounted

## Catalogo de geometria 3D para los objetos semanticos del mapa.
##
## Esta capa no sabe nada del OTBM: recibe categoria, nombre y orientacion
## y devuelve un modelo compuesto de mallas reales. Asi el mapper puede
## cambiar de modelos procedurales a escenas GLB/TScn sin tocar la lectura
## del mapa ni las reglas del servidor.

var _materiales: Dictionary = {}


func crear_modelo(categoria: String, nombre: String, orientacion: String,
		client_id: int = 0) -> Node3D:
	var root := Node3D.new()
	var cat := categoria.to_lower()
	var n := nombre.to_lower()
	root.name = "Model_%s_%d" % [cat, client_id]
	root.set_meta("model_category", cat)
	root.set_meta("model_name", nombre)
	root.set_meta("client_id", client_id)

	var solido := false
	var colision := Vector3(0.78, 0.80, 0.78)
	match cat:
		"ground":
			_parte(root, _caja(Vector3(1.0, 0.10, 1.0)), _material("ground", n),
				Vector3(0, 0.05, 0))
		"wall":
			var muro := Vector3(1.0, 1.0, 0.20)
			_parte(root, _caja(muro), _material("wall", n),
				Vector3(0, 0.50, 0))
			_anadir_zocalo(root, n)
			solido = true
			colision = muro
		"window":
			_crear_ventana(root, n)
			solido = true
			colision = Vector3(0.92, 0.92, 0.16)
		"door":
			if n.contains("trapdoor"):
				_parte(root, _caja(Vector3(0.92, 0.10, 0.92)),
					_material("door", n), Vector3(0, 0.05, 0))
			else:
				_crear_puerta(root, n)
				solido = true
				colision = Vector3(0.82, 0.90, 0.16)
		"stair":
			_crear_escalera(root, n)
			colision = Vector3(0.96, 0.85, 0.96)
		"crate":
			_crear_crate(root, n)
			solido = true
			colision = Vector3(0.78, 0.76, 0.78)
		"mailbox":
			_crear_mailbox(root, n)
			solido = true
			colision = Vector3(0.42, 0.92, 0.42)
		"sign":
			_crear_letrero(root, n)
			solido = true
			colision = Vector3(0.74, 0.72, 0.16)
		"roof":
			var techo := _caja(Vector3(1.06, 0.24, 1.06))
			_parte(root, techo, _material("roof", n), Vector3(0, 0.12, 0),
				Vector3(0, 0, 0.12))
		"container":
			_crear_cofre(root, n)
			solido = true
			colision = Vector3(0.82, 0.52, 0.72)
		"furniture":
			_crear_mueble(root, n)
			if not n.contains("carpet"):
				solido = true
				colision = Vector3(0.86, 0.58, 0.86)
		"nature":
			_crear_naturaleza(root, n)
		"interactive":
			_crear_interactivo(root, n)
			solido = true
			colision = Vector3(0.72, 0.66, 0.72)
		"decoration", "structure":
			_crear_decoracion(root, n)
		_:
			_crear_decoracion(root, n)

	if orientacion == "z" and cat in ["wall", "window", "door", "sign"] \
			and not n.contains("trapdoor"):
		root.rotation.y = PI * 0.5
	root.set_meta("solid", solido)
	root.set_meta("collision_size", colision)
	return root


func _caja(tamano: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = tamano
	return mesh


func _parte(root: Node3D, mesh: Mesh, material: StandardMaterial3D,
		posicion: Vector3 = Vector3.ZERO, rotacion: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var nodo := MeshInstance3D.new()
	nodo.mesh = mesh
	nodo.material_override = material
	nodo.position = posicion
	nodo.rotation = rotacion
	root.add_child(nodo)
	return nodo


func _material(familia: String, nombre: String) -> StandardMaterial3D:
	var clave := familia + ":" + _familia_nombre(nombre)
	if _materiales.has(clave):
		return _materiales[clave]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.86
	mat.metallic = 0.0
	mat.albedo_color = _color_de(familia, nombre)
	_materiales[clave] = mat
	return mat


func _familia_nombre(nombre: String) -> String:
	if nombre.contains("wood") or nombre.contains("wooden"):
		return "wood"
	if nombre.contains("stone") or nombre.contains("brick") or nombre.contains("wall"):
		return "stone"
	if nombre.contains("grass") or nombre.contains("plant") or nombre.contains("tree"):
		return "green"
	return nombre


func _color_de(familia: String, nombre: String) -> Color:
	var n := nombre.to_lower()
	match familia:
		"ground":
			if n.contains("wood"): return Color("#9a6637")
			if n.contains("stone") or n.contains("brick"): return Color("#777779")
			if n.contains("sand"): return Color("#b49a62")
			return Color("#557348")
		"wall":
			if n.contains("wood") or n.contains("framework"): return Color("#7b4d2d")
			if n.contains("brick"): return Color("#914d38")
			return Color("#6d7076")
		"door": return Color("#704223")
		"roof": return Color("#463d4b")
		"window": return Color("#72a7bd")
		"crate": return Color("#a16a32")
		"mailbox": return Color("#416e92")
		"sign": return Color("#a9793e")
		"stair": return Color("#97643a")
		"container": return Color("#754826")
		"nature": return Color("#397047")
		"furniture":
			if n.contains("bed"): return Color("#a84e47")
			if n.contains("carpet") or n.contains("rug"): return Color("#8d3e48")
			return Color("#85552e")
		"interactive": return Color("#a08a46")
	return Color("#77736b")


func _anadir_zocalo(root: Node3D, nombre: String) -> void:
	var mat := _material("wall_trim", nombre)
	_parte(root, _caja(Vector3(1.02, 0.08, 0.23)), mat, Vector3(0, 0.08, 0))


func _crear_puerta(root: Node3D, nombre: String) -> void:
	var madera := _material("door", nombre)
	var marco := _material("wall", nombre)
	_parte(root, _caja(Vector3(0.80, 0.88, 0.12)), madera, Vector3(0, 0.44, 0))
	_parte(root, _caja(Vector3(0.07, 0.98, 0.20)), marco, Vector3(-0.44, 0.49, 0))
	_parte(root, _caja(Vector3(0.07, 0.98, 0.20)), marco, Vector3(0.44, 0.49, 0))
	_parte(root, _caja(Vector3(0.95, 0.07, 0.20)), marco, Vector3(0, 0.98, 0))
	_parte(root, _caja(Vector3(0.06, 0.06, 0.03)), _material("interactive", "handle"),
		Vector3(0.24, 0.45, -0.08))


func _crear_ventana(root: Node3D, nombre: String) -> void:
	var marco := _material("wall", nombre)
	var vidrio := _material("window", nombre)
	_parte(root, _caja(Vector3(0.82, 0.72, 0.08)), vidrio, Vector3(0, 0.52, 0.02))
	_parte(root, _caja(Vector3(0.08, 0.88, 0.18)), marco, Vector3(-0.43, 0.52, 0))
	_parte(root, _caja(Vector3(0.08, 0.88, 0.18)), marco, Vector3(0.43, 0.52, 0))
	_parte(root, _caja(Vector3(0.92, 0.08, 0.18)), marco, Vector3(0, 0.97, 0))
	_parte(root, _caja(Vector3(0.92, 0.08, 0.18)), marco, Vector3(0, 0.07, 0))
	_parte(root, _caja(Vector3(0.04, 0.76, 0.12)), marco, Vector3(0, 0.52, -0.04))
	_parte(root, _caja(Vector3(0.76, 0.04, 0.12)), marco, Vector3(0, 0.52, -0.04))


func _crear_escalera(root: Node3D, nombre: String) -> void:
	var mat := _material("stair", nombre)
	for i in range(4):
		var altura := 0.16 + float(i) * 0.16
		var z := -0.34 + float(i) * 0.22
		_parte(root, _caja(Vector3(0.92, altura, 0.25)), mat,
			Vector3(0, altura * 0.5, z))


func _crear_crate(root: Node3D, nombre: String) -> void:
	var madera := _material("crate", nombre)
	var liston := _material("crate_trim", nombre)
	_parte(root, _caja(Vector3(0.76, 0.72, 0.76)), madera, Vector3(0, 0.36, 0))
	_parte(root, _caja(Vector3(0.80, 0.07, 0.08)), liston, Vector3(0, 0.36, -0.39))
	_parte(root, _caja(Vector3(0.08, 0.76, 0.07)), liston, Vector3(0, 0.36, -0.40))


func _crear_mailbox(root: Node3D, nombre: String) -> void:
	var metal := _material("mailbox", nombre)
	var post := _material("mailbox_post", "post")
	_parte(root, _caja(Vector3(0.15, 0.70, 0.15)), post, Vector3(0, 0.35, 0))
	_parte(root, _caja(Vector3(0.46, 0.34, 0.38)), metal, Vector3(0, 0.78, 0))
	_parte(root, _caja(Vector3(0.30, 0.05, 0.05)), _material("interactive", "flag"),
		Vector3(0.25, 0.85, 0))


func _crear_letrero(root: Node3D, nombre: String) -> void:
	var madera := _material("sign", nombre)
	_parte(root, _caja(Vector3(0.10, 0.72, 0.10)), madera, Vector3(0, 0.36, 0))
	_parte(root, _caja(Vector3(0.76, 0.38, 0.10)), madera, Vector3(0, 0.75, 0))
	_parte(root, _caja(Vector3(0.54, 0.04, 0.03)), _material("sign_text", nombre),
		Vector3(0, 0.76, -0.07))


func _crear_cofre(root: Node3D, nombre: String) -> void:
	var madera := _material("container", nombre)
	_parte(root, _caja(Vector3(0.80, 0.42, 0.68)), madera, Vector3(0, 0.21, 0))
	_parte(root, _caja(Vector3(0.82, 0.07, 0.70)), _material("container_trim", nombre),
		Vector3(0, 0.45, 0))


func _crear_mueble(root: Node3D, nombre: String) -> void:
	var mat := _material("furniture", nombre)
	if nombre.contains("bed"):
		_parte(root, _caja(Vector3(0.90, 0.24, 0.96)), mat, Vector3(0, 0.12, 0))
		_parte(root, _caja(Vector3(0.86, 0.14, 0.30)), _material("bed_sheet", nombre),
			Vector3(0, 0.31, -0.28))
		return
	if nombre.contains("chair") or nombre.contains("stool"):
		_parte(root, _caja(Vector3(0.52, 0.10, 0.52)), mat, Vector3(0, 0.48, 0))
		for x in [-0.20, 0.20]:
			for z in [-0.20, 0.20]:
				_parte(root, _caja(Vector3(0.07, 0.48, 0.07)), mat, Vector3(x, 0.24, z))
		return
	if nombre.contains("carpet") or nombre.contains("rug"):
		_parte(root, _caja(Vector3(0.90, 0.035, 0.90)), mat, Vector3(0, 0.018, 0))
		return
	if nombre.contains("table") or nombre.contains("counter") or nombre.contains("desk"):
		_parte(root, _caja(Vector3(0.92, 0.12, 0.78)), mat, Vector3(0, 0.58, 0))
		for x in [-0.36, 0.36]:
			for z in [-0.28, 0.28]:
				_parte(root, _caja(Vector3(0.08, 0.56, 0.08)), mat, Vector3(x, 0.28, z))
		return
	if nombre.contains("oven") or nombre.contains("fireplace"):
		_parte(root, _caja(Vector3(0.76, 0.72, 0.68)), mat, Vector3(0, 0.36, 0))
		_parte(root, _caja(Vector3(0.42, 0.32, 0.04)), _material("interactive", "fire"),
			Vector3(0, 0.40, -0.36))
		return
	_parte(root, _caja(Vector3(0.78, 0.45, 0.78)), mat, Vector3(0, 0.225, 0))


func _crear_naturaleza(root: Node3D, nombre: String) -> void:
	var verde := _material("nature", nombre)
	if nombre.contains("tree") or nombre.contains("palm"):
		_parte(root, _caja(Vector3(0.20, 0.90, 0.20)), _material("nature_trunk", nombre),
			Vector3(0, 0.45, 0))
		_parte(root, _caja(Vector3(0.86, 0.72, 0.86)), verde, Vector3(0, 1.05, 0))
	else:
		_parte(root, _caja(Vector3(0.74, 0.45, 0.74)), verde, Vector3(0, 0.225, 0))


func _crear_interactivo(root: Node3D, nombre: String) -> void:
	var mat := _material("interactive", nombre)
	if nombre.contains("lever") or nombre.contains("switch"):
		_parte(root, _caja(Vector3(0.18, 0.62, 0.18)), mat, Vector3(0, 0.31, 0))
		_parte(root, _caja(Vector3(0.40, 0.10, 0.10)), mat, Vector3(0, 0.56, 0))
	else:
		_parte(root, _caja(Vector3(0.64, 0.60, 0.64)), mat, Vector3(0, 0.30, 0))


func _crear_decoracion(root: Node3D, nombre: String) -> void:
	var mat := _material("decoration", nombre)
	var mesh := _caja(Vector3(0.58, 0.45, 0.58))
	_parte(root, mesh, mat, Vector3(0, 0.225, 0), Vector3(0, 0.35, 0))
