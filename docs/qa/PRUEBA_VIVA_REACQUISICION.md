# Prueba viva de reacquisicion de monstruos

Fecha: 2026-08-29
Carril: qa
Servidor: TVP 7.72 reconstruido, puertos 7171/7172
Estado: **COMPROBADO**

## Objetivo

Certificar el cambio de `servidor/src/monster.cpp`: si el objetivo sale
temporalmente de la ventana visible sin logout, muerte, cambio de piso ni PZ,
el monstruo conserva `attackedCreature` y retoma el ataque cuando ese mismo
jugador vuelve.

## Comando

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d \
  pruebas/prueba_reacquisicion_monstruo.tscn
```

La prueba no envia movimiento del personaje. Un god usa ordenes del servidor
para reunirlo en `(32082,32145,6)`, invocar un `cave rat`, moverlo a
`(32083,32184,6)` y devolverlo. Son 39 SQM en el mismo piso y ambas posiciones
estan fuera de casa y PZ.

## Oracle y resultado

Una bajada de vida sola no alcanza: hay criaturas silvestres en el campo. El
oracle exige que el mensaje autoritativo de dano nombre al `cave rat` invocado
y conserva su id de criatura.

La corrida valida produjo:

```text
Cave Rat nuevo id 1073764894 visto por el personaje.
You lose 2 hitpoints due to an attack by a cave rat.
Primer golpe: 133 -> 131.
Valentino volvio con vida 131; esperando otro golpe.
You lose 3 hitpoints due to an attack by a cave rat.
Golpe tras volver: 131 -> 128, cave rat id 1073764894.
La limpieza retira al monstruo invocado.
Prueba viva de reacquisicion de monstruo: OK
```

Una corrida preliminar se descarto correctamente: un `spider` silvestre habia
causado las dos bajadas de vida. Ese hallazgo endurecio la prueba para que el
nombre del atacante forme parte obligatoria de la evidencia.

Al cerrar, el god se acerca a la posicion confirmada del monstruo, `/killall`
lo retira y la prueba exige esa retirada antes de ejecutar `omani`. Despues
devuelve al personaje a su templo y cierra ambas conexiones. Nadie muere ni
pierde un nivel.
