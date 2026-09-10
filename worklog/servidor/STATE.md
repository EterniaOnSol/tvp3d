# Estado: servidor

Estado: LISTO_PARA_REVISION
Ultimo agente: codex
Ultima actualizacion: 2026-09-09T17:48:05-06:00
Contrato publicado: SI

## Ultimo turno cerrado

- Phase 1D publico Authoritative Server V2 2.0.0 y conservo Server 1.1.0
  como evidencia historica/paridad.
- Se consumen modelo-comun 2.0.0, protocolo-red 2.0.0 y assets 2.0.0.
- No se modifico codigo Godot/C++/Lua, red, cliente, importadores, mapa,
  persistencia, autenticacion, gameplay ni contratos Monster.

## Depende de

- `modelo-comun` 2.0.0: contrato publicado.
- `protocolo-red` 2.0.0: contrato publicado.
- `assets` 2.0.0: contrato publicado.

## Evidencia historica / paridad

2026-09-08: sala del pergamino de Demon, contrato 1.1.0.
- Este snapshot culmino en `CIERRE_SALA_DEMON_VERIFICADA`; sus bullets se
  conservan como historia y no describen trabajo V2 pendiente.
- El contenedor activo monta C:\Users\dell\TVP3D\servidor en /srv.
- La entrada inicial ya era amount=1 pero usaba radius=30; se hará
  determinista con radius=0 para impedir que el spawn caiga fuera de la sala.
- El script AID 3121 ya es idempotente y crea cuatro posiciones solo al
  retirar el pergamino; se conserva sin agregar modelos ni autoridad cliente.
- Falta reconstruir/recrear el servidor y comprobar el arranque y el XML.

Construir el servidor Godot headless autoritativo, sus reglas y persistencia.

## Hecho

### Phase 1D

- Publicado `CONTRATO.md` 2.0.0 con autoridad final Godot 4.7
  `--headless` y TVP/TFS solo como oracle/migration reference.
- Congelados AuthoritativeDatasetManifestV2, registro de payloads,
  lifecycle BOOTING..FAILED, runtime scope, DefinitionRegistry,
  RuntimeEntityStore y SessionBindingV2.
- Congelados pipeline atomico de CommandEnvelopeV2, ServerErrorV2,
  COMMAND_REJECTED y los eventos ENTITY_SPAWNED,
  ENTITY_CORE_STATE_CHANGED y ENTITY_DESPAWNED.
- Publicado CoreEntityStateSnapshotV2 como payload CORE_ENTITY_STATE, con
  recovery por snapshot y stream nuevo baseline 0.
- Assets solo entra por NormalizedRecordV2 publicado NORMALIZED_DOMAIN;
  audit, diagnostic, unresolved, ids legacy y schemas desconocidos fallan.
- LogicalFootprintV1 gobierna ocupacion; datos visuales no entran al servidor.
- MOVE queda contratado genericamente, pero no habilitado en produccion V2
  antes de publicar Map / World Rules.

### Evidencia legacy previa

- La guarda generica de `Game::playerUseItem` (game.cpp:2568-2573) rechazaba
  cualquier item de cama con `RETURNVALUE_CANNOTUSETHISOBJECT` antes de
  llegar a `Actions::internalUseItem`, que es donde vive el manejo real de
  `BedItem` (actions.cpp:198) y por lo tanto `BedItem::canUse`/`trySleep`/
  `sleep` en bed.cpp. Una cama no es `isUseable()`, ni contenedor, ni puerta,
  ni `canReadText`, ni tiene una `Action` registrada, asi que caia siempre en
  este rechazo silencioso -sin ningun print `[BedDiag]`, porque esta guarda
  especifica no tenia diagnostico propio. Localizado en vivo: tras corregir
  la resolucion de clic del lado cliente (contrato cliente 1.6.0), el clic
  seguia devolviendo "You cannot use this object" sin ningun log de servidor,
  ni siquiera al desconectar (lo que descarta buffering de stdout, porque los
  tres prints `[BedDiag]` existentes usan `std::endl`).
- Se agrega `&& !item->getBed()` a esa guarda, mismo patron que la excepcion
  ya existente para `canReadText`. Con este cambio la cama alcanza
  `BedItem::canUse`, que ahora es codigo alcanzable de verdad.
- Verificado en vivo contra la cuenta 123456: un clic sobre la mitad pasiva
  de una cama (servidor 1761/1765) produce el rechazo correcto
  `[BedDiag] mitad no activa item=1765 partnerDir=West` -la logica de
  `BedItem::canUse`, no la guarda generica-, y un clic sobre la mitad activa
  (servidor 1760, Mill Avenue 1/house 81) hizo dormir al personaje: el
  servidor lo removio (`Guillermo Knight was removed from the game`) *antes*
  de que el socket se cerrara (`client disconnected`), el mismo orden que ya
  usa el flujo de expulsion documentado para la muerte, y el cliente mostro
  la cama con alguien durmiendo.
- Reconstruido con `docker compose build --no-cache server` (dos builds
  completos por un error de redireccion propio en el primer intento, ambos
  terminaron en `Image servidor-server Built`) y `docker compose up -d
  --force-recreate server`. Arranque limpio verificado: `TVP3D Server
  Online!` sin errores, TCP 7171 respondiendo.

- Los items escribibles y legibles vuelven a poder usarse. La guarda de
  `game.cpp:2556-2560` los rechazaba antes de llegar a
  `Actions::internalUseItem`, que es donde `canReadText` abre la ventana de
  texto, asi que no se podia escribir una etiqueta ni una carta ni leer un
  cartel, y el correo entero quedaba inutilizable. Ahora la guarda tambien
  deja pasar `canReadText`.
- Servidor reconstruido con ese cambio (`docker compose up --build`), que de
  paso compilo la reacquisicion de monstruos de `monster.cpp` que estaba
  pendiente desde el 2026-08-27.
- Comprobado en vivo: la ventana de texto abre, guarda lo escrito y lo
  devuelve al releerla; la etiqueta escrita entra en la parcel y el mailbox se
  lleva la parcel de la casilla.
- Dos talkactions de diagnostico para QA, que no cambian reglas de juego:
  `/tileinfo` dice que ve el servidor en una casilla (mailbox, depot, banderas
  y textos de los items) y `/limpiarpruebas` saca del inventario los objetos
  que dejan las pruebas vivas.

- Andamiaje creado.
- Contrato v1.0.0 publicado para arranque, sesiones, autoridad y movimiento.
- Servidor headless carga el mapa con validacion estricta; la ausencia solo
  activa el demo determinista anunciado en el perfil de demo.
- Posiciones iniciales reservan casillas desde la conexion TCP y no se
  solapan entre clientes.
- `MOVE` valida cardinalidad, caminabilidad y ocupacion; los rechazos emiten
  `ERROR` sin mutar el estado.
- `STATE` se difunde completo y ordenado por id a todos los jugadores listos.
- Sesiones, desconexiones, `PING/PONG`, direccion de movimiento y transiciones
  quedan cubiertos por la implementacion.

## Falta

### V2

- Publicar Map / World Rules antes de implementar carga de mundo, ocupacion,
  pathfinding o MOVE nativo.
- Publicar Item / Inventory, Authentication / Persistent Character Identity,
  Combat, Monster / Spawn y Quest / House antes de sus implementaciones.
- Migrar contratos de cliente, editor, QA e integracion en sus propios
  carriles; no se tocaron en Phase 1D.
- Implementar Server V2 y fixtures solo en fases posteriores de roadmap.

### Deuda historica legacy

- Integrar el cliente 3D propio con este recorrido de autoridad.
- Ejecutar revision cruzada del carril y decidir una persistencia duradera para
  jugadores cuando exista contrato de identidad/autenticacion.
- Verificar en vivo el flujo de despertar (wake-up) y persistencia (dormir,
  cerrar sesion o reconectar, y comprobar que la cama sigue ocupada o vuelve
  a liberarse segun corresponda). Esta sesion solo confirmo dormir y la
  expulsion; no se probo `wakeUp` explicitamente.
- Los diagnosticos `[BedDiag]` (bed.cpp y game.cpp) siguen en el binario; son
  utiles y no cambian reglas de juego, pero alguien deberia decidir si se
  retiran cuando el bloque de casas/camas quede completo en QA.

## Bloqueos activos

- Ninguno para Phase 1D.
- Historico resuelto: tras reiniciar Docker Desktop, MariaDB quedo healthy y
  servidor-server-1 quedo Up. El contenedor monta el XML con radius=0, el
  puerto 7171 responde y el cliente 3D se abrio para revision visual.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| El runtime scope nace tras validar datos y cambia en cada restart | Impide que refs runtime stale parezcan identidad persistente | no |
| Protocol READY no concede control; SessionBinding AUTHORIZED es obligatorio | Separa transporte de autenticacion/autorizacion | no |
| Solo NORMALIZED_DOMAIN resuelto entra a autoridad | Audit/legacy/provenance no son reglas runtime | no |
| Todo rechazo conserva world state/revisions/persistencia | Garantiza atomicidad autoritativa | no |
| Recovery minimo usa snapshot, stream nuevo y baseline 0 | Protocol V2 no garantiza replay log | si, con nueva version |
| MOVE no se habilita sin Map / World Rules | El contrato servidor no inventa caminabilidad final | no |
| La persistencia pertenece al servidor | El cliente no puede escribir estado del juego | no |
| El estado de jugadores del perfil propio es de sesion y vive en memoria | Evita rehidratar sesiones sin autenticacion ni contrato de identidad persistente | si |
| Un mapa existente invalido detiene el arranque; solo la ausencia usa el demo anunciado | Evita ocultar corrupcion o incompatibilidad de datos | si |

## Notas para quien retome

- Siguiente carril recomendado: `cliente`, contract-only, para consumir los
  cuatro eventos core y CORE_ENTITY_STATE sobre Protocol V2 sin modificar
  `mundo3d.gd` ni gameplay.
- Los detalles de Demon, beds, readable/writeable items, skull/party y
  movimiento TVP son fixtures/oracle, no primitives Server V2.
- Monster Domain, Monster3D y Cyclops siguen sin publicar/implementar.
- El proceso debe arrancar sin renderer mediante `--headless`.
