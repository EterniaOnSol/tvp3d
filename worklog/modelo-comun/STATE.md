# Estado: modelo-comun

Estado: LISTO_PARA_REVISION
Ultimo agente: codex
Ultima actualizacion: 2026-09-09T06:43:44-06:00
Contrato publicado: SI
Version publicada: 2.0.0

## Turno cerrado: Phase 1A

- Congelar el contrato comun de Architecture V2 como version `2.0.0`.
- Trabajo exclusivamente documental y de contrato.
- No publicar Monster Domain ni Monster3D, ni modificar produccion, gameplay,
  red, mapa o runtime legacy.

## Resolucion compensatoria de la asignacion 2026-08-26

- La asignacion `EN_CURSO` de 2026-08-26 se declara obsoleta, no borrada.
- El trabajo de aquel turno quedo versionado en `1f9865c`; despues fue
  consumido por `protocolo-red`, `servidor` y `cliente` en cierres publicados.
- El bloqueo Git de aquel snapshot es historico: la rama
  `feature/architecture-v2` y su remoto estan operativos.
- La prueba QA v1 que quedo pendiente se conserva como deuda historica y no
  mantiene una reserva exclusiva del carril.

## Depende de

- Ninguno.

## Le toca

Definir y validar identidad, procedencia, coordenadas, footprints, entidades,
comandos, eventos, ownership, versionado y errores compartidos.

## Hecho en Phase 1A

- Contrato `CONTRATO.md` 2.0.0 publicado como ruptura mayor explicita.
- Identidad canonica separada de aliases de origen y de instancias runtime.
- `PosicionTibiaV2`, `DirectionV2` y `LogicalFootprintV1` congelados con
  rangos, serializacion, errores y ownership.
- Definicion de entidad separada de estado runtime autoritativo.
- Envelopes distintos para comandos cliente y eventos servidor.
- Frontera de persistencia, exclusion visual y migracion v1 -> v2 publicadas.
- Fixtures contractuales especificados; no se agrego codigo ni comportamiento.

## Follow-up fuera de este carril

- `protocolo-red` debe publicar un perfil V2 que consuma los envelopes y
  rechace versiones/ownership invalidos.
- `assets` debe migrar ids de fuente a `SourceAliasV2` en un turno propio.
- `servidor`, `cliente`, `editor` y `qa` requieren las migraciones enumeradas
  por el contrato, cada una en su carril.
- Monster Domain sigue siendo Phase 5 y Monster3D Phase 6; ninguno fue
  publicado ni autorizado.

## Historial v1 preservado

- Contrato `CONTRATO.md` v1.0.0 publico coordenadas, tiles, entidades,
  intenciones y transiciones cerradas; su contenido permanece en `1f9865c`.
- `coordenadas_tibia.gd` conserva round-trip y chunking con coordenadas
  negativas.
- `mapa_tvp3d.gd` acepta los siete tipos del contrato, considera caminables
  `SUELO` y `ESCALERA`, y expone `cargar_validado()` con errores explicitos.
- Quedo pendiente en aquel turno una prueba QA v1 y formalizar el consumo en
  `protocolo-red`. V2 conserva esa deuda como migracion downstream, no como
  reserva activa del carril.

## Bloqueos activos

- Ninguno.

## Verificacion de cierre

- Los 13 bloques JSON del contrato son parseables.
- Los eventos nuevos son JSONL validos y solo se agregaron al final.
- `git diff --check` no reporta errores en las rutas del turno.
- Phase 1A no modifico codigo de produccion, gameplay, red, mapa, legacy
  runtime ni documentos compartidos de Architecture V2.
- Monster Domain y Monster3D siguen sin contrato publicado.

## Bloqueos historicos preservados

- `GIT_SIN_AUTORIZACION_PARA_COMMIT_PUSH`: la propiedad de `.git` no coincide
  con el usuario de esta sesion; se puede revisar con
  `git -c safe.directory=C:/Users/dell/tvp3d`, pero este turno no tiene
  autorizacion explicita para commit/push. Este texto describe el snapshot de
  2026-08-26 y queda compensado por la resolucion anterior.

## Decisiones Phase 1A

| Decision | Motivo | Reversible |
|---|---|---|
| Publicar `2.0.0` | Los consumidores v1 malinterpretarian identidad, ids, direccion y envelopes V2 | no sin perfil de migracion |
| Direccion V2 solo cardinal | No mezclar facing con movimiento diagonal; diagonal queda reservada para version negociada | si, en version posterior |
| Footprint versionado e independiente de malla | La ocupacion SQM es autoridad del dominio servidor | no |
| Source aliases no son identidad | Preserva trazabilidad sin hacer permanentes ids legacy | no |

## Decisiones historicas v1

| Decision | Motivo | Reversible |
|---|---|---|
| El servidor es autoritativo | Evita que el cliente consolide estado falso | no |
| `cargar_validado()` es estricto y `cargar()` conserva fallback de demo con `ultimo_error` | Compatibilidad con el servidor propio existente sin ocultar el motivo de un rechazo a consumidores nuevos | si |
| `ESCALERA` comparte caminabilidad con `SUELO` | Una escalera es una celda transitable; el cambio no altera el fixture que no contiene escaleras | si |

## Notas para quien retome

- `cargar()` devuelve un mapa demo cuando falla por compatibilidad historica;
  los consumidores que deban rechazar entradas usan `cargar_validado()` y
  revisan `ok/error`.
- Solo cambiaron contrato/estado de `modelo-comun` y el diario append-only.
- Siguiente carril recomendado: `protocolo-red` para publicar su migracion V2.
