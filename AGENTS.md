# AGENTS.md

## Proyecto

Construimos una version propia y jugable de Tibia en 3D: servidor
autoritativo y headless en Godot, cliente 3D en Godot y un editor capaz de
importar el mapa y convertir elementos 2D en representaciones 3D.

| Aspecto | Decision fija |
|---|---|
| Producto | Tibia 3D propio, inspirado en las mecanicas y datos de Tibia 7.72 |
| Stack | Godot 4.7, GDScript, servidor Godot `--headless`, cliente Godot 3D, TCP propio, JSON para datos editables |
| Referencias | TVP/C++ y los archivos de Tibia son fuentes de datos y comportamiento, no el runtime final |
| Restriccion transversal | El servidor es la unica autoridad sobre estado, reglas y persistencia; nunca se registran credenciales ni secretos |
| Tamano estimado | 8 piezas grandes: modelo comun, red, servidor, cliente, assets, editor, integracion y QA |

Proponer otro lenguaje, motor, protocolo o forma de autoridad requiere un ADR
antes de implementarlo. Una preferencia individual no cambia el stack fijo.

## Reglas innegociables

1. **Contrato antes que codigo.** Ningun carril implementa hasta que su
   `CONTRATO.md` este publicado. Los demas programan contra el contrato, no
   contra la implementacion.
2. **Servidor autoritativo.** El cliente puede solicitar acciones y dibujar
   resultados, pero no puede aprobar movimiento, dano, inventario, drops,
   quests ni persistencia.
3. **No inventes credenciales ni datos de proveedor.** Si falta un token, una
   URL o una ruta de datos, deja un `TODO(config)` explicito y registralo como
   bloqueo. Nunca hardcodees valores de ejemplo que parezcan reales.
4. **Un agente = un carril por turno.** No toques rutas de otro carril. Si
   necesitas un cambio ahi, registralo como solicitud en su worklog.
5. **Las correcciones no borran historia.** Corrige con un registro
   compensatorio y conserva eventos, decisiones y estados anteriores.
6. **Secretos fuera de logs.** No escribas claves, tokens, contrasenas,
   sesiones ni contenido sensible en stdout, archivos de prueba o `EVENTS`.
7. **Datos de dominio como datos.** Estados, transiciones y vocabularios
   cerrados viven en tablas/estructuras validables; no se duplican como una
   cadena de condicionales en varios carriles.
8. **Cambios compartidos con dueño.** `CARRILES.md` es la fuente de verdad de
   propiedad. Si una ruta compartida necesita cambio, trabaja mediante su
   carril propietario y deja una solicitud en el worklog.

## Como registrar el trabajo

`worklog/EVENTS.jsonl` es append-only. Cada evento ocupa exactamente una linea
JSON con estas claves:

```json
{"ts":"ISO-8601","agent":"identidad","lane":"carril","event":"EVENTO","state":"ESTADO","contract":"PUBLICADO|NO_PUBLICADO|NO_APLICA","summary":"texto breve","blockers":[]}
```

Ejemplo real del andamiaje:

```json
{"ts":"2026-08-25T08:00:00-06:00","agent":"codex","lane":"orquestacion","event":"ANDAMIAJE_CREADO","state":"HECHO","contract":"NO_APLICA","summary":"Carriles, plantillas y skills publicados para TVP3D","blockers":[]}
```

Los eventos deben describir hechos verificables. No reescribas ni ordenes el
archivo despues; para corregir un hecho agrega otro evento compensatorio.

## Estados validos

La linea normal es:

`NO_INICIADO` -> `EN_CURSO` -> `LISTO_PARA_REVISION` -> `HECHO`

`BLOQUEADO` queda fuera de la linea y exige que `blockers` no sea vacio tanto
en `STATE.md` como en el evento. Un carril no puede pasar a
`LISTO_PARA_REVISION` sin contrato publicado, pruebas correspondientes y
notas para quien lo retome.

## Definicion de Hecho

- [ ] El alcance del carril coincide con `CARRILES.md`.
- [ ] `CONTRATO.md` esta publicado, es concreto y no contradice otros
      contratos.
- [ ] La implementacion respeta el contrato y no invade otra ruta.
- [ ] Las verificaciones automatizables pasan y sus comandos quedan anotados.
- [ ] Los casos de error y los limites relevantes tienen prueba o una nota de
      riesgo explicita.
- [ ] `STATE.md` refleja lo que falta, las decisiones y las notas de relevo.
- [ ] Se agrego un unico evento de cierre al worklog por este turno.
- [ ] El commit y push se hicieron, o el bloqueo de Git quedo registrado sin
      inventar remoto ni credenciales.

## Ambiguedades

Las decisiones de una sola puerta se consultan: cambian el contrato, la
autoridad del servidor, la compatibilidad de datos o el alcance de otro
carril. Las decisiones de dos puertas se toman y se anotan en `STATE.md` con
la columna `reversible`: se pueden corregir sin migracion ni contrato roto.

## Orden de lectura

Antes de trabajar, lee `AGENTS.md`, `CARRILES.md`, todo
`worklog/EVENTS.jsonl`, el `STATE.md` del carril y los contratos de sus
dependencias. Usa los skills `tomar-carril` y `cerrar-turno` en cada turno.
