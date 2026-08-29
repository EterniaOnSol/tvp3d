# Contrato: assets

Version: 1.4.0
Estado: PUBLICADO
Propietario: assets
Depende de: ninguno

## Proposito

Convertir fuentes de Tibia 7.72 (`map.otbm`, `items.otb` y el indice de
sprites) en un IR JSON reproducible, sin perder la identidad del servidor ni
los atributos persistentes que el servidor lee del OTBM.

## Esquemas concretos

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

## Errores

| Codigo | Cuando ocurre | Que hace quien llama |
|---|---|---|
| `OTBM_INVALID_NODE` | Marcadores, nodos o cierres no coinciden | Abortar la importacion y mostrar posicion si existe |
| `OTBM_UNSUPPORTED_ATTRIBUTE` | Un atributo de item no tiene tipo conocido | Abortar; no saltar bytes ni inventar un valor |
| `OTBM_TRUNCATED_ATTRIBUTE` | Faltan bytes para el tipo declarado | Abortar la importacion |
| `ITEM_ID_UNMAPPED` | El id de servidor no tiene id de cliente o sprite | Mantener el item y marcar `mapped: false`; reportarlo |
| `IR_SCHEMA_VERSION` | Un consumidor recibe una version no soportada | Rechazar con la version recibida |

## No expone

- Credenciales, sesiones, contrasenas o datos de conexion.
- El parser no modifica `servidor/data/`; las fuentes son de solo lectura.
- Los valores de autoridad, walkability dinamica y estado vivo del servidor.

## Consumidores

- Cliente 3D y visor de validacion.
- Editor de mapas.
- Pruebas de paridad y reportes de conversion.

## Catalogo de protocolo 7.72

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

## Compatibilidad y versionado

Agregar un atributo normalizado es compatible. Cambiar el significado de un
campo o eliminarlo exige subir la version del IR. El callback antiguo de
`leer_otbm.recorrer` sigue entregando solo ids y flags; el callback detallado
es opt-in para no romper extractores existentes.
