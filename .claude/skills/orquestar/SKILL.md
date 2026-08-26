---
name: orquestar
description: Construye el estado real de los carriles TVP3D desde worklog y contratos, calcula la ruta critica y despacha trabajo sin escribir produccion.
---

# Orquestar

1. Lee completos `AGENTS.md`, `CARRILES.md`, todos los `STATE.md`, todos los
   `CONTRATO.md` disponibles y `worklog/EVENTS.jsonl`.
2. Reconstruye el estado real desde eventos y archivos; senala contradicciones
   en vez de elegir silenciosamente una version.
3. Contrasta el estado con el grafo de dependencias y calcula la ruta critica.
4. Marca como despachable solo un carril cuyas dependencias tengan contrato
   `PUBLICADO` y que no este `EN_CURSO` en otra asignacion.
5. Prioriza desbloquear la ruta critica antes que carriles hoja.
6. Entrega para cada carril listo el prompt exacto, sus rutas, dependencias,
   criterio de cierre y comandos de verificacion.
7. No escribe codigo de produccion, no cambia estados por otro agente y no
   asigna dos agentes al mismo carril.

Si falta Git remoto, credencial, dato de proveedor o una decision de una sola
puerta, lo informa como bloqueo explicito. El orquestador puede recomendar la
publicacion de contratos en paralelo, pero nunca habilita implementacion antes
de contrato.
