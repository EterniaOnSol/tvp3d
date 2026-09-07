# Escalas de monstruos

La unidad es una casilla. La extension es el maximo ancho/largo de todas las
poses, incluyendo patas, cola y mandibulas. Los objetivos son artisticos,
editables en escalas.json; no representan medidas oficiales ni colisiones.

| Apariencia | ID | Extension anterior | Extension actual | Alto actual |
|---|---:|---:|---:|---:|
| Panda | 123 | 1.25 | 1.45 | 0.88 |
| Bear | 16 | 1.65 | 1.65 | 0.92 |
| The Old Widow | 208 | 1.78 | 1.85 | 0.60 |
| Rat | 21 | 1.17 | 0.48 | 0.16 |
| Tarantula | 219 | 1.34 | 1.35 | 0.46 |
| Rotworm | 26 | 0.77 | 0.80 | 0.61 |
| Wolf | 27 | 0.84 | 1.12 | 0.58 |
| Snake | 28 | 0.83 | 0.78 | 0.05 |
| War Wolf | 3 | 1.65 | 1.70 | 0.88 |
| Spider | 30 | 0.75 | 0.55 | 0.18 |
| Dragon | 34 | 2.31 | 2.65 | 1.55 |
| Poison Spider | 36 | 0.90 | 0.65 | 0.21 |
| Giant Spider | 38 | 1.78 | 1.85 | 0.60 |
| Dragon Lord | 39 | 2.31 | 2.85 | 1.66 |
| Polar Bear | 42 | 1.85 | 1.85 | 0.92 |
| Winter Wolf | 52 | 0.84 | 1.12 | 0.58 |
| Cave Rat | 56 | 1.17 | 0.52 | 0.18 |
| Ancient Scarab | 79 | 1.52 | 1.75 | 0.48 |
| Cobra | 81 | 0.85 | 0.95 | 0.50 |
| Larva | 82 | 0.83 | 0.65 | 0.19 |
| Scarab | 83 | 0.83 | 0.85 | 0.29 |
| Scorpion | 43 | nuevo | 1.10 | 0.62 |
| Bug | 45 | nuevo | 0.42 | 0.21 |
| Centipede | 124 | nuevo | 1.30 | 0.14 |
| Black Sheep | 13 | nuevo | 0.95 | 0.71 |
| Sheep | 14 | nuevo | 0.95 | 0.71 |
| Pig | 60 | nuevo | 1.00 | 0.50 |
| Deer | 31 | nuevo | 1.50 | 1.78 |
| Rabbit / The Halloween Hare | 74 | nuevo | 0.55 | 0.46 |
| Dog | 32 | nuevo | 0.85 | 0.44 |
| Hyaena | 94 | nuevo | 1.20 | 0.69 |
| Skeleton | 33 | nuevo | 0.70 | 1.58 |
| Demon Skeleton | 37 | nuevo | 0.82 | 1.85 |
| Troll | 15 | nuevo | 0.90 | 1.35 |
| Frost Troll | 53 | nuevo | 1.00 | 1.57 |
| Swamp Troll | 76 | nuevo | 0.94 | 1.26 |

Regenerar las apariencias modificadas con `python generar.py --ids ID ...`.
Un factor uniforme preserva las proporciones y se aplica a todas las poses.
La prueba Python audita los 36 objetivos y Godot mide las mallas cargadas.

Comparar en el visor: `--comparar`; solo escarabajos: `--comparar --grupo 83,79`.
El modo Detalle ajusta el zoom por modelo, por lo que no sirve para comparar
el porte de dos especies en capturas separadas.
