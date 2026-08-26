# Estado: qa

Estado: EN_CURSO
Ultimo agente: codex
Ultima actualizacion: 2026-08-25T16:46:00-06:00
Contrato publicado: SI

## Depende de

- `assets`: contrato publicado.
- `protocolo-red`: implementacion existente y contrato especializado en
  `docs/tibia3d/NETWORK_PROTOCOL.md`; falta formalizar su STATE.

## Le toca

Probar contratos, recorridos completos, concurrencia, fixtures y regresiones.

## Hecho

- Andamiaje creado.
- Publicado el contrato de QA v1.0.0.
- Ejecutada paridad IR vs estado vivo: 81 tiles coincidentes, 0 diferencias,
  1 criatura ignorada.
- Validada escalera real en TVP: z7 -> z6 -> z7, dos posiciones recibidas por
  0x64, personaje restaurado; `EstadoMundo` tambien expone 0xBE/0xBF si el
  servidor usa esos paquetes.
- Integrado inspector conectado en `mundo3d.gd`: seleccion por Shift+click,
  toggle F4, stack vivo y flags/metadatos IR por chunks; escena principal carga
  en headless sin errores.

## Falta

- Completar matriz de pruebas de todos los recorridos y errores.
- Implementar checklist ejecutable y reporte.

## Bloqueos activos

- No puede cerrar integracion hasta que existan implementaciones revisables.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| Las pruebas de fecha usan reloj fijado | Evita que fallen con el paso de los meses | si |

## Notas para quien retome

- La revision cruzada debe hacerla un agente que no haya implementado el
  carril revisado.
