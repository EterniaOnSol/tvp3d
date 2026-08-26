# TVP3D - Architecture

## Arquitectura elegida

Se conserva TVP como servidor autoritativo y Godot como cliente 3D. El
protocolo de juego actual ya acepta exactamente 7.72 y el cliente existente ya
resuelve RSA, XTEA, login, mapa de ventana y movimiento.

```text
TVP C++ / Lua / MariaDB
        |
        | protocolo 7.72: login, mapa vivo, criaturas, items, acciones
        v
cliente3d/red/conexion772.gd
        |
        +--> estado_mundo.gd       estado vivo confirmado
        +--> mapa772.gd             decodificacion de paquetes
        +--> mapa_disco.gd          decorado OTBM por chunks
        v
cliente 3D Godot
        |
        +--> coordenadas_tibia.gd  transformacion reversible
        +--> perfil de item         geometria/material/colision
        +--> renderer por chunks    MultiMesh, culling, streaming
```

## Separacion de responsabilidades

TVP decide movimiento, combate, items, criaturas, Lua, casas, spawns,
persistencia y reglas. Godot decide input, camara, interpolacion visual,
render, audio, UI y diagnostico. La interpolacion nunca modifica la posicion
confirmada.

El mapa del disco representa decoracion estatica de la version de OTBM que
esta usando el servidor. Los paquetes TVP representan cambios en vivo. Un
objeto dinamico o item mutable tiene prioridad sobre el cache del disco.

## Integracion segura

La primera integracion usa el cliente TVP existente. Las nuevas capas entran
por adaptadores y no cambian `servidor/src` hasta que una prueba demuestre que
falta un dato del protocolo. Cualquier nuevo opcode debe ser un ADR y una
extension compatible, no una sustitucion silenciosa.

## Coordenadas

La posicion logica es `Vector3i(x, y, z)` de Tibia. El mundo usa un ancla por
escena/chunk y constantes centrales `SQM_WORLD_SIZE` y
`FLOOR_WORLD_HEIGHT`. Nunca se escriben coordenadas absolutas directamente en
la geometria del cliente.
