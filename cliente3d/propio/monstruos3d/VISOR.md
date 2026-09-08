# Visor interactivo de monsters 3D

El visor descubre automaticamente todas las entradas de
`mallas/catalogo.json` con `anatomia=true`. Al agregar y generar otro
monster, aparece en la vista `Todos` sin editar una segunda lista.
La misma vista agrega Personaje principal [outfit 128] como referencia de
escala usando el modelo authored del jugador del cliente (0.5 de escala).
No cuenta como monster: la galeria contiene 40 monsters y una referencia.
La captura visor_personaje.png registra esa vista de 41 elementos.

Desde la raiz de TVP3D:

```powershell
& 'C:/Users/dell/3DTIBIA/herramientas/godot/Godot_v4.7.2-stable_win64.exe' --path cliente3d --script res://propio/monstruos3d/visor.gd
```

## Controles

| Entrada | Accion |
|---|---|
| Clic izquierdo | Seleccionar un monster |
| Arrastrar con izquierdo | Mover el seleccionado sobre el suelo |
| Boton derecho + arrastre | Orbitar la camara |
| Boton central + arrastre | Desplazar la camara |
| WASD | Desplazar la camara |
| Rueda | Acercar o alejar |
| Flechas | Mover con precision el monster seleccionado |
| Q / E | Girar el monster seleccionado |
| F / boton Enfocar | Centrar y acercar la camara al seleccionado |
| R / boton Ordenar | Restaurar la cuadricula alfabetica |
| Todos | Alternar galeria completa y detalle individual |
| Animacion | Pausar o reproducir las fases originales |
| Orbita | Activar o detener el giro automatico de camara |

El selector permanece activo en ambos modos. En `Todos`, elegir un nombre
selecciona y enfoca ese monster. En detalle muestra ademas el sprite original.
Elegir Personaje principal fuerza Todos, porque su funcion es comparar tamano
y no pertenece al catalogo anatomico de monsters.
El modo detalle conserva la recarga automatica de la malla modificada; la
galeria no sondea los 40 archivos para mantener estable el costo por frame.

Opciones compatibles para capturas o grupos concretos:

```powershell
# Detalle individual
... visor.gd -- --tipo 111

# Grupo elegido en la cuadricula interactiva
... visor.gd -- --todos --grupo 21,111,212,217,218

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

