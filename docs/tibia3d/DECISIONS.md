# TVP3D - Decisions

## D-001: TVP permanece como servidor

Estado: aceptada.

TVP ya posee mapa, tiles, pathfinding, combate, Lua, casas, spawns,
persistencia y protocolo 7.72. Reescribirlo ahora duplicaria reglas y
romperia compatibilidad. Godot se integra como cliente 3D.

## D-002: OTBM es la fuente del decorado estatico

Estado: aceptada.

El servidor solo envia 18x14 alrededor del jugador. El mundo lejano se genera
desde el mismo OTBM y se invalida cuando el servidor envia cambios vivos.

## D-003: Coordenadas absolutas no entran directamente al renderer

Estado: aceptada.

Se agrega una capa Tibia <-> mundo 3D con ancla, SQM_WORLD_SIZE y
FLOOR_WORLD_HEIGHT. Es reversible y evita overflow conceptual, deriva y
magic numbers repartidos.

## D-004: Primera visualizacion con proxies

Estado: aceptada.

La geometria proxy permite validar topologia y gameplay antes de crear modelos
finales. Items no mapeados se ven como placeholder y se reportan.

## D-005: IR conserva ids y atributos originales

Estado: aceptada.

El binario actual es util para streaming, pero se ampliara con un intermedio
versionado para recuperar por que cada objeto fue convertido.

## D-006: No tocar TVP core en la primera fase

Estado: aceptada.

Los cambios empiezan en herramientas, cliente y pruebas. Cualquier dato que
falte se demuestra con un fixture y se propone como adaptador/extended opcode.
