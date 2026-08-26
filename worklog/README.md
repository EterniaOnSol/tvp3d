# Worklog

Este directorio conserva el relevo entre agentes. `EVENTS.jsonl` es un diario
append-only; cada carril mantiene su `STATE.md` y su `CONTRATO.md`.

Reglas:

- Lee el archivo completo antes de actuar.
- Agrega una sola linea JSON por evento y no reescribas lineas anteriores.
- Usa solo los estados definidos en `AGENTS.md`.
- `BLOQUEADO` exige `blockers` no vacio y una explicacion accionable.
- Un carril no empieza implementacion hasta que sus dependencias tengan
  `CONTRATO.md` publicado.
- Los estados y contratos de un carril son escritos por su agente asignado;
  las revisiones cruzadas registran hallazgos sin editar su implementacion.

El directorio `TVP3D` actualmente no contiene `.git` ni un remoto confirmado.
El skill `cerrar-turno` debe registrar esa limitacion como bloqueo antes de
afirmar que hizo commit y push; nunca debe inventar una URL o credencial.
