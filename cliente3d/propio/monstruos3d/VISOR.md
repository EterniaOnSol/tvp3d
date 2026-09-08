# Visor interactivo de monsters 3D

El visor descubre automaticamente todas las entradas de
`mallas/catalogo.json` con `anatomia=true`. Al agregar y generar otro
monster, aparece en la vista `Todos` sin editar una segunda lista.
La misma vista agrega los 14 outfits humanos clasicos 128-134 y 136-142 como
referencias de escala. Son modelos 3D procedurales diferenciados por ropa y
equipo, con colores de cabeza/cuerpo/piernas/pies y tres poses de paso. El
personaje base mide cerca de una casilla, frente a las 0.67 de la referencia
anterior. No cuentan como monsters: la galeria completa contiene 40 monsters
y 14 outfits. La captura visor_outfits.png registra la vista exclusiva de
personajes. Cada etiqueta muestra ancho x alto x largo en casillas.
La cuadricula calcula su separacion desde la mayor huella del grupo para que
Dragon y Dragon Lord no se solapen con sus vecinos.

Jerarquia gigante vigente (ancho x alto x largo, en casillas):

- Frost Troll: 1.00 x 1.57 x 0.67.
- Giant Spider: 2.19 x 1.03 x 2.55.
- The Old Widow: 2.41 x 1.22 x 2.80.
- Dragon: 3.20 x 1.87 x 3.08.
- Dragon Lord: 3.55 x 2.07 x 3.41.

comparacion_gigantes.png registra jugador, los tres trolls, ambas aranas
gigantes y ambos dragones en una cuadricula comun.

Desde la raiz de TVP3D:

```powershell
& 'C:/Users/dell/3DTIBIA/herramientas/godot/Godot_v4.7.2-stable_win64.exe' --path cliente3d --script res://propio/monstruos3d/visor.gd
```

## Controles

| Entrada | Accion |
|---|---|
| Clic izquierdo | Seleccionar un modelo |
| Arrastrar con izquierdo | Mover el seleccionado sobre el suelo |
| Boton derecho + arrastre | Orbitar la camara |
| Boton central + arrastre | Desplazar la camara |
| WASD | Desplazar la camara |
| Rueda | Acercar o alejar |
| Flechas | Mover con precision el modelo seleccionado |
| Q / E | Girar el modelo seleccionado |
| F / boton Enfocar | Centrar y acercar la camara al seleccionado |
| R / boton Ordenar | Restaurar la cuadricula alfabetica |
| Todos | Alternar galeria completa y detalle individual |
| Animacion | Pausar o reproducir las fases originales |
| Orbita | Activar o detener el giro automatico de camara |

El selector permanece activo en ambos modos. En `Todos`, elegir un nombre
selecciona y enfoca ese monster. En detalle muestra ademas el sprite original.
Elegir cualquier character fuerza Todos, porque su funcion es comparar tamano
y no pertenece al catalogo anatomico de monsters.
El modo detalle conserva la recarga automatica de la malla modificada; la
galeria no sondea los 40 archivos para mantener estable el costo por frame.

Opciones compatibles para capturas o grupos concretos:

```powershell
# Detalle individual
... visor.gd -- --tipo 111

# Grupo elegido en la cuadricula interactiva
... visor.gd -- --todos --grupo 21,111,212,217,218

# Solo los 14 outfits humanos
... visor.gd -- --outfits

# Verificacion automatica
... visor.gd -- --self-test --todos
```

El movimiento existe solo en este visor local. No cambia posiciones de juego,
colisiones ni estado autoritativo del servidor.

El visor se ejecuta como SceneTree, por lo que delega los eventos a
entrada_visor.gd, un Node dentro del arbol que si recibe _input. El self-test
inyecta rueda, arrastre derecho y arrastre central para comprobar el recorrido
del receptor hasta zoom, orbita y paneo. En headless los eventos se entregan
directamente al receptor porque la reinyeccion de mouse de Windows no es
determinista sin una ventana activa.

