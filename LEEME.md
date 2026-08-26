# TVP3D

Tibia **7.72** con cámara 3D de verdad: el servidor es
[TVP](https://github.com/TVPV8/TVP) tal cual viene, y el cliente es propio,
hecho en Godot 4.

Empezado el **24 de agosto de 2026**.

---

## Continuidad rápida — leer esto al retomar

El proyecto activo es `C:/Users/dell/TVP3D`. El servidor TVP 7.72 vive en
`servidor/` y el cliente propio de Godot en `cliente3d/`. La cuenta local es
`123456`, la clave es `123456` y el personaje de prueba es `GOD`.

Estado real al **26 de agosto de 2026**:

- cliente 3D funcional con mapa completo precargado, UI en ingles y controles
  clasicos de 3DTIBIA;
- paredes, montanas y relieve de alcantarilla con volumen 3D;
- criaturas del spawn, arboles, arbustos, small fir trees, blueberry bushes,
  mailboxes y signs convertidos temporalmente en cubos 3D con paleta por
  categoria;
- prueba de formas en `0 fallas`; el siguiente frente grande es terminar la
  matriz de opcodes 7.72 y conectar sus estados a UI, efectos y ventanas;
- el inventario detallado de opcodes y su estado de implementacion esta en
  `worklog/OPCODES_772.md`;
- no hay commits disponibles en este entorno: el avance se registra en
  `worklog/EVENTS.jsonl` con el bloqueo `GIT_NO_DISPONIBLE`.

Para abrirlo en Windows:

```powershell
Set-Location C:/Users/dell/TVP3D
& 'C:/Users/dell/3DTIBIA/herramientas/godot/Godot_v4.7.2-stable_win64.exe' --path cliente3d main.tscn
```

Para revisar el mundo sin servidor:

```powershell
& 'C:/Users/dell/3DTIBIA/herramientas/godot/Godot_v4.7.2-stable_win64.exe' --path cliente3d main.tscn -- --mirar 32097,32219,7 --lejos 8 --alto 0.28
```

Pruebas rapidas:

```powershell
& 'C:/Users/dell/3DTIBIA/herramientas/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path cliente3d pruebas/test_controles.tscn
& 'C:/Users/dell/3DTIBIA/herramientas/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path cliente3d pruebas/test_formas_render.tscn
```

La captura grafica no se debe ejecutar con `--headless`: el renderer dummy no
crea viewport y `get_viewport().get_texture()` devuelve `null`. Para capturas
usa el ejecutable normal sin `--headless`.

---

## Arrancar

| Doble clic en | Qué hace |
|---|---|
| `ARRANCAR SERVIDOR.bat` | Levanta el servidor y la base de datos en Docker |
| `JUGAR.bat` | Abre el cliente 3D |
| `PROBAR CONEXION.bat` | Entra al mundo y camina, para ver que todo anda |
| `VER SERVIDOR.bat` | Muestra en vivo lo que dice el servidor |
| `PARAR SERVIDOR.bat` | Lo apaga (los personajes quedan guardados) |

**Cuenta:** `123456` · **Clave:** `123456` · **Personaje:** `GOD`

La primera vez `ARRANCAR SERVIDOR.bat` tarda bastante porque compila el C++
adentro de Docker. Después arranca en segundos.

---

## Qué hay adentro

```
servidor/     TVP sin tocar (clon de github.com/TVPV8/TVP)
cliente3d/    El cliente 3D en Godot 4
herramientas/ Los scripts que sacan datos del servidor
```

Nada del servidor se modifica salvo `config.lua`, que es el archivo de
configuración y está para eso. El código C++ y los scripts Lua quedan como
vienen.

### Puertos

| Qué | Puerto |
|---|---|
| Login | 7171 |
| Juego | 7172 |
| MariaDB | 3371 |
| phpMyAdmin | http://localhost:8071 (root / root) |

No chocan con los otros proyectos: INTEN3D usa 7371-7372 y 3DTIBIA 7271-7275.

---

## Por qué este servidor

TVP es un fork de **The Forgotten Server** que habla **protocolo 7.72**
(`servidor/src/definitions.h:10-12`). Eso importa por tres motivos:

1. **7.72 es el Tibia que se quiere.** No hay que traducir mecánicas de una
   época a otra como pasaba en 3DTIBIA, donde el motor era 15.25 y las reglas
   eran 7.4.
2. **El protocolo es simple.** Sin compresion, sin contador de secuencia ni
   checksum Adler32: sobre `[u16 largo][cuerpo XTEA]` y listo.
3. **Trae el mapa real de Tibia** (`data/world/map.otbm`, 70 MB) y todos los
   monstruos, NPCs y hechizos ya escritos en Lua.

### Lo que se aprovechó de INTEN3D

El cliente arranca como copia del de INTEN3D. Estos archivos pasaron **sin un
solo cambio**, porque TVP usa la clave RSA clásica de OpenTibia (verificado
contra `servidor/key.pem`: el módulo es idéntico):

`red/rsa.gd` · `red/xtea.gd` · `red/entero_grande.gd` · `red/mensaje.gd` ·
`red/adler32.gd`

### Las tres diferencias del 7.72 contra el 8.6

Están las tres en `red/conexion772.gd`, y las tres rompen el login si se
ignoran:

1. **La cuenta es un número de 32 bits, no un texto** — en 7.72 todavía se
   entraba con número de cuenta (`protocollogin.cpp:156`).
2. **No hay saludo del servidor.** En 8.6 había que esperar el paquete `0x1F`
   antes de mandar el login; acá se manda apenas se abre el socket
   (`protocolgame.cpp:338`, no manda nada antes de leer).
3. **No hay checksum adler32.** El sobre es sólo `[u16 largo][cuerpo]`. El
   adler32 aparece recién en Tibia 8.0: acá `addCryptoHeader()` sólo escribe
   el largo (`outputmessage.h:29-31`) y `connection.cpp` no verifica nada.

La tercera costó una hora y vale la pena recordarla, porque **el síntoma
engaña**: si igual se mandan los 4 bytes de firma, todo el paquete queda
corrido, el servidor lee el primer byte de la firma como identificador de
protocolo, no reconoce ninguno (`server.cpp:121-129`) y **cierra la conexión
sin mandar ni un mensaje de error**. Desde el cliente parece que el servidor
estuviera caído, y en el log del servidor no aparece absolutamente nada.

`red/adler32.gd` quedó en la carpeta pero ya no se usa.

### Las trampas del mapa (heredadas, siguen valiendo)

Verificadas en `servidor/src/protocolgame.cpp:616-660`:

- El contador de casillas vacías arranca en **-1**, no en 0
  (`GetMapDescription`, línea 618: `int32_t skip = -1`). Sin eso el mapa sale
  corrido 8 casillas — y engaña, porque la cantidad de bytes da bien.
- Al caminar, la franja nueva no trae coordenadas: van en el `0x6D` de antes.
- Un parser de mapa se verifica con **dos** comprobaciones, no una: (a) que el
  byte siguiente al mapa sea un opcode reconocible, y (b) que tu personaje
  caiga en la casilla que el servidor dice.

---

## Estado

### Estado verificado actual — 26 de agosto de 2026

La referencia vigente es la sección de continuidad al inicio y los avances
posteriores de este documento. El cliente ya tiene mapa completo precargado,
UI en ingles, controles clasicos, casas con mapper semantico, muros y
montanas con volumen, relieve de alcantarilla y cubos prototipo para
criaturas, arboles, arbustos, mailboxes y signs. `test_controles.tscn` y
`test_formas_render.tscn` terminan con `0 fallas`.

Pendiente real:

- terminar la matriz de opcodes 7.72 y conectar todos los mensajes a estado,
  efectos, ventanas y UI;
- sustituir los cubos por modelos 3D authored;
- completar quest log y combate avanzado.

El checklist inmediatamente siguiente conserva el historial del arranque del
proyecto; no usar sus pendientes antiguos para decidir el estado actual.

### Checklist histórico de la primera integración

- [x] Servidor clonado y configurado
- [x] Capa de red del cliente adaptada a 7.72
- [x] Servidor compilado y andando en Docker (`>> TVP3D Server Online!`)
- [x] Login y lista de personajes contra TVP
- [x] Entrada al mundo (2.279 bytes de mundo en el primer mensaje)
- [x] Caminar — el servidor aceptó 3 pasos y canceló 1 con `0xB5` (pared)
- [x] Catálogo de ítems sacado del `items.otb` (4.984 ids de cliente)
- [x] Leer el mapa: 252 de 252 casillas, alineado, y camina en las 4 direcciones
- [x] Mundo dibujado en 3D con los **sprites reales de 7.72**
- [x] **El mapa entero** del disco, no las 18×14 casillas del servidor
- [x] Paredes como cajas de verdad y vegetación con volumen
- [ ] Escaleras: el código de cambio de piso está escrito pero sin probar
- [ ] Animar el caminar (las 3 fases de cada outfit ya están extraídas)
- [ ] Teñir la ropa de los jugadores (la capa 1 del outfit es la máscara)

Probado con `pruebas/prueba_login.gd` y `pruebas/prueba_mapa.gd`, los dos de
punta a punta contra el servidor real.

### Cómo se comprueba que el mapa está bien

Con **dos** cosas, no una — y las dos hacen falta:

1. Que después del mapa siga un mensaje que el cliente reconoce. Atrapa los
   errores de un byte.
2. Que tu propio personaje caiga en una casilla que existe. Atrapa los
   corrimientos de casillas enteras, que la primera no ve, porque la cantidad
   de **bytes** puede dar bien igual.

`pruebas/prueba_mapa.gd` hace las dos, más una tercera (que el piso venga
casi entero) y después camina en cruz verificando cada paso.

---

## Si el cliente dice que no puede entrar

Antes de sospechar del protocolo, mirá **el arranque del servidor** con
`VER SERVIDOR.bat`. Tiene que decir:

```
> Loading data/world/map.otbm
> Map size:65000x65000.
>> TVP3D Server Online!
```

### El caché del mapa que se vacía (pasó el 24/08)

Si en cambio dice esto, el mundo del servidor está vacío:

```
> INFO: Live Map Data is being used.
> Live Map loading time: 0 seconds.
Failed to load map-spawn.xml: File was not found
Failed to load map-house.xml: File was not found
```

TVP guarda una copia del mapa en `gamedata/map.tvpm` para arrancar rápido.
Debería pesar unos 70 MB; quedó en **43 bytes**. Sin mapa no hay pueblos, y
al entrar el servidor rechaza al personaje con `unknown town`
(`iologindata.cpp:266-270`) — desde el cliente eso se veía como
"Connection lost", que no ayudaba nada.

**Por qué se truncaba:** al apagarse, el servidor tarda unos 14 segundos en
guardar mapa y casas. Docker le da 10 por defecto y después lo mata. Cada
apagado del contenedor partía el archivo al medio.

**Arreglado con dos cosas:**

- `servidor/docker-compose.override.yml` sube la espera a 120 s. Es un
  archivo aparte que Docker Compose lee solo, así no hay que tocar el
  `docker-compose.yaml` del repo. Esto también protege el guardado de los
  personajes y las casas.
- `enableMapDataFiles = false` en `config.lua`, que apaga el caché. Cuesta
  unos 30 segundos de arranque y hace que los objetos tirados en el suelo
  vuelvan a su lugar en cada arranque. Se eligió igual porque la falla
  contraria es peor y silenciosa: el mundo desaparece sin avisar. Para
  volver a activarlo, es esa línea.

### El puerto fantasma de Docker

Si al arrancar dice `ports are not available: ... 7171`, el contenedor ya no
existe pero `com.docker.backend` sigue reteniendo el puerto. Se ve con:

```powershell
Get-NetTCPConnection -State Listen -LocalPort 7171 | %{ (Get-Process -Id $_.OwningProcess).ProcessName }
```

Se destraba reiniciando Docker Desktop (bandeja → Restart). Ojo con el otro
lado de la misma moneda: **puerto abierto no quiere decir servidor vivo**.
La única prueba que vale es `PROBAR CONEXION.bat`.

---

## El servidor se apaga solo una vez por día

No es una falla: TFS trae un "server save" que guarda todo y **apaga el
proceso** (`servidor/data/scripts/globalevents/serversave.lua:4`). Es de
fábrica y es fiel al Tibia de la época.

La hora se configura en `config.lua` con `serverSaveTime`, y **va en UTC**,
que es la zona del contenedor. Estaba en `04:30`, que acá son las 22:30 — o
sea, justo en medio de las pruebas. Se movió a `10:30` UTC = **04:30 de acá**.

Si algún día el cliente dice "no contesta", lo primero es mirar si el
contenedor `server` está apagado; se levanta de nuevo con
`ARRANCAR SERVIDOR.bat`.

### El catálogo de ítems

`herramientas/extraer_items772.py` lee el `items.otb` del servidor y escribe
`cliente3d/assets/items772.json`: 4.984 ids de cliente con sus banderas.

Hace falta por algo que no se ve venir: cuando el servidor describe una
casilla manda el id del ítem (2 bytes) y **a veces uno más** — la cantidad si
se apila, el color si es un líquido (`networkmessage.cpp:95-106`). No hay
ninguna marca que avise cuál de los dos casos es: el cliente tiene que
saberlo de antemano. Si se equivoca en **un solo ítem**, todo lo que viene
después queda corrido.

Los líquidos son la trampa fina, porque son fáciles de olvidar: son los
grupos `ITEM_GROUP_SPLASH` (11) y `ITEM_GROUP_FLUID` (12) de
`itemloader.h:8`, no una bandera. Quedaron 81 apilables y 35 líquidos.

### Los sprites

`herramientas/extraer_sprites772.py` lee el `Tibia.dat` y el `Tibia.spr`
oficiales de 7.72 (están en `cliente3d/assets/cliente772/`) y escribe 5
láminas de 2048x2048 más un `indice.json`: **4.913 ítems y 156 outfits**.

**Cómo se supo que son los archivos correctos:** el `.dat` dice que su último
ítem es el **5089**, que es exactamente el id de cliente más alto que usa el
`items.otb` del servidor. Firma `0x439D5A33`. Además dos copias que había en
la máquina, de orígenes distintos, dieron el mismo MD5 — o sea que son los
originales sin tocar.

Van en láminas y no en un PNG por ítem porque Godot importa cada archivo del
proyecto al abrirlo: 5.000 PNGs sueltos son 5.000 importaciones.

### El mapa entero

El servidor **no manda el mapa entero**: manda una ventana de 18×14 casillas
alrededor tuyo y nada más (`protocolgame.cpp:1699`, con `maxClientViewportX/Y`
= 8 y 6). Eso es así en el protocolo de Tibia y no se puede pedir de otra
forma. Sin resolverlo, el mundo se corta a ocho casillas y parece una balsa
flotando en el vacío.

La solución es leer el mismo `.otbm` que usa el servidor. Queda un reparto
claro:

| De dónde | Qué |
|---|---|
| El `.otbm` del disco | El decorado: pisos, paredes, árboles — lo quieto |
| El servidor en vivo | Las criaturas y lo que cambia |

`herramientas/extraer_mapa772.py` convierte el `.otbm` de 70 MB en trozos de
64×64 casillas: **7,8 millones de casillas, 576 trozos, 45 MB**. El cliente
(`red/mapa_disco.gd`) lee del disco sólo los trozos que tiene cerca y suelta
los que quedaron lejos, así nunca carga los 45 MB.

Si el servidor ya habló de una casilla, mandan **sus** datos: son los de
ahora. El disco es de cuando se guardó el mapa.

**Cómo se verificó:** se dibujó el mismo pedazo de mapa desde el disco y
desde el servidor y salieron idénticos, casilla por casilla.

### Cómo se ve en 3D

| Qué | Cómo se dibuja |
|---|---|
| Suelo | Una losa acostada con su textura |
| Pared (tapa y no deja ver) | Una **caja** de verdad; la textura va en las caras verticales y las tapas quedan limpias |
| Arbustos, árboles, objetos | Dos planos **cruzados** en ángulo recto |
| Criaturas | Una lámina que gira siguiéndote (la técnica de Doom) |

Las cajas son las que hacen que se vea 3D de verdad: una pared con volumen se
ve como pared desde cualquier ángulo, y una lámina no.

**Por qué cruces y no láminas giratorias para la vegetación:** adentro de un
MultiMesh el modo billboard de Godot no orienta bien cada copia y los
arbustos quedan tirados de costado. Una cruz no depende de la cámara. Para
las criaturas sí se usa billboard, porque son pocas y van en nodos sueltos.

**Por qué MultiMesh:** a 36 casillas a la redonda hay unas 13.000 cosas
dibujadas. Un nodo por cada una arrastra el cuadro por los suelos. Agrupadas
por dibujo y forma quedan **299 nodos y 60 cuadros por segundo**.

### Ver cualquier rincón del mundo sin caminar hasta ahí

```
godot --path cliente3d main.tscn -- --mirar 32097,32219,7 --lejos 8 --alto 0.28
```

Dibuja el mapa del disco en ese punto, sin servidor y sin personaje.
`--lejos` es la distancia de la cámara y `--alto` cuánto mira desde arriba.

### Dos trampas del dibujado en 3D

1. **`AtlasTexture` no sirve en 3D.** En 2D recorta bien, pero un material 3D
   ignora la región y estira la lámina entera sobre cada cara. El síntoma es
   inconfundible: cada casilla del piso muestra el mosaico completo de miles
   de dibujos. Lo que sí anda es pasar la lámina entera como textura y mover
   el recorte con `uv1_scale` / `uv1_offset`.
2. **La cámara no puede mirar muy desde arriba.** Los dibujos de Tibia son de
   frente, así que todo lo que no es suelo se dibuja como una lámina parada
   que gira siguiendo a la cámara (la técnica de Doom). Desde muy arriba esas
   láminas se ven de canto y el mundo parece hecho de rebanadas. Con la
   cámara baja se ve como corresponde.
---

## Avance verificado: objetos dinamicos y quest de la Doublet (2026-08-25)

Este avance quedo probado contra el servidor local, no es una suposicion.

### Doublet: datos reales del mapa

- El barril de la quest esta en `(32084,32181,8)`.
- Su id de servidor es `1774` y su id de cliente es `2523`.
- La casilla tiene debajo el suelo servidor `405` con AID `1224`.
- El script del servidor para AID 1224 entrega el objeto `2485` (doublet).
- El destino de prueba para apartar el barril es `(32084,32182,8)`.

### Protocolos implementados

- `0x78` solicita mover una cosa; `red/conexion772.gd` ya serializa origen,
  sprite, stackpos, destino y cantidad.
- El estado vivo procesa la respuesta como `0x6C` (sale de la casilla de
  origen) y `0x6A` (entra en la casilla de destino).
- La prueba `pruebas/prueba_barril_doublet.gd` exige ambos cambios y devuelve
  el barril a su lugar original.

### Navegacion: evidencia y correcciones

El primer recorrido usaba `queryadd_walkable`. Esa bandera no basta para
caminar: por ejemplo, `(32086,32203,7)` tiene dustbin cliente `2526`,
`queryadd_walkable=true`, pero `walkable=false` y `blocking=true`. El servidor
rechazo entrar alli con `There is not enough room`.

La prueba ahora usa un paso cardinal por vez (`0x65`-`0x68`) y espera la
confirmacion del servidor antes de mandar el siguiente. Con esa correccion
recorrio 26 pasos hasta la escalera de `(32096,32190,7)` sin rechazos.

Al bajar por esa escalera, el servidor coloca al personaje en
`(32096,32191,8)`, una casilla al sur. Ese detalle ya esta registrado en el
arnes; no se debe asumir que conserva `(32096,32190,8)`.

### Estado historico: antes del cierre en vivo

En ese punto del trabajo el barril **aun no tenia una ejecucion viva exitosa**. La sala de la Doublet
no esta conectada por la escalera de `(32096,32190,7)`: el mapa muestra una
entrada por la escalera/ladder de la zona de la quest. El siguiente paso es
subir y usar la ladder de servidor `1386` (cliente `1948`) en
`(32081,32181,7)`; su casilla inferior correspondiente es `(32080,32181,8)`.
El XML del servidor marca esa ladder como `forceuse=true`.

El criterio que se esperaba ver era:

```
[doublet] moviendo barril ...
[doublet] casilla ... por 0x6C
[doublet] casilla ... por 0x6A
[doublet] OK: barril movido y restaurado
```

Ese criterio quedo satisfecho en la seccion de cierre verificado que sigue.

### Actualizacion posterior de la escalera

La prueba viva confirmo que, desde `(32096,32191,8)`, enviar norte por la
escalera deja al personaje en `(32096,32189,7)`. La coordenada intermedia
`(32096,32190,7)` es la pieza grafica de la escalera, no la posicion final
del jugador. El arnes ya espera `(32096,32189,7)` antes de buscar la
trampilla de la Doublet.
### Correccion de la entrada de la Doublet y prueba en vivo

La hipotesis anterior de usar la escalera oriental como entrada de la Doublet quedo corregida despues de revisar el mapa y los items del servidor. La entrada real es la trampilla server 409 / client 412 en `(32080,32181,7)`; el personaje se coloca en `(32080,32182,7)` y avanza al norte para entrar en `(32080,32181,8)`.

La prueba en vivo del 2026-08-25 ya alcanzo la sala y ejecuto correctamente el primer movimiento: el `0x78` movio el barril de `(32084,32181,8)` a `(32084,32182,8)`, seguido por un `0x6C` en el origen y un `0x6A` en el destino. La restauracion tambien fue enviada al servidor, pero el estado local del cliente no retiro correctamente el barril en el segundo `0x6C` porque la interpretacion del stackpos no coincide con el orden local de objetos. El quest no se marca completo hasta validar la ida y vuelta en el cliente.

### Cierre verificado de la prueba Doublet

Se corrigio el manejo cliente del `0x6A` para insertar objetos de abajo antes del bloque de objetos de abajo existente, igual que `Tile::addThing` y `Tile::getThing`. Antes se hacia `append()`, por lo que el cliente calculaba stack 2 mientras el servidor usaba stack 1 al colocar el barril delante del frasco roto.

La ejecucion viva posterior del 2026-08-25 termino con:

```
[doublet] moviendo barril stack=1 desde (32084,32181,8) hacia (32084,32182,8)
[doublet] casilla (32084,32181,8) por 0x6C; barril=false
[doublet] casilla (32084,32182,8) por 0x6A; barril=true
[doublet] moviendo barril stack=1 desde (32084,32182,8) hacia (32084,32181,8)
[doublet] casilla (32084,32182,8) por 0x6C; barril=false
[doublet] casilla (32084,32181,8) por 0x6A; barril=true
[doublet] OK: barril movido y restaurado
```

El reporte `cliente3d/generated/reports/doublet_barrel.json` queda con `passed=true`, `restored=true` y cuatro eventos (`0x6C`, `0x6A`, `0x6C`, `0x6A`). La prueba de la mecanica de mover y devolver el barril de la quest Doublet queda verificada en vivo; el siguiente trabajo puede continuar con la entrega del item Doublet/AID 1224 o con otra mecanica de quest.

### Recompensa Doublet verificada en vivo

Se agrego al estado del cliente el seguimiento de inventario para los mensajes `0x78` y `0x79`, y se creo el arnes `cliente3d/pruebas/prueba_recompensa_doublet.tscn`. La prueba usa la casilla de madera client `408` en `(32084,32181,8)` con `0x82`; el servidor la identifica por `AID 1224` y entrega el item server `2485`, client `3379`.

La ejecucion viva del 2026-08-25 termino con:

```
[doublet-reward] usando suelo client=408 en (32084, 32181, 8)
[doublet-reward] OK: AID 1224 entrego el Doublet en ranura 10
[doublet-reward] mensaje servidor: You have found a doublet.
```

El reporte `cliente3d/generated/reports/doublet_reward.json` queda con `passed=true`, recompensa server `2485`, client `3379` y ranura de inventario `10`. Despues de la entrega se repitio la prueba del barril y volvio a terminar con `OK: barril movido y restaurado`; la regresion confirma que el parser de inventario no rompio la mecanica anterior.

### Controles clasicos de Tibia portados desde 3DTIBIA

La escena principal de `cliente3d/mundo3d.gd` ahora sigue el modelo que ya usa
3DTIBIA:

- Clic izquierdo sobre una casilla libre: caminar hacia ella al soltar.
- Clic izquierdo sobre un objeto movible y movimiento superior a 3 px:
  inicia el arrastre y al soltar envia `0x78` con `client_id`, `stackpos`,
  destino y cantidad del objeto. Un clic sin mover conserva el comportamiento
  normal de caminar.
- Clic derecho quieto sobre un objeto: envia `0x82` para usarlo.
- Clic derecho mantenido y movido: gira la camara; el umbral es de 3 px.
- Clic izquierdo + clic derecho: inspecciona/look la casilla.
- Shift + clic izquierdo: abre el inspector de la casilla.
- Rueda del mouse: acerca o aleja la camara.

La seleccion de objetos movibles consulta el estado vivo y el catalogo de
items; no depende de una lista fija del barril. El parser de items ahora
conserva `movible`, `levantable` y `contenedor` para que esa decision use los
metadatos reales.

Validacion realizada el 2026-08-25:

- `test_controles.tscn`: `0` fallas.
- Carga headless de la escena principal: sin errores de parseo.
- `prueba_barril_doublet.tscn`: movio y restauro el barril en vivo, con
  `passed=true` y `restored=true`.
- El arrastre de objetos queda pendiente al presionar y solo se activa al
  mover el mouse, igual que `ZonaSuelo._get_drag_data` de 3DTIBIA.
- La ventana grafica fue relanzada con estos cambios para probar la
  interaccion manual.

### Interfaz y casas portadas desde 3DTIBIA

Se tomo la organizacion funcional de `3DTIBIA/motor3d/ui/interfaz.gd`, pero
se adapto al estado vivo de TVP3D en vez de copiar dependencias del simulador:

- ventanas reutilizables con barra de titulo plegable y arrastrable;
- columna izquierda con personaje, barras HP/MP, skills, capacidad y minimapa;
- panel derecho con las diez ranuras de equipo, paper-doll, iconos del atlas
  7.72 y cantidades de pilas;
- panel Vitals con barras reales, ventana Target y Battle con ataque/seguimiento;
- chat inferior para mensajes `0xB4`, habla `0xAA` y envio de `0x96`;
- arrastre de inventario a otra ranura o al mundo usando `0x78`, y clic derecho
  para usar un item del equipo con `0x82`.

Los mensajes de contenedores `0x6E`-`0x72` ya se conservan en
`estado_mundo.gd`: abrir una mochila crea una ventana con ranuras, la ventana
se puede mover, cerrar con `0x87` y acepta drag-and-drop entre inventario,
contenedores y suelo. El minimapa ahora pinta el mapa real con los colores
`color_mapa` del catalogo, usa el mapa completo del disco, tiene zoom con la
rueda y acepta map-click para caminar. Ese map-click construye una ruta
cardinal: no envia diagonales que el jugador no haya pedido; las diagonales
siguen reservadas para Q/E/Z/C y el numpad.

`mapa_disco.gd` precarga los 576 trozos del mapa (`mapa.bin`, unos 45.7 MiB)
antes de entrar al mundo. En la prueba del 2026-08-25 la lectura completa
tardo 9.11 s. El render 3D conserva una ventana alrededor de la camara por
rendimiento, pero los datos de todo el mapa quedan cargados y consultables;
el minimapa y las rutas ya no dependen de batches que se expulsen al moverse.

Los paquetes `0xA0` y `0xA1` ahora se conservan como estadisticas y
habilidades para que la interfaz no tenga que inventar valores.

Para las casas se copio la idea importante de 3DTIBIA: un muro es volumen,
no una postal vertical. TVP3D ya agrupaba las instancias por `MultiMesh`; ahora
las formas `CAJA` usan una textura maciza de pared (`assets/paredes`) solo en
las caras verticales, con tapas limpias, repeticion pixel-art, orientacion por
vecinos, grosor y altura ajustable. Los pisos por encima del jugador siguen
ocultos para poder entrar a las casas.

Validacion adicional del 2026-08-25:

- carga headless del proyecto y de `main.tscn`: sin errores;
- `test_controles.tscn`: `0` fallas, incluyendo una ruta de map-click sin
  diagonales;
- precarga completa: `576` trozos en `9.11 s`;
- visor visual `--mirar 32097,32219,7 --captura-tvp`: HUD y casas revisados
  con renderer real; minimapa con datos reales visible;
- `prueba_barril_doublet.tscn`: `passed=true`, `restored=true` despues de
  restaurar el fixture persistente que habia quedado en `(32083,32183,8)`;
- utilidades de diagnostico `prueba_localizar_item.tscn` y
  `prueba_restaurar_barril.tscn` documentan esa recuperacion sin tocar la
  recompensa ni las storages de la quest.

Queda pendiente para la siguiente pasada: quest log y paneles avanzados de
combate. El minimapa, contenedores, Battle basico y map-click ya estan
conectados; no se marca como terminado lo que aun no tiene una accion de red
completa.

### Paridad visual y lenguaje del cliente

La interfaz se comparo contra una captura real de `3DTIBIA` y se ajusto para
seguir su composicion de cliente clasico: columnas de 190 px, Skills y VIP a
la izquierda, Minimap/Health/Equipment/Battle a la derecha y Chat centrado
abajo. Se eliminaron el paper-doll ASCII y los paneles grandes de estilo web.

- paleta marron/negro, marcos y barra de titulo compactos de 3DTIBIA;
- ranuras de equipo de 34 px con los dibujos vacios reales de
  `assets/ui/slots`;
- Skills con nombres en ingles, barras de progreso y las diez habilidades
  visibles del cliente base;
- Chat con las pestañas `Default`, `Loot` y `Server Log`;
- textos, tooltips, inspector, mensajes de movimiento y acciones en ingles,
  alineados con el servidor/base de Tibia.

Capturas de referencia y resultado: `cliente3d/captura_3dtibia.png` y
`cliente3d/captura_tvp.png`. La prueba headless de `main.tscn` y la prueba de
controles siguen pasando; `test_controles.tscn` queda en `0` fallas.

### UI reconstruida con el video de Mythera como referencia definitiva

El video local entregado por el usuario (`Videos/Grabaciones de pantalla/
Grabación de pantalla 2026-08-23 044716.mp4`) reemplaza la captura estática
como referencia visual principal. La interfaz actual conserva el estado vivo
de TVP3D, pero adopta la composición y el flujo del cliente clásico:

- columna izquierda apilada: `VIP`, `Bestiary Tracker`, `Skills` y
  `Loot Analyzer`;
- columna derecha exterior: `Minimap`, barras HP/MP, `Actions`, `Stash` y
  `Equipment`;
- columna derecha interior reservada para `Backpack` y contenedores que se
  abren durante el juego;
- arrastre de la barra de título para reordenar paneles entre columnas o
  cambiar su orden, igual que en 3DTIBIA;
- `Battle` permanece cerrado cuando no hay criaturas y se abre desde la barra
  `Actions`, para no ocupar espacio sin contenido;
- chat inferior con `Default`, `Server Log`, `Help`, `Loot`, `Trade` y
  `Chat off`;
- paleta oscura gris/negra, marcos compactos, ranuras pixel-art y todos los
  textos propios del cliente en inglés.

La captura `cliente3d/captura_tvp.png` fue regenerada con renderer gráfico
después de esta pasada. Validación: HUD sin errores de parseo, mapa completo
precargado en 576 trozos y `test_controles.tscn` con `0` fallas.

### Video detallado y giro en sitio

Se recibió una segunda referencia de 170 segundos en
`Desktop/Grabación 2026-08-25 214755.mp4`, con resolución 1916x1122. Se
extrajeron 85 cuadros en `worklog/video_ref_detailed` para revisar estados
reales de la interfaz y sus cambios de paneles.

Los movimientos normales ya estaban definidos en `TECLAS_DIRECCION` y en
`sprites772.gd`; faltaba enlazar el gesto clásico de girar sin caminar. Ahora
`Ctrl+W`, `Ctrl+A`, `Ctrl+S` y `Ctrl+D` cambian únicamente el facing del
personaje, respetando la orientación de la cámara y las cuatro direcciones del
outfit 7.72. No se envía opcode ni se modifica la casilla del personaje.

Validación posterior: `mundo3d.gd` compila y `test_controles.tscn` conserva
`0` fallas.

### Mapper semántico para la reconstrucción 3D

La conversión del mundo 2.5D a geometría 3D ya tiene un inventario basado en
datos reales, no en una lectura visual aproximada. El script
`herramientas/mapear_mundo_3d.py` cruza `map.otbm`, `items.otb/items.xml`,
`items772.json` y `map-house.xml`.

La salida está en `cliente3d/generated/world_mapper/`:

- `report.json`: 7,786,904 tiles, 8,385,638 objetos y conteos semánticos;
- `houses.json`: 862 casas con nombre oficial, entrada, renta, town, pisos,
  bbox real, puertas y categorías de objetos;
- `house_tiles.jsonl`: huella completa de cada casa por `x,y,z`;
- `world_objects.jsonl`: objetos modelables en formato compacto.

El mapa reconoce, entre otras categorías, `ground`, `wall`, `door`, `stair`,
`mailbox`, `sign`, `window`, `roof`, `crate`, `furniture`, `container`,
`interactive` y `nature`. La validación cubre las 862 definiciones oficiales
de `map-house.xml`; no quedó ninguna casa con `house_id` sin definición.

Esto deja lista la base para reemplazar cada categoría por escenas/modelos 3D
reales y para construir casas usando su huella y sus pisos exactos, antes de
volver a tocar el renderer completo.

### Primera vertical slice 3D: Spiritkeep

Se implementaron `cliente3d/mundo/catalogo_modelos_3d.gd` y
`cliente3d/mundo/casa_mapper_3d.gd`. El catalogo separa la geometria del
lector del mapa y crea mallas volumetricas para ground, wall, door, window,
stair, crate, mailbox, sign, roof, container, furniture, nature, structure e
interactive, con metadatos y colisiones por objeto.

El mapper lee la huella completa desde `house_tiles.jsonl`, usa el nombre
oficial de `houses.json`, calcula la orientacion de muros por vecinos y coloca
las mallas en coordenadas Tibia reales. La escena reproducible esta en
`cliente3d/pruebas/casa_3d.tscn` y se lanza con `VER SPIRITKEEP 3D.bat`.

Validacion grafica: Spiritkeep carga 565 tiles y 803 objetos en cinco pisos;
la captura queda en `cliente3d/casa_spiritkeep_3d.png`. El resultado ya es
geometria 3D con colisiones, no billboards. Durante la validacion se corrigio
la clasificacion de `stone tile`, `stone railing` y `wall lamp`, que ahora son
ground, structure y decoration respectivamente.

### Muros con altura y animacion idle

Se corrigio `cliente3d/mundo3d.gd`: algunos muros 7.72 tienen `suelo=true`
y tambien `bloquea/frena_vista=true`. El renderer ahora prioriza el bloqueo
estructural y los convierte en cajas verticales con altura y espesor; ya no
los dibuja como losas. La captura de comprobacion en las coordenadas
`(32090,32204,7)` queda en `cliente3d/captura.png`.

La animacion del personaje ahora solo avanza mientras existe un movimiento
visual confirmado. En reposo queda en el frame idle, y `Ctrl+W/A/S/D` cambia
el facing sin activar la animacion de caminar. `test_controles.tscn` mantiene
0 fallas.

### Montanas 3D y referencia visual de Tibia

Se recibieron dos capturas de Mythera 7.4 para comparar el resultado: la
entrada de la tienda de Obi y el terreno que el cliente original llama
`mountain`. La comparacion confirmo que esos tiles no son paredes rectas:
forman una superficie de roca elevada, con una meseta continua y pendientes
solo en el borde del macizo.

La causa de las aletas grises era una prioridad incorrecta en
`cliente3d/mundo3d.gd`: los mountain del DAT tambien traen
`bloquea/frena_vista`, asi que la correccion anterior los habia convertido en
cajas de pared. Ahora `Forma.MONTANA` se decide por la semantica del nombre y
queda separada de `Forma.CAJA`. Las cuatro casillas vecinas calculan el perfil
del terreno: los lados que continuan el macizo llegan hasta la meseta y los
otros lados bajan con una pendiente.

La malla es volumetrica y low-poly, usa textura rocosa pixel-art del cliente
(`pared_01128.png`), colores de roca por cara y no usa billboard. Se elimino
la separacion entre tiles contiguos para que el resultado no parezca una
cuadricula de plataformas. La captura validada queda en
`cliente3d/captura.png`; la carga completa del mapa termino en 8.72 s y
`test_controles.tscn` conserva `0` fallas.

Este es el primer terreno 3D procedural de montana. La siguiente mejora
visual sera sustituir sus perfiles genericos por variantes de roca authored
por familia de tile, manteniendo esta lectura semantica del mapa.

### Alcantarilla: relieve de ladrillo

Se uso la captura de Mythera 7.4 como referencia para el piso subterraneo.
En `z=8+`, los `stone wall` 373-384 del DAT son bordes de relieve del tunel,
no muros de casa. Antes entraban como cajas grises y formaban bloques altos.

Ahora esos bordes usan la misma malla 3D de pendientes que las montanas, pero
con la textura rojiza de ladrillo (`pared_01270.png`) y una altura menor. El
relleno `earth` 101 vuelve a ser suelo marron, y `stone floor` 436 conserva
su tratamiento normal para no convertir interiores completos en ladrillo.
La regla esta limitada a pisos subterraneos: los muros estructurales y la
superficie exterior no cambian.

La captura validada de la alcantarilla queda en `cliente3d/captura.png`.
Validacion: carga completa de 576 trozos en 7.36 s, sin errores de runtime y
`test_controles.tscn` con `0` fallas.

### Prototipos cubicos para criaturas y objetos modelables

Las criaturas que llegan desde los spawns ahora se dibujan como cubos 3D
solidos, excepto el jugador local, que conserva su outfit para no perder la
referencia de control. El estado de cada criatura mantiene id, nombre,
apariencia, direccion y posicion; por eso el cubo es solo una representacion
visual temporal y mas adelante se puede reemplazar por una escena de monster
sin cambiar el protocolo, el spawn ni el combate.

Tambien se convirtieron en `Forma.PROTOTIPO` los objetos del mapa que se van a
modelar primero: `tree`, `bush`, `shrub`, `fir`, `blueberry`, `mailbox` y
`sign` (incluidos `small fir tree`, `blueberry bush` y `street sign`). Cada
familia usa una paleta distinta y dimensiones derivadas del footprint del
sprite, pero ya ocupa volumen real en 3D. Se mantienen intactos suelo,
montanas, muros, escaleras y el resto de la lectura semantica.

La prueba `cliente3d/pruebas/test_formas_render.gd` valida las categorias
`tree`, `small fir tree`, `blueberry bush`, `mailbox` y `sign`.
