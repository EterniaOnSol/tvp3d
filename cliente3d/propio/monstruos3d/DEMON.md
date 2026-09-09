# Demon reutilizado de 3DTIBIA

Activo desde contrato cliente 1.29.0. Reemplaza el prototipo procedural
rechazado por el usuario. Se conserva la malla, UV y textura original.

## Archivos

- `demon_3dtibia/editable/original.glb`: copia exacta e inmutable de 3DTIBIA.
- `demon_3dtibia/editable/demon_animado.blend`: esqueleto editable de 22 huesos.
- `demon_3dtibia/editable/demon_animado.glb`: skin y clips Reposo/Caminar.
- `demon_3dtibia/color.jpg`: JPEG 2048x2048 extraido byte a byte del original.
- `mallas/outfit_0035_texturado.tvol`: base y 24 poses, UV e indices, TVPVOL02.
- `demon_3dtibia/informe.json`: hashes, limpieza, escala y dimensiones.
- `demon_3dtibia/preview.png`, `reposo.gif`, `caminar.gif`, `ciclo_caminata.png`:
  capturas del renderer real de Godot.

La carpeta editable tiene `.gdignore` para evitar importaciones de Blender
innecesarias; esos archivos no se necesitan para ejecutar el cliente.
Los antiguos demon.py, outfit_0035.tvol y demon_*.png quedan como referencia
historica del prototipo, sin registrarse ni cargarse en el runtime vigente.

## Movimiento

Reposo dura 2 segundos (respiracion, cabeza y cola); caminar dura 1 segundo
(apoyo alternado, brazos, torso y cola). Cada clip tiene 12 muestras; Godot
interpola en GPU y cruza entre clips en 0.18 segundos. El archivo Blender
conserva los fotogramas completos a 24 fps y el GLB contiene ambos clips.

La malla animada se comparte, pero sus pesos son individuales por criatura.
No hay root motion. El renderer detecta cambios de posicion confirmada y
mantiene caminar durante 0.45 segundos desde el ultimo paso; al terminar
vuelve a reposo. Teletransportes y cambios de piso no disparan caminata.
Es una ventana visual, no una prediccion de movimiento ni una regla de juego.

El visor permite elegir Caminar/Reposo, pausar, girar y comparar. El picking
y el culling usan el AABB combinado de todas las poses. Se limpian los pesos
y el estado temporal al cambiar apariencia o volver desde un billboard.

## Fidelidad y limites

Se retiraron cinco islas de roca (419 vertices, 260 triangulos). El componente
principal se conserva, incluidos sus detalles y pequenas imperfecciones
originales junto a las garras; no se recortaron pies por altura/color.
Quedan 24544 triangulos y 27592 vertices UV. La huella artistica maxima es
2.0 casillas; altura 1.790 con torso erguido y brazos relajados.
Se conservan los muslos y piernas originales: el usuario descarto afinarlos.
La cola conserva pesos hasta la punta y oscila desde su raiz sin retorcerse.
El skinning se calcula con Bone Heat sobre una copia con costuras soldadas,
y se transfiere a la malla original sin alterar sus UV. Esto evita que la
mandibula arrastre el muslo al erguirlo. Cuatro influencias normalizadas por
vertice y rodillas sin torsion longitudinal mantienen coherentes GLB y poses.
El banco ocupa 17070484 bytes y se carga una vez por catalogo.

Validado en renderer real y mediante estado sintetico; falta partida viva
con servidor, revision artistica del usuario y benchmark de muchas criaturas.
Los clips son reposo y caminar; ataque/muerte no forman parte de esta entrega.
Exportacion empaquetada del cliente pendiente: incluir TVPVOL02 y JPEG como
archivos de runtime, igual que las demas mallas de carga directa.

## Reproducir

Desde raiz TVP3D:

```text
blender --background --python cliente3d/propio/monstruos3d/preparar_demon.py
python cliente3d/propio/monstruos3d/self_test_anatomia.py
godot --headless --path cliente3d --script res://propio/monstruos3d/self_test.gd
godot --headless --path cliente3d --script res://propio/monstruos3d/self_test_demon.gd
godot --headless --path cliente3d --script res://propio/monstruos3d/visor.gd -- --self-test
godot --path cliente3d --script res://propio/monstruos3d/visor.gd -- --tipo 35
```

`generar.py --ids 35` conserva el modelo importado y remite al script Blender.
No vuelve a generar el prototipo procedural ni modifica los demas monsters.
