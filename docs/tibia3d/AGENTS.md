# TVP3D - Specialized Agent Roles

Estado documental: CURRENT bajo `AGENTS.md`, `CARRILES.md` y Architecture
V2. Estos roles no pueden cambiar las fronteras de autoridad ni saltarse
contratos.

El entorno actual no expone subagentes nativos; el orquestador emula estos
roles con tareas separadas, contratos y documentos. Cada rol debe inspeccionar
antes de editar y dejar evidencia en `STATUS.md` o el documento de salida.

1. Repository Archaeologist -> `REPOSITORY_AUDIT.md`.
2. Tibia Protocol Specialist -> `NETWORK_PROTOCOL.md`.
3. Tibia Map Specialist -> `MAP_PIPELINE.md`.
4. Item/Sprite Reverse Engineering -> `ITEM_MAPPING.md`.
5. 3D Engine Architect -> `ARCHITECTURE.md` y `DECISIONS.md`.
6. 3D Map Conversion Engineer -> pipeline y herramientas.
7. Procedural Geometry Specialist -> reglas de adyacencia y perfiles.
8. Character/Creature Engineer -> criaturas, outfits e interpolacion.
9. Gameplay Integration Engineer -> interacciones y compatibilidad TVP.
10. Rendering/Performance Engineer -> `RENDERING.md` y benchmarks.
11. Tooling Engineer -> editor, inspector y debugger.
12. QA/Regression Agent -> pruebas, fixtures y reportes.

## Orquestador

El orquestador mantiene el estado, evita duplicar arquitecturas, revisa los
diffs, actualiza el backlog y no permite marcar exito con mocks silenciosos.
Cada hallazgo que cambie direccion se registra en `DECISIONS.md`.

## Reglas de convivencia

- Un rol no muta el servidor TVP por conveniencia: el legacy se protege como
  oracle. El carril `servidor` migra reglas al servidor Godot en rutas propias
  solo despues de contrato y fixtures de paridad.
- Las rutas y contratos se anuncian antes de tocar codigo compartido.
- Los agentes pueden analizar en paralelo, pero la integracion del mismo
  archivo se hace en serie.
- Un item desconocido genera placeholder y reporte.
- Todo cambio del cliente conserva el par posicion logica/posicion mundo.
