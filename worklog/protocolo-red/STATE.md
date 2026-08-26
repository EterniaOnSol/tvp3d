# Estado: protocolo-red

Estado: LISTO_PARA_REVISION
Ultimo agente: codex
Ultima actualizacion: 2026-08-26T05:28:46-06:00
Contrato publicado: SI

## Depende de

- `modelo-comun`: contrato publicado.

## Le toca

Definir y probar framing, version, mensajes, errores y compatibilidad de red.

## Hecho

- Contrato v1.0.0 publicado con framing, mensajes, errores y compatibilidad.
- Framing propio endurecido para conservar buffers fragmentados, rechazar
  opcodes desconocidos y validar payloads del contrato.
- Self-test cubre fragmentacion, concatenacion, round-trip y paquetes
  invalidos sin abrir sockets.
- Prueba punta a punta contra `servidor_propio/servidor.tscn`: `HELLO`,
  `WELCOME`, cuatro movimientos cardinales y cinco estados confirmados.

## Falta

- Validar el recorrido contra el servidor Godot propio con dos clientes.
- Mantener el adaptador TVP 7.72 separado de este framing JSON.

## Bloqueos activos

- `GIT_SIN_AUTORIZACION_PARA_COMMIT_PUSH`: este turno no tiene autorizacion
  explicita para crear commit o hacer push.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| TCP propio como primera version | Encaja con el ritmo de Tibia y simplifica entrega inicial | si |
| Framing de 4 bytes little-endian + opcode de 1 byte + JSON UTF-8 | Coincide con `protocolo_tvp3d.gd` y permite inspeccion sencilla durante la primera rebanada | si |
| El decoder devuelve siempre `buffer`, incluso con un frame incompleto | Evita perder bytes cuando TCP fragmenta el encabezado o el cuerpo | si |

## Notas para quien retome

- No mezclar el framing propio con el protocolo TVP 7.72.
- `cliente3d/red/` mantiene el adaptador legacy TVP 7.72; este turno solo toca
  el codec propio y su self-test dentro del carril de protocolo.
- El warning de cierre `Unreferenced static string to 0: servers` proviene del
  runtime de Godot al apagar el servidor de prueba y no afecto su codigo de
  salida ni el recorrido.
