# Contrato: editor

Estado: PUBLICADO
Version: 2.0.0
Carril: editor
Depende de: modelo-comun 2.1.0, assets 2.0.0

Editor V2 NO depende de `servidor`, `cliente` ni `protocolo-red`: el editor
autora datos y no necesita el stack de red en vivo para definir un proyecto.
Historial: Editor 1.0.0 dependia de `modelo-comun` y `assets` en sus
versiones vigentes de aquel momento (no declaradas por numero en 1.0.0); ver
`HISTORICAL / SUPERSEDED - Editor 1.0.0` mas abajo.

Esta es una revision **major** deliberada. Editor 1.x usa `itemId` crudo como
clave, un enum de tile legacy de siete valores como si fuera regla final,
rutas generadas fijas y perfiles visuales primitivos atados a ids legacy.
Ninguno de esos significados se reinterpreta silenciosamente como
Architecture V2. Las palabras `DEBE`, `NO DEBE`, `PUEDE` y `SOLO` son
normativas en las secciones 0-19 siguientes; el contenido bajo `HISTORICAL /
SUPERSEDED` no es normativo para V2.

## 0. Proposito y alcance normativo (Editor V2)

El editor es una **herramienta de autoria**. Puede crear y modificar datos de
proyecto propios (project-owned). NO:

- muta artefactos fuente importados de Tibia;
- muta estado runtime autoritativo del servidor;
- redefine identidad canonica;
- decide reglas de gameplay;
- convierte geometria visual en autoridad.

Editor V2 consume `modelo-comun 2.1.0` y `assets 2.0.0` y produce proyectos y
exports de autoria deterministas y versionados.

## 1. `EditorProjectV2`

Identificador de schema: `tvp3d.editor.project`, version `2.0.0`.

```json
{
  "schema": "tvp3d.editor.project",
  "version": "2.0.0",
  "project_id": "550e8400-e29b-41d4-a716-446655440000",
  "project_name": "rookgaard_norte_overrides",
  "source_binding": {
    "schema": "tvp3d.editor.source_binding",
    "version": "2.0.0",
    "assets_contract_version": "2.0.0",
    "import_run_manifest": {
      "logical_path": "assets/importados/v2/world.import-run.json",
      "sha256": "2222222222222222222222222222222222222222222222222222222222222222",
      "import_run_id": "sha256:3333333333333333333333333333333333333333333333333333333333333333"
    },
    "region_hint": {
      "min": {"x": 32073, "y": 32169, "z": 7},
      "max": {"x": 32109, "y": 32205, "z": 7}
    }
  },
  "scope": {
    "min": {"x": 32073, "y": 32169, "z": 7},
    "max": {"x": 32109, "y": 32205, "z": 7}
  },
  "tile_overrides": [],
  "authoring_records": [],
  "editor_metadata": {
    "created_with": {"tool": "tvp3d.editor", "version": "2.0.0"}
  }
}
```

Todos los campos son obligatorios; `tile_overrides` y `authoring_records`
pueden ser arrays vacios. Campos desconocidos se rechazan
(`EDITOR_PROJECT_INVALID`).

| Campo | Regla |
|---|---|
| `schema` | literal `tvp3d.editor.project` |
| `version` | literal `2.0.0` |
| `project_id` | `uuid_v4`, identidad de autoria persistente (seccion 2) |
| `project_name` | UTF-8 1..128 bytes; etiqueta de presentacion, no identidad |
| `source_binding` | `SourceBindingV2` exacto (seccion 3) |
| `scope` | `{min, max}` `PosicionTibiaV2` (seccion 1.1) |
| `tile_overrides` | `0..65536` `EditorTileOverrideV2` (seccion 4) |
| `authoring_records` | `0..65536` `AuthoringRecordV2` (seccion 5) |
| `editor_metadata` | objeto cerrado con `created_with.tool`/`created_with.version`; sin paths, timestamps ni ids de maquina |

### 1.1 `scope`

`min` y `max` son `PosicionTibiaV2` validos. En `2.0.0`, `min.z == max.z`
(alcance de autoria de un solo piso); un alcance multi-piso requiere una
extension minor futura del schema. `min.x <= max.x` y `min.y <= max.y`. El
`scope` es la region que el editor presenta por defecto; no restringe a que
`canonical_id` pueden apuntar los `authoring_records` — un record puede
referenciar una definicion fuera del scope visible.

## 2. `project_id`

`project_id` es un `uuid_v4` asignado una sola vez al crear el proyecto
(`Nuevo`). Es la identidad de autoria persistente del proyecto de EDITOR, no
una `CanonicalDomainId` de gameplay y no un `RuntimeInstanceRefV2`.

NO PUEDE ser:

- una ruta de archivo absoluta;
- un directorio local de una maquina;
- un `itemId`/id legacy importado;
- una coordenada de mapa.

Guardar el proyecto en una ruta distinta, renombrar el archivo o moverlo
NO cambia `project_id`. Dos archivos con el mismo `project_id` son la misma
identidad de autoria en distintos puntos de su historia (por ejemplo copias
de respaldo); el editor no fusiona automaticamente sus contenidos.

## 3. `SourceBindingV2`

El editor se ata a evidencia de publicacion inmutable de Assets V2:

```json
{
  "schema": "tvp3d.editor.source_binding",
  "version": "2.0.0",
  "assets_contract_version": "2.0.0",
  "import_run_manifest": {
    "logical_path": "assets/importados/v2/world.import-run.json",
    "sha256": "2222222222222222222222222222222222222222222222222222222222222222",
    "import_run_id": "sha256:3333333333333333333333333333333333333333333333333333333333333333"
  },
  "region_hint": {
    "min": {"x": 32073, "y": 32169, "z": 7},
    "max": {"x": 32109, "y": 32205, "z": 7}
  }
}
```

| Campo | Regla |
|---|---|
| `assets_contract_version` | SemVer; literal `2.0.0` para este perfil |
| `import_run_manifest.logical_path` | path relativo, evidencia/referencia, NO identidad |
| `import_run_manifest.sha256` | sha256 del manifest referenciado |
| `import_run_manifest.import_run_id` | `content_id` (`sha256:...`) del `ImportRunManifestV2` exacto contra el que se autoro el proyecto (assets 2.0.0 seccion 4) |
| `region_hint` | `{min,max}` `PosicionTibiaV2`, evidencia opcional; no restringe resolucion |

`import_run_manifest.import_run_id` es la clave primaria de deteccion de
obsolescencia: es determinista sobre `tool`, `inputs`, `contracts` y
`normalization_profile` segun assets 2.0.0. El editor NO se ata
principalmente a `generated/maps/rookgaard_100sqm.json` ni a ninguna otra
ruta de repositorio/maquina; una ruta es solo evidencia.

Al abrir el proyecto, el editor recalcula/lee el `import_run_id` y el
`sha256` publicados actualmente para el dataset referenciado. Si difieren de
los guardados en `source_binding`, el proyecto entra en estado de validacion
`STALE_SOURCE` (seccion 8). NO hay remapeo automatico; solo una migracion
explicita publicada puede resolverlo.

## 4. `EditorTileOverrideV2`

Anotacion de autoria por posicion, distinta de una regla autoritativa de
mundo:

```json
{
  "schema": "tvp3d.editor.tile_override",
  "version": "2.0.0",
  "position": {"x": 32091, "y": 32187, "z": 7},
  "override_kind": "LEGACY_TILE_CATEGORY_ANNOTATION",
  "payload_schema": "tvp3d.editor.legacy_tile_category",
  "payload_version": "1.0.0",
  "payload": {"category": 1},
  "status": "DRAFT"
}
```

| Campo | Regla |
|---|---|
| `position` | `PosicionTibiaV2` exacto |
| `override_kind` | `registry_token`; ver registro cerrado abajo |
| `payload_schema`/`payload_version` | del contrato **owner** de ese `override_kind` |
| `payload` | validado por ese owner |
| `status` | `DRAFT\|VALIDATED\|STALE_SOURCE\|UNRESOLVED` (seccion 6) |

### Registro cerrado de `override_kind`

Map / World Rules Domain sigue sin publicarse. Por eso, en `2.0.0`, NINGUN
`override_kind` puede declararse autoritativo:

| `override_kind` | Owner | `payload_schema/version` | Naturaleza |
|---|---|---|---|
| `LEGACY_TILE_CATEGORY_ANNOTATION` | `editor` (proyecto-local) | `tvp3d.editor.legacy_tile_category/1.0.0` | anotacion de paridad/migracion; `payload.category` conserva el enum legado `0..6` (suelo, pared, agua, arbol, roca, decoracion, escalera) verbatim, NUNCA una regla de mundo final |

`LEGACY_TILE_CATEGORY_ANNOTATION.status` NUNCA puede ser exportado como
`NORMALIZED_DOMAIN` autoritativo (seccion 9). Cuando Map / World Rules
publique su propio schema y gate, un `override_kind` nuevo con ese owner
podra componerse; este contrato no lo inventa hoy.

## 5. `AuthoringRecordV2`

Reemplaza el concepto v1 `profiles["870"]`. Toda referencia autorada a un
item/entidad/definicion usa `CanonicalDomainId` + `definition_version`, nunca
un id legacy directo:

```json
{
  "schema": "tvp3d.editor.authoring_record",
  "version": "2.0.0",
  "record_id": "7b1d9ad4-5d72-4b95-a00b-a6d83b302d7f",
  "target": {
    "schema": "tvp3d.editor.target_ref",
    "version": "2.0.0",
    "canonical_id": "tvp3d:item:gold_coin",
    "definition_version": "1.0.0"
  },
  "record_type": "VISUAL_PROFILE_DRAFT",
  "payload_schema": "tvp3d.editor.visual_profile_draft",
  "payload_version": "1.0.0",
  "payload": {
    "primitive": "box",
    "height": 1.5,
    "thickness": 0.25
  },
  "status": "DRAFT"
}
```

| Campo | Regla |
|---|---|
| `record_id` | `uuid_v4` asignado al crear el record; estable a traves de ediciones |
| `target` | `AuthoringTargetRefV2`: `canonical_id` + `definition_version` exactos; NUNCA `server_id`/`client_id`/`looktype`/`itemId`/sprite id/filename/GLB filename |
| `record_type` | `registry_token`; ver registro cerrado abajo |
| `payload_schema`/`payload_version` | del contrato **owner** de ese `record_type` |
| `payload` | validado por ese owner; se conserva tal cual si el owner es el propio editor (draft) |
| `status` | `DRAFT\|VALIDATED\|STALE_SOURCE\|UNRESOLVED` (seccion 6) |

Un array estructurado (no un objeto JSON con `itemId` como clave) permite
detectar duplicados exactos y ordenar deterministamente por
`(target.canonical_id, target.definition_version, record_type)`; dos records
con esa misma tupla activa son `EDITOR_RECORD_INVALID`.

### Registro cerrado de `record_type`

Ningun contrato de asset/presentacion final (Monster3D u otro) esta
publicado todavia. Por eso, en `2.0.0`:

| `record_type` | Owner | `payload_schema/version` | Naturaleza |
|---|---|---|---|
| `VISUAL_PROFILE_DRAFT` | `editor` (proyecto-local) | `tvp3d.editor.visual_profile_draft/1.0.0` | preserva `primitive\|auto,flat,card,wall,box`, `height 0.10..3.0`, `thickness 0.05..1.0` del prototipo 1.x; **nunca** dato visual V2 de produccion |

Cuando un contrato de asset/presentacion publique un `visual-profile schema`
propio, un `record_type` nuevo (por ejemplo
`VISUAL_PROFILE_ASSIGNMENT`) con ese owner podra componerse; este contrato no
lo inventa hoy. Este contrato tampoco define rutas GLB, rigs, clips de
animacion, PBR, LOD ni pipeline Blender.

## 6. Estado de un record (`DRAFT|VALIDATED|STALE_SOURCE|UNRESOLVED`)

Modelo cerrado, igual para `EditorTileOverrideV2` y `AuthoringRecordV2`:

| Estado | Significado |
|---|---|
| `DRAFT` | no validado aun, o su schema/payload fallo validacion; se conserva con diagnostico, nunca se descarta |
| `VALIDATED` | valido bajo su `payload_schema/version` propietario |
| `STALE_SOURCE` | el `source_binding` del proyecto quedo obsoleto (seccion 3); el record no se reevalua hasta migrar |
| `UNRESOLVED` | su `target`/evidencia legacy no resuelve a una identidad publicada (seccion 7) |

`VALIDATED` significa **valido bajo su schema propietario**. NO significa
aprobacion de gameplay autoritativa, salvo que el contrato de dominio owner
lo permita explicitamente para publicacion (ninguno lo permite hoy para
`VISUAL_PROFILE_DRAFT` ni para `LEGACY_TILE_CATEGORY_ANNOTATION`, que son
`editor`-owned por definicion y por lo tanto nunca alcanzan autoridad de
publicacion).

## 7. Resolucion de identidad (migracion de ids legacy)

Cuando un `AuthoringTargetRefV2` se deriva de un id legacy (por ejemplo
migrando `itemId` de Editor 1.0.0), el editor usa exactamente
`IdentityResolutionV2` de Assets V2:

- `RESOLVED` -> `target.canonical_id`/`definition_version` exactos; `status`
  puede avanzar a `VALIDATED` si el payload tambien valida;
- `UNRESOLVED` -> se preserva la evidencia (alias legacy) y el record queda
  `UNRESOLVED`; nunca se descarta ni recibe un `canonical_id` inventado;
- `AMBIGUOUS` -> se preservan **todos** los candidatos; el editor NO elige el
  primero ni ninguno por heuristica.

Prohibido sin excepcion: heuristica de filename, heuristica de looktype, o
"el client id ya es canonico". El editor no puede inventar
`CanonicalDomainId`.

## 8. Estado de validacion del proyecto (`EditorValidationStateV2`)

Separado deliberadamente del estado de persistencia (seccion 9) para no
mezclar preocupaciones distintas:

```text
VALID
STALE_SOURCE
INVALID
```

| Estado | Significado |
|---|---|
| `VALID` | el contenedor `tvp3d.editor.project/2.0.0` parsea y su `source_binding` coincide con la evidencia Assets vigente; records individuales pueden seguir `DRAFT`/`UNRESOLVED` sin degradar este estado |
| `STALE_SOURCE` | el contenedor parsea pero `source_binding` ya no coincide con el `import_run_id`/hash actual |
| `INVALID` | el contenedor no parsea o no valida contra su propio schema (JSON malformado, tipos incorrectos, rango invalido, campo desconocido) |

## 9. Estado de persistencia (`EditorPersistenceStateV2`)

```text
CLEAN
DIRTY
```

`CLEAN` es identico byte a byte al ultimo `Guardar`/`Abrir`. `DIRTY` tiene
cambios locales no guardados. Es ortogonal a `EditorValidationStateV2`: un
proyecto puede estar `DIRTY` y `VALID` a la vez, o `CLEAN` y `STALE_SOURCE` a
la vez (por ejemplo, justo tras abrirlo).

## 10. Abrir (`Abrir`)

Orden obligatorio:

1. parsear schema/version del proyecto;
2. validar la estructura del proyecto;
3. resolver `source_binding`;
4. verificar la publicacion/hash de Assets referenciada;
5. validar cada `AuthoringTargetRefV2` (`target.canonical_id` +
   `definition_version`);
6. validar cada `EditorTileOverrideV2`/`AuthoringRecordV2` bajo su schema
   owner;
7. clasificar records `UNRESOLVED`/`STALE_SOURCE`;
8. solo entonces exponer el proyecto como editable normal.

Si la validacion falla:

- NO se crea silenciosamente un proyecto en blanco;
- NO se reemplazan campos invalidos por defaults;
- se preserva evidencia de diagnostico (mensaje, `path`, bytes originales);
- NO se publica salida autoritativa.

Un `schema`/`version` de raiz totalmente desconocido (`EDITOR_SCHEMA_UNSUPPORTED`)
no abre sesion editable; un proyecto que si reconoce como
`tvp3d.editor.project/2.0.0` pero falla su propia validacion estructural
(`EDITOR_PROJECT_INVALID`) puede abrirse en modo diagnostico/recuperacion
(seccion 12), nunca como si estuviera limpio.

## 11. Guardar

`Guardar` persiste el proyecto de EDITOR. Guardar NO es publicacion.

Un proyecto puede contener records `DRAFT`/`UNRESOLVED` si el schema del
proyecto los admite explicitamente para recuperacion/trabajo en curso (los
admite: seccion 6). Guardar preserva su `status` visible; NUNCA descarta
silenciosamente un record desconocido/no resuelto. Guardar un proyecto en
estado de validacion `INVALID` esta permitido solo como recuperacion/borrador
explicitamente marcado (seccion 12); no repara el contenido por su cuenta.

## 12. Exportar / Publicar

Se separan tres conceptos:

| Concepto | Que es |
|---|---|
| **Guardar** | artefacto de trabajo propiedad del editor |
| **Exportar (EDITOR_PROJECT)** | artefacto generado deterministico para otro consumidor del propio proyecto de editor; PUEDE contener drafts si estan marcados explicitamente |
| **Publicacion AUTORITATIVA/NORMALIZED** | debe satisfacer el gate del dominio/assets propietario; el editor NO PUEDE anular las reglas de publicacion de Assets V2 |

Requisitos exactos de una publicacion AUTORITATIVA/NORMALIZED:

- toda identidad requerida esta `RESOLVED`;
- `source_binding` esta vigente (no `STALE_SOURCE`);
- todos los `payload_schema`/owner involucrados estan soportados/publicados;
- cero records `INVALID`/`STALE_SOURCE`/`UNRESOLVED` relevantes a ese export.

Dado que Map / World Rules Domain y un contrato de asset/presentacion visual
final **no estan publicados**, Editor V2 **NO PUEDE** publicar hoy ningun
export AUTORITATIVO/NORMALIZED para `LEGACY_TILE_CATEGORY_ANNOTATION` ni para
`VISUAL_PROFILE_DRAFT`: ningun owner distinto de `editor` existe todavia para
esos dos registros. El editor solo puede publicar artefactos cuyo contrato
owner ya exista; hoy ninguno de los dos tipos de record definidos en este
contrato lo tiene. Un intento de publicacion AUTORITATIVA en `2.0.0` siempre
produce `EDITOR_EXPORT_BLOCKED`.

## 13. Deshacer / Rehacer

Se preserva la semantica util de v1:

- deshacer/rehacer deterministas;
- una edicion nueva limpia el redo;
- historial acotado a 64 estados (sin motivo para cambiarlo).

Un registro de undo contiene una captura o diff de `scope`, `tile_overrides`
y `authoring_records` unicamente. Deshacer/rehacer:

- NUNCA muta `source_binding`, `project_id` ni `editor_metadata.created_with`;
- NUNCA muta artefactos fuente, salida de Assets, runtime del servidor ni
  historial Git;
- solo afecta el estado del proyecto de editor en memoria.

## 14. Determinismo

Aplica los principios de serializacion canonica de Assets V2 al documento
`tvp3d.editor.project/2.0.0` (este contrato, no el de assets, gobierna esta
serializacion):

- UTF-8 sin BOM, LF entre lineas y exactamente un LF final;
- orden de claves de schema segun se publica en este contrato;
- claves de mapas dinamicos ordenadas por bytes UTF-8; arrays-set
  (`tile_overrides`, `authoring_records`) ordenados por el comparador
  declarado en sus secciones;
- enteros en decimal sin `+`, exponentes, ceros iniciales o `-0`; `uint64`
  como string;
- a diferencia de Assets V2 Canonical JSON, `height`/`thickness` de
  `VISUAL_PROFILE_DRAFT` SI admiten floats de proyecto-local (son un draft
  editor-owned, no dato `NORMALIZED_DOMAIN`); se serializan con maximo 3
  decimales, sin ceros de relleno innecesarios y sin notacion exponencial;
- sin paths absolutos, timestamps, locale, hostname, usuario, PID ni ids
  aleatorios fuera de `project_id`/`record_id` (que son `uuid_v4`
  intencionales, no ids de maquina).

Para el mismo estado de proyecto, el export normalizado debe ser byte
identico donde el schema propietario lo exija.

## 15. Rutas y ownership (sin mover archivos este turno)

| Ruta | Semantica reservada |
|---|---|
| `assets/proyectos/` | proyectos de autoria persistentes (`tvp3d.editor.project/2.0.0`) |
| `herramientas/editor/` | utilidades de import/migracion/validacion del editor |
| `cliente3d/editor/` | aplicacion/presentacion del editor en Godot |

Ninguna ruta fisica se crea o mueve en este turno contract-only.

## 16. No se muta la fuente

El editor NO PUEDE sobrescribir:

- OTBM, OTB, DAT, SPR;
- `servidor/data/` legacy;
- artefactos fuente de Assets V2;
- Audit IR de Assets V2.

Los originales/importados permanecen inmutables; los datos autorados solo
los referencian por `canonical_id`/evidencia.

## 17. Sin autoridad runtime

El editor NUNCA decide en vivo:

caminabilidad, ocupacion, combate, existencia de entidad, resultado de spawn,
permiso de casa, transferencia de item, aceptacion de movimiento.

La previsualizacion es presentacion. Una previsualizacion de simulacion, si
se agrega mas adelante, debe ser explicitamente no-autoritativa salvo que se
conecte a un contrato runtime autoritativo publicado.

## 18. Previsualizacion

El editor puede presentar una previsualizacion 3D local usando transforms de
Godot, materiales temporales, placeholders primitivos, estado de camara y
gizmos. Nada de esto entra a la autoridad de dominio. Un asset visual
faltante NUNCA cambia `CanonicalDomainId`.

## 19. Migracion desde Editor 1.0.0

| Campo v1 | Regla de migracion a V2 |
|---|---|
| `format: tvp3d.project.v1`, `version: 1` | queda `HISTORICAL/SUPERSEDED`; un archivo v1 no se abre como v2 sin un adaptador de migracion explicito, y ese adaptador no se implementa en este turno |
| `source.mapa` (path string) | pasa a evidencia/input de migracion; NUNCA identidad del proyecto; `project_id` se asigna nuevo porque v1 no tenia uno |
| `source.region {min_x,max_x,min_y,max_y,z}` | se copia directo a `scope.min`/`scope.max` `PosicionTibiaV2` (mismo piso) |
| `tiles[].{x,y,z,tipo}` | se convierte en `EditorTileOverrideV2` con `override_kind=LEGACY_TILE_CATEGORY_ANNOTATION`; `payload.category = tipo` preservado verbatim `0..6`; `status=DRAFT` hasta revision; NUNCA se promueve automaticamente a regla autoritativa |
| `profiles[itemId] {primitive,height,thickness}` | `itemId` se resuelve via `IdentityResolutionV2` de Assets V2 (seccion 7): `RESOLVED` -> `AuthoringRecordV2` con `target.canonical_id` resuelto, `record_type=VISUAL_PROFILE_DRAFT`, payload preservado verbatim, `status=DRAFT`; `UNRESOLVED`/`AMBIGUOUS` -> se preserva el record con evidencia legacy y `status=UNRESOLVED`, sin auto-seleccionar candidato |

Un mapeo no resuelto o ambiguo permanece visible; nunca bloquea conservar el
proyecto legacy solo porque su migracion esta incompleta.

## 20. `EditorErrorV2`

```json
{
  "schema": "tvp3d.editor.error",
  "version": "2.0.0",
  "code": "EDITOR_SOURCE_HASH_MISMATCH",
  "path": null,
  "message": "import run manifest sha256 no coincide con el source_binding del proyecto",
  "context": {}
}
```

`code` es `registry_token`; `path` es `null` o JSONPath ASCII 1..256 bytes;
`message` es UTF-8 0..256 bytes sin secretos ni paths absolutos; `context`
es `{}` en `2.0.0`. Un error de una dependencia (Assets, modelo-comun)
conserva su `owner`/`code` original; el editor no se apropia de ese codigo.

| Codigo | Abrir | Guardar | Exportar (EDITOR_PROJECT) | Publicacion autoritativa |
|---|---|---|---|---|
| `EDITOR_SCHEMA_UNSUPPORTED` | no, no crea sesion editable | no aplica | no aplica | no |
| `EDITOR_PROJECT_INVALID` | si, solo modo diagnostico/recuperacion | si, marcado recuperacion | si, marcado draft | no |
| `EDITOR_SOURCE_BINDING_MISSING` | si, solo modo diagnostico/recuperacion | si, marcado recuperacion | si, marcado draft | no |
| `EDITOR_SOURCE_HASH_MISMATCH` | si | si | si | no |
| `EDITOR_SOURCE_STALE` | si | si | si | no |
| `EDITOR_TARGET_UNRESOLVED` | si | si | si, ese record marcado `UNRESOLVED` | no para ese record |
| `EDITOR_TARGET_AMBIGUOUS` | si | si | si, ese record marcado `UNRESOLVED` | no para ese record |
| `EDITOR_RECORD_SCHEMA_UNSUPPORTED` | si | si, record preservado opaco/`DRAFT` | si | no para ese record |
| `EDITOR_RECORD_INVALID` | si | si, marcado `DRAFT` con diagnostico | si | no para ese record |
| `EDITOR_EXPORT_BLOCKED` | si (no afecta apertura) | si | rechaza especificamente el intento de export AUTORITATIVO | no, por definicion |
| `EDITOR_ABSOLUTE_PATH_REJECTED` | rechaza solo la ruta ofrecida; el proyecto ya abierto no se cierra | si | si | no aplica |

No se duplican codigos de `AssetImportErrorV2` ni de `tvp3d.domain_error`
comunes; un fallo de esas capas conserva su owner/code tal cual, envuelto
solo si este contrato necesita correlacionarlo con una accion de editor.

## 21. Fixtures contractuales (especificacion, sin produccion)

| Fixture | Caso minimo | Resultado obligatorio |
|---|---|---|
| `EDITOR-NEW-001` | `Nuevo` proyecto vacio | `tvp3d.editor.project/2.0.0` valido, `tile_overrides=[]`, `authoring_records=[]` |
| `EDITOR-ROUNDTRIP-001` | guardar y volver a abrir el mismo estado | bytes deterministas identicos |
| `EDITOR-PATH-001` | ruta absoluta de maquina ofrecida como evidencia/origen | `EDITOR_ABSOLUTE_PATH_REJECTED` |
| `EDITOR-BINDING-001` | `source_binding` valido contra Assets 2.0.0 | proyecto `VALID` |
| `EDITOR-STALE-001` | `import_run_id` guardado difiere del vigente | `EDITOR_SOURCE_STALE`, estado `STALE_SOURCE` |
| `EDITOR-SCHEMA-001` | `schema`/`version` de raiz desconocido | `EDITOR_SCHEMA_UNSUPPORTED`, sin sesion editable |
| `EDITOR-TARGET-001` | `target` con `canonical_id` + `definition_version` resolubles | aceptado |
| `EDITOR-CLIENTID-001` | intento de usar client id crudo como `canonical_id` | rechazado |
| `EDITOR-LOOKTYPE-001` | intento de usar looktype crudo como `canonical_id` | rechazado |
| `EDITOR-MIGRATE-RESOLVED-001` | `itemId` legacy con mapping `RESOLVED` | `AuthoringRecordV2` con `target.canonical_id` correcto, `status` puede ser `VALIDATED` |
| `EDITOR-MIGRATE-UNRESOLVED-001` | `itemId` legacy `UNRESOLVED` | record preservado, `status=UNRESOLVED` |
| `EDITOR-MIGRATE-AMBIGUOUS-001` | `itemId` legacy con 2+ candidatos | todos los candidatos preservados; ninguno auto-seleccionado |
| `EDITOR-TILECAT-001` | tile override legacy migrado | `override_kind=LEGACY_TILE_CATEGORY_ANNOTATION`, nunca autoritativo |
| `EDITOR-SAVE-DRAFT-001` | guardar proyecto con un record `DRAFT` | el `status DRAFT` se conserva visible tras guardar |
| `EDITOR-EXPORT-BLOCK-UNRESOLVED-001` | export autoritativo con un record `UNRESOLVED` | `EDITOR_EXPORT_BLOCKED` |
| `EDITOR-EXPORT-BLOCK-STALE-001` | export autoritativo con proyecto `STALE_SOURCE` | `EDITOR_EXPORT_BLOCKED` |
| `EDITOR-UNDO-001` | deshacer una edicion de `tile_overrides` | solo cambia estado del proyecto; sin efecto en fuentes/Assets/servidor/Git |
| `EDITOR-REDO-001` | rehacer tras una edicion divergente | pila de redo se limpia |
| `EDITOR-VISUAL-MISSING-001` | asset visual de presentacion faltante para un `target` | `canonical_id` del record se conserva intacto |
| `EDITOR-NOVISUAL-INJECT-001` | intento de inyectar GLB/rig/semantica Monster3D como dato de dominio generico | rechazado; no existe ese schema en este contrato |
| `EDITOR-SOURCE-IMMUTABLE-001` | guardar/exportar un proyecto | los artefactos fuente (OTBM/OTB/DAT/SPR/audit IR) quedan byte-identicos |

Especificaciones de contrato; ningun test ni produccion se implementa en
este turno.

## 22. Consumidores y exclusiones

Consumidores: `cliente3d/editor/` (aplicacion Godot), `herramientas/editor/`
(utilidades), `integracion`, `qa`.

Editor V2 no expone credenciales, rutas privadas, estado runtime del
servidor, reglas finales de Map/World, ni mapping visual final
looktype->asset. No autoriza modificar assets/importadores, `mundo3d.gd`,
servidor, cliente, Monster Domain o Monster3D. No regenera datos de mapa ni
crea assets GLB.

## 23. Dependencias downstream pendientes

| Falta | Bloquea |
|---|---|
| Map / World Rules Domain (schema + gate) | publicacion AUTORITATIVA de `LEGACY_TILE_CATEGORY_ANNOTATION`/su sucesor |
| Contrato de asset/presentacion visual (Monster3D u otro) | publicacion AUTORITATIVA de `VISUAL_PROFILE_DRAFT`/su sucesor `VISUAL_PROFILE_ASSIGNMENT` |
| Adaptador de migracion explicito Editor 1.0.0 -> 2.0.0 | abrir un archivo `tvp3d.project.v1` directamente en Editor V2 |

## Historial de contrato de editor

| Version | Publicacion |
|---|---|
| `1.0.0` | formato propio `tvp3d.project.v1`, overrides de tile por enum legacy y perfiles primitivos por `itemId` (ver HISTORICAL) |
| `2.0.0` | `tvp3d.editor.project/2.0.0`: identidad de proyecto UUID, `SourceBindingV2` atado a `ImportRunManifestV2`, referencias por `CanonicalDomainId`, registro cerrado de `override_kind`/`record_type` (ambos editor-owned hasta que Map/World y visual/Monster3D publiquen), separacion guardar/exportar/publicar |

## HISTORICAL / SUPERSEDED — Editor 1.0.0

Estado: `SUPERSEDED` por Editor V2 2.0.0 (secciones 0-23 arriba). Preservado
integro como evidencia; ninguna palabra `DEBE`/`NO DEBE`/`SOLO` en las
secciones siguientes gobierna el contrato vigente. `itemId`, el enum `tipo`
legacy y los perfiles primitivos NUNCA fueron conceptos V2: son el material
que la seccion 19 migra explicitamente.

## Objetivo

El editor permite crear autoria propia sobre una region del mapa importado:
overrides de tipo de tile y perfiles 3D por `itemId`. La fuente importada es
solo lectura y no se modifica desde el editor.

## Formato `tvp3d.project.v1`

El archivo JSON versionado contiene exactamente estos bloques:

```json
{
  "format": "tvp3d.project.v1",
  "version": 1,
  "source": {
    "mapa": "generated/maps/rookgaard_100sqm.json",
    "region": {
      "min_x": 32073,
      "max_x": 32109,
      "min_y": 32169,
      "max_y": 32205,
      "z": 7
    }
  },
  "tiles": [
    {"x": 32091, "y": 32187, "z": 7, "tipo": 1}
  ],
  "profiles": {
    "870": {
      "primitive": "box",
      "height": 1.5,
      "thickness": 0.25
    }
  }
}
```

`tiles` es una lista dispersa: solo contiene celdas editadas. Los tipos
validos son `0..6` (suelo, pared, agua, arbol, roca, decoracion y escalera).
La coordenada `z` esta limitada a `0..15`. `profiles` usa ids positivos y
primitivas `auto`, `flat`, `card`, `wall` o `box`; la altura valida es
`0.10..3.0` y el grosor `0.05..1.0`.

Los numeros se normalizan al serializar, las listas se ordenan por coordenada
y por id, y los archivos cargados se validan antes de entrar al editor.

## Operaciones

- `Nuevo` crea un proyecto vacio vinculado a la region visible.
- `Abrir` carga un JSON validado; si falla, conserva el proyecto actual.
- `Guardar` persiste el proyecto y crea `assets/proyectos/` cuando falta.
- `Exportar` escribe una copia normalizada.
- `Aplicar tile` registra un override y lo dibuja como volumen coloreado.
- Guardar mapping actualiza tambien el perfil 3D del `itemId` seleccionado.
- `Deshacer` y `Rehacer` mantienen hasta 64 estados y limpian redo tras una
  nueva edicion.

## Propiedad y limites

El carril editor es propietario de `cliente3d/editor/` y de este contrato.
Los mapas originales, sprites, OTBM/IR y las reglas del servidor no se editan.
La integracion completa debe conservar la autoridad del servidor y el cliente
solo debe presentar estado confirmado.

## Verificacion

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d --script editor/proyecto_self_test.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d editor/editor3d.tscn -- --self-test
```

Ambos comandos deben terminar con codigo cero y mensajes `OK`.
