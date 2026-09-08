# Estado: cliente

Estado: LISTO_PARA_REVISION
Ultimo agente: codex
Ultima actualizacion: 2026-09-07
Contrato publicado: SI

## Depende de

- `modelo-comun`: contrato publicado.
- `protocolo-red`: contrato publicado.
- `assets`: contrato publicado.

## Le toca
2026-09-08: outfits humanos 3D, contrato 1.25.0.
- Se toma cliente para crear un componente modular en propio/personajes3d y
  mostrar los 14 outfits clasicos 128-134/136-142 en el visor.
- Base humana objetivo 0.95 casillas, mayor que la referencia anterior 0.67;
  cuatro direcciones, tres fases y colores HSI 0..132 del servidor.
- 3DTIBIA aporta geometria/proporciones del personaje actual y la formula de
  paleta MIT de OTClient; no contiene GLB humanos reutilizables.
- Decision reversible: primer pase estilizado por primitivas y perfiles de
  equipo; runtime legacy queda fuera por propiedad de carril.
- Futuro solicitado: servicio premium para subir un modelo 3D propio o comprar
  packs de outfits. Requiere pipeline GLB controlado, limites tecnicos,
  normalizacion, moderacion/derechos, preview/aprobacion, almacenamiento y
  reglas de cobro. Sera solo cosmetico: jamas modifica hitbox ni gameplay.
- Completado: 14 perfiles humanos 3D con piezas diferenciadas, paleta HSI
  head/body/legs/feet, cuatro orientaciones y tres poses. La altura base sube
  de la referencia antigua 0.67 a aproximadamente 0.95 casillas.
- El visor muestra 40 monsters + 14 outfits, permite moverlos, girarlos,
  enfocarlos y compararlos; --outfits abre solo los personajes.
- Verificado: personajes 74/74, visor 18/18 con 54 modelos y renderer de
  monsters 690/690, todos con codigo 0. visor_outfits.png (159213 bytes) fue
  renderizada correctamente. Inspeccion automatica bloqueada por DACL del
  helper de Windows; se abre la GUI para revision directa.
- Integrar estos modelos en mundo3d.gd sigue como siguiente bloque: la ruta
  legacy no pertenece al carril cliente publicado y no se modifica a escondidas.

2026-09-08: jerarquia Giant Spider/Dragon corregida, contrato 1.24.0.
- AABB final: Frost Troll 1.00x1.57x0.67; Giant Spider
  2.19x1.03x2.55; Old Widow 2.41x1.22x2.80; Dragon
  3.20x1.87x3.08; Dragon Lord 3.55x2.07x3.41 casillas.
- Giant Spider y Old Widow ganaron huella y masa vertical; normales
  renormalizadas despues de la escala vertical no uniforme.
- Dragon y Dragon Lord ahora superan al Frost Troll tambien en altura.
- Visor muestra ancho x alto x largo y separa la cuadricula segun la mayor
  huella, evitando solapamientos de los modelos gigantes.
- Regenerados solo outfits 34, 38, 39 y 208 y sus entradas de catalogo.
- Verificado: Python 17/17, renderer Godot 690/690 y visor 16/16.
  El primer intento Python desde la raiz fallo por import local; repetido desde
  monstruos3d con codigo 0. comparacion_gigantes.png se genero correctamente;
  inspeccion automatica no disponible por fallo DACL del helper.
- Decision reversible: objetivos artisticos en escalas.json y height_scale
  solo para 38/208; gameplay, ocupacion, red y autoridad intactos.

2026-09-08: jerarquia de escala gigante, contrato 1.24.0.
- Se toma cliente para corregir la lectura relativa Troll/Giant Spider/Dragon.
- Objetivos reversibles: Giant Spider 2.55, Old Widow 2.80, Dragon 3.20 y
  Dragon Lord 3.55 casillas de extension horizontal; las aranas ganan ademas
  masa vertical sin perder la postura baja.
- Las etiquetas pasaran a ancho x alto x largo para comparar volumen real.
- No cambia ocupacion, colisiones, combate, red ni autoridad del servidor.

2026-09-08: personaje principal incorporado al visor 1.23.0.
- La lista y la cuadricula muestran 40 monsters + Personaje principal outfit
  128 como referencia de escala; no altera el catalogo anatomico 40/144.
- Reproduce la geometria vigente del runtime: capsula, cabeza, nariz, colores
  y escala final 0.5; altura de comparacion aproximada 0.67 casillas.
- Todos los elementos ahora rotulan su altura para comparar tamanos.
- El personaje admite seleccionar, arrastrar, flechas, Q/E y enfoque; elegirlo
  desde detalle vuelve de forma segura a Todos.
- Verificado: visor 16/16, renderer 690/690 y captura PNG generada (224973
  bytes). La inspeccion automatica de la imagen no estuvo disponible por el
  fallo DACL del helper; queda confirmacion visual en la GUI relanzada.
- Decision reversible: referencia local con ID interno negativo, separada del
  outfit 128 y de los IDs autoritativos de criaturas.

2026-09-07: personaje principal en visor, contrato 1.23.0.
- Se toma el carril cliente para agregar el modelo authored del jugador como
  referencia fija de escala en la lista y la cuadricula Todos.
- Outfit 128 identifica la referencia visual; una clave interna separada evita
  confundirla con IDs de monsters o sumarla al catalogo anatomico 40/144.
- Decision reversible: misma geometria y escala 0.5 del runtime actual; solo
  vive en el visor y no toca autoridad, red, colisiones ni persistencia.

2026-09-07: entrada de mouse del visor corregida.
- Se agrego entrada_visor.gd como Node receptor; reenvia los InputEvent al
  SceneTree del visor, que por si solo no recibia _input.
- Rueda, orbita con derecho y paneo con centro quedan cubiertos por el receptor.
- Verificado: visor 11/11 y renderer 690/690, ambos con codigo 0.
- La prueba headless entrega mouse directamente al receptor porque la
  reinyeccion de eventos de Windows no es determinista sin ventana activa.
- Pendiente solo confirmacion manual del usuario en la ventana GUI relanzada.
- Decision reversible: receptor local sin persistencia, gameplay, red,
  colisiones ni cambios de contrato.

2026-09-07: correccion de entrada del visor 1.22.0.
- Reporte reproducible: la rueda y los arrastres de camara no responden.
- Causa localizada: visor.gd extiende SceneTree, cuyo metodo `_input` no recibe
  el despacho destinado a los Node del arbol.
- Alcance reversible: enrutar eventos mediante un Node local al visor y cubrir
  rueda/orbita con una prueba de entrada sintetica; sin tocar gameplay ni red.

2026-09-07: cierre retomado del visor 1.22.0.
- Diff completo releido y limitado a visor.gd, VISOR.md, captura y worklog cliente.
- Restaurada la recarga automatica de la malla seleccionada en modo detalle;
  la galeria completa evita sondear 40 archivos por frame.
- Verificado de nuevo: visor 7/7, renderer 690/690, ambos con codigo 0.
- La captura visor_todos.png se conserva como evidencia del recorrido visual
  revisado en la pasada original; no se regeneraron mallas ni assets.
- Cambios ajenos en ranura.gd, partidas, QA, previews y temporal de trolls
  permanecen fuera del commit.
- Decision reversible: toda la interaccion sigue local al visor, sin estado
  persistente, red, colisiones ni autoridad de gameplay.

2026-09-07: continuacion de cierre y publicacion del visor 1.22.0.
- Se conserva el alcance ya verificado: 40 monstruos, movimiento individual y
  camara orbital/paneable; no se agregan cambios de runtime ni autoridad.
- Objetivo de esta reapertura: releer el diff, repetir pruebas, aislar cambios
  ajenos y completar commit/push autorizado del visor.
- Decision reversible: mantener esta pasada limitada al visor y su documentacion.

2026-09-07: visor completo verificado, contrato 1.22.0.
- Descubre automaticamente las 40 fichas anatomicas y las ordena por nombre.
- Seleccion por clic o lista; arrastre X/Z, flechas para precision y Q/E para
  girar cada monster. Ordenar restaura la cuadricula de la sesion.
- Camara: boton derecho orbita, centro/WASD panean, rueda acerca y F enfoca.
- Modo individual, animacion, sprites y argumentos de captura conservados.
- Godot viewer 7/7, renderer 690/690 y detalle individual cargado sin errores.
- Captura real visor_todos.png revisada: 40 modelos visibles y UI legible.
- Comandos y controles completos en monstruos3d/VISOR.md.
- Decision reversible: interaccion local en visor.gd; no persiste posiciones,
  no modifica runtime, colisiones, red ni autoridad.
- Commit/push autorizados; resultado Git se confirma al cierre.


2026-09-07: Chicken 111, Flamingo 212, Parrot 217 y Terror Bird 218 verificados,
contrato 1.21.0.
- Catalogo 40/144, 104 pendientes. Lion/Tiger/Badger/Skunk siguen aplazados.
- Tres fases salvo Parrot con sus cuatro originales; RGB del atlas y siluetas
  separadas. Escalas .62/.88/.72/1.25; alturas .43/.96/.38/.82 casillas.
- Alas plegadas, picos, dedos y apoyo alternado; cuello en S de Flamingo,
  cola larga de Parrot y patas robustas de Terror Bird.
- Python 17/17 y Godot 690/690. Comandos y metricas en monstruos3d/AVES.md.
- Revisadas ave_111/212/217/218.png, comparacion_aves.png y la referencia
  original aves_referencia.png.
- Decision reversible: aves.py y objetivos de escala; formato intacto.
- Pendientes arte final, partida real, benchmark de grupos y exportacion.
- Commit/push autorizados; resultado Git se confirma al cierre.

2026-09-07: Troll 15, Frost Troll 53 y Swamp Troll 76 verificados, contrato 1.20.0.
- Catalogo 36/144, 108 pendientes. Lion/Tiger/Badger/Skunk siguen aplazados.
- Tres poses, manos con dedos, postura encorvada, RGB originales y escalas
  .90/1.00/.94; alturas 1.35/1.57/1.26. 20624 triangulos por pose.
- Corregida lectura del catalogo en la prueba de trolls (OUT y monstruos).
- Uniones de hombros, munecas y tobillos cubiertas; decision artistica reversible.
- Python 16/16 y Godot 619/619. Comandos y capturas en monstruos3d/TROLLS.md.
- Revisadas troll_15.png pose 0, troll_53.png pose 1, troll_76.png pose 2
  y comparacion_trolls.png con Rat/Skeleton/Bear en escala comun.
- Prototipos estilizados: siguen pendientes arte final, partida real,
  benchmark de grupos y exportacion. Las masas del cuerpo aun son distinguibles.
- Commit/push autorizados; resultado Git se confirma al cierre de la respuesta.

Apertura anterior conservada:
2026-09-07: EN_CURSO Troll 15, Frost Troll 53 y Swamp Troll 76, contrato 1.20.0.
Escalas artisticas editables .90/1.00/.94; los cuatro animales aplazados siguen pendientes.

2026-09-07: Skeleton 33 y Demon Skeleton 37 integrados, contrato 1.19.0.
- Catalogo 33/144, 111 pendientes. Lion/Tiger/Badger/Skunk siguen pendientes
  por eleccion del usuario: no retomarlos por defecto en la siguiente tanda.
- Craneos con orbitas, mandibula, dientes, caja toracica y pelvis abiertas,
  vertebras, huesos separados y dedos. Tres poses, sin armas/cuernos inventados.
- Escalas artisticas .70/.82 horizontal; alturas aprox. 1.58/1.85 casillas.
- Verificado: Godot 568/568, Python 15/15. Apoyos alternos, hueco del torso,
  costillas, giros, cache, RGB originales marfil/rojo, hashes y 33 escalas.
- Capturas finales revisadas: esqueleto_33.png pose 0, esqueleto_37.png pose 1,
  skeleton_dorso.png pose 2, comparacion_esqueletos.png. Fuente original:
  esqueletos_referencia.png, junto al componente. Comandos en LEEME.md.
- 32261 triangulos por pose, reducidos de 47049 al aligerar huesos pequenos.
- Decision reversible: esqueletos.py y objetivos de escala; formato intacto.
- Pendientes arte final, partida real, benchmark de grupos y exportacion.
- Commit y push a origin/main autorizados; confirmar resultado Git al cierre.
  Visor con Rat/Skeleton/Demon Skeleton/Wolf/Deer/Bear y Demon Skeleton elegido.

Apertura conservada:
2026-09-07: Skeleton/Demon Skeleton en curso, contrato 1.19.0.
Usuario mantiene Lion/Tiger/Badger/Skunk pendientes. Decision reversible:
esqueletos.py y escalas .70/.82; tres poses, sin armas/cuernos ajenos al sprite.


2026-09-07: Deer/Rabbit y Dog/Hyaena completados. Catalogo 31/144; 113 pendientes.
- Contrato 1.18.0. Deer/Rabbit publicados en 7d16f3c; se cierra Dog/Hyaena.
- Dog 32: castano, orejas caidas, cola delgada, cuatro patas con apoyo diagonal.
  Hyaena 94: hombros altos, lomo descendente, orejas redondas y crin corta,
  pelaje moteado del atlas. Tres poses, misma cache y formato TVPVOL01.
- Escalas: Dog .85, Hyaena 1.20, Deer 1.50, Rabbit .55 casillas; objetivos
  artisticos reversibles en escalas.json. Tabla ESCALAS.md completa para 31.
- Verificado: Godot 534/534, Python 14/14; comandos en LEEME.md. Pruebas de
  apoyos diagonales, inclinacion del lomo, escala, cache, RGB y geometria.
- Capturas finales revisadas: canino_32.png pose 0, canino_94.png pose 1,
  hyaena_perfil.png pose 2 y comparacion_caninos.png; fuente caninos_referencia.png.
  Deer/Rabbit: bosque_31.png, bosque_74.png, deer_dorso.png, comparacion_bosque.png.
- Triangulos por pose: Dog 9196, Hyaena 11436, Deer 13172, Rabbit 10160.
- Decision reversible: familias en bosque.py y caninos.py, materiales y escalas.
- Pendientes valoracion artistica, partida real, benchmark de grupos y exportacion.
  Siguiente familia posible: Lion/Tiger, revisando referencias y escalas primero.
- Commit y push autorizados a origin/main; confirmar el resultado de Git.
  Visor con Rat/Dog/Wolf/Hyaena/Deer/Bear, Hyaena seleccionada en detalle.

Historial de esta continuacion:
2026-09-07: Dog/Hyaena en curso, contrato 1.18.0. Deer/Rabbit subidos en 7d16f3c.
Decision reversible: perfiles en caninos.py y escalas .85/1.20.


2026-09-07: Deer/Rabbit verificados: 29/144; Godot 500, Python 13 OK.
Escalas 1.50/.55. Cuatro capturas finales revisadas; cornamenta corregida,
cola clara y orejas cerradas. Partida real, benchmark y exportacion pendientes.
Se guarda esta familia y se continua con la siguiente dentro del carril.


2026-09-06: Deer/Rabbit en curso, contrato 1.17.0.
Decision reversible: bosque.py y escalas artisticas 1.50/.55 casillas.


2026-09-06: Black Sheep 13, Sheep 14 y Pig 60 integrados, contrato 1.16.0.
- Catalogo 27/144, 117 pendientes. Tres poses, RGB originales, cuatro patas
  con apoyo diagonal y pezunas partidas; ovejas con lana geometrica continua,
  Pig mas bajo con hocico, narinas, orejas y cola rizada.
- Escalas: ovejas .95 y Pig 1.00 casillas; comparadas con Rat, Wolf y Bear.
  Modelos previos no regenerados. Decision reversible: granja.py y escalas.json.
- Verificado: Godot 466/466, Python 12/12; comandos en LEEME.md.
  Pezunas partidas y apoyos, lana con relieve, contraste de colores entre las
  dos ovejas, altura relativa, normales, RGB, hashes y todas las escalas.
- Capturas finales revisadas: granja_14.png pose 0, granja_13.png pose 1,
  granja_60.png pose 2, comparacion_granja.png. Fuente: granja_referencia.png.
- Triangulos por pose: Sheep/Black Sheep 10594, Pig 8382.
- Pendientes arte final, partida real, benchmark de grupos y exportacion.
  Seguir otra familia pendiente, conservando siempre escala y comparacion.
- Commit y push a origin/main autorizados; comprobar resultado Git al cierre.
  Visor con Rat/Black Sheep/Sheep/Pig/Wolf/Bear y Pig seleccionado en detalle.

Apertura conservada:
2026-09-06: Sheep/Black Sheep/Pig en curso, contrato 1.16.0.
Decision reversible: granja.py, tres poses y objetivos en escalas.json.


2026-09-06: Scorpion 43, Bug 45 y Centipede 124 integrados, contrato 1.15.0.
- 24/144 apariencias modeladas, 120 pendientes. Tres poses y RGB originales.
- Scorpion: ocho patas, dos pinzas, cola segmentada elevada y aguijon curvo.
  Bug: seis patas, elitros rojizos, antenas verdes. Centipede: doce pares,
  placas dorsales, antenas y onda corporal con apoyos alternados.
- Escalas artisticas: Bug .42, Scorpion 1.10, Centipede 1.30 casillas.
  Misma tabla uniforme. Modelos previos conservados sin regeneracion.
- Verificado: Godot 415/415 y Python 11/11; comandos en LEEME.md.
  La prueba admite apoyo doble al cruzar cero la onda de Centipede (fase 0).
- Capturas finales revisadas: artropodo_43.png pose 0, artropodo_45.png pose 1,
  artropodo_124.png pose 2, comparacion_artropodos.png. Referencias originales
  artropodos_referencia.png. Todos junto al componente de monstruos3d.
- Triangulos por pose: Scorpion 12852, Bug 5336, Centipede 15736.
- Decision reversible: artropodos.py y objetivos en escalas.json.
- Falta valoracion artistica, partida real, benchmark de grupos y exportacion.
  Continuar otra familia pendiente, manteniendo siempre escalas y comparacion.
- Cierre con commit y push autorizados a origin/main; comprobar resultado Git.
  Visor con comparacion Rat/Bug/Scarab/Scorpion/Centipede/Ancient Scarab.

Apertura conservada:
2026-09-06: Scorpion/Bug/Centipede en curso, contrato 1.15.0.
Decision reversible: anatomia en artropodos.py, escalas comunes y tres poses.


2026-09-06: refinamiento Scarab/Ancient Scarab y escala comun completados,
contrato 1.14.0. Usuario autoriza commit y push cuando se estime oportuno;
esta autorizacion persiste para proximas tandas, sin pedir confirmacion otra vez.
- Dos elitros separados con relieve, patas articuladas, espinas y garras;
  Ancient Scarab con grandes mandibulas aplanadas y dentadas.
- Regeneradas las 21 apariencias con escalas.json. Un unico factor por modelo
  y todas sus poses; regla artistica reversible, no modifica colisiones.
- Comparador con rejilla de una casilla, rueda y arrastre, nombres y medidas.
  Comparacion predeterminada de seis familias; --grupo 83,79 muestra el par.
- Tamano horizontal: Rat .48, Scarab .85, Ancient Scarab 1.75, Giant Spider 1.85.
  Auditoria completa y valores anteriores en ESCALAS.md junto al componente.
- Verificado: Godot 364/364, Python 10/10; comandos en LEEME.md.
  Capturas finales revisadas: scarab_refinada.png (pose 1), ancient_refinada.png
  (pose 0), comparacion_escarabajos.png (pose 2), comparacion_escalas.png.
- Triangulos/pose: Scarab 22680, Ancient Scarab 24072; tres poses cada uno.
  Aumenta detalle respecto al lote anterior: benchmark de grupos pendiente.
- Faltan aprobacion artistica, partida real y exportacion. No son modelos finales.
- Cierre con commit y push autorizados a origin/main; verificar resultado de Git.
  Cambios ajenos en ranura.gd, jugadores y worklog/qa quedan fuera del commit.

Apertura conservada:
2026-09-06: revision Scarab/Ancient Scarab y escalas en curso, contrato 1.14.0.
Decision reversible: tabla artistica de longitud en casillas, escala uniforme
y comparador comun. Usuario solicita mejor anatomia y diferencias de porte.


2026-09-06: Rotworm/Larva/Scarab/Ancient Scarab integrados, contrato 1.13.0.
- IDs 26/82/83/79; 21 apariencias modeladas de 144, 123 pendientes.
- Verificado: Godot 343/343, Python 8/8; comandos en LEEME.md.
  Soporte de seis fases originales, cache ciclica, suelo, normales, RGB y hashes;
  seis patas con apoyos alternados y cuatro direcciones en el renderer real.
- Capturas revisadas: reptador_26/82/83/79.png y rotworm_cerrado.png.
  Referencias originales: reptadores_referencia.png y rotworm_fases.png.
- Triangulos por pose: Rotworm 6772 (6), Larva 11624 (3), Scarab 8280 (3),
  Ancient Scarab 9120 (3). Poses discretas, sin rig esqueletico.
- Decision reversible: perfiles propios en reptadores.py y paleta fija de fase 0.
- Falta: aprobacion artistica, partida real, benchmark de grupos y exportacion.
  Seguir con otra familia pendiente; no habilitar experimentos 25/35.
- Git: cierre con commit local; push pendiente, sin instruccion de publicar
  esta tanda. No se declara push realizado. Visor abierto con Ancient Scarab.

Registro de apertura conservado:
2026-09-06: Rotworm/Larva/Scarab/Ancient Scarab en curso, contrato 1.13.0.
Decision reversible: perfiles en reptadores.py; Rotworm conserva seis fases.


2026-09-06: Snake/Cobra integradas, contrato 1.12.0.
- IDs 28/81; cuerpo ondulante con extremos fijos entre poses, perfil bajo de
  Snake y capucha volumetrica Cobra con vientre y marca dorsal originales.
- Diecisiete apariencias modeladas de 144; 127 pendientes. Serpent Spawn 220
  solo se inspecciono como referencia; no esta modelado ni habilitado.
- Verificado: Godot 270/270, Python 7/7. Prueba nueva de centrolinea estable,
  radios constantes y suelo, altura relativa Snake/Cobra; integracion y giros.
  El umbral de altura de volumen baja a .025 para admitir la anatomia Snake.
- Capturas finales revisadas: serpiente_28.png pose 0, serpiente_81.png pose 1,
  cobra_dorso.png pose 2. Fuente: serpientes_referencia.png, en el componente.
- Snake 4776 triangulos por pose; Cobra 7256. Tres poses, RGB y escala por sprite.
- LEEME actualizado y visor con Cobra. Otras familias no se regeneraron.
- Limites: arte estilizado pendiente de valoracion y partida real; benchmark
  con grupos y exportacion no realizados. Animacion discreta de tres poses.
- Decision reversible: perfiles y centrolineas en serpientes.py.
- Commit local; push pendiente sin instruccion de publicar este lote.
- Siguiente familia sugerida: Rotworm/Larva, previa revision de sprites.

Historial de osos:
2026-09-06: Bear/Polar Bear/Panda integrados, contrato 1.11.0.
- IDs 16/42/123: cuerpo robusto continuo, patas con cinco dedos, orejas redondas,
  hocico y cola corta. Polar Bear alarga cuello/hocico; Panda tiene mascara,
  orejas, patas y banda de hombros oscuras como el sprite.
- Quince apariencias modeladas de 144; 129 pendientes. Tres poses por modelo,
  escala por ancho del sprite y RGB originales estables entre poses.
- Verificado: Godot 238/238; Python 6/6, incluyendo contactos de patas y contraste
  real de la banda negra sobre la malla Panda. Capturas finales revisadas:
  oso_16.png pose 0, oso_42.png pose 1 perfil, oso_123.png pose 2; referencia
  osos_referencia.png. Todas dentro del componente.
- Bear/Polar Bear 15400 triangulos por pose; Panda 16648. Misma cache/formato.
- LEEME actualizado y visor con Panda. No se regeneraron familias anteriores.
- Limites: arte estilizado pendiente de valoracion del usuario y partida real;
  tres poses discretas, sin benchmark de multitud ni exportacion distribuible.
- Decision reversible: perfiles en osos.py sobre el constructor suave existente.
- Commit local del lote; push pendiente sin instruccion de publicarlo.
- Siguiente familia sugerida: Snake/Cobra, o animales de granja, previa referencia.

Historial de lobos:
2026-09-06: Wolf/Winter Wolf/War Wolf integrados, contrato 1.10.0.
- IDs 27/52/3, cuatro patas con apoyo diagonal, hocico, orejas y cola espesa.
  Torso continuo para reducir uniones; perfiles gris oscuro, blanco y War Wolf
  robusto con marcas grises/ojos amarillos. RGB del atlas estables por pose.
- Doce apariencias modeladas de 144; 132 pendientes. El experimento 27 se
  reemplaza por anatomia. Solo 25/35 siguen deshabilitados.
- Verificado: Godot self_test.gd 190/190; self_test_anatomia.py 5/5,
  incluidos apoyos diagonales, escala relativa y validacion binaria de todos
  los modelos con paleta fija. Capturas finales de las tres poses revisadas.
- Cada lobo tiene 12934 triangulos por pose. Misma cache y formato TVPVOL01.
  No se regeneraron ni editaron los modelos anteriores.
- Referencias/capturas: lobos_referencia.png, lobo_27.png, lobo_52.png y
  lobo_3.png dentro del componente. LEEME actualizado; visor con War Wolf.
- Limites: modelos estilizados y tres poses discretas; pendientes valoracion
  artistica del usuario, partida real, benchmark de multitud y exportacion.
- Decision reversible: perfiles en lobos.py y geometria suave compartida.
- Commit local del lote; push pendiente sin instruccion de publicarlo.
- Siguiente familia sugerida: Bear/Polar Bear/Panda, previa revision de sprites.

Historial de aranas:
2026-09-06: familia de aranas integrada, contrato 1.9.0.
- Nuevos IDs 30/36/38/208/219: Spider, Poison Spider, Giant Spider,
  The Old Widow y Tarantula. Nueve apariencias con modelo y 135 pendientes.
- Ocho patas, cuatro apoyos alternos por pose, abdomen/cefalotorax, palpos,
  ojos y colmillos. Tarantula tiene bandas claras y bristles cortos.
- Paletas originales por variante, marcas dorsales con colores por vertice,
  escala derivada del sprite. The Old Widow conserva aspecto de Giant Spider.
- Tres poses por apariencia, TVPVOL01 compatible, misma cache y orientaciones.
- Verificado: self_test.gd 142/142; self_test_anatomia.py 4/4. Se validan
  integracion y giro de los cinco IDs, ocho patas/apoyos, normals, RGB del atlas,
  estabilidad de paleta, bounds, hashes y diferencia de tamanos.
- Capturas finales arana_30/36/38/208/219.png en el componente; todas revisadas.
  La captura 36 muestra pose 1 de perfil y 208 pose 2 por detras; resto pose 0.
- LEEME actualizado conservando checkpoint anterior. Visor abierto con Giant Spider.
- Modelos estilizados: falta aprobacion artistica y partida real. Las aranas
  usan 12016 triangulos por pose; Tarantula 12586. No hay benchmark de multitud
  ni exportacion distribuible. Rat y dragones se mantienen sin regenerar.
- Decision reversible: perfiles de familia en aranas.py; constructor suave
  existente compartido, materiales propios. El experimento antiguo 30 se
  sustituye; 25/27/35 siguen deshabilitados y conservados en Git.
- Se guarda commit local; push pendiente, sin instruccion de publicar este lote.
- Proxima familia sugerida: Wolf/Winter Wolf/War Wolf, revisando sus sprites.

Historial del refinamiento anterior:
2026-09-06: Dragon y Dragon Lord refinados y revisados con renderer real.
- Cabeza alargada, cejas, cuernos curvos, cuatro patas apoyadas y cola curva.
- Alas concavas con dedos desde la muneca; placas de pecho y lomo adheridas.
- Normales exteriores suaves y winding horario Godot; se corrige sombreado
  invertido del generador anterior. Paleta por region, sin franjas por anillo.
- RGB tomados del sprite original; fase cero fija el material de las tres poses
  para evitar parpadeo de color. Dragon Lord conserva tonos rojos.
- Contrato 1.8.0 y TVPVOL01 intactos. Rat/Cave Rat no se regeneraron.
- Visor con luz de relleno, encuadre mayor y captura --fase / --elevacion.
- Verificado: self_test.gd 61/61; self_test_anatomia.py 2/2 (normales exteriores,
  winding, finitud, normalizacion, RGB originales, paletas iguales entre poses,
  bounds y hashes del catalogo). Capturas antes.png/despues.png/lord.png junto
  al componente; perfil.png es una captura intermedia de la segunda pose.
- Limites: siguen siendo modelos estilizados y tres poses discretas, sin rig
  esqueletico; pendiente valoracion artistica del usuario y partida real.
  Cada dragon tiene 39172 triangulos por pose y archivo de 9518820 bytes;
  no se ha medido el rendimiento con muchos dragones simultaneos ni exportado.
- Decision reversible: materiales regionales y curvas dentro de DragonSculpt.
- Se guarda commit local del carril. Push pendiente: no hay instruccion de
  publicar esta nueva pasada al remoto en el turno actual; no se pide permiso
  para continuar el trabajo visual ya autorizado.

Checkpoint anterior conservado como historial:
Checkpoint solicitado por usuario el 2026-09-06 antes de agotar tokens.
Implementado: cuatro prototipos anatomicos (21,56,34,39), cache de mallas,
renderer y picking integrados, visor interactivo abierto con recarga de mallas.
Catalogo: 144 outfits, 4 con modelo inicial y 140 pendientes; los experimentos
25/27/30/35 no cuentan como terminados ni se habilitan en produccion.
Pruebas: self_test.gd 61/61, test_controles y test_formas_render con 0 fallas,
editor --headless --quit OK. Capturas graficas revisadas de rat y dragon.
Falta: aprobacion artistica, refinamiento de forma/textura/poses, validacion
en partida real y comprobar inclusion de .tvol en futuros exports. No se
afirma que el sprite completo se proyecte pixel a pixel: se muestrean colores
de las referencias sobre formas construidas por partes. No se uso Blender.
Commit/push a origin/main solicitados por el usuario para guardar este avance.
Los cambios previos ajenos en ranura.gd, players y worklog/qa se conservan.

2026-09-06: monstruos volumetricos con pixeles originales, contrato 1.8.0.
Dependencias publicadas y ultimo cierre del carril libre. Decision reversible:
generador y recursos derivados junto al componente del cliente. Se conserva
la propiedad legacy de mundo3d.gd establecida en contratos cliente 1.1..1.7.

Correccion aplicada: el cliente vuelve al selector al cierre autoritativo del
socket (incluido dormir en cama) y conserva los mensajes 0xB4 del servidor en
el historial para que look y rechazos puedan leerse y copiarse. Verificado con
Godot headless --editor --quit.

Segunda correccion de esta sesion (causa raiz del bloqueo real en Mill Avenue
1 / house 81): la resolucion de clic sobre una cama usaba el rayo contra el
plano del piso, igual que cualquier casilla plana. Una cama tiene
`tiene_alto=true` (su respaldo sube del piso), asi que un clic sobre esa parte
alta pasaba de largo y caia en la casilla siguiente -en el caso reportado, un
tramo de pared (client 1281, "framework wall") en vez de la cabecera real
(client 2493, server 1760). El servidor rechazaba con razon: el `spriteId`
recibido no coincidia con lo que habia en esa casilla
(`Game::playerUseItem`, `item->getClientID() != spriteId`).

Verificado con una prueba headless nueva, no con la cuenta real ni con Docker:
el fix no toca servidor, asi que no hizo falta reconstruir nada. Confirmado en
vivo despues: la mitad activa de Mill Avenue 1 se pudo usar sin el rechazo.

Tercera correccion de esta sesion, encontrada al probar en vivo dormir de
verdad (bloqueada hasta ese momento por una guarda de servidor no relacionada
a este carril; ver `worklog/servidor/STATE.md`): al aceptar la cama, la
captura del usuario mostro dos figuras durmiendo superpuestas sobre la unica
cama real. Causa: `IDS_CAMA_PIE` (decide que mitad recibe la malla 3D grande
authored) y `IDS_CAMA_DORMIDA` (decide que textura usar) son dos preguntas
independientes sobre el mismo cid, pero un cambio anterior de esta misma
sesion saco 2496 y 2498 de `IDS_CAMA_PIE` al agregarlos a `IDS_CAMA_DORMIDA`,
sin darse cuenta de que ambas cosas pueden ser ciertas a la vez para un pie
ocupado. Confirmado en vivo con `/tileinfo`: servidor 1764 (cabecera ocupada,
Mill Avenue 1) -> client 2497, servidor 1765 (pie ocupado) -> client 2498;
los dos calificaban para la malla grande y se dibujaban superpuestos. Se
restauran 2496/2498 en `IDS_CAMA_PIE` (estaban ahi antes de esta sesion) y se
agregan 2500/2502, sus equivalentes en la familia "cot", por la misma
evidencia. `_es_cama_modelo` sigue devolviendo `false` para toda la familia
"cot" porque su nombre de catalogo es "cot", no "bed": nunca usan la malla 3D
authored, con o sin este fix.

Verificado headless con una prueba nueva
(`prueba_cama_pie_ocupada.gd`); **falta la confirmacion visual en el cliente
jugable real** porque el cliente se reinicio para tomar el cambio pero la
sesion no llego a probarlo antes de pasar al siguiente bloque.

Construir la experiencia jugable 3D y mostrar solo estado confirmado.

## Hecho

- Andamiaje creado.
- Contrato v1.0.0 publicado para conexion, estados, entrada, reconexion y
  autoridad visual.
- La escena propia usa el protocolo JSON propio y no el adaptador TVP 7.72.
- `WELCOME` valida mapa, posiciones, dimensiones, tipos y duplicados antes de
  renderizar.
- `STATE` reemplaza entidades confirmadas y no hace prediccion local.
- La conexion reintenta tras perdida, limpia buffer/entidades y permite
  configurar host, puerto y nombre por entorno.
- Se representan los siete tipos de tile del modelo, incluidos decoracion y
  escalera.
- Contrato v1.1.0 publicado con el recorrido de muerte y reentrada del cliente
  TVP 7.72, apoyado en `protocolo-red` 1.1.0.
- `mundo3d.gd` consume `EstadoMundo.jugador_muerto`: bloquea intenciones,
  cancela uso-con, arrastre y objetivo, oculta la interfaz, muestra la
  pantalla de reentrada y envia un unico logout `0x14`.
- `cliente3d/ui/muerte.gd` presenta `You are dead.` —el mismo texto que manda
  el servidor por `0xB4`— y una sola accion para volver al selector.
- El cierre del socket despues de morir ya no salta solo al formulario de
  cuenta: deja la pantalla de reentrada esperando la decision del jugador.
- Un `0xB4` con la palabra logout ya no cancela una muerte; solo cancela una
  salida voluntaria.
- `pruebas/prueba_muerte_reentrada.tscn` cubre las dos mitades con bytes
  reales: 21 comprobaciones en verde y codigo de salida cero.
- Contrato v1.2.0 publicado con el estado de criatura visible: de donde sale
  cada dato y que significa cada valor.
- `cliente3d/ui/marca_criatura.gd` dibuja la calavera y el escudo de party con
  las tablas `Skulls_t` y `PartyShields_t` copiadas de `servidor/src/const.h`.
- El Battle List y el panel Target muestran esas dos marcas junto al nombre,
  con el texto de la tabla como tooltip.
- La fila `Speed` de Skills muestra la velocidad confirmada de `mi_id`; antes
  leia un campo que el `0xA0` de 7.72 no manda y siempre valia cero.
- Contrato 1.3.0: menu de criatura con las acciones de party. El boton derecho
  del Battle List abre el menu, como en el cliente clasico; atacar y seguir
  siguen ahi dentro.
- Que se ofrece sale solo de los escudos confirmados: invitar, unirse,
  revocar, pasar liderazgo y salir, y nada sobre un monstruo, un NPC o uno
  mismo. Elegir una accion manda su opcode y no cambia ningun escudo: eso lo
  confirma el servidor con el `0x91`.
- La experiencia compartida no se ofrece; el cliente 7.72 no tenia ese boton.
- Contrato 1.4.0: el menu ofrece `Trade with <nombre>`. Son dos pasos como el
  "use with": primero a quien, y el clic siguiente sobre un objeto manda el
  `0x7D`. El derecho cancela, y despues de cancelar el objeto se usa como
  siempre. Si el otro salio de la vista no se manda nada.
- `pruebas/prueba_party_ui.tscn`: 20 comprobaciones en verde, una por cada
  combinacion de escudos, las dos formas de direccionar el objeto ofrecido, y
  las que verifican que mandar no adelanta estado.
- Contrato 1.5.0: la ventana de texto de carteles, cartas y etiquetas. La abre
  el servidor con el `0x96` y la respuesta va por el `0x89`. Muestra el nombre
  del item, quien lo escribio y el texto actual; corta en el maximo que puso el
  servidor y no adivina permisos, porque el paquete no dice si el item se puede
  escribir.
- `pruebas/prueba_ventana_texto_ui.tscn`: 13 comprobaciones en verde, con
  etiqueta en blanco, texto mas largo que el maximo, cartel ya escrito y
  cancelar sin mandar nada. Adoptada en la matriz, que queda 17/17.
- `pruebas/prueba_estado_criatura_ui.tscn`: 20 comprobaciones en verde,
  incluidos los cambios `0x90`, `0x91` y `0x8F` en vivo y el valor desconocido
  que se oculta.
- Contrato 1.6.0: la resolucion de clic sobre una cama (`_cama_bajo_mouse`)
  reutiliza el test de rectangulo en pantalla que ya usan las puertas simples
  (`_hit_puerta_en_pantalla`), en vez del rayo contra el plano del piso. Se
  agrega `_es_pieza_de_cama(cid)`, que reconoce cualquier mitad de cama por su
  nombre de catalogo ("bed"), a diferencia de `_es_cama_modelo` que excluye el
  pie porque esa funcion elige la malla 3D, no resuelve clics.
- La busqueda de cama recorre exclusivamente `EstadoMundo.casillas` (la
  ventana viva), nunca `_mapa_visible` ni el disco, y nunca una casilla vecina
  por cercania. Se eliminaron los dos parches de "vecindario" que un turno
  anterior habia dejado sin terminar en `_usar_en_casilla`: buscaban el
  objeto mas cercano en un radio de 3 casillas cuando el clic resolvia vacio o
  resolvia un objeto que no era cama, lo cual podia enviar un uso a una
  casilla distinta de la que el jugador realmente eligio.
- `_usar_en_casilla` y `_mirar_en_casilla` prueban primero `_cama_bajo_mouse`,
  luego `_puerta_bajo_mouse` y por ultimo el rayo contra el piso, igual que ya
  hacian solo con puertas.
- `pruebas/prueba_cama_bajo_mouse.gd` (`godot --headless -s
  res://pruebas/prueba_cama_bajo_mouse.gd`): reproduce el sintoma real -clic
  sobre el respaldo alto de la cabecera cae, por el rayo contra el piso, en
  una casilla vecina con otro objeto- y comprueba que `_cama_bajo_mouse`
  igual resuelve la cabecera real (client 2493) y el pie real (client 2494)
  cada uno en su propia casilla, que un clic lejano no adivina una cama por
  cercania, y que 1281 ("framework wall") nunca se reconoce como pieza de
  cama. 5/5 comprobaciones en verde, codigo de salida 0. No registrada todavia
  en `matriz_qa_local.gd` (ruta de `qa`); ver "Falta".
- `IDS_CAMA_PIE` vuelve a incluir 2496 y 2498 (restaurados) y suma 2500/2502
  (equivalentes en la familia "cot", misma evidencia): son los pies ocupados
  de cada pareja de cama, y deben quedar excluidos de la malla 3D grande
  igual que sus pares vacios, sin importar que tambien esten en
  `IDS_CAMA_DORMIDA` para la textura. `IDS_CAMA_DORMIDA` no cambio.
- `pruebas/prueba_cama_pie_ocupada.gd`: verifica que cada cabecera ocupada
  ("bed") siga calificando para la malla grande, que cada pie ocupado quede
  excluido, que los cuatro cids de "cot" ocupado nunca califiquen (su nombre
  de catalogo no es "bed"), y que el par vacio de Mill Avenue 1 (2493/2494)
  no haya cambiado. 3/3 bloques en verde, codigo de salida 0. Tampoco
  registrada en `matriz_qa_local.gd`.
- Verificado que "cancelar objetivo" ya estaba resuelto antes de esta sesion:
  Esc ya manda `0xBE` y ya limpia la ventana Target con el `0xA3` de
  confirmacion. No hizo falta ningun cambio; el hueco de
  `docs/qa/PARIDAD_772_2026-08-29.md` en ese punto esta desactualizado (ruta
  de `qa`, no se toca aca).
- Contrato 1.7.0: boton "Combat" en Actions abre un panel con los tres modos
  de ataque, chase y ataque a jugadores sin marcar, mandando el `0xA0` exacto
  de `parseFightModes`. Sin confirmacion posible (este servidor no contesta
  nada para ese paquete), asi que el panel solo refleja su propio ultimo
  envio, arrancando en el default real de `Player`
  (`ofensivo=1, chase=false, marcados=false`).
- `pruebas/prueba_modos_combate.tscn`: 14 comprobaciones en verde. Estado
  inicial, que cada boton manda exactamente `[modo, chase, marcados]` sin
  tocar los otros dos valores, que el grupo de botones de modo deja
  presionado solo uno, y que el texto de chase/marcados cambia entre sus dos
  caras. Tampoco registrada en `matriz_qa_local.gd`.

## Falta

- Confirmacion visual real del panel de Combat: el cliente no se reinicio
  todavia con este cambio en la sesion que lo escribio.
- Pedido explicito del usuario, distinto de "combate basico" y sin dueño
  todavia: hotkeys configurables (hoy `Hotkeys` en `interfaz.gd` es solo un
  cartel informativo fijo, no hay UI para remapear teclas).
- Solicitud a `qa` (ruta suya, `docs/qa/PARIDAD_772_2026-08-29.md`): la fila
  "Combate basico" listaba "cancel target" como hueco; ya estaba resuelto
  (ver "Hecho"). Falta certificar en vivo el panel de modos de combate y
  actualizar esa fila.
- Integrar la escena propia en el arranque general documentado por
  `integracion`.
- Ejecutar revision visual cruzada y comprobar input de usuario en una ventana
  no headless; las marcas todavia no se han visto dibujadas en pantalla real.
- Representar la calavera y el escudo tambien sobre la criatura en el mundo 3D.
  Hoy no hay placa de nombre flotante en `mundo3d.gd`, asi que ese trabajo es
  otro turno.
- ATENDIDA: `qa` adopto `prueba_party_ui` en la matriz, que va 16/16, y corrio
  la party viva con dos clientes.
- Solicitud a `qa` (ruta suya): agregar a la prueba viva de trade el camino de
  produccion, que hoy empieza en el menu de criatura y no en la prueba.
- Ver el menu de party en una ventana real: hasta ahora solo se comprobo
  headless, que no dibuja el popup.
- ATENDIDA en vivo: la mitad activa de la cama de Mill Avenue 1 (house 81,
  server 1760/client 2493) usa sin el rechazo "You cannot use this object";
  el jugador se duerme, el servidor lo expulsa (mismo orden removido->socket
  cerrado que la muerte) y el cliente vuelve al selector. Confirmado con la
  cuenta 123456 / Guillermo Knight y con GOD VALENTINO.
- ATENDIDA en vivo: el fix de `IDS_CAMA_PIE` se confirmo visualmente contra
  la cama real de Mill Avenue 1 despues de reiniciar el cliente; el usuario
  confirmo que ya se ve una sola figura durmiendo, no dos cruzadas.
- Wake-up y persistencia (reconectar con la cama ocupada, ver que se libera o
  se mantiene segun corresponda) no se probaron esta sesion.
- Solicitud a `qa` (ruta suya, `cliente3d/pruebas/matriz_qa_local.gd`):
  adoptar `prueba_cama_bajo_mouse.gd` y `prueba_cama_pie_ocupada.gd` en la
  matriz local, y retomar `prueba_casa_cama_vivo.tscn` contra Mill Avenue 1 /
  house 81 y contra la casa 6 (Sunset Homes) ahora que tanto la resolucion de
  clic del cliente como la guarda de `Game::playerUseItem` en el servidor
  estan corregidas. El bloqueo que dejo QA en casa 6
  (`RETURNVALUE_CANNOTUSETHISOBJECT`) coincide exactamente con la guarda de
  servidor que se corrigio en esta sesion (ver `worklog/servidor/STATE.md`).

## Bloqueos activos

- Ninguno.

## Decisiones

| Decision | Motivo | Reversible |
|---|---|---|
| El cliente envia intenciones, no resultados | Mantiene la autoridad del servidor | no |
| La reconexion limpia el estado vivo antes de reintentar | Evita mostrar como confirmado un mundo de una sesion anterior | si |
| La validacion del `WELCOME` vive en el cliente ademas del codec | Impide renderizar datos de mapa incompletos o fuera del modelo | si |
| La muerte manda el `0x14` de inmediato y no al pulsar el boton | `ProtocolGame::logout` ve al jugador ya removido y desconecta; dejar la sesion abierta mientras el jugador lee la pantalla no aporta nada | si |
| El regreso al selector lo pide el jugador, no el cierre del socket | Si el cierre saltara solo al login, la muerte pasaria sin que el jugador la vea | si |
| `_nueva_conexion()` como unico punto de creacion de la conexion | Permite probar muerte y reentrada headless sin abrir un socket real | si |
| El boton derecho del Battle List abre un menu en vez de seguir de una | Es lo que hace el cliente clasico, y seguir sigue estando dentro del menu | si |
| El menu de party se arma con los escudos y no con una lista propia | Esta rama no manda ningun paquete de party; inventar una lista seria estado que el servidor no confirmo | no |
| La experiencia compartida no se ofrece en la interfaz | El cliente 7.72 no tenia ese boton; el transporte queda por si se decide agregarla | si |
| El trade empieza por el jugador y sigue por el objeto | Es el orden inverso al del cliente clasico, pero el menu de criatura ya existe y el patron de dos pasos ya estaba en el cliente; se da vuelta el dia que haya menu de objeto | si |
| La calavera y el escudo se dibujan por codigo, no con un sprite importado | Esta rama no tiene `Tibia.pic`, que es donde vive ese icono en el cliente 2D; inventar un PNG parecido seria peor que una forma propia con el color exacto de la tabla | si |
| La velocidad solo se muestra del personaje propio | El cliente 7.72 no ensena la velocidad ajena en ningun panel; mostrarla del objetivo seria informacion que el juego original no da | si |
| El texto de cada valor va en tooltip y en ingles | La pantalla es en ingles como Tibia, y el color solo no distingue una invitacion enviada de una recibida | si |
| La cama se resuelve con rectangulo en pantalla, no con rayo contra el piso | `tiene_alto=true` hace que el rayo pase de largo por el respaldo; es el mismo mecanismo que ya usan las puertas simples, no uno nuevo | si |
| La busqueda de cama solo mira `EstadoMundo.casillas`, nunca vecinos por cercania | El usuario pidio explicitamente no ocultar el problema con un offset ni con prediccion local; adivinar la casilla mas cercana podia mandar el uso a un objeto que el jugador no eligio | si |
| Se elimino el parche de "vecindario" que un turno anterior dejo sin terminar en `_usar_en_casilla` | Era una heuristica de cercania (radio 3) sin causa raiz identificada; el fix de rectangulo la vuelve innecesaria y evita que un clic normal reciba un objeto adivinado | si |
| "Pie de la malla 3D" y "textura dormida" son predicados independientes sobre el mismo cid, aunque compartan casi todos sus valores | Un pie ocupado necesita ser las dos cosas a la vez (dormida=true, modelo=false); fusionarlos en una sola lista fue justo el bug de esta sesion | si |

## Notas para quien retome

- El cliente TVP 7.72 existente es referencia y compatibilidad, no dueño del
  cliente propio.
- La muerte NO tiene opcode propio en esta rama. La unica fuente valida es
  `EstadoMundo.jugador_muerto`; no volver a deducirla del `0x6C` suelto, de la
  barra de vida ni de un texto del chat.
- Las marcas no calculan nada: si una calavera aparece cuando no toca, el fallo
  esta en `estado_mundo.gd` o en el servidor, no en `marca_criatura.gd`.
- Continuidad:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d pruebas/prueba_muerte_reentrada.tscn`
  y `... pruebas/prueba_estado_criatura_ui.tscn`.

- Corrección pendiente de validación visual: los teletransportes grandes ahora
  fuerzan realineación inmediata del ancla para evitar offsets de interacción.

- Causa raiz del bloqueo de camas reales (esta sesion): NO era un problema de
  mapeo servidor<->cliente (1760/1761 <-> 2493/2494 ya era correcto) ni de
  permisos de casa. Era que el clic se resolvia con un rayo contra el piso, y
  una cama tiene altura (`tiene_alto=true` en `items772.json`). El client id
  1281 que el servidor rechazaba ("You cannot use this object") es
  literalmente "framework wall" en el catalogo -un tramo de pared en la
  casilla vecina, no la cama- lo que probo que el cliente apuntaba a la
  casilla equivocada, no que el servidor tuviera mal la cama.
- El fix reutiliza `_hit_puerta_en_pantalla` (rectangulo en pantalla), ya
  validado para puertas simples. Si algun dia se generaliza a mas objetos con
  `tiene_alto=true`, esa es la funcion a extender; no crear una nueva.
- `_es_pieza_de_cama` y `_es_cama_modelo` NO son intercambiables:
  `_es_cama_modelo` excluye el pie (`IDS_CAMA_PIE`) porque decide que malla 3D
  autorada usar, y el pie no usa esa malla. `_es_pieza_de_cama` es para
  resolucion de clic y SI incluye el pie, porque el jugador puede clickear
  cualquiera de las dos mitades.
- Continuidad de esta correccion:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d -s res://pruebas/prueba_cama_bajo_mouse.gd`
  (el ejecutable de Godot 4.7.2 en esta maquina esta en
  `C:\Users\dell\3DTIBIA\herramientas\godot\`, no en el repo).
- No se toco `servidor/` en esta correccion; los diagnosticos `[BedDiag]` que
  ya estaban en `game.cpp` (sucios, sin commitear al abrir este turno) no se
  modificaron ni se les atribuye autoria de este cierre.
