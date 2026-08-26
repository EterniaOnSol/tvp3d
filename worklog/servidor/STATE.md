# Estado: servidor

Estado: NO_INICIADO
Ultimo agente: ninguno
Ultima actualizacion: 2026-08-25T08:00:00-06:00
Contrato publicado: NO

## Depende de

- `modelo-comun`: falta contrato.
- `protocolo-red`: falta contrato.
- `assets`: falta contrato.

## Le toca

Construir el servidor Godot headless autoritativo, sus reglas y persistencia.

## Hecho

- Andamiaje creado.

## Falta

- Publicar contrato.
- Implementar mundo, validacion, eventos y persistencia.

## Bloqueos activos

- Dependencias sin contrato.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| La persistencia pertenece al servidor | El cliente no puede escribir estado del juego | no |

## Notas para quien retome

- El proceso debe arrancar sin renderer mediante `--headless`.
