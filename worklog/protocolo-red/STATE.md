# Estado: protocolo-red

Estado: LISTO_PARA_REVISION
Ultimo agente: codex
Ultima actualizacion: 2026-08-29T05:23:17-06:00
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
- Contrato 1.1.0 publicado para el estado de criatura TVP 7.72.
- `AddCreature` conserva luz, velocidad, skull y party shield; el marcador
  corto de giro mantiene los valores anteriores y ya no cura visualmente.
- `0x8D`, `0x8F`, `0x90` y `0x91` actualizan solo criaturas conocidas,
  emiten estado confirmado y consumen IDs desconocidos sin desalinear.
- `0x6C` de `mi_id` con HP autoritativo cero emite `jugador_muerto`; una
  retirada con HP positivo queda distinguida como teleport/refresh posible.
- `estado_criatura_self_test.gd` cubre payload completo, concatenacion,
  truncados, desconocidos, giro corto, teleport y muerte; toda la regresion
  de protocolo, contenedores, controles, eventos, spells, main y editor pasa.

## Falta

- Validar el recorrido contra el servidor Godot propio con dos clientes.
- Mantener el adaptador TVP 7.72 separado de este framing JSON.
- El consumidor debe reaccionar a `jugador_muerto`, enviar logout `0x14` y
  presentar la reentrada; pertenece al siguiente carril de cliente.
- QA debe hacer pruebas vivas de muerte/corpse/loot y actualizar la matriz
  global de opcodes que todavia describe `0x8D/0x8F/0x90/0x91` como SKIP.

## Bloqueos activos

- Ninguno.

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
- Continuidad: ejecutar
  `Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d --script res://red/estado_criatura_self_test.gd`.
  El siguiente carril no debe volver a inferir muerte solo desde `0x6C`: debe
  consumir la señal ya validada y conservar la autoridad del servidor.
