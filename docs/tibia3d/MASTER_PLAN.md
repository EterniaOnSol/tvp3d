# TVP3D - Master Plan

## Mision

Convertir el mundo clasico Tibia 7.4-7.7 a una representacion 3D jugable,
conservando las coordenadas SQM, reglas, mapa, criaturas, items y autoridad
del servidor TVP. El mapa original es la fuente de verdad; la escena 3D es una
proyeccion determinista y trazable.

## Alcance tecnico

- Servidor: `servidor/`, fork TVP basado en TFS, protocolo 7.72.
- Cliente: `cliente3d/`, Godot 4.7 y GDScript.
- Datos: `servidor/data/world/map.otbm`, `items.otb`, `items.xml`,
  `cliente3d/assets/cliente772/Tibia.dat` y `Tibia.spr`.
- Herramientas: `herramientas/` para analizar, traducir y empaquetar datos.
- Persistencia y reglas: permanecen en TVP salvo un adaptador documentado.

## Orden de construccion

1. Auditar y congelar contratos de coordenadas, items y red.
2. Validar el parser OTBM contra el servidor y conservar flags/atributos.
3. Introducir la conversion reversible Tibia <-> mundo 3D.
4. Generar un IR de mapa con ids, flags, casas, niveles y trazabilidad.
5. Convertir un area real de 50x50 o 100x100 SQM a chunks 3D.
6. Mostrar el area con modelos proxy y placeholders visibles para todo item no
   mapeado.
7. Sincronizar criaturas y movimiento usando el protocolo TVP 7.72.
8. Agregar pisos, escaleras, puertas, interaccion, combate y UI por fases.
9. Reemplazar proxies con perfiles 3D y reglas de adyacencia desde el editor.

## Criterio de primer exito

El cliente Godot se conecta a TVP, carga automaticamente un area real del
OTBM, muestra la posicion Tibia en 3D, mueve el personaje SQM por SQM,
conserva bloqueos y cambia de piso sin deriva de coordenadas.

## No hacer al inicio

- Reescribir `servidor/src` sin una falla demostrada.
- Crear un segundo servidor que duplique las reglas de TVP.
- Convertir manualmente ciudades o miles de items.
- Ocultar items no mapeados.
- Optimizar draw calls antes de medir chunks reales.
