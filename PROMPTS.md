# PROMPTS.md

## Preambulo comun

Trabajas en `C:\Users\dell\TVP3D`. Lee primero `AGENTS.md`, `CARRILES.md`,
todo `worklog/EVENTS.jsonl`, tu `STATE.md` y los `CONTRATO.md` de tus
dependencias. Usa `tomar-carril` al abrir y `cerrar-turno` al terminar.

Respeta las rutas de tu carril. No implementes contra una dependencia sin
contrato publicado. Si descubres una contradiccion, detente, registrala y
propone la correccion en tu worklog. No inventes credenciales ni datos de
proveedor. Verifica con pruebas y deja notas de relevo concretas.

## Carril modelo-comun

Toma `modelo-comun`. Publica primero su `CONTRATO.md`: entidades, coordenadas,
tiles, acciones, estados, transiciones y validaciones. Implementa solo sus
rutas. Genera pruebas desde las tablas de dominio de `CARRILES.md`.

## Carril protocolo-red

Toma `protocolo-red`. Verifica que el contrato de `modelo-comun` este
publicado. Publica el contrato de framing, version, mensajes, errores,
fragmentacion y compatibilidad. Implementa pruebas de stream partido y
mensajes concatenados sin tocar logica de servidor o cliente.

## Carril servidor

Toma `servidor`. Verifica contratos de modelo, red y assets. Publica el
contrato de autoridad, comandos, eventos, persistencia y errores. Implementa
el servidor headless; el cliente nunca decide el resultado. Prueba dos clientes
y movimientos invalidos.

## Carril cliente

Toma `cliente`. Verifica contratos de modelo, red y assets. Publica el contrato
de estados visuales, input, reconexion y limites de autoridad. Implementa la
escena 3D y la UI solo en sus rutas. Prueba que una accion rechazada no cambia
la posicion confirmada.

## Carril assets

Toma `assets`. Publica formatos concretos de importacion/exportacion, ids,
versiones y errores. Implementa fixtures pequenos antes de datos grandes.
Conserva los originales y haz que la salida sea reproducible.

## Carril editor

Toma `editor`. Verifica contratos de modelo y assets. Publica el formato de
proyecto, operaciones, undo/redo y exportacion. Implementa edicion de tiles y
perfiles 3D sin mutar fuentes originales. Prueba guardar y recargar.

## Carril integracion

Toma `integracion`. Verifica contratos de servidor, cliente, editor y assets.
Publica comandos, puertos, perfiles y rutas de datos. Implementa solo
configuracion y arranque. Prueba maquina limpia y ausencia de secretos en la
salida.

## Carril qa

Toma `qa`. Verifica todos los contratos. Publica la matriz de pruebas y
fixtures. No arregles el carril revisado: registra hallazgos en su worklog.
Ejecuta pruebas de contrato, integracion, concurrencia y fecha fija; entrega
reporte reproducible.

## Prompt del orquestador

Lee todos los estados, contratos y eventos. Construye el estado real y
contrástalo con el grafo de `CARRILES.md`. No escribas codigo de produccion.
Entrega: (1) carriles despachables ahora en paralelo, (2) ruta critica y
bloqueos, (3) prompt exacto para cada carril listo, (4) contradicciones entre
contratos y (5) el siguiente evento append-only que corresponde registrar.
Nunca asignes un carril cuyas dependencias no tengan contrato ni dos agentes al
mismo carril.

## Prompt de revision cruzada

Revisa un carril que no implementaste. Lee su contrato, `STATE.md`, diff,
pruebas y eventos. Verifica punto por punto la Definicion de Hecho de
`AGENTS.md`, las rutas de propiedad, la autoridad del servidor, los secretos,
la historia append-only y los bloqueos. Entrega veredicto `HECHO` o una lista
concreta de faltantes con evidencia. No apruebes por cortesia.
