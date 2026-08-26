---
name: tomar-carril
description: Abre un carril de trabajo en TVP3D verificando contratos, propiedad de rutas y exclusividad del agente antes de implementar.
---

# Tomar carril

1. Lee completos `AGENTS.md`, `CARRILES.md` y `worklog/EVENTS.jsonl`.
2. Lee `worklog/<CARRIL>/STATE.md`.
3. Lee el `CONTRATO.md` del carril si existe.
4. Verifica cada dependencia en `CARRILES.md`: debe tener
   `worklog/<DEPENDENCIA>/CONTRATO.md` con `Estado: PUBLICADO`. Si falta uno,
   detente sin programar y registra el bloqueo.
5. Busca en `EVENTS.jsonl` y en los `STATE.md` si otro agente tiene el mismo
   carril `EN_CURSO`. Si lo tiene, detente y registra el conflicto.
6. Confirma que las rutas que tocaras pertenecen al carril.
7. Cambia solo tu `STATE.md` a `EN_CURSO`, rellena agente y fecha, y agrega una
   linea `APERTURA` a `EVENTS.jsonl` por append.

La apertura no autoriza tocar rutas de otro carril ni publicar una implementacion
sin contrato. Si hay una decision de una sola puerta, consulta antes de
continuar; si es de dos puertas, decidela y anotala como reversible.
