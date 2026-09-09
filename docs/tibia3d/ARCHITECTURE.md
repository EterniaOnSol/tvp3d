# TVP3D - Architecture V2

Estado: OBJETIVO VIGENTE

Este documento reconcilia la arquitectura de `docs/tibia3d` con las reglas
vigentes de `AGENTS.md` y `CARRILES.md`. Cuando un documento anterior afirma
que TVP/TFS debe permanecer como servidor final, esa afirmacion es historica y
queda reemplazada por esta arquitectura y por D-007. Los registros de trabajo,
fixtures y decisiones anteriores se conservan como evidencia de migracion.

## Producto objetivo

TVP3D termina como un producto propio compuesto por:

- servidor autoritativo Godot 4.7 ejecutable con `--headless`;
- cliente 3D Godot 4.7;
- protocolo propio, versionado y normalizado entre ambos;
- datos de dominio propios, normalizados y versionados;
- importadores, fixtures y herramientas de paridad que extraen conocimiento
  de Tibia 7.4/7.72 y de la implementacion legacy TVP/TFS.

El juego final no requiere ejecutar TVP/TFS, MariaDB legacy ni el protocolo
7.72. Esos componentes siguen siendo valiosos durante la migracion, pero no
forman parte del runtime final.

```text
TIBIA 7.4 / 7.72 FILES
OTBM / OTB / XML / DAT / SPR
              +
TVP / TFS LEGACY IMPLEMENTATION
              |
              | source / oracle / migration reference
              v
IMPORTERS + PARITY TOOLS
              |
              v
VERSIONED OWN DATA / IR
map / items / monsters / spells / domain data
              |
       +------+------+
       |             |
       v             v
GODOT HEADLESS      GODOT 3D
AUTHORITATIVE       CLIENT
SERVER
       |             |
       +-- protocol--+
```

## Papel de TVP/TFS y de los archivos originales

TVP/TFS es:

- oracle de comportamiento para reglas aun no migradas;
- referencia de compatibilidad y de ingenieria inversa;
- fuente de fixtures de paridad;
- puente temporal para vertical slices durante la migracion.

OTBM, OTB, XML, DAT y SPR son fuentes de importacion. No son APIs del runtime
final. Los importadores deben conservar ids, coordenadas, procedencia y datos
desconocidos; nunca deben convertir silenciosamente un valor no soportado.

`servidor/`, `cliente3d/red/conexion772.gd` y los recorridos Docker actuales
son transicionales. Pueden seguir ejecutandose para obtener evidencia y
comparar paridad. No definen la autoridad final ni justifican agregar nuevas
dependencias del producto sobre el runtime legacy.

## Datos propios y contratos versionados

La salida de importacion es un modelo de dominio propio, no una copia opaca del
layout interno de TVP. Como minimo debe separar:

- identidad estable y aliases de ids de origen;
- coordenadas y tiles logicos;
- items, criaturas, monstruos, spells, spawns y quests;
- reglas y estados que requieren autoridad del servidor;
- referencias visuales consumibles solo por cliente/assets;
- version de esquema, procedencia y errores de importacion.

Un cambio incompatible de significado requiere nueva version y migracion. Los
consumidores rechazan versiones desconocidas de forma explicita. Los caches de
render y formatos derivados pueden regenerarse; el IR versionado y sus fuentes
trazables son la referencia de migracion.

## Limites de autoridad

### Dominio servidor

El servidor Godot headless es el unico propietario de:

- posicion autoritativa, movimiento y pathfinding;
- combate, dano y reglas de juego;
- monstruos, IA, spawns y drops;
- inventario e items dinamicos;
- quests, houses y persistencia;
- validacion y aplicacion de toda intencion del cliente.

El cliente envia intenciones. Solo un evento o snapshot confirmado por el
servidor puede cambiar el estado logico presentado como verdadero.

### Dominio cliente

El cliente posee exclusivamente:

- camara e input;
- interpolacion visual;
- render, animacion, audio y UI;
- seleccion visual y diagnosticos.

La interpolacion no mueve la posicion logica. Una animacion, un raycast o una
malla nunca aprueban movimiento, alcance, dano, ocupacion ni persistencia.

### Dominio assets

Assets posee:

- fuentes importadas y conversion reproducible;
- modelos, GLB, texturas, materiales PBR, rigs y LODs;
- procesamiento Blender y validacion visual/tecnica;
- asociaciones versionadas entre identidad de dominio y recurso visual.

El servidor no conoce nombres de `.glb`, Blender, Astra o image-to-3D,
materiales, texturas, implementaciones de skeleton ni geometria LOD. Un
registro visual puede cambiar sin migrar estado autoritativo.

## Geometria y colision

La geometria visible nunca define autoridad ni footprint de gameplay. Las
reglas Tibia SQM y los datos de dominio son independientes de la malla 3D.

Se distinguen al menos tres conceptos:

1. `logical_footprint`: ocupacion/regla autoritativa del servidor.
2. `visual_bounds`: volumen que el cliente usa para encuadre y presentacion.
3. `visual_collision`: ayuda opcional para picking o camara en el cliente.

Ninguna conversion entre los tres es implicita. Cambiar escala, rig, LOD o
silhouette no cambia un tile bloqueado, la distancia de ataque ni la casilla
ocupada.

## Arquitectura de coordenadas

La coordenada de dominio es una posicion Tibia entera `(x, y, z)`. `z` vive en
`0..15`; `z=7` es la superficie de referencia y valores menores se presentan
mas altos. La autoridad trabaja en SQM y no en vertices, metros ni colliders.

La conversion de presentacion centraliza:

- un ancla logica por escena o ventana;
- `SQM_WORLD_SIZE` positivo;
- `FLOOR_WORLD_HEIGHT` positivo;
- el mapeo reversible Tibia <-> mundo 3D;
- chunking por division piso, conservando coordenadas negativas.

Los chunks organizan streaming y almacenamiento; no cambian identidad ni
coordenadas. El cliente puede realinear su ancla para precision, pero debe
conservar la posicion Tibia confirmada. Las mallas usan coordenadas locales al
ancla y nunca convierten su transform en verdad de dominio.

## Protocolo final y adaptador legacy

El protocolo V2 sera propio y versionado. Debe distinguir intenciones
cliente->servidor de eventos/snapshots servidor->cliente, validar framing y
payloads, y fallar de forma explicita ante versiones u opcodes desconocidos.

El adaptador 7.72 actual es una frontera de migracion. Sirve para capturar
fixtures, medir comportamiento y mantener vertical slices mientras un dominio
se migra. No se mezcla su framing con el protocolo propio ni se exportan sus
detalles accidentales como modelo de dominio V2.

## Estrategia de migracion incremental

No se hace una reescritura big-bang. Cada vertical slice sigue este ciclo:

1. definir el contrato de dominio y sus invariantes;
2. capturar fixtures reproducibles desde archivos y/o TVP;
3. implementar la misma capacidad en el servidor Godot;
4. comparar resultados con la oracle legacy;
5. dirigir el cliente V2 a la capacidad nativa;
6. retirar solo esa dependencia legacy cuando alcance la paridad acordada.

Una diferencia puede ser una incompatibilidad, una regla no migrada o una
correccion deliberada. Debe clasificarse; nunca se elige silenciosamente entre
TVP, un documento y la implementacion nueva.

## Monstruos: separacion dominio/visual

No se implementa un pipeline Monster3D nuevo hasta publicar los contratos de
dominio y de asset. La frontera futura es:

```text
server creature
    -> monster id / looktype / position / direction / semantic state
    -> versioned protocol
    -> client Monster Registry
    -> visual Monster3D asset
    -> GLB / rig / animation / materials
```

El concepto aprobado es la fuente de verdad visual. El flujo previsto, aun no
implementable, es:

```text
original Tibia sprite
  -> approved 50% faithful / 50% realistic concept
  -> image-to-3D raw GLB
  -> automated Blender processing
  -> validation
  -> final Godot GLB
```

El servidor transmite identidad, looktype, posicion, direccion y estados
semanticos. No transmite clips, huesos o rutas de assets. El Monster Registry
del cliente resuelve esos datos a una representacion y conserva un fallback
diagnostico para assets aun no migrados. Los prototipos y formatos Monster3D
anteriores a V2 son evidencia transicional; no sustituyen el contrato futuro.

## Evolucion de `mundo3d.gd`

`cliente3d/mundo3d.gd` concentra hoy streaming, render de mapa, criaturas,
jugador, efectos, camara, input y diagnosticos. Es deuda conocida. No se
reescribe de una vez ni se refactoriza en Phase 0.

La descomposicion cliente de largo plazo es:

```text
Mundo3D
|-- WorldStreamer
|-- ChunkRenderer
|-- StaticMapRenderer
|-- CreatureManager
|-- PlayerManager
|-- EffectManager
|-- CameraController
`-- DebugOverlay
```

Cada extraccion futura debe conservar comportamiento, depender de contratos
publicados y entrar con pruebas. `Mundo3D` queda como fachada/orquestador
mientras se mueven responsabilidades una por una.

## Invariantes de Architecture V2

- El producto final arranca sin TVP/TFS.
- El servidor Godot headless es la autoridad final.
- El cliente nunca aprueba resultados de gameplay.
- Assets no filtra detalles visuales al dominio servidor.
- Ninguna malla o collider visual define reglas SQM.
- El IR y el protocolo tienen version explicita.
- La migracion se acepta por contratos y paridad reproducible.
- Los documentos y logs historicos se conservan y se marcan como
  superseded/transicionales cuando corresponda.
