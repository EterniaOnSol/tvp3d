# TVP3D Map Editor

El editor visual vive en `cliente3d/editor/editor3d.tscn`. No modifica el
OTBM ni el servidor: lee `assets/mapa772` y guarda solamente reglas visuales
en `cliente3d/assets/mappings/items.json`.

## Abrir

Desde la raiz:

```text
ABRIR MAP EDITOR.bat
```

Tambien se puede abrir con Godot:

```text
Godot.exe --path cliente3d editor/editor3d.tscn
```

## Flujo

1. Escribe `X`, `Y`, `Z` y pulsa `Cargar`.
2. Haz click sobre un SQM del mapa real.
3. Elige el ground o item del stack.
4. Revisa el sprite original y selecciona `Auto`, `Suelo horizontal`,
   `Sprite vertical`, `Pared` o `Caja`.
5. Ajusta alto y grosor cuando la representacion sea una pared.
6. Pulsa `Guardar mapping` y luego `Aplicar` para reconstruir la region.

El mapping se aplica por `itemId`, por lo que una regla resuelve todas las
ocurrencias del item. Las excepciones por SQM se agregaran en una etapa
posterior; no se deben editar miles de casillas manualmente.

## Estado actual

- Carga el mapa binario real por chunks.
- Conserva y muestra la coordenada Tibia del tile seleccionado.
- Muestra el sprite 2D extraido de DAT/SPR.
- Genera preview 3D con primitivas y reglas de adyacencia simples.
- Guarda mappings JSON sin recompilar el cliente.
- Todavia faltan modelos GLB/OBJ, perfiles de esquina y overrides por tile.
