# Contrato: protocolo-red

Version: 2.0.0
Estado: PUBLICADO
Propietario: protocolo-red
Depende de: modelo-comun 2.0.0

## Proposito y alcance normativo

Protocol V2 transporta intenciones desde el cliente Godot 3D y hechos
autoritativos desde el servidor Godot headless final. TCP, el frame V2 y el
payload son capas distintas. El protocolo valida transporte, sesion y forma;
no define reglas de gameplay.

```text
Godot 3D Client
      |
      | Protocol V2
      |
Godot Headless Authoritative Server
```

Este contrato no reinterpreta Protocol 1.x ni el protocolo TVP 7.72. Ambos se
conservan como perfiles historico y legacy separados. Ningun endpoint 1.x o
7.72 puede entrar a una sesion V2 sin un adaptador explicito.

Las palabras `DEBE`, `NO DEBE`, `PUEDE` y `RECHAZA` son normativas.

## Dependencia comun

Protocol V2 consume sin redefinir los schemas de modelo-comun 2.0.0:

- RuntimeInstanceRefV2 para referencias de instancia (scope_id + instance_id);
- CommandEnvelopeV2 para toda intencion;
- AuthoritativeEventEnvelopeV2 para todo hecho del servidor;
- PosicionTibiaV2, DirectionV2 y sus invariantes;
- errores y ownership comunes.

Un campo transportado no se convierte en autoridad por cruzar la red. Un
session_id, un id de TCP, un client id legacy, un looktype o un opcode nunca
es identidad de dominio.

## Capas del protocolo

### Capa 1: TCP stream

TCP es un flujo ordenado de bytes, no una API de paquetes. Una recepcion puede
contener un encabezado parcial, un payload parcial, exactamente un frame o
varios frames concatenados. El decoder:

1. conserva todos los bytes no consumidos;
2. espera hasta tener los 16 bytes del header;
3. valida el header antes de reservar el payload;
4. espera el payload completo y luego consume exactamente un frame;
5. repite mientras haya otro frame completo.

Nunca asume fronteras de recv(), nunca salta bytes para resincronizar y nunca
interpreta bytes restantes despues de un error de framing. El buffer
persistente maximo es 524320 bytes (dos frames maximos completos); el
integrador debe alimentar el decoder por porciones para no reservar mas. Si
un frame parcial o bytes no consumidos exceden ese limite, cierra la sesion
con BUFFER_LIMIT_EXCEEDED.

### Capa 2: frame binario V2

Todo frame usa exactamente este header de 16 bytes, little-endian donde se
indica:

| Offset | Tamano | Campo | Regla en 2.0.0 |
|---:|---:|---|---|
| 0 | 4 | magic | ASCII TVP2 (54 56 50 32) |
| 4 | 2 | protocol_major | uint16 LE, exactamente 2 |
| 6 | 2 | protocol_minor | uint16 LE, exactamente 0 negociado |
| 8 | 1 | message_kind | registro cerrado 0x01..0x0A |
| 9 | 1 | flags | exactamente 0; no compresion/encriptacion |
| 10 | 2 | reserved | uint16 LE, exactamente 0 |
| 12 | 4 | payload_length | uint32 LE, 1..262144 |

El payload ocupa los payload_length bytes siguientes, es UTF-8 estricto sin
BOM y es un objeto JSON. El header mas payload mide como maximo 262160 bytes.
No hay checksum, terminador, compresion ni encriptacion en la capa 2.0.0.
TLS, autenticacion y gestion de credenciales son contratos de integracion
posteriores; este contrato no inventa proveedores ni secretos.

protocol_major desconocido se rechaza; un cambio de major nunca se interpreta
como otro perfil. Solo se acepta protocol_minor=0 en esta version. Flags o
reserved no cero se rechazan. Un payload_length=0 o mayor que 262144 se
rechaza. El decoder no continua despues de un header invalido.

### Capa 3: payload

El payload debe ser un objeto JSON RFC 8259 con nombres sin duplicar,
profundidad maxima 32 y sin miembros desconocidos en schemas de protocolo.
Los envelopes comunes se validan exactamente segun modelo-comun; los campos
uint64 siguen siendo strings decimales. El orden de claves no altera el
significado, aunque los ejemplos muestran el orden canonico.

## Registro cerrado de message kinds

Los numeros son estables y no son acciones de gameplay:

| Valor | Kind | Direccion | Payload exacto |
|---:|---|---|---|
| 0x01 | CLIENT_HELLO | cliente -> servidor | schema de handshake |
| 0x02 | SERVER_WELCOME | servidor -> cliente | schema de handshake |
| 0x03 | COMMAND | cliente -> servidor | CommandEnvelopeV2 |
| 0x04 | EVENT | servidor -> cliente | AuthoritativeEventEnvelopeV2 |
| 0x05 | SNAPSHOT | servidor -> cliente | envelope snapshot V2 |
| 0x06 | SYNC_REQUEST | cliente -> servidor | envelope sync V2 |
| 0x07 | PROTOCOL_ERROR | servidor -> cliente | ProtocolErrorV2 |
| 0x08 | PING | cliente -> servidor | payload ping V2 |
| 0x09 | PONG | servidor -> cliente | payload pong V2 |
| 0x0A | GOODBYE | ambos, segun cierre | payload goodbye V2 |

Un valor fuera de este registro produce MESSAGE_KIND_UNKNOWN. MOVE,
ENTITY_MOVED, ataques, animaciones y cualquier otro concepto de dominio no
obtienen opcode propio. COMMAND transporta el tipo registrado por el contrato
propietario; EVENT transporta el tipo registrado por su dominio. No existen
kinds de monstruos, GLB, rigs o clips.

## Handshake

El cliente inicia una conexion con un frame CLIENT_HELLO cuyo header ya usa
TVP2, major 2 y minor 0. Su objeto exacto es:

```json
{
  "schema": "tvp3d.protocol.client_hello",
  "version": "2.0.0",
  "protocol_versions": [{"major": 2, "minor": 0}],
  "common_domain_versions": ["2.0.0"],
  "capabilities": []
}
```

protocol_versions contiene de 1 a 8 pares unicos; major/minor son uint16.
common_domain_versions contiene de 1 a 16 SemVer unicos. capabilities
contiene cero a 64 registry_token unicos; en 2.0.0 todos son opcionales.
Campos extra, duplicados o listas fuera de limite son invalidos. No hay
usuario, contrasena, token, clave ni configuracion de proveedor.

El servidor responde con SERVER_WELCOME solo si selecciona major 2, minor 0
y common domain 2.0.0 anunciados por el cliente:

```json
{
  "schema": "tvp3d.protocol.server_welcome",
  "version": "2.0.0",
  "protocol_version": {"major": 2, "minor": 0},
  "common_domain_version": "2.0.0",
  "session_id": "9b7d8c4e-8e64-4f3b-a9e6-5efc17a8b2d1",
  "runtime_scope_id": "550e8400-e29b-41d4-a716-446655440000",
  "capabilities": []
}
```

session_id identifica esta conexion y es transitorio. runtime_scope_id es el
scope que debe aparecer en los RuntimeInstanceRefV2 de esta sesion; lo asigna
el servidor y tampoco sustituye una identidad canonica. El servidor devuelve
solo capacidades que selecciono de la oferta. Si no hay interseccion de
versiones, envia COMMON_DOMAIN_VERSION_UNSUPPORTED si puede y cierra. No hay
downgrade silencioso. READY significa protocolo negociado, no autenticacion
de usuario; autenticacion es una preocupacion separada.

## Maquina de estados de conexion

CONNECTED es el instante TCP inicial y transiciona automaticamente a
NEGOTIATING. Los estados observables son:

| Estado | Cliente -> servidor | Servidor -> cliente | Transicion |
|---|---|---|---|
| CONNECTED | ninguno | ninguno | -> NEGOTIATING |
| NEGOTIATING | solo CLIENT_HELLO una vez | SERVER_WELCOME o PROTOCOL_ERROR | welcome -> READY; error -> CLOSING |
| READY | COMMAND, SYNC_REQUEST, PING, GOODBYE | EVENT, SNAPSHOT, PROTOCOL_ERROR, PONG, GOODBYE | gap -> SYNCING; goodbye -> CLOSING |
| SYNCING | PING, GOODBYE | SNAPSHOT, PONG, PROTOCOL_ERROR, GOODBYE | snapshot valido -> READY |
| CLOSING | solo GOODBYE ya iniciado | solo GOODBYE/cierre TCP | -> CLOSED |
| CLOSED | ninguno | ninguno | terminal |

EVENT nunca es legal cliente -> servidor y COMMAND nunca es legal servidor
-> cliente. Un mensaje ilegal produce ROLE_VIOLATION, no muta el mundo y
cierra. Un CLIENT_HELLO duplicado produce HANDSHAKE_DUPLICATE. Antes de
READY, cualquier mensaje distinto de hello produce HANDSHAKE_REQUIRED.

## COMMAND

El payload de kind COMMAND es exactamente CommandEnvelopeV2 de modelo-comun
2.0.0; no se envuelve ni se redefine. El protocolo comprueba schema/version,
forma, actor.scope_id igual a runtime_scope_id, tamano y que type sea un
registro publicado por un contrato de dominio. El dominio propietario valida
reglas, permisos, ocupacion y efectos. Un comando valido sigue siendo una
intencion y nunca confirma estado. Un comando con payload semantico invalido
recibe rechazo del servidor/dominio sin mutar el mundo; no se etiqueta como
corrupcion de framing.

El unico tipo comun de migracion publicado es MOVE, con dx/dy cardinales de
modelo-comun. Combate, inventario y monstruos requieren contratos propietarios
posteriores.

## EVENT

El payload de kind EVENT es exactamente AuthoritativeEventEnvelopeV2 de
modelo-comun 2.0.0. Solo el servidor puede producirlo. El protocolo garantiza
el orden de bytes de la conexion, y el cliente acepta eventos solo para el
stream_id activo con sequence igual a last_accepted + 1.

- Un event_id repetido con el mismo contenido ya aceptado es idempotente: se
  descarta sin reaplicar.
- El mismo event_id con contenido distinto, o una secuencia ya aceptada con
  contenido distinto, es conflicto: no se aplica y se inicia sync.
- Una secuencia mayor que la esperada es gap: no se aplica ningun evento
  posterior, el cliente entra en SYNCING y envia SYNC_REQUEST.
- Una subject_revision menor que la revision conocida del subject es stale:
  no se aplica y se solicita sync. La comparacion no inventa reglas de
  dominio sobre revisiones iguales.

El cliente nunca inventa eventos faltantes ni confirma por si mismo un evento
recibido fuera de secuencia.

## SNAPSHOT

Kind SNAPSHOT usa este envelope generico, sin campos de mundo, jugador o
monstruo:

```json
{
  "schema": "tvp3d.protocol.snapshot",
  "version": "2.0.0",
  "stream_id": "03fa9346-8dd7-43af-bc6c-e15597053641",
  "last_sequence": "42",
  "snapshot_id": "f88c92a7-72f1-4f50-8f52-6f5fa9f98259",
  "payload_type": "WORLD_STATE",
  "payload_version": "1.0.0",
  "payload": {}
}
```

Todos los campos son obligatorios. stream_id y snapshot_id son uuid_v4;
last_sequence es uint64_string y puede ser "0"; payload_type es
registry_token publicado por el dominio; payload_version es SemVer; y payload
es un objeto validado por ese dominio. Protocol V2 solo transporta el objeto.

El snapshot establece o ancla exactamente el stream_id que lleva. Al
aceptarlo, el cliente reemplaza atomicamente el estado del payload_type y fija
last_accepted_sequence = last_sequence; el siguiente evento valido debe ser
last_sequence + 1. Un stream nuevo puede comenzar en cualquier snapshot
autoritativo; un snapshot atrasado del stream actual se descarta y mantiene
SYNCING si no puede demostrar una baseline monotona. El servidor no reanuda
event replay en 2.0.0.

## SYNC_REQUEST y recuperacion

El cliente envia este objeto en kind SYNC_REQUEST:

```json
{
  "schema": "tvp3d.protocol.sync_request",
  "version": "2.0.0",
  "stream_id": "03fa9346-8dd7-43af-bc6c-e15597053641",
  "last_accepted_sequence": "41",
  "reason": "SEQUENCE_GAP"
}
```

stream_id es uuid_v4 o null para INITIAL; last_accepted_sequence es
uint64_string; reason es uno de INITIAL, SEQUENCE_GAP, DUPLICATE_CONFLICT,
STALE_SUBJECT_REVISION o MANUAL.

La recuperacion minima y determinista de V2 es un SNAPSHOT autoritativo. No
se exige ni se presume un log de replay. Mientras SYNCING, el servidor no
envia eventos y el cliente no envia comandos. El snapshot aceptado fija la
baseline y devuelve ambos a READY; PING y GOODBYE siguen permitidos.

## PING/PONG y GOODBYE

PING y PONG usan:

```json
{"schema":"tvp3d.protocol.ping","version":"2.0.0","nonce":"0f6f3e6b-9a1c-4c58-8c8c-2d5c3c7e9a10"}
```

El PONG cambia solo el schema a tvp3d.protocol.pong y debe devolver el mismo
nonce. El nonce es diagnostico y no es reloj de simulacion, tick, latencia
autoritativa ni orden de gameplay.

GOODBYE usa schema tvp3d.protocol.goodbye, version 2.0.0, reason uno de
NORMAL, CLIENT_SHUTDOWN, SERVER_SHUTDOWN o PROTOCOL_ERROR, y message de
0..256 bytes UTF-8. Quien inicia el cierre envia un unico goodbye si el
stream sigue escribible y luego pasa a CLOSING.

## ProtocolErrorV2

Un error de protocolo es distinto de un error de dominio:

```json
{
  "schema": "tvp3d.protocol.error",
  "version": "2.0.0",
  "code": "PROTOCOL_MAGIC_INVALID",
  "message": "invalid V2 frame",
  "fatal": true,
  "related_message_kind": null
}
```

code es un token cerrado; message mide 0..256 bytes UTF-8;
related_message_kind es uint8 o null; fatal debe coincidir con la tabla. Un
error no muta el mundo. El frame de error solo se intenta cuando el header era
suficientemente confiable; nunca se salta byte ni se reinterpreta.

| Codigo | Causa | Fatal/cierre | Error antes de cerrar |
|---|---|---|---|
| PROTOCOL_MAGIC_INVALID | magic distinto | si | prohibido |
| PROTOCOL_MAJOR_UNSUPPORTED | major distinto de 2 | si | prohibido |
| PROTOCOL_MINOR_UNSUPPORTED | minor no soportado | si | permitido si header valido |
| PROTOCOL_FLAGS_UNSUPPORTED | flags no cero | si | permitido si magic/version validos |
| FRAME_LENGTH_INVALID | longitud cero/invalida | si | prohibido |
| FRAME_TOO_LARGE | payload sobre 262144 | si | permitido si header valido |
| FRAME_RESERVED_NONZERO | reserved no cero | si | permitido si header valido |
| BUFFER_LIMIT_EXCEEDED | buffer > 524320 | si | prohibido |
| MESSAGE_KIND_UNKNOWN | kind fuera de 1..10 | si | obligatorio si frame valido |
| PAYLOAD_NOT_UTF8 | UTF-8 invalido/BOM | si | obligatorio si frame valido |
| PAYLOAD_JSON_INVALID | JSON invalido | si | obligatorio si frame valido |
| PAYLOAD_NOT_OBJECT | JSON array/primitive | si | obligatorio si frame valido |
| JSON_NESTING_EXCEEDED | profundidad >32 | si | obligatorio si frame valido |
| MESSAGE_SCHEMA_INVALID | schema/protocolo malformado | segun estado | obligatorio si frame valido |
| COMMON_DOMAIN_VERSION_UNSUPPORTED | handshake sin 2.0.0 | si | permitido |
| ROLE_VIOLATION | direccion ilegal | si | obligatorio |
| HANDSHAKE_REQUIRED | mensaje antes de hello | si | obligatorio |
| HANDSHAKE_DUPLICATE | hello/welcome repetido | si | obligatorio |
| SESSION_SCOPE_MISMATCH | ref fuera del scope asignado | si | obligatorio |
| SYNC_REQUIRED | receptor debe obtener snapshot | no | obligatorio |

MESSAGE_SCHEMA_INVALID en NEGOTIATING es fatal. En READY solo cubre forma
del envelope de protocolo y es no fatal; un CommandEnvelopeV2 con reglas o
tipo de dominio rechazado se devuelve como error del dominio, no como error
de framing. SYNC_REQUIRED no muta estado y deja la conexion en SYNCING. Todo
error fatal pasa por CLOSING y luego CLOSED.

## Ownership y limites de protocolo

| Categoria transportada | Owner |
|---|---|
| header, stream order, handshake, roles, limites | SERVER (protocolo) |
| intenciones CommandEnvelopeV2 emitidas | CLIENT_PRESENTATION; valida SERVER |
| eventos/snapshots aceptados | SERVER |
| PosicionTibiaV2, refs, revisiones y reglas de dominio | SERVER |
| payloads de dominio | contrato del dominio; autoridad SERVER |
| GLB, materiales, texturas, rigs, clips, LOD, Blender | ASSETS / CLIENT_PRESENTATION |
| ids OTBM/OTB/XML/DAT/SPR y opcodes 7.72 | IMPORT_ONLY / LEGACY |

El cliente no puede enviar EVENT ni marcar un campo como SERVER para confirmar
estado. Protocol V2 no contiene rutas .glb, nombres de materiales, texturas,
skeletons, animaciones, Blender, Astra ni dimensiones visuales.

## Limites exactos 2.0.0

- payload maximo: 262144 bytes UTF-8;
- frame maximo: 262160 bytes;
- buffer persistente no decodificado: 524320 bytes;
- profundidad JSON maxima: 32;
- capacidades por handshake: 64, token maximo 64 bytes;
- versiones common por hello: 16;
- pares protocol por hello: 8;
- mensaje de ProtocolError/Goodbye: 256 bytes;
- no compresion ni cifrado en esta version.

Superar cualquier limite produce el error especifico, sin truncar ni
fragmentar semanticamente el objeto.

## Versionado y migracion

2.0.0 es un cambio mayor semantico: no se reinterpretan frames 1.x. Un
consumidor que solo soporta 2.0.0 rechaza SemVer desconocido, major distinto,
flags futuros o kinds no registrados. Cambios compatibles pueden publicarse
como minor solo si mantienen header, invariantes y rechazo seguro; un cambio
de framing, autoridad o significado obligatorio exige major nuevo.

Migracion:

1. Protocol 1.x (modelo-comun 1.0.0) queda congelado como prototipo y fixture.
2. Cada consumidor migra a modelo-comun 2.0.0, refs, command/event envelopes
   y el frame V2; no hay interop directo.
3. El servidor y cliente native Godot negocian V2 y usan snapshots para
   baseline; el dominio publica sus tipos antes de transportarlos.
4. Un adapter explicito puede traducir 1.x a V2 durante la transicion, pero
   no hace que un endpoint 1.x sea V2.
5. El adapter TVP 7.72 permanece separado hasta Phase 10 y sigue siendo oracle,
   fuente de fixtures y puente temporal.

Migraciones downstream requeridas: servidor, cliente, qa y cualquier
integracion que consuma el framing 1.6.0 deben publicar contratos/fixtures que
declaren dependencia protocolo-red 2.0.0; assets solo debe mapear identidades
de dominio a visuales en su propio contrato, nunca agregar GLB al payload
comun. No se cambia ninguno de esos carriles en esta fase.

## Plan de fixtures y validacion contractual

La suite futura de qa/protocolo-red debe especificar y congelar fixtures para:

- header de 16 bytes fragmentado, payload fragmentado y varios frames en una
  recepcion;
- magic invalido, major/minor no soportado, flag/reserved no cero,
  payload cero/sobre limite, kind desconocido;
- UTF-8 invalido, JSON invalido, JSON array y profundidad 33;
- hello duplicado, comando antes de handshake y EVENT cliente -> servidor;
- CommandEnvelopeV2 y AuthoritativeEventEnvelopeV2 validos sin redefinirlos;
- duplicate event id idempotente y conflicto, gap -> sync request, stale
  revision -> sync, sync -> snapshot autoritativo;
- snapshot con baseline 0, baseline monotona y nuevo stream;
- ping/pong con nonce, goodbye y cierre ordenado;
- frame 1.x y paquete TVP 7.72 rechazados por decoder V2;
- scope mismatch, capacidad/version fuera de limite y rechazo de schema.

Estas son especificaciones de contrato; este turno no implementa tests ni
produccion.

## Perfil historico Protocol 1.x

Estado: `SUPERSEDED` por Protocol V2 2.0.0.

Esta seccion conserva el prototipo propio 1.x y sus fixtures; no gobierna
endpoints V2. Dependia de `modelo-comun 1.0.0`.

La version `1` es el perfil del endpoint propio. No existe un byte de version
dentro del frame actual; un cambio incompatible debe publicar otro perfil antes
de que un consumidor lo use. El frame no tiene checksum, compresion ni
terminador.

### Frame

```text
uint32 little-endian body_length
uint8  opcode
bytes  json_utf8_object
```

`body_length` cuenta el opcode y el JSON, y debe estar entre `1` y `65536`
bytes inclusive. El JSON debe ser un objeto UTF-8 valido. El buffer de TCP
puede contener medio encabezado, un frame incompleto o varios frames
concatenados; el decoder conserva los bytes no consumidos y no los descarta.

El resultado de `extraer(buffer)` tiene siempre esta forma:

```json
{
  "buffer": "bytes restantes",
  "mensajes": [{"tipo": "uint8", "datos": "object"}],
  "error": "string",
  "incompleto": "bool"
}
```

Con un frame incompleto, `mensajes` queda vacio, `error` queda vacio y
`buffer` es identico al de entrada. Con un error, el consumidor cierra la
conexion y no intenta reinterpretar los bytes restantes.

### Mensajes

| Opcode | Nombre | Direccion | Payload obligatorio |
|---:|---|---|---|
| 1 | `HELLO` | cliente -> servidor | `{ "nombre": "string[1..24]" }` |
| 2 | `WELCOME` | servidor -> cliente | `{ "id": "uint32>0", "nombre": "string[1..24]", "pos": "PosicionTibia", "mapa": "object mapa v1" }` |
| 3 | `STATE` | servidor -> cliente | `{ "jugadores": "array de Entidad" }` |
| 4 | `MOVE` | cliente -> servidor | `{ "dx": "int8[-1..1]", "dy": "int8[-1..1]" }` |
| 5 | `ERROR` | servidor -> cliente | `{ "mensaje": "string[1..160]" }` |
| 6 | `PING` | cliente -> servidor | `{}` |
| 7 | `PONG` | servidor -> cliente | `{}` |
| 8 | `GOODBYE` | cliente -> servidor | `{}` |

`PosicionTibia` y `Entidad` son los esquemas de
`worklog/modelo-comun/CONTRATO.md`. `MOVE` solo admite movimiento cardinal:
`abs(dx)+abs(dy)==1`. Un `MOVE` valido sigue siendo una intencion; el servidor
debe validar el tile, la ocupacion y las reglas antes de emitir `STATE`.

Ejemplo de frame `MOVE`:

```text
10 00 00 00 04 7B 22 64 78 22 3A 31 2C 22 64 79 22 3A 30 7D
```

El ejemplo tiene body de 16 bytes: opcode `04` seguido de
`{"dx":1,"dy":0}` en UTF-8.

### API del codec

```text
empaquetar(tipo: int, datos: Dictionary) -> PackedByteArray
extraer(buffer: PackedByteArray) -> Dictionary
validar_mensaje(tipo: int, datos: Dictionary) -> Dictionary
posicion_a_diccionario(posicion: Vector3i) -> Dictionary
diccionario_a_posicion(datos: Dictionary) -> Vector3i
```

`validar_mensaje` devuelve `{ "ok": bool, "error": string }`. Los
consumidores deben validar un payload antes de enviarlo; `empaquetar` devuelve
un array vacio y registra un error si recibe un mensaje fuera del contrato.

## Frontera historica con TVP 7.72

`cliente3d/red/conexion772.gd` es un adaptador separado y conserva el framing
real del servidor C++: `uint16 little-endian body_length`, payload interior y
XTEA/RSA según el flujo de TVP. No usa JSON ni este opcode table. Sus cambios
deben comprobarse contra `servidor/src/` y no pueden reutilizar funciones del
perfil propio por similitud de nombres.

## Errores del perfil historico 1.x

| Codigo | Cuando ocurre | Que hace quien llama |
|---|---|---|
| `PAQUETE_INCOMPLETO` | El resultado trae `incompleto=true` porque aun no llegaron todos los bytes del encabezado o cuerpo | Conservar `buffer` y esperar mas datos; `error` permanece vacio y no es fallo de conexion |
| `PAQUETE_DEMASIADO_GRANDE` | `body_length > 65536` | Cerrar la conexion y registrar el tamano |
| `PAQUETE_SIN_OPCODE` | `body_length == 0` | Cerrar la conexion |
| `OPCODE_DESCONOCIDO` | El opcode no esta entre `1..8` | Cerrar la conexion; no ignorar el mensaje |
| `JSON_INVALIDO` | El body no contiene JSON UTF-8 valido | Cerrar la conexion |
| `JSON_NO_OBJETO` | El JSON valido no es un objeto | Cerrar la conexion |
| `MENSAJE_INVALIDO` | Faltan campos, hay rangos invalidos o la direccion no coincide | Rechazar el frame sin mutar estado; el servidor puede responder `ERROR` |
| `PAYLOAD_EXCESIVO` | El JSON hace que el body supere el limite | No enviar; reducir el payload o negociar otra version |
| `PERFIL_INCOMPATIBLE` | El consumidor recibe una version/perfil que no soporta | Rechazar y no reinterpretar bytes |

## El perfil historico 1.x no expone

- Credenciales, contrasenas, tokens, sesiones o claves privadas.
- La decision de caminabilidad, combate, inventario, persistencia o cualquier
  otro estado autoritativo.
- Framing, opcodes o payloads de una version de proveedor que no este dentro
  del adaptador TVP 7.72 documentado.
- Rutas privadas de despliegue.

## Consumidores historicos

- `cliente3d/servidor_propio/`, para recibir intenciones y emitir estado.
- Cliente 3D y pruebas del carril `qa`.
- `cliente3d/red/conexion772.gd`, unicamente como adaptador independiente de
  compatibilidad, no como consumidor del JSON propio.

## LEGACY ADAPTER PROFILE: TVP 7.72

Estado: TRANSICIONAL / ORACLE. No es Protocol V2.

Se preserva a continuacion el conocimiento probado de RSA/XTEA, mapa,
criaturas, muerte, texto, comercio y party. Protocol V2 no depende de estos
opcodes, estructuras ni reglas de cifrado.

### Estado de criatura del adaptador 7.72

El adaptador conserva como estado confirmado los campos que
`ProtocolGame::AddCreature` envia con cada criatura completa:

```text
light_level uint8
light_color uint8
speed       uint16 little-endian
skull       uint8
shield      uint8
```

Los cambios posteriores usan exactamente:

| Opcode | Payload servidor -> cliente | Efecto permitido |
|---:|---|---|
| `0x8D` | `creature_id uint32, level uint8, color uint8` | Actualizar luz de una criatura conocida |
| `0x8F` | `creature_id uint32, speed uint16` | Actualizar velocidad de una criatura conocida |
| `0x90` | `creature_id uint32, skull uint8` | Actualizar skull de una criatura conocida |
| `0x91` | `creature_id uint32, shield uint8` | Actualizar shield de party de una criatura conocida |

Un cambio para un id no conocido se consume por completo para mantener la
alineacion, pero no crea una criatura. Cada cambio aceptado emite el estado
completo confirmado; ningun valor se calcula en el cliente.

La retirada `0x6C` representa la muerte del jugador cuando se cumplen las dos
condiciones autoritativas a la vez:

1. La retirada es del jugador: el `id` retirado es `mi_id`, **o** la casilla
   del mensaje es la posicion confirmada `mi_pos`.
2. Las stats autoritativas mas recientes tienen vida cero.

La segunda condicion es la que distingue muerte de teleport o refresh: una
retirada con vida positiva nunca emite muerte. La primera no puede depender
solo del indice de pila. `Player::drainHealth` (`servidor/src/player.cpp:1402`)
manda el `0xA0` con vida cero antes de que `Game::removeCreature` retire al
jugador, asi que la vida cero siempre llega primero; el indice de pila, en
cambio, solo vale si la pila local coincide con la del servidor.

La muerte se emite una sola vez por sesion: si el jugador ya esta fuera del
mundo, un `0x6C` posterior en la misma casilla no vuelve a emitirla. Este
adaptador solo emite el evento y marca al jugador fuera del mundo; cerrar la
conexion y presentar la UI corresponden al consumidor.

### Ventana de texto

El servidor la abre al usar un cartel, una carta o la etiqueta de una parcel.

`0x96` servidor -> cliente (`protocolgame.cpp:2091-2115`):

```text
uint32 id_ventana
item        client id, mas un byte si es apilable o liquido
uint16      maximo de caracteres
string      texto actual
string      quien lo escribio, vacio si nadie
```

`0x89` cliente -> servidor (`protocolgame.cpp:1095-1100`): `uint32 id_ventana`
y el texto nuevo. Sin id de ventana no se envia nada; un texto vacio si es un
envio valido, porque borrar lo escrito es una accion legitima.

El paquete **no dice si el item se puede escribir**. Las dos ramas de
`sendTextWindow` mandan la misma forma: la unica diferencia es que el primer
`uint16` es el maximo permitido o el largo del texto ya escrito. El cliente por
lo tanto no lo adivina: expone lo que llego y deja que el servidor rechace el
`0x89` con un `0xB4` si ese item no se podia escribir.

El adaptador conserva la ultima ventana en `ultima_ventana_texto` y la emite
por `ventana_texto(datos)`. Una ventana truncada no se emite.

Self-test con bytes exactos en `red/ventana_texto_self_test.gd`.

### Comercio entre jugadores

Las cuatro ordenes del cliente, con los payloads de
`ProtocolGame::parseRequestTrade` y `parseLookInTrade`
(`protocolgame.cpp:511-514` y `1000-1015`):

| Opcode | Orden | Payload |
|---:|---|---|
| `0x7D` | Ofrecer un objeto a otro jugador | `posicion`, `client_id uint16`, `stackpos uint8`, `player_id uint32` |
| `0x7E` | Mirar un objeto de la ventana | `contraparte uint8` (1 la del otro), `indice uint8` |
| `0x7F` | Aceptar la oferta | sin payload |
| `0x80` | Cerrar el comercio | sin payload |

El equipo se direcciona con la posicion `(0xFFFF, ranura, 0)` y `stackpos` 0,
que es como Tibia nombra el inventario en todos los mensajes de objeto. Sin un
`player_id` valido no se envia nada.

Quien decide si el objeto se puede ofrecer, si hay distancia y si la otra parte
acepta es el servidor. El cliente transporta la intencion y dibuja lo que
vuelve por `0x7D`-`0x80`.

Self-test con los bytes exactos en `red/comercio_self_test.gd`.

### Party

Las ordenes de party van del cliente al servidor y son las que acepta
`ProtocolGame::parsePacket` (`protocolgame.cpp:536-541`), con los payloads de
`protocolgame.cpp:1171-1207`:

| Opcode | Orden | Payload |
|---:|---|---|
| `0xA3` | Invitar a la party | `creature_id uint32` |
| `0xA4` | Unirse a la party de ese lider | `creature_id uint32` |
| `0xA5` | Revocar una invitacion propia | `creature_id uint32` |
| `0xA6` | Pasar el liderazgo | `creature_id uint32` |
| `0xA7` | Salir de la party | sin payload |
| `0xA8` | Experiencia compartida | `uint8` (1 activa, 0 no) |

Un id de criatura cero o negativo no identifica a nadie y no se envia.

**Este servidor no manda ningun paquete de party.** Lo unico que vuelve es el
escudo de cada criatura por el `0x91` que ya define este contrato: `Party`
llama a `sendCreatureShield` para cada miembro e invitado cuando algo cambia
(`servidor/src/party.cpp:39-268`). El cliente no debe esperar una lista de
miembros ni inventarla: la party se deduce de los escudos confirmados.

`0xA8` existe en este servidor, pero el cliente 7.72 original no tenia boton de
experiencia compartida. Aca solo esta el transporte; ofrecerlo o no es decision
de la interfaz.

Self-test con los bytes exactos en `red/party_self_test.gd`.

### Alineacion del mapa

El servidor siempre describe al jugador dentro de su propia casilla. Al
terminar de leer una descripcion de mapa, el adaptador comprueba esa invariante
y, si no se cumple, deja `mapa_alineado` en falso y emite
`mapa_desalineado(detalle)` con la posicion, la cantidad de items sin catalogo,
sus client ids y el primero de ellos.

Un mapa desalineado no se corrige adivinando: en 7.72 los apilables y los
liquidos traen un byte extra y nada en el mensaje lo anuncia
(`servidor/src/networkmessage.cpp:95-105`), asi que un ancho equivocado
desplaza todo lo que sigue. Mientras `mapa_alineado` sea falso, ningun
consumidor debe confiar en los indices de pila de esa casilla: ni para
`0x6C`, ni para usar un item del suelo, ni para moverlo.

El lector tiene self-test propio en `red/mapa_self_test.gd`, que codifica los
saltos igual que `GetFloorDescription` —contador `skip` que arranca en -1,
tandas de 255 y desfase por piso— y exige que cada casilla caiga en la
coordenada que dijo el servidor consumiendo el mensaje entero.

### Casillas que existen y no describen nada

Una marca normal `(n, 0xFF)` no significa solo "vinieron n vacias": el
servidor la escribe **justo antes de describir una casilla**
(`protocolgame.cpp:646-653`), asi que el casillero siguiente le pertenece.

Esa casilla puede ocupar cero bytes. `GetTileDescription` no escribe nada si la
casilla no tiene suelo, ni items, ni criaturas visibles para ese jugador
(`protocolgame.cpp:566-614`); en el mapa real pasa con las casillas que solo
llevan banderas de zona. El resultado son dos marcas pegadas, y el lector debe
consumir igual el casillero de en medio: si lo saltea, pierde un lugar por cada
una y todo lo que sigue cae en la coordenada equivocada.

Detras de una tanda `0xFFFF` **no** viene una casilla descrita: esa marca la
escribe la rama de casilla vacia y la racha continua.

Esta regla se comprueba con bytes reales del servidor en
`red/mapa_captura_self_test.gd`, sobre la captura versionada
`generated/capturas/entrada_mundo.bin`.

## Compatibilidad y versionado del adaptador legacy

Esta seccion solo gobierna el perfil historico TVP 7.72, no Protocol V2.
Agregar un opcode o un campo opcional documentado es compatible dentro de una
version menor del adaptador si los consumidores antiguos pueden rechazarlo sin
desalinear el frame. Cambiar el ancho del prefijo, el significado de un opcode,
la forma de un campo obligatorio o el limite de frame exige una version mayor y
un perfil de endpoint nuevo. Nunca se ignora un opcode desconocido ni se
convierten bytes faltantes en valores por defecto. Protocol V2 conserva su
registro cerrado, magic TVP2 y reglas de versionado en las secciones
normativas anteriores.
