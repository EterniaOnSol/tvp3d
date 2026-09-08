extends RefCounted

const GIROS := [PI,PI*.5,0.0,-PI*.5]
const TIPOS := [128,129,130,131,132,133,134,136,137,138,139,140,141,142]
const NOMBRES := {
	128:"Citizen",129:"Hunter",130:"Mage",131:"Knight",132:"Nobleman",
	133:"Summoner",134:"Warrior",136:"Citizen",137:"Hunter",138:"Mage",
	139:"Knight",140:"Noblewoman",141:"Summoner",142:"Warrior",
}
const ESTILOS := {
	128:"citizen",129:"hunter",130:"mage",131:"knight",132:"noble",
	133:"summoner",134:"warrior",136:"citizen",137:"hunter",138:"mage",
	139:"knight",140:"noble",141:"summoner",142:"warrior",
}


func tiene(tipo: int) -> bool:
	return tipo in TIPOS


func nombre(tipo: int) -> String:
	if not tiene(tipo):
		return "Outfit desconocido"
	var sexo := "M" if tipo < 136 else "F"
	return "%s %s [%d]" % [NOMBRES[tipo],sexo,tipo]


func fases(_tipo: int) -> int:
	return 3


func color_outfit(indice: int) -> Color:
	indice = clampi(indice,0,132)
	var paso_h := indice%19
	if paso_h == 0:
		var valor := 1.0-float(indice)/19.0/7.0
		return Color(valor,valor,valor)
	var saturacion := .25
	var valor := 1.0
	match floori(float(indice)/19.0):
		1: saturacion = .25; valor = .75
		2: saturacion = .50; valor = .75
		3: saturacion = .667; valor = .75
		4: saturacion = 1.0; valor = 1.0
		5: saturacion = 1.0; valor = .75
		6: saturacion = 1.0; valor = .50
	return Color.from_hsv(float(paso_h)/18.0,saturacion,valor)


func crear(tipo: int,colores: Array = [78,94,115,40],
		direccion: int = 2,fase: int = 0) -> Node3D:
	if not tiene(tipo):
		return null
	var paleta := []
	for i in range(4):
		paleta.append(color_outfit(int(colores[i]) if i < colores.size() else 0))
	var raiz := Node3D.new()
	raiz.name = "Outfit%d" % tipo
	raiz.set_meta("tipo_outfit",tipo)
	raiz.set_meta("nombre_outfit",nombre(tipo))
	var femenino := tipo >= 136
	var piel := Color("dcae82")
	var oscuro := Color("252932")
	var metal := Color("aab2bd")
	var torso_x := .30 if femenino else .34
	_parte_caja(raiz,"Torso",Vector3(torso_x,.34,.19),Vector3(0,.59,0),paleta[1])
	_parte_esfera(raiz,"Cabeza",.115,Vector3(0,.87,0),piel)
	_parte_esfera(raiz,"Cabello",.122,Vector3(0,.905,-.012),paleta[0],
		Vector3(1,.72,1))
	_parte_caja(raiz,"Rostro",Vector3(.07,.055,.035),Vector3(0,.86,.112),piel)
	var paso: float = [0.0,.30,-.30][posmod(fase,3)]
	_brazo(raiz,-1,torso_x,paleta[1],-paso)
	_brazo(raiz,1,torso_x,paleta[1],paso)
	_pierna(raiz,-1,paleta[2],paleta[3],paso)
	_pierna(raiz,1,paleta[2],paleta[3],-paso)
	var estilo: String = ESTILOS[tipo]
	match estilo:
		"citizen":
			_parte_caja(raiz,"Chaleco",Vector3(torso_x+.035,.22,.205),
				Vector3(0,.62,.01),paleta[1].lightened(.12))
			_parte_caja(raiz,"Cinturon",Vector3(torso_x+.045,.055,.215),
				Vector3(0,.45,.01),oscuro)
			_parte_cilindro(raiz,"Gorra",.13,.105,.07,Vector3(0,1.005,0),paleta[0])
		"hunter":
			_parte_cono(raiz,"Capucha",.16,.09,.23,Vector3(0,.96,-.015),paleta[0])
			_parte_caja(raiz,"Capa",Vector3(.34,.43,.035),Vector3(0,.57,-.12),
				paleta[1].darkened(.16))
			_parte_caja(raiz,"Arco",Vector3(.035,.58,.035),Vector3(.27,.56,.02),
				Color("80552e"),Vector3(0,0,.22))
		"mage":
			_parte_cono(raiz,"Tunica",.25,.15,.48,Vector3(0,.38,0),paleta[1])
			_parte_cono(raiz,"Sombrero",.19,.025,.31,Vector3(0,1.08,0),paleta[0])
			_parte_cilindro(raiz,"AlaSombrero",.22,.22,.025,Vector3(0,.96,0),paleta[0])
			_baston(raiz,.28,paleta[3],Color("80552e"))
		"knight":
			_parte_caja(raiz,"Peto",Vector3(torso_x+.09,.39,.235),Vector3(0,.59,.01),metal)
			_parte_cilindro(raiz,"Casco",.14,.125,.20,Vector3(0,.95,0),paleta[0])
			_parte_caja(raiz,"Visera",Vector3(.25,.055,.045),Vector3(0,.90,.13),oscuro)
			_escudo(raiz,-.31,paleta[1])
		"noble":
			_parte_caja(raiz,"Capa",Vector3(.38,.47,.04),Vector3(0,.58,-.13),
				paleta[1].darkened(.12))
			_parte_cilindro(raiz,"Corona",.125,.10,.11,Vector3(0,1.005,0),
				Color("e4bf4d"))
			_parte_caja(raiz,"Cuello",Vector3(.37,.09,.24),Vector3(0,.74,0),paleta[0])
		"summoner":
			_parte_cono(raiz,"Tunica",.24,.14,.47,Vector3(0,.38,0),paleta[1])
			_parte_cono(raiz,"Capucha",.17,.105,.24,Vector3(0,.96,-.01),paleta[0])
			_baston(raiz,.29,paleta[0],Color("65452b"))
			_parte_esfera(raiz,"Orbe",.065,Vector3(.29,1.00,.02),paleta[3])
		"warrior":
			_parte_caja(raiz,"Armadura",Vector3(torso_x+.075,.37,.225),
				Vector3(0,.60,0),paleta[1])
			_parte_cilindro(raiz,"Yelmo",.145,.125,.20,Vector3(0,.96,0),metal)
			_parte_cono(raiz,"Cresta",.045,.01,.20,Vector3(0,1.10,-.01),paleta[0])
			_espada(raiz,.30,metal,oscuro)
	raiz.rotation.y = GIROS[posmod(direccion,4)]
	raiz.set_meta("aabb_comparacion",_calcular_aabb(raiz))
	return raiz


func aplicar_pose(raiz: Node3D,fase: int) -> void:
	var paso: float = [0.0,.30,-.30][posmod(fase,3)]
	for nombre in ["BrazoIzquierdo","PiernaDerecha"]:
		var parte := raiz.get_node_or_null(nombre) as Node3D
		if parte:
			parte.rotation.x = paso
	for nombre in ["BrazoDerecho","PiernaIzquierda"]:
		var parte := raiz.get_node_or_null(nombre) as Node3D
		if parte:
			parte.rotation.x = -paso


func aplicar_prioridad_local(raiz: Node) -> void:
	for hijo in raiz.get_children():
		var geometria := hijo as GeometryInstance3D
		if geometria != null:
			var material := geometria.material_override as StandardMaterial3D
			if material != null:
				var copia := material.duplicate() as StandardMaterial3D
				# Cada pieza necesita el z-buffer para ocultarse mutuamente y conservar
				# volumen. Sin depth test el torso termina tapando cabeza/extremidades.
				copia.no_depth_test = false
				copia.render_priority = 100
				geometria.material_override = copia
		aplicar_prioridad_local(hijo)


func _brazo(raiz: Node3D,lado: int,torso_x: float,color: Color,paso: float) -> void:
	var nombre := "BrazoIzquierdo" if lado < 0 else "BrazoDerecho"
	var brazo := _parte_capsula(raiz,nombre,.052,.31,
		Vector3(lado*(torso_x*.5+.055),.58,0),color)
	brazo.rotation = Vector3(paso,0,-lado*.10)


func _pierna(raiz: Node3D,lado: int,color: Color,pie: Color,paso: float) -> void:
	var nombre := "PiernaIzquierda" if lado < 0 else "PiernaDerecha"
	var pierna := _parte_capsula(raiz,nombre,.062,.37,
		Vector3(lado*.09,.25,0),color)
	pierna.rotation.x = paso
	var pie_nodo := _parte_caja(pierna,"Pie",Vector3(.13,.075,.20),
		Vector3(0,-.17,.045),pie)
	pie_nodo.rotation.x = -paso


func _baston(raiz: Node3D,x: float,color: Color,madera: Color) -> void:
	_parte_cilindro(raiz,"Baston",.018,.018,.72,Vector3(x,.50,.02),madera)
	_parte_esfera(raiz,"Gema",.055,Vector3(x,.89,.02),color)


func _escudo(raiz: Node3D,x: float,color: Color) -> void:
	_parte_cilindro(raiz,"Escudo",.18,.18,.045,Vector3(x,.57,.04),color,
		Vector3(PI*.5,0,0))


func _espada(raiz: Node3D,x: float,metal: Color,mango: Color) -> void:
	_parte_caja(raiz,"Hoja",Vector3(.045,.48,.025),Vector3(x,.59,.04),metal,
		Vector3(0,0,-.16))
	_parte_caja(raiz,"Mango",Vector3(.15,.035,.035),Vector3(x-.035,.34,.04),mango,
		Vector3(0,0,-.16))


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .78
	return material


func _parte(raiz: Node3D,nombre: String,malla: PrimitiveMesh,posicion: Vector3,
		color: Color,rotacion: Vector3 = Vector3.ZERO,
		escala: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var nodo := MeshInstance3D.new()
	nodo.name = nombre
	nodo.mesh = malla
	nodo.position = posicion
	nodo.rotation = rotacion
	nodo.scale = escala
	nodo.material_override = _material(color)
	raiz.add_child(nodo)
	return nodo


func _parte_caja(raiz: Node3D,nombre: String,tamano: Vector3,posicion: Vector3,
		color: Color,rotacion: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var malla := BoxMesh.new()
	malla.size = tamano
	return _parte(raiz,nombre,malla,posicion,color,rotacion)


func _parte_esfera(raiz: Node3D,nombre: String,radio: float,posicion: Vector3,
		color: Color,escala: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio*2.0
	return _parte(raiz,nombre,malla,posicion,color,Vector3.ZERO,escala)


func _parte_capsula(raiz: Node3D,nombre: String,radio: float,alto: float,
		posicion: Vector3,color: Color) -> MeshInstance3D:
	var malla := CapsuleMesh.new()
	malla.radius = radio
	malla.height = alto
	return _parte(raiz,nombre,malla,posicion,color)


func _parte_cilindro(raiz: Node3D,nombre: String,radio_arriba: float,
		radio_abajo: float,alto: float,posicion: Vector3,color: Color,
		rotacion: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var malla := CylinderMesh.new()
	malla.top_radius = radio_arriba
	malla.bottom_radius = radio_abajo
	malla.height = alto
	return _parte(raiz,nombre,malla,posicion,color,rotacion)


func _parte_cono(raiz: Node3D,nombre: String,radio: float,punta: float,
		alto: float,posicion: Vector3,color: Color) -> MeshInstance3D:
	return _parte_cilindro(raiz,nombre,punta,radio,alto,posicion,color)


func _calcular_aabb(raiz: Node3D) -> AABB:
	var resultado := AABB()
	var primero := true
	for hijo in raiz.get_children():
		var malla := hijo as MeshInstance3D
		if malla == null or malla.mesh == null:
			continue
		var caja: AABB = malla.transform*malla.mesh.get_aabb()
		resultado = caja if primero else resultado.merge(caja)
		primero = false
		for nieto in malla.get_children():
			var parte := nieto as MeshInstance3D
			if parte:
				var caja_nieto: AABB = malla.transform*parte.transform*parte.mesh.get_aabb()
				resultado = resultado.merge(caja_nieto)
	return resultado
