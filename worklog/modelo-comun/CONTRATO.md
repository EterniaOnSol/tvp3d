# Contrato: modelo-comun

Version: 1.0.0
Estado: PUBLICADO
Propietario: modelo-comun
Depende de: ninguno

## Proposito

Definir las coordenadas, tiles, entidades y transiciones que comparten el
servidor propio, el cliente 3D, el editor y las pruebas, sin transferir al
cliente ninguna autoridad sobre el estado del juego.

## Esquemas concretos

### PosicionTibia

```json
{
  "x": "int32",
  "y": "int32",
  "z": "uint8[0..15]"
}
```

`x` y `y` son coordenadas logicas enteras. `z=7` es la superficie de
referencia del espacio 3D; un `z` menor se representa mas alto. La conversion
3D usa un ancla `Vector3i`, un tamano positivo de SQM y una altura positiva de
piso. Convertir una posicion a 3D y volverla a convertir debe producir la
misma posicion cuando el punto 3D cae en la rejilla.

Los chunks usan un lado entero positivo. La clave es
`floor(x/lado)_floor(y/lado)` y la coordenada local siempre queda en
`[0, lado-1]`, incluso para coordenadas negativas.

### Tile

```json
{
  "position": {"x": "int32", "y": "int32", "z": "uint8"},
  "tipo": "SUELO|PARED|AGUA|ARBOL|ROCA|DECORACION|ESCALERA",
  "caminable": "bool"
}
```

La enumeracion es cerrada y sus valores estables son `SUELO=0`, `PARED=1`,
`AGUA=2`, `ARBOL=3`, `ROCA=4`, `DECORACION=5` y `ESCALERA=6`. Un mapa propio
usa version `1`, dimensiones entre 3 y 128 y conserva su origen logico. La
representacion JSON de un mapa contiene `version`, `origen`, `ancho`, `alto` y
una lista de celdas locales `{x, y, tipo}`.

En el fixture de demostracion, `SUELO` y `ESCALERA` son caminables; el
servidor debe volver a validar la caminabilidad contra su estado autoritativo
antes de aplicar un movimiento. El cliente solo presenta el resultado
recibido.

### Entidad

```json
{
  "id": "uint32",
  "nombre": "string[0..24]",
  "pos": "PosicionTibia",
  "direccion": "norte|este|sur|oeste"
}
```

`id` identifica una entidad durante su vida en la partida. La posicion,
direccion, existencia y cambios de una entidad pertenecen al servidor; el
cliente no puede confirmarlos localmente.

### IntencionDeAccion

```json
{
  "accion": "MOVER",
  "dx": "int8[-1..1]",
  "dy": "int8[-1..1]"
}
```

En la primera version solo se acepta movimiento cardinal: exactamente uno de
`dx` o `dy` debe ser distinto de cero. Las acciones futuras deben agregar un
tipo y su payload al contrato antes de implementarse; no se interpretan como
movimiento por defecto.

### TransicionDeAccion

```json
{
  "estado": "SOLICITADA|VALIDADA|RECHAZADA|APLICADA|EMITIDA",
  "accion": "MOVER",
  "resultado": "PosicionTibia|null",
  "motivo": "string[0..160]"
}
```

La unica secuencia valida es:

| Estado | Evento | Siguiente |
|---|---|---|
| `SOLICITADA` | `VALIDAR` | `VALIDADA` o `RECHAZADA` |
| `VALIDADA` | `APLICAR` | `APLICADA` |
| `APLICADA` | `EMITIR` | `EMITIDA` |
| `RECHAZADA` | `NOTIFICAR` | `EMITIDA` |

Una accion rechazada no cambia posicion, inventario ni persistencia. El
servidor es el unico que puede producir `APLICADA`.

## Errores

| Codigo | Cuando ocurre | Que hace quien llama |
|---|---|---|
| `COORDENADA_Z_INVALIDA` | `z` esta fuera de `0..15` | Rechazar la posicion y no convertirla |
| `CHUNK_LADO_INVALIDO` | El lado es cero o negativo | Rechazar la operacion y pedir una configuracion valida |
| `MAPA_ARCHIVO_AUSENTE` | La ruta no contiene un archivo de mapa | Mantener el mapa activo y reportar la ruta al operador |
| `MAPA_ARCHIVO_ILEGIBLE` | El archivo no puede abrirse | Mantener el mapa activo y reportar el error de lectura |
| `MAPA_JSON_INVALIDO` | El contenido no es un objeto JSON | Rechazar la carga y conservar el mapa activo |
| `MAPA_VERSION_NO_SOPORTADA` | El JSON no usa version `1` | Rechazar el archivo; no aplicar un fallback silencioso |
| `MAPA_ORIGEN_INVALIDO` | Falta el objeto `origen` o no tiene forma de posicion | Rechazar el mapa y conservar el mapa activo |
| `MAPA_DIMENSION_INVALIDA` | Ancho o alto estan fuera de `3..128` | Rechazar el mapa y conservar el mapa activo |
| `MAPA_SIN_CELDAS` | La lista de celdas esta ausente o vacia | Rechazar el mapa y conservar el mapa activo |
| `MAPA_CELDA_INVALIDA` | Una entrada de celdas no es un objeto | Rechazar la carga |
| `MAPA_CELDA_FUERA_DE_RANGO` | Una celda queda fuera de ancho/alto | Rechazar la carga |
| `MAPA_CELDA_DUPLICADA` | Dos entradas usan la misma coordenada local | Rechazar la carga |
| `TIPO_TILE_DESCONOCIDO` | El tipo no pertenece a la enumeracion cerrada | Rechazar la celda y no mutar el mapa |
| `MOVIMIENTO_NO_CARDINAL` | `dx`/`dy` no forman exactamente un paso cardinal | Rechazar la intencion sin mutar el estado |
| `TRANSICION_INVALIDA` | Un evento no pertenece a la tabla | Rechazar el evento y conservar el estado anterior |

## No expone

- Credenciales, sesiones, tokens ni rutas privadas.
- La autoridad del servidor, reglas de persistencia o decisiones de otro
  carril.
- Sprites, modelos 3D o semantica de proveedor; esos datos pertenecen a
  `assets` y a los consumidores visuales.
- El framing o los opcodes de red; pertenecen a `protocolo-red`.

## Consumidores

- `protocolo-red`, para validar posiciones y payloads sin duplicar vocabulario.
- `servidor`, para aplicar acciones y persistir el estado autoritativo.
- `cliente`, para convertir posiciones y presentar entidades confirmadas.
- `assets` y `editor`, para conservar coordenadas, tipos e ids durante la
  importacion y exportacion.
- `qa`, para probar la tabla cerrada y las transiciones.

## Compatibilidad y versionado

Agregar un campo opcional o un tipo nuevo exige una version menor y una regla
de compatibilidad explicita. Cambiar valores de enum, rangos, significado de
coordenadas o transiciones exige una version mayor y una migracion. Un
consumidor debe rechazar versiones no soportadas con un error identificable;
no debe reinterpretarlas silenciosamente.
