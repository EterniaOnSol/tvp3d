# Estado: protocolo-red

Estado: NO_INICIADO
Ultimo agente: ninguno
Ultima actualizacion: 2026-08-25T08:00:00-06:00
Contrato publicado: NO

## Depende de

- `modelo-comun`: falta contrato.

## Le toca

Definir y probar framing, version, mensajes, errores y compatibilidad de red.

## Hecho

- Andamiaje creado.

## Falta

- Publicar `CONTRATO.md` despues del modelo.
- Implementar round-trip y fragmentacion.

## Bloqueos activos

- Contrato de `modelo-comun` aun no publicado.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| TCP propio como primera version | Encaja con el ritmo de Tibia y simplifica entrega inicial | si |

## Notas para quien retome

- No mezclar el framing propio con el protocolo TVP 7.72.
