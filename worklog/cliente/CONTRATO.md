# Contrato: cliente

Version: 1.1.0
Estado: PUBLICADO
Propietario: cliente
Depende de: modelo-comun 1.0.0, protocolo-red 1.1.0, assets 1.3.0

## Proposito

Presentar el mundo propio de TVP3D en 3D, enviar intenciones de movimiento y
mostrar unicamente posiciones confirmadas por el servidor. Este carril no
decide caminabilidad, ocupacion, existencia ni resultado de una accion.

## Escena y conexion

- Escena propia: `res://propio/cliente_3d.tscn`.
- Host por defecto: `127.0.0.1`; se puede sustituir con `TVP3D_HOST`.
- Puerto por defecto: `7277`; se puede sustituir con `TVP3D_PUERTO`.
- La conexion usa exclusivamente `protocolo-red` v1 y su `StreamPeerTCP`.
- Al conectar se envia `HELLO` una sola vez por intento, con un nombre entre
  1 y 24 caracteres.
- Al recibir `WELCOME` valido se carga el mapa y se pasa a `EN_MUNDO`.
- Al recibir un `STATE` se reemplaza el conjunto visual completo por las
  entidades confirmadas, sin interpolar la posicion logica ni crear entidades
  locales.

## Estados del cliente

| Estado | Evento | Siguiente |
|---|---|---|
| `DESCONECTADO` | temporizador de reintento | `CONECTANDO` |
| `CONECTANDO` | TCP conectado | `CONECTANDO` + `HELLO` |
| `CONECTANDO` | `WELCOME` valido | `EN_MUNDO` |
| `CONECTANDO` | error TCP/protocolo | `DESCONECTADO` |
| `EN_MUNDO` | `STATE` | `EN_MUNDO` + reemplazo visual |
| `EN_MUNDO` | `ERROR` | `EN_MUNDO` + aviso, sin mutar posicion |
| `EN_MUNDO` | cierre TCP | `DESCONECTADO` |
| cualquier estado | `ESC` | cierre ordenado |

Tras una perdida de conexion, el cliente limpia el estado vivo y reintenta
con una pausa fija. No conserva como confirmado un jugador desconectado ni
reutiliza el buffer de un intento anterior.

## Entrada

- `W`, flecha arriba: `MOVE {dx:0,dy:-1}`.
- `D`, flecha derecha: `MOVE {dx:1,dy:0}`.
- `S`, flecha abajo: `MOVE {dx:0,dy:1}`.
- `A`, flecha izquierda: `MOVE {dx:-1,dy:0}`.
- Se envia como maximo una intencion cada `0.18` segundos.
- El cliente no cambia `_mi_pos` al enviar; solo lo cambia con `STATE` que
  contenga su id.
- Un `ERROR` conserva la posicion y muestra el motivo recibido.

## Representacion

- El mapa del `WELCOME` se valida antes de renderizarlo: version, origen,
  dimensiones, celdas, rangos y tipos deben pertenecer al modelo comun.
- Se representan los siete tipos cerrados del modelo: suelo, pared, agua,
  arbol, roca, decoracion y escalera.
- Las entidades de `STATE` se renderizan desde sus posiciones Tibia y se
  distinguen por id local; el jugador propio no se inventa si no aparece en
  el estado recibido.
- La camara sigue la ultima posicion confirmada del jugador local.

## Errores y limites

| Codigo | Accion del cliente |
|---|---|
| `MAPA_RECIBIDO_INVALIDO` | No renderizar el mapa; mostrar aviso y cerrar el intento |
| `PROTOCOLO_INVALIDO` | Descartar el intento, limpiar buffer y reconectar |
| `ERROR` del servidor | Mostrar `mensaje`; no cambiar estado logico |
| `CONEXION_PERDIDA` | Limpiar entidades y reconectar |
| `PERFIL_INCOMPATIBLE` | Rechazar el `WELCOME` y no reinterpretar sus datos |

El cliente no expone credenciales, tokens, claves ni rutas privadas. El
adaptador `conexion772.gd` del cliente legacy es independiente y no se usa
para la escena propia.

## Muerte y reentrada del cliente TVP 7.72

Esta seccion aplica al cliente jugable de la rama TVP 7.72 (`mundo3d.gd` y
`cliente3d/ui/`), no a la escena propia del perfil JSON. La rama del servidor
no tiene `sendDeath` ni `sendReLoginWindow`: el cliente no espera, no inventa
y no acepta ningun opcode de muerte.

La unica fuente de muerte es la senal `jugador_muerto(posicion)` que emite
`cliente3d/red/estado_mundo.gd` cuando el `0x6C` retira a `mi_id` con las
stats autoritativas mas recientes en vida cero, tal como define
`protocolo-red` 1.1.0. El cliente no vuelve a inferir muerte por su cuenta,
no la deduce de la barra de vida, del corpse ni de un mensaje de texto.

Al recibir la senal, y una sola vez por sesion:

| Paso | Obligacion |
|---|---|
| 1 | Marcar la sesion como muerta y bloquear toda intencion nueva: teclado de movimiento, map-click, ataque, uso, arrastre y chat |
| 2 | Cancelar el uso-con pendiente, el arrastre pendiente y el objetivo visual |
| 3 | Ocultar la interfaz de juego y mostrar la pantalla de reentrada |
| 4 | Enviar logout `0x14` por la misma conexion |
| 5 | Esperar el cierre del socket sin volver solo al formulario de cuenta |
| 6 | Volver al selector de personajes unicamente cuando el jugador lo pide |

El paso 4 usa `enviar_logout()` del adaptador. `ProtocolGame::logout`
(`servidor/src/protocolgame.cpp:303-336`) encuentra al jugador ya removido por
`Game::removeCreature` y llama `disconnect()`; el cliente no debe cerrar el
socket por su cuenta para provocar ese camino ni tratar el cierre como error
de red.

La pantalla de reentrada muestra el texto `You are dead.`, que es el mismo que
el servidor envia por `0xB4` desde
`servidor/data/scripts/creaturescripts/playerdeath.lua:12`, y una accion unica
para volver al selector de personajes. No promete revivir en el templo, no
muestra perdidas ni estadisticas: esas consecuencias son autoridad del
servidor y solo se ven al reingresar.

Al aceptar la reentrada, el cliente limpia el estado vivo de la sesion, cierra
la conexion si el servidor todavia no lo hizo y pide de nuevo la lista de
personajes con las credenciales que ya estaban en memoria. Si no hay
credenciales en memoria vuelve al formulario de cuenta.

Un mensaje del servidor que cancele un logout voluntario no cancela esta
salida: la muerte ya ocurrio en la autoridad y no es reversible desde el
cliente.

## Pruebas de cierre

- La escena arranca sin renderer con `--headless` y no produce errores de
  script.
- Con el servidor propio, un usuario recibe `WELCOME`/`STATE`, ve el mapa 3D y
  camina con teclado.
- Un segundo jugador recibido en `STATE` aparece en la escena.
- Un movimiento rechazado por el servidor no cambia la posicion visual.
- Una perdida de conexion limpia el mundo vivo y activa reconexion.
- La senal `jugador_muerto` bloquea intenciones, envia exactamente un `0x14`,
  deja visible la pantalla de reentrada y no vuelve solo al formulario de
  cuenta al cerrarse el socket.
- La reentrada pedida por el jugador limpia la sesion y vuelve al selector de
  personajes.
