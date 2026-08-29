# Estado: qa

Estado: LISTO_PARA_REVISION
Ultimo agente: codex
Ultima actualizacion: 2026-08-29T15:18:00-06:00
Contrato publicado: SI

## Depende de

- `assets`: contrato publicado.
- `protocolo-red`: implementacion existente y contrato especializado en
  `docs/tibia3d/NETWORK_PROTOCOL.md`; falta formalizar su STATE.

## Le toca

Probar contratos, recorridos completos, concurrencia, fixtures y regresiones.

## Hecho

- Andamiaje creado.
- Publicado el contrato de QA v1.0.0.
- Ejecutada paridad IR vs estado vivo: 81 tiles coincidentes, 0 diferencias,
  1 criatura ignorada.
- Validada escalera real en TVP: z7 -> z6 -> z7, dos posiciones recibidas por
  0x64, personaje restaurado; `EstadoMundo` tambien expone 0xBE/0xBF si el
  servidor usa esos paquetes.
- Integrado inspector conectado en `mundo3d.gd`: seleccion por Shift+click,
  toggle F4, stack vivo y flags/metadatos IR por chunks; escena principal carga
  en headless sin errores.
- Runner local en `pruebas/matriz_qa_local.gd` ejecuta la checklist en procesos
  Godot separados y escribe `generated/reports/qa_matrix_local.json`.
- Matriz local ejecutada 6/6: coordenadas, controles, formas, chunks, modelo
  de proyecto y escena del editor pasan.
- Reporte versionado en `generated/reports/qa_matrix_local.json`.
- Regresion de spells y animaciones ejecutada 0 fallas: catalogo JSON, outfit
  multiframe, efectos/proyectiles importados, eventos `0x83`-`0x85`, cambio de
  outfit `0x8E`, alineacion del siguiente mensaje y lanzamiento por `0x96`.
- Matriz local ampliada y ejecutada 7/7 con `prueba_spells_animaciones.tscn`.
- Magic Wall de 3DTIBIA integrada con sus seis PNG originales, cubo 1x2x1 y
  animacion de tres fases a 5 FPS para los client ids 2128/2129.
- `prueba_magic_wall.tscn` verifica texturas, animacion y reemplazo seguro de
  una instancia dinamica; matriz local ejecutada 8/8.
- El picking de puertas simples usa la proyeccion vertical de la camara para
  uso/mirar; las variantes con llave, nivel, mision o sellado quedan fuera.
- Se agregaron regresiones para puertas simples/parametrizadas; la matriz local
  termina 9/9 y el login real contra TVP responde correctamente.
- El servidor reconstruido conserva la regeneracion otorgada por equipo dentro
  de proteccion: Guuille, con life ring en la ranura 9, paso de 157 a 160 de
  vida y de 1079 a 1082 de mana durante una medicion real de 7 segundos.
- Publicada `docs/qa/PARIDAD_772_2026-08-29.md`: matriz global basada en el
  servidor autoritativo que separa COMPROBADO, PARCIAL y AUSENTE.
- Validado el checkpoint actual en ocho procesos Godot: contenedores/canales,
  controles, eventos/trade, modelos authored, formas, spells, escena principal
  y escaneo de editor terminaron con codigo cero.
- `prueba_muerte_reentrada` adoptada en la matriz local: 10/10 OK y reporte
  regenerado.
- Prueba viva de muerte, corpse y loot ejecutada contra el servidor TVP:
  un demon invocado con `/m` mato al personaje, el servidor dejo el corpse
  `dead human`, el `0x6C` de `mi_id` con vida cero emitio la muerte, el
  logout `0x14` termino la sesion y el reingreso devolvio un personaje vivo
  en su templo.
- Mitad de corpse y loot repetible sola con `--solo-loot`: dos corridas
  independientes abrieron el corpse `dead rat` y leyeron loot distinto
  (`gold coin x3` y `x4`), que es el que decide el servidor.
- Evidencia, etapas, limites y efectos publicados en
  `docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md`; matriz global actualizada.
- La precondicion del duelo ya no es manual: el god va al campo y trae al
  personaje con `/c`, la talkaction del servidor. El cliente no camina ni
  simula intenciones, y la confirmacion la da la posicion autoritativa de la
  propia sesion del personaje.
- La prueba abre dos sesiones simultaneas (personaje y god) y respeta
  `Ban::acceptConnection`: un solo login por corrida y seis segundos entre
  sesiones nuevas.
- Modo `--solo-campo`: prueba solo la precondicion, retira el verdugo antes de
  que mate a nadie y devuelve el personaje a su templo con `omani`. Cinco
  comprobaciones en verde y codigo cero, repetible sin costo.
- `--solo-loot` sigue en verde y ahora distingue su propia rata por id nuevo y
  su corpse por casilla que no tenia corpse antes de la caza; el campo tiene
  ratas salvajes y restos de corridas viejas.
- `prueba_estado_criatura_ui` adoptada en `matriz_qa_local.gd`, que termina
  11/11 OK.
- La matriz local incorpora los self-tests de estado de criatura y mapa 7.72;
  termina 13/13 OK con codigo cero.
- Dos corridas vivas posteriores a `protocolo-red` 1.2.0 confirmaron muerte,
  logout `0x14`, cierre de sesion, reingreso vivo y corpse `dead rat` abierto
  con loot real (`cheese x1` y `gold coin x3`). La carrera de muerte queda
  cerrada.
- `pila: ?` queda corregido como diagnostico: no falta un nombre de assets. El
  `0x64` vivo deja al jugador fuera de `mi_pos` y reinterpreta bytes siguientes
  como ids imposibles. La prueba conserva el detalle y no acusa al servidor de
  omitir un corpse cuando `mapa_alineado` es falso.
- Prueba viva de VIP y trade ejecutada con dos sesiones reales. El god hizo
  remove/add de Valentino por nombre, recibio GUID 2 offline, online al entrar
  y offline al salir.
- El trade vivo preparo dos server id 2006/client id 2874, recibio oferta
  propia y contraparte en ambos clientes, acepto desde los dos sockets y
  comprobo las actualizaciones de inventario de la transferencia. Corrida
  final: codigo 0, 10 comprobaciones en verde.
- Publicado `docs/qa/PRUEBA_VIVA_TRADE_VIP.md` y contrato QA 1.2.0 con el
  comando, mutaciones, evidencia y limite de produccion encontrado.
- Repetida la certificacion con `Son Goku` (GUID 16) desde su otra cuenta:
  codigo 0, VIP y transferencia completos. La asociacion temporal a la cuenta
  de pruebas se restauro en `finally` y la prueba queda parametrizada sin
  imprimir claves.

- Party viva con dos clientes: `pruebas/prueba_party_viva.tscn` recorrio
  invitar, unirse, pasar liderazgo y salir contra el servidor, y los escudos
  de las dos sesiones contaron la misma party en cada paso. Ocho
  comprobaciones en verde y codigo cero, sin costo para ningun personaje.
- Evidencia y limites en `docs/qa/PRUEBA_VIVA_PARTY.md`; la fila de party de la
  matriz global pasa a COMPROBADO.
- La matriz local adopta `party_ui`, `party_protocolo` y `mapa_captura`, y
  termina 16/16 OK.
- La prueba viva de trade dejo de armar el `0x7D` a mano: usa el metodo que
  publico `protocolo-red` 1.5.0 y volvio a pasar entera contra el servidor.
- Depot probado en vivo: `pruebas/prueba_depot_vivo.tscn` guarda un objeto,
  cierra la sesion, vuelve a entrar y el objeto sigue en el `depot chest`.
  Seis comprobaciones en verde y codigo cero, sin tocar las cosas de nadie.
- Tres reglas de esta rama que no eran obvias quedaron escritas en
  `docs/qa/PRUEBA_VIVA_DEPOT.md`: hay que PISAR la baldosa para que el servidor
  cargue el depot del jugador, las cosas viven en el `depot chest` de adentro
  del locker, y la ventana de contenedor la elige el cliente en el `0x82`.
  Sin pisar la baldosa se abre el mueble del mapa, que acepta objetos y no es
  de nadie: es la trampa mas facil del recorrido.
- La fila de la matriz global se parte en dos: `Depot` pasa a COMPROBADO y
  `Mail/parcels` queda BLOQUEADO por el servidor.
- Correccion: el depot probado es el de **Thais**, no el de Rookgaard. Los
  personajes de prueba salen en el templo de Thais `(32369,32241,7)` y su
  depot esta a quince casillas. Rookgaard no tiene depot ni correo, igual que
  en el Tibia original.
- Prueba viva de parcel y mailbox escrita y corriendo en Thais. Se traba
  siempre en el mismo punto y con la causa localizada: al usar una etiqueta el
  servidor contesta `You cannot use this object` por la guarda de
  `game.cpp:2556-2560`. Evidencia en `docs/qa/PRUEBA_VIVA_PARCEL.md`.
- Correccion compensatoria: el servidor ya deja usar la etiqueta y el usuario
  confirmo que la parcel llega al depot del destinatario. Los archivos vivos
  conservan parcels dirigidas dentro de depot 1; mail/parcels pasa a
  COMPROBADO sin repetir la prueba mutante.
- `prueba_reacquisicion_monstruo.tscn` certifica el cambio compilado de
  `monster.cpp`: un `cave rat` identificado golpeo, el servidor movio al
  personaje 39 SQM fuera de vista y, al devolverlo, el mismo id retomo el
  ataque. Corrida final: vida 133 -> 131 -> salida/regreso -> 128, mismo id y
  limpieza confirmada, codigo 0.
- La prueba descarto una primera corrida donde los golpes eran de un `spider`
  silvestre y endurecio el oracle: solo cuenta dano cuyo mensaje nombra al
  monstruo invocado. Evidencia en
  `docs/qa/PRUEBA_VIVA_REACQUISICION.md`.
- La matriz local se repitio despues del cambio y termino 17/17 OK.

## Falta

- Completar matriz de red de todos los recorridos y errores contra un servidor
  legacy disponible.
- Repetir la checklist desde un clon limpio para la prueba de entrega.
- Probar en vivo el camino de produccion que inicia trade desde el menu de la
  criatura y luego selecciona el objeto.
- En la prueba viva de muerte, el unico fallo que queda es la limpieza del
  demon con `/killall`, que solo alcanza el cuadro alrededor de quien lo dice.
- Casas/camas: permisos, dormir/despertar y persistencia real contra la
  autoridad del servidor.
- Las corridas fallidas del depot dejaron dos parcels del god dentro del
  mueble del mapa en `(32354,32231,7)`. No rompen nada pero estan ahi.

## Bloqueos activos

- ATENDIDA el 2026-08-29: el `0x64` desalineado. `protocolo-red` 1.3.0
  encontro la causa con el OTBM como oraculo —una casilla que existe y se
  describe con cero bytes deja dos marcas pegadas— y dejo la captura real como
  regresion. El mapa vivo del campo entrega ahora las 356 casillas que dice el
  OTBM, con el jugador en la suya.
- ATENDIDA el 2026-08-29: el `0x7D` saliente. `protocolo-red` 1.5.0 lo publico
  con el atajo de inventario y la prueba viva ya lo usa en vez de armar los
  bytes. `cliente` 1.4.0 ya lo ofrece; falta la prueba viva que empieza en ese
  menu.
- La prueba manual de puertas y runas sigue pendiente; la prueba automatizada
  del life ring ya pasa contra el servidor reconstruido.
- ATENDIDA el 2026-08-29: reacquisicion de monstruos. El servidor ya estaba
  reconstruido y la prueba viva por salida/regreso de la ventana termino en
  codigo cero con el mismo id de criatura.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| Las pruebas de fecha usan reloj fijado | Evita que fallen con el paso de los meses | si |
| La prueba viva no camina al personaje para salir del templo | Caminar a ciegas no sale de la zona de proteccion y un auto-walk inventado seria la intencion de cliente que la prueba no debe simular | si |
| Al personaje lo saca del templo el servidor con `/c`, no el cliente | Es una talkaction del propio servidor: mueve a la criatura a la casilla libre mas cercana al god y el cliente solo mira donde lo dejaron | si |
| La prueba mantiene dos sesiones simultaneas | El `/c` solo alcanza a un personaje conectado, y asi el duelo no necesita relogueos | si |
| El god no se teletransporta encima de un monstruo vivo | El empujon del teleport deja la casilla en un estado que la prueba lee mal; sobre un corpse si puede pararse | si |
| El duelo ocurre siempre en la misma casilla de campo | Es la unica comprobada fuera de zona de proteccion, y asi la corrida no depende de donde quedo nadie | si |
| La mitad de corpse y loot se hace siempre en `32082,32145,6` | Es una casilla comprobada fuera de zona de proteccion, asi la media prueba se repite sin depender de donde quedo nadie | si |
| El monstruo del corpse se remata con `/killall` si el cuerpo a cuerpo tarda | El personaje god es nivel 1 y la prueba mide corpse y loot, no el ritmo de combate | si |
| Una pila solo certifica un corpse si `mapa_alineado` es verdadero | Sin el jugador en `mi_pos`, los indices y objetos locales no representan el paquete del servidor | no |
| La prueba viva de trade normaliza las manos y usa dos server id 2006 | El servidor necesita dos ofertas reales para ejecutar `playerAcceptTrade`; el usuario autorizo alterar los personajes de prueba | si |
| QA usa el `0x7D` publicado, no bytes armados a mano | La prueba viva debe cubrir el mismo transporte que usa produccion | no |
| Un golpe de reacquisicion debe nombrar al monstruo invocado | El campo contiene criaturas silvestres; una bajada de vida sola produjo un falso positivo real con un spider | no |

## Notas para quien retome

- La revision cruzada debe hacerla un agente que no haya implementado el
  carril revisado.
- El runner local no arranca servidores ni toca datos persistentes; las
  pruebas de red siguen siendo explícitas y secuenciales.
- La prueba viva SI toca datos persistentes: una corrida completa le cuesta un
  nivel al personaje normal y deja sus objetos en el corpse. Para restaurarlo
  estan la semilla `servidor/docker/data/02-data.sql` y
  `servidor/gamedata/players/`. El 2026-08-29 se ejecutaron cuatro corridas
  completas, asi que Valentino quedo varios niveles abajo.
- Para probar la precondicion sin costo se usa `--solo-campo`. Solo la corrida
  completa mata al personaje.
- En este turno se ejecutaron dos corridas completas adicionales con permiso
  explicito del usuario; ambas terminaron con dos fallas de alineacion, no de
  muerte ni de loot.
- Si una corrida se cuelga y se la mata a mano, conviene esperar antes de la
  siguiente: el servidor todavia considera conectado al personaje y
  `Ban::acceptConnection` cuenta las conexiones de la IP.
- Si el CLI de Docker en Windows se cuelga, el motor suele seguir vivo: se lo
  mira por el socket de adentro de WSL y se arregla reiniciando Docker
  Desktop. El 2026-08-29 el contenedor `servidor-server-1` estaba caido y los
  puertos 7171/7172 seguian escuchando sin nadie detras.
- `prueba_trade_vip_vivo.tscn` es mutante y no entra a la matriz local. Vaciar
  slots ya vacios puede producir `Sorry, not possible.` antes del trade; esos
  mensajes son precondicion esperada. Cualquier error durante oferta o
  aceptacion si hace fallar la corrida.
- El 2026-08-29 Son Goku estaba offline antes de la prueba. No se cambio su
  clave: solo se cambio su asociacion de cuenta durante la corrida y se
  restauro inmediatamente despues, aun ante fallo.
- La prueba de reacquisicion mueve y dana temporalmente a Valentino. Tras la
  corrida final se restauraron exactamente los timestamps, posicion, vida y
  duracion de condicion que tenian sus archivos al abrir este turno; los
  depots y demas cambios previos del usuario quedaron intactos.
