# `PARITY-HOUSE-DOOR-GUEST-SUBOWNER-001` — Puerta de casa: invitado frente a subdueno

Estado: **CERTIFICADO**. Fixture `LEGACY_PARITY` de Phase 2; contrato QA
`2.1.1`, protocolo-red `2.3.0`. La captura fue **HUMAN-DRIVEN** y su origen
normativo es `LIVE_ORACLE`. No se ejecuto ninguna accion viva adicional durante
la materializacion.

## Resultado certificado

La comparacion usa el mismo actor, la misma puerta ordinaria de House 83 y la
lista especifica de esa puerta vacia en ambos brazos:

| Brazo | Estado de acceso | Resultado autoritativo |
|---|---|---|
| ARM 1 | invitado general; no owner; no subowner; door-list vacia | `Sorry, not possible.` clase `23` (`0x17`); puerta sigue `CLOSED`; actor sigue afuera |
| ARM 2 | subowner; no owner; door-list vacia | uso permitido; la misma puerta transiciona `CLOSED -> OPEN` |

Esto certifica exactamente: **GENERAL HOUSE GUEST ONLY + selected door-specific
list EMPTY -> DENIED**, mientras que **SUBOWNER + la misma lista vacia -> ALLOWED**.
No significa que los invitados nunca puedan usar puertas: pertenecer a la lista
especifica de la puerta es una via separada.

## Relacion con el codigo legacy

La implementacion auditada en `servidor/src/house.cpp:578-589` (`Door::canUse`)
devuelve `true` si no hay casa, o si `House::getHouseAccessLevel(player)` es al
menos `HOUSE_SUBOWNER` (`house.cpp:584-586`); para los demas jugadores consulta
`accessList->isInList(player)` (`house.cpp:588`). La llamada durante el uso de un
item puerta esta en `servidor/src/actions.cpp:181-185`. Por eso owner/subowner
pueden pasar sin estar en la lista individual, pero un invitado general necesita
la lista de la puerta seleccionada.

## Evidencia cruda conservada

- Casa: `83`, `Mill Avenue 3` (`servidor/data/world/map-house.xml:85`).
- Exterior medido: `(32410,32184,7)`.
- Puerta medida: `(32410,32185,7)`.
- Mapeo de la puerta: `house_door_id=4`, server item cerrado `1221`, client
  item `1640`, nombre `closed door` (`cliente3d/generated/world_mapper/world_objects.jsonl:56328`).
- Server item abierto: `1222`, nombre runtime `open door`, observado en el
  brazo positivo; el cierre final volvio a `1221`.
- La captura ARM 1 persistio el snapshot PRE/POST en el observador QA y contiene
  el texto y clase exactos, el estado autoritativo de la puerta, la posicion
  exterior y cero eventos de apertura.

## Limpieza y alcance

La limpieza posterior dejo owner `0`, guest/subowner/door lists vacias, puerta
`1221 CLOSED` y `house_lists = 0 rows`. No se reasigno la casa, no se edito otra
lista, no se repitio ARM 2 y no se automatizo ninguna accion humana. Los archivos
del observador son infraestructura QA pasiva: reutilizan el `Mundo` normal y su
`_estado`, no duplican conexion/parser, no contienen credenciales, secretos ni
rutas absolutas, y no cambian produccion.

No se certifican otras casas, otras puertas, comodines, persistencia entre
reinicios, compra/alquiler/transferencia ni requisitos premium.
