class_name CoordenadasTibia3D
extends RefCounted

## Conversion reversible entre la posicion logica de Tibia y el espacio 3D.
## Ejes: X de Tibia -> X de mundo, Y de Tibia -> Z de mundo, Z de Tibia
## -> altura de mundo. La superficie Tibia z=7 es la referencia vertical.

const SUPERFICIE_Z := 7
const SQM_WORLD_SIZE := 1.0
const FLOOR_WORLD_HEIGHT := 1.0


static func tibia_a_mundo(posicion: Vector3i, ancla: Vector3i,
		tamano_sqm: float = SQM_WORLD_SIZE,
		altura_piso: float = FLOOR_WORLD_HEIGHT) -> Vector3:
	assert(tamano_sqm > 0.0, "SQM_WORLD_SIZE debe ser positivo")
	assert(altura_piso > 0.0, "FLOOR_WORLD_HEIGHT debe ser positivo")
	return Vector3(
		float(posicion.x - ancla.x) * tamano_sqm,
		float(SUPERFICIE_Z - posicion.z) * altura_piso,
		float(posicion.y - ancla.y) * tamano_sqm)


static func mundo_a_tibia(posicion: Vector3, ancla: Vector3i,
		tamano_sqm: float = SQM_WORLD_SIZE,
		altura_piso: float = FLOOR_WORLD_HEIGHT) -> Vector3i:
	assert(tamano_sqm > 0.0, "SQM_WORLD_SIZE debe ser positivo")
	assert(altura_piso > 0.0, "FLOOR_WORLD_HEIGHT debe ser positivo")
	return Vector3i(
		ancla.x + roundi(posicion.x / tamano_sqm),
		ancla.y + roundi(posicion.z / tamano_sqm),
		SUPERFICIE_Z - roundi(posicion.y / altura_piso))


static func chunk_de(posicion: Vector3i, lado: int = 64) -> Vector2i:
	assert(lado > 0, "El lado del chunk debe ser positivo")
	return Vector2i(
		floori(float(posicion.x) / float(lado)),
		floori(float(posicion.y) / float(lado)))


static func local_de_chunk(posicion: Vector3i, lado: int = 64) -> Vector2i:
	var chunk := chunk_de(posicion, lado)
	return Vector2i(
		posicion.x - chunk.x * lado,
		posicion.y - chunk.y * lado)


static func clave_chunk(posicion: Vector3i, lado: int = 64) -> String:
	var chunk := chunk_de(posicion, lado)
	return "%d_%d" % [chunk.x, chunk.y]
