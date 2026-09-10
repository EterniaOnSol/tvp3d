# Estado: editor

Estado: LISTO_PARA_REVISION
Ultimo agente: claude
Ultima actualizacion: 2026-09-10T00:15:00-06:00
Contrato publicado: SI (`CONTRATO.md` v2.0.0)

## Turno cerrado: Phase 1F — Native Editor V2

- Publicado Editor V2 `2.0.0` (major) sobre `modelo-comun 2.1.0` y
  `assets 2.0.0`. NO depende de `servidor`, `cliente` ni `protocolo-red`.
- `tvp3d.editor.project/2.0.0` reemplaza `tvp3d.project.v1`: `project_id`
  UUID persistente (nunca path/coordenada/id legacy), `SourceBindingV2`
  atado a `ImportRunManifestV2.import_run_id` (no a
  `generated/maps/rookgaard_100sqm.json` ni a otra ruta de repositorio),
  `scope` en `PosicionTibiaV2`, `tile_overrides`/`authoring_records` como
  arrays estructurados en vez de objetos JSON con `itemId` como clave.
- Toda referencia autorada usa `CanonicalDomainId` + `definition_version`;
  `server_id`/`client_id`/`looktype`/`itemId`/sprite/GLB filename quedan
  fuera como identidad, solo evidencia via `IdentityResolutionV2` de Assets
  V2 (RESOLVED/UNRESOLVED/AMBIGUOUS preservados sin auto-seleccion).
- `override_kind`/`record_type` quedan en un registro cerrado 100%
  editor-owned hoy (`LEGACY_TILE_CATEGORY_ANNOTATION`,
  `VISUAL_PROFILE_DRAFT`): ninguno puede publicarse como
  AUTORITATIVO/NORMALIZED porque Map/World Rules y el contrato visual final
  (Monster3D u otro) no existen todavia.
- Separados con precision: Guardar (artefacto de editor, puede contener
  drafts/unresolved) != Exportar EDITOR_PROJECT (puede contener drafts
  marcados) != Publicacion AUTORITATIVA/NORMALIZED (exige RESOLVED, source
  binding vigente, owners publicados, cero INVALID/STALE/UNRESOLVED
  relevantes). Un intento de publicacion autoritativa en 2.0.0 siempre
  produce `EDITOR_EXPORT_BLOCKED`.
- `EditorValidationStateV2` (VALID/STALE_SOURCE/INVALID) separado de
  `EditorPersistenceStateV2` (CLEAN/DIRTY), y ambos separados del `status`
  por record (DRAFT/VALIDATED/STALE_SOURCE/UNRESOLVED).
- Undo/redo (64 estados, nueva edicion limpia redo) documentado como
  exclusivo del estado de proyecto: nunca muta fuentes, salida de Assets,
  runtime del servidor ni historial Git.
- Migracion explicita de `source.mapa`, `source.region`, `tiles[].tipo` y
  `profiles[itemId]` documentada; ningun mapeo no resuelto se descarta.
- Editor 1.0.0 preservado integro bajo
  `HISTORICAL / SUPERSEDED — Editor 1.0.0`.
- No se modifico codigo de produccion, escenas Godot, assets/importadores,
  servidor, cliente ni modelo-comun/protocolo-red. No se regenero mapa ni se
  crearon assets GLB.

## Dependencias downstream reportadas (Phase 1F)

- **Integracion V2** debe saber: los proyectos viven en `assets/proyectos/`
  como `tvp3d.editor.project/2.0.0`; `project_id` es UUID, no un path ni un
  nombre de archivo; no debe asumirse un archivo por region de mapa; los
  proyectos nunca contienen paths absolutos de maquina.
- **QA V2** debe materializar las fixtures de la seccion 21 del contrato:
  round-trip deterministico, rechazo de path absoluto, deteccion de fuente
  obsoleta, migracion resuelta/no-resuelta/ambigua, bloqueo de export
  autoritativo por unresolved/stale, y que undo/redo no toque fuentes.
- **Map / World Rules Domain** (futuro) debe publicar su propio schema/gate
  antes de que `LEGACY_TILE_CATEGORY_ANNOTATION` (o su sucesor) pueda
  exportarse como AUTORITATIVO/NORMALIZED.
- **Contrato visual/Monster3D** (futuro) debe publicar su propio
  visual-profile schema antes de que `VISUAL_PROFILE_DRAFT` (o su sucesor
  `VISUAL_PROFILE_ASSIGNMENT`) sea dato de produccion valido.

## Decisiones Phase 1F

| Decision | Motivo | Reversible |
|---|---|---|
| `project_id` es UUID de autoria, no content-hash | Un proyecto es un artefacto mutable de trabajo; un hash cambiaria con cada edicion y rompería identidad estable entre sesiones | no sin migracion |
| `SourceBindingV2` ata por `import_run_id` (hash), no por ruta | Una ruta de repositorio/maquina no detecta datos importados distintos; el hash si | no |
| `override_kind`/`record_type` quedan 100% editor-owned en 2.0.0 | Map/World Rules y el contrato visual final no existen; declarar un owner ajeno inventaria un contrato que no se publico | si, en cuanto esos contratos existan |
| Guardar nunca bloquea por DRAFT/UNRESOLVED; solo la publicacion AUTORITATIVA bloquea | Preserva flujo de trabajo en curso sin perder evidencia, mientras protege la autoridad de publicacion | no |
| `EditorValidationStateV2`, `EditorPersistenceStateV2` y `status` por record quedan separados | Evita una sola maquina de estados sobrecargada con preocupaciones distintas | no |

## Verificacion de cierre Phase 1F

- 6 bloques JSON del contrato parsean.
- Los eventos agregados son lineas JSON validas y solo se anexaron al final.
- `git diff --check` no reporta errores en las rutas del turno.
- Solo contrato/estado de `editor` y el diario append-only forman parte del
  cierre; los cambios sucios ajenos detectados al inicio quedan intactos.
- El contrato `editor` no referencia `servidor`, `cliente` ni
  `protocolo-red` como dependencia normativa.
- No se crearon/movieron archivos de produccion, escenas ni assets.
- Monster Domain, Monster3D y Cyclops siguen sin publicarse/implementarse.

## Depende de

- `modelo-comun` 2.1.0: contrato publicado.
- `assets` 2.0.0: contrato publicado.
- NO depende de `servidor`, `cliente` ni `protocolo-red`.

## Le toca

Mantener el formato de autoria y la edicion reproducible de proyectos V2
(overrides no autoritativos y drafts de perfil visual), sin modificar las
fuentes importadas, hasta que Map/World Rules y un contrato visual final
permitan publicacion autoritativa.

## Hecho

- Contrato `tvp3d.project.v1` publicado.
- Modelo `ProyectoTVP3D` con fuente, overrides, perfiles y validacion estricta.
- Undo/redo acotado a 64 estados.
- Guardado y exportacion JSON deterministas en `assets/proyectos/`.
- Botones Nuevo, Abrir, Guardar, Deshacer, Rehacer y Exportar integrados en la
  escena existente.
- Override de tile visible como volumen coloreado en el mapa.
- Guardar mapping actualiza tambien el perfil del proyecto propio.
- Self-test aislado y self-test de escena pasan.

## Falta

- Revision visual manual con ventana grafica y prueba cruzada con la
  integracion completa.
- Decidir en una siguiente iteracion si se necesita dialogo de archivos en vez
  de rutas editables.

## Bloqueos activos

- Ninguno para cerrar este carril.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| El editor exporta un formato propio versionado | Separa autoria de los datos originales | si |
| Los tiles se guardan como overrides dispersos | Evita duplicar el mapa importado | si |
| Los enteros JSON se normalizan al cargar/guardar | Mantiene determinismo entre runtimes | si |

## Notas para quien retome

- Un sprite plano no se convierte automaticamente en malla correcta; el
  perfil 3D debe conservar el id y declarar su geometria/material.
- La escena sigue usando el mapa real importado para visualizacion; el
  proyecto solo agrega autoria encima.
