# PARITY-VIP-DUPLICATE-ADD-001

Fixture LIVE_ORACLE de Phase 2. La primera alta VIP por nombre debe producir una entrada `0xD2` de la identidad esperada. La segunda alta idéntica debe producir únicamente el rechazo autoritativo `0xB4`, clase `0x17`, texto `This player is already in your list.`, sin segunda entrada.

Cadena auditada: `ProtocolGame::parseAddVip` -> `Game::playerRequestAddVip` -> `IOLoginData::getGuidByNameEx`/`getPlayerByName` -> `Player::addVIP`. `VIPList` es `std::unordered_set<uint32_t>`; capacidad se comprueba antes de `insert`, y `insert(...).second == false` rechaza el duplicado antes de `sendVIP`. El cliente usa `enviar_agregar_vip`/`enviar_quitar_vip` y `EstadoMundo` parsea `vip_actualizado`/`mensaje_pantalla`.

La captura consume el replay inicial, exige que el GUID esperado esté ausente, verifica la primera entrada y luego envía la misma alta. B permanece offline. La baja es sólo cleanup antes del logout. No hay evidencia histórica runtime específica, por lo que RECORDED_EVIDENCE no cambia.
## Certificación viva y cierre

La reanudación resolvió `TVP772_VIP_TARGET_ID` mediante una consulta `SELECT` read-only a `players`, inyectándolo sólo al proceso Godot. El personaje objetivo fue una identidad persistida única y su archivo de jugador existía; el GUID no se publica.

El intento 1 de esta reanudación pasó: replay inicial completo con 0 contactos, objetivo ausente y lista bajo capacidad; primera alta por API de producción produjo el `0xD2` esperado; la segunda alta idéntica produjo `0xB4`, clase `0x17` (23), con el texto exacto. No apareció una segunda entrada del objetivo. El objetivo permaneció offline. `0xDD` se usó únicamente como cleanup antes del logout. No hubo cuentas/personajes/items/progresión/combat ni procesos ajenos terminados. El turno bloqueado anterior queda preservado históricamente como 0 intentos por GUID ausente.

La observación normalizada vive en `qa/parity/observations/tvp772/vip_duplicate_add/live/`; el caso individual replaya `PASS 4/4`. El corpus completo de 20 casos dio en dos corridas: `19 PASS, 1 NOT_RUN` (el EVIDENCE_ONLY de loot), `0 FAIL`, `0 BLOCKED`; ambas secuencias fueron idénticas. Todos los JSON parsean. `replay.py`, `conexion772.gd`, `estado_mundo.gd` y la evidencia previa VIP quedaron sin cambios.

Hash SHA-256 del fixture: `7F2041B9A89F63FCE1E052DD3422E0BC2BFBD603344D3F39392350DCBD37071D`; la identidad esperada es metadata efímera y no forma parte del hash público.

No se certifican baja VIP, self-add, capitalización alternativa, capacidad, límites de lista, presencia ni persistencia como semántica.