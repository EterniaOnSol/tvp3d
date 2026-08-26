# Estado: modelo-comun

Estado: EN_CURSO
Ultimo agente: codex
Ultima actualizacion: 2026-08-26T05:14:13-06:00
Contrato publicado: SI

## Depende de

- Ninguno.

## Le toca

Definir y validar entidades, coordenadas, tiles, acciones y transiciones
compartidas.

## Hecho

- Contrato `CONTRATO.md` v1.0.0 publicado con coordenadas, tiles, entidades,
  intenciones y transiciones cerradas.
- `coordenadas_tibia.gd` conserva round-trip y chunking con coordenadas
  negativas.
- `mapa_tvp3d.gd` acepta los siete tipos del contrato, considera caminables
  `SUELO` y `ESCALERA`, y expone `cargar_validado()` con errores explícitos.

## Falta

- Agregar una prueba del carril QA que cargue un mapa valido y rechace version,
  celda y transicion invalidas.
- Formalizar el uso del modelo en el contrato de `protocolo-red` antes de
  ampliar sus mensajes.

## Bloqueos activos

- `GIT_SIN_AUTORIZACION_PARA_COMMIT_PUSH`: la propiedad de `.git` no coincide
  con el usuario de esta sesion; se puede revisar con
  `git -c safe.directory=C:/Users/dell/tvp3d`, pero este turno no tiene
  autorizacion explicita para commit/push.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| El servidor es autoritativo | Evita que el cliente consolide estado falso | no |
| `cargar_validado()` es estricto y `cargar()` conserva fallback de demo con `ultimo_error` | Compatibilidad con el servidor propio existente sin ocultar el motivo de un rechazo a consumidores nuevos | si |
| `ESCALERA` comparte caminabilidad con `SUELO` | Una escalera es una celda transitable; el cambio no altera el fixture que no contiene escaleras | si |

## Notas para quien retome

- `cargar()` devuelve un mapa demo cuando falla por compatibilidad historica;
  los consumidores que deban rechazar entradas usan `cargar_validado()` y
  revisan `ok/error`.
- No se modificaron rutas de `protocolo-red`, `servidor`, `cliente`, `assets`
  ni `editor`.
