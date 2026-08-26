# Estado: servidor

Estado: LISTO_PARA_REVISION
Ultimo agente: codex
Ultima actualizacion: 2026-08-26T05:45:03-06:00
Contrato publicado: SI

## Depende de

- `modelo-comun`: contrato publicado.
- `protocolo-red`: contrato publicado.
- `assets`: contrato publicado.

## Le toca

Construir el servidor Godot headless autoritativo, sus reglas y persistencia.

## Hecho

- Andamiaje creado.
- Contrato v1.0.0 publicado para arranque, sesiones, autoridad y movimiento.
- Servidor headless carga el mapa con validacion estricta; la ausencia solo
  activa el demo determinista anunciado en el perfil de demo.
- Posiciones iniciales reservan casillas desde la conexion TCP y no se
  solapan entre clientes.
- `MOVE` valida cardinalidad, caminabilidad y ocupacion; los rechazos emiten
  `ERROR` sin mutar el estado.
- `STATE` se difunde completo y ordenado por id a todos los jugadores listos.
- Sesiones, desconexiones, `PING/PONG`, direccion de movimiento y transiciones
  quedan cubiertos por la implementacion.

## Falta

- Integrar el cliente 3D propio con este recorrido de autoridad.
- Ejecutar revision cruzada del carril y decidir una persistencia duradera para
  jugadores cuando exista contrato de identidad/autenticacion.

## Bloqueos activos

- Ninguno.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| La persistencia pertenece al servidor | El cliente no puede escribir estado del juego | no |
| El estado de jugadores del perfil propio es de sesion y vive en memoria | Evita rehidratar sesiones sin autenticacion ni contrato de identidad persistente | si |
| Un mapa existente invalido detiene el arranque; solo la ausencia usa el demo anunciado | Evita ocultar corrupcion o incompatibilidad de datos | si |

## Notas para quien retome

- El proceso debe arrancar sin renderer mediante `--headless`.
