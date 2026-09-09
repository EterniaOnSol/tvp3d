# TVP3D - Repository Audit (historical snapshot)

Fecha de auditoria: 2026-08-25.

Estado documental: HISTORICAL. Conserva lo observado antes de Architecture V2.
Las referencias a autoridad describen el runtime de aquella fecha y quedan
SUPERSEDED por `ARCHITECTURE.md` y D-007.

## Estructura real

| Ruta | Evidencia | Funcion |
|---|---|---|
| `servidor/src/` | 151 archivos C++ | Runtime TVP/TFS: map, tiles, items, criaturas, game, Lua, red |
| `servidor/data/` | 1371 archivos | OTBM, OTB, scripts Lua, monsters, spells, houses y spawns |
| `cliente3d/` | 55 archivos listados | Cliente Godot, parser 7.72, render 3D y pruebas |
| `herramientas/` | scripts Python | lectores OTBM, OTB, DAT/SPR y extractores |

## Servidor

- `src/definitions.h` fija `CLIENT_VERSION_MIN/MAX = 772`.
- `Game::loadMainMap` llama a `Map::loadMap`, que intenta el cache
  `gamedata/map.tvpm` y, si no aplica, `IOMap::loadMap` sobre el OTBM.
- `Map::loadMap` carga tambien spawns, houses, house items y propietarios.
- `IOMap` conoce nodos OTBM, atributos de tile, towns y waypoints.
- `Map` almacena tiles en un quadtree por coordenadas y 16 pisos; implementa
  busqueda A* y consulta de tiles.
- `Tile` separa ground, items top/down, criaturas, casa y flags; tambien
  expone propiedades de bloqueo, altura, puertas, campos, teleport y containers.
- `ItemType` viene de `items.otb` y sus propiedades alimentan `Tile::queryAdd`,
  movimiento, pathfinding y serializacion.
- LuaJIT/Lua es parte del runtime y los scripts de `servidor/data/` son parte
  del comportamiento, por lo que no se duplican en el cliente.

## Red

- `ProtocolGame::onRecvFirstMessage` descifra RSA, configura XTEA y autentica
  cuenta/personaje.
- `parsePacketOnDispatcher` acepta movimiento 0x65-0x68, diagonales,
  containers, items, combate, chat, outfit y extended opcode.
- `sendMapDescription` envia 18x14 casillas: `maxClientViewportX=8` y
  `maxClientViewportY=6`.
- `GetMapDescription` usa pisos 7..0 en superficie o pisos cercanos bajo
  tierra, y el contador de vacios empieza en -1.
- `sendMoveCreature` transmite movimiento, franjas nuevas o cambio de piso.
- El cliente ya tiene `conexion772.gd`, `estado_mundo.gd` y `mapa772.gd` para
  este contrato.

## Pipeline existente

- `herramientas/leer_otbm.py` recorre OTBM y extrae ids de servidor por tile.
- `extraer_items772.py` traduce ids servidor a cliente y conserva flags de
  protocolo, incluyendo apilables y liquidos.
- `extraer_mapa772.py` produce `cliente3d/assets/mapa772/mapa.bin` en chunks
  64x64 y `mapa.json`; el binario actual mide aproximadamente 47.9 MB.
- `extraer_sprites772.py` lee `Tibia.dat/.spr` y crea laminas e indice para
  items y outfits.
- `cliente3d/red/mapa_disco.gd` carga chunks bajo demanda.
- `cliente3d/mundo3d.gd` agrupa items por dibujo/forma con MultiMesh y usa
  cajas para bloqueos y laminas cruzadas para decoracion.

## Riesgos encontrados

1. El formato actual del mapa descarta flags de tile, casas y cualquier item
   cuyo id no se pueda traducir; eso impide trazabilidad completa.
2. El mapa binario conserva ids de cliente, pero no un IR explicito de reglas
   3D, elevacion, conexiones o item desconocido.
3. `mundo3d.gd` usa escala y altura en su propio script; falta una capa unica
   de coordenadas.
4. La visualizacion estatica y el estado vivo se combinan correctamente para
   el prototipo, pero aun no existe invalidacion por item mutable con version
   de mapa.
5. No se encontro un editor 3D de produccion; el editor inicial actual es
   prototipo y debe integrarse con el IR.

## Zonas que no se tocaban inicialmente

`servidor/src/protocolgame.cpp`, `game.cpp`, `map.cpp`, `tile.cpp`, Lua y
`servidor/data/` quedaron como autoridad de la primera vertical slice. En V2
se conservan como oracle de solo lectura y referencia de migracion. La nueva
autoridad se implementa en el dominio servidor Godot despues de contratos y
fixtures de paridad.
