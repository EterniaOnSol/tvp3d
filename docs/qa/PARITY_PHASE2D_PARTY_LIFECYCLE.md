# Phase 2D — Paridad de ciclo de vida de party (TVP 7.72)

Estado: **CERTIFICADO EN VIVO**.

`PARITY-PARTY-LIFECYCLE-001`: observacion `LIVE_ORACLE` fresca contra TVP
7.72 real y replay `PASS 15/15` con el comparador generico sin modificar.
Cero muertes, cero combate, cero monstruos invocados.

Este es el **tercer dominio de paridad** distinto, despues de corpse de
monstruo y reacquisicion de objetivo.

## Alcance

Cubre **solo** el ciclo de vida de la party: estado inicial sin party,
invitacion, union, transferencia de liderazgo y salida/disolucion.

La **experiencia compartida es un dominio separado**, con su propio fixture
(`PARITY-PARTY-SHARED-EXP-001`), su propio adaptador y su propio documento
(`docs/qa/PARITY_PHASE2D_PARTY_SHARED_EXP.md`). No se mezcla aqui.

## Como observa el servidor este dominio

El servidor de esta rama **no manda una lista de miembros de party**.
Comunica cada cambio reenviando el escudo de cada criatura
(`PartyShields_t`). Por eso la evidencia son los escudos que ven **las dos
sesiones**, nunca una lista inventada — el propio documento historico
(`docs/qa/PRUEBA_VIVA_PARTY.md`) ya habia establecido ese criterio.

Valores verificados en `servidor/src/const.h:187-193`:

| Valor | Constante | Significado |
|---:|---|---|
| 0 | `SHIELD_NONE` | sin escudo de party |
| 1 | `SHIELD_WHITEYELLOW` | invitacion recibida |
| 2 | `SHIELD_WHITEBLUE` | invitacion enviada |
| 3 | `SHIELD_BLUE` | miembro |
| 4 | `SHIELD_YELLOW` | lider |

**El enum tiene exactamente esos cinco valores.** No existen variantes de
escudo para experiencia compartida en 7.72, asi que no se invento ninguna.

## Fixture y case

- `qa/parity/fixtures/tvp772/party_lifecycle/parity-party-lifecycle-001.json`
  (`tvp3d.qa.parity_fixture/2.0.0`, oracle `TVP_772`/`7.72`, clasificacion
  `MATCH_EXPECTED`)
- `qa/parity/cases/tvp772/party_lifecycle/parity-party-lifecycle-001.case.json`
  (`tvp3d.qa.case/2.0.0`, `LEGACY_PARITY`, `SINGLE_OBSERVATION`,
  `case_id == fixture_id`)

**15 aserciones `EQ`**, todas sostenidas por la evidencia historica:

| Etapa | Aserciones |
|---|---:|
| `initial` | 3 (se ven; ambos escudos en 0) |
| `after_invite` | 2 (enviada=2, recibida=1) |
| `after_join` | 4 (lider ve 3, miembro ve 4, lider propio 4, miembro propio 3) |
| `after_leadership_transfer` | 3 (escudos invertidos + quien cedio se ve miembro) |
| `after_leave` | 3 (los tres escudos vuelven a 0) |

## Normalizacion

Se comparan **roles**, nunca identidades: quien invita, quien es invitado,
quien es lider, quien es miembro. Excluidos de la comparacion:
`creature_runtime_ids`, `character_names`, `account_id`, `positions`,
`server_message_text`, `wall_clock_timestamp`.

El texto exacto de los mensajes del servidor **no** forma parte de la
comparacion: lo comparado es el estado de escudo autoritativo resultante.

## Replay contra evidencia grabada

Evidencia: `docs/qa/PRUEBA_VIVA_PARTY.md` (corrida del 2026-08-29), que
documenta las cinco etapas con sus escudos.

```text
PASS PARITY-PARTY-LIFECYCLE-001
exit=0 pass=1 fail=0 blocked=0 not_run=0
```

`assertions_total = 15`, `assertions_passed = 15`, byte-identico entre dos
corridas. `qa/parity/tools/replay.py` **no se modifico**: el comparador
generico acepto un **tercer** dominio de comportamiento sin ningun cambio.

## Adaptador de captura en vivo

`cliente3d/pruebas/prueba_parity_party_lifecycle_capture.gd` + `.tscn`
(nuevos, QA-owned). El historico `prueba_party_viva.gd` **no se toco** y
**no se copio ninguna de sus credenciales literales**.

Credenciales solo por entorno: `TVP772_ACCOUNT`, `TVP772_PASSWORD`,
`TVP772_GOD_CHARACTER`, `TVP772_PLAYER_CHARACTER` (opcionales
`TVP772_HOST`, `TVP772_LOGIN_PORT`). Nunca literales, nunca impresas.

Terreno de reunion: `(32008,32400,7)`, el punto aislado y colocable ya
calificado en Phase 2C.1/2C.2. Es detalle de implementacion de la captura y
**no entra** al payload normalizado.

Mutacion: solo comandos de party y un `/c` para reunir a las dos sesiones.
Sin invocar, sin atacar, sin `/killall`, sin muerte, sin tocar inventario ni
persistencia.

## Ejecucion certificada

Una sola ejecucion, exito al **primer intento**, codigo de salida 0 y
exactamente una linea `OBSERVATION_JSON`:

```text
Estado inicial: ambas sesiones sin escudo de party.
A invita a B (0xA3).
  [A] <B> has been invited. Open the party channel to communicate with your members.
  [B] <A> has invited you to her party.
Invitacion confirmada por los escudos de ambas sesiones.
B se une a la party de A (0xA4).
  [A] <B> has joined the party.
Union confirmada: lider y miembro coherentes en las dos sesiones.
A pasa el liderazgo a B (0xA6).
  [A] <B> is now the leader of the party.
  [B] You are now the leader of the party.
Transferencia confirmada: los escudos se invirtieron.
A (ahora miembro) sale de la party (0xA7).
  [B] Your party has been disbanded.
Disolucion confirmada: ninguna sesion conserva escudo.
```

Los nombres de personaje del transcripto estan reemplazados por `<A>` y `<B>`:
son identidades concretas y el criterio del fixture es comparar **roles**, no
identidades. El texto exacto tampoco entra a la comparacion.

Etapas ejercitadas: inicial -> invitar (`0xA3`) -> unirse (`0xA4`) ->
transferir liderazgo (`0xA6`) -> salir/disolver (`0xA7`).

## Payload normalizado

```json
{
  "initial": {
    "sessions_see_each_other": true,
    "inviter_sees_invitee_shield": 0,
    "invitee_sees_inviter_shield": 0
  },
  "after_invite": {
    "inviter_sees_invitee_shield": 2,
    "invitee_sees_inviter_shield": 1
  },
  "after_join": {
    "leader_sees_member_shield": 3,
    "member_sees_leader_shield": 4,
    "leader_self_shield": 4,
    "member_self_shield": 3
  },
  "after_leadership_transfer": {
    "previous_leader_sees_new_leader_shield": 4,
    "new_leader_sees_previous_leader_shield": 3,
    "previous_leader_self_shield": 3
  },
  "after_leave": {
    "former_member_sees_other_shield": 0,
    "former_member_self_shield": 0,
    "remaining_player_self_shield": 0
  }
}
```

## Limpieza

La party de prueba queda deshecha por el propio recorrido: la ultima etapa
es exactamente la salida que la disuelve, confirmada por los tres escudos en
0. Ante cualquier fallo intermedio el adaptador manda `0xA7` por ambas
sesiones como higiene defensiva antes de cerrar. Ningun personaje quedo en
party al terminar.

## Seguridad

- **Muertes de jugador: 0**
- **Monstruos invocados: 0**
- **Acciones de combate: 0**
- **Usos de `/killall`: 0**
- Ningun personaje perdio nivel ni experiencia.

## Requisito diferido para el TVP3D nativo

Este fixture es **evidencia de oracle legacy**, no una implementacion. La
semantica legacy `0xA3`/`0xA4`/`0xA6`/`0xA7` y los valores de
`PartyShields_t` **no** entran en los contratos de Architecture V2. La
implementacion nativa futura debera reproducir el comportamiento resultante
a traves de nuestra propia arquitectura servidor-autoritativa. Ver la nota
de requisito completa en `docs/qa/PARITY_PHASE2D_PARTY_SHARED_EXP.md`.

## Conteos

| Inventario | Antes | Despues |
|---|---:|---:|
| Obligaciones Architecture V2 | 198 / 0 | 198 / 0 (sin cambio) |
| Fixtures `LEGACY_PARITY` | 5 | **6** |
| Casos de replay `QACaseV2` | 5 | **6** |
| Observaciones `RECORDED_EVIDENCE` | 4 | **5** |
| Observaciones `LIVE_ORACLE` | 2 | **3** |

Phase 2 sigue **EN CURSO**: este turno amplia el corpus de oracle, no lo
cierra.
