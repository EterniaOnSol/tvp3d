# Estado: qa

Estado: LISTO_PARA_REVISION
Ultimo agente: codex
Ultima actualizacion: 2026-08-29T10:36:00-06:00
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

## Falta

- Completar matriz de red de todos los recorridos y errores contra un servidor
  legacy disponible.
- Repetir la checklist desde un clon limpio para la prueba de entrega.
- Volver a correr la prueba completa en verde cuando `protocolo-red` corrija
  la alineacion del mapa inicial vivo.
- Publicar desde `protocolo-red` el iniciador saliente de trade `0x7D` y
  conectarlo a una interaccion de produccion. QA certifico el payload y la
  transferencia, pero `Conexion772` solo expone aceptar/cancelar/mirar.

## Bloqueos activos

- SOLICITUD A `protocolo-red` (ruta suya, `cliente3d/red/`): el self-test
  sintetico de mapa pasa, pero el `0x64` real queda desalineado. Tres sesiones
  independientes dejaron al jugador fuera de `mi_pos`; el primer falso item
  aparecio casi al final de `z=0` en `(32097,32155,0)` con cid 0, seguido por
  ids como `10`, `38560`, `38400` y `41316`. Son bytes posteriores al mapa
  reinterpretados. Corregir el cierre/salto real y agregar esta captura como
  regresion antes de declarar la prueba viva verde.
- SOLICITUD A `protocolo-red`: agregar a `Conexion772` un metodo de solicitud
  de trade con `position + client id + stackpos + player id` (opcode `0x7D`)
  y entregarlo al carril cliente para la accion contextual. La prueba viva
  tuvo que construir esos bytes dentro de QA porque hoy no existe el metodo.
- La prueba manual de puertas y runas sigue pendiente; la prueba automatizada
  del life ring ya pasa contra el servidor reconstruido.
- El cambio de reacquisicion de monstruos en C++ requiere reconstruccion y
  prueba viva; no esta certificado por la matriz headless del cliente.

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
| QA arma temporalmente el `0x7D` inicial | Permite certificar la autoridad sin invadir `cliente3d/red/`, reservado al otro agente; debe desaparecer cuando el carril publique el metodo | si |

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
