# Contrato: servidor

Version: 1.1.0
Estado: PUBLICADO
Propietario: servidor
Depende de: modelo-comun 1.0.0, protocolo-red 1.0.0, assets 1.3.0

## Sala del pergamino de Demon

- La sala de Edron usa la posicion Tibia [33063,31623,15] como spawn
  inicial determinista: monstername=Demon, amount=1, radius=0.
- El item con AID 3121 es el unico disparador de la emboscada. Al retirarlo,
  si GlobalStorageKeys.edronDemonScroll != 1, crea exactamente cuatro
  Demons en [33060,31623,15], [33066,31623,15], [33066,31627,15] y
  [33060,31627,15], y luego fija la storage a 1.
- Retirar el pergamino otra vez es idempotente: no crea duplicados ni mueve
  el Demon inicial. La autoridad permanece en el servidor y el cliente solo
  representa el STATE recibido.
- El cambio de radio no altera otros spawns de Demon ni el comportamiento de
  la emboscada; se limita a esta entrada exacta del mapa.

## Proposito

Ejecutar el mundo propio de TVP3D como una autoridad headless. El servidor
recibe intenciones, valida cada transicion contra su mapa y ocupacion actuales
y solo entonces emite el estado confirmado por `STATE`.

## Perfil de ejecucion

- Proceso: Godot 4 en modo `--headless`.
- Host local de desarrollo: `127.0.0.1`.
- Puerto del perfil propio: `7277`.
- Mapa: `user://mapa_tvp3d.json`, version `1` del modelo comun.
- Si el archivo no existe, el perfil de demo inicia con el mapa determinista
  integrado y lo anuncia en el log; un mapa existente pero invalido hace que
  el proceso termine con error y no se sustituye silenciosamente.
- El estado de jugadores es de sesion y vive en memoria durante este perfil;
  no se persisten credenciales, tokens ni sesiones desconectadas.

## Estados de conexion

| Estado | Entrada valida | Salida |
|---|---|---|
| `CONECTADO` | `HELLO` valido | `EN_MUNDO` |
| `CONECTADO` | `MOVE`, `PING` o `GOODBYE` | `CONECTADO` + `ERROR`, o desconexion |
| `EN_MUNDO` | `MOVE` validado | `EN_MUNDO` + `STATE` |
| `EN_MUNDO` | `MOVE` rechazado | `EN_MUNDO` + `ERROR`, sin mutar estado |
| `EN_MUNDO` | `PING` | `EN_MUNDO` + `PONG` |
| cualquier estado | `GOODBYE` o cierre TCP | desconectado |

El servidor acepta del cliente solamente `HELLO`, `MOVE`, `PING` y `GOODBYE`.
`WELCOME`, `STATE`, `ERROR` y `PONG` son mensajes de salida; recibirlos como
entrada es un error de direccion y no cambia el mundo.

## Estado autoritativo

Cada jugador listo conserva:

```json
{
  "id": "uint32>0",
  "nombre": "string[1..24]",
  "pos": "PosicionTibia",
  "direccion": "norte|este|sur|oeste"
}
```

Los ids son unicos durante la ejecucion. Cada nuevo jugador recibe una casilla
caminable libre; el servidor nunca confirma dos jugadores sobre la misma
casilla. Al entrar o salir un jugador, todos los jugadores listos reciben el
`STATE` completo y ordenado por id.

## Resolucion de `MOVE`

1. El mensaje debe pertenecer al estado `EN_MUNDO` y cumplir el contrato de
   `protocolo-red`.
2. Se registra la intencion `SOLICITADA`.
3. Se calcula la posicion vecina y se vuelve a comprobar que el tile sea
   `SUELO` o `ESCALERA`, tenga el mismo `z` y este dentro del mapa.
4. Se comprueba que ningun otro jugador listo ocupe la posicion destino.
5. Si ambas comprobaciones pasan, la transicion es `VALIDADA`, `APLICADA` y
   `EMITIDA`; se actualizan posicion y direccion y se difunde `STATE`.
6. Si falla una comprobacion, la transicion es `RECHAZADA` y `EMITIDA` como
   `ERROR`; la posicion, ocupacion y mapa quedan sin cambios.

Errores de rechazo de movimiento:

| Codigo | Motivo |
|---|---|
| `IDENTIFICACION_REQUERIDA` | Aun no se recibio `HELLO` valido |
| `MOVIMIENTO_BLOQUEADO` | El destino no es caminable o esta fuera del mapa |
| `MOVIMIENTO_OCUPADO` | Otro jugador listo ocupa el destino |
| `MOVIMIENTO_NO_CARDINAL` | El payload no representa un paso cardinal |
| `OPCODE_NO_PERMITIDO` | El cliente envio un opcode de salida |
| `HELLO_DUPLICADO` | Se intento cambiar la identidad de una sesion lista |

Los textos enviados en `ERROR.mensaje` son breves y quedan limitados por el
maximo de 160 caracteres del protocolo.

## Arranque y fallos

- Un fallo al abrir o validar un mapa existente impide arrancar el listener.
- Un fallo al enlazar el puerto termina con codigo de salida distinto de cero.
- Un paquete invalido del protocolo se informa, se cierra esa conexion y no se
  reinterpretan sus bytes restantes.
- La desconexion de un cliente elimina su entidad y difunde el nuevo `STATE`.
- El servidor no expone rutas privadas, secretos ni datos de autenticacion.

## Pruebas de cierre

- Arranque reproducible con `--headless`.
- Dos clientes reciben el mismo `STATE` con las mismas entidades.
- Un segundo cliente no puede ocupar la casilla del primero.
- Un movimiento hacia un tile bloqueado no muta estado y produce `ERROR`.
- `HELLO`, `WELCOME`, `STATE`, `MOVE`, `ERROR`, `PING`, `PONG` y `GOODBYE`
  usan exclusivamente el framing de `protocolo-red` propio.

## No expone

- No implementa el framing ni los opcodes TVP 7.72.
- No permite al cliente escribir mapa, posiciones o persistencia.
- No convierte tiles desconocidos en suelo.
