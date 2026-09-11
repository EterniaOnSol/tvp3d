# Regresion QA — identidades de criaturas conocidas del legacy TVP 7.72

Estado: **PASS** (determinista + matriz + viva).

Turno de regresion QA estrecho. **No** cambia
`PARITY-MONSTER-REACQUISITION-001`, **no** crea ningun fixture, case,
observacion ni reporte de paridad, y **no** produce una tercera observacion
`LIVE_ORACLE`.

## Reparacion que se verifica

Commit del carril `protocolo-red`:

```text
78aaed58b38512a7c0edbe975895b707d380611a
fix: preserve TVP known creature identities
```

**Defecto reparado:** el servidor mantiene un `knownCreatureSet`
(`protocolgame.cpp:665-698`) que NO se vacia cuando una criatura sale de la
vista — solo desaloja al pasar de 150 entradas. `estado_mundo.gd`, en cambio,
vaciaba `criaturas` entero en cada `0x64` de mapa completo. Al reenviar el
servidor esa criatura como conocida (`0x62`, deliberadamente sin nombre), el
cliente ya no tenia de donde sacar el nombre y lo dejaba vacio. En vivo,
durante Phase 2C.2, eso dejo simultaneamente sin nombre al monstruo objetivo,
al god y al propio personaje.

La reparacion agrego un conjunto conocido propio del cliente
(`identidades_conocidas`), separado del mundo visible, con desalojo dirigido
por el `removedKnown` del `0x61` y limpieza en `reiniciar_sesion()`.

## Parte A — registro en la matriz QA

El carril `protocolo-red` dejo deliberadamente sin tocar
`cliente3d/pruebas/matriz_qa_local.gd` porque esa ruta pertenece a `qa`
(AGENTS.md regla 4). Este turno acepta esa solicitud y registra el caso una
sola vez:

```gdscript
{
    "nombre": "identidad_conocida_protocolo",
    "argumentos": PackedStringArray(["--headless", "--path", _raiz(),
        "--script", "red/identidad_conocida_self_test.gd"]),
},
```

Sigue exactamente la convencion ya usada por `party_self_test.gd`,
`mapa_captura_self_test.gd`, `estado_criatura_self_test.gd` y
`mapa_self_test.gd`. El self-test en si **no se modifico**.

### Resultado del self-test determinista

```text
Godot --headless --path cliente3d --script red/identidad_conocida_self_test.gd
```

**20/20 comprobaciones OK, codigo de salida 0.**

Correccion de un dato mal reportado antes: el cierre del turno de
`protocolo-red` dijo "21/21". El conteo correcto es **20**. El 21 salia de
contar `grep "_comprobar("`, que tambien matchea la linea de **definicion**
`func _comprobar(...)`. Hay 20 sitios de llamada reales y los 20 pasan. El
contenido de la prueba no cambio; solo se corrige la cifra.

Cobertura: alta que cachea identidad, perdida de visibilidad que no borra la
identidad de protocolo, reaparicion `0x62`, desalojo por `removedKnown`, no
resurreccion de un id desalojado (con diagnostico determinista en vez de
nombre inventado), reinicio de sesion, comportamiento generico
jugador/monstruo/NPC, forma corta `0x63` incluida tras perder visibilidad, y
la forma exacta del fallo vivo de Phase 2C.2 con las tres criaturas.

### Resultado de la matriz completa

```text
[qa] matriz local: 18/18 OK
```

Los 17 casos previos siguen verdes y el nuevo
`identidad_conocida_protocolo` tambien. No se removio ni se saelteo ningun
caso para que la matriz pasara.

## Parte B — regresion viva del parser

`cliente3d/pruebas/prueba_known_creature_identity_live.gd` + `.tscn`
(nuevos, QA-owned).

**No es un oracle de paridad:** no emite `OBSERVATION_JSON`, no usa
`wrap_live_observation.py`, no crea `OracleObservationV1`, `ParityFixtureV2`,
`QACaseV2` ni reporte de paridad.

### Terreno

Par aislado y colocable ya probado en Phase 2C.2:

```text
A = (32008, 32400, 7)
B = (32008, 32339, 7)
```

Coordenadas operativas de QA unicamente; no entran en ningun artefacto de
paridad.

### Secuencia ejecutada

1. conectar sesion god;
2. conectar sesion del personaje normal;
3. god a `A` con `/gotopos`;
4. `/c <personaje>` para colocarlo junto al god en `A`;
5. el personaje ve al god **por primera vez**, asi que el servidor lo manda
   como desconocido (`0x61`) **con** nombre -> se registra id y nombre exacto
   en memoria de proceso;
6. god a `B` con `/gotopos`;
7. `/c <personaje>` de nuevo: el personaje se teletransporta, lo que fuerza
   un `0x64` de mapa completo que **vacia su mundo visible**;
8. el servidor reenvia al god, que YA esta en su `knownCreatureSet`, en
   **forma conocida sin nombre** (`0x62`);
9. se exige que el nombre siga exacto y no vacio.

Mutacion total: solo `/gotopos` y `/c`. Sin invocar, sin atacar, sin
`/killall`, sin muerte, sin tocar inventario ni persistencia.

### Por que la transicion fue realmente de forma conocida

Esto importa: una llegada `0x61` de primera vez **no** probaria nada. La
prueba lo descarta de dos maneras, sin tocar el parser:

1. **Hubo refresco de mapa completo.** Se cuentan los `mapa_recibido`
   (emitido por cada `0x64`). Resultado: **5 mapas completos, contra 2 al
   momento de aprender** -> hubo 3 refrescos posteriores, cada uno vaciando
   el mundo visible.
2. **No pudo haber desalojo.** `checkCreatureAsKnown` solo saca a alguien del
   conjunto conocido cuando este supera **150** entradas. La prueba verifica
   que el conjunto local **nunca se acerco a 150** y que **nunca encogio**.
   Sin desalojo, el id siguio conocido para el servidor, asi que el reenvio
   posterior tuvo que ser `0x62` y no un `0x61` nuevo.

### Resultado

```text
Identidad aprendida en A (id relacion-only, nombre no vacio=true).
  OK  el personaje aprendio el nombre del god con la forma completa
  OK  la identidad quedo en el conjunto conocido del parser
Tras el refresco: mapas completos=5 (antes 2), nombre no vacio=true
  OK  hubo al menos un refresco de mapa completo (0x64) despues de aprender
  OK  el mismo runtime id volvio a estar visible
  OK  el nombre no quedo vacio tras el refresco
  OK  el nombre es exactamente el aprendido antes
  OK  el conjunto conocido sigue mapeando ese id al mismo nombre
  OK  el conjunto conocido nunca se acerco al tope del servidor (150)
  OK  el conjunto conocido nunca encogio: no hubo desalojo
  OK  el propio personaje tampoco perdio su nombre
  OK  ningun aviso de identidad conocida ausente
Regresion viva de identidades conocidas: OK
```

**11/11 comprobaciones OK, codigo de salida 0.**

| Criterio | Resultado |
|---|---|
| Refresco de mapa completo `0x64` involucrado | SI (3 despues de aprender) |
| Mismo runtime id tras la transicion | SI (`same_runtime_id = true`) |
| Nombre exacto preservado | SI (`same_name = true`, no vacio) |
| Conteo de `identidad_conocida_ausente` | **0** |
| Identidades verificadas con nombre vacio | **0** |
| Muertes de jugador | **0** |
| Monstruos invocados | **0** |
| Acciones de combate | **0** |
| Usos de `/killall` | **0** |

Se verifico ademas la **segunda identidad disponible de forma natural**: el
propio personaje conservo su nombre exacto tras el refresco. No se invoco
ningun monstruo solo para llegar a una tercera identidad — el self-test
determinista ya cubre la forma sintetica de tres criaturas.

Siguiendo la preferencia del turno, los ids de runtime concretos **no** se
documentan: lo que importa es la relacion (`same_runtime_id = true`), no el
valor numerico.

### No se hizo trampa

La prueba **solo lee** `estado_mundo.identidades_conocidas`; nunca escribe en
ella ni llama a internals del parser para fabricar un PASS. Verificado por
`grep`: no existe ninguna asignacion ni `clear`/`erase`/`merge` sobre la
cache desde el lado QA. La parte viva ejerce paquetes TVP reales; la parte
sintetica ya la cubre el self-test del carril `protocolo-red`.

## Credenciales

Exclusivamente por variables de entorno (`TVP772_ACCOUNT`,
`TVP772_PASSWORD`, `TVP772_GOD_CHARACTER`, `TVP772_PLAYER_CHARACTER`), nunca
literales en el codigo, nunca impresas, y sin enumerar otros personajes de la
cuenta ante un fallo. Ningun archivo nuevo contiene valores de credencial.

## Artefactos de Phase 2C.2 sin tocar

Verificado por hash, byte-identicos a antes de este turno:

| Archivo | SHA-256 |
|---|---|
| `cliente3d/red/mapa772.gd` | `74b10254bed3b76389654db0b0b4f5af95b66abb5399137bc32f69cc489adfbc` |
| `cliente3d/red/estado_mundo.gd` | `bab976ff8de83be9505b9471865da29ecd11f7af36ad313d837c5a73cc432c2f` |
| `cliente3d/red/identidad_conocida_self_test.gd` | `34f792f834e794b252f319b281f1c993b3ca563dd010d9a920693864320de2a5` |
| `cliente3d/pruebas/prueba_parity_monster_reacquisition_capture.gd` | `caa969e6863ce60e60d497c522426e82f84fc0f0c0de53d1878b6e19e4ee535f` |
| `qa/parity/reports/replay_live_monster_reacquisition_report.json` | `2b0f41f00d6309ed5876849064c3d4cde6406a248dafe65679180b695fd511fb` |

El adaptador de Phase 2C.2 conserva su `_ids_cave_rat`: es parte de la
implementacion ya certificada y ahora funciona como defensa en profundidad.
El hash `caa969e6...` es exactamente el congelado durante aquella
certificacion, asi que esa certificacion sigue siendo valida.

Tampoco se modifico ningun fixture, case, observacion o reporte de paridad.
El conteo de observaciones `LIVE_ORACLE` **sigue en 2**.

## Entorno

Docker Desktop estaba apagado al abrir este turno y se levanto para la parte
viva; el stack de TVP 7.72 se arranco con `docker compose up -d` (sin
`--build`, sin resetear datos ni volumenes) y se espero a
`>> TVP3D Server Online!` antes de conectar.

## Desalineamiento de mapa 0x64

La investigacion de `INVESTIGACION_DESALINEAMIENTO_MAPA_0X64_PENDIENTE`
**sigue abierta y separada**. Este turno usa el mensaje `0x64` unicamente
como disparador legitimo del refresco de mundo visible; no investiga ni
modifica nada del desalineamiento de pila.

## Proximo paso recomendado

Abrir un **tercer dominio de paridad**. No volver a modificar la
reacquisicion de monstruo salvo que aparezca una regresion nueva.
