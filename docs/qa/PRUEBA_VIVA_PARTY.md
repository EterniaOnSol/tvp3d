# Prueba viva de party

Fecha: 2026-08-29
Carril: qa
Servidor: TVP 7.72 en Docker, puertos 7171/7172

## Que prueba y que no

Esta rama **no manda ningun paquete de party**. No hay lista de miembros que
esperar: `Party` avisa cada cambio mandando el escudo de cada criatura por el
`0x91` (`servidor/src/party.cpp:39-268`). Por eso la prueba no comprueba una
lista —seria inventada— sino que los escudos de **las dos sesiones** cuentan la
misma party en cada paso.

Archivo: `cliente3d/pruebas/prueba_party_viva.tscn`.

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path cliente3d ^
  pruebas/prueba_party_viva.tscn
```

No mata a nadie, no mueve objetos y no le cuesta un nivel a ningun personaje,
asi que se puede repetir. Abre un unico login y separa seis segundos la segunda
sesion, para no chocar con `Ban::acceptConnection`.

## Etapas

| Etapa | Orden | Que se comprueba |
|---|---|---|
| Reunion | `/c` del god | Las dos sesiones se ven y ninguno arranca con escudo |
| Invitar | `0xA3` | El que invita ve escudo 2 en el otro; el invitado ve 1 |
| Unirse | `0xA4` | El lider ve 3 en el otro y se ve 4; el miembro ve 4 y se ve 3 |
| Liderazgo | `0xA6` | Los dos escudos se dan vuelta; el que lo cedio se ve como miembro |
| Salir | `0xA7` | La party se deshace y los dos escudos vuelven a 0 |

Los valores son los de `PartyShields_t` (`servidor/src/const.h:187-193`): 1
invitacion recibida, 2 invitacion enviada, 3 miembro, 4 lider.

## Resultado del 2026-08-29

Salida real, con los mensajes del propio servidor entre medio:

```text
Se ven: Valentino es 268435541 para el god, y el god es 268435540 para Valentino.
  OK  las dos sesiones ven a la otra criatura
  OK  nadie empieza con escudo de party
  [god] Valentino has been invited. Open the party channel to communicate with your members.
  [Valentino] GOD VALENTINO has invited you to her party.
  OK  el que invita ve la invitacion enviada
  OK  el invitado ve la invitacion recibida
  [god] Valentino has joined the party.
  OK  el lider ve al otro como miembro
  OK  el miembro ve al otro como lider
  OK  el lider se ve a si mismo como lider
  OK  el miembro se ve a si mismo como miembro
  [god] Valentino is now the leader of the party.
  OK  pasar el liderazgo da vuelta los dos escudos
  OK  el que lo cedio se ve como miembro
  [Valentino] Your party has been disbanded.
  OK  al salir el ultimo miembro la party se deshace
  OK  ninguno de los dos conserva escudo
Prueba viva de party: OK
```

## Limites

- La experiencia compartida `0xA8` no se ejercita: el servidor la acepta, pero
  el cliente 7.72 no tenia ese boton y la interfaz no lo ofrece. El transporte
  esta probado con bytes exactos en `red/party_self_test.gd`.
- Revocar una invitacion (`0xA5`) tiene su self-test de bytes, pero no recorrido
  vivo: haria falta un tercer paso que invite y se arrepienta antes de que el
  otro acepte.
- La prueba mira escudos, no el canal de party ni la reparticion de
  experiencia.
