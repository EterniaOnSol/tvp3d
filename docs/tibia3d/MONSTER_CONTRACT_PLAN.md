# TVP3D - Monster Contract Plan

Estado: PROPUESTA DE PHASE 0; NO ES UN CONTRATO PUBLICADO

Este documento define el alcance de los dos contratos que deben existir antes
de implementar un Monster3D nuevo. No congela esquemas, no habilita produccion
de assets y no autoriza el Cyclops vertical slice.

## Orden y dependencia

```text
Monster Domain Contract
        |
        | semantic identity/state vocabulary
        v
versioned protocol + client Monster Registry
        ^
        | visual realization only
Monster3D Asset Contract
```

El contrato de dominio se publica primero. El contrato visual consume su
identidad y vocabulario semantico, pero no puede ampliar gameplay. Ambos deben
declarar version, compatibilidad, errores, consumidores y fixtures de
validacion.

## A. Monster Domain Contract

Propietario propuesto: `modelo-comun`, con consumidores `servidor`,
`protocolo-red`, `cliente` y `qa`.

Debe definir:

- **Stable monster identity:** id estable de especie/archetype separado del id
  de instancia de sesion; aliases de las fuentes Tibia/TVP con procedencia.
- **Tibia looktype:** valor de compatibilidad/importacion, su rango y la regla
  para un looktype desconocido; no debe usarse como nombre de archivo GLB.
- **Logical footprint:** tiles ocupados, ancla/origen logico y reglas para
  footprints mayores que un SQM. Es dato autoritativo, no AABB visual.
- **Position and direction:** posicion Tibia, facing cerrado y reglas de cambio
  confirmadas por el servidor.
- **Semantic states:** vocabulario cerrado inicial, por ejemplo `idle`,
  `moving`, `attacking`, `hit`, `dying` y `dead`, con transiciones,
  prioridad e idempotencia. Los nombres finales deben validarse en Phase 5.
- **Server-authoritative movement/state:** comandos aceptados, eventos
  emitidos, timestamps/ticks si aplican, spawn/despawn y rechazo de estados
  inventados por el cliente.
- **Animation semantic vocabulary:** significado de cada estado que el cliente
  puede representar, sin fps, huesos, clips ni detalles de rig.
- **Species vs instance data:** stats/reglas base separados de HP, target,
  condiciones y estado vivo de una instancia.
- **Versioning and errors:** version de schema/protocolo, compatibilidad,
  identidad desconocida, estado invalido y payload fuera de rango.

Debe excluir explicitamente:

- rutas de GLB, materiales, texturas, skeletons y LODs;
- Blender o cualquier proveedor image-to-3D;
- colision derivada de mallas;
- decisiones visuales sobre escala, silhouette o calidad.

Fixtures propuestos:

- round-trip de identidad/looktype;
- footprint de uno y varios SQM;
- las cuatro direcciones;
- tabla completa de transiciones semanticas validas e invalidas;
- spawn, movimiento, cambio de estado y despawn confirmados por servidor;
- unknown monster/looktype rechazado o representado con fallback documentado.

## B. Monster3D Asset Contract

Propietario propuesto: `assets`, con consumidores `cliente`, herramientas de
validacion y `qa`. El servidor no es consumidor.

Debe definir:

- **Runtime format:** glTF 2.0 binario `.glb`, version/extensiones permitidas,
  politica de recursos embebidos y limite de tamano.
- **Scale:** unidad del asset, altura/extension visual de referencia y lugar
  donde vive el factor de presentacion. Nunca recalcula logical footprint.
- **Axis/orientation:** up axis, forward axis, handedness, facing canonico y
  conversion de las cuatro direcciones de dominio.
- **Pivot/origin:** apoyo en suelo, centro logico y regla para criaturas que
  vuelan, se arrastran o exceden un SQM.
- **Naming:** archivo, scene root, meshes, skeleton, bones, materials, clips,
  sockets y LODs; nombres estables y validables.
- **Skeleton archetypes:** catalogo versionado de archetypes como humanoid,
  quadruped, multi-leg y dragon/flying; reglas para excepciones.
- **Mandatory semantic animations:** mapeo de los estados del contrato de
  dominio a clips obligatorios, loop/no-loop, duracion y fallback. Los nombres
  definitivos no se fijan hasta consumir el vocabulario de Phase 5.
- **Materials/PBR:** Base Color, Normal, Roughness, Metallic y AO, espacios de
  color, resoluciones, transparencia y extensiones permitidas.
- **LOD policy:** cantidad/nombres, umbrales como metadata cliente, presupuesto
  de triangulos/bones/materials y fallback cuando falta un LOD opcional.
- **Visual collision:** colliders opcionales solo para picking/camara; prohibido
  usarlos como gameplay footprint o autoridad.
- **Validation:** schema manifest, apertura/import de GLB, ejes, pivot, bounds,
  skeleton, clips, materiales, LODs, recursos faltantes y determinismo.
- **Blender pipeline requirements:** version soportada, escena editable,
  transforms aplicados, unidades, export preset, pasos automatizables, logs sin
  secretos y artefactos reproducibles.

Debe incluir un manifest versionado que asocie `monster_identity` y
`skeleton_archetype` con el GLB y sus capacidades. El manifest vive en assets
o en el Monster Registry del cliente; el servidor nunca lo carga.

Fixtures propuestos:

- asset minimo valido por archetype;
- GLB con eje, pivot, clip, material o LOD invalido;
- registro con monster identity desconocida;
- sustitucion de LOD que no cambia posicion ni footprint;
- fallback visual ante asset ausente;
- import/export Blender reproducible.

## Preguntas que deben cerrarse al publicar

- identidad canonica: string namespaced, entero propio o ambos;
- vocabulario semantico minimo y politica de estados opcionales;
- unidad visual exacta y facing canonico;
- archetypes iniciales y politica de extensiones;
- presupuestos por plataforma para GLB, texturas, bones y LOD;
- manifest separado o metadata glTF permitida;
- version de Blender y preset de export oficial.

Estas preguntas son decisiones de contrato. Phase 0 no las resuelve a
escondidas.
