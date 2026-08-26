# TVP3D Map Editor

El editor visual vive en `cliente3d/editor/editor3d.tscn`. No modifica el
OTBM ni el servidor: lee el mapa importado y guarda autoria propia en dos
capas:

- mappings por `itemId` en `cliente3d/assets/mappings/items.json`;
- proyectos versionados `tvp3d.project.v1` en `cliente3d/assets/proyectos/`.

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

Para editar una celda concreta:

1. Selecciona el SQM en el mapa.
2. Elige `Suelo`, `Pared`, `Agua`, `Arbol`, `Roca`, `Decoracion` o `Escalera`.
3. Pulsa `Aplicar tile`.
4. Usa `Guardar` para persistir el proyecto, o `Exportar` para escribir una
   copia normalizada.

`Nuevo`, `Abrir`, `Deshacer` y `Rehacer` operan sobre el proyecto editable. La
ruta se puede escribir en el campo superior; por defecto es
`res://assets/proyectos/rookgaard_editable.tvp3d.json`.

El mapping se aplica por `itemId`, por lo que una regla resuelve todas las
ocurrencias del item. Las excepciones por SQM se guardan como lista dispersa,
por lo que no se duplica el mapa completo ni se editan miles de casillas sin
cambios.

## Estado actual

- Carga el mapa binario real por chunks.
- Conserva y muestra la coordenada Tibia del tile seleccionado.
- Muestra el sprite 2D extraido de DAT/SPR.
- Genera preview 3D con primitivas y reglas de adyacencia simples.
- Guarda mappings JSON sin recompilar el cliente.
- Guarda y valida proyectos versionados con overrides por tile.
- Permite deshacer/rehacer y muestra los overrides como volumenes coloreados.
- Todavia faltan modelos GLB/OBJ y perfiles de esquina.

El contrato completo del archivo esta en
`worklog/editor/CONTRATO.md`. Las pruebas headless del modelo y de la escena
se ejecutan con `proyecto_self_test.gd` y el argumento `--self-test`.
