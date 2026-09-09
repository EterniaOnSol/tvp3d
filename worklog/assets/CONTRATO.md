# Contrato: assets

Version: 2.0.0
Estado: PUBLICADO
Propietario: assets
Depende de: ninguno para publicar; modelo-comun 2.0.0 para implementar
exportadores V2

## Proposito y alcance

Congelar la frontera Architecture V2 que observa fuentes Tibia/TVP de solo
lectura, conserva evidencia auditable, resuelve identidades explicitamente y
publica datos normalizados versionados para servidor, cliente, editor y QA.
Assets/importadores no crean autoridad de gameplay.

Publicar este contrato no depende de otro carril. Implementar exportadores V2
si depende de modelo-comun 2.0.0 y debe consumir sus tipos sin redefinirlos,
exactamente como establece CARRILES.md.

```text
SOURCE_ARTIFACT
      -> IMPORT_RECORD
      -> IDENTITY_RESOLUTION
      -> NORMALIZED_RECORD
      -> DERIVED_ARTIFACT
```

Cada etapa es distinta. Un cache, catalogo o chunk derivado nunca es fuente de
verdad y un dato importado nunca se vuelve autoritativo solo por publicarse.

## Convenciones normativas V2

- JSON usa UTF-8 y los tipos numericos/strings de modelo-comun 2.0.0.
- CanonicalDomainId, SourceAliasV2, DomainIdentityV2 y PosicionTibiaV2 se
  referencian por nombre y version; este contrato no cambia sus campos,
  rangos, enums ni errores.
- sha256 es exactamente 64 caracteres ASCII minusculos con
  `^[0-9a-f]{64}$`.
- content_id es `sha256:` seguido de un sha256.
- registry_token es el tipo comun `^[A-Z][A-Z0-9_]{0,63}$`.
- uint64_string y SemVer conservan la forma exacta de modelo-comun 2.0.0.
- Campos desconocidos y nombres JSON duplicados se rechazan.

## 1. Etapas cerradas del pipeline

| Etapa | Entrada | Salida | Puede contener unresolved | Autoridad |
|---|---|---|---|---|
| `SOURCE_ARTIFACT` | archivo original read-only | SourceArtifactManifestV2 | no aplica | IMPORT_ONLY |
| `IMPORT_RECORD` | bytes verificados | observacion lossless/auditable | si | IMPORT_ONLY |
| `IDENTITY_RESOLUTION` | aliases + mapping publicado | IdentityResolutionV2 | si | IMPORT_ONLY/RESOLVED_DOMAIN |
| `NORMALIZED_RECORD` | import record validado + resolucion | schema apto para consumidor | segun gate del consumidor | no crea autoridad |
| `DERIVED_ARTIFACT` | audit/normalized data publicados | indice, chunk, cache o catalogo regenerable | solo si su perfil lo permite | derivado |

No se salta una etapa por coincidencia de nombre o numero. SOURCE_ARTIFACT es
inmutable; IMPORT_RECORD conserva lo observado; IDENTITY_RESOLUTION asocia
sin adivinar; NORMALIZED_RECORD aplica un schema publicado; DERIVED_ARTIFACT
siempre declara de que hashes se regenera.

## 2. SourceArtifactManifestV2

Objeto raiz exacto:

```json
{
  "schema": "tvp3d.assets.source_artifact",
  "version": "2.0.0",
  "artifact_id": "legacy/tvp772/world-map",
  "system": "OTBM",
  "source_version": "7.72",
  "kind": "OTBM",
  "repository_relative_path": "servidor/data/world/map.otbm",
  "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "size_bytes": "123456"
}
```

Todos los campos son obligatorios:

| Campo | Tipo/regla |
|---|---|
| `schema` | literal `tvp3d.assets.source_artifact` |
| `version` | literal `2.0.0` |
| `artifact_id` | id logico estable, `^[a-z][a-z0-9._/-]{0,127}$` |
| `system` | enum `system` de SourceAliasV2 |
| `source_version` | forma comun SourceAliasV2, 1..64 bytes |
| `kind` | SourceArtifactKindV2 cerrado |
| `repository_relative_path` | path relativo normalizado, 1..512 bytes |
| `sha256` | digest de los bytes exactos |
| `size_bytes` | uint64_string |

SourceArtifactKindV2 contiene `OTBM`, `OTB`, `XML`, `DAT`, `SPR`,
`CPP_SOURCE`, `LUA_SOURCE` y `BINARY_CAPTURE`. Cada kind requiere su parser
publicado; compartir manifest no implica compartir parser.

artifact_id identifica el artefacto logico dentro de un perfil de importacion,
no una entidad de dominio. repository_relative_path es procedencia, tampoco
identidad. El path:

- usa `/`, nunca `\`;
- no empieza por `/`, drive letter, UNC ni esquema URI;
- no contiene componentes vacios, `.`, `..`, NUL o `:`;
- nunca contiene `C:\Users\...` ni otra ruta de maquina.

`servidor/data/` solo puede aparecer como fuente read-only. El importador
verifica existencia, size y hash antes de parsear. Archivo ausente o hash
distinto es detectable y fatal; no se usa una copia parecida ni se actualiza
el manifest automaticamente.

### SourceArtifactRefV2 y SourceEvidenceRefV2

Una referencia no duplica el manifest:

```json
{
  "artifact_id": "legacy/tvp772/world-map",
  "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
}
```

SourceEvidenceRefV2 agrega un locator logico de 1..256 bytes:

```json
{
  "artifact_id": "legacy/tvp772/world-map",
  "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "locator": "tile-area/32000/32000/tile/97/219/7/item/0"
}
```

locator usa `/` y no es un filesystem path. Una referencia cuyo artifact_id y
sha256 no coinciden con el manifest cargado produce SOURCE_HASH_MISMATCH.

## 3. ProvenanceV2

La clase de cada observacion/asociacion es machine-validable:

```json
{
  "class": "OBSERVED_SOURCE",
  "sources": [{
    "artifact_id": "legacy/tvp772/items-otb",
    "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "locator": "item/2148/flag/block_pathfind"
  }],
  "method": null,
  "method_version": null
}
```

Todos los campos son obligatorios. `sources` contiene 1..64 referencias
unicas, ordenadas por artifact_id, sha256, locator.

| class | Significado | method / method_version |
|---|---|---|
| `OBSERVED_SOURCE` | bytes/campo vistos directamente | ambos null |
| `NORMALIZED_SOURCE` | representacion tipada sin crear significado | registry_token + SemVer |
| `DERIVED_ORACLE` | calculo reproducible que imita una oracle | registry_token + SemVer |
| `RESOLVED_DOMAIN` | asociacion mediante mapping publicado | registry_token + SemVer |

OTBM house_id es OBSERVED_SOURCE. OTB block_pathfind es OBSERVED_SOURCE.
Convertir el entero del OTB a boolean tipado es NORMALIZED_SOURCE.
queryadd_walkable calculado desde TVP es DERIVED_ORACLE. Asociar aliases a
CanonicalDomainId es RESOLVED_DOMAIN. Ninguna clase significa autoridad
runtime.

## 4. ImportRunManifestV2

El manifest reproducible de ejecucion es:

```json
{
  "schema": "tvp3d.assets.import_run",
  "version": "2.0.0",
  "import_run_id": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
  "tool": {
    "id": "tvp3d.assets.importer",
    "version": "2.0.0"
  },
  "inputs": [{
    "artifact_id": "legacy/tvp772/world-map",
    "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }],
  "contracts": [
    {"name": "assets", "version": "2.0.0"},
    {"name": "modelo-comun", "version": "2.0.0"}
  ],
  "normalization_profile": {
    "id": "TVP772_BASELINE",
    "version": "1.0.0"
  },
  "outputs": [],
  "result": "SUCCESS",
  "summary": {
    "warnings": 0,
    "errors": 0,
    "fatals": 0,
    "unresolved": 0,
    "ambiguous": 0
  }
}
```

Reglas:

- tool.id cumple `^[a-z][a-z0-9._-]{0,127}$` y tool.version es SemVer.
- inputs contiene 1..256 SourceArtifactRefV2 unicos y ordenados por
  artifact_id/sha256.
- contracts contiene 1..32 pares unicos, ordenados por name; name cumple
  `^[a-z][a-z0-9._-]{0,63}$`.
- normalization_profile.id es registry_token y version es SemVer.
- result es `SUCCESS` o `FAILED`; los cinco contadores son uint32.
- No hay timestamp, hostname, usuario, path absoluto, PID ni UUID aleatorio.

Cada output tiene exactamente:

```json
{
  "logical_path": "assets/importados/v2/world.audit.json",
  "schema": "tvp3d.assets.audit_ir",
  "version": "3.0.0",
  "sha256": "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
  "size_bytes": "456789",
  "publication_class": "AUDIT_IR"
}
```

outputs contiene 0..4096 entradas ordenadas por logical_path. El path cumple
las reglas relativas de SourceArtifactManifestV2. publication_class es uno
de `AUDIT_IR`, `NORMALIZED_DOMAIN`, `CLIENT_DIAGNOSTIC` o
`DERIVED_CACHE`.

import_run_id es el sha256 de la serializacion canonica de un descriptor que
contiene, en este orden logico, tool, inputs, contracts y
normalization_profile; excluye outputs, result y summary para evitar ciclos.
Mismos inputs/hashes, tool/version, contratos y profile producen el mismo
import_run_id. Si ese id produce bytes de salida distintos bajo el mismo
schema/version, la corrida falla OUTPUT_NONDETERMINISTIC.

## 5. IdentityResolutionV2

La etapa consume exactamente SourceAliasV2 y CanonicalDomainId de
modelo-comun 2.0.0:

```json
{
  "schema": "tvp3d.assets.identity_resolution",
  "version": "2.0.0",
  "status": "RESOLVED",
  "canonical_id": "tvp3d:item:gold_coin",
  "aliases": [{
    "system": "OTB",
    "source_version": "7.72",
    "kind": "OTB_SERVER_ID",
    "value": "2148"
  }],
  "candidates": []
}
```

Todos los campos son obligatorios. aliases contiene 1..256 SourceAliasV2
exactos, sin duplicados y en el orden canonico comun. candidates contiene
0..64 CanonicalDomainId unicos, ordenados byte a byte.

| status | canonical_id | candidates | Regla |
|---|---|---|---|
| `RESOLVED` | CanonicalDomainId no null | vacio | mapping explicito unico |
| `UNRESOLVED` | null | vacio | no existe mapping publicado |
| `AMBIGUOUS` | null | 2..64 ids | mas de un mapping valido |

Para RESOLVED, proyectar canonical_id + aliases como DomainIdentityV2 debe
validar contra modelo-comun 2.0.0. Para UNRESOLVED y AMBIGUOUS el import
record se conserva; nunca se descarta ni recibe un id placeholder falso.

Un alias exacto duplicado dentro de aliases se rechaza. El mismo looktype o
client id puede pertenecer a dos identidades si la fuente realmente lo
comparte. Un resolver que necesita unicidad devuelve AMBIGUOUS y todos los
candidatos; nunca elige el primero. repository_relative_path, locator, nombre
XML o filename aislado no resuelven identidad. XML_NAME solo es alias cuando
cumple SourceAliasV2 y aun requiere un mapping publicado.

### IdentityMappingRecordV2

La evidencia de resolucion vive en un registro separado:

```json
{
  "schema": "tvp3d.assets.identity_mapping",
  "version": "2.0.0",
  "canonical_id": "tvp3d:item:gold_coin",
  "aliases": [{
    "system": "OTB",
    "source_version": "7.72",
    "kind": "OTB_SERVER_ID",
    "value": "2148"
  }],
  "mapping_profile": {"id": "TVP772_BASELINE", "version": "1.0.0"},
  "provenance": {
    "class": "RESOLVED_DOMAIN",
    "sources": [{
      "artifact_id": "legacy/tvp772/items-otb",
      "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      "locator": "item/2148"
    }],
    "method": "CURATED_MAPPING",
    "method_version": "1.0.0"
  }
}
```

En este registro, provenance.sources tiene 1..64 entradas y aliases contiene
1..256 SourceAliasV2. Dos mapping records que
asocian el mismo alias a ids distintos no se pisan: producen
IDENTITY_MAPPING_CONFLICT o AMBIGUOUS segun el profile declare que compartir
ese kind es valido.

## 6. Import records auditables

Todo import record incluye evidencia para volver a los bytes:

- record_id: content_id calculado sobre artifact hash, locator, record kind y
  orden de origen;
- source_evidence: 1..64 SourceEvidenceRefV2;
- raw_slice: objeto con sha256 y size_bytes de los bytes que originaron el
  registro;
- diagnostics: 0..256 codigos AssetImportErrorV2 en orden de deteccion.

record_id no es CanonicalDomainId ni UUID. raw_slice no sustituye la fuente:
permite detectar que el locator ya no apunta a los mismos bytes.

### TypedAttributeV2

```json
{
  "type": "UINT32",
  "value": 1224,
  "provenance": {
    "class": "OBSERVED_SOURCE",
    "sources": [{
      "artifact_id": "legacy/tvp772/world-map",
      "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "locator": "tile/32097/32219/7/item/1/attribute/action_id"
    }],
    "method": null,
    "method_version": null
  }
}
```

type es uno de `BOOL`, `INT32`, `UINT32`, `UINT64_STRING`,
`UTF8_STRING` o `POSITION_TIBIA`. value debe cumplir el tipo; UTF8_STRING
mide 0..65535 bytes y POSITION_TIBIA es exactamente PosicionTibiaV2. Un tipo
no publicado produce IMPORT_ATTRIBUTE_UNSUPPORTED; nunca se adivina su ancho
ni se saltan bytes.

## 7. ImportedItemRecordV2

Objeto auditable concreto:

```json
{
  "schema": "tvp3d.assets.imported_item",
  "version": "2.0.0",
  "record_id": "sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
  "source_order": 0,
  "identity_resolution": {
    "schema": "tvp3d.assets.identity_resolution",
    "version": "2.0.0",
    "status": "RESOLVED",
    "canonical_id": "tvp3d:item:gold_coin",
    "aliases": [
      {"system":"OTB","source_version":"7.72","kind":"CLIENT_ID","value":"3031"},
      {"system":"OTB","source_version":"7.72","kind":"OTB_SERVER_ID","value":"2148"}
    ],
    "candidates": []
  },
  "name_observations": [],
  "category": {
    "value": "DECORATION",
    "provenance": {
      "class": "NORMALIZED_SOURCE",
      "sources": [{
        "artifact_id": "legacy/tvp772/items-otb",
        "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        "locator": "item/2148/category"
      }],
      "method": "NORMALIZE_ITEM_CATEGORY",
      "method_version": "1.0.0"
    }
  },
  "count": {
    "value": 1,
    "provenance": {
      "class": "NORMALIZED_SOURCE",
      "sources": [{
        "artifact_id": "legacy/tvp772/world-map",
        "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "locator": "tile/32097/32219/7/item/0"
      }],
      "method": "NORMALIZE_ITEM_COUNT",
      "method_version": "1.0.0"
    }
  },
  "subtype": {
    "value": null,
    "provenance": {
      "class": "OBSERVED_SOURCE",
      "sources": [{
        "artifact_id": "legacy/tvp772/world-map",
        "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "locator": "tile/32097/32219/7/item/0"
      }],
      "method": null,
      "method_version": null
    }
  },
  "attributes_present": [],
  "attributes": {},
  "flags": {},
  "contents": [],
  "source_evidence": [
    {
      "artifact_id": "legacy/tvp772/items-otb",
      "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      "locator": "item/2148"
    },
    {
      "artifact_id": "legacy/tvp772/world-map",
      "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "locator": "tile/32097/32219/7/item/0"
    }
  ],
  "raw_slice": {
    "sha256": "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    "size_bytes": "2"
  },
  "diagnostics": []
}
```

Todos los campos son obligatorios y rigen estas reglas:

- source_order es uint32 y conserva el indice 0-based entre hermanos en el
  nodo OTBM/contenedor. Nunca se reordena por id o nombre.
- identity_resolution contiene server/client ids solo como SourceAliasV2.
  No existen campos canonicos server_id o client_id en V2.
- name_observations contiene 0..64 objetos
  `{value, language, provenance}`. value es UTF-8 NFC de 0..256 bytes;
  language es ASCII BCP-47 simplificado de 2..16 bytes o null; provenance es
  ProvenanceV2. Un nombre vacio observado se conserva, no tapa otro nombre.
- category.value es registry_token o null; provenance es ProvenanceV2. Null
  conserva que no se pudo normalizar la categoria.
- count.value es uint32 `1..4294967295` y representa cantidad efectiva.
  subtype.value es uint32 `0..4294967295` o null y conserva el valor fuente.
  Ambos llevan ProvenanceV2 independiente: count nunca destruye subtype.
- attributes_present contiene 0..1024 registry_token en orden fuente. Distingue
  ausencia de un valor por defecto.
- attributes es un objeto de claves snake_case
  `^[a-z][a-z0-9_]{0,63}$` a TypedAttributeV2. Claves dinamicas se serializan
  en orden byte a byte. Como minimo preserva los atributos publicados en 1.4.0:
  action_id, unique_id, text, description, teleport_destination, depot_id,
  house_door_id, duration, decaying_state, written_date, written_by,
  sleeper_guid, sleep_start, charges, key_number, keyhole_number,
  door_quest_number, door_quest_value, door_level y chest_quest_number.
- flags es un objeto de la misma forma snake_case a
  `{value: bool, provenance: ProvenanceV2}`. block_pathfind y blocking son
  flags independientes; el primero nunca se colapsa en el segundo.
- contents contiene 0..65535 ImportedItemRecordV2 y conserva el orden del
  contenedor. Profundidad maxima 64; el profile publica tambien un limite total.
- source_evidence contiene 1..64 entradas. diagnostics puede estar vacio.

Un client id ausente significa que no existe ese SourceAliasV2; no se usa 0,
el server id ni un filename como sustituto.

## 8. ImportedTileRecordV2

```json
{
  "schema": "tvp3d.assets.imported_tile",
  "version": "2.0.0",
  "record_id": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "source_sequence": "0",
  "position": {"x": 32097, "y": 32219, "z": 7},
  "source_aliases": [{
    "system": "OTBM",
    "source_version": "7.72",
    "kind": "OTBM_POSITION",
    "value": "32097,32219,7"
  }],
  "house_id": {
    "value": 0,
    "provenance": {
      "class": "OBSERVED_SOURCE",
      "sources": [{
        "artifact_id": "legacy/tvp772/world-map",
        "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "locator": "tile/32097/32219/7/house_id"
      }],
      "method": null,
      "method_version": null
    }
  },
  "tile_flags": [],
  "tile_flags_value": {
    "value": 0,
    "provenance": {
      "class": "OBSERVED_SOURCE",
      "sources": [{
        "artifact_id": "legacy/tvp772/world-map",
        "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "locator": "tile/32097/32219/7/tile_flags"
      }],
      "method": null,
      "method_version": null
    }
  },
  "ground_record_id": null,
  "items": [],
  "walkability": {
    "walkable_historical": {
      "value": true,
      "provenance": {
        "class": "NORMALIZED_SOURCE",
        "sources": [{
          "artifact_id": "legacy/tvp772/items-otb",
          "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          "locator": "tile/32097/32219/7/item-flags"
        }],
        "method": "LEGACY_WALKABLE",
        "method_version": "1.4.0"
      }
    },
    "queryadd_walkable": {
      "value": true,
      "provenance": {
        "class": "DERIVED_ORACLE",
        "sources": [{
          "artifact_id": "legacy/tvp772/items-otb",
          "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          "locator": "tile/32097/32219/7/item-flags"
        }],
        "method": "TVP_QUERYADD_STATIC",
        "method_version": "1.0.0"
      }
    },
    "blocking": {
      "value": false,
      "provenance": {
        "class": "NORMALIZED_SOURCE",
        "sources": [{
          "artifact_id": "legacy/tvp772/items-otb",
          "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          "locator": "tile/32097/32219/7/item-flags"
        }],
        "method": "NORMALIZE_BLOCKING",
        "method_version": "1.0.0"
      }
    }
  },
  "source_evidence": [{
    "artifact_id": "legacy/tvp772/world-map",
    "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "locator": "tile/32097/32219/7"
  }],
  "raw_slice": {
    "sha256": "2222222222222222222222222222222222222222222222222222222222222222",
    "size_bytes": "8"
  },
  "diagnostics": []
}
```

Reglas:

- position es exactamente PosicionTibiaV2: x/y int32, z 0..15, sin Vector3,
  metros ni campos extra.
- source_sequence es uint64_string y conserva el orden total de recorrido.
- source_aliases contiene 1..16 SourceAliasV2; debe incluir el OTBM_POSITION
  cuando la fuente sea OTBM. La posicion sigue sin ser CanonicalDomainId.
- house_id.value y tile_flags_value.value son uint32 observados con
  ProvenanceV2. tile_flags contiene 0..256 objetos
  `{value: registry_token, provenance: ProvenanceV2}` unicos por value y
  ordenados por value; bits desconocidos sobreviven en tile_flags_value y
  generan diagnostico.
- items conserva el stack completo en orden fuente y cada source_order debe
  ser su indice. ground_record_id es null o el record_id de exactamente un item
  de items observado como ground. Un tile puede tener items sin ground.
- walkable_historical.value es bool con clase NORMALIZED_SOURCE e indica la
  derivacion historica 1.4 basada en blockSolid.
- queryadd_walkable.value es bool o null y su clase debe ser DERIVED_ORACLE;
  null expresa dependencia dinamica o metadata insuficiente.
- blocking.value es bool NORMALIZED_SOURCE derivado de metadata importada.
- source_evidence tiene 1..64 entradas; raw_slice y diagnostics siguen las
  reglas comunes de import record.

Los tres campos de walkability son IMPORT_ONLY/diagnosticos. Ni una flag OTB,
ni walkable_historical, ni queryadd_walkable decide caminabilidad dinamica,
ocupacion o pathfinding runtime. El servidor Godot final aplica contratos de
dominio/servidor y estado vivo.

## 9. NormalizedRecordV2

Un record apto para consumo usa un envelope generico; el payload concreto lo
publica el contrato propietario:

```json
{
  "schema": "tvp3d.assets.normalized_record",
  "version": "2.0.0",
  "record_id": "sha256:5555555555555555555555555555555555555555555555555555555555555555",
  "record_type": "ITEM_DEFINITION",
  "identity": {
    "schema": "tvp3d.domain_identity",
    "version": "2.0.0",
    "canonical_id": "tvp3d:item:gold_coin",
    "aliases": []
  },
  "payload_schema": "tvp3d.item_definition",
  "payload_version": "1.0.0",
  "payload": {},
  "source_record_ids": [
    "sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
  ],
  "provenance": {
    "class": "RESOLVED_DOMAIN",
    "sources": [{
      "artifact_id": "legacy/tvp772/items-otb",
      "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      "locator": "item/2148"
    }],
    "method": "TVP772_IDENTITY_MAP",
    "method_version": "1.0.0"
  }
}
```

Todos los campos son obligatorios. record_type es registry_token.
payload_schema cumple `^[a-z][a-z0-9_.]{0,127}$` y payload_version es SemVer.
payload es un objeto validado exactamente por ese schema/version; assets no
inventa sus campos. source_record_ids contiene 1..1024 content_id unicos y
ordenados. record_id es el hash de la serializacion canonica del objeto sin
record_id.

identity es DomainIdentityV2 exacto o null. Es obligatorio RESOLVED para toda
definicion consumida como identidad de dominio. Null solo es valido si el
contrato del payload publica otra clave estable, por ejemplo una
PosicionTibiaV2 para un record espacial; nunca permite usar client id,
looktype, filename o chunk key como identidad.

## 10. IR auditable y versionado

La decision V2 es usar schema nombrado y un major IR nuevo:

```json
{
  "schema": "tvp3d.assets.audit_ir",
  "version": "3.0.0",
  "import_run_id": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
  "source_artifacts": [{
    "schema": "tvp3d.assets.source_artifact",
    "version": "2.0.0",
    "artifact_id": "legacy/tvp772/world-map",
    "system": "OTBM",
    "source_version": "7.72",
    "kind": "OTBM",
    "repository_relative_path": "servidor/data/world/map.otbm",
    "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "size_bytes": "123456"
  }],
  "standalone_items": [],
  "tiles": [],
  "errors": [],
  "summary": {
    "items": "0",
    "tiles": "0",
    "unresolved": "0",
    "ambiguous": "0"
  }
}
```

source_artifacts contiene 1..256 SourceArtifactManifestV2 ordenados por
artifact_id. standalone_items contiene ImportedItemRecordV2 que no pertenecen
a un tile; tiles contiene ImportedTileRecordV2 en source_sequence ascendente.
errors contiene AssetImportErrorV2 en orden de deteccion. Los contadores son
uint64_string y deben coincidir con el contenido recursivo.

El antiguo documento sin schema y con `version: 2` sigue siendo
`LEGACY_OTBM_REGION_V2`. Un lector V2 exige schema string + SemVer
`3.0.0`; por tanto rechaza el root legacy antes de leer records. No se
reutiliza el numero 2 ni se transforma su significado implicitamente.

## 11. Regiones, chunks e indice

El audit IR completo es el artefacto auditable. Los chunks son
DERIVED_ARTIFACT regenerables. chunk_size es entero 1..65535 y en el profile
base vale 32. Para cada PosicionTibiaV2 se usa exactamente modelo-comun:

```text
chunk_x = floor(x / chunk_size)
chunk_y = floor(y / chunk_size)
local_x = x - chunk_x * chunk_size
local_y = y - chunk_y * chunk_size
```

local_x/local_y quedan en 0..chunk_size-1, z se conserva y x/y negativos usan
floor matematico, no truncado hacia cero. Una ChunkAddressV2 es:

```json
{"chunk_x":-1,"chunk_y":0,"z":7,"chunk_size":32}
```

chunk_x/chunk_y son int32, z es 0..15 y chunk_size 1..65535. No es identidad
de dominio ni reemplaza position.

El indice usa schema `tvp3d.assets.chunk_index` version `2.0.0`:

```json
{
  "schema": "tvp3d.assets.chunk_index",
  "version": "2.0.0",
  "source_document_sha256": "3333333333333333333333333333333333333333333333333333333333333333",
  "chunk_size": 32,
  "audit_header": {
    "schema": "tvp3d.assets.audit_ir",
    "version": "3.0.0",
    "import_run_id": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    "source_artifacts": [{
      "schema": "tvp3d.assets.source_artifact",
      "version": "2.0.0",
      "artifact_id": "legacy/tvp772/world-map",
      "system": "OTBM",
      "source_version": "7.72",
      "kind": "OTBM",
      "repository_relative_path": "servidor/data/world/map.otbm",
      "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "size_bytes": "123456"
    }],
    "standalone_items": [],
    "errors": [],
    "summary": {
      "items": "0",
      "tiles": "0",
      "unresolved": "0",
      "ambiguous": "0"
    }
  },
  "chunks": []
}
```

audit_header es el objeto audit_ir completo sin la clave tiles; conserva
source_artifacts, standalone_items, errors, summary e import_run_id. chunks
contiene 0..65535 entradas y esta ordenado por z, chunk_y, chunk_x. Cada
entrada no vacia tiene exactamente:

```json
{
  "address": {"chunk_x": -1, "chunk_y": 0, "z": 7, "chunk_size": 32},
  "logical_path": "assets/importados/v2/chunks/-1_0_7.json",
  "sha256": "4444444444444444444444444444444444444444444444444444444444444444",
  "size_bytes": "1024",
  "tile_count": "1"
}
```

logical_path es relativo, size_bytes es uint64_string y tile_count es
positive_uint64_string. Un publisher no lista chunks vacios.

Cada chunk usa schema `tvp3d.assets.tile_chunk` version `2.0.0`:

```json
{
  "schema": "tvp3d.assets.tile_chunk",
  "version": "2.0.0",
  "source_document_sha256": "3333333333333333333333333333333333333333333333333333333333333333",
  "address": {"chunk_x": -1, "chunk_y": 0, "z": 7, "chunk_size": 32},
  "tiles": []
}
```

tiles conserva ImportedTileRecordV2 completos, ordenados por
source_sequence. Cada posicion debe pertenecer a address segun la formula. No
se permiten posiciones o record_id duplicados entre chunks.

Reconstruccion determinista:

1. validar index, hashes y cada chunk;
2. verificar pertenencia y unicidad;
3. unir tiles y ordenar numericamente por source_sequence;
4. insertar la lista como tiles en audit_header;
5. serializar canonicamente;
6. exigir que el hash sea source_document_sha256.

Una union semanticamente completa pero con hash distinto falla
OUTPUT_NONDETERMINISTIC.

## 12. Serializacion y determinismo

TVP3D Canonical JSON Assets V2 exige:

- UTF-8 sin BOM;
- LF entre lineas y exactamente un LF final;
- indentacion de dos espacios, sin espacios finales;
- campos de schema en el orden publicado en este contrato;
- claves de mapas dinamicos ordenadas por sus bytes UTF-8;
- arrays con orden fuente conservan ese orden; arrays-set usan el comparador
  documentado por su schema;
- enteros en decimal sin `+`, exponentes, ceros iniciales o `-0`;
- uint64 como strings comunes;
- no se usan floats. Un profile futuro que los necesite debe publicar rango,
  precision y normalizacion antes de emitirlos;
- no hay paths absolutos, timestamps, locale, hostname, usuario, PID ni
  separadores dependientes del sistema;
- no hay ids aleatorios; record_id e import_run_id usan la regla sha256
  publicada.

SourceArtifactManifestV2, ImportRunManifestV2, audit_ir 3.0.0,
NormalizedRecordV2, index y chunks deben reproducirse byte a byte con iguales
inputs, hashes, tool/version y profile. Logs humanos no son outputs
publicables y pueden compararse semanticamente solo si su contrato enumera
campos excluidos; nunca participan en hashes de datos normalizados.

## 13. Artefactos legacy 7.72

Se preservan sin regenerarlos en esta fase:

- `cliente3d/assets/items772.json`: lookup legacy por client id;
- `cliente3d/assets/items772_flags.json`: metadata de render/compatibilidad;
- `monster_names772.json` donde exista: lookup legacy de nombres/looktypes;
- metadata extraida de DAT/SPR y capturas de protocolo.

Son `LEGACY_COMPATIBILITY` / `MIGRATION_ARTIFACT`, no registro canonico
V2. Un key client id, looktype, sprite id, server id o filename nunca es
CanonicalDomainId. La migracion futura crea SourceAliasV2 con source_version
y system correctos y lo resuelve mediante un mapping publicado.

Un LOOKTYPE puede aparecer como SourceAliasV2 porque modelo-comun ya lo
permite. En este contrato solo es procedencia. No se define GLB, rig, clip,
material, PBR, Blender, LOD, pivot, escala ni mapping visual.

## 14. Semantica de rutas y ownership

No se crean ni mueven directorios en esta fase:

| Ruta | Semantica reservada |
|---|---|
| `assets/importados/` | source manifests, audit IR y derivados propiedad assets |
| `cliente3d/assets/propios/` | datos/assets curados por assets para consumidores runtime |
| `herramientas/` | importadores y validadores; implementacion futura del carril assets |
| `servidor/data/` | oracle/fuente legacy read-only; nunca output |

Si una ruta fisica no existe, el contrato reserva su semantica sin crear
contenido. No se inventa otra raiz compartida. Cliente/editor/servidor
consumen outputs publicados; no editan fuentes assets.

Ownership:

| Dato | Owner |
|---|---|
| bytes, ids, nombres y flags observados | IMPORT_ONLY |
| aliases y provenance | IMPORT_ONLY |
| mapping explicito a CanonicalDomainId | RESOLVED_DOMAIN, publicado por assets/dominio |
| caches/chunks/catalogos | ASSETS, regenerables |
| caminabilidad, ocupacion y reglas runtime | SERVER |
| visuales futuros | ASSETS/CLIENT_PRESENTATION bajo contrato posterior |

## 15. AssetImportErrorV2

Objeto exacto:

```json
{
  "schema": "tvp3d.assets.import_error",
  "version": "2.0.0",
  "code": "IDENTITY_UNRESOLVED",
  "severity": "WARNING",
  "stage": "IDENTITY_RESOLUTION",
  "artifact_id": "legacy/tvp772/items-otb",
  "record_id": "sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
  "locator": "item/2148",
  "message": "no published mapping",
  "details": {}
}
```

Todos los campos son obligatorios; artifact_id, record_id y locator admiten
null cuando el fallo no tiene ese alcance. severity es `WARNING`, `ERROR` o
`FATAL`; stage es una de las cinco etapas. message mide 0..512 bytes UTF-8,
sin secretos ni paths absolutos. details debe ser el objeto vacio {} en 2.0.0;
el contexto machine-readable vive en los campos anteriores. Un minor futuro
debe publicar el schema de details antes de agregar miembros.

`partial` en la tabla significa que puede conservarse un failure manifest y
los records completos anteriores, siempre marcados result FAILED; no equivale
a audit_ir exitoso ni habilita normalized output.

| Codigo | Severity | Abort scope | Partial audit | Publicacion permitida |
|---|---|---|---|---|
| `SOURCE_PATH_INVALID` | FATAL | whole run | manifest only | ninguna |
| `SOURCE_ARTIFACT_MISSING` | FATAL | whole run | manifest only | ninguna |
| `SOURCE_HASH_MISMATCH` | FATAL | whole run | manifest only | ninguna |
| `SOURCE_FORMAT_UNSUPPORTED` | FATAL | artifact/run | si | failure manifest |
| `SOURCE_TRUNCATED` | FATAL | artifact/run | si | failure manifest |
| `IMPORT_SCHEMA_UNSUPPORTED` | FATAL | consumer read/run | no | ninguna |
| `IMPORT_ATTRIBUTE_UNSUPPORTED` | FATAL | record/run | si | failure manifest |
| `IDENTITY_ALIAS_INVALID` | ERROR | record/resolution | si | audit only |
| `SOURCE_ALIAS_DUPLICATE` | ERROR | record/resolution | si | audit only |
| `IDENTITY_UNRESOLVED` | WARNING | no | si | audit/diagnostic; gate normalized |
| `IDENTITY_AMBIGUOUS` | WARNING | no | si | audit/diagnostic; gate normalized |
| `IDENTITY_MAPPING_CONFLICT` | FATAL | resolution/run | si | ninguna normalized |
| `POSITION_INVALID` | FATAL | record/run | si | failure manifest |
| `CHUNK_INVALID` | FATAL | derived artifact | full IR survives | no index/chunk |
| `DERIVATION_FAILED` | ERROR | derived artifact | full IR survives | no derivado fallido |
| `OUTPUT_NONDETERMINISTIC` | FATAL | whole publication | si | ninguna |
| `OTBM_INVALID_NODE` | FATAL | artifact/run | si | failure manifest |
| `OTBM_UNSUPPORTED_ATTRIBUTE` | FATAL | record/run | si | failure manifest |
| `OTBM_TRUNCATED_ATTRIBUTE` | FATAL | artifact/run | si | failure manifest |

IDENTITY_UNRESOLVED y IDENTITY_AMBIGUOUS preservan el record; nunca crean un
placeholder CanonicalDomainId. Un placeholder solo seria valido bajo una
politica separada y publicada, que no existe en 2.0.0.

`SOURCE_ALIAS_DUPLICATE` conserva exactamente la condicion definida por
modelo-comun 2.0.0; Assets V2 la transporta en su error auditable y no cambia
su significado. Un resolver que exige unicidad para un alias compartido
produce `IDENTITY_AMBIGUOUS` en esta etapa, preservando la causa comun
`SOURCE_ALIAS_AMBIGUOUS`.

## 16. Gates de publicacion

| Clase | Unresolved/ambiguous | Requisitos |
|---|---|---|
| `AUDIT_IR` | permitidos y visibles | fuentes/hash validos, parse completo, resumen/errores coherentes |
| `NORMALIZED_DOMAIN` | prohibidos para ids requeridos por consumidor | RESOLVED, schema propietario, cero fatal/error relevante |
| `CLIENT_DIAGNOSTIC` | permitidos | status visible; placeholder solo de presentacion, sin fake canonical id |
| `DERIVED_CACHE` | segun input/profile | hashes de input, schema/version y reconstruccion declarados |

Un consumidor publica por requirement set explicito. El servidor exige
RESOLVED para toda definicion que trate como dominio. El cliente diagnostico
puede mostrar unresolved sin ocultarlo. El editor puede conservarlo para
curacion pero no exportarlo como NORMALIZED_DOMAIN. Nunca se eliminan records
unresolved para lograr un contador verde.

## 17. Migracion desde Assets 1.4.0

| Campo/artefacto 1.4 | Migracion V2 |
|---|---|
| `server_id` proveniente de OTB/OTBM | SourceAliasV2 system OTB, kind OTB_SERVER_ID |
| `server_id` observado en runtime TVP | SourceAliasV2 system TVP, kind SERVER_ID |
| `client_id` | SourceAliasV2 kind CLIENT_ID con system/source_version reales |
| `looktype` | SourceAliasV2 kind LOOKTYPE; nunca filename |
| `source.file` | SourceArtifactManifestV2 + SourceEvidenceRefV2 |
| `position` | PosicionTibiaV2 exacta |
| root numerico `version: 2` | LEGACY_OTBM_REGION_V2; migracion explicita a audit_ir 3.0.0 |
| keys de `items772.json` | lookup legacy CLIENT_ID, no CanonicalDomainId |
| `walkable` | walkable_historical NORMALIZED_SOURCE/IMPORT_ONLY |
| `queryadd_walkable` | DERIVED_ORACLE/diagnostico |
| `blocking` | observacion normalizada; no autoridad runtime |
| `mapped: false` / `ITEM_ID_UNMAPPED` | IdentityResolutionV2 UNRESOLVED |

count/subtype, atributos tipados, attributes_present, contents recursivos,
flags independientes y orden fuente se copian sin perdida al import record.
El callback, root y catalogos antiguos siguen congelados para consumidores
legacy; no se reinterpretan como V2.

## 18. Fixtures contractuales requeridos

La implementacion futura debe cubrir:

- source manifest valido, path absoluto rechazado, source ausente y SHA
  mismatch;
- round-trip de aliases, alias exacto duplicado rechazado y alias invalido;
- identidad unresolved preservada; ambiguous preservada en audit y rechazada
  por NORMALIZED_DOMAIN;
- dos ids canonicos que comparten LOOKTYPE permitidos cuando la fuente lo
  demuestra; lookup que exige unicidad devuelve AMBIGUOUS;
- item con OTB_SERVER_ID/CLIENT_ID como aliases, client id ausente, count y
  subtype distintos, contents anidados y orden estable;
- atributo desconocido/truncado aborta sin byte skipping;
- tile con PosicionTibiaV2 valida y z invalido rechazado;
- chunk de (-1,0,7) para position (-1,0,7), size 32, local (31,0);
- union de chunks reconstruye hash/records/orden del audit IR;
- inputs/tool/profile iguales producen bytes iguales; cambio de input hash
  cambia import_run_id/provenance;
- legacy root version 2 rechazado por lector audit_ir 3.0.0;
- CLIENT_ID, LOOKTYPE y filename rechazados como CanonicalDomainId;
- walkability diagnostic no puede publicarse como decision SERVER.

Son especificaciones; Phase 1C no implementa ni regenera fixtures.

## 19. Consumidores, relevo y exclusiones

Migraciones contractuales futuras:

- servidor: consumir solo NORMALIZED_DOMAIN resuelto, definir schemas de
  mapa/items y decidir caminabilidad/ocupacion dinamicas;
- cliente: resolver CanonicalDomainId a presentacion, conservar catalogos
  7.72 como fallback diagnostico y nunca confirmar gameplay;
- editor: guardar CanonicalDomainId + aliases/evidencia, mantener fuentes
  read-only y bloquear export autoritativo de unresolved;
- qa: materializar fixtures de hashes, errores, determinismo, chunks,
  resolucion y gates; distinguir oracle TVP de autoridad Godot.

El futuro Monster Domain puede reutilizar SourceArtifactManifestV2,
SourceAliasV2 LOOKTYPE, IdentityResolutionV2 e ImportRunManifestV2 para
trazabilidad de especie. El futuro Monster3D Asset Contract puede reutilizar
manifests, hashes, derived artifacts y gates. Ninguno se publica aqui.

Este contrato no expone credenciales, secretos, rutas privadas, URLs de
proveedor, autoridad de gameplay, almacenamiento de servidor, framing de red,
GLB paths, rigs, clips, PBR, Blender, image-to-3D, LOD, skeletons, pivots,
escalas visuales ni footprint derivado de malla.

## Perfil historico Assets 1.4.0

Estado: SUPERSEDED para exports nuevos por Assets V2 2.0.0.

Esta seccion conserva la semantica, fixtures y errores del IR OTBM anterior.
El root numerico `version: 2` sigue siendo historico y no cambia de significado.

### Esquemas concretos historicos

### Item del IR

```json
{
  "server_id": 123,
  "client_id": 456,
  "name": "",
  "category": "DECORATION",
  "count": 1,
  "subtype": null,
  "attributes": {},
  "mapped": true,
  "flags": {}
}
```

Reglas:

- `server_id` es obligatorio y conserva el id del OTBM; nunca se reemplaza
  por el id de cliente.
- `client_id` puede ser `null` cuando `items.otb` no tiene traduccion.
- `subtype` es el valor exacto de `OTBM_ATTR_COUNT`,
  `OTBM_ATTR_RUNE_CHARGES` o `OTBM_ATTR_CHARGES`; es `null` si el nodo no lo
  serializa.
- `count` es la cantidad efectiva que usa el servidor: `subtype` cuando esta
  presente y `1` cuando el servidor normaliza una cantidad ausente o cero.
- `attributes` contiene nombres estables en `snake_case` y valores JSON
  tipados. Se conservan como minimo `action_id`, `unique_id`, `text`,
  `description`, `teleport_destination`, `depot_id`, `house_door_id`,
  `duration`, `decaying_state`, `written_date`, `written_by`, `sleeper_guid`,
  `sleep_start`, `charges`, `key_number`, `keyhole_number`,
  `door_quest_number`, `door_quest_value`, `door_level` y
  `chest_quest_number` cuando aparecen en el OTBM.
- El parser conserva `attributes_present`, una lista ordenada de ids OTBM
  presentes, para auditar diferencias entre un atributo ausente y su valor
  por defecto.
- `contents` aparece solo en items contenedores y conserva recursivamente los
  items hijos con el mismo esquema.
- `flags.block_pathfind` conserva la propiedad de `ItemType` que hace que el
  servidor levante `TILESTATE_BLOCKPATH`; no se debe confundir con
  `flags.blocking`, que representa `blockSolid`.
- El orden de `items` es el orden del nodo OTBM: suelo primero y objetos de
  abajo hacia arriba.

### Tile del IR

```json
{
  "position": {"x": 32097, "y": 32219, "z": 7},
  "house_id": 0,
  "tile_flags": [],
  "tile_flags_value": 0,
  "ground": {},
  "items": [],
  "walkable": true,
  "queryadd_walkable": true,
  "blocking": false,
  "source": {"file": "servidor/data/world/map.otbm"}
}
```

Reglas:

- Las coordenadas son enteros Tibia y no se convierten en el importador.
- `ground` es el primer item con `flags.ground`; `items` conserva todos los
  items. Un tile puede tener objetos sin suelo y entonces `ground` es `null`.
- `walkable` conserva la derivacion visual basada en `blockSolid` de objetos
  que no son suelo.
- `queryadd_walkable` es la decision estatica derivada de
  `Tile::queryAdd(FLAG_PATHFINDING | FLAG_IGNOREFIELDDAMAGE)`. Es `null` si el
  tile depende de estado dinamico de casa o si falta metadata para modelarlo.
- `house_id` y `tile_flags_value` son la representación sin pérdida de los
  campos del tile que conoce el lector.

### Documento de region

El documento raíz usa `version: 2`, incluye `source.header`, `region` y
`tiles`. La version 1 se considera legible solo por consumidores que migren
`count: 1` y `attributes: {}`; los nuevos exports no deben producirla.

### Indice y chunks de depuracion

Cada export puede publicar un indice junto al JSON completo:

```json
{
  "version": 1,
  "source": {"ir": "cliente3d/generated/maps/rookgaard_100sqm.json"},
  "chunk_size": 32,
  "chunks": {
    "1001_1006_7": {
      "x": 1001, "y": 1006, "z": 7,
      "file": "chunk_1001_1006_7.json"
    }
  }
}
```

Reglas:

- La clave es `floor(x / chunk_size)_floor(y / chunk_size)_z` y conserva el
  piso como tercera coordenada.
- Cada chunk contiene tiles completos del IR, sin cambiar ids, orden,
  atributos, walkability ni coordenadas.
- El JSON completo sigue siendo el artefacto auditable y la referencia para
  comprobar que la union de chunks reproduce todos sus tiles por posicion;
  el orden global se recupera ordenando por `position` si un consumidor lo
  necesita.
- Un lector puede cargar y liberar chunks por ventana; no debe asumir que el
  indice implica que todos los chunks estan residentes.

### Reporte de paridad de walkability

```json
{
  "version": 1,
  "oracle": {"name": "Tile::queryAdd", "mode": "player_pathfinding_static"},
  "summary": {"compared_tiles": 0, "matches": 0, "mismatches": 0},
  "mismatches": []
}
```

Reglas:

- La oracle reproduce solo la parte estatica de `Tile::queryAdd` para un
  jugador con `FLAG_PATHFINDING`; no inventa criaturas, PZ locks ni permisos
  de casa.
- Se excluyen del conteo de paridad los tiles con `house_id` distinto de cero,
  porque su resultado depende de la autoridad y del jugador conectado.
- La oracle exige ground, rechaza `block_pathfind`, floor changes y
  teleports. El reporte conserva la razon de cada mismatch.
- El reporte sigue siendo diagnostico: valida `queryadd_walkable` y no cambia
  automaticamente el significado historico de `walkable`.

### Errores historicos

| Codigo | Cuando ocurre | Que hace quien llama |
|---|---|---|
| `OTBM_INVALID_NODE` | Marcadores, nodos o cierres no coinciden | Abortar la importacion y mostrar posicion si existe |
| `OTBM_UNSUPPORTED_ATTRIBUTE` | Un atributo de item no tiene tipo conocido | Abortar; no saltar bytes ni inventar un valor |
| `OTBM_TRUNCATED_ATTRIBUTE` | Faltan bytes para el tipo declarado | Abortar la importacion |
| `ITEM_ID_UNMAPPED` | El id de servidor no tiene id de cliente o sprite | Mantener el item y marcar `mapped: false`; reportarlo |
| `IR_SCHEMA_VERSION` | Un consumidor recibe una version no soportada | Rechazar con la version recibida |

### El perfil historico no expone

- Credenciales, sesiones, contrasenas o datos de conexion.
- El parser no modifica `servidor/data/`; las fuentes son de solo lectura.
- Los valores de autoridad, walkability dinamica y estado vivo del servidor.

### Consumidores historicos

- Cliente 3D y visor de validacion.
- Editor de mapas.
- Pruebas de paridad y reportes de conversion.

### Catalogo legacy de protocolo 7.72

`python herramientas/extraer_items772.py` genera
`cliente3d/assets/items772.json`, indexado por el `client id` que
`NetworkMessage::addItem` envia por red. Los nombres salen de
`servidor/data/items/items.xml`; las banderas y el cruce server/client id,
de `items.otb`.

La generacion debe auditar todos los roots `corpse` declarados por monstruos,
los corpses de jugador de `servidor/src/const.h` y cada transformacion
`decayto` alcanzable. Si una etapa no tiene entrada OTB, client id exportado o
nombre resoluble, el comando falla y no publica silenciosamente un catalogo
incompleto. Cuando varios server ids comparten client id, un nombre vacio no
puede tapar otro nombre real del XML para el mismo sprite.

`cliente3d/assets/items772_flags.json` es un artefacto de render separado y no
es salida de `extraer_items772.py`; esta auditoria no cambia su formato.

### Compatibilidad y versionado historicos

Agregar un atributo normalizado es compatible. Cambiar el significado de un
campo o eliminarlo exige subir la version del IR. El callback antiguo de
`leer_otbm.recorrer` sigue entregando solo ids y flags; el callback detallado
es opt-in para no romper extractores existentes.
