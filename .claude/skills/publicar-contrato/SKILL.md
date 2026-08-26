---
name: publicar-contrato
description: Publica el contrato concreto de un carril TVP3D antes de que ese carril pueda implementar.
---

# Publicar contrato

1. Lee `AGENTS.md`, `CARRILES.md`, el `STATE.md` del carril y los contratos de
   sus dependencias.
2. Escribe `worklog/<CARRIL>/CONTRATO.md` usando la plantilla de
   `PLANTILLAS.md`.
3. Incluye esquemas concretos con nombres, tipos, obligatoriedad, rangos,
   version y ejemplos pequenos. Las frases vagas no son contrato.
4. Incluye una tabla de errores con la accion obligatoria del consumidor.
5. Declara explicitamente que no expone: secretos, autoridad ajena, rutas
   privadas o decisiones que pertenecen a otro carril.
6. Lista los consumidores y la regla de versionado.
7. Comprueba que no contradice `CARRILES.md` ni las tablas de dominio.
8. Cambia `Contrato publicado: SI` solo cuando el archivo sea util para otro
   agente. Agrega un evento `CONTRATO_PUBLICADO` por append.

Un contrato que miente es peor que uno ausente. Si una parte no se puede
determinar con evidencia local, escribe `TODO(config)` y registra el bloqueo;
no inventes credenciales, URLs, ids ni semantica de proveedor.
