# Contrato: protocolo-red

Version: 1.2.0
Estado: PUBLICADO
Propietario: protocolo-red
Depende de: modelo-comun 1.0.0

## Proposito

Transportar mensajes del servidor propio por TCP preservando fragmentacion,
orden y autoridad del servidor, sin confundir este protocolo con el adaptador
legacy de TVP 7.72.

## Perfil propio v1

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

## Compatibilidad TVP 7.72

`cliente3d/red/conexion772.gd` es un adaptador separado y conserva el framing
real del servidor C++: `uint16 little-endian body_length`, payload interior y
XTEA/RSA según el flujo de TVP. No usa JSON ni este opcode table. Sus cambios
deben comprobarse contra `servidor/src/` y no pueden reutilizar funciones del
perfil propio por similitud de nombres.

## Errores

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

## No expone

- Credenciales, contrasenas, tokens, sesiones o claves privadas.
- La decision de caminabilidad, combate, inventario, persistencia o cualquier
  otro estado autoritativo.
- Framing, opcodes o payloads de una version de proveedor que no este dentro
  del adaptador TVP 7.72 documentado.
- Rutas privadas de despliegue.

## Consumidores

- `cliente3d/servidor_propio/`, para recibir intenciones y emitir estado.
- Cliente 3D y pruebas del carril `qa`.
- `cliente3d/red/conexion772.gd`, unicamente como adaptador independiente de
  compatibilidad, no como consumidor del JSON propio.

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

## Compatibilidad y versionado

Agregar un opcode o un campo opcional documentado es compatible dentro de una
version menor si los consumidores antiguos pueden rechazarlo sin desalinear el
frame. Cambiar el ancho del prefijo, el significado de un opcode, la forma de
un campo obligatorio o el limite de frame exige una version mayor y un perfil
de endpoint nuevo. Nunca se ignora un opcode desconocido ni se convierten
bytes faltantes en valores por defecto.
