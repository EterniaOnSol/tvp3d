# Contrato: modelo-comun

Version: 2.0.0
Estado: PUBLICADO
Propietario: modelo-comun
Depende de: ninguno

## Proposito y alcance

Congelar los valores y envoltorios comunes de Architecture V2 para que
servidor, protocolo, cliente, assets, editor y QA compartan identidad,
procedencia, coordenadas, ocupacion logica y estado autoritativo sin mezclar
dominio con presentacion.

Este contrato define primitivas. No define combate, inventario, IA, spawns,
persistencia fisica, Monster Domain ni Monster3D. Un contrato especializado
puede componer estas primitivas, pero no cambiar sus rangos o autoridad.

Las palabras `DEBE`, `NO DEBE` y `SOLO` son normativas.

## Convenciones de serializacion

- Los ejemplos y payloads canonicos usan objetos JSON RFC 8259 codificados en
  UTF-8.
- Un objeto no admite nombres de propiedad duplicados. Los objetos comunes
  rechazan propiedades desconocidas; la extension de un dominio vive solo en
  un `payload` publicado por el contrato que registra su `type`.
- Los enteros se serializan como numeros JSON, salvo los `uint64`, que se
  serializan como strings decimales para no perder precision en consumidores.
- `int32` significa `-2147483648..2147483647`.
- `uint32` significa `0..4294967295`.
- `uint64_string` cumple `^(0|[1-9][0-9]{0,19})$` y su valor numerico no
  supera `18446744073709551615`.
- `positive_uint64_string` usa la misma forma, pero excluye `0`.
- `uuid_v4` es ASCII minusculo y cumple
  `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`.
- `registry_token` cumple `^[A-Z][A-Z0-9_]{0,63}$`.
- Una version de schema es SemVer estable `MAJOR.MINOR.PATCH`, sin prefijo
  `v` ni metadata.
- Un valor objeto embebido hereda la version del documento o envoltorio. Un
  documento persistido o mensaje raiz siempre incluye `schema` y `version`.
- Para serializacion canonica, las claves se emiten en el orden mostrado por
  cada schema; los consumidores comparan significado, no orden de claves.

## 1. Identidad de dominio

### `CanonicalDomainId`

Es un string ASCII de tres segmentos:

```text
namespace:kind:key
```

Cada segmento empieza por letra minuscula. `namespace` y `kind` cumplen
`^[a-z][a-z0-9_]{0,31}$`; `key` cumple
`^[a-z][a-z0-9_]{0,63}$`. La longitud total maxima es 130 bytes.

Ejemplos validos:

```text
tvp3d:item:gold_coin
tvp3d:entity_type:player
```

Reglas:

- Es estable e inmutable dentro de una linea de datos publicada.
- Es unico en el registro de dominio que lo publica.
- La comparacion es byte a byte; no hay lowercase, trim ni Unicode implicito.
- `kind` describe la clase del registro, pero no habilita gameplay por si
  solo. El contrato especializado publica su significado.
- Un server id, client id, looktype, nombre XML, posicion OTBM o nombre de
  archivo nunca se convierte implicitamente en `CanonicalDomainId`.
- Un cambio de alias o recurso visual no cambia el id canonico.

### `DomainIdentityV2`

```json
{
  "schema": "tvp3d.domain_identity",
  "version": "2.0.0",
  "canonical_id": "tvp3d:item:gold_coin",
  "aliases": []
}
```

`canonical_id` es obligatorio. `aliases` contiene `0..256` valores
`SourceAliasV2`, ordenados canonicamente por
`system, source_version, kind, value`.

La identidad persistente es `canonical_id`. Los aliases explican procedencia
y compatibilidad; no son autoridad, no sustituyen el id y pueden ampliarse en
una version compatible del registro.

## 2. Alias de origen y procedencia

### `SourceAliasV2`

```json
{
  "system": "OTB",
  "source_version": "7.72",
  "kind": "OTB_SERVER_ID",
  "value": "2148"
}
```

`system` es un enum cerrado:

```text
TIBIA_SERVER
TIBIA_CLIENT
TVP
TFS
OTBM
OTB
XML
DAT
SPR
```

`source_version` tiene `1..64` caracteres ASCII y cumple
`^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$`. Identifica la version del dataset,
formato o revision consultada; no es la version de este contrato.

`kind` es un enum cerrado:

| Kind | Forma canonica de `value` |
|---|---|
| `SERVER_ID` | decimal `uint32`, sin ceros iniciales salvo `0` |
| `CLIENT_ID` | decimal `uint32`, sin ceros iniciales salvo `0` |
| `LOOKTYPE` | decimal `uint32`, sin ceros iniciales salvo `0` |
| `OTBM_POSITION` | `x,y,z`, sin espacios; `x/y int32`, `z 0..15` |
| `OTB_SERVER_ID` | decimal `uint32`, sin ceros iniciales salvo `0` |
| `XML_NAME` | UTF-8 NFC, `1..128` bytes, sin whitespace inicial/final |
| `DAT_THING_ID` | decimal `uint32`, sin ceros iniciales salvo `0` |
| `SPRITE_ID` | decimal `uint32`, sin ceros iniciales salvo `0` |

Reglas:

- La tupla exacta `(system, source_version, kind, value)` conserva la
  trazabilidad determinista.
- La misma tupla no puede repetirse dentro de `aliases`; se rechaza con
  `SOURCE_ALIAS_DUPLICATE`.
- Un alias es procedencia, no necesariamente una clave uno-a-uno. Dos
  definiciones pueden compartir un looktype si la fuente realmente lo hace.
  Un resolver que exige un solo resultado debe devolver
  `SOURCE_ALIAS_AMBIGUOUS`, no elegir por orden.
- Un importador puede proponer el mapping alias -> id canonico. Publicarlo
  requiere un registro explicito; no se deriva de un filename o de un numero.
- Un `system` o `kind` desconocido se rechaza. Agregar uno exige una version
  menor negociada de este contrato.

La procedencia cubre ids de servidor y cliente Tibia/TVP/TFS, looktypes y
referencias derivadas de OTBM/OTB/XML/DAT/SPR sin convertirlas en identidad
permanente.

## 3. `PosicionTibiaV2`

Representacion canonica embebida:

```json
{
  "x": 32097,
  "y": 32219,
  "z": 7
}
```

Invariantes:

- `x` e `y` son `int32`.
- `z` es un entero `0..15`.
- Dos posiciones son iguales solo si `x`, `y` y `z` coinciden exactamente.
- `z=7` es la superficie de referencia para presentacion. Un `z` menor se
  presenta mas alto y uno mayor mas bajo. Esto no declara que toda casilla
  con `z=7` sea suelo o caminable.
- Norte es `y-1`, este `x+1`, sur `y+1` y oeste `x-1`, en el mismo `z`.
- Sumas que desbordan `int32` se rechazan; no hacen wrap.
- No hay floats, `Vector3`, metros, transforms, vertices ni colliders en la
  autoridad de esta posicion.

### Chunks

`chunk_size` es un entero `1..65535`. Se calcula con division piso matematica,
usando intermedios de al menos 64 bits:

```text
chunk_x = floor(x / chunk_size)
chunk_y = floor(y / chunk_size)
local_x = x - chunk_x * chunk_size
local_y = y - chunk_y * chunk_size
```

`local_x` y `local_y` siempre quedan en `0..chunk_size-1`; `z` se conserva.
La direccion canonica de chunk es:

```json
{
  "chunk_x": -1,
  "chunk_y": 0,
  "z": 7,
  "local_x": 31,
  "local_y": 0
}
```

Para `x=-1`, `y=0`, `z=7`, `chunk_size=32`, el resultado anterior es
obligatorio. Truncar hacia cero produciria un chunk invalido. Los chunks son
organizacion de almacenamiento/streaming: nunca cambian identidad ni posicion.

La forma JSON de `PosicionTibiaV2` siempre usa las claves `x,y,z`, numeros
enteros y ningun campo extra.

## 4. `DirectionV2`

Enum cerrado:

```text
NORTH
EAST
SOUTH
WEST
```

La direccion es dominio semantico y no un angulo. Radianes, grados,
quaternions y rotaciones de renderer no son valores validos ni se
round-trippean al enum.

Las diagonales quedan reservadas para una capacidad posterior, como minimo
`2.1.0`. Un emisor `2.0.0` no puede producirlas y un consumidor `2.0.0` debe
rechazarlas. Movimiento diagonal y facing diagonal seran decisiones separadas;
ninguno se infiere del otro.

## 5. `LogicalFootprintV1`

El footprint versiona su propia semantica espacial para poder reutilizarse en
definiciones de dominio V2:

```json
{
  "version": 1,
  "anchor": {"dx": 0, "dy": 0},
  "cells": [
    {"dx": 0, "dy": 0}
  ]
}
```

Cada `dx/dy` es un entero `-127..127`. `cells` contiene `1..256` entradas.
`anchor` debe coincidir con exactamente una celda ocupada. No puede haber dos
celdas con el mismo par `(dx,dy)`.

La `PosicionTibiaV2` autoritativa de una entidad corresponde a `anchor`. Para
cada celda `c`, la ocupacion de mundo es:

```text
world_x = position.x + c.dx - anchor.dx
world_y = position.y + c.dy - anchor.dy
world_z = position.z
```

El resultado debe caber en `int32`. Las celdas se serializan ordenadas por
`dy` y luego por `dx`. El contrato comun no exige rectangularidad,
conectividad ni ausencia de huecos; un dominio especializado puede imponer
restricciones adicionales sin relajar las comunes.

Ejemplo 2x2 con la posicion anclada en la esquina suroeste local:

```json
{
  "version": 1,
  "anchor": {"dx": 0, "dy": 1},
  "cells": [
    {"dx": 0, "dy": 0},
    {"dx": 1, "dy": 0},
    {"dx": 0, "dy": 1},
    {"dx": 1, "dy": 1}
  ]
}
```

Invariante no negociable:

```text
logical_footprint
!= visual_bounds
!= visual_collision
!= GLB dimensions
```

El footprint pertenece a datos de dominio autoritativos. Nunca se calcula
desde una malla, AABB, collider, escala, rig, sprite o LOD.

## 6. Definicion de entidad e instancia runtime

### `RuntimeInstanceRefV2`

```json
{
  "scope_id": "550e8400-e29b-41d4-a716-446655440000",
  "instance_id": "42"
}
```

- `scope_id` es un `uuid_v4` emitido por el servidor para una ejecucion,
  mundo o epoch autoritativo.
- `instance_id` es un `positive_uint64_string` emitido por el servidor.
- El par completo identifica una instancia runtime. `instance_id` solo no
  tiene significado fuera de su scope.
- Un par no se reutiliza despues de retirar la instancia.
- No es identidad de especie, item, definicion, personaje persistente ni asset.

### `EntityDefinitionCoreV2`

```json
{
  "schema": "tvp3d.entity_definition",
  "version": "2.0.0",
  "identity": {
    "schema": "tvp3d.domain_identity",
    "version": "2.0.0",
    "canonical_id": "tvp3d:entity_type:player",
    "aliases": []
  },
  "definition_version": "1.0.0",
  "logical_footprint": {
    "version": 1,
    "anchor": {"dx": 0, "dy": 0},
    "cells": [{"dx": 0, "dy": 0}]
  }
}
```

`definition_version` es SemVer y versiona el contenido de esa definicion, no
el schema comun. Toda referencia debe fijar `canonical_id` y
`definition_version`. Cambiar aliases sin cambiar significado puede ser patch;
cambiar footprint o semantica requiere una version de definicion compatible
explicitamente migrada.

### `AuthoritativeEntityStateV2`

```json
{
  "schema": "tvp3d.entity_state",
  "version": "2.0.0",
  "runtime_id": {
    "scope_id": "550e8400-e29b-41d4-a716-446655440000",
    "instance_id": "42"
  },
  "definition": {
    "canonical_id": "tvp3d:entity_type:player",
    "definition_version": "1.0.0"
  },
  "position": {"x": 32097, "y": 32219, "z": 7},
  "direction": "NORTH",
  "revision": "0"
}
```

Invariantes:

- `runtime_id` identifica esta aparicion; `definition` identifica que es.
- `definition.canonical_id` y su version deben resolver una definicion
  publicada antes de aceptar el estado.
- El footprint efectivo se lee de esa version de definicion. No se repite ni
  se recalcula desde el renderer.
- `position`, `direction`, existencia y `revision` son producidos por el
  servidor.
- `revision` es `uint64_string`, empieza en `0` y aumenta estrictamente con
  cada mutacion autoritativa de esa instancia. No se decrementa ni se recicla.
- Retirar una instancia se expresa con un evento autoritativo; el cliente no
  conserva este record como existente despues de recibirlo.
- Estado semantico especializado no se agrega como diccionario libre a este
  schema. El contrato de dominio correspondiente debe publicar su propio
  schema/payload y referenciar `runtime_id`.

Esta separacion sustituye al `Entidad.id` generico de v1:

```text
definition/species/type identity
!= source alias
!= runtime instance identity
!= authoritative runtime state
```

## 7. Envoltorio de comandos/intenciones

### `CommandEnvelopeV2`

```json
{
  "schema": "tvp3d.command",
  "version": "2.0.0",
  "command_id": "7b1d9ad4-5d72-4b95-a00b-a6d83b302d7f",
  "actor": {
    "scope_id": "550e8400-e29b-41d4-a716-446655440000",
    "instance_id": "42"
  },
  "type": "MOVE",
  "payload": {
    "dx": 1,
    "dy": 0
  }
}
```

Todos los campos son obligatorios.

- `command_id` es un `uuid_v4` creado por el cliente y unico dentro de su
  conexion. Repetirlo se rechaza; no implica idempotencia salvo que el contrato
  del comando la publique.
- `actor` debe coincidir con la instancia autenticada/autorizada por el
  servidor. Conocer un `RuntimeInstanceRefV2` no concede control.
- `type` es un `registry_token` publicado. Un token sintacticamente valido
  pero no registrado se rechaza.
- `payload` es un objeto y se valida contra el schema exacto del `type`. No
  hay payload generico permisivo.
- Un comando valido sigue siendo una solicitud. No confirma posicion,
  direccion, footprint, dano, inventario ni ningun otro estado.

`MOVE` es el unico payload comun registrado en `2.0.0` para migrar la
intencion v1:

```json
{"dx": 0, "dy": -1}
```

`dx` y `dy` son enteros `-1..1` y deben cumplir
`abs(dx)+abs(dy)==1`. Es un paso cardinal propuesto en el mismo piso. El
servidor valida reglas y ocupacion antes de emitir un evento.

Combate, inventario y otros comandos no se definen en este contrato. Cada uno
requiere tipo, payload, ownership, errores y version propios antes de uso.

## 8. Envoltorio de eventos autoritativos

### `AuthoritativeEventEnvelopeV2`

```json
{
  "schema": "tvp3d.event",
  "version": "2.0.0",
  "event_id": "f88c92a7-72f1-4f50-8f52-6f5fa9f98259",
  "stream_id": "03fa9346-8dd7-43af-bc6c-e15597053641",
  "sequence": "1",
  "type": "ENTITY_MOVED",
  "subject": {
    "scope_id": "550e8400-e29b-41d4-a716-446655440000",
    "instance_id": "42"
  },
  "subject_revision": "1",
  "causation_command_id": "7b1d9ad4-5d72-4b95-a00b-a6d83b302d7f",
  "payload": {}
}
```

Todos los campos son obligatorios; los tres campos anulables usan JSON
`null`, no ausencia:

`ENTITY_MOVED` en el ejemplo solo demuestra la forma del envelope. Este
contrato comun no registra su payload ni autoriza comportamiento; el contrato
propietario debe publicarlo antes de emitirlo.

- `event_id` y `stream_id` son `uuid_v4` emitidos por el servidor.
- `sequence` es `positive_uint64_string` y aumenta exactamente en uno dentro
  de `stream_id`. Un nuevo stream comienza en `1`.
- `type` es un `registry_token` publicado por el contrato del evento.
- `subject` es `RuntimeInstanceRefV2|null`. Es `null` para un evento global.
- `subject_revision` es `uint64_string|null`. Si el evento reemplaza o muta
  estado de un subject, debe coincidir con la revision resultante; si no hay
  subject debe ser `null`.
- `causation_command_id` es `uuid_v4|null`. `null` significa que no deriva de
  un comando cliente identificable.
- `payload` es un objeto validado por `type`. No puede redefinir los campos
  reservados del envoltorio.

Un evento es inmutable y solo el servidor puede producirlo. El cliente puede
detectar duplicados por `event_id` y gaps por `stream_id/sequence`, pero no
rellena un gap inventando estado: solicita el mecanismo de recuperacion que
publique el protocolo.

### Comando no es evento

| Propiedad | Comando | Evento |
|---|---|---|
| Autor del envelope | cliente | servidor |
| Significado | intencion solicitada | hecho autoritativo |
| Identidad | `command_id` | `event_id` + `stream_id/sequence` |
| Actor/subject | actor que solicita | subject afectado o `null` |
| Puede cambiar estado confirmado por si solo | no | si, segun su contrato |
| Rechazo | no muta estado | evento/error autoritativo publicado |

No se hace cast, copia de campos ni reinterpretacion silenciosa entre ambos.

## 9. Metadata de ownership

`OwnershipClassV2` es un enum de documentacion/schema:

```text
SERVER
CLIENT_PRESENTATION
ASSETS
IMPORT_ONLY
```

No es un campo que el emisor pueda elegir dentro de comandos o eventos. Vive
en el registro de schemas y se valida con el rol de la conexion.

| Campo o categoria | Owner | Regla |
|---|---|---|
| `canonical_id` publicado, `definition_version` y `logical_footprint` | `SERVER` | El dominio autoritativo los consume; el cliente no los redefine |
| `SourceAliasV2` y evidencia de procedencia | `IMPORT_ONLY` | Importadores la producen; no es autoridad runtime |
| `runtime_id`, posicion/direccion confirmadas y `revision` | `SERVER` | Solo aparecen como verdad en snapshot/evento servidor |
| `event_id`, `stream_id`, `sequence`, `subject_revision` | `SERVER` | El cliente no los emite ni corrige |
| `command_id`, `type` y `payload` de intencion | `CLIENT_PRESENTATION` | El cliente origina input; el servidor valida y decide el resultado |
| Posicion/direccion dentro de una intencion futura | `CLIENT_PRESENTATION` | Son propuestas, nunca estado confirmado |
| Camara, interpolacion, UI y diagnosticos | `CLIENT_PRESENTATION` | Quedan fuera del estado de dominio |
| Mapping de id canonico a GLB/material/rig/LOD | `ASSETS` | Queda fuera de todos los schemas comunes |
| ids, nombres y flags extraidos sin normalizar | `IMPORT_ONLY` | Requieren mapping/validacion antes de dominio |

`CLIENT_PRESENTATION` en un comando describe autoria de input, no autoridad de
gameplay. Si un cliente envia un evento, incluye un campo `owner`, intenta
sobrescribir un campo `SERVER` o presenta estado como confirmado, el servidor
rechaza con `OWNERSHIP_VIOLATION` sin mutar el mundo.

## 10. Frontera de persistencia

| Dato | Semantica de vida | Persistencia |
|---|---|---|
| `CanonicalDomainId` | identidad estable de definicion/registro | persistente |
| `DomainIdentityV2.aliases` | procedencia y compatibilidad | persistente/auditable |
| `definition_version` y `logical_footprint` | datos versionados de definicion | persistentes |
| `scope_id` | epoch de runtime | solo runtime/sesion |
| `instance_id` | instancia dentro de un scope | solo runtime/sesion |
| posicion, direccion y revision | estado vivo autoritativo | politica del dominio servidor; nunca autoridad cliente |
| comando y `command_id` | input transitorio/deduplicacion acotada | no identidad persistente |
| evento, ids y secuencia | salida transitoria; puede auditarse | log opcional, nunca identidad canonica |
| payload especializado | segun contrato propietario | no se presume persistente |

Un dominio que necesite identidad persistente de una instancia concreta debe
publicar otro `CanonicalDomainId` o tipo persistente especializado. No puede
promover `RuntimeInstanceRefV2` ni `event_id` a identidad permanente.

Este contrato congela semantica, no motor, tablas ni formato fisico de
persistencia.

## 11. Dominio y referencias visuales

El dominio comun puede exponer `CanonicalDomainId` para que assets y el
registro cliente resuelvan una representacion. No contiene:

- ruta o filename `.glb`;
- material, textura o shader;
- skeleton, bone, rig o nombre de clip;
- datos de Blender;
- Astra o proveedor image-to-3D;
- mesh, AABB, collider visual o geometria LOD.

Un cambio visual no migra identidad, posicion, direccion, footprint ni estado
servidor. Una malla visible nunca determina colision u ocupacion de gameplay.

## Compatibilidad conservada de tiles/mapa v1

La version 1 publico `SUELO=0`, `PARED=1`, `AGUA=2`, `ARBOL=3`,
`ROCA=4`, `DECORACION=5` y `ESCALERA=6`, junto con el documento de mapa
`version: 1`. Esos valores y su significado historico no cambian.

Architecture V2 no convierte automaticamente ese documento en un IR de
dominio V2. Al migrarlo:

- `position/origen` se valida como `PosicionTibiaV2`;
- `tipo` conserva exactamente su enum/codigo v1;
- `caminable` se trata como hint `IMPORT_ONLY` del fixture v1;
- el servidor vuelve a decidir ocupacion y caminabilidad autoritativas;
- una version V2 de mapa/tiles requiere contrato propio; no se infiere en esta
  fase.

## Modelo de error

Todo validador comun devuelve exito o un unico error primario con esta forma:

```json
{
  "schema": "tvp3d.domain_error",
  "version": "2.0.0",
  "code": "POSITION_Z_OUT_OF_RANGE",
  "path": "$.position.z",
  "message": "z must be an integer in 0..15"
}
```

`code` es un `registry_token` de la tabla siguiente, `path` es JSONPath ASCII
de `1..256` caracteres y `message` es UTF-8 de `1..256` bytes, apto para
diagnostico y sin secretos. Se rechaza el objeto contenedor completo: no hay
defaults silenciosos ni mutacion parcial.

| Codigo | Condicion |
|---|---|
| `SCHEMA_VERSION_UNSUPPORTED` | `schema/version` ausente, mal formado o no soportado |
| `SCHEMA_FIELD_UNKNOWN` | Un objeto comun contiene un campo no publicado |
| `CANONICAL_ID_INVALID` | Forma, longitud o casing invalido |
| `CANONICAL_ID_DUPLICATE` | Dos registros publican el mismo id canonico |
| `SOURCE_SYSTEM_UNKNOWN` | `system` fuera del enum cerrado |
| `SOURCE_KIND_UNKNOWN` | `kind` fuera del enum cerrado |
| `SOURCE_VERSION_INVALID` | Version de fuente vacia o fuera de forma/rango |
| `SOURCE_VALUE_INVALID` | `value` no cumple la forma de su kind |
| `SOURCE_ALIAS_DUPLICATE` | La misma tupla aparece dos veces en una identidad |
| `SOURCE_ALIAS_AMBIGUOUS` | Se pidio un resultado unico a un alias compartido |
| `POSITION_XY_OUT_OF_RANGE` | `x` o `y` no es `int32` |
| `POSITION_Z_OUT_OF_RANGE` | `z` no es entero `0..15` |
| `POSITION_OVERFLOW` | Una operacion de posicion sale de `int32` |
| `CHUNK_SIZE_OUT_OF_RANGE` | `chunk_size` no esta en `1..65535` |
| `DIRECTION_UNKNOWN` | Valor fuera de `NORTH/EAST/SOUTH/WEST` |
| `FOOTPRINT_VERSION_UNSUPPORTED` | `LogicalFootprint.version != 1` |
| `FOOTPRINT_EMPTY` | `cells` no tiene entradas |
| `FOOTPRINT_TOO_LARGE` | Mas de 256 celdas |
| `FOOTPRINT_COORD_OUT_OF_RANGE` | Un `dx/dy` no esta en `-127..127` |
| `FOOTPRINT_ANCHOR_NOT_OCCUPIED` | `anchor` no aparece exactamente una vez en `cells` |
| `FOOTPRINT_CELL_DUPLICATE` | Dos celdas tienen el mismo `dx/dy` |
| `FOOTPRINT_POSITION_OVERFLOW` | Aplicar una celda desborda `int32` |
| `RUNTIME_SCOPE_ID_INVALID` | `scope_id` no es `uuid_v4` |
| `RUNTIME_INSTANCE_ID_INVALID` | Id cero, con ceros iniciales, no decimal o mayor que `uint64` |
| `RUNTIME_INSTANCE_ID_REUSED` | El servidor reutilizo un par retirado |
| `DEFINITION_UNKNOWN` | Id/version de definicion no publicado |
| `STATE_REVISION_INVALID` | Revision mal formada, repetida o decreciente |
| `COMMAND_SCHEMA_INVALID` | Forma/envoltorio de comando incompleto |
| `COMMAND_ID_INVALID` | `command_id` no es `uuid_v4` |
| `COMMAND_ID_DUPLICATE` | Id ya visto en la conexion |
| `COMMAND_ACTOR_MISMATCH` | Actor no corresponde a la sesion autorizada |
| `COMMAND_TYPE_UNKNOWN` | Token no registrado para esa version |
| `COMMAND_PAYLOAD_INVALID` | Payload no cumple el schema de `type` |
| `EVENT_SCHEMA_INVALID` | Forma/envoltorio de evento incompleto |
| `EVENT_NOT_SERVER_AUTHORED` | Un rol cliente intento emitir un evento |
| `EVENT_ID_INVALID` | Id de evento o stream no es `uuid_v4` |
| `EVENT_SEQUENCE_INVALID` | Secuencia no positiva, repetida o decreciente |
| `EVENT_STREAM_GAP` | La secuencia no es la siguiente del stream |
| `EVENT_SUBJECT_INVALID` | Subject/revision no cumple sus reglas de nulabilidad |
| `RESERVED_FIELD_OVERRIDE` | Un payload redefine campos del envelope |
| `OWNERSHIP_VIOLATION` | El emisor intenta afirmar o mutar un campo ajeno |

## Fixtures y contract tests requeridos

Esta fase especifica fixtures; no implementa comportamiento de produccion.
Cuando QA los materialice, cada caso debe validar el documento completo,
comparar el `code` exacto y comprobar cero mutaciones tras rechazo.

| Fixture | Caso minimo | Resultado obligatorio |
|---|---|---|
| `ID-VALID-001` | `tvp3d:item:gold_coin` | acepta y round-trip byte exacto |
| `ID-INVALID-001` | mayusculas, dos segmentos o key vacia | `CANONICAL_ID_INVALID` |
| `ID-DUPLICATE-001` | dos registros con el mismo id | `CANONICAL_ID_DUPLICATE` |
| `ALIAS-DUPLICATE-001` | misma tupla dos veces en `aliases` | `SOURCE_ALIAS_DUPLICATE` |
| `ALIAS-SYSTEM-001` | `system: UNKNOWN` | `SOURCE_SYSTEM_UNKNOWN` |
| `POSITION-Z-001` | `z=0` y `z=15` | acepta ambos |
| `POSITION-Z-002` | `z=-1` y `z=16` | `POSITION_Z_OUT_OF_RANGE` |
| `CHUNK-NEGATIVE-001` | `(-1,0,7)`, size 32 | chunk `(-1,0,7)`, local `(31,0)` |
| `DIRECTION-001` | cuatro valores publicados | acepta los cuatro |
| `DIRECTION-002` | `north`, `NORTHEAST` o `90` | `DIRECTION_UNKNOWN` |
| `FOOTPRINT-1X1-001` | anchor/cell `(0,0)` | una celda en `position` |
| `FOOTPRINT-MULTI-001` | ejemplo 2x2 de este contrato | cuatro celdas deterministas |
| `FOOTPRINT-DUP-001` | celda `(0,0)` repetida | `FOOTPRINT_CELL_DUPLICATE` |
| `FOOTPRINT-ANCHOR-001` | anchor ausente de cells | `FOOTPRINT_ANCHOR_NOT_OCCUPIED` |
| `FOOTPRINT-RANGE-001` | offset 128, cero celdas o 257 celdas | error de rango/tamano exacto |
| `RUNTIME-ID-001` | UUID v4 + ids `1` y maximo `uint64` | acepta |
| `RUNTIME-ID-002` | `0`, `01`, overflow o UUID no v4 | error runtime exacto |
| `COMMAND-VALID-001` | envelope `MOVE` cardinal completo | acepta como intencion |
| `COMMAND-INVALID-001` | UUID, actor, type o payload invalido | error `COMMAND_*` exacto |
| `EVENT-VALID-001` | evento servidor, sequence 1, subject/revision coherentes | acepta |
| `EVENT-INVALID-001` | evento emitido por cliente | `EVENT_NOT_SERVER_AUTHORED` |
| `EVENT-SEQUENCE-001` | stream pasa de 1 a 3 | `EVENT_STREAM_GAP` |
| `OWNERSHIP-001` | comando agrega `owner: SERVER` o estado confirmado | `OWNERSHIP_VIOLATION` |
| `VERSION-001` | `1.0.0`, `2.1.0` o `3.0.0` ante lector solo 2.0.0 | `SCHEMA_VERSION_UNSUPPORTED` |

La suite debe incluir tambien orden canonico de aliases/celdas, rechazo de
campos extra y los limites exactos de todos los strings/enteros.

## Compatibilidad y migracion desde 1.0.0

`2.0.0` es una version mayor deliberada. Un consumidor v1 confundiria el
`Entidad.id uint32` con la nueva separacion de definicion/instancia, no
entenderia ids `uint64_string`, direcciones inglesas mayusculas ni la
separacion comando/evento. Por eso no se edita silenciosamente el significado
de v1.

El contrato v1 permanece en la historia Git, publicado en `1f9865c`, y sus
reglas se conservan como perfil legacy hasta que cada consumidor migre.

| V1 | Regla de migracion a V2 |
|---|---|
| `PosicionTibia {x,y,z}` | Copiar solo tras validar rangos V2; no convertir a metros/`Vector3` |
| `direccion norte/este/sur/oeste` | Mapping cerrado a `NORTH/EAST/SOUTH/WEST` |
| `Entidad.id uint32` | Puede alimentar `runtime_id.instance_id` solo con `scope_id` servidor explicito; nunca `canonical_id` |
| `Entidad.nombre` | Label de presentacion/importacion; nunca identidad canonica |
| Tipo/especie implicito | Requiere `EntityDefinitionCoreV2` y mapping publicado |
| server/client id/looktype | Crear `SourceAliasV2`; nunca copiar a `canonical_id` |
| `IntencionDeAccion MOVER` | Crear UUID, actor runtime, `type: MOVE` y copiar `dx/dy` validos |
| `TransicionDeAccion` | No es evento V2. El servidor emite tipos de evento publicados; no se mapean estados por nombre |
| mapa/tile v1 | Conservar version/enum; tratar `caminable` como import hint hasta contrato de mapa V2 |

La tabla `SOLICITADA -> VALIDADA/RECHAZADA -> APLICADA -> EMITIDA` de
`CARRILES.md` permanece valida como lifecycle interno cerrado para resolver
una accion. `APLICADA` sigue siendo exclusiva del servidor. Esos estados no
son valores de `AuthoritativeEventEnvelopeV2.type` y no se exponen como hechos
de red sin que un contrato de evento publique su payload.

Reglas operativas de migracion:

1. Un boundary puede implementar dual-read v1/v2 si declara el perfil elegido;
   nunca mezcla campos de ambas versiones en un mismo objeto.
2. Todo writer nuevo de dominio comun produce V2 despues de migrar. No cambia
   el writer v1 usado por recorridos legacy hasta que su carril publique la
   migracion.
3. Falta de mapping canonico es error/deuda explicita; no se genera un id a
   partir de nombre, numero o filename.
4. Una version desconocida se rechaza. No se baja de version silenciosamente.
5. Un patch no cambia schema. Una minor puede agregar capacidad solo en puntos
   declarados extensibles y con negociacion; una major cambia significado o
   forma incompatible.

## Migraciones requeridas en contratos consumidores

Este contrato no edita otros carriles. Deja las solicitudes precisas:

| Carril/contrato actual | Migracion requerida |
|---|---|
| `protocolo-red 1.6.0` (depende de modelo 1.0.0) | Publicar un perfil V2 que negocie version y transporte `CommandEnvelopeV2` separado de `AuthoritativeEventEnvelopeV2`; usar runtime refs, direcciones V2 y rechazo de ownership/version. El framing/opcodes v1 y el adaptador 7.72 permanecen transicionales hasta ese turno. |
| `assets 1.4.0` | Adoptar ids canonicos y `SourceAliasV2` en un contrato del carril assets; `server_id/client_id/looktype` quedan como procedencia. Asociar recursos visuales fuera del dominio y no derivar footprint de GLB. |
| `servidor 1.1.0` (depende de modelo 1.0.0) | Referenciar definiciones/versiones, emitir scope/instance ids y eventos autoritativos, aplicar logical footprints y fijar politica de persistencia por dominio. No migrar comportamiento sin fixtures/paridad. |
| `cliente 1.30.0` (depende de modelo 1.0.0) | Consumir eventos/snapshots V2, conservar comandos como intenciones y mapear `canonical_id` a registros visuales sin confirmar estado ni usar bounds como footprint. |
| `editor 1.0.0` | Sustituir autoria permanente por `itemId` por `CanonicalDomainId`, conservando el numero original como alias/procedencia; mantener fuentes importadas read-only. |
| `qa 1.4.0` | Materializar los fixtures de esta tabla, probar roles de emisor y diferenciar oracle TVP transicional de autoridad final Godot. |

La siguiente migracion recomendada es `protocolo-red`, porque hoy declara
dependencia directa de modelo-comun 1.0.0 y es la frontera que debe impedir
que un comando se interprete como evento.

## Suficiencia para el futuro Monster Domain

Sin publicar Monster Domain, estas primitivas ya permiten que Phase 5 defina:

| Necesidad futura | Primitiva comun disponible |
|---|---|
| identidad estable de especie | `CanonicalDomainId` + `DomainIdentityV2` |
| looktype legacy | `SourceAliasV2 {system, source_version, kind: LOOKTYPE, value}` |
| instancia de monstruo | `RuntimeInstanceRefV2` |
| ocupacion SQM | `LogicalFootprintV1` |
| posicion/facing | `PosicionTibiaV2` + `DirectionV2` |
| estado confirmado | `AuthoritativeEntityStateV2` + envelope de evento |

El vocabulario semantico, stats, transiciones y tipos de evento de monstruo
siguen pendientes de Phase 5. No se registran aqui `idle/moving/attacking` ni
se autoriza implementacion. `docs/tibia3d/MONSTER_CONTRACT_PLAN.md` permanece
un plan; Monster3D y Cyclops siguen fuera de alcance.

## Consumidores y exclusiones

Consumidores: `servidor`, `protocolo-red`, `cliente`, `assets`, `editor`,
`qa` y contratos de dominio futuros.

Este contrato no expone credenciales, sesiones de autenticacion, tokens,
rutas privadas, framing/opcodes, almacenamiento fisico, reglas de gameplay ni
referencias visuales. Tampoco autoriza modificar `mundo3d.gd`, red, mapa,
TVP/TFS o codigo de produccion.
