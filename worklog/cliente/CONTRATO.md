# Contrato: cliente

Version: 1.13.0
Estado: PUBLICADO
Propietario: cliente
Depende de: modelo-comun 1.0.0, protocolo-red 1.1.0, assets 1.3.0

## Monstruos con volumen (TVP 7.72)

- El renderer consume cuatro facings y fases del atlas original sin editarlo.
- Las apariencias 21/56/34/39 tienen modelos anatomicos iniciales,
  colores muestreados del sprite, orientacion N/E/S/W y tres poses 3D.
  Se incorpora la familia de aranas: 30 Spider, 36 Poison Spider,
  38 Giant Spider, 208 The Old Widow y 219 Tarantula, con ocho patas,
  abdomen, cefalotorax y poses segun las fases disponibles en el atlas.
  La paleta original de fase cero se conserva durante la animacion.
  Se incorporan 27 Wolf, 52 Winter Wolf y 3 War Wolf con cuatro patas,
  hocico, orejas y cola; tres poses y RGB originales estables por variante.
  Se incorporan 16 Bear, 42 Polar Bear y 123 Panda: cuerpo robusto,
  cuatro patas, orejas redondas y patrones originales por variante.
  Se incorporan 28 Snake y 81 Cobra con cuerpo ondulante, tres poses y
  capucha volumetrica para Cobra. Snake conserva un perfil bajo sobre suelo.
  Se incorporan 26 Rotworm (seis poses de apertura de boca), 82 Larva,
  83 Scarab y 79 Ancient Scarab (tres poses), con anatomia y RGB originales.
  Veintiuna apariencias tienen modelo; las otras 123 quedan pendientes.
  Las pruebas de interseccion de siluetas no se habilitan en produccion.
- Recursos derivados y generador viven en `cliente3d/propio/monstruos3d/`.
  No cambian formatos de assets ni red; son recursos del renderer.
- Solo IDs de monstruo (0x40000000..0x7fffffff) usan estas mallas.
  Jugadores, NPCs y apariencias ausentes conservan su representacion actual.
- Posicion, piso, apariencia, seleccion y retirada siguen al servidor.
  La malla no agrega colisiones ni cambia reglas de combate.
- Se comparten mallas por apariencia/fase; la camara no gira el modelo.
- La reconstruccion interpreta siluetas; no recupera anatomia oculta exacta.
- Un visor local permite comparar sprites y volumen sin servidor.
  Las pruebas del componente viven junto al renderer.

## Proposito

Presentar el mundo propio de TVP3D en 3D, enviar intenciones de movimiento y
mostrar unicamente posiciones confirmadas por el servidor. Este carril no
decide caminabilidad, ocupacion, existencia ni resultado de una accion.

## Escena y conexion

- Escena propia: `res://propio/cliente_3d.tscn`.
- Host por defecto: `127.0.0.1`; se puede sustituir con `TVP3D_HOST`.
- Puerto por defecto: `7277`; se puede sustituir con `TVP3D_PUERTO`.
- La conexion usa exclusivamente `protocolo-red` v1 y su `StreamPeerTCP`.
- Al conectar se envia `HELLO` una sola vez por intento, con un nombre entre
  1 y 24 caracteres.
- Al recibir `WELCOME` valido se carga el mapa y se pasa a `EN_MUNDO`.
- Al recibir un `STATE` se reemplaza el conjunto visual completo por las
  entidades confirmadas, sin interpolar la posicion logica ni crear entidades
  locales.

## Estados del cliente

| Estado | Evento | Siguiente |
|---|---|---|
| `DESCONECTADO` | temporizador de reintento | `CONECTANDO` |
| `CONECTANDO` | TCP conectado | `CONECTANDO` + `HELLO` |
| `CONECTANDO` | `WELCOME` valido | `EN_MUNDO` |
| `CONECTANDO` | error TCP/protocolo | `DESCONECTADO` |
| `EN_MUNDO` | `STATE` | `EN_MUNDO` + reemplazo visual |
| `EN_MUNDO` | `ERROR` | `EN_MUNDO` + aviso, sin mutar posicion |
| `EN_MUNDO` | cierre TCP | `DESCONECTADO` |
| cualquier estado | `ESC` | cierre ordenado |

Tras una perdida de conexion, el cliente limpia el estado vivo y reintenta
con una pausa fija. No conserva como confirmado un jugador desconectado ni
reutiliza el buffer de un intento anterior.

## Entrada

- `W`, flecha arriba: `MOVE {dx:0,dy:-1}`.
- `D`, flecha derecha: `MOVE {dx:1,dy:0}`.
- `S`, flecha abajo: `MOVE {dx:0,dy:1}`.
- `A`, flecha izquierda: `MOVE {dx:-1,dy:0}`.
- Se envia como maximo una intencion cada `0.18` segundos.
- El cliente no cambia `_mi_pos` al enviar; solo lo cambia con `STATE` que
  contenga su id.
- Un `ERROR` conserva la posicion y muestra el motivo recibido.

## Representacion

- El mapa del `WELCOME` se valida antes de renderizarlo: version, origen,
  dimensiones, celdas, rangos y tipos deben pertenecer al modelo comun.
- Se representan los siete tipos cerrados del modelo: suelo, pared, agua,
  arbol, roca, decoracion y escalera.
- Las entidades de `STATE` se renderizan desde sus posiciones Tibia y se
  distinguen por id local; el jugador propio no se inventa si no aparece en
  el estado recibido.
- La camara sigue la ultima posicion confirmada del jugador local.

## Errores y limites

| Codigo | Accion del cliente |
|---|---|
| `MAPA_RECIBIDO_INVALIDO` | No renderizar el mapa; mostrar aviso y cerrar el intento |
| `PROTOCOLO_INVALIDO` | Descartar el intento, limpiar buffer y reconectar |
| `ERROR` del servidor | Mostrar `mensaje`; no cambiar estado logico |
| `CONEXION_PERDIDA` | Limpiar entidades y reconectar |
| `PERFIL_INCOMPATIBLE` | Rechazar el `WELCOME` y no reinterpretar sus datos |

El cliente no expone credenciales, tokens, claves ni rutas privadas. El
adaptador `conexion772.gd` del cliente legacy es independiente y no se usa
para la escena propia.

## Muerte y reentrada del cliente TVP 7.72

Esta seccion aplica al cliente jugable de la rama TVP 7.72 (`mundo3d.gd` y
`cliente3d/ui/`), no a la escena propia del perfil JSON. La rama del servidor
no tiene `sendDeath` ni `sendReLoginWindow`: el cliente no espera, no inventa
y no acepta ningun opcode de muerte.

La unica fuente de muerte es la senal `jugador_muerto(posicion)` que emite
`cliente3d/red/estado_mundo.gd` cuando el `0x6C` retira a `mi_id` con las
stats autoritativas mas recientes en vida cero, tal como define
`protocolo-red` 1.1.0. El cliente no vuelve a inferir muerte por su cuenta,
no la deduce de la barra de vida, del corpse ni de un mensaje de texto.

Al recibir la senal, y una sola vez por sesion:

| Paso | Obligacion |
|---|---|
| 1 | Marcar la sesion como muerta y bloquear toda intencion nueva: teclado de movimiento, map-click, ataque, uso, arrastre y chat |
| 2 | Cancelar el uso-con pendiente, el arrastre pendiente y el objetivo visual |
| 3 | Ocultar la interfaz de juego y mostrar la pantalla de reentrada |
| 4 | Enviar logout `0x14` por la misma conexion |
| 5 | Esperar el cierre del socket sin volver solo al formulario de cuenta |
| 6 | Volver al selector de personajes unicamente cuando el jugador lo pide |

El paso 4 usa `enviar_logout()` del adaptador. `ProtocolGame::logout`
(`servidor/src/protocolgame.cpp:303-336`) encuentra al jugador ya removido por
`Game::removeCreature` y llama `disconnect()`; el cliente no debe cerrar el
socket por su cuenta para provocar ese camino ni tratar el cierre como error
de red.

La pantalla de reentrada muestra el texto `You are dead.`, que es el mismo que
el servidor envia por `0xB4` desde
`servidor/data/scripts/creaturescripts/playerdeath.lua:12`, y una accion unica
para volver al selector de personajes. No promete revivir en el templo, no
muestra perdidas ni estadisticas: esas consecuencias son autoridad del
servidor y solo se ven al reingresar.

Al aceptar la reentrada, el cliente limpia el estado vivo de la sesion, cierra
la conexion si el servidor todavia no lo hizo y pide de nuevo la lista de
personajes con las credenciales que ya estaban en memoria. Si no hay
credenciales en memoria vuelve al formulario de cuenta.

Un mensaje del servidor que cancele un logout voluntario no cancela esta
salida: la muerte ya ocurrio en la autoridad y no es reversible desde el
cliente.

## Estado de criatura visible en la UI

Esta seccion aplica al cliente jugable de la rama TVP 7.72. Los tres valores
que `protocolo-red` 1.1.0 conserva —velocidad, calavera y escudo de party— se
muestran, no se calculan. El cliente no deduce una calavera del combate, un
escudo de un mensaje de chat ni una velocidad de la distancia recorrida.

| Dato | Fuente unica | Donde se ve |
|---|---|---|
| Velocidad propia | `EstadoMundo.criaturas[mi_id]["velocidad"]`, puesta por `AddCreature` y por `0x8F` | Fila `Speed` de la ventana Skills |
| Calavera | `EstadoMundo.criaturas[id]["calavera"]`, puesta por `AddCreature` y por `0x90` | Fila del Battle List y panel Target |
| Escudo de party | `EstadoMundo.criaturas[id]["escudo_party"]`, puesta por `AddCreature` y por `0x91` | Fila del Battle List y panel Target |

La velocidad propia no se lee del `0xA0`: ese paquete de 7.72 no la
transporta y usarlo mostraba siempre cero.

Las dos tablas de significado viven en `cliente3d/ui/marca_criatura.gd` como
dato, copiadas de `servidor/src/const.h:179-193`:

| Valor | Calavera | Escudo de party |
|---:|---|---|
| 0 | sin marca | sin marca |
| 1 | `Yellow Skull` | `Party invitation received` |
| 2 | `Green Skull` | `Party invitation sent` |
| 3 | `White Skull` | `Party member` |
| 4 | `Red Skull` | `Party leader` |

El sentido del escudo es el que resuelve `Player::getPartyShield`
(`servidor/src/player.cpp:3742-3767`) desde el jugador que mira; el cliente no
vuelve a decidir quien invito a quien.

Un valor fuera de la tabla se oculta y no se dibuja con un color aproximado.
Un valor ausente vale cero, que tambien es sin marca. Un cambio de calavera o
de escudo no reconstruye la fila del Battle List.

## Menu de criatura y party

El boton derecho sobre una fila del Battle List abre el menu de esa criatura,
como en el cliente clasico. Atacar y seguir siguen estando ahi; lo que se
agrega son las acciones de party.

Que se ofrece sale **solo de los escudos confirmados** por el servidor, porque
esta rama no manda ningun paquete de party (`protocolo-red` 1.4.0). El escudo
propio dice si estamos en una y si somos lider; el del otro dice que relacion
tiene con nosotros:

| Escudo del otro | Escudo propio | Accion ofrecida |
|---:|---|---|
| 0 | sin party, o lider | `Invite to Party` (`0xA3`) |
| 1 | cualquiera | `Join Party` (`0xA4`) |
| 2 | cualquiera | `Revoke Invitation` (`0xA5`) |
| 3 | lider | `Pass Leadership` (`0xA6`) |
| 4 | cualquiera | ninguna sobre el lider |
| — | en una party | `Leave Party` (`0xA7`) |

Solo se ofrece party sobre un jugador: los ids de monstruo y de NPC quedan
fuera (`player.cpp:34`, `monster.cpp:18`, `npc.cpp:16`), y uno no se invita a
si mismo.

Elegir una accion envia su opcode y nada mas. La interfaz **no** se adelanta al
resultado: ningun escudo cambia hasta que el servidor lo confirme por `0x91`.
Si el servidor rechaza la accion, lo dice por `0xB4` como cualquier otra.

La experiencia compartida (`0xA8`) no se ofrece: el cliente 7.72 no tenia ese
boton. El transporte existe si alguna vez se decide agregarla.

### Ofrecer un trade

El menu de un jugador incluye `Trade with <nombre>`. Ofrecer es de dos pasos,
igual que el "use with" de las runas que este cliente ya usa:

1. Se elige a quien. No se manda nada todavia.
2. El clic siguiente sobre un objeto del equipo o de un contenedor manda el
   `0x7D` con ese objeto y ese jugador.

El objeto se direcciona como en cualquier mensaje de objeto: `(0xFFFF, ranura,
0)` para el equipo y `(0xFFFF, 0x40 | contenedor, ranura)` para un contenedor,
con `stackpos` 0.

El boton derecho cancela el trade a medio armar, y despues de cancelar el clic
vuelve a usar el objeto como siempre. Si el otro jugador dejo de estar a la
vista, no se manda nada y se avisa.

El orden es el inverso al del cliente clasico, que empieza por el objeto. Se
eligio asi porque el menu de criatura ya existe y el patron de dos pasos ya
esta en el cliente; es reversible el dia que haya menu de objeto.

### Panel de modos de combate

Boton "Combat" en la barra de Actions abre un panel con tres modos de ataque
(Full Attack / Balanced / Full Defense), Chase Opponent y ataque a jugadores
sin marcar. Manda el `0xA0` exacto con el formato de
`ProtocolGame::parseFightModes` (`servidor/src/protocolgame.cpp:1049-1064`):

| Byte | 1 | 2 | 3 |
|---|---|---|---|
| Fight mode | ofensivo | equilibrado | defensivo |
| Chase (byte 2) | 0 = standing | 1 = chase | - |
| Marcados (byte 3) | 0 = solo marcados | 1 = puede atacar sin marcar | - |

Este servidor **no contesta nada** para `0xA0` -a diferencia de party (`0x91`)
o trade (`0x7E`/`0x7F`)-, asi que el panel no espera ni puede esperar una
confirmacion: refleja unicamente su propio ultimo envio, igual que hace el
cliente clasico con este mismo paquete. El estado inicial (`ofensivo=1`,
`chase=false`, `marcados=false`) copia el default real de `Player` en
`servidor/src/player.h:1065,1071-1072` (`fightMode=FIGHTMODE_ATTACK`,
`chaseMode=false`, `secureMode=false`), no un valor inventado.

Cancelar el objetivo actual (Esc) ya estaba resuelto antes de este contrato:
`enviar_cancelar_accion()` manda `0xBE`
(`Game::playerCancelAttackAndFollow`), que el servidor confirma con el `0xA3`
que el cliente ya escuchaba (`objetivo_cancelado`). No se toco ese camino.

### Interaccion con camas reales (casas)

Esta seccion aplica al cliente jugable de la rama TVP 7.72 (`mundo3d.gd`). Una
cama del catalogo (`items772.json[cid].nombre == "bed"`, cualquiera de sus dos
mitades) tiene `tiene_alto=true`: su modelo 3D sube desde el piso, igual que
el marco vertical de una puerta simple. El clic normal para usar u observar
resuelve la casilla proyectando un rayo contra el plano del piso a la altura
del jugador; contra un objeto con altura ese rayo puede pasar de largo por
encima del respaldo y caer en la casilla siguiente, con cualquier otro objeto
que este ahi. Antes de este contrato eso se traducia en enviar el `spriteId`
de un objeto distinto (por ejemplo un tramo de pared) en una posicion vecina,
y el servidor rechazaba con `You cannot use this object` porque, con razon,
`item->getClientID() != spriteId` en `Game::playerUseItem`.

La correccion reutiliza el mismo mecanismo que ya resuelve puertas simples: un
test de rectangulo en pantalla contra la altura y el ancho reales del sprite
(`_hit_puerta_en_pantalla`), en vez de la interseccion con el plano del piso.
Se aplica con dos reglas fijas:

- La busqueda recorre **exclusivamente** `EstadoMundo.casillas`, la ventana
  viva que ya confirmo el servidor. Nunca el mapa estatico (`_mapa_visible`)
  ni el disco, y nunca una casilla vecina elegida por cercania: la unica
  fuente valida de que mitad de la cama esta en una casilla es el propio
  servidor, tal como pide `protocolo-red`.
- La busqueda queda acotada al piso del jugador y al radio de render
  (`_nivel_visible_para_interaccion`, `RADIO`), igual que las puertas, para no
  repetir el bug ya corregido de resolver la cama homologa de otro
  departamento del mismo edificio (Flat 01 contra Flat 11/21).

Si el rectangulo de ninguna cama viva cubre el clic, la resolucion cae al
camino normal (puerta simple bajo el mouse y, si tampoco hay, la casilla del
rayo contra el piso). No hay busqueda en vecindario ni offset fijo: si el
clic no cae sobre el rectangulo real de una cama, no se envia una cama.

El `use` sobre una cama manda el mismo `0x82` que cualquier objeto, con la
posicion, `spriteId` y `stackpos` que la ventana viva ya confirmo para esa
mitad exacta. La aceptacion, el rechazo y el efecto (dormir, ocupada, sin
permiso de la casa) son autoridad exclusiva del servidor; el cliente no
predice el resultado ni cambia el modelo de la cama hasta que la ventana viva
lo confirme.

### Ventana de texto

El servidor la abre con el `0x96` al usar un cartel, una carta o la etiqueta de
una parcel, y la respuesta vuelve por el `0x89` (`protocolo-red` 1.6.0).

La ventana muestra **solo lo que mando el servidor**: el nombre del item, quien
lo escribio y el texto actual. El maximo de caracteres tambien es suyo: al
escribir se corta ahi y se avisa cuantos quedan.

El paquete **no dice si el item se puede escribir**, asi que el cliente no lo
adivina: deja escribir siempre que el maximo sea mayor que cero y, si no
correspondia, el servidor rechaza el `0x89` con un `0xB4`. `Ok` manda lo
escrito; `Cancel` y `Esc` cierran sin mandar nada.

## Pruebas de cierre

- La escena arranca sin renderer con `--headless` y no produce errores de
  script.
- Con el servidor propio, un usuario recibe `WELCOME`/`STATE`, ve el mapa 3D y
  camina con teclado.
- Un segundo jugador recibido en `STATE` aparece en la escena.
- Un movimiento rechazado por el servidor no cambia la posicion visual.
- Una perdida de conexion limpia el mundo vivo y activa reconexion.
- La senal `jugador_muerto` bloquea intenciones, envia exactamente un `0x14`,
  deja visible la pantalla de reentrada y no vuelve solo al formulario de
  cuenta al cerrarse el socket.
- La reentrada pedida por el jugador limpia la sesion y vuelve al selector de
  personajes.
- Una criatura con calavera o escudo confirmados los muestra en el Battle List
  y en el Target con el nombre exacto de la tabla; una sin ellos no muestra
  marca, y un valor desconocido se oculta.
- `Speed` de la ventana Skills muestra la velocidad confirmada de `mi_id` y la
  cambia al recibir un `0x8F`.
- La ventana de texto muestra el texto y el autor que mando el servidor, corta
  en su maximo, y al aceptar devuelve el id de ventana y el texto tal cual.
- El menu de una criatura ofrece exactamente las acciones de party que
  permiten los escudos confirmados, y ninguna sobre un monstruo, un NPC o uno
  mismo.
- Elegir una accion de party envia su opcode y no cambia ningun escudo.
- Un clic sobre el rectangulo en pantalla de una mitad de cama viva manda el
  `spriteId` y la posicion exactos de esa mitad, aunque el rayo contra el
  piso caería en otra casilla.
- Un clic fuera del rectangulo de cualquier cama viva no envia una cama por
  cercania: cae al camino normal (puerta, luego rayo contra el piso).
- La busqueda de cama nunca usa `_mapa_visible` ni el disco, solo
  `EstadoMundo.casillas`.
- El panel de combate arranca con `ofensivo=1, chase=false, marcados=false`,
  igual que el default de `Player` en el servidor.
- Elegir un modo de ataque manda `[modo, chase actual, marcados actual]` sin
  tocar chase ni marcados; el grupo de botones deja presionado solo el modo
  elegido.
- Alternar chase o marcados manda el byte correspondiente conservando el modo
  de ataque y el otro alternador, y el texto del boton cambia entre sus dos
  caras (Chase Opponent / Stand While Fighting, Attack Unmarked Players /
  Marked Players Only).
