# Contrato: cliente

Version: 1.0.0
Estado: PUBLICADO
Propietario: cliente
Depende de: modelo-comun 1.0.0, protocolo-red 1.0.0, assets 1.3.0

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

## Pruebas de cierre

- La escena arranca sin renderer con `--headless` y no produce errores de
  script.
- Con el servidor propio, un usuario recibe `WELCOME`/`STATE`, ve el mapa 3D y
  camina con teclado.
- Un segundo jugador recibido en `STATE` aparece en la escena.
- Un movimiento rechazado por el servidor no cambia la posicion visual.
- Una perdida de conexion limpia el mundo vivo y activa reconexion.
