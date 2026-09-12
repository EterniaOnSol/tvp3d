# Estado actual del juego — 2026-09-12

Inspeccion de **estado de producto**, no de paridad. Este documento **no** es
`OracleObservationV1`, no crea `ParityFixtureV2` ni `QACaseV2`, no produce
`OBSERVATION_JSON` y **no mueve ningun conteo de paridad**.

| Dato | Valor |
|---|---|
| Rama | `feature/architecture-v2` |
| Commit inspeccionado | `85c956d681472e6bb17a3519dc303c6ce8c918cb` |
| Fecha real de la inspeccion | 2026-09-12, 00:10–00:30 hora local |
| Identidad usada | `QA_LEVEL_HIGH` (personaje **dedicado de QA**, cuenta que contiene solo personajes de QA) |
| Personajes del usuario usados | **0** |
| Cuentas/personajes creados | **0** |
| Credenciales cambiadas | **0** |
| **Clasificacion global** | **`PLAYABLE_WITH_MINOR_DEFECTS`** |

---

## 1. Servidor

### 1.1 Como arranca esta rama

Se inspeccionaron los archivos del repositorio antes de suponer nada. El
arranque canonico es **Docker Compose**, definido en
`servidor/docker-compose.yaml` mas `servidor/docker-compose.override.yml`, y
envuelto por `ARRANCAR SERVIDOR.bat` (`docker compose up --build -d`).

El `override` existe por un motivo documentado: al apagarse el servidor guarda
mapa y casas y tarda ~14 s; el `stop_grace_period: 120s` evita que Docker lo
mate a los 10 s y deje un `gamedata/map.tvpm` truncado.

### 1.2 Que se hizo

**El stack ya estaba corriendo, asi que NO se reinicio.** No se reconstruyo
ninguna imagen, no se borro ningun volumen, no se toco la base, no se
regenero el mundo y no se modifico ninguna configuracion para hacerlo
arrancar.

| Contenedor | Estado | Puertos |
|---|---|---|
| `servidor-server-1` | Up 17 h | `0.0.0.0:7171-7172 -> 7171-7172/tcp` |
| `servidor-mariadb-1` | Up 17 h (**healthy**) | `0.0.0.0:3371 -> 3306/tcp` |
| `tvp3d_web` | Up 17 h | `0.0.0.0:8072 -> 80/tcp` (MyAAC, compose aparte en `web/`) |

### 1.3 Puertos

| Puerto | Escuchando | Conexion TCP de prueba |
|---|---|---|
| **7171** (login) | si (`::` y `::1`) | **CONECTA** |
| **7172** (juego) | si (`::` y `::1`) | **CONECTA** |

### 1.4 Arranque y errores

Log de arranque limpio y completo:

```
The Violet Project - Version 3.1 Beta
Compiled on Sep 10 2026 08:03:37 for platform x64
>> Establishing database connection... MySQL 8.0.46
>> Loading map  ->  data/world/map.otbm   Map size: 65000x65000
> Map loading time: 21.399 seconds.
> Loading house items...  8.34 s
>> Initializing gamestate
> Total Monsters: 23063
> Total NPCs: 336
```

- Errores fatales: **0**
- Excepciones / crash loop: **0** (un solo proceso, 17 h de pie)
- Migraciones destructivas de base: **0**
- Unico aviso: `The Violet Project has been executed as root user` — benigno,
  propio del contenedor.
- Errores del servidor **durante la sesion de inspeccion**: **0**

**SERVER: `RUNNING`.**

---

## 2. Cliente

### 2.1 Como se lanzo

Punto de entrada normal del proyecto, el mismo de `JUGAR.bat`
(`cliente3d/project.godot` -> `run/main_scene="res://main.tscn"`):

```
Godot_v4.7.2-stable_win64_console.exe --path cliente3d main.tscn
```

**Sin `--headless`.** Se abrio una **ventana real** titulada `TVP3D (DEBUG)`,
confirmada por el driver de video que reporta el propio motor:

```
OpenGL API 3.3.0 NVIDIA 595.97 - Compatibility - Using Device: NVIDIA GeForce GTX 1650
```

**Inspeccion visual con GUI: SI.** Las capturas de la seccion 7 salen de la
ventana real, no de un log.

### 2.2 Login

El cliente normal acepta credenciales por entorno para arranques automatizados
(`mundo3d.gd:719-720`, con el comentario explicito de que nunca se imprimen ni
se guardan en disco). Se le paso la cuenta **dedicada de QA**; el cliente
selecciona automaticamente el primer personaje de la cuenta, que es un
personaje de QA.

| Etapa | Resultado |
|---|---|
| Pantalla de login | funciona |
| Conexion al servidor de cuentas | OK |
| Lista de personajes | OK |
| Entrada al mundo | **OK** |
| Sesion estable | si, toda la sesion sin caidas |
| Confirmacion del lado servidor | `<QA_LEVEL_HIGH> has logged in` … `was removed from the game` |

**Ningun valor de credencial se imprimio, ni en el log del cliente ni aca.**

---

## 3. Estado jugable observado

### 3.1 Mapa y mundo

El mundo carga y se dibuja. El HUD del cliente reporta en vivo:

```
TVP3D   (32091, 32179, 7)   6948 things   7 creatures
Chunk (501, 502)   unmapped 3
WASD/arrows/QE-ZC walk | left click auto-walk | right drag camera | wheel zoom
```

| Aspecto | Estado |
|---|---|
| Aparece el mapa | **si** |
| Posicion del jugador plausible | si, Thais y cuevas de Thais |
| Alineacion de casillas | sin corrimientos visibles en las cuatro capturas |
| Casillas faltantes | ninguna; si hay **items sin perfil 3D** (seccion 5.1) |
| Sintomas de desalineamiento `0x64` | **no se observaron** en esta sesion |
| Renderizado de pisos | correcto en `z = 7` (superficie) y `z = 8` (cueva) |
| Cambio de piso | **funciona**, observado en los dos sentidos |

Se dibujan: suelo de pasto, camino empedrado, tierra, pisos de madera, paredes
y edificios con techo, escaleras, agua, vegetacion, vallas y objetos sueltos
(barriles, ollas, estantes, armas en el piso).

### 3.2 Jugador

| Aspecto | Estado |
|---|---|
| Representacion visible | si. El jugador tiene **entidad visual propia**, separada del pool de criaturas, para poder interpolar entre confirmaciones del servidor (`mundo3d.gd:3961-3965`) |
| Movimiento | **funciona** |
| Cambio de direccion | si |
| Camara sigue al jugador | si |
| Posicion sincronizada | **si, verificado contra el servidor** (seccion 3.6) |

### 3.3 Criaturas

| Aspecto | Estado |
|---|---|
| Aparecen criaturas cercanas | si (NPC `Norma`, `Rabbit` x2, `Rat`) |
| Nombres | si, correctos, tanto en la lista de batalla como en el panel de objetivo |
| Vida / estado | si, barra y porcentaje (`100%`, `20%`) |
| Movimiento de criaturas | si |
| Regresiones de identidad/nombre | **ninguna observada**: ninguna criatura aparecio sin nombre |
| Presentacion | sprites 2D del propio 7.72 colocados como entidades dentro del mundo 3D |

Esto ultimo importa como dato de estado: la regresion de "criatura conocida sin
nombre" que se arreglo en Phase 2C.2 **sigue sin reaparecer**.

### 3.4 Camara

Perspectiva 3D en tercera persona, elevada y centrada en el jugador. Controles
publicados por el propio HUD: `right drag camera` para rotar y `wheel zoom`
para acercar. No se observaron recortes (*clipping*), ni pisos superiores
tapando la vista, ni bloqueos de camara.

### 3.5 UI

Todo lo siguiente esta presente y con datos reales:

| Panel | Estado |
|---|---|
| Vida / mana | barras `HP 143/270`, `MP 120/120`, coherentes con el servidor |
| Skills | Level, Hitpoints, Mana, Capacity, Magic Level y las 7 habilidades con valores reales |
| Lista de batalla | si, con nombre y barra de vida por criatura |
| Panel de objetivo | si, con nombre y porcentaje |
| Inventario / equipo | si, cuadricula de ranuras con items puestos |
| Chat | si, con pestañas `Default / Game-Chat / RL-Chat / Trade / Help` y campo de entrada |
| Minimapa | **si**, con leyenda `White: you  Pink: creatures` y zoom |
| VIP | si (vacio) |
| Stash | si (`0 gold`) |
| Acciones | `Store / Skills / Battle / Vip / Stash` |
| Pie | `Cap: 526`, `Quests`, `Options`, `Logout` |
| UI de debug obvia | ninguna, salvo el HUD de diagnostico de la esquina superior |

Mensajes autoritativos del servidor recibidos y mostrados correctamente:
`Blocked.`, `There is not enough room.`, `Sorry, not possible.`,
`You cannot use this object.`, `Using meat...`.

### 3.6 Movimiento — y una advertencia honesta

Se envio una muestra chica de pasos con las flechas a la ventana enfocada y se
capturo antes y despues. Posicion observada en el HUD: `(32115, 32244, 8)` ->
`(32117, 32243, 8)`.

**Declaracion necesaria: el usuario estaba usando la misma ventana durante la
inspeccion** (peleo una rata, uso objetos, se movio y bajo a la cueva). Por eso
**no se puede atribuir limpiamente ese delta a las teclas enviadas por QA**, y
no se afirma aca que se haya medido un paso aislado.

Lo que **si** queda probado, y no depende de quien apreto la tecla:

- la posicion del jugador **cambia** de forma coherente con la entrada;
- el cambio de piso funciona (`z = 7` <-> `z = 8`);
- al cerrar sesion, el servidor persistio `Position = [32091,32179,7]`, que es
  **exactamente** la ultima posicion que mostraba el HUD del cliente. Cliente y
  servidor terminaron **de acuerdo**, verificado fuera del camino de
  observacion del cliente.

### 3.7 Progresion de la sesion

Efectos normales de juego, provocados por la partida del usuario, no por QA:

| Magnitud | Antes | Despues |
|---|---:|---:|
| Nivel | 25 | 25 (**0**) |
| Experiencia | 204834 | 204839 (**+5**) |
| Vida | 143 | 135 |
| Stamina persistida | 2530 | 2530 |

---

## 4. Errores en tiempo de ejecucion

| Fuente | Resultado |
|---|---|
| `stderr` del cliente | **vacio** |
| `stdout` del cliente | 28 lineas, **0** errores y **0** advertencias; solo trazas informativas `[tvp3d] resolver uso ...` |
| Errores del parser de red | **0** |
| Excepciones de Godot | **0** |
| Log del servidor durante la sesion | **0** errores |

---

## 5. Defectos observados — registrados, NO corregidos

Este turno es una inspeccion. Ninguno de estos se arreglo, y ninguno pertenece
al carril `qa`.

### 5.1 Items sin perfil 3D (`assets` / `editor`)

En el mundo aparece un **cubo magenta** bien visible. No es un fallo: es el
marcador deliberado del propio cliente,
`_material_placeholder()` (`mundo3d.gd:3682-3690`), un
`Color(1.0, 0.0, 1.0)` sin sombreado con la clave `__unmapped_item__`, que se
usa cuando un id de item **no tiene mapeo 3D**.

El HUD lleva la cuenta: se observo `unmapped 0` en una zona y `unmapped 3` en
otra. O sea que la cobertura de perfiles 3D esta **casi completa** pero no del
todo.

**Solicitud de carril:** `assets` / `editor` — completar el perfil 3D de los
ids que todavia caen en el placeholder. El cliente ya los senala solo.

### 5.2 Speed, Food y Stamina siempre en 0 (`cliente`)

El panel de skills muestra `Speed 0`, `Food 0` y `Stamina 0%` de forma
permanente, y `Exp.` muestra `--`.

No es un error de parseo: el `0xA0` de este servidor 7.72 trae **once** campos
(`estado_mundo.gd:636-652`) — vida, vida maxima, capacidad, experiencia, nivel,
% de nivel, mana, mana maxima, nivel magico, % magico y alma — y **ninguno es
stamina, comida ni velocidad**. La UI (`interfaz.gd:1296-1299`) pinta filas que
leen claves que el protocolo nunca entrega.

La prueba de que el dato existe pero no viaja: el archivo persistido del
personaje tiene `Stamina = 2530` mientras la UI muestra `0%`.

**Solicitud de carril:** `cliente` — o quitar esas filas del panel, o marcarlas
como no disponibles en 7.72, en vez de mostrar un cero que parece un valor real.

### 5.3 Credenciales literales fuera de `cliente3d/pruebas/` (`integracion`)

Mientras se verificaba el arranque canonico se encontro que
`ARRANCAR SERVIDOR.bat` y `web/LEEME.md` **publican en texto plano** la cuenta
y la clave de desarrollo del servidor, en archivos versionados.

Es exactamente el mismo problema que este turno resolvio dentro de
`cliente3d/pruebas/`, pero esos archivos son del carril `integracion` y **este
carril no los toca**.

**Solicitud de carril:** `integracion` — decidir si esa credencial de
desarrollo debe seguir publicada o pasar a configuracion local.

---

## 6. Clasificacion

### `PLAYABLE_WITH_MINOR_DEFECTS`

Por que **no** es algo peor:

- no es `NOT_BOOTABLE` / `BOOTS_ONLY`: servidor y cliente arrancan;
- no es `LOGIN_WORKS`: el mundo carga entero, con terreno, edificios,
  criaturas e items;
- no es `WORLD_LOADS`: se camina, se cambia de piso, la camara sigue, la UI
  responde, el combate y el uso de objetos funcionan;
- no es `PLAYABLE_WITH_MAJOR_DEFECTS`: **cero** errores de runtime en el
  cliente, **cero** errores en el servidor, **cero** desconexiones, y la
  posicion del cliente coincide **exactamente** con la que el servidor
  persiste.

Por que **no** es `PLAYABLE_WITH_MINOR_DEFECTS` a secas sin salvedades: quedan
los tres puntos de la seccion 5. Los dos primeros son visibles en pantalla —un
cubo magenta y tres filas de estadisticas en cero— y por eso la clasificacion
no sube mas.

### Salvedades de alcance

- Sesion **unica** y corta, en Thais y sus cuevas. No es una certificacion de
  jugabilidad ni un barrido del mundo.
- La ventana estuvo **compartida con el usuario jugando**; se declara en 3.6.
- **Nada de lo observado aca se convierte en evidencia de paridad.**

---

## 7. Evidencia visual

Capturas de la ventana real, en `docs/qa/capturas/`:

| Archivo | Que muestra |
|---|---|
| `estado_2026-09-12_01_thais_superficie.png` | Thais desde arriba: calle empedrada, edificios, agua, vegetacion, UI completa, lista de batalla con el NPC `Norma` |
| `estado_2026-09-12_02_thais_hud.png` | HUD de diagnostico con posicion, `6948 things`, `7 creatures`, `unmapped 3`, y el **cubo magenta** del placeholder |
| `estado_2026-09-12_03_cueva_objetivo.png` | Cueva en `z = 8` con el panel de **objetivo** mostrando `Rat 20%` |
| `estado_2026-09-12_04_cueva_tras_mover.png` | La misma cueva tras la muestra de movimiento, con posicion actualizada en el HUD |

Ninguna captura contiene la pantalla de credenciales ni ningun valor secreto.

---

## 8. Higiene de credenciales de este turno

Detalle operativo completo en `worklog/qa/STATE.md`. Resumen:

| Magnitud | Valor |
|---|---:|
| Scripts de prueba viva legacy con credenciales literales **antes** | **20** |
| Scripts con credenciales literales **despues** | **0** |
| Archivo extra encontrado por este turno y corregido | **1** (`prueba_muerte_reentrada.gd`) |
| Identificadores de login literales reales en fuente QA ejecutable | **0** |
| Contrasenas literales reales en fuente QA ejecutable | **0** |
| Helper QA creado | **1** (`cliente3d/pruebas/credenciales_qa.gd`) |
| Scripts que parsean OK | **21 / 21** |
| Matriz QA local | **18 / 18 OK** |
| Mutaciones de credenciales | **0** |
| Artefactos de paridad modificados | **0** |
