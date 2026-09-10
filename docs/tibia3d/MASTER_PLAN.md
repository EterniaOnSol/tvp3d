# TVP3D - Architecture V2 Roadmap

Estado: PLAN VIGENTE

Este roadmap reemplaza el plan en el que TVP/TFS permanecia como runtime
final. Conserva los resultados de aquel trabajo como fixtures, conocimiento y
vertical slices de migracion.

## Mision

Construir un Tibia 3D propio con datos y protocolo versionados, servidor Godot
headless autoritativo y cliente Godot 3D. Los archivos Tibia 7.4/7.72 y el
runtime TVP/TFS alimentan importadores y pruebas de paridad, pero no son
dependencias del juego final.

## Reglas del roadmap

- Contrato antes de codigo.
- Migracion por vertical slices, nunca big-bang.
- Cada dominio nuevo demuestra paridad o documenta la diferencia.
- El cliente no adquiere autoridad durante la transicion.
- Los assets visuales no definen footprint ni colision de gameplay.
- Una fase no autoriza automaticamente la siguiente.

## Phase 0: architecture reconciliation

Objetivo: eliminar contradicciones activas sin borrar la historia.

Entregables:

- `ARCHITECTURE.md` V2;
- D-001 marcada historica y superseded por D-007;
- decisiones D-007 a D-010;
- roadmap V2 y auditoria de declaraciones contradictorias;
- plan, no implementacion, para los contratos Monster Domain y Monster3D.

Gate de salida: root `AGENTS.md` y `CARRILES.md` no tienen contradicciones
activas en la documentacion vigente; no cambio codigo de produccion, red, mapa,
gameplay ni runtime legacy.

## Phase 1: freeze domain contracts

Objetivo: publicar la base comun sobre la que migraran servidor, cliente,
assets, protocolo y QA.

Debe congelar, como minimo:

- identidad estable y aliases de ids de origen;
- coordenadas Tibia, chunks, pisos y logical footprints;
- entidades, comandos, eventos y ownership de cada estado;
- formato/versionado del IR y reglas de compatibilidad;
- limites de persistencia y errores de validacion;
- separacion entre metadata de dominio y referencias visuales.

Gate de salida: contratos concretos publicados, con esquemas, rangos, errores,
consumidores y migraciones. Ningun dominio nativo se implementa antes.

## Phase 2: build parity fixtures against TVP

Objetivo: convertir el legacy en una oracle reproducible.

Entregables:

- fixtures versionados por dominio;
- harness de comparacion determinista;
- catalogo de reglas observadas y casos limite;
- politica para clasificar diferencias como bug, deuda o cambio deliberado.

Gate de salida: cada fixture declara fuente, version, precondiciones y
resultado esperado sin depender de credenciales ni estado mutable oculto.

## Phase 3: native Godot authoritative server migration

Objetivo: migrar capacidades al servidor Godot headless por slices.

Orden interno orientativo:

1. carga de datos y mundo;
2. sesiones e identidad;
3. movimiento, ocupacion y pathfinding;
4. items, inventario y persistencia;
5. combate y efectos de dominio;
6. spawns, monstruos, quests y houses.

Cada slice implementa contrato, pasa fixtures de paridad y cambia al protocolo
propio antes de retirar su equivalente legacy. TVP puede seguir corriendo al
lado como oracle durante esta fase.

Gate de salida: el conjunto acordado de reglas autoritativas corre con
`--headless` y el cliente no necesita consultar al legacy para esas reglas.

## Phase 4: client subsystem decomposition

Objetivo: extraer responsabilidades de `mundo3d.gd` incrementalmente.

Destino:

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

No se hace una reescritura total. Cada extraccion conserva la fachada,
contratos y pruebas del comportamiento existente.

## Phase 5: Monster Domain Contract

Objetivo: definir el monstruo autoritativo sin referencias de render.

El contrato debe cubrir identidad estable, looktype, logical footprint,
direccion, estados semanticos, movimiento/estado autoritativo y vocabulario
semantico de animacion. Debe distinguir datos de especie, instancia y estado
transitorio.

Gate de salida: servidor, protocolo, cliente y QA pueden validar el mismo
payload sin conocer GLB, rig, materiales o LOD.

## Phase 6: Monster3D Asset Contract

Objetivo: definir el paquete visual consumido por el cliente.

El contrato debe cubrir glTF 2.0/GLB, escala, ejes, orientacion, pivot, naming,
skeleton archetypes, animaciones semanticas obligatorias, PBR, LOD, colision
visual, validacion y automatizacion Blender. Debe declarar que
`logical_footprint` no se deriva de la malla.

Gate de salida: un validador puede aceptar o rechazar un asset sin arrancar el
servidor ni consultar gameplay.

## Phase 7: Cyclops vertical slice

Objetivo: validar de punta a punta un solo monstruo despues de publicar ambos
contratos.

Flujo previsto:

```text
original sprite
  -> approved 50% faithful / 50% realistic concept
  -> image-to-3D raw GLB
  -> automated Blender processing
  -> validation
  -> final Godot GLB
  -> Monster Registry
```

El concepto aprobado es la fuente de verdad visual. La slice debe demostrar
registro, carga, escala, facing, estados semanticos, fallback, validacion y
separacion de footprint.

## Phase 8: Giant Spider + Dragon archetype validation

Objetivo: probar que los contratos no estan acoplados a un humanoide.

Giant Spider valida un archetype de multiples extremidades. Dragon valida un
archetype grande/volador o cuadrupedo. Cualquier excepcion descubierta vuelve
al contrato antes de producir mas assets.

## Phase 9: mass monster production

Objetivo: escalar solo un pipeline ya validado.

Incluye lotes, trazabilidad a concepto aprobado, QA automatico, revision
visual, presupuestos de rendimiento y reporte de fallos. Ningun fallo se
resuelve cambiando gameplay para ajustarlo a una malla.

## Phase 10: legacy runtime retirement after sufficient parity

Objetivo: retirar TVP/TFS del camino de ejecucion del producto.

Condiciones:

- dominios requeridos migrados al servidor Godot;
- protocolo propio cubre cliente-servidor;
- persistencia propia verificada;
- fixtures de paridad acordados en verde o con diferencias aprobadas;
- arranque y operacion no requieren TVP/TFS, MariaDB legacy ni archivos de
  runtime no importados.

TVP/TFS y los fixtures pueden conservarse en el repositorio como referencia y
regresion historica aun despues del retiro.

## Proxima fase exacta

**Phase 1 — freeze domain contracts: CERRADA / GATE APROBADO.** Los ocho
contratos fundacionales quedaron publicados y coherentes: `modelo-comun
2.1.0`, `protocolo-red 2.1.0`, `assets 2.0.0`, `servidor 2.1.0`,
`cliente 2.0.0`, `editor 2.0.0`, `integracion 2.0.1` y `qa 2.0.0`. El detalle
completo de la revision (grafo de dependencias, invariantes cruzados,
defectos encontrados) vive en `docs/tibia3d/PHASE1_CLOSURE_REVIEW.md`.

Este cierre es sobre CONTRATO, no sobre implementacion: ningun carril queda
`HECHO` por este cierre, `FULL_NATIVE_PLAYABLE` sigue bloqueado
(Authentication/Application Session, Map/World Rules y otros dominios
especializados siguen sin publicarse) y QA V2 sigue con 0 fixtures
materializadas.

Continuar unicamente con **Phase 2: build parity fixtures against TVP**.
Objetivo exacto: convertir el comportamiento legacy en fixtures de oracle
reproducibles (`LEGACY_PARITY`, usando `ParityFixtureV2` ya publicado por
`qa 2.0.0`), no implementar el servidor Godot nativo. La migracion del
servidor Godot headless sigue siendo Phase 3. No iniciar refactor de
`mundo3d.gd`, Monster Domain, Monster3D, Cyclops ni migracion de gameplay
hasta que Phase 2 entregue fixtures de paridad suficientes.
