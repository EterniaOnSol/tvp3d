# TVP3D - Network Protocol

## Contrato actual

TVP fija version minima y maxima 772. El cliente actual implementa este
contrato en `cliente3d/red/conexion772.gd`.

### Login

1. TCP a puerto de login 7171.
2. Cliente envia opcode 0x01, sistema Windows, version 772, firmas vacias de
   12 bytes y bloque RSA de 128 bytes.
3. El bloque contiene clave XTEA de 16 bytes, cuenta numerica de 32 bits y
   clave.
4. La respuesta ya usa XTEA; no hay saludo 0x1F previo.
5. Lista de personajes trae nombre, mundo, IPv4 y puerto de juego.

### Juego

1. TCP al puerto anunciado por el login, actualmente 7172.
2. Cliente envia opcode 0x0A, sistema, version y bloque RSA con clave XTEA,
   flag GM, cuenta, personaje y clave.
3. El sobre de TVP 7.72 es `[u16 length][body]`; no lleva Adler32 ni contador
   de secuencia.
4. El cuerpo XTEA contiene `[u16 real_length][payload][padding]`.

### Mapas y movimiento

- 0x64: posicion del jugador y descripcion inicial de pisos/casillas.
- 0x65/0x66/0x67/0x68: movimiento norte/este/sur/oeste del cliente.
- 0x6D: criatura cambia de casilla.
- 0x65-0x68 tambien aparecen como franjas nuevas del servidor, sin posicion
  propia; la posicion viene en el 0x6D anterior.
- 0xBE/0xBF: cambio de piso arriba/abajo cuando el servidor usa la ruta de
  movimiento de piso dedicada. `EstadoMundo` los observa mediante
  `cambio_piso(opcode, posicion)`.
- En la escalera real validada `(32080,32203,7)`, TVP envia 0x64 y no 0xBE/0xBF:
  `Tile::queryDestination` cambia z, `Map::moveCreature` lo marca como
  teletransporte y `ProtocolGame::sendMoveCreature` responde con un mapa
  completo. La prueba registro 0x64 hacia `(32080,32202,6)` y de vuelta hacia
  `(32080,32204,7)`.
- 0x6A/0x69/0x6B/0x6C: add/update/remove de item o tile.
- 0x14 y 0xB5: rechazo y movimiento cancelado.

La ventana es 18x14 (`maxClientViewportX=8`, `maxClientViewportY=6`). El
mapa completo se obtiene del OTBM, no del protocolo.

## Direccion futura

Se mantiene este protocolo para la primera vertical slice. Un adaptador
extended opcode solo se agrega si falta un dato necesario para visualizacion o
debug. La logica de juego no se muda al cliente para resolver una carencia de
render.
