# TVP3D - Map Pipeline

## Estado actual

```text
map.otbm + items.otb
        -> leer_otbm.py
        -> extraer_mapa772.py
        -> mapa.bin + mapa.json (chunks 64x64, ids de cliente)
        -> mapa_disco.gd
        -> mundo3d.gd
```

Es un buen camino de lectura rapida, pero no es suficiente como fuente de
trazabilidad porque descarta flags y ids no traducidos.

La ruta de auditoria ya esta implementada en
`herramientas/tibia3d_map.py`. Lee el mismo `map.otbm`, conserva los ids de
servidor, flags de tile y `house_id`, y escribe un IR JSON versionado. La
region de prueba actual es `rookgaard_100sqm`, con 20240 tiles y 25272 items.
El cache binario sigue siendo la ruta de render rapido del cliente conectado;
no se usa como fuente de verdad para flags o atributos.

## Intermedio objetivo

Cada tile debe poder reconstruirse con un registro versionado equivalente a:

```json
{
  "pos": {"x": 32369, "y": 32241, "z": 7},
  "house_id": 0,
  "tile_flags": ["PROTECTION_ZONE"],
  "ground": {"server_id": 452, "client_id": 1024},
  "items": [
    {"server_id": 123, "client_id": 456, "count": 1, "subtype": null,
     "attributes": {}, "attributes_present": [],
     "flags": {"block_pathfind": false}}
  ],
  "source": {"file": "map.otbm", "node": "tile-area:..."}
}
```

El IR conserva ids servidor y cliente. Si un id no tiene traduccion, se
mantiene como `unknown` y se agrega a `generated/unmapped_items.json`; nunca
se elimina silenciosamente.

## Conversor por fases

1. Parsear OTBM con las mismas constantes de `iomap.h`.
2. Leer `items.otb` y resolver ids sin perder colisiones.
3. Emitir IR particionado espacialmente por chunks, con indice de archivos.
4. Emitir un reporte de ids no traducidos y atributos ignorados.
5. Aplicar perfiles de item para seleccionar geometria 3D.
6. Resolver conexiones de vecinos para bordes, muros, agua y rampas.
7. Generar chunks visuales y colision logica de diagnostico.

## Regla de coordenadas

El chunk solo organiza almacenamiento. No cambia `x`, `y` ni `z`. La clave de
chunk y la posicion local se calculan y se prueban de forma reversible.

## Validacion

- Conteo de areas, tiles e items contra un recorrido independiente.
- Round-trip de una muestra IR -> posicion -> chunk -> posicion.
- Comparacion de walkability contra `Tile::queryAdd`/`Map::getTile` cuando el
  servidor esta disponible.
- Reporte estatico reproducible contra `Tile::queryAdd(FLAG_PATHFINDING)`;
  distingue `blockSolid` visual de `blockPathFind` de movimiento.
- Reporte no vacio para todo item que carezca de perfil.

## IR v2

El exportador conserva `count`, `subtype`, `attributes` y
`attributes_present` de cada nodo `OTBM_ITEM`. Se leen los tipos de
`iomap.h` para cantidades, action/unique id, textos, destinos, puertas,
duracion, llaves, quests y atributos de cama. Los items anidados de
contenedores se conservan en `contents`.

`OTBM_ATTR_ITEM` inline sigue siendo solo un id, tal como lo lee
`IOMap::parseTileArea`; por eso se exporta con `count=1`, `subtype=null` y sin
atributos. El callback antiguo de `leer_otbm.recorrer` mantiene su contrato de
ids/flags y el callback detallado es opt-in.

## Streaming del IR de depuracion

`herramientas/tibia3d_map.py export-region` conserva el JSON completo y genera
ademas `generated/maps/<region>_chunks/index.json` con archivos espaciales de
32x32 por piso. `cliente3d/red/ir_trozos.gd` carga el indice, abre solo los
chunks de una ventana y libera los que quedan fuera; el visor de validacion ya
usa esta ruta y cargo 39 chunks para reconstruir los 20.240 tiles de
`rookgaard_100sqm`.

La particion es reversible: los chunks contienen los registros completos y su
union debe coincidir por posicion con el JSON auditable, no con una version
reducida de render.

## Paridad de walkability

`herramientas/comparar_walkability.py` compara el `walkable` historico del IR
con una oracle estatica de `Tile::queryAdd` para jugador y pathfinding. En la
region `rookgaard_100sqm` se compararon 20.240 tiles: 17.014 coincidencias,
3.226 diferencias (84,06%), 3.161 conservadoras y 65 permisivas.

La diferencia principal es que el IR historico usa `blockSolid` de objetos
decorativos, mientras que `Tile::queryAdd` usa `blockPathFind`, floor changes
y teleports. El resultado queda en
`cliente3d/generated/reports/walkability_parity.json`. El exportador ahora
incluye `queryadd_walkable` como campo adicional: en la muestra los 20.240
valores modelables coinciden con la oracle. El campo historico `walkable` se
mantiene para no cambiar comportamiento del cliente sin una decision de
dominio.
