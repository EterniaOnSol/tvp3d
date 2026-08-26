---
name: cerrar-turno
description: Cierra un turno de un carril TVP3D dejando estado, decisiones, notas, evento append-only y relevo versionado.
---

# Cerrar turno

1. Relee `AGENTS.md`, `CARRILES.md`, tu contrato, pruebas y el diff de tus
   rutas.
2. Actualiza tu `STATE.md` con estado real, hecho, falta, bloqueos, decisiones
   con `reversible` y notas para quien retome.
3. Usa `LISTO_PARA_REVISION` solo si la Definicion de Hecho es verificable. Si
   no puede continuar por una condicion externa, usa `BLOQUEADO` y llena
   `blockers` con una accion concreta.
4. Agrega exactamente una linea de cierre a `worklog/EVENTS.jsonl`. Nunca
   reescribas ni compactes el diario.
5. Ejecuta `git status`, revisa que no haya rutas de otro carril y crea un
   commit con mensaje claro.
6. Ejecuta `git push` al remoto configurado.
7. Si no existe `.git`, remoto o autorizacion, no inventes ninguno: registra el
   bloqueo en `STATE.md` y en el evento. El turno no puede declararse como
   push realizado.

El cierre debe decir exactamente que se verifico y que no. No borres historia,
no ocultes fallos y no marques `HECHO` por falta de tiempo.
