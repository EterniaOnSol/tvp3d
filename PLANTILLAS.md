# PLANTILLAS.md

## Plantilla de `STATE.md`

```markdown
# Estado: <CARRIL>

Estado: NO_INICIADO
Ultimo agente: <identidad>
Ultima actualizacion: <ISO-8601>
Contrato publicado: NO

## Depende de

- <carril>: <contrato publicado / falta>

## Hecho

- Nada todavia.

## Falta

- Publicar contrato.

## Bloqueos activos

- Ninguno.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| <decision> | <evidencia> | si/no |

## Notas para quien retome

- <trampa, supuesto o prueba que no es obvia leyendo el codigo>
```

## Plantilla de `CONTRATO.md`

```markdown
# Contrato: <CARRIL>

Version: 1.0.0
Estado: PUBLICADO
Propietario: <carril>
Depende de: <contratos>

## Proposito

<una frase verificable>

## Esquemas concretos

### <nombre>

```json
{"campo":"tipo","obligatorio":true}
```

Reglas: <rangos, ids, version y semantica>

## Errores

| Codigo | Cuando ocurre | Que hace quien llama |
|---|---|---|
| `<codigo>` | <condicion> | <accion obligatoria> |

## No expone

- <dato, autoridad o ruta que no forma parte del contrato>

## Consumidores

- <carril>

## Compatibilidad y versionado

<regla de cambios compatibles y migraciones>
```

## Ejemplo de `EVENTS.jsonl`

```json
{"ts":"2026-08-25T08:00:00-06:00","agent":"codex","lane":"orquestacion","event":"ANDAMIAJE_CREADO","state":"HECHO","contract":"NO_APLICA","summary":"Sistema de carriles creado","blockers":[]}
{"ts":"2026-08-25T08:10:00-06:00","agent":"agente-modelo","lane":"modelo-comun","event":"APERTURA","state":"EN_CURSO","contract":"NO_PUBLICADO","summary":"Inicia contrato del modelo comun","blockers":[]}
```
