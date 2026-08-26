# Contrato: editor

Estado: PUBLICADO
Version: 1.0.0
Carril: editor

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
