# TVP3D - Item Mapping

## Fuentes reales

- `servidor/data/items/items.otb`: id servidor, grupo y flags de runtime.
- `servidor/data/items/items.xml`: nombres y rangos de items.
- `cliente3d/assets/cliente772/Tibia.dat`: geometria 2D, capas, direcciones,
  animacion, elevacion, luz y displacement.
- `cliente3d/assets/cliente772/Tibia.spr`: pixeles fuente.
- `cliente3d/assets/items772.json`: salida actual traducida por id cliente.
- `cliente3d/assets/sprites772/indice.json`: laminas y regiones de sprites.

## Metadatos que ya se extraen

`extraer_items772.py` conserva grupo, apilable, liquido, suelo, container,
bloqueo solido, bloqueo de proyectil, altura, transparencia, pickup, movable,
always-on-top, orden y velocidad de suelo. `leer_dat_spr.py` conserva ancho,
alto, capas, direcciones, fases, atributos, elevacion, luz y displacement.

## Perfil 3D objetivo

```json
{
  "item_id": 1234,
  "category": "wall",
  "visual": {"model": "proxy_box", "material": "sprite_atlas"},
  "transform": {"scale": [1, 1, 1], "offset": [0, 0, 0], "rotation": "adjacent"},
  "collision": {"gameplay": "server", "visual": "solid"},
  "animation": {"type": "none", "frames": 1},
  "connection_rule": "wall_4way",
  "source": {"server_id": 1234, "client_id": 2345}
}
```

La clasificacion automatica es una sugerencia. Los casos ambiguos quedan en
un reporte y usan placeholder visible, no una omision.

## Clasificacion inicial

`ground`, `border`, `wall`, `door`, `window`, `roof`, `mountain`, `vegetation`,
`furniture`, `container`, `decoration`, `field`, `stairs`, `ladder`, `unknown`.

La categoria no reemplaza las flags del servidor. Una puerta cerrada puede ser
visual `door` y gameplay `blocking`; la abierta debe conservar el id y estado
actual que envia el servidor.

## Reglas de seguridad del mapping

- Un id desconocido se renderiza como magenta y se reporta.
- No se modifica `items.otb`, `Tibia.dat` ni `Tibia.spr`.
- El mapping es editable sin recompilar el servidor.
- El id logico siempre se conserva junto al modelo elegido.
