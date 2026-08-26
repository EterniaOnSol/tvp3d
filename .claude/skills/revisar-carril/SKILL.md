---
name: revisar-carril
description: Hace una revision cruzada de un carril TVP3D buscando fallos, violaciones de contrato y bloqueos reales.
---

# Revisar carril

La revision la hace un agente que no implemento el carril.

1. Lee `AGENTS.md`, `CARRILES.md`, `STATE.md`, `CONTRATO.md`, diff, pruebas y
   eventos del carril.
2. Comprueba cada punto de la Definicion de Hecho con evidencia, no con una
   lectura superficial.
3. Verifica propiedad de rutas, contrato antes de codigo, autoridad del
   servidor, ausencia de secretos, historia append-only y estados validos.
4. Ejecuta el checklist automatizable y revisa limites, errores, concurrencia
   y fechas fijas cuando apliquen.
5. Busca contradicciones con contratos de dependencias y consumidores.
6. Entrega veredicto `HECHO` o una lista priorizada de faltantes con ruta,
   prueba y accion concreta.

No apruebes por cortesia. No edites el carril revisado para arreglarlo; registra
la solicitud en su worklog y deja el estado que la evidencia justifique.
